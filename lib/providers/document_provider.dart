import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:document_lens/models/document_model.dart';
import 'package:document_lens/core/constants/app_constants.dart';

class DocumentProvider extends ChangeNotifier {
  List<DocumentModel> _documents = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isSyncing = false;

  List<DocumentModel> get documents => _documents;
  String get selectedCategory => _selectedCategory;
  bool get isSyncing => _isSyncing;

  // ✅ Cloud backend — Firestore stores document metadata/text under
  // users/{uid}/documents/{docId}; Storage stores the scanned image.
  // Everything still writes to the local Hive cache FIRST (instant,
  // works offline), then syncs to the cloud in the background.
  String? get _uid => fb.FirebaseAuth.instance.currentUser?.uid;
  CollectionReference<Map<String, dynamic>>? get _cloudCollection {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('documents');
  }

  // Categories
  static const List<String> categories = [
    'All', 'Receipt', 'Notes', 'ID Card', 'Letter', 'Other'
  ];

  List<DocumentModel> get filteredDocuments {
    List<DocumentModel> docs = _documents;

    // Category filter
    if (_selectedCategory != 'All') {
      docs = docs.where((d) => d.category == _selectedCategory).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      docs = docs.where((doc) =>
      doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.extractedText.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Pinned first
    docs.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return docs;
  }

  List<DocumentModel> get favourites =>
      _documents.where((d) => d.isFavourite).toList();

  // Dashboard stats
  int get totalDocuments => _documents.length;
  int get totalWords => _documents.fold(0,
          (sum, doc) => sum + doc.extractedText.split(' ').length);
  Map<String, int> get categoryCount {
    final map = <String, int>{};
    for (final doc in _documents) {
      map[doc.category] = (map[doc.category] ?? 0) + 1;
    }
    return map;
  }
  Map<String, int> get languageCount {
    final map = <String, int>{};
    for (final doc in _documents) {
      map[doc.language] = (map[doc.language] ?? 0) + 1;
    }
    return map;
  }

  // This week count
  int get thisWeekCount {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _documents.where((d) => d.createdAt.isAfter(weekAgo)).length;
  }

  DocumentProvider() {
    _loadDocuments();
    // ✅ Whenever the user logs in (including app restart with a saved
    // session), pull their cloud documents so other devices' scans show up.
    fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) syncFromCloud();
    });
  }

  void _loadDocuments() {
    final box = Hive.box<DocumentModel>(AppConstants.documentsBox);
    _documents = box.values.toList().reversed.toList();
    notifyListeners();
  }

  // ===== Cloud sync (Firebase) =====
  // All of these are best-effort / fire-and-forget: if there's no
  // internet or the user isn't logged in, they fail silently and the
  // app just keeps working off the local Hive cache.

  /// Writes [doc]'s text/metadata to Firestore. Call after any local
  /// create/update. ✅ Images stay local-only (no Storage — that needs the
  /// paid Blaze plan) — only the extracted text and metadata sync.
  Future<void> _syncToCloud(DocumentModel doc) async {
    final collection = _cloudCollection;
    if (collection == null) return; // not logged in — local-only for now
    try {
      await collection.doc(doc.id).set(doc.toFirestoreMap());
    } catch (e) {
      debugPrint('⚠️ Cloud sync failed for ${doc.id} (kept locally): $e');
    }
  }

  Future<void> _deleteFromCloud(String docId) async {
    final collection = _cloudCollection;
    if (collection == null) return;
    try {
      await collection.doc(docId).delete();
    } catch (e) {
      debugPrint('⚠️ Cloud delete failed for $docId: $e');
    }
  }

  /// Pulls all documents for the signed-in user from Firestore and merges
  /// them into the local Hive cache (cloud copy wins on conflicts).
  /// Call on login and on pull-to-refresh for multi-device sync.
  Future<void> syncFromCloud() async {
    final collection = _cloudCollection;
    if (collection == null) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final snapshot = await collection.get();
      final box = Hive.box<DocumentModel>(AppConstants.documentsBox);
      final existingById = {
        for (final d in box.values) d.id: d,
      };

      for (final docSnap in snapshot.docs) {
        final cloudDoc = DocumentModel.fromFirestoreMap(docSnap.data());
        final local = existingById[cloudDoc.id];
        if (local == null) {
          // New document from the cloud — add to local cache.
          // Image downloads lazily (imageUrl is used directly for display).
          await box.add(cloudDoc);
        } else {
          // Merge: keep the local image path, take the cloud's text/meta.
          local
            ..title = cloudDoc.title
            ..extractedText = cloudDoc.extractedText
            ..category = cloudDoc.category
            ..isFavourite = cloudDoc.isFavourite
            ..isPinned = cloudDoc.isPinned
            ..highlights = cloudDoc.highlights
            ..imageUrl = cloudDoc.imageUrl ?? local.imageUrl
            ..blurredTypes = cloudDoc.blurredTypes;
          await local.save();
        }
      }
      _loadDocuments();
    } catch (e) {
      debugPrint('⚠️ syncFromCloud failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Copies a scanned image out of the OS temp/cache folder (where the
  /// camera, gallery picker, and image-enhance tool all write) into the
  /// app's permanent documents folder. Without this, [imagePath] points
  /// at a temp file the OS can delete anytime — the saved document's
  /// text stays in Hive, but its image silently disappears later.
  Future<String> _copyToPermanentStorage(String imagePath) async {
    final srcFile = File(imagePath);
    if (!await srcFile.exists()) return imagePath;

    final docsDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${docsDir.path}/scanned_documents');
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }

    final ext = p.extension(imagePath).isNotEmpty ? p.extension(imagePath) : '.jpg';
    final destPath =
        '${scansDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destFile = await srcFile.copy(destPath);
    return destFile.path;
  }

  Future<DocumentModel> saveDocument({
    required String title,
    required String extractedText,
    required String imagePath,
    required String language,
    String category = 'Other',
    List<String> blurredTypes = const <String>[],
  }) async {
    final box = Hive.box<DocumentModel>(AppConstants.documentsBox);
    // ✅ Move off the temp/cache path onto permanent storage first —
    // this is what actually keeps the image around long-term.
    final permanentImagePath = await _copyToPermanentStorage(imagePath);
    final doc = DocumentModel(
      id: const Uuid().v4(),
      title: title,
      extractedText: extractedText,
      imagePath: permanentImagePath,
      createdAt: DateTime.now(),
      language: language,
      category: category,
      blurredTypes: blurredTypes,
    );
    await box.add(doc);
    _loadDocuments();
    unawaited(_syncToCloud(doc)); // ✅ background cloud sync
    return doc;
  }

  /// Sets (or clears, with an empty list) which sensitive-info types stay
  /// hidden for [doc]. Persists so the blur shows up everywhere the
  /// document's text is displayed — not just the Privacy Blur screen.
  Future<void> setPrivacyBlur(DocumentModel doc, List<String> types) async {
    doc.blurredTypes = types;
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  Future<void> deleteDocument(String id) async {
    final box = Hive.box<DocumentModel>(AppConstants.documentsBox);
    final key = box.keys.firstWhere(
          (k) => (box.get(k) as DocumentModel).id == id,
      orElse: () => null,
    );
    if (key != null) await box.delete(key);
    _loadDocuments();
    unawaited(_deleteFromCloud(id)); // ✅ background cloud delete
  }

  /// Removes every saved document.
  Future<void> clearAll() async {
    final box = Hive.box<DocumentModel>(AppConstants.documentsBox);
    final ids = box.values.map((d) => d.id).toList();
    await box.clear();
    _loadDocuments();
    for (final id in ids) {
      unawaited(_deleteFromCloud(id)); // ✅ background cloud delete
    }
  }

  Future<void> toggleFavourite(DocumentModel doc) async {
    doc.isFavourite = !doc.isFavourite;
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  Future<void> togglePin(DocumentModel doc) async {
    doc.isPinned = !doc.isPinned;
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  /// Rename a saved document to a custom title.
  Future<void> renameDocument(DocumentModel doc, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    doc.title = trimmed;
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  /// Adds a manual highlight for the given [start, end) character range
  /// (offsets into `doc.extractedText`), merging with any existing
  /// overlapping/adjacent ranges so highlights don't fragment.
  Future<void> addHighlightRange(DocumentModel doc, int start, int end) async {
    if (end <= start) return;
    final ranges = _rangesFromFlat(doc.highlights);
    ranges.add(_Range(start, end));
    doc.highlights = _flattenRanges(_mergeRanges(ranges));
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  /// Removes any highlight range(s) that overlap [start, end).
  /// Used when the user taps an existing highlight to un-highlight it.
  Future<void> removeHighlightRange(DocumentModel doc, int start, int end) async {
    final ranges = _rangesFromFlat(doc.highlights);
    final result = <_Range>[];
    for (final r in ranges) {
      if (r.end <= start || r.start >= end) {
        // No overlap — keep as-is.
        result.add(r);
        continue;
      }
      // Overlaps — keep the non-overlapping remainder(s), if any.
      if (r.start < start) result.add(_Range(r.start, start));
      if (r.end > end) result.add(_Range(end, r.end));
    }
    doc.highlights = _flattenRanges(result);
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  /// Remove all highlights from a document.
  Future<void> clearHighlights(DocumentModel doc) async {
    doc.highlights = <int>[];
    await doc.save();
    _loadDocuments();
    unawaited(_syncToCloud(doc));
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // ===== Highlight range helpers =====
  // Ranges are persisted as a flattened List<int> [start0, end0, start1, end1, ...]
  // — no Hive schema change needed since the field is still List<int>.

  List<_Range> _rangesFromFlat(List<int> flat) {
    final ranges = <_Range>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      ranges.add(_Range(flat[i], flat[i + 1]));
    }
    return ranges;
  }

  List<int> _flattenRanges(List<_Range> ranges) {
    final flat = <int>[];
    for (final r in ranges) {
      flat.add(r.start);
      flat.add(r.end);
    }
    return flat;
  }

  /// Sorts and merges overlapping/adjacent ranges into a minimal set.
  List<_Range> _mergeRanges(List<_Range> ranges) {
    if (ranges.isEmpty) return ranges;
    final sorted = List<_Range>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Range>[sorted.first];
    for (final r in sorted.skip(1)) {
      final last = merged.last;
      if (r.start <= last.end) {
        merged[merged.length - 1] =
            _Range(last.start, r.end > last.end ? r.end : last.end);
      } else {
        merged.add(r);
      }
    }
    return merged;
  }
}

/// Simple [start, end) character-offset range used for text highlights.
class _Range {
  final int start;
  final int end;
  const _Range(this.start, this.end);
}