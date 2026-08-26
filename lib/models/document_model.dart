import 'package:hive/hive.dart';
import 'package:document_lens/services/privacy_blur_service.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String extractedText;

  @HiveField(3)
  final String imagePath;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String language;

  // Added fields expected by providers and UI
  @HiveField(6)
  String category;

  @HiveField(7)
  bool isFavourite;

  @HiveField(8)
  bool isPinned;

  // ✅ Manual highlights, persisted per document — flattened character-offset
  // ranges [start0, end0, start1, end1, ...] into `extractedText`, so a
  // drag-selected portion of text is highlighted, not a whole line.
  @HiveField(9)
  List<int> highlights;

  // ✅ Firebase Storage download URL for the scanned image, once uploaded.
  // null until the document has synced to the cloud at least once.
  @HiveField(10)
  String? imageUrl;

  // ✅ Privacy Blur — which sensitive-info types the user chose to hide for
  // THIS document, persisted so the blur applies everywhere the document's
  // text is shown (home list, notebook, full viewer, search), not just the
  // Privacy Blur screen itself. Empty = no blur active. `extractedText`
  // itself is never overwritten, so search/reminders/scan-calendar still
  // work off the real text — only display reads go through [displayText].
  @HiveField(11)
  List<String> blurredTypes;

  DocumentModel({
    required this.id,
    required this.title,
    required this.extractedText,
    required this.imagePath,
    required this.createdAt,
    required this.language,
    this.category = 'Other',
    this.isFavourite = false,
    this.isPinned = false,
    this.highlights = const <int>[],
    this.imageUrl,
    this.blurredTypes = const <String>[],
  });

  /// True if this document currently has any Privacy Blur types active.
  bool get hasPrivacyBlur => blurredTypes.isNotEmpty;

  /// The text to actually SHOW in the UI. Same length as [extractedText]
  /// (masked spans keep their original length, whitespace preserved) so
  /// anything indexed by character offset — like saved [highlights] — still
  /// lines up correctly. Falls back to [extractedText] untouched when no
  /// blur is active.
  String get displayText {
    if (blurredTypes.isEmpty) return extractedText;
    final items = PrivacyBlurService.detectSensitiveInfo(extractedText)
        .where((i) => blurredTypes.contains(i.type))
        .toList();
    if (items.isEmpty) return extractedText;
    return PrivacyBlurService.applyPrivacyBlurPreserveLength(
        extractedText, items);
  }

  DocumentModel copyWith({
    String? title,
    String? extractedText,
    String? category,
    bool? isFavourite,
    bool? isPinned,
    List<int>? highlights,
    String? imageUrl,
    List<String>? blurredTypes,
  }) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      extractedText: extractedText ?? this.extractedText,
      imagePath: imagePath,
      createdAt: createdAt,
      language: language,
      category: category ?? this.category,
      isFavourite: isFavourite ?? this.isFavourite,
      isPinned: isPinned ?? this.isPinned,
      highlights: highlights ?? this.highlights,
      imageUrl: imageUrl ?? this.imageUrl,
      blurredTypes: blurredTypes ?? this.blurredTypes,
    );
  }

  /// ✅ For syncing to Firestore. imagePath (a local file path) is
  /// intentionally excluded — only imageUrl (cloud) is meaningful remotely.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'extractedText': extractedText,
      'createdAt': createdAt.toIso8601String(),
      'language': language,
      'category': category,
      'isFavourite': isFavourite,
      'isPinned': isPinned,
      'highlights': highlights,
      'imageUrl': imageUrl,
      'blurredTypes': blurredTypes,
    };
  }

  /// ✅ Rebuilds a DocumentModel from a Firestore document snapshot.
  /// [localImagePath] is filled in separately once the image is
  /// downloaded/cached locally (empty until then).
  factory DocumentModel.fromFirestoreMap(
      Map<String, dynamic> map, {
        String localImagePath = '',
      }) {
    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      extractedText: map['extractedText'] as String? ?? '',
      imagePath: localImagePath,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      language: map['language'] as String? ?? 'english',
      category: map['category'] as String? ?? 'Other',
      isFavourite: map['isFavourite'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      highlights: (map['highlights'] as List?)?.cast<int>() ?? const <int>[],
      imageUrl: map['imageUrl'] as String?,
      blurredTypes:
      (map['blurredTypes'] as List?)?.cast<String>() ?? const <String>[],
    );
  }
}