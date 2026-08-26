class PrivacyBlurService {
  // ── Sensitive patterns ──────────────────────────────────────
  // NOTE: only "Bank Account" uses a capturing group (the digits). Every
  // other pattern uses (?:...) non-capturing groups so the WHOLE match is
  // masked, not a sub-group.
  static final Map<String, RegExp> _patterns = {
    // Tolerate OCR spacing/dashes (0–2 separators between digit groups).
    'Aadhaar Number':
    RegExp(r'(?<!\d)\d{4}[\s\-]{0,2}\d{4}[\s\-]{0,2}\d{4}(?!\d)'),
    'Credit Card': RegExp(
        r'(?<!\d)\d{4}[\s\-]{0,2}\d{4}[\s\-]{0,2}\d{4}[\s\-]{0,2}\d{4}(?!\d)'),
    'PAN Card': RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b'),
    'Passport Number': RegExp(r'\b[A-Z][1-9]\d{7}\b'),
    'IFSC Code': RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b'),
    'Email Address':
    RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
    // +91 / 0 prefix optional; tolerate a space/dash in the middle
    // (e.g. "98765 43210", "+91-98765-43210", "09876543210").
    'Phone Number': RegExp(
        r'(?<!\d)(?:(?:\+?91|0)[\s\-]?)?[6-9]\d{4}[\s\-]?\d{5}(?!\d)'),
    'Date of Birth': RegExp(
      r'\b(?:DOB|Date of Birth|Birth Date)[\s:\-]+\d{1,2}[/\-]\d{1,2}[/\-]\d{4}\b',
      caseSensitive: false,
    ),
    // Context-anchored; group(1) = account digits (only this is masked).
    'Bank Account': RegExp(
      r'(?:A/?C|Acc(?:ount)?)\s*(?:No\.?|Number|#)?[:\s\-]*(\d{9,18})',
      caseSensitive: false,
    ),
    'Pincode': RegExp(r'(?<!\d)[1-9]\d{5}(?!\d)'),
    // Catch-all (lowest priority): any long unbroken digit run the specific
    // patterns didn't claim — long account/ID numbers, etc. Overlap
    // resolution ensures phone/Aadhaar/etc. still win their spans.
    'Sensitive Number': RegExp(r'(?<!\d)\d{9,}(?!\d)'),
  };

  /// More-specific types win when ranges overlap (higher = stronger).
  static const Map<String, int> _priority = {
    'Aadhaar Number': 100,
    'Credit Card': 95,
    'PAN Card': 90,
    'Passport Number': 85,
    'IFSC Code': 80,
    'Email Address': 75,
    'Phone Number': 70,
    'Date of Birth': 65,
    'Bank Account': 40,
    'Pincode': 25,
    'Sensitive Number': 10,
  };

  /// Detect all sensitive info in [text] — returns a clean, NON-overlapping
  /// list (overlaps resolved by priority, then length). Every occurrence is
  /// kept (repeated values are all masked, not just the first).
  static List<SensitiveInfo> detectSensitiveInfo(String text) {
    final List<SensitiveInfo> all = [];

    _patterns.forEach((type, regex) {
      for (final match in regex.allMatches(text)) {
        late String value;
        late int start;
        late int end;

        // Only "Bank Account" defines a capturing group (the digits).
        if (match.groupCount >= 1 && match.group(1) != null) {
          final full = match.group(0)!;
          final captured = match.group(1)!;
          // Dart Match has no per-group offset, so locate the captured
          // digits inside the full match (they sit at the end).
          final rel = full.lastIndexOf(captured);
          start = match.start + (rel < 0 ? 0 : rel);
          end = start + captured.length;
          value = captured;
        } else {
          value = match.group(0)!;
          start = match.start;
          end = match.end;
        }

        all.add(SensitiveInfo(
          type: type,
          value: value,
          start: start,
          end: end,
        ));
      }
    });

    return _resolveOverlaps(all);
  }

  /// Greedy overlap resolution: strongest (highest priority, then longest)
  /// match claims its span first; weaker matches overlapping it are dropped.
  static List<SensitiveInfo> _resolveOverlaps(List<SensitiveInfo> items) {
    final ranked = List<SensitiveInfo>.from(items)
      ..sort((a, b) {
        final pa = _priority[a.type] ?? 0;
        final pb = _priority[b.type] ?? 0;
        if (pa != pb) return pb.compareTo(pa); // priority desc
        final la = a.end - a.start;
        final lb = b.end - b.start;
        if (la != lb) return lb.compareTo(la); // length desc
        return a.start.compareTo(b.start);
      });

    final List<SensitiveInfo> accepted = [];
    bool overlaps(SensitiveInfo x) {
      for (final y in accepted) {
        if (x.start < y.end && y.start < x.end) return true;
      }
      return false;
    }

    for (final item in ranked) {
      if (!overlaps(item)) accepted.add(item);
    }

    accepted.sort((a, b) => a.start.compareTo(b.start)); // reading order
    return accepted;
  }

  /// Apply mask to the given (non-overlapping) [items].
  static String applyPrivacyBlur(String text, List<SensitiveInfo> items) {
    String result = text;
    final sorted = List<SensitiveInfo>.from(items)
      ..sort((a, b) => b.start.compareTo(a.start)); // end -> start

    for (final item in sorted) {
      if (item.start < 0 ||
          item.end > result.length ||
          item.start >= item.end) {
        continue; // guard against any stale/out-of-range span
      }
      result =
          result.replaceRange(item.start, item.end, _maskValue(item.value));
    }
    return result;
  }

  static String _maskValue(String value) {
    final len = value.replaceAll(RegExp(r'\s'), '').length;
    if (len <= 4) return '████';
    if (len <= 8) return '████████';
    return '████████████';
  }

  /// Same-length masking: every non-whitespace char in [items]' spans
  /// becomes '█', whitespace/newlines are preserved as-is. Unlike
  /// [applyPrivacyBlur] (which uses bucketed-length placeholders, fine for
  /// a one-off preview), this keeps the output the SAME LENGTH as [text] —
  /// required wherever character offsets into the original text must stay
  /// valid after masking (e.g. saved highlight ranges).
  static String applyPrivacyBlurPreserveLength(
      String text, List<SensitiveInfo> items) {
    final buffer = StringBuffer();
    var cursor = 0;
    final sorted = List<SensitiveInfo>.from(items)
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final item in sorted) {
      if (item.start < cursor || item.end > text.length || item.start >= item.end) {
        continue; // guard against stale/overlapping/out-of-range spans
      }
      buffer.write(text.substring(cursor, item.start));
      for (final ch in text.substring(item.start, item.end).split('')) {
        buffer.write(RegExp(r'\s').hasMatch(ch) ? ch : '█');
      }
      cursor = item.end;
    }
    if (cursor < text.length) buffer.write(text.substring(cursor));
    return buffer.toString();
  }

  /// Mask only one type across the whole text.
  static String maskType(String text, String type) {
    final all =
    detectSensitiveInfo(text).where((e) => e.type == type).toList();
    return applyPrivacyBlur(text, all);
  }

  static String getIcon(String type) {
    switch (type) {
      case 'Phone Number':
        return '📱';
      case 'Aadhaar Number':
        return '🪪';
      case 'PAN Card':
        return '💳';
      case 'Email Address':
        return '📧';
      case 'Credit Card':
        return '💳';
      case 'Date of Birth':
        return '🎂';
      case 'Passport Number':
        return '🛂';
      case 'Bank Account':
        return '🏦';
      case 'IFSC Code':
        return '🏛️';
      case 'Pincode':
        return '📍';
      case 'Sensitive Number':
        return '🔢';
      default:
        return '🔒';
    }
  }
}

/// Sensitive info data class
class SensitiveInfo {
  final String type;
  final String value;
  final int start;
  final int end;

  SensitiveInfo({
    required this.type,
    required this.value,
    required this.start,
    required this.end,
  });
}