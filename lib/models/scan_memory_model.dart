import 'package:hive/hive.dart';

part 'scan_memory_model.g.dart';

@HiveType(typeId: 2)
class ScanMemoryModel extends HiveObject {
  @HiveField(0)
  final String documentId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String category;

  @HiveField(3)
  int scanCount; // how many times scanned

  @HiveField(4)
  DateTime lastScanned;

  @HiveField(5)
  final String imagePath;

  ScanMemoryModel({
    required this.documentId,
    required this.title,
    required this.category,
    required this.scanCount,
    required this.lastScanned,
    required this.imagePath,
  });
}