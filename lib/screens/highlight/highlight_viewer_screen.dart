import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/providers/document_provider.dart';

/// Drag over any portion of the text to select it, then tap "Highlight" to
/// save exactly that portion (not the whole line). Tap an existing
/// highlight to remove it. Highlights are saved per document and persist
/// after closing/reopening.
class HighlightViewerScreen extends StatefulWidget {
  final DocumentModel document;

  const HighlightViewerScreen({super.key, required this.document});

  @override
  State<HighlightViewerScreen> createState() => _HighlightViewerScreenState();
}

class _HighlightViewerScreenState extends State<HighlightViewerScreen> {
  TextSelection? _selection;
  // Changing this key forces SelectableText to drop its internal selection
  // state after we save a highlight (SelectableText has no selection
  // controller, so re-keying is the standard way to reset it).
  Key _selectableKey = UniqueKey();

  DocumentModel get document => widget.document;

  void _saveSelection(DocumentProvider provider) {
    final sel = _selection;
    if (sel == null || sel.start == sel.end) return;
    final start = sel.start < sel.end ? sel.start : sel.end;
    final end = sel.start < sel.end ? sel.end : sel.start;
    provider.addHighlightRange(document, start, end);
    setState(() {
      _selection = null;
      _selectableKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch so the screen rebuilds when highlights change.
    context.watch<DocumentProvider>();
    final provider = context.read<DocumentProvider>();
    // Same length as extractedText when Privacy Blur is active, so the
    // saved highlight offsets below still line up correctly.
    final text = document.displayText;
    final ranges = _mergedSortedRanges(document.highlights);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor =
    isDark ? Colors.yellow.withValues(alpha: 0.35) : const Color(0xFFFFF59D);
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final hasSelection = _selection != null && _selection!.start != _selection!.end;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(document.title, overflow: TextOverflow.ellipsis),
            ),
            if (document.hasPrivacyBlur) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Privacy Blur active',
                child: Icon(Icons.privacy_tip_rounded,
                    size: 18, color: Colors.blue),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy highlighted',
            icon: const Icon(Icons.copy_rounded),
            onPressed: ranges.isEmpty
                ? null
                : () {
              final picked = ranges
                  .map((r) => text.substring(r.start, r.end))
                  .join('\n');
              Clipboard.setData(ClipboardData(text: picked));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Highlighted text copied'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          if (ranges.isNotEmpty)
            IconButton(
              tooltip: 'Clear all highlights',
              icon: const Icon(Icons.format_clear_rounded),
              onPressed: () => provider.clearHighlights(document),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Drag over text to select it, then tap Highlight. '
                        'Tap a highlight to remove it. ${ranges.length} highlighted.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: text.trim().isEmpty
                ? const Center(
              child: Text('No text in this document.',
                  style: TextStyle(color: Colors.grey)),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText.rich(
                key: _selectableKey,
                TextSpan(
                  children: _buildSpans(
                    context: context,
                    text: text,
                    ranges: ranges,
                    highlightColor: highlightColor,
                    textColor: textColor,
                    provider: provider,
                  ),
                ),
                onSelectionChanged: (selection, cause) {
                  setState(() => _selection = selection);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: hasSelection
          ? FloatingActionButton.extended(
        onPressed: () => _saveSelection(provider),
        icon: const Icon(Icons.highlight_rounded),
        label: const Text('Highlight'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      )
          : null,
    );
  }

  List<_Range> _mergedSortedRanges(List<int> flat) {
    final ranges = <_Range>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      final s = flat[i];
      final e = flat[i + 1];
      if (e > s) ranges.add(_Range(s, e));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  /// Builds a TextSpan tree covering the whole document text, styling the
  /// highlighted ranges and attaching a tap-to-remove recognizer to them.
  List<TextSpan> _buildSpans({
    required BuildContext context,
    required String text,
    required List<_Range> ranges,
    required Color highlightColor,
    required Color? textColor,
    required DocumentProvider provider,
  }) {
    final spans = <TextSpan>[];
    var cursor = 0;
    final baseStyle = TextStyle(fontSize: 15, height: 1.5, color: textColor);

    for (final r in ranges) {
      if (r.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, r.start),
          style: baseStyle,
        ));
      }
      final rangeStart = r.start;
      final rangeEnd = r.end;
      spans.add(TextSpan(
        text: text.substring(r.start, r.end),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor,
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            provider.removeHighlightRange(document, rangeStart, rangeEnd);
          },
      ));
      cursor = r.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
}

class _Range {
  final int start;
  final int end;
  const _Range(this.start, this.end);
}