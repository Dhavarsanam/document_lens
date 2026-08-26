import 'package:hive/hive.dart';

part 'reminder_model.g.dart';

@HiveType(typeId: 5)
class ReminderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime reminderDate;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  String documentTitle;

  @HiveField(6)
  int notificationId;

  ReminderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.reminderDate,
    required this.documentTitle,
    required this.notificationId,
    this.isCompleted = false,
  });
}