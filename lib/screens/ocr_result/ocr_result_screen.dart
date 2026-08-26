import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/providers/smart_memory_provider.dart';
import 'package:document_lens/providers/notebook_provider.dart';
import 'package:document_lens/models/notebook_model.dart';
import 'package:document_lens/services/auto_naming_service.dart';
import 'package:document_lens/core/constants/app_constants.dart';

class OcrResultScreen extends StatefulWidget {
  const OcrResultScreen({super.key});

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  late TextEditingController _textController;
  late TextEditingController _titleController;
  late OcrProvider _ocrProvider;
  String _selectedCategory = 'Other';
  String _suggestedName = '';
  // Privacy Blur types chosen before this scan is saved (no DocumentModel
  // exists yet to persist to) — applied once _saveToHistory() creates it.
  List<String> _pendingBlurTypes = const [];
  // ✅ NEW: guards the auto-name suggestion so it only fires once per
  // scan (right when THIS photo's OCR finishes), not again every time
  // the displayed text later changes because of a language-selector
  // translation.
  bool _namedForCurrentScan = false;

  int get _wordCount => _textController.text.trim().isEmpty
      ? 0
      : _textController.text.trim().split(RegExp(r'\s+')).length;
  int get _charCount => _textController.text.length;
  int get _lineCount => _textController.text.trim().isEmpty
      ? 0
      : _textController.text.trim().split('\n').length;

  @override
  void initState() {
    super.initState();
    _ocrProvider = context.read<OcrProvider>();
    _textController =
        TextEditingController(text: _ocrProvider.displayText);
    // ✅ Default name is sequential — "Document 1", "Document 2"... —
    // simple and predictable. User can edit it, or tap ✨ for a smart
    // content-based suggestion instead.
    final existingCount = context.read<DocumentProvider>().totalDocuments;
    _suggestedName = AutoNamingService.generateSequentialName(existingCount);
    _titleController = TextEditingController(text: _suggestedName);
    // If OCR is already done by the time this screen builds (the normal
    // case — scan happens before navigation), the name has effectively
    // already been "assigned" above; only let a LATER genuine re-scan
    // regenerate it.
    if (_ocrProvider.status == OcrStatus.done) {
      _namedForCurrentScan = true;
    }
    _textController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
    // Re-run when the OcrProvider notifies (new OCR result, translation
    // finishing, or an error).
    _ocrProvider.addListener(_onOcrChanged);
  }

