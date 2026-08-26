import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/screens/highlight/highlight_viewer_screen.dart';

/// Shows a bottom sheet with quick actions for a document:
/// View full text, toggle Favourite, toggle Pin, and Delete.
///
/// Used by the "more options" (⋮) icons on Home and Insights recent
/// document lists, so those icons are no longer decorative.
void showDocumentActionSheet(BuildContext context, DocumentModel document) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View Full Text'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showFullText(context, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                subtitle: Text(
                  document.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showRenameDialog(context, document);
                },
              ),
              ListTile(
                leading: const Icon(Icons.highlight_rounded,
                    color: Colors.amber),
                title: const Text('Highlight'),
                subtitle: Text(
                  document.highlights.isEmpty
                      ? 'Mark important text'
                  // ✅ highlights stores flattened [start,end] pairs now,
                  // so the actual highlight count is half the list length.
                      : '${document.highlights.length ~/ 2} highlighted',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HighlightViewerScreen(document: document),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  document.isFavourite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: document.isFavourite ? Colors.red : null,
                ),
                title: Text(document.isFavourite
                    ? 'Remove from Favourites'
                    : 'Add to Favourites'),
                onTap: () {
                  context.read<DocumentProvider>().toggleFavourite(document);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: Icon(
                  document.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: document.isPinned ? Colors.orange : null,
                ),
                title: Text(document.isPinned ? 'Unpin' : 'Pin to Top'),
                onTap: () {
                  context.read<DocumentProvider>().togglePin(document);
                  Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, document);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showRenameDialog(BuildContext context, DocumentModel document) {
  final controller = TextEditingController(text: document.title);
  final provider = context.read<DocumentProvider>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Document name',
            hintText: 'Enter a new name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  ).then((confirmed) async {
    if (confirmed == true) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != document.title) {
        await provider.renameDocument(document, newName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Renamed to "$newName"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
    controller.dispose();
  });
}

void _showFullText(BuildContext context, DocumentModel doc) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(doc.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ),
                if (doc.hasPrivacyBlur) ...[
                  const SizedBox(width: 8),
                  const Tooltip(
                    message: 'Privacy Blur active',
                    child: Icon(Icons.privacy_tip_rounded,
                        size: 18, color: Colors.blue),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(doc.category,
                style: const TextStyle(fontSize: 12, color: Colors.blue)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Text(
                  doc.extractedText.isEmpty
                      ? 'No text extracted from this document.'
                      : doc.displayText,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, DocumentModel document) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Document'),
      content: const Text('Are you sure you want to delete this document?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.read<DocumentProvider>().deleteDocument(document.id);
            Navigator.pop(dialogContext);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}