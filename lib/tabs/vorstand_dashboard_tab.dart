import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';

class VorstandDashboardTab extends StatefulWidget {
  const VorstandDashboardTab({super.key});

  @override
  State<VorstandDashboardTab> createState() => _VorstandDashboardTabState();
}

class MonthlyStat {
  final String label;
  final int registrations;
  final int memberships;

  MonthlyStat({
    required this.label,
    required this.registrations,
    required this.memberships,
  });
}

class _VorstandDashboardTabState extends State<VorstandDashboardTab> {
  int memberCount = 0;
  int appRegistrationCount = 0;
  bool isLoading = true;
  List<MonthlyStat> monthlyStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final users = await pb.collection('users').getFullList(sort: 'created');
      final now = DateTime.now();
      final months = <String, MonthlyStat>{};

      for (var offset = 5; offset >= 0; offset--) {
        final month = DateTime(now.year, now.month - offset, 1);
        final key = '${month.year}-${month.month}';
        final label = DateFormat('MMM', 'de_DE').format(month);
        months[key] = MonthlyStat(
          label: label,
          registrations: 0,
          memberships: 0,
        );
      }

      var memberships = 0;
      for (final user in users) {
        final createdValue = user.getStringValue('created');
        if (createdValue.isEmpty) continue;

        DateTime created;
        try {
          created = DateTime.parse(createdValue).toLocal();
        } catch (_) {
          continue;
        }

        final bucketKey = '${created.year}-${created.month}';
        final bucket = months[bucketKey];
        if (bucket == null) continue;

        months[bucketKey] = MonthlyStat(
          label: bucket.label,
          registrations: bucket.registrations + 1,
          memberships:
              bucket.memberships + (user.getBoolValue('membership') ? 1 : 0),
        );

        if (user.getBoolValue('membership')) {
          memberships += 1;
        }
      }

      setState(() {
        appRegistrationCount = users.length;
        memberCount = memberships;
        monthlyStats = months.values.toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler Dashboard: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildLineChart(String title, Color color, List<int> values) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _LineChartPainter(values: values, color: color),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: monthlyStats.map((stat) {
            return Expanded(
              child: Text(
                stat.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCharts() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildLineChart(
              'App-Anmeldungen',
              Colors.blue.shade600,
              monthlyStats.map((stat) => stat.registrations).toList(),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildLineChart(
              'Mitgliedschaften',
              Colors.green.shade600,
              monthlyStats.map((stat) => stat.memberships).toList(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Übersicht",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.group,
                          size: 40,
                          color: Colors.green,
                        ),
                        title: const Text("Mitglieder aktuell"),
                        trailing: Text(
                          "$memberCount",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildLineChart(
                          'Mitgliedschaften',
                          Colors.green.shade600,
                          monthlyStats.map((stat) => stat.memberships).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.login,
                          color: Colors.blue,
                          size: 40,
                        ),
                        title: const Text("App-Anmeldungen aktuell"),
                        trailing: Text(
                          "$appRegistrationCount",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildLineChart(
                          'App-Anmeldungen',
                          Colors.blue.shade600,
                          monthlyStats
                              .map((stat) => stat.registrations)
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final maxValue = values.reduce(max).toDouble();
    final minValue = values.reduce(min).toDouble();
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;

    final stepX = size.width / (values.length - 1).clamp(1, values.length - 1);
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - ((values[i] - minValue) / range) * size.height;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    final circlePaint = Paint()..color = color;
    for (final point in points) {
      canvas.drawCircle(point, 4, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
