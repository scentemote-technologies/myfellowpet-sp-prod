import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../Colors/AppColor.dart';

class RequestsTrendChart extends StatefulWidget {
  final List<dynamic> cancelledRequests;
  const RequestsTrendChart({super.key, required this.cancelledRequests});

  @override
  State<RequestsTrendChart> createState() => _RequestsTrendChartState();
}

class _RequestsTrendChartState extends State<RequestsTrendChart> {

  late int selectedYear;
  late int selectedMonth;
  late List<int> availableYears;
  late List<int> availableMonths;

  // New variables to store unfiltered totals
  late int _unfilteredTotalMonthlyCancellations;
  late int _unfilteredTotalYearlyCancellations;

  final Map<String, String> cancellationReasonsMap = {
    'Service provider took too long to respond': 'sp_timeout',
    'Admin took too long to respond': 'admin_timeout',
    'Cost was too high': 'cost_high',
    'Change of plans': 'change_plans',
    'Other': 'other',
  };

  final Map<String, Color> reasonColors = {
    'sp_timeout': Colors.blue,
    'admin_timeout': Colors.red,
    'cost_high': Colors.orange,
    'change_plans': Colors.green,
    'other': Colors.purple,
  };

  // New state for selected reasons
  late Map<String, bool> selectedReasons;

  // Declare ScrollControllers here
  late ScrollController _monthlyChartScrollController;
  late ScrollController _yearlyChartScrollController;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    _extractAvailableDates();

    // Initialize selectedReasons with all true initially
    selectedReasons = {
      'all': true,
      for (var reason in cancellationReasonsMap.values) reason: true,
    };

    // Calculate initial unfiltered totals
    _updateUnfilteredTotals();

