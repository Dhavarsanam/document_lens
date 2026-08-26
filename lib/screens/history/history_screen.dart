import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/screens/highlight/highlight_viewer_screen.dart';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Document History')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: docProvider.search,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    docProvider.clearSearch();
                  },
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ✅ Category Filter
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: DocumentProvider.categories.length,
              itemBuilder: (context, index) {
                final cat = DocumentProvider.categories[index];
                final isSelected = docProvider.selectedCategory == cat;
                return GestureDetector(
                  onTap: () => docProvider.setCategory(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color:
                            isSelected ? Colors.white : Colors.grey,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Document List
          Expanded(
            child: docProvider.filteredDocuments.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No documents found',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docProvider.filteredDocuments.length,
              itemBuilder: (context, index) {
                final doc = docProvider.filteredDocuments[index];
                return _DocumentCard(
                  document: doc,
                  searchQuery: _searchController.text,
                  onDelete: () =>
                      docProvider.deleteDocument(doc.id),
                  onFavourite: () =>
                      docProvider.toggleFavourite(doc),
                  onPin: () => docProvider.togglePin(doc),
                  onRename: () => _showRenameDialog(context, doc),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HighlightViewerScreen(document: doc),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, DocumentModel doc) {
    final controller = TextEditingController(text: doc.title);
    final provider = context.read<DocumentProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        final newName = controller.text.trim();
        if (newName.isNotEmpty && newName != doc.title) {
          await provider.renameDocument(doc, newName);
          if (mounted) {
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

}

class _DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final String searchQuery;
  final VoidCallback onDelete;
  final VoidCallback onFavourite;
  final VoidCallback onPin;
  final VoidCallback onRename;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.document,
    required this.searchQuery,
    required this.onDelete,
    required this.onFavourite,
    required this.onPin,
    required this.onRename,
    required this.onTap,
  });

  // ✅ Highlight matched text
  Widget _highlightText(String text, String query, TextStyle style) {
    if (query.isEmpty) return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    final lower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final index = lower.indexOf(queryLower);
    if (index < 0) return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style.copyWith(
              backgroundColor: Colors.yellow.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onRename,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image / Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: document.imagePath.isNotEmpty &&
                    File(document.imagePath).existsSync()
                    ? Image.file(File(document.imagePath),
                    width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                  width: 56,
                  height: 56,
                  color: Colors.blueGrey.withValues(alpha: 0.2),
                  child: const Icon(Icons.document_scanner_rounded,
                      color: Colors.blueGrey),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (document.isPinned)
                          const Icon(Icons.push_pin_rounded,
                              size: 14, color: Colors.orange),
                        if (document.isPinned) const SizedBox(width: 4),
                        Expanded(
                          child: _highlightText(
                            document.title,
                            searchQuery,
                            TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textColor),
                          ),
                        ),
                        if (document.hasPrivacyBlur) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.privacy_tip_rounded,
                              size: 14, color: Colors.blue),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _highlightText(
                      document.displayText,
                      searchQuery,
                      const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(document.category,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.blue)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${document.createdAt.day}/${document.createdAt.month}/${document.createdAt.year}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  GestureDetector(
                    onTap: onRename,
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.blue, size: 20),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onFavourite,
                    child: Icon(
                      document.isFavourite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: document.isFavourite
                          ? Colors.red
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onPin,
                    child: Icon(
                      document.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: document.isPinned
                          ? Colors.orange
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content:
        const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
}