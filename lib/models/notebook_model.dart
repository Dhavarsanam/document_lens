import 'package:hive/hive.dart';

part 'notebook_model.g.dart';

@HiveType(typeId: 3)
class SubjectModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String colorHex;

  @HiveField(3)
  String emoji;

  @HiveField(4)
  final DateTime createdAt;

  SubjectModel({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.emoji,
    required this.createdAt,
  });
}

@HiveType(typeId: 4)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String content;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  int pageCount;

  NoteModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 1,
  });
}