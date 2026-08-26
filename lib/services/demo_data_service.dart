import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/models/scan_memory_model.dart';
import 'package:document_lens/models/notebook_model.dart';

class DemoDataService {
  static const _uuid = Uuid();

  /// First time app open aagum pothu demo data add pannurom
  static Future<void> seedIfEmpty() async {
    await _seedDocuments();
    await _seedScanMemory();
    await _seedNotebookNotes();
  }

  // ✅ 1. Demo Documents
  static Future<void> _seedDocuments() async {
    final box = Hive.box<DocumentModel>('documents');
    if (box.isNotEmpty) return; // Already has data

    final docs = [
      DocumentModel(
        id: _uuid.v4(),
        title: 'Physics_Notes',
        extractedText:
        'Chapter 1: Newton\'s Laws of Motion\n\n'
            'First Law: An object at rest stays at rest and an object '
            'in motion stays in motion unless acted upon by an external force.\n\n'
            'Second Law: F = ma\nForce equals mass times acceleration.\n\n'
            'Third Law: For every action, there is an equal and opposite reaction.\n\n'
            'Velocity: v = u + at\nDisplacement: s = ut + ½at²\n'
            'Energy: E = mc²',
        imagePath: '',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        language: 'latin',
        category: 'Notes',
        isFavourite: true,
        isPinned: true,
      ),
      DocumentModel(
        id: _uuid.v4(),
        title: 'Electricity_Bill_May_2024',
        extractedText:
        'ELECTRICITY BILL\n'
            'Consumer Name: Sowbarnika\n'
            'Consumer No: 1234567890\n'
            'Meter Reading: 5432\n'
            'Units Consumed: 245 KWH\n'
            'Amount Due: Rs. 1,850\n'
            'Due Date: 25 May 2024\n'
            'Phone: +91 98765 43210\n'
            'Email: sowbar@gmail.com',
        imagePath: '',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        language: 'latin',
        category: 'Receipt',
        isFavourite: false,
        isPinned: false,
      ),
      DocumentModel(
        id: _uuid.v4(),
        title: 'Resume_Sowbarnika',
        extractedText:
        'RESUME\n\n'
            'Name: Sowbarnika\n'
            'Email: sowbar@gmail.com\n'
            'Phone: +91 98765 43210\n\n'
            'OBJECTIVE\n'
            'Seeking a challenging position in software development '
            'to utilize my skills in Flutter and Dart.\n\n'
            'EDUCATION\n'
            'B.E Computer Science - 2024\n'
            'GPA: 8.5/10\n\n'
            'SKILLS\n'
            'Flutter, Dart, Python, Java, SQL\n\n'
            'EXPERIENCE\n'
            'Intern - XYZ Software Solutions\n'
            'Duration: 3 months',
        imagePath: '',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        language: 'latin',
        category: 'Letter',
        isFavourite: true,
        isPinned: false,
      ),
      DocumentModel(
        id: _uuid.v4(),
        title: 'Maths_Assignment',
        extractedText:
        'MATHEMATICS ASSIGNMENT\n\n'
            'Subject: Calculus\n'
            'Submit by: 30 June 2024\n\n'
            'Q1. Find the derivative of f(x) = x³ + 2x² - 5x + 3\n'
            'Solution: f\'(x) = 3x² + 4x - 5\n\n'
            'Q2. Integrate ∫(2x + 3)dx\n'
            'Solution: x² + 3x + C\n\n'
            'Q3. Find the limit of (x²-1)/(x-1) as x→1\n'
            'Solution: lim = 2\n\n'
            'Total Marks: 50\nObtained: 45',
        imagePath: '',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        language: 'latin',
        category: 'Notes',
        isFavourite: false,
        isPinned: false,
      ),
      DocumentModel(
        id: _uuid.v4(),
        title: 'Exam_HallTicket',
        extractedText:
        'HALL TICKET\n\n'
            'Student Name: Sowbarnika R\n'
            'Register Number: 21CS001\n'
            'Exam: Final Semester Examination\n'
            'Date: 15 May 2024\n'
            'Time: 10:00 AM\n'
            'Centre: Government College of Engineering\n'
            'Subject: Software Engineering\n'
            'Subject Code: CS601\n\n'
            'Note: Bring this hall ticket to the exam centre.',
        imagePath: '',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        language: 'latin',
        category: 'ID Card',
        isFavourite: false,
        isPinned: true,
      ),
    ];

    for (final doc in docs) {
      await box.add(doc);
    }
  }

  // ✅ 2. Demo Scan Memory
  static Future<void> _seedScanMemory() async {
    final box = Hive.box<ScanMemoryModel>('scan_memory');
    if (box.isNotEmpty) return;

    final memories = [
      ScanMemoryModel(
        documentId: _uuid.v4(),
        title: 'Physics_Notes',
        category: 'Notes',
        scanCount: 5,
        lastScanned: DateTime.now().subtract(const Duration(hours: 2)),
        imagePath: '',
      ),
      ScanMemoryModel(
        documentId: _uuid.v4(),
        title: 'Maths_Class_Notes',
        category: 'Notes',
        scanCount: 3,
        lastScanned: DateTime.now().subtract(const Duration(days: 1)),
        imagePath: '',
      ),
      ScanMemoryModel(
        documentId: _uuid.v4(),
        title: 'Aadhaar_Card',
        category: 'ID Card',
        scanCount: 2,
        lastScanned: DateTime.now().subtract(const Duration(days: 3)),
        imagePath: '',
      ),
      ScanMemoryModel(
        documentId: _uuid.v4(),
        title: 'Electricity_Bill',
        category: 'Receipt',
        scanCount: 4,
        lastScanned: DateTime.now().subtract(const Duration(days: 2)),
        imagePath: '',
      ),
    ];

    for (final m in memories) {
      await box.add(m);
    }
  }

