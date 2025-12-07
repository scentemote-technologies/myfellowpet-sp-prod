import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../Colors/AppColor.dart';

/// Your brand’s primaryColor color
typedef QueryDoc = QueryDocumentSnapshot;

class BookingTrendChart extends StatefulWidget {
  final List<QueryDoc> data;
  const BookingTrendChart({Key? key, required this.data}) : super(key: key);

  @override
  _BookingTrendChartState createState() => _BookingTrendChartState();
}

class _BookingTrendChartState extends State<BookingTrendChart> {
  late List<DateTime> _months;
  late List<int> _years;
  DateTime? _selectedMonth;
  int? _selectedYear;
  String _viewType = 'Monthly'; // Can be 'Monthly' or 'Yearly'

  @override
  void initState() {
    super.initState();
    _initDateLists();
  }

  void _initDateLists() {
    final monthSet = <DateTime>{};
    final yearSet = <int>{};
    for (var doc in widget.data) {
      final ts = doc['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
      monthSet.add(DateTime(dt.year, dt.month));
      yearSet.add(dt.year);
    }
    _months = monthSet.toList()..sort((a, b) => b.compareTo(a));
    _years = yearSet.toList()..sort((a, b) => b.compareTo(a));

    if (_months.isNotEmpty) _selectedMonth = _months.first;
    if (_years.isNotEmpty) _selectedYear = _years.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_months.isEmpty || _years.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24,vertical: 250),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // shrink-wrap to content
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: isMobile ? 64 : 96,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No bookings to display',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your booking history will appear here once available.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }


    // --- FIX: Wrap the entire page content in a SingleChildScrollView ---
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
children: [        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Text(
            'Booking Trend',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: bulletPointText('Daily/Monthly booking counts for the selected month/year.'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: bulletPointText('This chart only includes completed orders, not pending or cancelled requests.'),
        ),
        const SizedBox(height: 12),// Add padding at the bottom
        _buildPageContent(),
     ] ),
    );
  }

  Widget bulletPointText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 15, color: Colors.black87)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build the page content, making the main build method cleaner.
  Widget _buildPageContent() {
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Button for Mobile
        if (isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Center(
              child: ToggleButtons(
                isSelected: [_viewType == 'Monthly', _viewType == 'Yearly'],
                onPressed: (index) {
                  setState(() {
                    _viewType = index == 0 ? 'Monthly' : 'Yearly';
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: primaryColor,
                color: primaryColor,
                constraints: BoxConstraints(minHeight: 40, minWidth: (MediaQuery.of(context).size.width - 40) / 2),
                children: [
                  Text('Monthly Chart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text('Yearly Chart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 15),


        // Controls row: Month + Year selectors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isMobile
              ? (_viewType == 'Monthly'
              ? DropdownButtonFormField<DateTime>(
            decoration: InputDecoration(labelText: 'Select Month', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            value: _selectedMonth,
            items: _months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM yyyy').format(m), style: GoogleFonts.poppins()))).toList(),
            onChanged: (val) => setState(() => _selectedMonth = val),
          )
              : DropdownButtonFormField<int>(
            decoration: InputDecoration(labelText: 'Select Year', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            value: _selectedYear,
            items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: GoogleFonts.poppins()))).toList(),
            onChanged: (val) => setState(() => _selectedYear = val),
          ))
              : Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DateTime>(
                  decoration: InputDecoration(labelText: 'Select Month', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  value: _selectedMonth,
                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM yyyy').format(m), style: GoogleFonts.poppins()))).toList(),
                  onChanged: (val) => setState(() => _selectedMonth = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: 'Select Year', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  value: _selectedYear,
                  items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: GoogleFonts.poppins()))).toList(),
                  onChanged: (val) => setState(() => _selectedYear = val),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // --- FIX: Removed Expanded and used a fixed-height container for the chart area ---
        Container(
          height: isMobile ? 400 : 500, // Define height for the chart section
          padding: const EdgeInsets.fromLTRB(16, 30, 40, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isMobile) {
                // Mobile layout now shows one chart at a time
                return _viewType == 'Monthly'
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Bookings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(child: _buildMonthlyBarChart()),
                    const SizedBox(height: 12),
                    _buildAxisLabels(xLabel: 'Day of month', yLabel: 'Number of bookings'),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text('Yearly Bookings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(child: _buildYearlyBarChart()),
                    const SizedBox(height: 12),
                    _buildAxisLabels(xLabel: 'Month of year', yLabel: 'Number of bookings'),
                  ],
                );
              } else {
                // Desktop/Tablet layout
                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('Monthly Bookings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Expanded(child: _buildMonthlyBarChart()),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 32),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Yearly Bookings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Expanded(child: _buildYearlyBarChart()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 17, bottom: 12, left: 56, right: 16),
                      child: Row(
                        children: [
                          Expanded(child: _buildAxisLabels(xLabel: 'Day of month', yLabel: 'Number of bookings')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildAxisLabels(xLabel: 'Month of year', yLabel: 'Number of bookings')),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }
  Widget _buildAxisLabels({required String xLabel, required String yLabel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'X-axis: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: xLabel,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Y-axis: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: yLabel,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyBarChart() {
    // 1️⃣ Build the list of days in the selected month
    final firstDay = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
    final lastDay  = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0);
    final days     = List<DateTime>.generate(
      lastDay.day,
          (i) => DateTime(firstDay.year, firstDay.month, i + 1),
    );

    // 2️⃣ Initialize counts and ID lists
    final counts      = <DateTime, int>{for (var d in days) d: 0};
    final idsPerIndex = <int, List<String>>{ for (var i = 0; i < days.length; i++) i: [] };

    // 3️⃣ Fill them by iterating your data once
    for (var doc in widget.data) {
      final ts = doc['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
      if (dt.year == _selectedMonth!.year && dt.month == _selectedMonth!.month) {
        final dayKey    = DateTime(dt.year, dt.month, dt.day);
        counts[dayKey]  = counts[dayKey]! + 1;
        final groupIndex = dt.day - 1;
        idsPerIndex[groupIndex]!.add(doc.id);
      }
    }

    // 4️⃣ Convert to lists for the chart
    final values = days.map((d) => counts[d]!.toDouble()).toList();
    final labels = days.map((d) => DateFormat('dd').format(d)).toList();

    // 5️⃣ Build chart, passing your ID map
    return _buildBarChart(
      labels,
      values,
      idsPerGroup: idsPerIndex,
    );
  }


  Widget _buildYearlyBarChart() {
    // 1️⃣ Prepare labels for all 12 months
    final monthLabels = List<String>.generate(
      12,
          (i) => DateFormat('MMM').format(DateTime(0, i + 1)),
    );

    // 2️⃣ Initialize counts and ID lists
    final counts = <int, int>{ for (var m = 1; m <= 12; m++) m: 0 };
    final idsPerIndex = <int, List<String>>{
      for (var i = 0; i < 12; i++) i: [],
    };

    // 3️⃣ Fill them by iterating your data once
    for (var doc in widget.data) {
      final ts = doc['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
      if (dt.year == _selectedYear) {
        // increment count for this month
        counts[dt.month] = counts[dt.month]! + 1;
        // groupIndex = month - 1 (Jan→0, Dec→11)
        final groupIndex = dt.month - 1;
        idsPerIndex[groupIndex]!.add(doc.id);
      }
    }

    // 4️⃣ Convert counts to chart values
    final values = List<double>.generate(
      12,
          (i) => counts[i + 1]!.toDouble(),
    );

    // 5️⃣ Build chart, passing the IDs map
    return _buildBarChart(
      monthLabels,
      values,
      idsPerGroup: idsPerIndex,
    );
  }


  Widget _buildBarChart(
      List<String> xLabels,
      List<double> values, {
        required Map<int, List<String>> idsPerGroup,
      }) {
    // 1) Determine Y‑axis max & interval
    final maxY = values.fold<double>(0, (prev, y) => y > prev ? y : prev);
    const int ySteps = 5;
    final yInterval = (maxY / (ySteps - 1)).ceilToDouble();
    final dialogCtx = context;

    return LayoutBuilder(builder: (ctx, bc) {
      final availableWidth = bc.maxWidth;
      final count          = xLabels.length;
      final gap            = 18.0;  // px between bar‐groups
      // Compute raw barWidth and clamp to reasonable bounds:
      final rawBarWidth    = (availableWidth - (count - 1) * gap) / count;
      final barWidth       = rawBarWidth.clamp(12.0, 32.0);
      // Add some total horizontal padding so labels at edges have breathing room:
      final horizontalPadding = 40.0;
      // “Natural” content width before scrolling:
      final naturalWidth   = count * (barWidth + gap) + horizontalPadding;

      final scrollController = ScrollController();

      return Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: naturalWidth,
            height: 300,
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.start,
                    maxY: maxY + yInterval,
                    minY: 0,
                    groupsSpace: gap,
                    barGroups: List.generate(count, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(toY: values[i], width: barWidth, color: primaryColor),
                        ],
                      );
                    }),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.black54),
                        bottom: BorderSide(color: Colors.black54),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= xLabels.length) return const SizedBox();

                            final isMonthly = xLabels.length > 12;
                            final labelMinWidth = isMonthly ? 32.0 : barWidth;

                            return SideTitleWidget(
                              space: 4,
                              axisSide: meta.axisSide, // <-- ADD THIS LINE
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: labelMinWidth),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    xLabels[i],
                                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            if (value % yInterval != 0) return const SizedBox();
                            return SideTitleWidget(
                              axisSide: meta.axisSide, // <-- ADD THIS LINE
                              space: 4,
                              child: Text(
                                value.toInt().toString(),
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),

                    // ── Tooltip on hover showing count + IDs ──
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final count = rod.toY.toInt();
                          return BarTooltipItem(
                            'Count: $count',
                            TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),

                      // ── On‑tap popup listing the same IDs ──
                      touchCallback: (FlTouchEvent event, BarTouchResponse? resp) {
                        if (event is FlTapUpEvent && resp?.spot != null) {
                          final idx = resp!.spot!.touchedBarGroupIndex;
                          final ids = idsPerGroup[idx] ?? [];
                          showDialog(
                            context: dialogCtx, // page context
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white,
                              title: Text(
                                'Orders for ${xLabels[idx]}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              content: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: 300),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: ids.isNotEmpty
                                        ? List.generate(ids.length, (i) {
                                      final orderId = ids[i];
                                      return InkWell(
                                        hoverColor: Colors.grey.shade200,
                                        onTap: () {

                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                          child: Text(
                                            '${i + 1}. $orderId',
                                            style: GoogleFonts.poppins(fontSize: 14, color: primaryColor),
                                          ),
                                        ),
                                      );
                                    })
                                        : [
                                      Text(
                                        'No orders',
                                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(),
                                  child: Text('Close', style: GoogleFonts.poppins(color: primaryColor)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),

                    // ──────────────────────────────────────────────

                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}