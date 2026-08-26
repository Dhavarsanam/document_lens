import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/reminder_provider.dart';
import 'package:document_lens/models/reminder_model.dart';

class ReminderScreen extends StatefulWidget {
  final String? documentTitle;
  const ReminderScreen({super.key, this.documentTitle});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // If opened from a document's "Set Reminder" action, jump straight
    // into the add-reminder sheet pre-filled with that document's title.
    if (widget.documentTitle != null && widget.documentTitle!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAddReminderDialog(documentTitle: widget.documentTitle);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddReminderDialog({String? documentTitle}) {
    final titleController = TextEditingController(
        text: documentTitle != null ? 'Reminder: $documentTitle' : '');
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Add Reminder',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Reminder Title',
                  prefixIcon:
                  const Icon(Icons.notifications_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Date + Time picker
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              selectedTime.format(context),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quick reminder options
              const Text('Quick Set',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _QuickChip(
                      label: 'Tomorrow 9 AM',
                      onTap: () => setModalState(() {
                        selectedDate = DateTime.now()
                            .add(const Duration(days: 1));
                        selectedTime =
                        const TimeOfDay(hour: 9, minute: 0);
                      }),
                    ),
                    _QuickChip(
                      label: 'In 3 days',
                      onTap: () => setModalState(() {
                        selectedDate = DateTime.now()
                            .add(const Duration(days: 3));
                      }),
                    ),
                    _QuickChip(
                      label: 'Next week',
                      onTap: () => setModalState(() {
                        selectedDate = DateTime.now()
                            .add(const Duration(days: 7));
                      }),
                    ),
                    _QuickChip(
                      label: 'Tonight 8 PM',
                      onTap: () => setModalState(() {
                        selectedDate = DateTime.now();
                        selectedTime =
                        const TimeOfDay(hour: 20, minute: 0);
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Set Reminder'),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;

                    final reminderDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final provider = context.read<ReminderProvider>();
                    await provider.addReminder(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      reminderDate: reminderDateTime,
                      documentTitle: documentTitle ?? '',
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Reminder set!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderProvider = context.watch<ReminderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (reminderProvider.pendingReminders.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${reminderProvider.pendingReminders.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Overdue'),
                  if (reminderProvider.overdueReminders.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${reminderProvider.overdueReminders.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            const Tab(text: 'Done'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReminderList(
            reminders: reminderProvider.pendingReminders,
            emptyMessage: 'No pending reminders\nTap + to add one!',
            emptyIcon: Icons.notifications_none_rounded,
            onComplete: (r) =>
                reminderProvider.markComplete(r),
            onDelete: (r) =>
                reminderProvider.deleteReminder(r),
            isPending: true,
          ),
          _ReminderList(
            reminders: reminderProvider.overdueReminders,
            emptyMessage: 'No overdue reminders!',
            emptyIcon: Icons.check_circle_rounded,
            onComplete: (r) =>
                reminderProvider.markComplete(r),
            onDelete: (r) =>
                reminderProvider.deleteReminder(r),
            isPending: false,
            isOverdue: true,
          ),
          _ReminderList(
            reminders: reminderProvider.completedReminders,
            emptyMessage: 'No completed reminders yet',
            emptyIcon: Icons.task_alt_rounded,
            onComplete: (r) =>
                reminderProvider.markComplete(r),
            onDelete: (r) =>
                reminderProvider.deleteReminder(r),
            onUndo: (r) =>
                reminderProvider.markIncomplete(r),
            isPending: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Reminder'),
      ),
    );
  }
}

// Reminder List Widget
class _ReminderList extends StatelessWidget {
  final List<ReminderModel> reminders;
  final String emptyMessage;
  final IconData emptyIcon;
  final Function(ReminderModel) onComplete;
  final Function(ReminderModel) onDelete;
  final Function(ReminderModel)? onUndo;
  final bool isPending;
  final bool isOverdue;

  const _ReminderList({
    required this.reminders,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onComplete,
    required this.onDelete,
    this.onUndo,
    required this.isPending,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        final isDark =
            Theme.of(context).brightness == Brightness.dark;
        final daysLeft =
            reminder.reminderDate.difference(DateTime.now()).inDays;

        Color statusColor = Colors.blue;
        if (isOverdue) statusColor = Colors.red;
        if (reminder.isCompleted) statusColor = Colors.green;
        if (daysLeft == 0 || daysLeft == 1) statusColor = Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOverdue
                    ? Icons.warning_amber_rounded
                    : reminder.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.notifications_rounded,
                color: statusColor,
                size: 24,
              ),
            ),
            title: Text(
              reminder.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: reminder.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminder.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reminder.description,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(reminder.reminderDate),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOverdue
                            ? 'Overdue'
                            : reminder.isCompleted
                            ? 'Done'
                            : daysLeft == 0
                            ? 'Today!'
                            : daysLeft == 1
                            ? 'Tomorrow!'
                            : '$daysLeft days left',
                        style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPending || isOverdue)
                  GestureDetector(
                    onTap: () => onComplete(reminder),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.green, size: 18),
                    ),
                  ),
                if (onUndo != null)
                  GestureDetector(
                    onTap: () => onUndo!(reminder),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.undo_rounded,
                          color: Colors.orange, size: 18),
                    ),
                  ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onDelete(reminder),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $period';
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}