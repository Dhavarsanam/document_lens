import 'package:flutter/material.dart';
import 'package:document_lens/services/calendar_service.dart';

class ScanCalendarScreen extends StatefulWidget {
  final String extractedText;

  const ScanCalendarScreen({
    super.key,
    required this.extractedText,
  });

  @override
  State<ScanCalendarScreen> createState() =>
      _ScanCalendarScreenState();
}

class _ScanCalendarScreenState extends State<ScanCalendarScreen> {
  List<DetectedEvent> _events = [];
  bool _isScanning = false;
  Set<int> _addedEvents = {};

  @override
  void initState() {
    super.initState();
    _scanForDates();
  }

  Future<void> _scanForDates() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final events = CalendarService.detectEvents(widget.extractedText);
    setState(() {
      _events = events;
      _isScanning = false;
    });
  }

  Future<void> _addToCalendar(DetectedEvent event, int index) async {
    try {
      await CalendarService.addToCalendar(event);
      setState(() => _addedEvents.add(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Added: ${event.title}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open calendar. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addAllToCalendar() async {
    for (int i = 0; i < _events.length; i++) {
      if (!_addedEvents.contains(i)) {
        await CalendarService.addToCalendar(_events[i]);
        setState(() => _addedEvents.add(i));
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_events.length} events added to calendar!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to Calendar'),
        actions: [
          if (_events.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Add All',
                  style: TextStyle(color: Colors.white)),
              onPressed: _addAllToCalendar,
            ),
        ],
      ),
      body: _isScanning
          ? _buildScanningUI()
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              _buildStatusBanner(),

              const SizedBox(height: 20),

              if (_events.isEmpty) ...[
                // No dates found
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.event_busy_rounded,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No dates detected',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try scanning a document with dates\nlike exam schedules or timetables',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Events header
                Row(
                  children: [
                    const Icon(Icons.event_rounded,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_events.length} Event${_events.length > 1 ? 's' : ''} Detected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Events List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final isAdded = _addedEvents.contains(index);
                    final remaining =
                    CalendarService.daysRemaining(
                        event.dateTime);
                    final isPassed = remaining == 'Passed';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2130)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAdded
                              ? Colors.green.withValues(alpha: 0.4)
                              : isPassed
                              ? Colors.grey.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Event Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Date Circle
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isPassed
                                        ? Colors.grey.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${event.dateTime.day}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                          color: isPassed
                                              ? Colors.grey
                                              : Colors.green,
                                        ),
                                      ),
                                      Text(
                                        _shortMonth(event.dateTime.month),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isPassed
                                              ? Colors.grey
                                              : Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Event Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CalendarService.formatDate(
                                            event.dateTime),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Days remaining badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPassed
                                              ? Colors.grey.withValues(alpha: 0.1)
                                              : remaining == 'Today!' ||
                                              remaining == 'Tomorrow!'
                                              ? Colors.orange.withValues(alpha: 0.1)
                                              : Colors.green.withValues(alpha: 0.1),
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          remaining,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isPassed
                                                ? Colors.grey
                                                : remaining == 'Today!' ||
                                                remaining == 'Tomorrow!'
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Add button
                                GestureDetector(
                                  onTap: isAdded
                                      ? null
                                      : () => _addToCalendar(
                                      event, index),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isAdded
                                          ? Colors.green
                                          : Colors.green.withValues(alpha: 0.1),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAdded
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          color: isAdded
                                              ? Colors.white
                                              : Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isAdded ? 'Added' : 'Add',
                                          style: TextStyle(
                                            color: isAdded
                                                ? Colors.white
                                                : Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Original text
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                      Icons.format_quote_rounded,
                                      color: Colors.grey,
                                      size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      event.originalText,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Original Text
              const Text('Scanned Text',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2130)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.extractedText,
                  style: const TextStyle(
                      fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: Colors.green, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Scanning for dates...',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const CircularProgressIndicator(color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final count = _events.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: count > 0
              ? [const Color(0xFF00897B), const Color(0xFF00BCD4)]
              : [Colors.grey, Colors.blueGrey],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? '$count Date${count > 1 ? 's' : ''} Detected!'
                      : 'No Dates Found',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  count > 0
                      ? 'Tap Add to create calendar events'
                      : 'Scan a document with dates',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[month - 1];
  }
}