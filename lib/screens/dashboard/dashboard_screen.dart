import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:document_lens/providers/document_provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docProvider = context.watch<DocumentProvider>();
    final categoryData = docProvider.categoryCount;
    final langData = docProvider.languageCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.description_rounded,
                    label: 'Total Docs',
                    value: '${docProvider.totalDocuments}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.text_fields_rounded,
                    label: 'Total Words',
                    value: '${docProvider.totalWords}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'This Week',
                    value: '${docProvider.thisWeekCount}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.favorite_rounded,
                    label: 'Favourites',
                    value: '${docProvider.favourites.length}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Category Pie Chart
            if (categoryData.isNotEmpty) ...[
              const Text('Documents by Category',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    sections: _buildPieSections(categoryData),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLegend(categoryData),
            ],

            const SizedBox(height: 28),

            // Language Bar Chart
            if (langData.isNotEmpty) ...[
              const Text('Documents by Language',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: _buildBarGroups(langData),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final keys = langData.keys.toList();
                            if (value.toInt() < keys.length) {
                              return Text(keys[value.toInt()],
                                  style: const TextStyle(fontSize: 10));
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  ),
                ),
              ),
            ],

            // Empty state
            if (docProvider.totalDocuments == 0)
              const Center(
                child: Column(
                  children: [
                    SizedBox(height: 40),
                    Icon(Icons.bar_chart_rounded,
                        size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No data yet.\nScan documents to see stats!',
                        textAlign: TextAlign.center,
                        style:
                        TextStyle(color: Colors.grey, fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> data) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange,
      Colors.red, Colors.purple, Colors.teal,
    ];
    final entries = data.entries.toList();
    return List.generate(entries.length, (i) {
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: entries[i].value.toDouble(),
        title: '${entries[i].value}',
        radius: 55,
        titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white),
      );
    });
  }

  Widget _buildLegend(Map<String, int> data) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange,
      Colors.red, Colors.purple, Colors.teal,
    ];
    final entries = data.entries.toList();
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(entries.length, (i) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(entries[i].key,
                style: const TextStyle(fontSize: 12)),
          ],
        );
      }),
    );
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, int> data) {
    final entries = data.entries.toList();
    return List.generate(entries.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entries[i].value.toDouble(),
            color: AppTheme.primaryBlue,
            width: 20,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6)),
          ),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}