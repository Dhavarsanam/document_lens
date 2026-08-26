import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/notebook_provider.dart';
import 'package:document_lens/models/notebook_model.dart';

class SubjectNotesScreen extends StatefulWidget {
  final SubjectModel subject;

  const SubjectNotesScreen({super.key, required this.subject});

  @override
  State<SubjectNotesScreen> createState() =>
      _SubjectNotesScreenState();
}

class _SubjectNotesScreenState extends State<SubjectNotesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Note to ${widget.subject.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Note title...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Note content...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  await context.read<NotebookProvider>().addNote(
                    subjectId: widget.subject.id,
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Add Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNoteDialog(NoteModel note) {
    final contentController =
    TextEditingController(text: note.content);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit: ${note.title}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Note content...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context
                      .read<NotebookProvider>()
                      .updateNote(note, contentController.text);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notebookProvider = context.watch<NotebookProvider>();
    final subjectColor = Color(
        NotebookProvider.colorFromHex(widget.subject.colorHex));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allNotes =
    notebookProvider.getNotesForSubject(widget.subject.id);
    final filteredNotes = _searchQuery.isEmpty
        ? allNotes
        : allNotes
        .where((n) =>
    n.title
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()) ||
        n.content
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '${widget.subject.emoji} ${widget.subject.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      subjectColor,
                      subjectColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(widget.subject.emoji,
                      style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _showAddNoteDialog,
              ),
            ],
          ),
        ],
        body: Column(
          children: [
            // Stats + Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: subjectColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${allNotes.length} Notes',
                          style: TextStyle(
                              color: subjectColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: subjectColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${notebookProvider.pageCountForSubject(widget.subject.id)} Pages',
                          style: TextStyle(
                              color: subjectColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search
                  TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),

            // Notes List
            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.note_add_rounded,
                        size: 56,
                        color: subjectColor
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    const Text('No notes yet',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Note'),
                      onPressed: _showAddNoteDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: subjectColor,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  final note = filteredNotes[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2130)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(
                        left: BorderSide(
                            color: subjectColor, width: 4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      title: Text(
                        note.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            note.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.pages_rounded,
                                  size: 11,
                                  color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                '${note.pageCount} page${note.pageCount > 1 ? 's' : ''}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[400]),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time_rounded,
                                  size: 11,
                                  color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                _timeAgo(note.updatedAt),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded,
                                    size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded,
                                    size: 16,
                                    color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(
                                        color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showEditNoteDialog(note);
                          } else if (val == 'delete') {
                            context
                                .read<NotebookProvider>()
                                .deleteNote(note.id);
                          }
                        },
                      ),
                      onTap: () =>
                          _showEditNoteDialog(note),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        backgroundColor: subjectColor,
        child: const Icon(Icons.add_rounded, color: Colors.white),
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