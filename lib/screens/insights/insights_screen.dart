import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';
import 'package:document_lens/models/document_model.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _selectedTab = 0; // 0: Overview, 1: Trends, 2: Categories, 3: Activity

  final List<String> _tabs = const [
    'Overview',
    'Trends',
    'Categories',
    'Activity',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docProvider = context.watch<DocumentProvider>();

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TabSelector(
                tabs: _tabs,
                selectedIndex: _selectedTab,
                onSelected: (i) => setState(() => _selectedTab = i),
              ),
              const SizedBox(height: 16),
              if (_selectedTab == 0) ..._buildOverviewTab(docProvider),
              if (_selectedTab == 1) ..._buildTrendsTab(docProvider),
              if (_selectedTab == 2) ..._buildCategoriesTab(docProvider),
              if (_selectedTab == 3) ..._buildActivityTab(docProvider),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverviewTab(DocumentProvider docProvider) {
    return [
      _DocumentStatisticsCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _ScanActivityCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _StorageUsageCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _RecentScansCard(docProvider: docProvider),
    ];
  }

  List<Widget> _buildTrendsTab(DocumentProvider docProvider) {
    return [
      _TrendsCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _ScanActivityCard(docProvider: docProvider),
    ];
  }

  List<Widget> _buildCategoriesTab(DocumentProvider docProvider) {
    return [
      _DocumentStatisticsCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _CategoryBreakdownCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _LanguageBreakdownCard(docProvider: docProvider),
    ];
  }

  List<Widget> _buildActivityTab(DocumentProvider docProvider) {
    return [
      _ScanActivityCard(docProvider: docProvider),
      const SizedBox(height: 16),
      _ActivityTimelineCard(docProvider: docProvider),
    ];
  }
}

