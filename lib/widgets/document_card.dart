import 'dart:io';
import 'package:flutter/material.dart';
import 'package:document_lens/models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: document.imagePath.isNotEmpty &&
              File(document.imagePath).existsSync()
              ? Image.file(
            File(document.imagePath),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          )
          // ✅ No local file (e.g. this doc synced in from another
          // device) — fall back to the Firebase Storage image.
              : (document.imageUrl != null && document.imageUrl!.isNotEmpty)
              ? Image.network(
            document.imageUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              width: 56,
              height: 56,
              color: Colors.blueGrey.withValues(alpha: 0.2),
              child: const Icon(Icons.document_scanner_rounded,
                  color: Colors.blueGrey),
            ),
          )
              : Container(
            width: 56,
            height: 56,
            color: Colors.blueGrey.withValues(alpha: 0.2),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.blueGrey,
            ),
          ),
        ),
        title: Text(
          document.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              document.extractedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              '${document.createdAt.day}/${document.createdAt.month}/${document.createdAt.year}  •  ${document.language.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: () => _showFullText(context),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onDelete();
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFullText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    document.extractedText,
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
}