import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Size, Rect;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

// ── Operation codes (kept simple/sendable for the isolate) ──────
const int _opAuto = 0;
const int _opGrayscale = 1;
const int _opBrightness = 2;
const int _opContrast = 3;
const int _opSharpen = 4;
const int _opDocMode = 5;
const int _opInvert = 6;
const int _opGentleDocMode = 7; // ✅ for complex scripts (Devanagari/CJK)

/// Sendable payload for the background isolate (all fields are sendable).
class _EnhanceParams {
  final Uint8List bytes;
  final int op;
  final double value; // brightness / contrast amount (ignored by others)
  const _EnhanceParams(this.bytes, this.op, this.value);
}

// ✅ Crop — lets the user drag out an unwanted area (e.g. a finger holding
// the paper) instead of relying on unreliable AI object removal.
class _CropParams {
  final Uint8List bytes;
  final int x;
  final int y;
  final int w;
  final int h;
  const _CropParams(this.bytes, this.x, this.y, this.w, this.h);
}

Uint8List? _cropBytes(_CropParams p) {
  final image = img.decodeImage(p.bytes);
  if (image == null) return null;
  final x = p.x.clamp(0, image.width - 1);
  final y = p.y.clamp(0, image.height - 1);
  final w = p.w.clamp(1, image.width - x);
  final h = p.h.clamp(1, image.height - y);
  final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
  return img.encodeJpg(cropped, quality: 90);
}

img.Image _sharpenImg(img.Image image) {
  return img.convolution(image, filter: [
    0, -1, 0, //
    -1, 5, -1, //
    0, -1, 0,
  ]);
}

/// Runs INSIDE the background isolate. Pure CPU work: decode → op → encode.
/// Top-level + only sendable input, so it is safe to run via Isolate.run.
Uint8List? _processBytes(_EnhanceParams p) {
  var image = img.decodeImage(p.bytes);
  if (image == null) return null;

  switch (p.op) {
    case _opAuto:
      image = img.adjustColor(image,
          brightness: 1.1, contrast: 1.2, saturation: 0.9);
      image = _sharpenImg(image);
      break;
    case _opGrayscale:
      image = img.grayscale(image);
      break;
    case _opBrightness:
      image = img.adjustColor(image, brightness: p.value);
      break;
    case _opContrast:
      image = img.adjustColor(image, contrast: p.value);
      break;
    case _opSharpen:
      image = _sharpenImg(image);
      break;
    case _opDocMode:
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.8, brightness: 1.1);
      // ✅ Sharpen text edges — makes characters more distinct for OCR,
      // especially on slightly blurry or low-light phone photos.
      image = _sharpenImg(image);
      break;
    case _opGentleDocMode:
    // ✅ Devanagari/Chinese/Japanese/Korean have fine strokes (matras,
    // conjuncts, radicals) that the aggressive contrast+sharpen combo
    // above was distorting, causing misrecognition. Milder pass only.
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.25, brightness: 1.08);
      break;
    case _opInvert:
      image = img.invert(image);
      break;
  }

  return img.encodeJpg(image, quality: 90);
}

/// All heavy pixel work runs in a BACKGROUND ISOLATE via Isolate.run, so the
/// UI thread never blocks. Plugin work (temp dir + file write) stays on the
/// main isolate.
///
/// Previously these ran on the UI isolate — a high-res phone photo froze the
/// app and triggered "Application Not Responding" (ANR).
class ImageEnhancementService {
  static Future<File?> autoEnhance(File f) =>
      _run(f, 'auto_enhanced', _opAuto);

  static Future<File?> applyGrayscale(File f) =>
      _run(f, 'grayscale', _opGrayscale);

  static Future<File?> adjustBrightness(File f, double brightness) =>
      _run(f, 'brightness', _opBrightness, brightness);

  static Future<File?> adjustContrast(File f, double contrast) =>
      _run(f, 'contrast', _opContrast, contrast);

  static Future<File?> applySharpen(File f) =>
      _run(f, 'sharpen', _opSharpen);

  static Future<File?> applyDocumentMode(File f) =>
      _run(f, 'document_mode', _opDocMode);

  /// ✅ For Devanagari/Chinese/Japanese/Korean scans — mild contrast only,
  /// no sharpen convolution (preserves fine strokes those scripts need).
  static Future<File?> applyGentleDocumentMode(File f) =>
      _run(f, 'gentle_document_mode', _opGentleDocMode);

  static Future<File?> applyInvert(File f) =>
      _run(f, 'invert', _opInvert);

  /// ✅ Crops the image to [rect] (in the image's own pixel coordinates).
  /// Use this to manually cut out an unwanted area — e.g. a finger holding
  /// the paper — since reliably auto-detecting and "erasing" a finger
  /// would need a heavy AI inpainting model that isn't practical on-device.
  static Future<File?> cropImage(File imageFile, Rect pixelRect) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final params = _CropParams(
        bytes,
        pixelRect.left.round(),
        pixelRect.top.round(),
        pixelRect.width.round(),
        pixelRect.height.round(),
      );
      final Uint8List? outBytes =
      await Isolate.run<Uint8List?>(() => _cropBytes(params));
      if (outBytes == null) return null;
      return _saveBytes(outBytes, 'cropped');
    } catch (e) {
      return null;
    }
  }

  /// Returns the decoded pixel dimensions of [imageFile], needed to convert
  /// an on-screen crop selection into real image pixel coordinates.
  static Future<Size?> getImageSize(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final dims = await Isolate.run<List<int>?>(() {
        final image = img.decodeImage(bytes);
        if (image == null) return null;
        return [image.width, image.height];
      });
      if (dims == null) return null;
      return Size(dims[0].toDouble(), dims[1].toDouble());
    } catch (e) {
      return null;
    }
  }

  // ── Core: read bytes → process in isolate → write file ──────
  static Future<File?> _run(
      File imageFile,
      String suffix,
      int op, [
        double value = 1.0,
      ]) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final params = _EnhanceParams(bytes, op, value);
      // Heavy work off the UI thread; only the encoded result comes back.
      final Uint8List? outBytes =
      await Isolate.run<Uint8List?>(() => _processBytes(params));
      if (outBytes == null) return null;
      return _saveBytes(outBytes, suffix);
    } catch (e) {
      return null;
    }
  }

  static Future<File> _saveBytes(Uint8List bytes, String suffix) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/enhanced_${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }
}