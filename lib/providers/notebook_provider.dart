import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:document_lens/models/notebook_model.dart';

class NotebookProvider extends ChangeNotifier {
  static const String _subjectsBox = 'subjects';
  static const String _notesBox = 'notes';

  List<SubjectModel> _subjects = [];
  List<NoteModel> _notes = [];

  List<SubjectModel> get subjects => _subjects;
  List<NoteModel> get notes => _notes;

  // Default subjects
  static const List<Map<String, String>> defaultSubjects = [
    {'name': 'Physics', 'emoji': '⚛️', 'color': 'FF1A73E8'},
    {'name': 'Maths', 'emoji': '📐', 'color': 'FF00897B'},
    {'name': 'Computer Science', 'emoji': '💻', 'color': 'FF7B1FA2'},
    {'name': 'Chemistry', 'emoji': '🧪', 'color': 'FFEF6C00'},
    {'name': 'Biology', 'emoji': '🌿', 'color': 'FF2E7D32'},
    {'name': 'English', 'emoji': '📚', 'color': 'FFC62828'},
  ];

  NotebookProvider() {
    _loadData();
  }

  void _loadData() {
    final subBox = Hive.box<SubjectModel>(_subjectsBox);
    final noteBox = Hive.box<NoteModel>(_notesBox);
    _subjects = subBox.values.toList();
    _notes = noteBox.values.toList();

    // Add default subjects if empty
    if (_subjects.isEmpty) {
      _addDefaultSubjects();
    } else {
      notifyListeners();
    }
  }

  Future<void> _addDefaultSubjects() async {
    final box = Hive.box<SubjectModel>(_subjectsBox);
    for (final s in defaultSubjects) {
      final subject = SubjectModel(
        id: const Uuid().v4(),
        name: s['name']!,
        colorHex: s['color']!,
        emoji: s['emoji']!,
        createdAt: DateTime.now(),
      );
      await box.add(subject);
    }
    _subjects = box.values.toList();
    notifyListeners();
  }

  // Get notes for subject
  List<NoteModel> getNotesForSubject(String subjectId) {
    return _notes
        .where((n) => n.subjectId == subjectId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // Total notes count for subject
  int noteCountForSubject(String subjectId) {
    return _notes.where((n) => n.subjectId == subjectId).length;
  }

  // Total pages for subject
  int pageCountForSubject(String subjectId) {
    return _notes
        .where((n) => n.subjectId == subjectId)
        .fold(0, (sum, n) => sum + n.pageCount);
  }

  // Add subject
  Future<void> addSubject({
    required String name,
    required String emoji,
    required String colorHex,
  }) async {
    final box = Hive.box<SubjectModel>(_subjectsBox);
    final subject = SubjectModel(
      id: const Uuid().v4(),
      name: name,
      colorHex: colorHex,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    await box.add(subject);
    _subjects = box.values.toList();
    notifyListeners();
  }

  // Delete subject
  Future<void> deleteSubject(String subjectId) async {
    final subBox = Hive.box<SubjectModel>(_subjectsBox);
    final noteBox = Hive.box<NoteModel>(_notesBox);

    // Delete all notes for this subject
    final keysToDelete = noteBox.keys
        .where((k) => (noteBox.get(k) as NoteModel).subjectId == subjectId)
        .toList();
    for (final key in keysToDelete) {
      await noteBox.delete(key);
    }

    // Delete subject
    final subKey = subBox.keys.firstWhere(
          (k) => (subBox.get(k) as SubjectModel).id == subjectId,
      orElse: () => null,
    );
    if (subKey != null) await subBox.delete(subKey);

    _loadData();
  }

  // Add note
  Future<void> addNote({
    required String subjectId,
    required String title,
    required String content,
  }) async {
    final box = Hive.box<NoteModel>(_notesBox);
    final note = NoteModel(
      id: const Uuid().v4(),
      subjectId: subjectId,
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      pageCount: _estimatePages(content),
    );
    await box.add(note);
    _notes = box.values.toList();
    notifyListeners();
  }

  // Update note
  Future<void> updateNote(NoteModel note, String newContent) async {
    note.content = newContent;
    note.updatedAt = DateTime.now();
    note.pageCount = _estimatePages(newContent);
    await note.save();
    _notes = Hive.box<NoteModel>(_notesBox).values.toList();
    notifyListeners();
  }

  // Delete note
  Future<void> deleteNote(String noteId) async {
    final box = Hive.box<NoteModel>(_notesBox);
    final key = box.keys.firstWhere(
          (k) => (box.get(k) as NoteModel).id == noteId,
      orElse: () => null,
    );
    if (key != null) await box.delete(key);
    _notes = box.values.toList();
    notifyListeners();
  }

  // Estimate pages (300 words per page)
  int _estimatePages(String content) {
    final words = content.trim().split(RegExp(r'\s+')).length;
    return (words / 300).ceil().clamp(1, 999);
  }

  // Search notes
  List<NoteModel> searchNotes(String query) {
    if (query.isEmpty) return _notes;
    return _notes
        .where((n) =>
    n.title.toLowerCase().contains(query.toLowerCase()) ||
        n.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Get color from hex
  static int colorFromHex(String hex) {
    return int.parse(hex, radix: 16);
  }
}