  void _onOcrChanged() {
    if (!mounted) return;

    // Keep the visible text in sync with whatever should currently be
    // shown — the raw OCR text, or a translation if the person picked a
    // different language on the selector (or used the Tamil card).
    if (_ocrProvider.displayText != _textController.text) {
      _textController.text = _ocrProvider.displayText;
    }

    // Auto-suggest a document name once, right when THIS photo's OCR
    // finishes — not on every later translation/display-language change.
    if (_ocrProvider.status == OcrStatus.done && !_namedForCurrentScan) {
      _namedForCurrentScan = true;
      if (_titleController.text == _suggestedName) {
        final existingCount = context.read<DocumentProvider>().totalDocuments;
        _suggestedName = AutoNamingService.generateSequentialName(existingCount);
        _titleController.text = _suggestedName;
      }
    } else if (_ocrProvider.status == OcrStatus.error) {
      // ✅ A failed scan/re-scan used to leave the OLD text sitting in the
      // box with zero indication anything went wrong. Surface the real
      // error now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _ocrProvider.errorMessage.isNotEmpty
                  ? _ocrProvider.errorMessage
                  : 'Could not scan this photo. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
    setState(() {}); // reflect processing / translating / done state
  }

  // Language selector shown on the result screen: pick a language to
  // TRANSLATE the extracted text into it (does not re-scan the photo).
  Widget _buildLanguageSelector() {
    final isTranslating =
        _ocrProvider.translationStatus == TranslationStatus.translating;
    final current = _ocrProvider.targetLanguage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Language',
                style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 8),
            if (_ocrProvider.usedGroqForLastScan)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.3)),
                ),
                child: const Text('⚡ AI OCR (Groq)',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 8),
            if (isTranslating)
              Row(
                children: const [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text('Translating…',
                      style: TextStyle(fontSize: 11.5, color: Colors.blue)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap a language to translate the extracted text into it',
          style: TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppConstants.supportedLanguages.map((lang) {
              final code = lang['code']!;
              final name = lang['name']!;
              final selected = code == current;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: isTranslating
                      ? null
                      : (_) => _ocrProvider.changeDisplayLanguage(code),
                ),
              );
            }).toList(),
          ),
        ),
        if (_ocrProvider.translationStatus == TranslationStatus.error &&
            _ocrProvider.targetLanguage != _ocrProvider.selectedLanguage)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _ocrProvider.translationError,
              style: const TextStyle(fontSize: 11.5, color: Colors.red),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  void dispose() {
    _ocrProvider.removeListener(_onOcrChanged);
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _regenerateName() {
    final newName =
    AutoNamingService.generateFileName(_textController.text);
    setState(() {
      _suggestedName = newName;
      _titleController.text = newName;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_fix_high_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Auto named: $newName'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _effectiveTitle {
    final trimmed = _titleController.text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final now = DateTime.now();
    return 'Document_${now.day}_${now.month}_${now.year}';
  }

  Future<void> _saveAsPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      // ✅ MultiPage instead of Page — Page has a fixed single-page size and
      // silently fails to render content that overflows it (this was
      // causing the exported PDF to look blank for longer scans).
      // MultiPage automatically paginates across as many pages as needed.
      pw.MultiPage(
        build: (context) => [
          pw.Text(_effectiveTitle,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text(_textController.text),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _saveAsText() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$_effectiveTitle.txt');
    await file.writeAsString(_textController.text);
    // ✅ share_plus 12.x — new SharePlus API (old Share.shareXFiles still
    // works but is deprecated).
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: _effectiveTitle),
    );
  }

  // ── Share to WhatsApp / Gmail / other apps ──────────────────
  Future<void> _shareDocument() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text to share'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Share document',
                  style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.red),
              title: const Text('Share as PDF'),
              subtitle: const Text('WhatsApp, Gmail, Drive…'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _sharePdf();
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.short_text_rounded, color: Colors.blue),
              title: const Text('Share as text'),
              subtitle: const Text('Send the extracted text as a message'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _shareText();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      // ✅ Same MultiPage fix as _saveAsPdf().
      pw.MultiPage(
        build: (context) => [
          pw.Text(_effectiveTitle,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text(_textController.text),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final safe = _effectiveTitle.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
    final file = File('${dir.path}/${safe.isEmpty ? 'document' : safe}.pdf');
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: _effectiveTitle),
    );
  }

  Future<void> _shareText() async {
    await SharePlus.instance.share(
      ShareParams(text: _textController.text, subject: _effectiveTitle),
    );
  }

  /// Opens Privacy Blur for this not-yet-saved scan. Since there's no
  /// DocumentModel to persist to yet, the chosen types come back via the
  /// route result and are applied once the doc is actually saved.
  Future<void> _openPrivacyBlur() async {
    final result = await Navigator.pushNamed<List<String>>(
      context,
      '/privacy_blur',
      arguments: _textController.text,
    );
    if (result != null) {
      setState(() => _pendingBlurTypes = result);
    }
  }

  Future<void> _saveToHistory() async {
    final ocrProvider = context.read<OcrProvider>();
    final docProvider = context.read<DocumentProvider>();
    final memoryProvider = context.read<SmartMemoryProvider>();

    await docProvider.saveDocument(
      title: _effectiveTitle,
      extractedText: _textController.text,
      imagePath: ocrProvider.selectedImage?.path ?? '',
      language: ocrProvider.selectedLanguage,
      category: _selectedCategory,
      blurredTypes: _pendingBlurTypes,
    );

    await memoryProvider.trackScan(
      documentId: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _effectiveTitle,
      category: _selectedCategory,
      imagePath: ocrProvider.selectedImage?.path ?? '',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to history!'),
          backgroundColor: Colors.green,
        ),
      );
      ocrProvider.reset();
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  /// Saves the extracted text as a note in the Digital Notebook.
  /// Lets the user pick an existing subject or create a new one.
  Future<void> _saveToNotebook(BuildContext context) async {
    final notebookProvider = context.read<NotebookProvider>();

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No extracted text to save!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedSubject = await showModalBottomSheet<SubjectModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Save to Notebook',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Choose a subject for this note',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: notebookProvider.subjects.length,
                  itemBuilder: (context, index) {
                    final subject = notebookProvider.subjects[index];
                    final color =
                    Color(NotebookProvider.colorFromHex(subject.colorHex));
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(subject.emoji,
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      title: Text(subject.name),
                      onTap: () => Navigator.pop(sheetContext, subject),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedSubject == null || !context.mounted) return;

    await notebookProvider.addNote(
      subjectId: selectedSubject.id,
      title: _effectiveTitle,
      content: _textController.text,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Saved to ${selectedSubject.name}!'),
            ],
          ),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrProvider = context.read<OcrProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracted Text'),
        actions: [
          // Quality Check
          IconButton(
            icon: const Icon(Icons.verified_rounded,
                color: Colors.indigo),
            tooltip: 'Quality Check',
            onPressed: () {
              if (ocrProvider.selectedImage != null) {
                Navigator.pushNamed(context, '/quality_check',
                    arguments: ocrProvider.selectedImage!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No image to check!'),
                      backgroundColor: Colors.red),
                );
              }
            },
          ),
          // Image Enhance
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded,
                color: Colors.purple),
            tooltip: 'Enhance Image',
            onPressed: () {
              if (ocrProvider.selectedImage != null) {
                Navigator.pushNamed(context, '/image_enhance',
                    arguments: ocrProvider.selectedImage!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No image to enhance!'),
                      backgroundColor: Colors.red),
                );
              }
            },
          ),
          // Privacy Blur
          IconButton(
            icon: const Icon(Icons.privacy_tip_rounded,
                color: Colors.blue),
            tooltip: 'Privacy Blur',
            onPressed: () => _openPrivacyBlur(),
          ),
          // Scan to Calendar
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: Colors.green),
            tooltip: 'Scan to Calendar',
            onPressed: () => Navigator.pushNamed(
                context, '/scan_calendar',
                arguments: _textController.text),
          ),
          // Reminder
          IconButton(
            icon: const Icon(Icons.notification_add_rounded,
                color: Colors.orange),
            tooltip: 'Set Reminder',
            onPressed: () => Navigator.pushNamed(context, '/reminders',
                arguments: _titleController.text),
          ),
          // Copy
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: _textController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ocrProvider.selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    ocrProvider.selectedImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 16),

              // Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                        label: 'Words',
                        value: '$_wordCount',
                        icon: Icons.text_fields_rounded),
                    _StatChip(
                        label: 'Chars',
                        value: '$_charCount',
                        icon: Icons.abc_rounded),
                    _StatChip(
                        label: 'Lines',
                        value: '$_lineCount',
                        icon: Icons.format_list_numbered_rounded),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ✅ Quick Feature Banners — 4x2 grid (8 features)
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.0,
                children: [
                  _FeatureBanner(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy Blur',
                    sublabel: 'Hide sensitive info',
                    color: Colors.blue,
                    onTap: () => _openPrivacyBlur(),
                  ),
                  _FeatureBanner(
                    icon: Icons.calendar_today_rounded,
                    label: 'Scan Calendar',
                    sublabel: 'Detect dates',
                    color: Colors.green,
                    onTap: () => Navigator.pushNamed(
                        context, '/scan_calendar',
                        arguments: _textController.text),
                  ),
                  _FeatureBanner(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Enhance Image',
                    sublabel: 'Improve quality',
                    color: Colors.purple,
                    onTap: () {
                      if (ocrProvider.selectedImage != null) {
                        Navigator.pushNamed(context, '/image_enhance',
                            arguments: ocrProvider.selectedImage!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No image to enhance!'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                  _FeatureBanner(
                    icon: Icons.notification_add_rounded,
                    label: 'Set Reminder',
                    sublabel: 'Add reminder',
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/reminders',
                        arguments: _titleController.text),
                  ),
                  _FeatureBanner(
                    icon: Icons.verified_rounded,
                    label: 'Quality Check',
                    sublabel: 'Check scan score',
                    color: Colors.indigo,
                    onTap: () {
                      if (ocrProvider.selectedImage != null) {
                        Navigator.pushNamed(context, '/quality_check',
                            arguments: ocrProvider.selectedImage!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No image to check!'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                  _FeatureBanner(
                    icon: Icons.menu_book_rounded,
                    label: 'Notebook',
                    sublabel: 'Save to notebook',
                    color: Colors.deepPurple,
                    onTap: () => _saveToNotebook(context),
                  ),
                  // ✅ NEW - Edge Detection banner
                  _FeatureBanner(
                    icon: Icons.crop_free_rounded,
                    label: 'Edge Detection',
                    sublabel: 'Detect borders',
                    color: Colors.cyan,
                    onTap: () {
                      if (ocrProvider.selectedImage != null) {
                        Navigator.pushNamed(context, '/edge_detect',
                            arguments: ocrProvider.selectedImage!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('No image for edge detection!'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                  // ✅ NEW - PDF Annotation banner
                  _FeatureBanner(
                    icon: Icons.edit_document,
                    label: 'PDF Annotate',
                    sublabel: 'Highlight & annotate',
                    color: Colors.amber,
                    onTap: () {
                      if (ocrProvider.selectedImage != null) {
                        Navigator.pushNamed(context, '/pdf_annotate',
                            arguments: ocrProvider.selectedImage!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('No image to annotate!'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Auto File Name
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high_rounded,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 6),
                        const Text('Auto File Name',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: _regenerateName,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Regenerate',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('$_suggestedName.pdf',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          if (_titleController.text == _suggestedName)
                            Tooltip(
                              message: 'Suggestion applied',
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _titleController.text = _suggestedName;
                                });
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content:
                                  Text('Auto name applied!'),
                                  backgroundColor: Colors.green,
                                ));
                              },
                              child: const Tooltip(
                                message: 'Apply this name to the title',
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Title
              const Text('Document Title',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Document title...',
                  prefixIcon: const Icon(Icons.title_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_fix_high_rounded,
                        color: Colors.green),
                    tooltip: 'Auto generate name',
                    onPressed: _regenerateName,
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 12),

              // Category
              const Text('Category',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DocumentProvider.categories
                      .where((c) => c != 'All')
                      .map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // Language selector (translate the extracted text)
              _buildLanguageSelector(),

              // No data / blank page notice
              if (_textController.text.trim().isEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No data found',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.orange)),
                            SizedBox(height: 4),
                            Text(
                                'This page looks blank — no readable text '
                                    'was detected. Try a clearer photo, better '
                                    'lighting, or the right language.',
                                style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Extracted Text
              const Text('Extracted Text',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: null,
                minLines: 8,
                decoration: InputDecoration(
                  hintText: 'Extracted text will appear here...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),

              const SizedBox(height: 20),
              const _TamilTranslationSection(),

              const SizedBox(height: 20),

              // Export
              const Text('Export / Save',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Save PDF',
                      color: Colors.red,
                      onTap: _saveAsPdf,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.text_snippet_rounded,
                      label: 'Share TXT',
                      color: Colors.orange,
                      onTap: _saveAsText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded, color: Colors.green),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _shareDocument,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save to History'),
                  onPressed: _saveToHistory,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _FeatureBanner({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 11)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 18)),
        Text(label,
            style:
            const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

/// "Scan only" vs "Scan + Translate to Tamil" — this card lets the person
/// optionally translate the extracted text into Tamil regardless of the
/// document's original language. Kept as its own card (not mixed into the
/// editable extracted-text field above) so editing OCR text and viewing
/// its Tamil translation don't interfere with each other.
class _TamilTranslationSection extends StatelessWidget {
  const _TamilTranslationSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<OcrProvider>(
      builder: (context, ocrProvider, _) {
        final status = ocrProvider.translationStatus;
        final isTamilSource = ocrProvider.selectedLanguage == 'tamil';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate_rounded,
                      color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Tamil Translation',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  if (status == TranslationStatus.done)
                    Switch(
                      value: ocrProvider.showTranslation,
                      activeColor: Colors.teal,
                      onChanged: (v) => ocrProvider.toggleShowTranslation(v),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (isTamilSource)
                const Text(
                  'Already scanned in Tamil — no translation needed.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else if (status == TranslationStatus.idle)
                Text(
                  'Get this text in Tamil, whatever language it was scanned in.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                )
              else if (status == TranslationStatus.error)
                  Text(
                    ocrProvider.translationError,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),

              if (status == TranslationStatus.done) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ocrProvider.translatedText.isEmpty
                        ? '—'
                        : ocrProvider.translatedText,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ],

              if (!isTamilSource) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: status == TranslationStatus.translating
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.teal),
                    )
                        : const Icon(Icons.translate_rounded,
                        color: Colors.teal),
                    label: Text(
                      status == TranslationStatus.translating
                          ? 'Translating…'
                          : status == TranslationStatus.done
                          ? 'Re-translate'
                          : 'Translate to Tamil',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: status == TranslationStatus.translating
                        ? null
                        : () => ocrProvider.translateToTamil(),
                  ),
                ),
                if (status == TranslationStatus.idle)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'First translation needs internet (downloads the language model once); works offline after that.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}