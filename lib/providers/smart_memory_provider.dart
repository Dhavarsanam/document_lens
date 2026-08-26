import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:document_lens/models/scan_memory_model.dart';

class SmartMemoryProvider extends ChangeNotifier {
  static const String _memoryBox = 'scan_memory';

  List<ScanMemoryModel> _memories = [];

  List<ScanMemoryModel> get memories => _memories;

  // Top 5 frequently scanned
  List<ScanMemoryModel> get frequentlyScanned {
    final sorted = List<ScanMemoryModel>.from(_memories)
      ..sort((a, b) => b.scanCount.compareTo(a.scanCount));
    return sorted.take(5).toList();
  }

  // Recent 5 scanned
  List<ScanMemoryModel> get recentlyScanned {
    final sorted = List<ScanMemoryModel>.from(_memories)
      ..sort((a, b) => b.lastScanned.compareTo(a.lastScanned));
    return sorted.take(5).toList();
  }

  // Smart suggestions — mix of frequent + recent
  List<ScanMemoryModel> get smartSuggestions {
    final Set<String> addedIds = {};
    final List<ScanMemoryModel> suggestions = [];

    // Add top 3 frequent
    for (final m in frequentlyScanned.take(3)) {
      if (!addedIds.contains(m.documentId)) {
        suggestions.add(m);
        addedIds.add(m.documentId);
      }
    }

    // Add top 2 recent (not already added)
    for (final m in recentlyScanned.take(3)) {
      if (!addedIds.contains(m.documentId) && suggestions.length < 5) {
        suggestions.add(m);
        addedIds.add(m.documentId);
      }
    }

    return suggestions;
  }

  // Category frequency
  Map<String, int> get categoryFrequency {
    final map = <String, int>{};
    for (final m in _memories) {
      map[m.category] = (map[m.category] ?? 0) + m.scanCount;
    }
    return map;
  }

  // Most used category
  String get mostUsedCategory {
    if (categoryFrequency.isEmpty) return 'Notes';
    return categoryFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  SmartMemoryProvider() {
    _loadMemories();
  }

  void _loadMemories() {
    final box = Hive.box<ScanMemoryModel>(_memoryBox);
    _memories = box.values.toList();
    notifyListeners();
  }

  // ✅ Track scan — called when document saved
  Future<void> trackScan({
    required String documentId,
    required String title,
    required String category,
    required String imagePath,
  }) async {
    final box = Hive.box<ScanMemoryModel>(_memoryBox);

    // Check if already tracked
    ScanMemoryModel? existing;
    dynamic existingKey;

    for (final key in box.keys) {
      final m = box.get(key) as ScanMemoryModel;
      if (m.documentId == documentId) {
        existing = m;
        existingKey = key;
        break;
      }
    }

    if (existing != null) {
      // Update existing
      existing.scanCount += 1;
      existing.lastScanned = DateTime.now();
      await existing.save();
    } else {
      // Add new memory
      final memory = ScanMemoryModel(
        documentId: documentId,
        title: title,
        category: category,
        scanCount: 1,
        lastScanned: DateTime.now(),
        imagePath: imagePath,
      );
      await box.add(memory);
    }

    _loadMemories();
  }

  // Remove memory
  Future<void> removeMemory(String documentId) async {
    final box = Hive.box<ScanMemoryModel>(_memoryBox);
    dynamic keyToDelete;
    for (final key in box.keys) {
      final m = box.get(key) as ScanMemoryModel;
      if (m.documentId == documentId) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) await box.delete(keyToDelete);
    _loadMemories();
  }

  // Clear all memories
  Future<void> clearAll() async {
    await Hive.box<ScanMemoryModel>(_memoryBox).clear();
    _loadMemories();
  }
}