// ----------------- Tab Selector -----------------
class _TabSelector extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _TabSelector({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ----------------- Document Statistics -----------------
class _DocumentStatisticsCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _DocumentStatisticsCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = docProvider.totalDocuments;
    final categoryCount = docProvider.categoryCount;

    // Map categories to colors similar to the reference design
    final categoryColors = <String, Color>{
      'Receipt': const Color(0xFFE53935), // red - "PDF Files"
      'Notes': const Color(0xFF43A047), // green
      'ID Card': const Color(0xFFFB8C00), // orange
      'Letter': const Color(0xFF7E57C2), // purple - images
      'Other': const Color(0xFF42A5F5), // blue
    };

    final segments = categoryCount.entries
        .where((e) => e.value > 0)
        .map((e) => _PieSegment(
      label: e.key,
      value: e.value,
      color: categoryColors[e.key] ?? Colors.grey,
    ))
        .toList();

    // Calculate "new this week" stats
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final newThisWeek =
        docProvider.documents.where((d) => d.createdAt.isAfter(weekAgo)).length;
    final newLastMonth = docProvider.documents
        .where((d) =>
    d.createdAt.isAfter(monthAgo) && d.createdAt.isBefore(weekAgo))
        .length;

    double growth = 0;
    if (newLastMonth > 0) {
      growth = ((newThisWeek - newLastMonth) / newLastMonth) * 100;
    } else if (newThisWeek > 0) {
      growth = 100;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Document Statistics',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                'This Month',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Pie chart with center label
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        sections: segments.isEmpty
                            ? [
                          PieChartSectionData(
                            value: 1,
                            color: Colors.grey.withValues(alpha: 0.2),
                            showTitle: false,
                            radius: 22,
                          ),
                        ]
                            : segments
                            .map((s) => PieChartSectionData(
                          value: s.value.toDouble(),
                          color: s.color,
                          showTitle: false,
                          radius: 22,
                        ))
                            .toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Documents',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend + Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '+$newThisWeek',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Total Documents',
                      style:
                      TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          growth >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 14,
                          color: growth >= 0 ? Colors.green : Colors.red,
                        ),
                        Text(
                          '${growth.abs().toStringAsFixed(0)}% vs last month',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: growth >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend grid
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: total == 0
                ? [
              Text(
                'No documents yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ]
                : segments.map((s) {
              final pct = total > 0
                  ? ((s.value / total) * 100).toStringAsFixed(0)
                  : '0';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.value} ${s.label} ($pct%)',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PieSegment {
  final String label;
  final int value;
  final Color color;
  _PieSegment({required this.label, required this.value, required this.color});
}

// ----------------- Scan Activity -----------------
class _ScanActivityCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _ScanActivityCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Build last 7 days counts (Mon..Sun aligned like reference, but using last 7 days)
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final counts = days
        .map((d) => docProvider.documents
        .where((doc) =>
    doc.createdAt.year == d.year &&
        doc.createdAt.month == d.month &&
        doc.createdAt.day == d.day)
        .length)
        .toList();

    final todayCount = counts.last;
    final weekTotal = counts.fold(0, (a, b) => a + b);
    final monthTotal = docProvider.documents
        .where((d) => d.createdAt
        .isAfter(now.subtract(const Duration(days: 30))))
        .length;

    final maxY = (counts.reduce((a, b) => a > b ? a : b) + 1).toDouble();
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scan Activity',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                'This Week',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ActivityMetric(
                  icon: Icons.calendar_today_rounded,
                  label: 'Today',
                  value: '$todayCount',
                  color: AppTheme.primaryBlue),
              const SizedBox(width: 24),
              _ActivityMetric(
                  icon: Icons.bar_chart_rounded,
                  label: 'This Week',
                  value: '$weekTotal',
                  color: Colors.green),
              const SizedBox(width: 24),
              _ActivityMetric(
                  icon: Icons.trending_up_rounded,
                  label: 'This Month',
                  value: '$monthTotal',
                  color: Colors.orange),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayLabels[idx],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: idx == 6
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final isToday = i == 6;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: isToday
                            ? AppTheme.primaryBlue
                            : AppTheme.primaryBlue.withValues(alpha: 0.35),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                    showingTooltipIndicators:
                    counts[i] > 0 && isToday ? [0] : [],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ActivityMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ----------------- Storage Usage -----------------
class _StorageUsageCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _StorageUsageCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Estimate storage from actual image file sizes on disk
    int totalBytes = 0;
    for (final doc in docProvider.documents) {
      if (doc.imagePath.isNotEmpty) {
        final file = File(doc.imagePath);
        if (file.existsSync()) {
          try {
            totalBytes += file.lengthSync();
          } catch (_) {}
        }
      }
    }

    const totalLimitBytes = 1024 * 1024 * 1024; // 1 GB
    final usedMb = totalBytes / (1024 * 1024);
    final usedPct = (totalBytes / totalLimitBytes * 100).clamp(0, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Storage Usage',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                'This Month',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: usedPct / 100,
                        strokeWidth: 8,
                        backgroundColor:
                        AppTheme.primaryBlue.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.primaryBlue),
                      ),
                    ),
                    Text(
                      '${usedPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Used',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${usedMb.toStringAsFixed(usedMb < 10 ? 1 : 0)} MB',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'of 1 GB',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------- Recent Scans -----------------
class _RecentScansCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _RecentScansCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recent = docProvider.documents.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Scans',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/history'),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No scans yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...recent.map((doc) => _RecentScanRow(document: doc)),
        ],
      ),
    );
  }
}

class _RecentScanRow extends StatelessWidget {
  final DocumentModel document;
  const _RecentScanRow({required this.document});

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Receipt':
        return Icons.receipt_long_rounded;
      case 'Notes':
        return Icons.note_rounded;
      case 'ID Card':
        return Icons.badge_rounded;
      case 'Letter':
        return Icons.mail_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'Receipt':
        return const Color(0xFFE53935);
      case 'Notes':
        return const Color(0xFF43A047);
      case 'ID Card':
        return const Color(0xFFFB8C00);
      case 'Letter':
        return const Color(0xFF7E57C2);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $period';
  }

  String _sizeLabel(DocumentModel doc) {
    if (doc.imagePath.isEmpty) return '';
    final file = File(doc.imagePath);
    if (!file.existsSync()) return '';
    try {
      final bytes = file.lengthSync();
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(document.category);
    final size = _sizeLabel(document);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconForCategory(document.category),
                color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(document.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (size.isNotEmpty)
            Text(
              size,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500]),
            ),
          const SizedBox(width: 6),
          Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }
}

