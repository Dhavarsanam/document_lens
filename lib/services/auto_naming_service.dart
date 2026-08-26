class AutoNamingService {
  /// ✅ Default automatic name right after a scan: "Document 1", "Document 2"...
  /// based on how many documents already exist. Simple and predictable —
  /// the user can still edit it manually, or tap the ✨ wand to get a
  /// smart content-based suggestion instead (see [generateFileName] below).
  static String generateSequentialName(int existingDocumentCount) {
    return 'Document ${existingDocumentCount + 1}';
  }

  // Keyword maps — document type detect pannum
  static const Map<String, List<String>> _keywordMap = {
    'Resume': [
      'resume', 'cv', 'curriculum vitae', 'experience',
      'skills', 'objective', 'qualification', 'career'
    ],
    'Physics_Notes': [
      'physics', 'newton', 'force', 'velocity', 'acceleration',
      'energy', 'momentum', 'optics', 'magnetism', 'wave'
    ],
    'Maths_Notes': [
      'mathematics', 'maths', 'algebra', 'geometry', 'calculus',
      'trigonometry', 'equation', 'theorem', 'integral', 'derivative'
    ],
    'Chemistry_Notes': [
      'chemistry', 'chemical', 'element', 'compound', 'reaction',
      'molecule', 'atom', 'periodic', 'acid', 'base'
    ],
    'Biology_Notes': [
      'biology', 'cell', 'organism', 'photosynthesis', 'dna',
      'genetics', 'evolution', 'ecosystem', 'anatomy', 'tissue'
    ],
    'Computer_Science_Notes': [
      'computer', 'algorithm', 'programming', 'software', 'database',
      'network', 'operating system', 'data structure', 'coding', 'compiler'
    ],
    'Electricity_Bill': [
      'electricity', 'electric bill', 'power bill', 'kwh',
      'units consumed', 'meter reading', 'tariff', 'voltage'
    ],
    'Water_Bill': [
      'water bill', 'water supply', 'water charges',
      'municipal', 'water meter', 'water board'
    ],
    'Phone_Bill': [
      'mobile bill', 'phone bill', 'airtel', 'jio', 'bsnl',
      'vi', 'vodafone', 'telecom', 'recharge', 'data usage'
    ],
    'Receipt': [
      'receipt', 'invoice', 'bill', 'payment', 'amount paid',
      'total', 'tax', 'gst', 'cash', 'transaction'
    ],
    'Aadhaar_Card': [
      'aadhaar', 'aadhar', 'uid', 'uidai',
      'unique identification', 'biometric'
    ],
    'PAN_Card': [
      'pan card', 'permanent account', 'income tax',
      'pan number', 'taxpayer'
    ],
    'Driving_License': [
      'driving license', 'dl', 'motor vehicle',
      'transport', 'rto', 'licence'
    ],
    'Passport': [
      'passport', 'travel document', 'visa',
      'nationality', 'date of issue', 'place of birth'
    ],
    'Exam_HallTicket': [
      'hall ticket', 'admit card', 'roll number',
      'examination', 'centre', 'register number'
    ],
    'Marksheet': [
      'marksheet', 'mark sheet', 'result', 'grade',
      'cgpa', 'percentage', 'pass', 'fail', 'semester'
    ],
    'Assignment': [
      'assignment', 'homework', 'submit', 'due date',
      'question', 'answer', 'marks'
    ],
    'Timetable': [
      'timetable', 'time table', 'schedule', 'period',
      'class', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'
    ],
    'Medical_Report': [
      'medical', 'report', 'diagnosis', 'prescription',
      'doctor', 'hospital', 'patient', 'blood test', 'lab'
    ],
    'Offer_Letter': [
      'offer letter', 'appointment', 'joining', 'salary',
      'designation', 'employee', 'company', 'ctc'
    ],
    'Leave_Letter': [
      'leave', 'absent', 'sick leave', 'casual leave',
      'principal', 'respectfully', 'permission'
    ],
  };

  /// Generate smart filename from extracted text
  static String generateFileName(String extractedText) {
    if (extractedText.trim().isEmpty) {
      return _timestampName();
    }

    final lowerText = extractedText.toLowerCase();

    // Score each document type
    final scores = <String, int>{};
    _keywordMap.forEach((docType, keywords) {
      int score = 0;
      for (final keyword in keywords) {
        if (lowerText.contains(keyword)) {
          score++;
        }
      }
      if (score > 0) scores[docType] = score;
    });

    if (scores.isEmpty) {
      // Try to extract first meaningful line as name
      return _extractFromFirstLine(extractedText);
    }

    // Get highest scoring type
    final bestMatch = scores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Add date if found in text
    final dateStr = _extractDate(extractedText);
    if (dateStr != null) {
      return '${bestMatch}_$dateStr';
    }

    return bestMatch;
  }

  /// Extract date from text (e.g., May 2024, 12/05/2024)
  static String? _extractDate(String text) {
    // Match patterns like "May 2024", "Jan 2024"
    final monthYearRegex = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{4})\b',
      caseSensitive: false,
    );
    final match = monthYearRegex.firstMatch(text);
    if (match != null) {
      final month = match.group(1)!
          .substring(0, 3)
          .toLowerCase()
          .replaceFirstMapped(
          RegExp(r'^.'), (m) => m.group(0)!.toUpperCase());
      final year = match.group(2);
      return '${month}_$year';
    }

    // Match DD/MM/YYYY
    final dateRegex = RegExp(r'\b(\d{2})[/\-](\d{2})[/\-](\d{4})\b');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      return '${dateMatch.group(3)}_${dateMatch.group(2)}_${dateMatch.group(1)}';
    }

    return null;
  }

  /// Extract first meaningful line
  static String _extractFromFirstLine(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 3)
        .toList();

    if (lines.isEmpty) return _timestampName();

    // Clean and format first line
    final firstLine = lines.first
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .trim()
        .split(' ')
        .take(3)
        .join('_');

    return firstLine.isEmpty ? _timestampName() : firstLine;
  }

  /// Timestamp based fallback name
  static String _timestampName() {
    final now = DateTime.now();
    return 'Document_${now.day}_${now.month}_${now.year}';
  }

  /// Get full filename with extension
  static String getFullFileName(String extractedText,
      {String extension = 'pdf'}) {
    final name = generateFileName(extractedText);
    return '$name.$extension';
  }
}