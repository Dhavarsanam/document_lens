class AppConstants {
  /// Languages that ACTUALLY work in the app (no fake entries).
  ///  - Hindi/Marathi/Sanskrit/Nepali -> ML Kit Devanagari (on-device)
  ///  - Chinese/Japanese/Korean       -> ML Kit (on-device)
  ///  - English/French/German/Spanish -> ML Kit Latin (on-device)
  static const List<Map<String, String>> supportedLanguages = [
    {'name': 'Tamil', 'code': 'tamil'},
    {'name': 'Hindi', 'code': 'hindi'},
    {'name': 'Marathi', 'code': 'marathi'},
    {'name': 'Sanskrit', 'code': 'sanskrit'},
    {'name': 'Nepali', 'code': 'nepali'},
    {'name': 'English', 'code': 'english'},
    {'name': 'Chinese', 'code': 'chinese'},
    {'name': 'Japanese', 'code': 'japanese'},
    {'name': 'Korean', 'code': 'korean'},
    {'name': 'French', 'code': 'french'},
    {'name': 'German', 'code': 'german'},
    {'name': 'Spanish', 'code': 'spanish'},
  ];

  static const String documentsBox = 'documents';
  static const String pdfExtension = '.pdf';
  static const String txtExtension = '.txt';
  static const String appName = 'DOCMIND';
  static const String appVersion = '1.0.0';
}