// ----------------- Trends -----------------
class _TrendsCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _TrendsCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Last 6 weeks, weekly buckets
    final weekLabels = <String>[];
    final weekCounts = <int>[];
    for (int i = 5; i >= 0; i--) {
      final end = now.subtract(Duration(days: 7 * i));
      final start = end.subtract(const Duration(days: 6));
      final count = docProvider.documents
          .where((d) =>
      !d.createdAt.isBefore(
          DateTime(start.year, start.month, start.day)) &&
          d.createdAt.isBefore(
              DateTime(end.year, end.month, end.day + 1)))
          .length;
      weekCounts.add(count);
      weekLabels.add('${start.day}/${start.month}');
    }

    final maxY =
    (weekCounts.isEmpty ? 1 : weekCounts.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);

    final totalScanned = docProvider.totalDocuments;
    final avgPerWeek = weekCounts.isEmpty
        ? 0.0
        : weekCounts.reduce((a, b) => a + b) / weekCounts.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scanning Trend',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                'Last 6 Weeks',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TrendMetric(
                  label: 'Total Scanned',
                  value: '$totalScanned',
                  icon: Icons.description_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrendMetric(
                  label: 'Weekly Average',
                  value: avgPerWeek.toStringAsFixed(1),
                  icon: Icons.show_chart_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: totalScanned == 0
                ? Center(
              child: Text(
                'No documents yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
                : LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY + 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= weekLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            weekLabels[idx],
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey[500]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      weekCounts.length,
                          (i) => FlSpot(i.toDouble(), weekCounts[i].toDouble()),
                    ),
                    isCurved: true,
                    color: AppTheme.primaryBlue,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TrendMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ----------------- Category Breakdown -----------------
class _CategoryBreakdownCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _CategoryBreakdownCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryCount = docProvider.categoryCount;
    final total = docProvider.totalDocuments;

    final categoryColors = <String, Color>{
      'Receipt': const Color(0xFFE53935),
      'Notes': const Color(0xFF43A047),
      'ID Card': const Color(0xFFFB8C00),
      'Letter': const Color(0xFF7E57C2),
      'Other': const Color(0xFF42A5F5),
    };

    final categoryIcons = <String, IconData>{
      'Receipt': Icons.receipt_long_rounded,
      'Notes': Icons.note_rounded,
      'ID Card': Icons.badge_rounded,
      'Letter': Icons.mail_rounded,
      'Other': Icons.description_rounded,
    };

    final entries = categoryCount.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No documents yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...entries.map((e) {
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              final color = categoryColors[e.key] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                          categoryIcons[e.key] ?? Icons.description_rounded,
                          color: color,
                          size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text('${e.value} (${pct.toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? e.value / total : 0,
                              minHeight: 6,
                              backgroundColor:
                              color.withValues(alpha: 0.1),
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ----------------- Language Breakdown -----------------
class _LanguageBreakdownCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _LanguageBreakdownCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langCount = docProvider.languageCount;
    final entries = langCount.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Languages Scanned',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No documents yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.key[0].toUpperCase() + e.key.substring(1),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ----------------- Activity Timeline -----------------
class _ActivityTimelineCard extends StatelessWidget {
  final DocumentProvider docProvider;
  const _ActivityTimelineCard({required this.docProvider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docs = docProvider.documents;

    final pinnedCount = docs.where((d) => d.isPinned).length;
    final favouriteCount = docProvider.favourites.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Overview',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TrendMetric(
                  label: 'Pinned',
                  value: '$pinnedCount',
                  icon: Icons.push_pin_rounded,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrendMetric(
                  label: 'Favourites',
                  value: '$favouriteCount',
                  icon: Icons.favorite_rounded,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'All Scans',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No scans yet',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...docs.take(10).map((doc) => _RecentScanRow(document: doc)),
        ],
      ),
    );
  }
}