    // Initialize ScrollControllers
    _monthlyChartScrollController = ScrollController();
    _yearlyChartScrollController = ScrollController();
  }

  @override
  void dispose() {
    // Dispose ScrollControllers to prevent memory leaks
    _monthlyChartScrollController.dispose();
    _yearlyChartScrollController.dispose();
    super.dispose();
  }

  // New method to calculate unfiltered totals
  void _updateUnfilteredTotals() {
    final dailyDataUnfiltered = _aggregateData(year: selectedYear, month: selectedMonth, applyReasonFilter: false);
    final monthlyDataUnfiltered = _aggregateData(year: selectedYear, applyReasonFilter: false);

    _unfilteredTotalMonthlyCancellations = _calculateTotalCancellations(dailyDataUnfiltered, applyReasonFilter: false);
    _unfilteredTotalYearlyCancellations = _calculateTotalCancellations(monthlyDataUnfiltered, applyReasonFilter: false);
  }

  void _extractAvailableDates() {
    Set<int> years = {};
    Set<int> months = {};
    for (var doc in widget.cancelledRequests) {
      final timestamp = doc['timestamp'];
      if (timestamp != null) {
        final date = (timestamp as Timestamp).toDate();
        years.add(date.year);
        if (date.year == selectedYear) {
          months.add(date.month);
        }
      }
    }

    availableYears = years.toList()..sort();
    availableMonths = months.toList()..sort();
    // Ensure the selected month is valid for the selected year
    if (!availableMonths.contains(selectedMonth) && availableMonths.isNotEmpty) {
      selectedMonth = availableMonths.last;
    }
  }

  // ADD THIS NEW FUNCTION
  // REPLACE your old _buildBarChartData function with this one
  BarChartData _buildBarChartData(
      Map<String, Map<int, int>> reasonData, bool isMonthly) {
    List<BarChartGroupData> barGroups = [];
    final int maxX = isMonthly ? 12 : 31; // Determine the max value for the x-axis

    // --- THIS IS THE KEY CHANGE ---
    // Loop through every possible day or month from 1 to maxX
    for (int xValue = 1; xValue <= maxX; xValue++) {
      List<BarChartRodData> barRods = [];

      // This inner logic to build the rods for a specific day remains the same
      for (var reasonEntry in cancellationReasonsMap.entries) {
        final reasonKey = reasonEntry.value;
        if (_isReasonSelected(reasonKey)) {
          final count = reasonData[reasonKey]?[xValue] ?? 0;
          if (count > 0) {
            barRods.add(
              BarChartRodData(
                toY: count.toDouble(),
                color: reasonColors[reasonKey]!,
                width: 3, // Adjust bar width here
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            );
          }
        }
      }

      // Always add a BarChartGroupData for every xValue.
      // If barRods is empty, it will create a blank space on the chart.
      barGroups.add(
        BarChartGroupData(
          x: xValue,
          barRods: barRods,
        ),
      );
    }
    // --- END OF KEY CHANGE ---

    // The rest of the function (calculating maxY, titles, etc.) is the same
    final allYValues = reasonData.entries
        .where((entry) => _isReasonSelected(entry.key))
        .expand((entry) => entry.value.values)
        .where((value) => value != 0)
        .toList();

    double maxY = allYValues.isNotEmpty
        ? allYValues.reduce((a, b) => a > b ? a : b).toDouble()
        : 1;
    double interval = 1;
    if (maxY > 0) {
      if (maxY <= 5) {
        interval = 1;
        maxY = 5;
      } else {
        final double targetInterval = maxY / 4;
        interval = (targetInterval / 5).ceil() * 5.0;
        if (interval == 0) interval = 1;
        maxY = (maxY / interval).ceil() * interval;
      }
    } else {
      maxY = 1;
      interval = 1;
    }

    return BarChartData(
      barGroups: barGroups,
      alignment: BarChartAlignment.spaceAround,
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey[300], strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No of cancellations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          axisNameSize: 24,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value % interval == 0 && value >= 0) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isMonthly ? 'Month' : 'Day',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          axisNameSize: 24,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (isMonthly && value >= 1 && value <= 12) {
                return Text(
                  DateFormat.MMM().format(DateTime(0, value.toInt())),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                );
                // ... inside bottomTitles -> getTitlesWidget
              } else if (!isMonthly && value >= 1 && value <= 31) {
                // REMOVED THE IF CONDITION TO SHOW ALL DATES
                return Text(
                  value.toInt().toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final reasonName = cancellationReasonsMap.entries
                .firstWhere((e) => e.value == cancellationReasonsMap.values.firstWhere((r) => reasonColors[r] == rod.color))
                .key;
            return BarTooltipItem(
              '$reasonName\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: <TextSpan>[
                TextSpan(
                  text: (rod.toY.toInt()).toString(),
                  style: TextStyle(
                    color: rod.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Start of NEW/MODIFIED methods for unfiltered data details ---

  String _getBiggestReasonUnfiltered(Map<String, Map<int, int>> dataMap) {
    // Sum counts for each reason, considering ALL reasons (no filter)
    final Map<String, int> reasonTotals = {};

    for (var entry in dataMap.entries) {
      reasonTotals[entry.key] = entry.value.values.fold(0, (sum, count) => sum + count);
    }

    if (reasonTotals.isEmpty) return "N/A";

    final maxEntry = reasonTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final displayName = cancellationReasonsMap.entries
        .firstWhere((element) => element.value == maxEntry.key, orElse: () => const MapEntry('', ''))
        .key;

    return displayName;
  }

  String _getDayWithMostCancellationsUnfiltered(
      Map<String, Map<int, int>> data, int year, int month) {
    final dailyTotals = <int, int>{};
    for (var entry in data.entries) {
      // Count ALL reasons (no filter)
      for (var dayEntry in entry.value.entries) {
        dailyTotals[dayEntry.key] = (dailyTotals[dayEntry.key] ?? 0) + dayEntry.value;
      }
    }

    if (dailyTotals.isEmpty) return "N/A";

    final maxEntry = dailyTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final date = DateTime(year, month, maxEntry.key);
    return "${DateFormat('d MMMM y').format(date)} (${maxEntry.value} Bookings)";
  }

  String _getMonthWithMostCancellationsUnfiltered(Map<String, Map<int, int>> data, int year) {
    final monthlyTotals = <int, int>{};
    for (var entry in data.entries) {
      // Count ALL reasons (no filter)
      for (var monthEntry in entry.value.entries) {
        monthlyTotals[monthEntry.key] = (monthlyTotals[monthEntry.key] ?? 0) + monthEntry.value;
      }
    }

    if (monthlyTotals.isEmpty) return "N/A";

    final maxEntry = monthlyTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final date = DateTime(year, maxEntry.key);
    return "${DateFormat('MMMM y').format(date)} (${maxEntry.value} Bookings)";
  }

  // --- End of NEW/MODIFIED methods for unfiltered data details ---


  String _getBiggestReason(Map<String, Map<int, int>> dataMap) {
    // Sum counts for each reason, considering only selected reasons
    final Map<String, int> reasonTotals = {};

    for (var entry in dataMap.entries) {
      // Use containsKey to safely check before accessing, or handle the case where key might not exist in selectedReasons
      if (selectedReasons.containsKey(entry.key) && selectedReasons[entry.key] == false) continue;

      reasonTotals[entry.key] = entry.value.values.fold(0, (sum, count) => sum + count);
    }

    if (reasonTotals.isEmpty) return "N/A";

    // Find reason with max cancellations
    final maxEntry = reasonTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Find the display name from cancellationReasonsMap (reverse lookup)
    final displayName = cancellationReasonsMap.entries
        .firstWhere((element) => element.value == maxEntry.key, orElse: () => const MapEntry('', '')) // Added orElse to handle cases where key might not be found
        .key;

    return displayName;
  }

  Map<String, Map<int, int>> _aggregateData({required int year, int? month, bool applyReasonFilter = true}) {
    final isMonthly = month == null;
    final maxIndex = isMonthly ? 12 : 31;

    Map<String, Map<int, int>> result = {};
    for (String reason in cancellationReasonsMap.values) {
      result[reason] = {for (var i = 1; i <= maxIndex; i++) i: 0};
    }

    for (var doc in widget.cancelledRequests) {
      final timestamp = doc['timestamp'];
      if (timestamp == null) continue;
      final date = (timestamp as Timestamp).toDate();

      if (date.year == year && (isMonthly || date.month == month)) {
        final reasonMap = doc['cancellation_reason'] ?? {};
        reasonMap.forEach((key, value) {
          final reasonKey = cancellationReasonsMap[value];
          if (reasonKey != null) {
            // Apply reason filter here only if applyReasonFilter is true
            if (applyReasonFilter && !_isReasonSelected(reasonKey)) return;

            final index = isMonthly ? date.month : date.day;
            result[reasonKey]![index] = (result[reasonKey]![index] ?? 0) + 1;
          }
        });
      }
    }

    return result;
  }

  int _calculateTotalCancellations(Map<String, Map<int, int>> dataMap, {bool applyReasonFilter = true}) {
    // Sum all reasons or only selected reasons based on applyReasonFilter
    return dataMap.entries
        .where((entry) => applyReasonFilter ? _isReasonSelected(entry.key) : true)
        .expand((entry) => entry.value.values)
        .fold(0, (sum, count) => sum + count);
  }

  bool _isReasonSelected(String reasonKey) {
    // Check 'all' first, then individual reason
    if (selectedReasons['all'] == true) return true;
    return selectedReasons[reasonKey] ?? false; // Default to false if key doesn't exist
  }

  String _getDayWithMostCancellations(
      Map<String, Map<int, int>> data, int year, int month) {
    final dailyTotals = <int, int>{};
    for (var entry in data.entries) {
      if (!_isReasonSelected(entry.key)) continue; // Only count selected reasons
      for (var dayEntry in entry.value.entries) {
        dailyTotals[dayEntry.key] = (dailyTotals[dayEntry.key] ?? 0) + dayEntry.value;
      }
    }

    if (dailyTotals.isEmpty) return "N/A";

    final maxEntry = dailyTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final date = DateTime(year, month, maxEntry.key);
    return "${DateFormat('d MMMM y').format(date)} (${maxEntry.value} Bookings)";
  }

  String _getMonth(
      Map<String, Map<int, int>> data, int year, int month) {
    // This method is for displaying the current selected month in the title, not for finding a month with most cancellations.
    // It should just format the selectedMonth.
    return DateFormat('MMMM').format(DateTime(year, month));
  }

  String _getYear(
      Map<String, Map<int, int>> data, int year, int month) {
    // This method is for displaying the current selected year in the title, not for finding a year with most cancellations.
    // It should just format the selectedYear.
    return DateFormat('y').format(DateTime(year));
  }


  String _getMonthWithMostCancellations(Map<String, Map<int, int>> data, int year) {
    final monthlyTotals = <int, int>{};
    for (var entry in data.entries) {
      if (!_isReasonSelected(entry.key)) continue; // Only count selected reasons
      for (var monthEntry in entry.value.entries) {
        monthlyTotals[monthEntry.key] = (monthlyTotals[monthEntry.key] ?? 0) + monthEntry.value;
      }
    }

    if (monthlyTotals.isEmpty) return "N/A";

    final maxEntry = monthlyTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final date = DateTime(year, maxEntry.key);
    return "${DateFormat('MMMM y').format(date)} (${maxEntry.value} Bookings)";
  }

  List<FlSpot> _generateSpots(Map<int, int> dataMap) {
    return dataMap.entries
        .where((e) => e.value != 0)
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  LineChartData _buildLineChartData(
      Map<String, Map<int, int>> reasonData, bool isMonthly) {
    List<LineChartBarData> lines = [];

    for (var entry in reasonData.entries) {
      if (!_isReasonSelected(entry.key)) continue;
      final spots = _generateSpots(entry.value);
      if (spots.isNotEmpty) {
        lines.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2.5,
            dotData: FlDotData(show: true),
            color: reasonColors[entry.key],
          ),
        );
      }
    }

    final allYValues = reasonData.entries
        .where((entry) => _isReasonSelected(entry.key))
        .expand((entry) => entry.value.values)
        .where((value) => value != 0)
        .toList();

    double maxY = allYValues.isNotEmpty
        ? allYValues.reduce((a, b) => a > b ? a : b).toDouble()
        : 1; // Default to 1 if no data

    // Calculate dynamic maxY and interval
    double interval = 1;
    if (maxY > 0) {
      // Ensure at least 5 intervals
      if (maxY <= 5) {
        interval = 1;
        maxY = 5; // Ensure 0, 1, 2, 3, 4, 5
      } else {
        // Find a suitable interval to get around 5 points (0 included, so 4-5 steps)
        final double targetInterval = maxY / 4; // To get 5 points (0, x, 2x, 3x, 4x)
        if (targetInterval <= 1) {
          interval = 1;
        } else if (targetInterval <= 2) {
          interval = 2;
        } else if (targetInterval <= 5) {
          interval = 5;
        } else if (targetInterval <= 10) {
          interval = 10;
        } else if (targetInterval <= 25) {
          interval = 25;
        } else if (targetInterval <= 50) {
          interval = 50;
        } else {
          interval = (targetInterval / 10).ceil() * 10; // Round up to nearest 10
        }
        maxY = (maxY / interval).ceil() * interval; // Adjust maxY to be a multiple of the interval
      }
    } else {
      maxY = 1; // If maxY is 0, set it to 1 to show 0 and 1
      interval = 1;
    }

    return LineChartData(
      minX: 1,
      maxX: isMonthly ? 12 : 31,
      minY: 0,
      maxY: maxY, // Use the dynamically calculated maxY
      lineBarsData: lines,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval, // Use the dynamically calculated interval
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey[300], strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          left: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
          right: BorderSide(color: Colors.transparent),
          top: BorderSide(color: Colors.transparent),
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No of cancellations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          axisNameSize: 24,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: interval, // Use the dynamically calculated interval
            getTitlesWidget: (value, meta) {
              if (value % interval == 0 && value >= 0) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isMonthly ? 'Month' : 'Day',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          axisNameSize: 24,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              if (isMonthly && value >= 1 && value <= 12) {
                return Text(
                  DateFormat.MMM().format(DateTime(0, value.toInt())),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                );
              } else if (!isMonthly && value >= 1 && value <= 31) {
                return Text(
                  value.toInt().toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false, // Titles themselves are not shown
            reservedSize: isMonthly ? 50 : 0, // Reserve space only for yearly chart's tooltip
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      // --- Line Touch Data for Tooltips ---
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(8),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipMargin: 8,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              return LineTooltipItem(
                '${touchedSpot.y.toInt()}',
                TextStyle(
                  color: touchedSpot.bar.color,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((spotIndex) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: barData.color,
                strokeWidth: 2,
              ),
              FlDotData(
                show: true, // Ensure the dot is shown
              ),
            );
          }).toList();
        },
      ),

      // --- END Line Touch Data ---
    );
  }

  // to be flexible with placement.
  Widget _buildStaticLegend() {
    final isMobile = MediaQuery.of(context).size.width < 600; // breakpoint
    final legendItems = cancellationReasonsMap.entries.map((entry) {
      final reasonKey = entry.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: reasonColors[reasonKey],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              entry.key,
              style: GoogleFonts.poppins(fontSize: 11),
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: isMobile
          ? Column( // ✅ vertical in mobile
        crossAxisAlignment: CrossAxisAlignment.start,
        children: legendItems,
      )
          : SingleChildScrollView( // ✅ horizontal in tablet/desktop
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: legendItems,
        ),
      ),
    );
  }


  Widget _buildLegend() {
    final isMobile = MediaQuery.of(context).size.width < 600; // adjust breakpoint

    final legendItems = cancellationReasonsMap.entries.map((entry) {
      final reasonKey = entry.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.7,
            child: Checkbox(
              value: selectedReasons[reasonKey],
              onChanged: (val) {
                setState(() {
                  selectedReasons[reasonKey] = val ?? false;
                  selectedReasons['all'] = cancellationReasonsMap.values
                      .every((key) => selectedReasons[key] == true);
                });
              },
              activeColor: primaryColor,
              visualDensity: const VisualDensity(horizontal: -4.0, vertical: -4.0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Text(
            entry.key,
            style: GoogleFonts.poppins(fontSize: 11.5),
          ),
          if (!isMobile) const SizedBox(width: 8), // spacing only for horizontal layout
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isMobile
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: legendItems
              .map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: item,
          ))
              .toList(),
        )
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: legendItems),
        ),
      ],
    );
  }

  Widget _buildChartCard({required Widget titleWidget, required Widget chartChild, required String totalcount, required String mostCancellationHappenedOnIn, required String mostFrequentReason, required ScrollController scrollController}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F4F9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RESPONSIVE CHANGE: Replaced Row with Wrap to allow title and total to stack on narrow screens.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8.0, // Vertical spacing when items wrap
            children: [
              titleWidget,
              Row(
                children: [
                  // Left widget (if any), or leave empty
                  Spacer(),
                  Text(
                    "Total cancellations: $totalcount",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "MOST CANCELLATION HAPPENED: ",
                        ),
                        TextSpan(
                          text: mostCancellationHappenedOnIn,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: "MOST FREQUENT REASON: "),
                        TextSpan(
                          text: mostFrequentReason,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.black,
                      ),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9), // Spacing after the details box

          // The scrollable chart area. The use of SingleChildScrollView with a sized box
          // is a deliberate and effective pattern for showing dense data charts on any screen size.
          ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.all(Colors.grey[700]),
              trackColor: MaterialStateProperty.all(Colors.grey[300]),
              thickness: MaterialStateProperty.all(8.0),
              radius: const Radius.circular(10),
            ),
            child: Scrollbar(
              controller: scrollController, // Assign the passed controller
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true, // Enable dragging of the thumb itself
              child: SingleChildScrollView(
                controller: scrollController, // Assign the passed controller
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 20.0),
                  child: SizedBox(
                    // This logic ensures the chart has enough space to be readable,
                    // creating a scrollable area on smaller screens.
                    width: MediaQuery.of(context).size.width < 600
                        ? 600
                        : MediaQuery.of(context).size.width * 0.9,
                    height: 200, // Increased height for chart content
                    child: chartChild, // Use chartChild here
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16), // Spacing before the legend
          _buildStaticLegend(), // Place the static legend here
        ],
      ),
    );
  }

  // RESPONSIVE CHANGE: Removed SizedBox wrapper. The parent LayoutBuilder will handle sizing.
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
      dropdownColor: Colors.white,
      onChanged: onChanged,
      items: items.map((T item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item is int && label.contains('Month') // Assuming type is int for month dropdown
                ? DateFormat.MMMM().format(DateTime(0, item))
                : item.toString(),
            style: GoogleFonts.poppins(),
          ),
        );
      }).toList(),
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

  @override
  Widget build(BuildContext context) {
    // These data maps will respect the reason filters for the chart and other statistics
    final dailyData = _aggregateData(year: selectedYear, month: selectedMonth);
    final monthlyData = _aggregateData(year: selectedYear);

    // Data for the unfiltered details box
    final dailyDataUnfilteredForDetails = _aggregateData(year: selectedYear, month: selectedMonth, applyReasonFilter: false);
    final monthlyDataUnfilteredForDetails = _aggregateData(year: selectedYear, applyReasonFilter: false);

    if (availableYears.isEmpty || availableMonths.isEmpty) {
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
                      'No cancellation data available for charts.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
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


    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              'Cancelled Requests Trend',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: bulletPointText('Shows the trend of cancelled booking requests over time.'),
          ),
          const SizedBox(height: 12),
          // RESPONSIVE CHANGE: Use LayoutBuilder to switch between Row and Column for dropdowns.
          LayoutBuilder(
            builder: (context, constraints) {
              // Use a breakpoint to decide the layout. 500 is a good value for two dropdowns.
              if (constraints.maxWidth > 500) {
                // WIDE SCREEN: Use a Row with Expanded dropdowns to fill the width.
                return Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<int>(
                        label: "Select Year",
                        value: selectedYear,
                        items: availableYears,
                        onChanged: (year) {
                          if (year != null) {
                            setState(() {
                              selectedYear = year;
                              _extractAvailableDates(); // Re-extract months for the new year
                              _updateUnfilteredTotals();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown<int>(
                        label: "Select Month",
                        value: selectedMonth,
                        items: availableMonths,
                        onChanged: (month) {
                          if (month != null) {
                            setState(() {
                              selectedMonth = month;
                              _updateUnfilteredTotals();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                );
              } else {
                // NARROW SCREEN: Use a Column to stack the dropdowns.
                return Column(
                  children: [
                    _buildDropdown<int>(
                      label: "Select Year",
                      value: selectedYear,
                      items: availableYears,
                      onChanged: (year) {
                        if (year != null) {
                          setState(() {
                            selectedYear = year;
                            _extractAvailableDates(); // Re-extract months for the new year
                            _updateUnfilteredTotals();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<int>(
                      label: "Select Month",
                      value: selectedMonth,
                      items: availableMonths,
                      onChanged: (month) {
                        if (month != null) {
                          setState(() {
                            selectedMonth = month;
                            _updateUnfilteredTotals();
                          });
                        }
                      },
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 20),
          // Monthly Card
          _buildChartCard(
            titleWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getMonth(dailyData, selectedYear, selectedMonth),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 45, // ✅ dynamic
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            // ... inside the first _buildChartCard call
            chartChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // THIS IS THE CHANGE
                  child: BarChart(_buildBarChartData(dailyData, false)),
                ),
              ],
            ),
// ...
            totalcount: '$_unfilteredTotalMonthlyCancellations', // Use the unfiltered total
            mostCancellationHappenedOnIn: _getDayWithMostCancellationsUnfiltered(dailyDataUnfilteredForDetails, selectedYear, selectedMonth),
            mostFrequentReason: _getBiggestReasonUnfiltered(dailyDataUnfilteredForDetails),
            scrollController: _monthlyChartScrollController, // Pass the monthly controller
          ),
          const SizedBox(height: 30), // Added spacing after the monthly graph
          // Yearly Card
          _buildChartCard(
            titleWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getYear(dailyData, selectedYear, selectedMonth),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 45, // ✅ dynamic
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            // ... inside the second _buildChartCard call
            chartChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // THIS IS THE CHANGE
                  child: BarChart(_buildBarChartData(monthlyData, true)),
                ),
              ],
            ),
// ...
            totalcount: "$_unfilteredTotalYearlyCancellations", // Use the unfiltered total
            mostCancellationHappenedOnIn: _getMonthWithMostCancellationsUnfiltered(monthlyDataUnfilteredForDetails, selectedYear),
            mostFrequentReason: _getBiggestReasonUnfiltered(monthlyDataUnfilteredForDetails),
            scrollController: _yearlyChartScrollController, // Pass the yearly controller
          ),
        ],
      ),
    );
  }
}