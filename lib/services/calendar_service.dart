import 'package:url_launcher/url_launcher.dart';

class CalendarService {
  // ✅ All date patterns detect pannurom
  static final List<Map<String, dynamic>> _datePatterns = [
    // "25 May 2024", "25 May, 2024"
    {
      'regex': RegExp(
        r'\b(\d{1,2})\s+(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?),?\s+(\d{4})\b',
        caseSensitive: false,
      ),
      'type': 'DMY_MONTH',
    },
    // "May 25 2024", "May 25, 2024"
    {
      'regex': RegExp(
        r'\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+(\d{1,2}),?\s+(\d{4})\b',
        caseSensitive: false,
      ),
      'type': 'MDY_MONTH',
    },
    // "25/05/2024", "25-05-2024", "23.09.2026", "23.09. 2026" (dots + spaces)
    {
      'regex': RegExp(
          r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4})\b'),
      'type': 'DMY_NUM',
    },
    // "2024-05-25", "2024.05.25", "2024. 05. 25"
    {
      'regex': RegExp(
          r'\b(\d{4})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{1,2})\b'),
      'type': 'YMD_NUM',
    },
  ];

  // Time pattern
  static final RegExp _timePattern = RegExp(
    r'\b(\d{1,2}):(\d{2})\s*(am|pm)?\b',
    caseSensitive: false,
  );

  // Context keywords — event type detect
  static final Map<String, String> _contextKeywords = {
    'exam': '📝 Exam',
    'test': '📝 Test',
    'assignment': '📋 Assignment',
    'submit': '📋 Submission',
    'deadline': '⏰ Deadline',
    'interview': '💼 Interview',
    'meeting': '🤝 Meeting',
    'appointment': '🏥 Appointment',
    'result': '📊 Result',
    'holiday': '🎉 Holiday',
    'birthday': '🎂 Birthday',
    'event': '📅 Event',
    'class': '🎓 Class',
    'seminar': '🎤 Seminar',
    'workshop': '🔧 Workshop',
  };

  /// Detect all calendar events from text
  static List<DetectedEvent> detectEvents(String text) {
    final List<DetectedEvent> events = [];
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      DateTime? detectedDate;
      String matchedText = '';

      // Try each date pattern
      for (final pattern in _datePatterns) {
        final regex = pattern['regex'] as RegExp;
        final type = pattern['type'] as String;
        final match = regex.firstMatch(line);

        if (match != null) {
          detectedDate = _parseDate(match, type);
          matchedText = match.group(0) ?? '';
          break;
        }
      }

      if (detectedDate == null) continue;

      // Check time in same line
      final timeMatch = _timePattern.firstMatch(line);
      if (timeMatch != null) {
        int hour = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        final ampm = timeMatch.group(3)?.toLowerCase();
        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;
        detectedDate = DateTime(
          detectedDate.year,
          detectedDate.month,
          detectedDate.day,
          hour,
          minute,
        );
      }

      // Detect event title from context
      String eventTitle = 'Document Event';
      String eventEmoji = '📅';
      _contextKeywords.forEach((keyword, label) {
        if (line.toLowerCase().contains(keyword)) {
          eventTitle = label;
          eventEmoji = label.split(' ').first;
        }
      });

      events.add(DetectedEvent(
        title: eventTitle,
        emoji: eventEmoji,
        originalText: line.trim(),
        dateTime: detectedDate,
        matchedDateText: matchedText,
      ));
    }

    return events;
  }

  /// Parse date from regex match
  static DateTime? _parseDate(RegExpMatch match, String type) {
    try {
      switch (type) {
        case 'DMY_MONTH':
          final day = int.parse(match.group(1)!);
          final month = _monthFromName(match.group(2)!);
          final year = int.parse(match.group(3)!);
          return DateTime(year, month, day);

        case 'MDY_MONTH':
          final month = _monthFromName(match.group(1)!);
          final day = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          return DateTime(year, month, day);

        case 'DMY_NUM':
          var day = int.parse(match.group(1)!);
          var month = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          // Looks like MM.DD (month first)? swap to salvage it.
          if (month > 12 && day <= 12) {
            final t = day;
            day = month;
            month = t;
          }
          if (month > 12 || day > 31) return null;
          return DateTime(year, month, day);

        case 'YMD_NUM':
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          if (month > 12) return null;
          return DateTime(year, month, day);

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static int _monthFromName(String name) {
    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    return months[name.toLowerCase()] ?? 1;
  }

  /// Add event to the user's calendar.
  ///
  /// Opens a Google Calendar "create event" page pre-filled with the
  /// detected event. Works on web, Windows, macOS, Linux, Android and iOS
  /// (unlike native-only calendar plugins). Throws if the URL can't open
  /// so the caller can show an error.
  static Future<void> addToCalendar(DetectedEvent event) async {
    final start = event.dateTime;
    final allDay = start.hour == 0 && start.minute == 0;
    final end = start.add(const Duration(hours: 1));

    String two(int n) => n.toString().padLeft(2, '0');
    String dt(DateTime d) =>
        '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}00';
    String day(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';

    final dates = allDay
        ? '${day(start)}/${day(start.add(const Duration(days: 1)))}'
        : '${dt(start)}/${dt(end)}';

    // Strip the leading emoji from the title (e.g. "📝 Exam" -> "Exam").
    final title = event.title.replaceAll(RegExp(r'^[^\s]+\s'), '').trim();

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title.isEmpty ? 'Document Event' : title,
      'dates': dates,
      'details': event.originalText,
    });

    final opened =
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('Could not open calendar');
    }
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final time = date.hour > 0
        ? ' at ${_formatTime(date)}'
        : '';
    return '${date.day} ${months[date.month - 1]} ${date.year}$time';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  /// Days remaining
  static String daysRemaining(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'Passed';
    if (diff.inDays == 0) return 'Today!';
    if (diff.inDays == 1) return 'Tomorrow!';
    return '${diff.inDays} days left';
  }
}

/// Detected event data class
class DetectedEvent {
  final String title;
  final String emoji;
  final String originalText;
  final DateTime dateTime;
  final String matchedDateText;

  DetectedEvent({
    required this.title,
    required this.emoji,
    required this.originalText,
    required this.dateTime,
    required this.matchedDateText,
  });
}