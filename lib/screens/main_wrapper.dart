import 'package:flutter/material.dart';
import 'package:document_lens/screens/home/home_screen.dart';
import 'package:document_lens/screens/history/history_screen.dart';
import 'package:document_lens/screens/settings/settings_screen.dart';
import 'package:document_lens/screens/insights/insights_screen.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:provider/provider.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    InsightsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.insights_rounded,
                  label: 'Insights',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _ScanFAB(
                  onCamera: () async {
                    final ocrProvider = context.read<OcrProvider>();
                    await ocrProvider.pickFromCamera();
                    if (!context.mounted) return;
                    if (ocrProvider.status == OcrStatus.done) {
                      Navigator.pushNamed(context, '/result');
                    } else if (ocrProvider.isObstructionError) {
                      _showObstructionBlockedDialog(context,
                          errorMessage: ocrProvider.errorMessage);
                    }
                  },
                  onGallery: () async {
                    final ocrProvider = context.read<OcrProvider>();
                    await ocrProvider.pickFromGallery();
                    if (!context.mounted) return;
                    if (ocrProvider.status == OcrStatus.done) {
                      Navigator.pushNamed(context, '/result');
                    } else if (ocrProvider.isObstructionError) {
                      _showObstructionBlockedDialog(context,
                          errorMessage: ocrProvider.errorMessage);
                    }
                  },
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Shown when the obstruction check blocks a photo (finger/hand/object
  // covering the document) instead of letting a bad scan through.
  void _showObstructionBlockedDialog(BuildContext context,
      {required String errorMessage}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('⚠️ Document Covered'),
        content: Text(
          errorMessage.isNotEmpty
              ? errorMessage
              : 'Something is covering the document. Please retake the photo.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A73E8).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF1A73E8)
                  : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF1A73E8)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFAB extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _ScanFAB({
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showScanOptions(context),
      onLongPress: () => _showLanguageSelector(context), // ✅ Long press
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A73E8), Color(0xFF00BCD4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.document_scanner_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  // ✅ Only languages that ACTUALLY work (no fake fallbacks)
  // ML Kit on-device: Devanagari + CJK + Latin. Tamil: Tesseract (offline).
  static const List<Map<String, String>> _languages = [
    // Indian Languages
    {'code': 'tamil',     'name': 'Tamil',    'flag': '🇮🇳', 'group': 'Indian'},
    {'code': 'hindi',     'name': 'Hindi',    'flag': '🇮🇳', 'group': 'Indian'},
    {'code': 'marathi',   'name': 'Marathi',  'flag': '🇮🇳', 'group': 'Indian'},
    {'code': 'sanskrit',  'name': 'Sanskrit', 'flag': '🇮🇳', 'group': 'Indian'},
    {'code': 'nepali',    'name': 'Nepali',   'flag': '🇳🇵', 'group': 'Indian'},
    // International
    {'code': 'english',   'name': 'English',  'flag': '🇬🇧', 'group': 'International'},
    {'code': 'chinese',   'name': 'Chinese',  'flag': '🇨🇳', 'group': 'International'},
    {'code': 'japanese',  'name': 'Japanese', 'flag': '🇯🇵', 'group': 'International'},
    {'code': 'korean',    'name': 'Korean',   'flag': '🇰🇷', 'group': 'International'},
    {'code': 'french',    'name': 'French',   'flag': '🇫🇷', 'group': 'International'},
    {'code': 'german',    'name': 'German',   'flag': '🇩🇪', 'group': 'International'},
    {'code': 'spanish',   'name': 'Spanish',  'flag': '🇪🇸', 'group': 'International'},
  ];

  void _showLanguageSelector(BuildContext context) {
    final ocrProvider = context.read<OcrProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    const Text('🌐',
                        style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select OCR Language',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Long press scanner to change language',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Indian Languages
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Text('🇮🇳',
                                  style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text('Indian Languages',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.orange)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: _languages
                              .where((l) => l['group'] == 'Indian')
                              .map((lang) => _buildLangCard(
                            lang,
                            ocrProvider,
                            setModalState,
                            ctx,
                          ))
                              .toList(),
                        ),

                        const SizedBox(height: 20),

                        // ✅ International Languages
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Text('🌍',
                                  style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text('International Languages',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.blue)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: _languages
                              .where(
                                  (l) => l['group'] == 'International')
                              .map((lang) => _buildLangCard(
                            lang,
                            ocrProvider,
                            setModalState,
                            ctx,
                          ))
                              .toList(),
                        ),

                        const SizedBox(height: 16),

                        // Info box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('💡',
                                  style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hindi, Marathi, Sanskrit → Devanagari script\nBengali, Assamese, Manipuri → Bengali script\nOther Indian languages → Latin fallback',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done'),
                          ),
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLangCard(
      Map<String, String> lang,
      OcrProvider ocrProvider,
      StateSetter setModalState,
      BuildContext context,
      ) {
    final isSelected = ocrProvider.selectedLanguage == lang['code'];
    return GestureDetector(
      onTap: () {
        ocrProvider.setLanguage(lang['code']!);
        setModalState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${lang['flag']} ${lang['name']} selected!'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : Colors.blue.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(lang['flag']!,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              lang['name']!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.blue,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan Document',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Camera + Gallery
            Row(
              children: [
                Expanded(
                  child: _ScanOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF1A73E8),
                    onTap: () {
                      Navigator.pop(context);
                      onCamera();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScanOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF00897B),
                    onTap: () {
                      Navigator.pop(context);
                      onGallery();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Camera Stabilizer
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/camera_stabilizer');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.motion_photos_auto_rounded,
                        color: Colors.purple, size: 22),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Stabilizer',
                            style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text('Auto capture when stable',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Language selector shortcut
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showLanguageSelector(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language_rounded,
                        color: Colors.teal, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Language',
                            style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Text(
                          'Long press scanner to change',
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}