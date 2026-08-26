import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/providers/smart_memory_provider.dart';
import 'package:document_lens/providers/reminder_provider.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/providers/main_tab_provider.dart';
import 'package:document_lens/widgets/document_action_sheet.dart';
import 'package:document_lens/services/auto_naming_service.dart';
import 'package:document_lens/core/theme/app_theme.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/models/scan_memory_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final docProvider = context.watch<DocumentProvider>();
    final memoryProvider = context.watch<SmartMemoryProvider>();
    final reminderProvider = context.watch<ReminderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = authProvider.currentUser?.name ?? 'User';

    final today = DateTime.now();
    final todayScans = docProvider.documents
        .where((d) =>
    d.createdAt.day == today.day &&
        d.createdAt.month == today.month &&
        d.createdAt.year == today.year)
        .length;

    final reminderCount = reminderProvider.pendingReminders.length +
        reminderProvider.overdueReminders.length;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(),
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text(userName,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                      Text(
                          'Scan, organize & secure your documents',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  Row(
                    children: [
                      // Notification Bell with Badge
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, '/reminders'),
                        child: Stack(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2130)
                                    : Colors.white,
                                borderRadius:
                                BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.05),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                  Icons.notifications_rounded,
                                  size: 22),
                            ),
                            if (reminderCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$reminderCount',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight:
                                          FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppTheme.primaryBlue,
                            AppTheme.accentCyan
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Overdue Reminder Banner
              if (reminderProvider.overdueReminders.isNotEmpty) ...[
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/reminders'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${reminderProvider.overdueReminders.length} reminder${reminderProvider.overdueReminders.length > 1 ? 's' : ''} overdue!',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.red, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Total Documents',
                      value: '${docProvider.totalDocuments}',
                      icon: Icons.description_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _StatBox(
                      label: "Today's Scans",
                      value: '$todayScans',
                      icon: Icons.document_scanner_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: const _StatBox(
                      label: 'OCR Accuracy',
                      value: '98%',
                      icon: Icons.trending_up_rounded,
                      color: Colors.orange,
                      isAccuracy: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Extract Text Banner
              GestureDetector(
                onTap: () => _scanWithCamera(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryBlue,
                        AppTheme.accentCyan
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Extract Text',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 6),
                            Text(
                              'Capture any document and convert\nto digital text instantly',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.document_scanner_outlined,
                          color: Colors.white30, size: 64),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions
              const Text('Quick Actions',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      sublabel: 'Take a photo',
                      color: Colors.blue,
                      onTap: () => _scanWithCamera(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      sublabel: 'Choose image',
                      color: Colors.green,
                      onTap: () => _scanWithGallery(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Import PDF',
                      sublabel: 'From device',
                      color: Colors.red,
                      onTap: () => _importPdf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.book_rounded,
                      label: 'Notes',
                      sublabel: 'New note',
                      color: Colors.purple,
                      onTap: () =>
                          Navigator.pushNamed(context, '/notebook'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ✅ Smart Features — all 10 cards
              const Text('Smart Features',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _SmartFeatureCard(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy Blur',
                    sublabel: 'Hide sensitive info',
                    color: Colors.blue,
                    onTap: () => _pickDocumentForTool(
                        context, docProvider, '/privacy_blur'),
                  ),
                  _SmartFeatureCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Scan to Calendar',
                    sublabel: 'Detect dates & add reminder',
                    color: Colors.purple,
                    onTap: () => _pickDocumentForTool(
                        context, docProvider, '/scan_calendar'),
                  ),
                  _SmartFeatureCard(
                    icon: Icons.menu_book_rounded,
                    label: 'Digital Notebook',
                    sublabel: 'Organize notes smartly',
                    color: Colors.green,
                    onTap: () =>
                        Navigator.pushNamed(context, '/notebook'),
                  ),
                  _SmartFeatureCard(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Auto File Naming',
                    sublabel: 'Auto name files intelligently',
                    color: Colors.yellow,
                    onTap: () => _showAutoNamingInfo(context),
                  ),
                  _SmartFeatureCard(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Image Enhance',
                    sublabel: 'Brighten & sharpen scans',
                    color: Colors.orange,
                    onTap: () => _pickImageForTool(context, '/image_enhance'),
                  ),
                  _SmartFeatureCard(
                    icon: Icons.verified_rounded,
                    label: 'Quality Check',
                    sublabel: 'Check scan quality score',
                    color: Colors.red,
                    onTap: () => _pickImageForTool(context, '/quality_check'),
                  ),
                  // ✅ Edge Detection
                  _SmartFeatureCard(
                    icon: Icons.crop_free_rounded,
                    label: 'Edge Detection',
                    sublabel: 'Auto detect borders',
                    color: Colors.blueGrey,
                    onTap: () => _pickImageForTool(context, '/edge_detect'),
                  ),
                  // ✅ PDF Annotation
                  _SmartFeatureCard(
                    icon: Icons.edit_document,
                    label: 'PDF Annotate',
                    sublabel: 'Highlight & annotate',
                    color: Colors.grey,
                    onTap: () => _pickImageForTool(context, '/pdf_annotate'),
                  ),
                ],
              ),

              // Smart Memory Section
              if (memoryProvider.smartSuggestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology_rounded,
                            color: Colors.purple, size: 20),
                        SizedBox(width: 6),
                        Text('Frequently Scanned',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<MainTabProvider>().goToHistory(),
                      child: const Text('See All'),
                    ),
                  ],
                ),
                if (memoryProvider.categoryFrequency.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (memoryProvider.categoryFrequency
                          .entries
                          .toList()
                        ..sort((a, b) =>
                            b.value.compareTo(a.value)))
                          .map((entry) => Container(
                        margin:
                        const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple
                              .withValues(alpha: 0.1),
                          borderRadius:
                          BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.purple
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getCategoryIcon(entry.key),
                              style: const TextStyle(
                                  fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.purple,
                                )),
                          ],
                        ),
                      ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: memoryProvider.smartSuggestions.length,
                  itemBuilder: (context, index) {
                    final memory =
                    memoryProvider.smartSuggestions[index];
                    return _SmartMemoryCard(memory: memory);
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Recent Documents
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Documents',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () =>
                        context.read<MainTabProvider>().goToHistory(),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              docProvider.documents.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No documents yet.\nScan your first document!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docProvider.documents.length > 5
                    ? 5
                    : docProvider.documents.length,
                itemBuilder: (context, index) {
                  final doc = docProvider.documents[index];
                  return _RecentDocItem(document: doc);
                },
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '👋 Good Morning,';
    if (hour < 17) return '👋 Good Afternoon,';
    return '👋 Good Evening,';
  }

  Future<void> _scanWithCamera(BuildContext context) async {
    final ocrProvider = context.read<OcrProvider>();
    await ocrProvider.pickFromCamera();
    if (!context.mounted) return;
    if (ocrProvider.status == OcrStatus.done) {
      Navigator.pushNamed(context, '/result');
    } else if (ocrProvider.isObstructionError) {
      _showObstructionBlockedDialog(context, retry: () => _scanWithCamera(context));
    }
  }

  void _showAutoNamingInfo(BuildContext context) {
    // Real examples generated by the actual AutoNamingService
    final examples = <String, String>{
      'Physics homework with "Newton\'s laws of motion"':
      AutoNamingService.generateFileName(
          'Notes on Newton\'s laws of motion and force'),
      'Electricity bill mentioning "units consumed"':
      AutoNamingService.generateFileName(
          'Electricity bill - units consumed: 240 kWh'),
      'Aadhaar card scan':
      AutoNamingService.generateFileName(
          'Government of India Aadhaar Unique Identification Authority biometric'),
      'Resume / CV':
      AutoNamingService.generateFileName(
          'Resume - Career Objective, Skills, Experience'),
    };

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auto File Naming'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'When you scan a document, DOCMIND reads the '
                    'extracted text and automatically suggests a file name '
                    'based on what it detects:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...examples.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text('→ ${e.value}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange)),
                  ],
                ),
              )),
              const SizedBox(height: 4),
              const Text(
                'You can always rename a document after scanning.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanWithGallery(BuildContext context) async {
    final ocrProvider = context.read<OcrProvider>();
    await ocrProvider.pickFromGallery();
    if (!context.mounted) return;
    if (ocrProvider.status == OcrStatus.done) {
      Navigator.pushNamed(context, '/result');
    } else if (ocrProvider.isObstructionError) {
      _showObstructionBlockedDialog(context, retry: () => _scanWithGallery(context));
    }
  }

  // ✅ Shown when the obstruction check blocks a photo (finger/hand/object
  // covering the document) — instead of the normal flow, we stop before
  // OCR/navigation and tell the person to retake it.
  void _showObstructionBlockedDialog(BuildContext context,
      {required VoidCallback retry}) {
    final ocrProvider = context.read<OcrProvider>();
    final message = ocrProvider.errorMessage.isNotEmpty
        ? ocrProvider.errorMessage
        : 'Something is covering the document. Please retake the photo.';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Document Covered'),
        content: Text(message, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              retry();
            },
            child: const Text('Retake Photo'),
          ),
        ],
      ),
    );
  }

  /// Lets the user pick one of their scanned documents and opens the given
  /// route with that document's extracted text. Used by text-based Smart
  /// Feature tools (Privacy Blur, Scan to Calendar). If no documents exist
  /// yet, offers to scan one first.
  Future<void> _pickDocumentForTool(
      BuildContext context,
      DocumentProvider docProvider,
      String route,
      ) async {
    final documents = docProvider.documents;

    if (documents.isEmpty) {
      final shouldScan = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No Documents Yet'),
          content: const Text(
              'Scan a document first so this tool can analyze its text.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Scan Now'),
            ),
          ],
        ),
      );
      if (shouldScan == true && context.mounted) {
        await _scanWithCamera(context);
      }
      return;
    }

    if (!context.mounted) return;

    final selected = await showModalBottomSheet<DocumentModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
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
              const Text('Choose a Document',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Select which document to analyze',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final doc = documents[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: doc.imagePath.isNotEmpty &&
                            File(doc.imagePath).existsSync()
                            ? Image.file(File(doc.imagePath),
                            width: 44, height: 44, fit: BoxFit.cover)
                            : Container(
                          width: 44,
                          height: 44,
                          color: Colors.blue.withValues(alpha: 0.1),
                          child: const Icon(Icons.description_rounded,
                              color: Colors.blue),
                        ),
                      ),
                      title: Text(doc.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(doc.category,
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.pop(sheetContext, doc),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && context.mounted) {
      Navigator.pushNamed(context, route,
          arguments: selected.extractedText);
    }
  }

  /// Lets the user pick an image (camera or gallery) and opens the given
  /// route with that image as the argument. Used by Smart Feature tools
  /// (Image Enhance, Quality Check, Edge Detection, PDF Annotate) that
  /// operate directly on an image without requiring OCR first.
  Future<void> _pickImageForTool(BuildContext context, String route) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return; // user cancelled

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return; // user cancelled picker

      if (context.mounted) {
        Navigator.pushNamed(context, route, arguments: File(picked.path));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importPdf(BuildContext context) async {
    bool dialogShown = false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return; // user cancelled
      }

      final pdfFile = File(result.files.single.path!);

      if (!context.mounted) return;

      // Show loading dialog while converting PDF page to an image
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Converting PDF page...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Rasterize the first page of the PDF to an image
      final pages = Printing.raster(
        await pdfFile.readAsBytes(),
        pages: const [0],
        dpi: 200,
      );

      final page = await pages.first;
      final pngBytes = await page.toPng();

      final tempDir = await getTemporaryDirectory();
      final imagePath =
          '${tempDir.path}/pdf_page_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
      dialogShown = false;

      // Run OCR on the rasterized page, same as camera/gallery flow
      final ocrProvider = context.read<OcrProvider>();
      await ocrProvider.processImageFromPath(imagePath);

      if (context.mounted && ocrProvider.status == OcrStatus.done) {
        Navigator.pushNamed(context, '/result');
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                ocrProvider.errorMessage.isNotEmpty
                    ? ocrProvider.errorMessage
                    : 'Could not extract text from PDF.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (dialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

String _getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'notes':
      return '📝';
    case 'receipt':
      return '🧾';
    case 'id card':
      return '🪪';
    case 'letter':
      return '📄';
    default:
      return '📁';
  }
}

