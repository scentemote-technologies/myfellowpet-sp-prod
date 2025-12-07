// lib/widgets/revenue_chart.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../Colors/AppColor.dart';


/// Your brand’s primaryColor color

double _niceNum(double range, bool roundUp) {
  final exp = range == 0 ? 0 : (math.log(range) / math.ln10).floor();
  final frac = range / math.pow(10, exp);
  double nice;
  if (roundUp) {
    if (frac < 1.5) nice = 1;
    else if (frac < 3) nice = 2;
    else if (frac < 7) nice = 5;
    else nice = 10;
  } else {
    if (frac <= 1) nice = 1;
    else if (frac <= 2) nice = 2;
    else if (frac <= 5) nice = 5;
    else nice = 10;
  }
  return nice * math.pow(10, exp);
}

class RevenueChart extends StatefulWidget {
  final List<QueryDocumentSnapshot> data;
  const RevenueChart({Key? key, required this.data}) : super(key: key);

  @override
  _RevenueChartState createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  late List<DateTime> _months;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _initMonths();
  }

  void _initMonths() {
    final set = <DateTime>{};
    for (var doc in widget.data) {
      final ts = doc['completedAt'];
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
      set.add(DateTime(dt.year, dt.month));
    }
    _months = set.toList()..sort((a, b) => b.compareTo(a));
    if (_months.isNotEmpty) _selectedMonth = _months.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_months.isEmpty) {
      return Center(
        child: Text(
          'No revenue data available',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButtonFormField<DateTime>(
            decoration: InputDecoration(
              labelText: 'Select Month',
              labelStyle: GoogleFonts.poppins(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            value: _selectedMonth,
            items: _months
                .map((m) => DropdownMenuItem<DateTime>(
              value: m,
              child: Text(DateFormat('MMMM yyyy').format(m), style: GoogleFonts.poppins()),
            ))
                .toList(),
            onChanged: (v) => setState(() => _selectedMonth = v),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildChart(),
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    final revenueByDay = <DateTime, double>{};
    for (var doc in widget.data) {
      final ts = doc['completedAt'];
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
      if (dt.year == _selectedMonth!.year && dt.month == _selectedMonth!.month) {
        final cb = doc['cost_breakdown'] as Map<String, dynamic>? ?? {};
        final total = double.tryParse(cb['total_amount']?.toString() ?? '0') ?? 0.0;
        final day = DateTime(dt.year, dt.month, dt.day);
        revenueByDay[day] = (revenueByDay[day] ?? 0) + total;
      }
    }

    final first = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
    final last = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
    final days = List<DateTime>.generate(last.day, (i) => DateTime(first.year, first.month, i + 1));

    final spots = days
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), revenueByDay[e.value] ?? 0))
        .toList();

    // dynamic Y range
    final values = spots.map((e) => e.y).toList();
    final rawMin = values.reduce((a, b) => a < b ? a : b);
    final rawMax = values.reduce((a, b) => a > b ? a : b);
    // add 10% headroom so points never exceed axis
    final adjustedMax = rawMax * 1.1;
    final niceMin = rawMin <= 0 ? 0 : _niceNum(rawMin, false);
    final niceMax = _niceNum(adjustedMax, true);
    final span = niceMax - niceMin;
    const steps = 4;
    final interval = span / steps;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        minY: niceMin.toDouble(),
        maxY: niceMax.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.black54),
            bottom: BorderSide(color: Colors.black54),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 2.5,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                return SideTitleWidget(
                  meta: m,
                  child: Text(
                    '${days[i].day}',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (v, m) {
                return SideTitleWidget(
                  meta: m,
                  child: Text(
                    NumberFormat.compactCurrency(symbol: '₹').format(v),
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}