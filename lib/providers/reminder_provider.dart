import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:document_lens/models/reminder_model.dart';
import 'package:document_lens/services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  static const String _remindersBox = 'reminders';
  List<ReminderModel> _reminders = [];

  List<ReminderModel> get reminders => _reminders;

  List<ReminderModel> get pendingReminders => _reminders
      .where((r) =>
  !r.isCompleted && r.reminderDate.isAfter(DateTime.now()))
      .toList()
    ..sort((a, b) => a.reminderDate.compareTo(b.reminderDate));

  List<ReminderModel> get completedReminders =>
      _reminders.where((r) => r.isCompleted).toList();

  List<ReminderModel> get overdueReminders => _reminders
      .where((r) =>
  !r.isCompleted && r.reminderDate.isBefore(DateTime.now()))
      .toList();

  ReminderProvider() {
    _loadReminders();
  }

  void _loadReminders() {
    final box = Hive.box<ReminderModel>(_remindersBox);
    _reminders = box.values.toList()
      ..sort((a, b) => a.reminderDate.compareTo(b.reminderDate));
    notifyListeners();
  }

  // Add reminder
  Future<void> addReminder({
    required String title,
    required String description,
    required DateTime reminderDate,
    required String documentTitle,
  }) async {
    final box = Hive.box<ReminderModel>(_remindersBox);
    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;

    final reminder = ReminderModel(
      id: const Uuid().v4(),
      title: title,
      description: description,
      reminderDate: reminderDate,
      documentTitle: documentTitle,
      notificationId: notifId,
    );

    await box.add(reminder);

    // Schedule notification — not on web
    if (!reminderDate.isBefore(DateTime.now())) {
      try {
        await NotificationService.scheduleNotification(
          id: notifId,
          title: '📄 $title',
          body: description,
          scheduledDate: reminderDate,
        );
      } catch (_) {}
    }

    _loadReminders();
  }

  // Mark complete
  Future<void> markComplete(ReminderModel reminder) async {
    reminder.isCompleted = true;
    await reminder.save();
    await NotificationService.cancelNotification(
        reminder.notificationId);
    _loadReminders();
  }

  // Undo complete — move back to pending
  Future<void> markIncomplete(ReminderModel reminder) async {
    reminder.isCompleted = false;
    await reminder.save();

    // Re-schedule notification if the reminder time is still upcoming
    if (reminder.reminderDate.isAfter(DateTime.now())) {
      try {
        await NotificationService.scheduleNotification(
          id: reminder.notificationId,
          title: '📄 ${reminder.title}',
          body: reminder.description,
          scheduledDate: reminder.reminderDate,
        );
      } catch (_) {}
    }

    _loadReminders();
  }

  // Delete reminder
  Future<void> deleteReminder(ReminderModel reminder) async {
    await NotificationService.cancelNotification(
        reminder.notificationId);
    await reminder.delete();
    _loadReminders();
  }

  // Update reminder
  Future<void> updateReminder(
      ReminderModel reminder,
      DateTime newDate,
      ) async {
    await NotificationService.cancelNotification(
        reminder.notificationId);
    reminder.reminderDate = newDate;
    await reminder.save();

    try {
      await NotificationService.scheduleNotification(
        id: reminder.notificationId,
        title: '📄 ${reminder.title}',
        body: reminder.description,
        scheduledDate: newDate,
      );
    } catch (_) {}

    _loadReminders();
  }
}