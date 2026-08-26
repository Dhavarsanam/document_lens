import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/notebook_provider.dart';
import 'package:document_lens/models/notebook_model.dart';
import 'package:document_lens/screens/notebook/subject_notes_screen.dart'; // ✅ Fixed

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📚';
    String selectedColor = 'FF1A73E8';

    final emojis = [
      '📚', '⚛️', '📐', '💻', '🧪',
      '🌿', '🎨', '🏛️', '🌍', '🎵'
    ];
    final colors = [
      'FF1A73E8', 'FF00897B', 'FF7B1FA2',
      'FFEF6C00', 'FF2E7D32', 'FFC62828',
      'FF00838F', 'FF4527A0', 'FF558B2F',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Subject',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // Name field
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Subject name...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              // Emoji picker
              const Text('Pick Emoji',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: emojis.map((e) {
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedEmoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selectedEmoji == e
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedEmoji == e
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Color picker
              const Text('Pick Color',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.map((c) {
                  final color =
                  Color(NotebookProvider.colorFromHex(c));
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedColor = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == c
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (selectedColor == c)
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                        ],
                      ),
                      child: selectedColor == c
                          ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    // ✅ Fixed: async gap issue
                    final provider =
                    context.read<NotebookProvider>();
                    await provider.addSubject(
                      name: nameController.text.trim(),
                      emoji: selectedEmoji,
                      colorHex: selectedColor,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Add Subject'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notebookProvider = context.watch<NotebookProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredSubjects = _searchQuery.isEmpty
        ? notebookProvider.subjects
        : notebookProvider.subjects
        .where((s) => s.name
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notebook'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Subject',
            onPressed: _showAddSubjectDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search subjects...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Stats bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MiniStat(
                    icon: Icons.menu_book_rounded,
                    label: 'Subjects',
                    value: '${notebookProvider.subjects.length}',
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.note_rounded,
                    label: 'Total Notes',
                    value: '${notebookProvider.notes.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.pages_rounded,
                    label: 'Total Pages',
                    value:
                    '${notebookProvider.notes.fold(0, (s, n) => s + n.pageCount)}',
                    color: Colors.green,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Subjects Grid
            Expanded(
              child: filteredSubjects.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text('No subjects yet',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Subject'),
                      onPressed: _showAddSubjectDialog,
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemCount: filteredSubjects.length,
                itemBuilder: (context, index) {
                  final subject = filteredSubjects[index];
                  final color = Color(
                      NotebookProvider.colorFromHex(
                          subject.colorHex));
                  final noteCount = notebookProvider
                      .noteCountForSubject(subject.id);
                  final pageCount = notebookProvider
                      .pageCountForSubject(subject.id);

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectNotesScreen(
                            subject: subject),
                      ),
                    ),
                    onLongPress: () =>
                        _confirmDeleteSubject(subject),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2130)
                            : Colors.white,
                        borderRadius:
                        BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                            color.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          // Color header
                          Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: color
                                  .withValues(alpha: 0.12),
                              borderRadius:
                              const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                subject.emoji,
                                style: const TextStyle(
                                    fontSize: 40),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: color,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.note_rounded,
                                        size: 12,
                                        color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$noteCount Notes',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                          Colors.grey[500]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.pages_rounded,
                                        size: 12,
                                        color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$pageCount Pages',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                          Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubjectDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _confirmDeleteSubject(SubjectModel subject) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${subject.name}?'),
        content: const Text(
            'This will delete all notes in this subject.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<NotebookProvider>()
                  .deleteSubject(subject.id);
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}