import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/services/privacy_blur_service.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/providers/document_provider.dart';

class PrivacyBlurScreen extends StatefulWidget {
  final String extractedText;

  /// The saved document this text belongs to, if any. When present, the
  /// user's blur choice is PERSISTED to it (via [DocumentProvider]) so the
  /// blur shows up everywhere the document is displayed in the app — home
  /// list, notebook, full viewer — not just this screen. When null (a
  /// fresh scan that hasn't been saved yet), the choice can't be persisted
  /// yet, so it's returned via [Navigator.pop] instead for the caller to
  /// apply once the document is actually saved.
  final DocumentModel? document;

  const PrivacyBlurScreen({
    super.key,
    required this.extractedText,
    this.document,
  });

  @override
  State<PrivacyBlurScreen> createState() => _PrivacyBlurScreenState();
}

class _PrivacyBlurScreenState extends State<PrivacyBlurScreen> {
  late String _originalText;
  late String _processedText;
  List<SensitiveInfo> _detectedItems = [];
  Map<String, bool> _selectedTypes = {};
  bool _blurApplied = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _originalText = widget.extractedText;
    // If this document already has a persisted blur, reflect that
    // immediately instead of showing the raw text for a moment.
    final existing = widget.document?.blurredTypes ?? const <String>[];
    _blurApplied = existing.isNotEmpty;
    _processedText = widget.document?.displayText ?? widget.extractedText;
    _scanForSensitiveInfo(preSelected: existing);
  }

  Future<void> _scanForSensitiveInfo({List<String> preSelected = const []}) async {
    setState(() => _isScanning = true);

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 600));

    final detected =
    PrivacyBlurService.detectSensitiveInfo(_originalText);

    // Initialize types as selected: use the document's already-persisted
    // choice if it has one, otherwise default to "all selected".
    final types = <String>{};
    for (final item in detected) {
      types.add(item.type);
    }
    final selectedTypes = preSelected.isNotEmpty
        ? {for (final t in types) t: preSelected.contains(t)}
        : {for (final t in types) t: true};

    setState(() {
      _detectedItems = detected;
      _selectedTypes = selectedTypes;
      _isScanning = false;
    });
  }

  void _applyBlur() {
    // Only blur selected types
    final selectedTypeNames =
    _selectedTypes.entries.where((e) => e.value).map((e) => e.key).toList();
    final toBlur = _detectedItems
        .where((item) => _selectedTypes[item.type] == true)
        .toList();

    setState(() {
      _processedText =
          PrivacyBlurService.applyPrivacyBlur(_originalText, toBlur);
      _blurApplied = true;
    });

    final document = widget.document;
    if (document != null) {
      // Saved document — persist so the blur applies app-wide.
      context.read<DocumentProvider>().setPrivacyBlur(document, selectedTypeNames);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.privacy_tip_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(document != null
                ? '${toBlur.length} sensitive items hidden everywhere!'
                : '${toBlur.length} sensitive items hidden!'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _removeBlur() {
    setState(() {
      _processedText = _originalText;
      _blurApplied = false;
    });

    final document = widget.document;
    if (document != null) {
      context.read<DocumentProvider>().setPrivacyBlur(document, const []);
    }
  }

  /// The currently-selected blur types, or empty if blur isn't applied.
  /// Used to hand the choice back to the caller in the pre-save flow.
  List<String> _selectedTypesForResult() {
    if (!_blurApplied) return const [];
    return _selectedTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Blur'),
        // Pre-save flow (no document yet): hand the chosen blur types back
        // to the caller on the way out so they can be applied once the
        // document is actually saved. Saved-document flow already
        // persists on every Apply/Remove, so the default back is fine.
        leading: widget.document == null
            ? BackButton(
          onPressed: () => Navigator.pop(context, _selectedTypesForResult()),
        )
            : null,
        actions: [
          // Copy blurred text
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy text',
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: _processedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Copied!'),
                    backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
      body: _isScanning
          ? _buildScanningUI()
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              _buildStatusBanner(),

              const SizedBox(height: 16),

              // Detected Items
              if (_detectedItems.isNotEmpty) ...[
                const Text(
                  'Sensitive Info Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select which info to hide before sharing',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                ..._buildDetectedList(),
                const SizedBox(height: 16),
              ] else ...[
                // No sensitive info found
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                        Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Sensitive Info Found!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'This document appears safe to share.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (_detectedItems.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(
                            Icons.privacy_tip_rounded,
                            size: 18),
                        label: Text(_blurApplied
                            ? 'Re-apply Blur'
                            : 'Apply Privacy Blur'),
                        onPressed: _applyBlur,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_blurApplied) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(
                            Icons.visibility_rounded),
                        tooltip: 'Show original',
                        onPressed: _removeBlur,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Text Preview
              const Text(
                'Text Preview',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),

              // Before/After toggle
              if (_blurApplied) ...[
                Row(
                  children: [
                    _PreviewToggle(
                      label: 'Blurred',
                      icon: Icons.lock_rounded,
                      color: Colors.blue,
                      isActive: true,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removeBlur,
                      child: _PreviewToggle(
                        label: 'Original',
                        icon: Icons.lock_open_rounded,
                        color: Colors.grey,
                        isActive: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2130)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _blurApplied
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_blurApplied)
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded,
                              color: Colors.blue, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            'Privacy Protected',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue
                                  .withValues(alpha: 0.1),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🔒 Blurred',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    if (_blurApplied)
                      const SizedBox(height: 10),
                    Text(
                      _processedText,
                      style: const TextStyle(
                          fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.privacy_tip_rounded,
                color: Colors.blue, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Scanning for sensitive info...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final count = _detectedItems.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: count > 0
              ? [Colors.orange, Colors.red]
              : [Colors.green, const Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            count > 0
                ? Icons.warning_amber_rounded
                : Icons.verified_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? '$count Sensitive Items Found!'
                      : 'Document is Safe!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  count > 0
                      ? 'Select items to hide before sharing'
                      : 'No sensitive information detected',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetectedList() {
    // Group by type
    final Map<String, List<SensitiveInfo>> grouped = {};
    for (final item in _detectedItems) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    return grouped.entries.map((entry) {
      final type = entry.key;
      final items = entry.value;
      final isSelected = _selectedTypes[type] ?? false;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            // Type header with toggle
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    PrivacyBlurService.getIcon(type),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              title: Text(
                type,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${items.length} found',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Switch(
                value: isSelected,
                onChanged: (val) {
                  setState(() => _selectedTypes[type] = val);
                },
                activeColor: Colors.blue,
              ),
            ),

            // Individual values
            ...items.map((item) => Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSelected
                          ? '████████████'
                          : item.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.grey
                            : Colors.red,
                        letterSpacing:
                        isSelected ? 2 : 0,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      );
    }).toList();
  }
}

class _PreviewToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _PreviewToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? color : Colors.grey, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.grey,
              fontSize: 12,
              fontWeight: isActive
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}