  // ✅ 3. Demo Notebook Notes
  static Future<void> _seedNotebookNotes() async {
    final subjectBox = Hive.box<SubjectModel>('subjects');
    final noteBox = Hive.box<NoteModel>('notes');

    if (noteBox.isNotEmpty) return;

    // Get Physics subject
    SubjectModel? physicsSubject;
    SubjectModel? mathsSubject;
    SubjectModel? csSubject;

    for (final sub in subjectBox.values) {
      if (sub.name == 'Physics') physicsSubject = sub;
      if (sub.name == 'Maths') mathsSubject = sub;
      if (sub.name == 'Computer Science') csSubject = sub;
    }

    // Physics notes
    if (physicsSubject != null) {
      final physicsNotes = [
        NoteModel(
          id: _uuid.v4(),
          subjectId: physicsSubject.id,
          title: 'Chapter 1 - Newton\'s Laws',
          content:
          'First Law: Inertia — object stays at rest or motion.\n'
              'Second Law: F = ma\n'
              'Third Law: Action-Reaction pairs\n\n'
              'Applications:\n'
              '• Seat belts (First Law)\n'
              '• Rocket propulsion (Third Law)\n'
              '• Braking distance (Second Law)',
          createdAt:
          DateTime.now().subtract(const Duration(days: 5)),
          updatedAt:
          DateTime.now().subtract(const Duration(days: 3)),
          pageCount: 2,
        ),
        NoteModel(
          id: _uuid.v4(),
          subjectId: physicsSubject.id,
          title: 'Chapter 2 - Optics',
          content:
          'Snell\'s Law: n₁sinθ₁ = n₂sinθ₂\n\n'
              'Types of lenses:\n'
              '• Convex (Converging)\n'
              '• Concave (Diverging)\n\n'
              'Mirror formula: 1/f = 1/v + 1/u\n'
              'Magnification: m = -v/u',
          createdAt:
          DateTime.now().subtract(const Duration(days: 3)),
          updatedAt:
          DateTime.now().subtract(const Duration(days: 1)),
          pageCount: 3,
        ),
      ];
      for (final n in physicsNotes) await noteBox.add(n);
    }

    // Maths notes
    if (mathsSubject != null) {
      final mathsNotes = [
        NoteModel(
          id: _uuid.v4(),
          subjectId: mathsSubject.id,
          title: 'Calculus Formulas',
          content:
          'Derivatives:\n'
              'd/dx(xⁿ) = nxⁿ⁻¹\n'
              'd/dx(sin x) = cos x\n'
              'd/dx(cos x) = -sin x\n'
              'd/dx(eˣ) = eˣ\n\n'
              'Integration:\n'
              '∫xⁿ dx = xⁿ⁺¹/(n+1) + C\n'
              '∫sin x dx = -cos x + C\n'
              '∫eˣ dx = eˣ + C',
          createdAt:
          DateTime.now().subtract(const Duration(days: 7)),
          updatedAt:
          DateTime.now().subtract(const Duration(days: 2)),
          pageCount: 4,
        ),
        NoteModel(
          id: _uuid.v4(),
          subjectId: mathsSubject.id,
          title: 'Probability & Statistics',
          content:
          'P(A) = Favorable outcomes / Total outcomes\n\n'
              'P(A∪B) = P(A) + P(B) - P(A∩B)\n\n'
              'Mean = Σx/n\n'
              'Variance = Σ(x-μ)²/n\n'
              'Standard Deviation = √Variance\n\n'
              'Normal Distribution: Bell curve',
          createdAt:
          DateTime.now().subtract(const Duration(days: 4)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
          pageCount: 3,
        ),
      ];
      for (final n in mathsNotes) await noteBox.add(n);
    }

    // CS notes
    if (csSubject != null) {
      final csNotes = [
        NoteModel(
          id: _uuid.v4(),
          subjectId: csSubject.id,
          title: 'Data Structures',
          content:
          'Arrays: Fixed size, O(1) access\n'
              'Linked List: Dynamic, O(n) access\n'
              'Stack: LIFO - push/pop O(1)\n'
              'Queue: FIFO - enqueue/dequeue O(1)\n'
              'Tree: Hierarchical, O(log n) search\n'
              'Graph: Nodes + Edges\n\n'
              'Sorting Algorithms:\n'
              '• Bubble Sort: O(n²)\n'
              '• Quick Sort: O(n log n)\n'
              '• Merge Sort: O(n log n)',
          createdAt:
          DateTime.now().subtract(const Duration(days: 6)),
          updatedAt:
          DateTime.now().subtract(const Duration(hours: 8)),
          pageCount: 5,
        ),
        NoteModel(
          id: _uuid.v4(),
          subjectId: csSubject.id,
          title: 'Flutter Notes',
          content:
          'Widget Types:\n'
              '• StatelessWidget — no state change\n'
              '• StatefulWidget — dynamic state\n\n'
              'State Management:\n'
              '• Provider\n'
              '• Riverpod\n'
              '• Bloc\n\n'
              'Key Concepts:\n'
              '• Everything is a Widget\n'
              '• Hot Reload\n'
              '• Cross-platform (Android + iOS)',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
          pageCount: 2,
        ),
      ];
      for (final n in csNotes) await noteBox.add(n);
    }
  }
}