class _SmartMemoryCard extends StatelessWidget {
  final ScanMemoryModel memory;
  const _SmartMemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: Colors.purple.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_rounded,
                color: Colors.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memory.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(memory.category,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Scanned ${memory.scanCount}x',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.purple,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(_timeAgo(memory.lastScanned),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isAccuracy;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isAccuracy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color)),
              if (isAccuracy)
                const Icon(Icons.trending_up_rounded,
                    color: Colors.green, size: 14),
            ],
          ),
          Text(label,
              textAlign: TextAlign.center,
              style:
              const TextStyle(fontSize: 9, color: Colors.grey),
              maxLines: 2),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            SizedBox(
              height: 24,
              child: Text(sublabel,
                  style: const TextStyle(
                      fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartFeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _SmartFeatureCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: color)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.grey),
                      maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentDocItem extends StatelessWidget {
  final DocumentModel document;
  const _RecentDocItem({required this.document});

  String _fileTypeLabel() {
    final path = document.imagePath.toLowerCase();
    if (path.endsWith('.pdf')) return 'PDF';
    if (path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg')) {
      return 'Image';
    }
    return 'Scan';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => showDocumentActionSheet(context, document),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: document.imagePath.isNotEmpty &&
                  File(document.imagePath).existsSync()
                  ? Image.file(File(document.imagePath),
                  width: 44, height: 44, fit: BoxFit.cover)
                  : Container(
                width: 44,
                height: 44,
                color: Colors.blue.withValues(alpha: 0.1),
                child: const Icon(Icons.description_rounded,
                    color: Colors.blue, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(document.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${document.category} • ${_fileTypeLabel()}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatDate(document.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey)),
                const Icon(Icons.more_vert_rounded,
                    color: Colors.grey, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day} ${_month(date.month)}';
  }

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}