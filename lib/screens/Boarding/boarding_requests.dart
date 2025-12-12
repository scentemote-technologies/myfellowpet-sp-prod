import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/highlight_mode.dart';
import 'OvernightPendingRequests.dart';
import 'chat_support/chat_support.dart';
import 'confirmed_requests_calendar_view.dart';


class CustomDateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const CustomDateRangePickerDialog({Key? key, this.initialDateRange}) : super(key: key);

  @override
  _CustomDateRangePickerDialogState createState() => _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState extends State<CustomDateRangePickerDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDateRange?.start ?? DateTime.now();
    _endDate = widget.initialDateRange?.end ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Select Date Range',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primary),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: 380, // Increased height to accommodate date text and prevent overflow
        child: SingleChildScrollView( // 1. FIX: Added SingleChildScrollView
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start Date Picker
              Expanded(
                child: Column(
                  children: [
                    Text('Start Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    // 2. NEW: Display the selected date
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_startDate),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                    const Divider(),
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: primary),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2101),
                        onDateChanged: (newDate) => setState(() {
                          _startDate = newDate;
                          if (_endDate.isBefore(_startDate)) {
                            _endDate = _startDate;
                          }
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(),
              // End Date Picker
              Expanded(
                child: Column(
                  children: [
                    Text('End Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    // 2. NEW: Display the selected date
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_endDate),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                    const Divider(),
                    Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: primary),
                      ),
                      child: CalendarDatePicker(
                        key: ValueKey(_startDate),
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2101),
                        onDateChanged: (newDate) => setState(() {
                          _endDate = newDate;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 16.0),
      actions: [
        // Filter Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          ),
          onPressed: () {
            Navigator.of(context).pop(DateTimeRange(start: _startDate, end: _endDate));
          },
          child: Text('Filter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

enum SortOrder { ascending, descending }

// REPLACE YOUR EXISTING OrderFilters WIDGET
// REPLACE YOUR EXISTING OrderFilters WIDGET
// Your brand's primary color
const Color kPrimary = Color(0xFF2CB4B6);

class OrderFilters extends StatelessWidget {
  final SortOrder sortOrder;
  final DateTimeRange? selectedRange;
  final Function(SortOrder, DateTimeRange?) onChanged;
  final bool showBookingDateSort;

  const OrderFilters({
    Key? key,
    required this.sortOrder,
    required this.selectedRange,
    required this.onChanged,
    this.showBookingDateSort = true,
  }) : super(key: key);

  /// --- UPDATED DATE PICKER METHOD ---
  /// This now uses Flutter's beautiful, mobile-friendly date range picker.
  Future<void> _selectDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange,
      firstDate: DateTime(now.year - 5), // Allow selection from 5 years ago
      lastDate: DateTime(now.year + 5), // Allow selection up to 5 years in the future
      helpText: 'SELECT DATE RANGE',
      // Theming the picker to match your brand
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // The onChanged callback is now only called here
      onChanged(sortOrder, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a LayoutBuilder to switch between Row and Column
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define a breakpoint. Below this width, the layout will be a Column.
        const double mobileBreakpoint = 550.0;
        final bool isMobile = constraints.maxWidth < mobileBreakpoint;

        // The list of filter widgets to display.
        final filterWidgets = <Widget>[
          // "Sort by" section
          if (showBookingDateSort)
            Flexible( // Using Flexible is better than Expanded here for responsiveness
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Prevents vertical expansion in a Row
                children: [
                  _buildSectionTitle('Sort by Booking Date'),
                  const SizedBox(height: 12),
                  _buildSortChips(),
                ],
              ),
            ),

          // Add spacing that adapts to the layout direction
          if (showBookingDateSort)
            isMobile
                ? const SizedBox(height: 24) // Vertical space for Column
                : const SizedBox(width: 16), // Horizontal space for Row

          // "Filter by Date" section
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionTitle('Filter by Order Date'),
                const SizedBox(height: 12),
                _buildDateFilterControl(context),
              ],
            ),
          ),
        ];

        // Return a Row for wide screens or a Column for narrow screens.
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filterWidgets,
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filterWidgets,
          );
        }
      },
    );
  }

  /// Helper widget for consistent section titles.
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Colors.grey.shade700,
      ),
    );
  }

  /// --- NEW: Modern ChoiceChips for Sorting ---
  /// This replaces the old radio buttons with a cleaner look.
  Widget _buildSortChips() {
    return Row(
      children: [
        ChoiceChip(
          label: Text('Ascending', style: GoogleFonts.poppins()),
          selected: sortOrder == SortOrder.ascending,
          showCheckmark: false,

          onSelected: (isSelected) {
            if (isSelected) {
              onChanged(SortOrder.ascending, selectedRange);
            }
          },
          selectedColor: kPrimary.withOpacity(0.15),
          labelStyle: TextStyle(
            color: sortOrder == SortOrder.ascending ? kPrimary : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: sortOrder == SortOrder.ascending ? kPrimary : Colors.grey.shade300,
          ),
          avatar: Icon(
            Icons.arrow_upward,
            size: 16,
            color: sortOrder == SortOrder.ascending ? kPrimary : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: Text('Descending', style: GoogleFonts.poppins()),
          selected: sortOrder == SortOrder.descending,
          showCheckmark: false,

          onSelected: (isSelected) {
            if (isSelected) {
              onChanged(SortOrder.descending, selectedRange);
            }
          },
          selectedColor: kPrimary.withOpacity(0.15),
          labelStyle: TextStyle(
            color: sortOrder == SortOrder.descending ? kPrimary : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: sortOrder == SortOrder.descending ? kPrimary : Colors.grey.shade300,
          ),
          avatar: Icon(
            Icons.arrow_downward,
            size: 16,
            color: sortOrder == SortOrder.descending ? kPrimary : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// --- NEW: A cleaner control for the date filter ---
  Widget _buildDateFilterControl(BuildContext context) {
    String rangeText;
    if (selectedRange == null) {
      rangeText = 'Select a date range';
    } else {
      final start = DateFormat('dd MMM yyyy').format(selectedRange!.start);
      final end = DateFormat('dd MMM yyyy').format(selectedRange!.end);
      rangeText = start == end ? start : '$start - $end';
    }

    return InkWell(
      onTap: () => _selectDateRange(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: kPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rangeText,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            // Show a clear button only if a date range is selected
            if (selectedRange != null)
              GestureDetector(
                onTap: () => onChanged(sortOrder, null),
                child: const Icon(Icons.close, color: Colors.grey, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
const Color primary = Color(0xFF2CB4B6);
class BoardingRequests extends StatefulWidget {
  final String serviceId;
  const BoardingRequests({super.key, required this.serviceId});

  @override
  _BoardingRequestsState createState() => _BoardingRequestsState();
}

class _BoardingRequestsState extends State<BoardingRequests> {
  int _selectedIndex = 0;
  late final List<Widget> _tabs;

  // Brand Colors
  static const Color primaryColor = Color(0xFF2CB4B6);
  static const Color accentColor = Color(0xFFF67B0D);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    // Initialize the list of tab widgets here to preserve their state.
    _tabs = [
      OvernightPendingRequests(serviceId: widget.serviceId),
      ConfirmedRequests(serviceId: widget.serviceId),
      AbandonedRequests(serviceId: widget.serviceId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Use a LayoutBuilder to determine the screen size and build the appropriate UI.
    return LayoutBuilder(
      builder: (context, constraints) {
        // A common breakpoint for switching between mobile and desktop layouts.
        bool isDesktop = constraints.maxWidth >= 768;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // Layout for wide screens (Laptops, Tablets)
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            minWidth: 100,
            backgroundColor: Colors.white,
            indicatorColor: primaryColor.withOpacity(0.1),
            selectedIconTheme: const IconThemeData(color: primaryColor, size: 28),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600, size: 28),
            selectedLabelTextStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 14,
            ),
            unselectedLabelTextStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.fromLTRB(0, 15, 0, 0),
              child: Column(
                children: [


                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.pending_actions_outlined),
                selectedIcon: Icon(Icons.pending_actions),
                label: Tooltip(
                  message: 'Pending Requests',
                  child: Text('Pending'),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_available_outlined),
                selectedIcon: Icon(Icons.event_available),
                label: Tooltip(
                  message: 'Active Bookings',
                  child: Text('Active'),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_toggle_off),
                selectedIcon: Icon(Icons.history),
                label: Tooltip(
                  message: 'Abandoned Requests',
                  child: Text('Abandoned'),
                ),
              ),
            ],

          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.grey),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
    );
  }

  // Layout for narrow screens (Phones)
  Widget _buildMobileLayout() {

    return Scaffold(
      backgroundColor: backgroundColor,

      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions_outlined),
            activeIcon: Icon(Icons.pending_actions),
            label: 'Pending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Confirmed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cancel_outlined),
            activeIcon: Icon(Icons.cancel),
            label: 'Abandoned',
          ),
        ],
      ),
    );
  }
}
// REPLACE YOUR ENTIRE AbandonedRequests CLASS

class AbandonedRequests extends StatefulWidget {
  final String serviceId;
  const AbandonedRequests({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<AbandonedRequests> createState() => _AbandonedRequestsState();
}

class _AbandonedRequestsState extends State<AbandonedRequests> {
  SortOrder _sortOrder = SortOrder.ascending;
  DateTimeRange? _selectedRange;

  // --- Step 1: Add state variables for search ---
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  bool _isSearchActive = false;


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- NEW: Method to show the filter drawer on mobile ---
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter & Sort',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              OrderFilters(
                sortOrder: _sortOrder,
                selectedRange: _selectedRange,
                onChanged: (newSortOrder, newRange) {
                  setState(() {
                    _sortOrder = newSortOrder;
                    _selectedRange = newRange;
                  });
                  Navigator.pop(context); // Closes the drawer after selection
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final query = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // The old OrderFilters widget is replaced with the new responsive bar
        _buildFilterBar(),
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: query.get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No abandoned requests found.'));
              }

              var docs = snapshot.data!.docs;

              // Apply search filter
              if (searchQuery.isNotEmpty) {
                docs = docs.where((d) => d.id.toLowerCase().contains(searchQuery.toLowerCase())).toList();
              }

              // Apply date range filter
              if (_selectedRange != null) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final selectedDatesList = data['selectedDates'] as List?;
                  if (selectedDatesList == null) return false;

                  final orderDates = selectedDatesList
                      .map((e) => e is Timestamp ? e.toDate() : DateTime.parse(e.toString()))
                      .map((d) => DateTime(d.year, d.month, d.day))
                      .toList();

                  return orderDates.any((orderDate) {
                    final start = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
                    final end = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day);
                    return !orderDate.isBefore(start) && !orderDate.isAfter(end);
                  });
                }).toList();
              }

              // Apply sort order
              final sortedList = docs.toList();
              sortedList.sort((a, b) {
                final aTs = (a['timestamp'] as Timestamp).toDate();
                final bTs = (b['timestamp'] as Timestamp).toDate();
                return _sortOrder == SortOrder.ascending ? aTs.compareTo(bTs) : bTs.compareTo(aTs);
              });

              if (sortedList.isEmpty) {
                return Center(
                  child: Text('No requests match this filter.', style: GoogleFonts.poppins()),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: sortedList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final dates = (data['selectedDates'] as List)
                        .map((e) => e is Timestamp ? e.toDate() : DateTime.parse(e.toString()))
                        .map((dt) => DateTime(dt.year, dt.month, dt.day))
                        .toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${idx + 1})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350, minWidth: 100),
                          child: PendingBoardingRequestCard(
                            serviceId: widget.serviceId,
                            doc: doc,
                            selectedDates: dates,
                            mode: HighlightMode.past,
                            frompending: false,
                            onComplete: () {},
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- NEW: Unified and responsive filter bar (same as other tabs) ---
  Widget _buildFilterBar() {
    if (_isSearchActive) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(child: _buildSearchField()),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: 'Close Search',
              onPressed: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double wideBreakpoint = 768.0;
          bool isWide = constraints.maxWidth >= wideBreakpoint;

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 2, child: _buildSearchField()),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: OrderFilters(
                    sortOrder: _sortOrder,
                    selectedRange: _selectedRange,
                    onChanged: (newSortOrder, newRange) {
                      setState(() {
                        _sortOrder = newSortOrder;
                        _selectedRange = newRange;
                      });
                    },
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: Text('Filters', style: GoogleFonts.poppins()),
                  onPressed: () => _showFilterSheet(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_selectedRange != null || _sortOrder != SortOrder.ascending)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: accentColor,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, color: primaryColor),
                  tooltip: 'Search Requests',
                  onPressed: () {
                    setState(() {
                      _isSearchActive = true;
                    });
                  },
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // --- NEW: Styled search field (same as other tabs) ---
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.poppins(),
      onChanged: (v) => setState(() => searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: 'Search by Request ID...',
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
        prefixIcon: const Icon(Icons.search, color: primaryColor),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
class ConfirmedRequests extends StatefulWidget {
  final String serviceId;
  const ConfirmedRequests({Key? key, required this.serviceId}) : super(key: key);

  @override
  _ConfirmedRequestsState createState() => _ConfirmedRequestsState();
}

class _ConfirmedRequestsState extends State<ConfirmedRequests> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<DocumentSnapshot>? _verificationSub;
  DateTimeRange? _selectedRange;
  SortOrder _sortOrder = SortOrder.descending;

  // In _OvernightPendingRequestsState
  // ADD this method to _OvernightPendingRequestsState
  Widget _buildDialogHeader(String title, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, color: Colors.black87, size: 24),
            ),
          ),
        ],
      ),
    );
  }

// REPLACE _showEarningsBreakdownDialog
  void _showEarningsBreakdownDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final bool gstRegistered = data['gstRegistered'] == true;
    final bool checkoutEnabled = data['checkoutEnabled'] == true;

    final double serviceExcGst  = (data['sp_service_fee_exc_gst'] as num? ?? 0).toDouble();
    final double gstOnService   = (data['gst_on_sp_service'] as num? ?? 0).toDouble();
    final double platformExcGst = (data['platform_fee_exc_gst'] as num? ?? 0).toDouble();
    final double gstOnPlatform  = (data['gst_on_platform_fee'] as num? ?? 0).toDouble();

    /// CORRECT SERVICE PROVIDER EARNING LOGIC
    final double spIncomeTotal = serviceExcGst + (gstRegistered ? gstOnService : 0);

    /// Customer total platform fee (not deducted from SP)
    final double platformTotal = checkoutEnabled ? platformExcGst + gstOnPlatform : 0;

    /// GST percentage helper
    String pct(double base, double gst) {
      if (base <= 0 || gst <= 0) return "";
      return "(${(gst / base * 100).toStringAsFixed(0)}%)";
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          title: _buildDialogHeader("Earnings Summary", context),

          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ============= USER BILL SECTION =============
                _sectionHeader("WHAT THE USER PAID"),
                _ledgerRow("Service Fee", serviceExcGst),
                if (gstRegistered)
                  _ledgerRow("GST on Service Fee ${pct(serviceExcGst, gstOnService)}", gstOnService),

                if (checkoutEnabled) ...[
                  _ledgerRow("Platform Fee (charged to user)", platformExcGst),
                  _ledgerRow(
                      "GST on Platform Fee ${pct(platformExcGst, gstOnPlatform)}",
                      gstOnPlatform),
                ],

                _divider(),

                _ledgerRow("Total User Payment",
                    serviceExcGst +
                        (gstRegistered ? gstOnService : 0) +
                        platformTotal,
                    bold: true),

                const SizedBox(height: 24),

                // ============= SP EARNINGS SECTION =============
                _sectionHeader("YOUR EARNINGS"),

                _ledgerRow("Service Fee (Exc. GST)", serviceExcGst),
                if (gstRegistered)
                  _ledgerRow("GST on Service Fee", gstOnService),

                _divider(),

                // ========= GREEN OUTLINE TOTAL EARNING BOX =========
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green, // your green-accent color
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Total earning from this booking",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "₹${spIncomeTotal.toStringAsFixed(2)}",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,       // bigger, more premium
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),


                Text(
                  "This is the exact amount you earn for this booking.",
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 24),

                // ============= PLATFORM CHARGES NOTE =============
                if (checkoutEnabled)
                  Text(
                    "Note: Platform fees shown above are charged to the user and "
                        "do NOT reduce your payout.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "CLOSE",
                style: GoogleFonts.poppins(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 12.0),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _divider() => Divider(
    thickness: 1,
    height: 20,
    color: Colors.grey.shade300,
  );

  Widget _ledgerRow(
      String label,
      double amount, {
        bool deduction = false,
        bool highlight = false,
        bool bold = false,
        bool big = false,
      }) {
    Color valueColor =
    deduction ? Colors.red.shade700 :
    highlight ? primaryColor :
    Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            "${deduction ? '-' : ''}₹${amount.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              fontSize: big ? 16 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }



  // Brand Colors
  static const Color primaryColor = Color(0xFF2CB4B6);
  static const Color accentColor = Color(0xFFF67B0D);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final baseQuery = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .where('order_status', isEqualTo: 'confirmed');

    return StreamBuilder<QuerySnapshot>(
      stream: baseQuery.snapshots(),
      builder: (context, snapshot) {
        // 1. Handle loading and errors first
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading requests: ${snapshot.error}');
        }

        // 🟢 TWEAK: Always proceed if data is available (even if docs.isEmpty)
        if (snapshot.hasData) {

          var docs = snapshot.data!.docs;

          // Apply search filter (no change)
          if (_searchQuery.isNotEmpty) {
            docs = docs
                .where((d) =>
                d.id.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }

          // Apply date range filter (no change)
          if (_selectedRange != null) {
            docs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final selectedDatesList = data['selectedDates'] as List?;
              if (selectedDatesList == null) return false;
              final orderDates =
              selectedDatesList.map((e) => (e as Timestamp).toDate()).toList();
              return orderDates.any((d) =>
              !d.isBefore(_selectedRange!.start) &&
                  !d.isAfter(_selectedRange!.end));
            }).toList();
          }

          // Apply sort order (no change)
          docs.sort((a, b) {
            final aTs = (a['timestamp'] as Timestamp).toDate();
            final bTs = (b['timestamp'] as Timestamp).toDate();
            return _sortOrder == SortOrder.ascending
                ? aTs.compareTo(bTs)
                : bTs.compareTo(aTs);
          });

          // 2. If the filtered list is empty AND filters were actively used, show filtered empty state.
          if (docs.isEmpty && (_searchQuery.isNotEmpty || _selectedRange != null)) {
            return _buildEmptyState('No requests match your filters.');
          }

          // 3. Render the MonthlyBookingCalendar in ALL other cases (including when docs.isEmpty initially).
          return MonthlyBookingCalendar(
            serviceId: widget.serviceId,
            calendarType: CalendarType.confirmed,
            onStart: (doc) => _onStartOrder(doc),
            onComplete: (doc) => _onCompleteOrder(doc),
            onShowEarnings: (doc) => _showEarningsBreakdownDialog(context, doc), // <--- ADD THIS
          );
        }
        // Fallback for unexpected missing data
        return _buildEmptyState('No confirmed requests found.');
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Accepted requests will appear here, organized by month.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerifiedAndComplete(DocumentSnapshot doc) async {
    int rating = 5;
    String remarks = '';
    // Define a clean accent color for the UI
    const Color accentColor = Color(0xFFF67B0D);
    const Color primaryColor = Color(0xFF2CB4B6);

    final confirmed = await showDialog<bool>(
      context: context,
      // Use a clean, compact Dialog wrapper
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch for full-width buttons
            children: [
              // --- Header & Title ---
              Icon(Icons.star_half_rounded, color: primaryColor, size: 48),
              const SizedBox(height: 16),
              Text(
                'Finalize & Rate Service',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Please provide a rating for this service before completion.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // --- Rating Stars (Stateful) ---
              StatefulBuilder(builder: (ctx2, setState2) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      icon: Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 38), // Slightly larger stars
                      onPressed: () => setState2(() => rating = i + 1),
                    );
                  }),
                );
              }),
              const SizedBox(height: 24),

              // --- Remarks Text Field ---
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Remarks (optional) - How was the service?',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded border
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2)),
                ),
                onChanged: (v) => remarks = v,
                style: GoogleFonts.poppins(fontSize: 15),
              ),
              const SizedBox(height: 32),

              // --- Action Buttons ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                      ),
                      child: Text('Submit & Complete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    // --- EXISTING DATA MANIPULATION LOGIC (NO CHANGE) ---

    final srcRef = doc.reference;
    final firestore = FirebaseFirestore.instance;

    final dstRef = firestore
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('completed_orders')
        .doc(doc.id);

    // ✅ Copy main document first
    final data = doc.data() as Map<String, dynamic>;
    data
      ..['rating'] = rating
      ..['remarks'] = remarks
      ..['completedAt'] = FieldValue.serverTimestamp()
      ..['isEndPinUsed'] = true
      ..['payout_done'] = false
      ..['order_status'] = 'completed';

    await dstRef.set(data);

    // ✅ Copy all relevant subcollections
    final possibleSubcollections = [
      'pet_services',
      'user_cancellation_history',
      'sp_cancellation_history',
    ];

    for (final sub in possibleSubcollections) {
      final subCol = srcRef.collection(sub);
      final subSnap = await subCol.get();

      if (subSnap.docs.isEmpty) continue;

      final subDest = dstRef.collection(sub);
      for (final sDoc in subSnap.docs) {
        await subDest.doc(sDoc.id).set(sDoc.data());
      }
      print('✅ Copied subcollection: $sub');
    }

    // ✅ Delete all old subcollections and main doc
    for (final sub in possibleSubcollections) {
      final subCol = srcRef.collection(sub);
      final subSnap = await subCol.get();
      for (final sDoc in subSnap.docs) {
        await sDoc.reference.delete();
      }
    }

    await srcRef.delete();
    print('🗑️ Deleted original document and subcollections after completion.');

    // ✅ Mirror update to user's "completed_orders"
    if (data.containsKey('user_id')) {
      final userId = data['user_id'];
      await firestore
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc('overnight_boarding')
          .collection('completed_orders')
          .doc(doc.id)
          .set({
        'user_reviewed': 'false',
        'service_id': widget.serviceId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    print('✅ Booking ${doc.id} moved to completed_orders with subcollections.');
  }

  Future<String?> _showPinVerificationDialog(BuildContext context, {required String title}) async {
    final pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            hintText: '----',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(pinController.text),
            child: Text('Verify', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _onStartOrder(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // 🗓 Extract booking dates (your existing logic)
    final selectedDatesRaw = data['selectedDates'] as List?;
    if (selectedDatesRaw == null || selectedDatesRaw.isEmpty) {
      _showErrorDialog('No booking dates found for this order.');
      return;
    }

    final selectedDates = selectedDatesRaw.map((e) {
      if (e is Timestamp) return e.toDate();
      return DateTime.parse(e.toString());
    }).toList()
      ..sort((a, b) => a.compareTo(b));

    final firstDate = DateTime(
      selectedDates.first.year,
      selectedDates.first.month,
      selectedDates.first.day,
    );

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // ⚠️ If today is before the first booking date (your existing logic)
    if (todayDate.isBefore(firstDate)) {
      await _showStylishNotAllowedDialog();
      return;
    }

    // Get the hash *once* outside the loop
    final storedHash = data['startPinHash'] as String?;
    if (storedHash == null) {
      _showErrorDialog('PIN not found for this booking.');
      return;
    }

    // --- NEW: Loop for PIN verification ---
    bool isPinCorrect = false;
    while (!isPinCorrect) {
      final enteredPin = await _showPinVerificationDialog(context, title: 'Enter Start PIN');

      // If user hits "Cancel" on the PIN dialog, exit the loop
      if (enteredPin == null || enteredPin.isEmpty) {
        return;
      }

      final enteredPinHash = sha256.convert(utf8.encode(enteredPin)).toString();

      if (enteredPinHash == storedHash) {
        // --- Success ---
        isPinCorrect = true; // This will break the loop

        await doc.reference.update({
          'isStartPinUsed': true,
          'order_started': true,
          'startedAt': FieldValue.serverTimestamp(),
        });

        _showConfirmationDialog(
          'Booking Started 🎉',
          'Your booking has officially started. Have a great boarding experience!',
        );
      } else {
        // --- Failure ---
        // Show error, and the loop will automatically repeat
        await _showErrorDialog('Invalid PIN. Please try again.');
      }
    }
  }


  Future<void> _showStylishNotAllowedDialog() async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2CB4B6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule_rounded, size: 40, color: Color(0xFF2CB4B6)),
              ),
              const SizedBox(height: 20),
              Text(
                "Too Early to Start!",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You can start this booking only on or after its first scheduled day.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2CB4B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Got it",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _showStartWaitingPopup(String orderId) async {
    final bookingRef = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .doc(orderId);

    _verificationSub = bookingRef.snapshots().listen((snap) {
      final data = snap.data();
      if (data != null && data['order_started'] == true) {
        bookingRef.update({'startedAt': FieldValue.serverTimestamp()});
        Navigator.of(context).pop(); // Close waiting dialog
        _verificationSub?.cancel();
        _showConfirmationDialog(
            'Order Started!', 'Order $orderId has now officially started.');
      }
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _buildWaitingDialog(
          'Waiting for User', 'A start-link has been sent to the user’s email.'),
    );
    _verificationSub?.cancel();
  }
  Future<void> _onCompleteOrder(DocumentSnapshot doc) async {
    print('🟢 Starting onCompleteOrder for booking ${doc.id}');

    final data = doc.data() as Map<String, dynamic>;
    final storedHash = data['endPinHash'] as String?;

    if (storedHash == null) {
      _showErrorDialog('PIN not found for this booking.');
      print('❌ No endPinHash found for booking ${doc.id}');
      return;
    }

    // --- NEW: Loop for PIN verification ---
    bool isPinCorrect = false;
    while (!isPinCorrect) {
      final enteredPin = await _showPinVerificationDialog(context, title: 'Enter End PIN');

      // If user hits "Cancel" on the PIN dialog, exit the loop
      if (enteredPin == null || enteredPin.isEmpty) {
        print('⚠️ No PIN entered — exiting');
        return;
      }

      final enteredPinHash = sha256.convert(utf8.encode(enteredPin)).toString();
      print('🔑 Comparing entered hash with stored hash...');

      if (enteredPinHash == storedHash) {
        // --- Success ---
        isPinCorrect = true; // This breaks the loop
        print('✅ PIN matched — proceeding to mark completed + payout.');

        await doc.reference.update({'isEndPinUsed': true});

        // Show loader
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2CB4B6)),
            ),
          );
        }

        try {
          // ✅ Step 1: Move booking to completed_orders FIRST
          print('🔁 Moving booking to completed_orders before payout...');
          await _handleVerifiedAndComplete(doc);
          print('✅ Booking moved successfully, proceeding to payout.');

          // ✅ Step 2: Fetch SP details
          final spDoc = await FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(widget.serviceId)
              .get();

          final spData = spDoc.data();
          if (spData == null) {
            if (context.mounted) Navigator.pop(context);
            _showErrorDialog('Service provider data not found.');
            print('❌ SP data not found for serviceId: ${widget.serviceId}');
            return;
          }

          final fundAccountId = spData['payout_fund_account_id'];
          if (fundAccountId == null) {
            if (context.mounted) Navigator.pop(context);
            _showErrorDialog('Bank details not linked for this service provider.');
            print('❌ Missing Razorpay fund account for SP ${widget.serviceId}');
            return;
          }

          // ✅ Step 3: Fetch the completed order data now
          final completedSnap = await FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(widget.serviceId)
              .collection('completed_orders')
              .doc(doc.id)
              .get();

          if (!completedSnap.exists) {
            print('❌ Completed order not found after move: ${doc.id}');
            if (context.mounted) Navigator.pop(context);
            _showErrorDialog('Completed order not found.');
            return;
          }

          final bookingData = completedSnap.data()!;

          final rawExcGstStr = bookingData['sp_service_fee_exc_gst']?.toString() ?? '0';
          double baseFee = double.tryParse(rawExcGstStr) ?? 0.0;

// ✅ NEW: Collect refund from cancellation subcollections
          double totalRefund = 0.0;

          Future<double> sumRefunds(String subCol) async {
            final snap = await FirebaseFirestore.instance
                .collection('users-sp-boarding')
                .doc(widget.serviceId)
                .collection('service_request_boarding')    // ✔ correct parent
                .doc(doc.id)
                .collection(subCol)
                .get();

            double subtotal = 0.0;

            for (var d in snap.docs) {
              final refundStr = d['net_refund_excluding_gst']?.toString() ?? '0';
              subtotal += double.tryParse(refundStr) ?? 0.0;
            }

            return subtotal;
          }

// Sum refund from both collections
          final userRefund = await sumRefunds('user_cancellation_history');
          final spRefund   = await sumRefunds('sp_cancellation_history');

          totalRefund = userRefund + spRefund;

// FINAL PAYOUT
          final payoutAmount = baseFee - totalRefund;

          // ✅ Step 4: Fetch admin commission from Firestore
          final settingsDoc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('cancellation_time_brackets')
              .get();

          final commissionStr = settingsDoc.data()?['admin_boarder_commision'] ?? '0';
          final commissionRate = double.tryParse(commissionStr) ?? 0.0;

          final commissionAmount = (payoutAmount * commissionRate) / 100;
          final finalPayoutAmount = payoutAmount - commissionAmount;

          print('💰 Raw Fee: ₹$payoutAmount');
          print('🏦 Admin Commission: ₹$commissionAmount (${commissionRate.toStringAsFixed(2)}%)');
          print('✅ Final Payout: ₹$finalPayoutAmount');

          // ✅ Step 5: Trigger payout
          print('🚀 Triggering v2initiatePayout...');
          final url = "https://us-central1-petproject-test-g.cloudfunctions.net/v2initiatePayout";
          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "serviceProviderId": widget.serviceId,
              "orderId": doc.id,
              "fundAccountId": fundAccountId,
              "amount": (finalPayoutAmount * 100).toInt(), // paise
            }),
          );

          if (context.mounted) Navigator.pop(context); // close loader
          print('📤 Cloud Function Response: ${response.body}');

          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result['success'] == true) {
              final payoutId = result['payoutId'];
              print('✅ Payout initiated successfully! ID: $payoutId');
              _showConfirmationDialog(
                'Payout Initiated',
                '₹${finalPayoutAmount.toStringAsFixed(2)} has been successfully sent to the service provider. It will reflect shortly.',
              );
            } else {
              print('❌ Payout failed: ${response.body}');
              _showErrorDialog('Failed to trigger payout. Please try again.');
            }
          } else {
            print('❌ Server Error: ${response.statusCode}');
            _showErrorDialog('Server error while triggering payout.');
          }

        } catch (e) {
          if (context.mounted) Navigator.pop(context);
          _showErrorDialog('Error while triggering payout: $e');
          print('🚨 Exception during payout: $e');
        }

        print('🏁 onCompleteOrder finished successfully.');

      } else {
        // --- Failure ---
        print('❌ PIN mismatch for booking ${doc.id}');
        // Show error, and the loop will automatically repeat
        await _showErrorDialog('Invalid PIN. Please try again.');
      }
    }
  }


  AlertDialog _buildWaitingDialog(String title, String content) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:
      Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(content, style: GoogleFonts.poppins()),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: primaryColor),
        ],
      ),
    );
  }

  void _showConfirmationDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String msg) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.error_outline, size: 48, color: accentColor),
        content:
        Text(msg, style: GoogleFonts.poppins(), textAlign: TextAlign.center),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: primaryColor))),
        ],
      ),
    );
  }
  // Add this method inside your _ConfirmedRequestsState class

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter & Sort',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Here we reuse your existing OrderFilters widget
              OrderFilters(
                sortOrder: _sortOrder,
                selectedRange: _selectedRange,
                // Since this screen shows a calendar, we only need one date sort option.
                // If you wanted to show both, you could change this.
                showBookingDateSort: false,
                onChanged: (newSortOrder, newRange) {
                  setState(() {
                    _sortOrder = newSortOrder;
                    _selectedRange = newRange;
                  });
                  Navigator.pop(context); // This closes the drawer after selection
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
class CancellationRequests extends StatefulWidget {
  final String serviceId;
  const CancellationRequests({required this.serviceId});

  @override
  _CancellationRequestsState createState() => _CancellationRequestsState();
}

class _CancellationRequestsState extends State<CancellationRequests> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FirebaseFirestore.instance
        .collection('rejected-boarding-bookings')
        .where('service_id', isEqualTo: widget.serviceId)
        .where('order_status', isEqualTo: 'cancelled')
        .orderBy('timestamp', descending: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Request ID',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => searchQuery = v.trim()),
          ),
        ),

      ],
    );
  }
}


class BoardingRequestCard extends StatefulWidget {
  final DocumentSnapshot doc;
  final String serviceId;
  final List<DateTime> selectedDates;
  final HighlightMode mode;
  final VoidCallback onComplete;
  final VoidCallback onStart;
  final bool frompending;
  final Function(DocumentSnapshot) onShowEarnings; // <--- ADD NEW CALLBACK

  const BoardingRequestCard({
    Key? key,
    required this.doc,
    required this.selectedDates,
    required this.mode,
    required this.onComplete,
    required this.serviceId,
    required this.onShowEarnings, // <--- ADD NEW REQUIRED FIELD
    required this.frompending,
    required this.onStart,
  }) : super(key: key);

  @override
  State<BoardingRequestCard> createState() => _BoardingRequestCardState();
}
class _BoardingRequestCardState extends State<BoardingRequestCard> {
  bool _showAll = false;  // ◀ resets to false on every rebuild
  String? shopName;
  String? ownerPhone;
  String? notificationEmail;
  String? ownerEmail;

  // ADD THIS METHOD inside the _BoardingRequestCardState class:

  // Inside _BoardingRequestCardState:

  Widget _buildInfoColumn(String label, String value,
      {required IconData icon, required VoidCallback onTap}) {
    // Define primaryColor locally or ensure it's accessible
    const Color primaryColor = Color(0xFF2CB4B6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      softWrap: true,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                    ),
                  ),
                  // The clickable icon
                  GestureDetector( // <--- WRAP ICON IN GESTURE DETECTOR
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, right: 0),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  @override
  void initState() {
    super.initState();
    fetchShopDetails();
  }

  Future<void> fetchShopDetails() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        setState(() {
          shopName = data['shop_name'] as String?;
          ownerPhone = data['owner_phone'] as String?;
          notificationEmail = data['notification_email'] as String?;
        });
      } else {
        print("No document found for serviceId ${widget.serviceId}");
      }
    } catch (e) {
      print("Error fetching shop details: $e");
    }
  }



  @override
  Widget build(BuildContext context) {


    final data = widget.doc.data() as Map<String, dynamic>;
    final id = widget.doc.id;
    final owner = data['user_name'] as String? ?? 'N/A';
    final started = data['order_started'] as bool? ?? false;
    final phone = data['phone_number'] as String? ?? 'N/A';
    final user_id = data['user_id'] as String? ?? 'N/A';
    final pets = (data['pet_name'] as List<dynamic>?)?.cast<String>() ?? [];
    final petIds = (data['pet_id'] as List<dynamic>?)?.cast<String>() ?? [];

    // --- FIX: Add a reliable check to see if the order is truly completed ---
    final isTrulyCompleted = widget.doc.reference.parent.id == 'completed_orders';


    // Parse attendance_override from Firestore
    final attendanceOverride = (data['attendance_override'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, (v as List).cast<String>()))
        ?? <String, List<String>>{};

    // Helper: for a given day, return only the petIds not cancelled
    List<String> petIdsFor(DateTime day) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final cancelled = attendanceOverride[key];
      if (cancelled == null) {
        return petIds;
      }
      return petIds.where((id) => !cancelled.contains(id)).toList();
    }

    // Cost breakdown (unchanged) …
    final breakdown = data['cost_breakdown'] as Map<String, dynamic>? ?? {};
    final totalCostWithGst =
        double.tryParse(breakdown['total_amount']?.toString() ?? '') ?? 0.0;
    final platformFee =
        double.tryParse(breakdown['platform_fee_plus_gst']?.toString() ?? '') ?? 0.0;
    final totalCost = totalCostWithGst - platformFee;

    // Today's date for highlighting
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final ts = (data['timestamp'] is Timestamp)
        ? _format((data['timestamp'] as Timestamp).toDate())
        : 'N/A';
    final startedAtTs = (data['startedAt'] as Timestamp?)?.toDate();
    final startedAtStr = startedAtTs != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(startedAtTs)
        : 'Not started';

    final furthestDate = widget.selectedDates.isNotEmpty
        ? widget.selectedDates.reduce((a, b) => b.isAfter(a) ? b : a)
        : null;
    final completesOnStr = furthestDate != null
        ? DateFormat('dd-MM-yyyy').format(furthestDate)
        : '–––';
    // --- START OF CHANGE ---
    // Define booleans for all possible modes, including 'past' for completed orders.
    final isOngoing = widget.mode == HighlightMode.ongoing;
    final isUpcoming = widget.mode == HighlightMode.upcoming;
    final isAwaitingFinalization =
        widget.mode == HighlightMode.awaitingFinalization;
    final isPast = widget.mode == HighlightMode.past; // For completed orders
    // --- END OF CHANGE ---

    // 🕓 Button greys out if today < first booking date
    final firstDate = widget.selectedDates.isNotEmpty
        ? DateTime(widget.selectedDates.first.year, widget.selectedDates.first.month, widget.selectedDates.first.day)
        : DateTime.now();
    final isStartEnabled = todayDate.isAtSameMomentAs(firstDate) || todayDate.isAfter(firstDate);
    final state = (context).findAncestorStateOfType<_ConfirmedRequestsState>();
    final earnings = data['sp_service_fee_exc_gst'] as double? ??
        data['sp_service_fee_inc_gst'] as double? ?? // Fallback 2: Try Inc GST
        data['sp_service_fee'] as double? ?? // Fallback 3: Old cost_breakdown field
        0.0;




    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Order ID: $id',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // --- UPDATED CONDITION ---
                    // Now, the button will NOT show if 'isTrulyCompleted' is true.
                    if (!widget.frompending && !isTrulyCompleted)

                      ElevatedButton(
                        onPressed: started ? widget.onComplete : widget.onStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: started
                              ? const Color(0xFF2CB4B6)
                              : isStartEnabled
                              ? const Color(0xFF2CB4B6)
                              : Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: isStartEnabled ? 2 : 0,
                        ),
                        child: Text(
                          started ? 'Complete' : 'Start',
                          style: GoogleFonts.poppins(
                            color: isStartEnabled ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.headset_mic),
                          tooltip: 'Raise Support Ticket',
                          color: primary,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Raise Ticket'),
                                content:
                                Text('Do you want to raise a ticket for Order #$id?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Yes')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SPChatPage(
                                    initialOrderId: id,
                                    serviceId: widget.serviceId,
                                    shop_name: shopName ?? "",
                                    shop_phone_number: ownerPhone ?? '',
                                    shop_email: notificationEmail ?? "",
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy Order ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order ID copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // ── Info Grid ───────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _infoRow('Owner', owner)),
                    Expanded(child: _infoRow('Phone', phone)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _infoRow('Pets', pets.join(', '))),
                    Expanded(child: _infoRow('Booked', ts)),
                  ],
                ),
                const SizedBox(height: 6),
                // If using the optimized version where _buildInfoColumn handles the click:

                _buildInfoColumn(
                  'Your Earnings',
                  '₹${earnings.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () {
                    print('DEBUG: FINAL CHECK - Calling widget.onShowEarnings for ${widget.doc.id}');
                    widget.onShowEarnings(widget.doc); // This is the function passed from ConfirmedRequestsState
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ▼ Attendance-by-Date block ▼
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Attendance by Date:",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Filter the dates with at least one pet
                ...[
                  for (int i = 0; i < widget.selectedDates.length; i++)
                    if (petIdsFor(widget.selectedDates[i]).isNotEmpty)
                      if (_showAll || i == 0) // Show only first or all if expanded
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date bubble
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.selectedDates[i] == todayDate
                                      ? primary.withOpacity(0.2)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(widget.selectedDates[i]),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: widget.selectedDates[i] == todayDate
                                        ? primary
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Pet names booked on that date
                              Expanded(
                                child: Text(
                                  petIdsFor(widget.selectedDates[i])
                                      .map((id) {
                                    final idx = petIds.indexOf(id);
                                    return pets[idx];
                                  })
                                      .join(', '),
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],

                // Show More / Show Less button

                  Row(
                    children: [
                      if (widget.selectedDates.where((d) => petIdsFor(d).isNotEmpty).length > 1)

                      // Toggle attendance list
                      ElevatedButton(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 0,
                        ),
                        child: Text(
                          _showAll ? 'Show Less' : 'Show All',
                          style: GoogleFonts.poppins(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Show pet details dialog
                      ElevatedButton(
                        onPressed: () => _showPetDetailsDialog(
                          context,
                          pets,
                          petIds,
                          user_id,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 0,
                        ),
                        child: Text(
                          'Show Pet Detail',
                          style: GoogleFonts.poppins(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

              ],
            ),
            const SizedBox(height: 8),

            _infoRow('Started At',   startedAtStr),
            _infoRow('Completes On', completesOnStr),
            const SizedBox(height: 8),



            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1) Cancel button
                if (widget.mode != HighlightMode.past)
                  ElevatedButton(
                    onPressed: () => handleCancel(widget.doc, context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      elevation: 0,
                    ),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // 2) Cancellation History button
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CancellationHistoryPage(
                          bookingDoc: widget.doc,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    elevation: 0,
                  ),
                  child: Text(
                    'CANCELLATION HISTORY',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),

// ▲ end Attendance-by-Date block ▲
          ],
        ),
      ),
    );
  }


  Widget _infoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.black,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  // 🔽 V V V PASTE THIS ENTIRE BLOCK INTO _BoardingRequestCardState 🔽 V V V

  void _showPetDetailsDialog(
      BuildContext context,
      List<String> petNames,
      List<String> petIds,
      String userId,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pet Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: FutureBuilder<List<Widget>>(
            // The function signature now expects context first
            future: _buildPetCards(context, petNames, petIds, userId),
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: primaryColor));
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Center(
                    child: Text('No pet data found',
                        style: GoogleFonts.poppins()));
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: snapshot.data!,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: GoogleFonts.poppins(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildPetCards(
      BuildContext context, // Note: Added context here
      List<String> names,
      List<String> ids,
      String userId,
      ) async {
    final List<Widget> cards = [];

    for (int i = 0; i < min(names.length, ids.length); i++) {
      final petName = names[i];
      final petId = ids[i];

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('users-pets')
          .doc(petId)
          .get();

      if (!snap.exists) {
        cards.add(Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No data for $petName', style: GoogleFonts.poppins()),
          ),
        ));
        continue;
      }

      final data = snap.data()!;

      // 🟢 UPDATED LOGIC: Retrieve image from single string field 'pet_image'
      final rawImage = data['pet_image'] as String?;

      final petImage = (rawImage != null && rawImage.isNotEmpty)
          ? rawImage
          : 'https://via.placeholder.com/150'; // Fallback URL

      // 🟢 NEW LOGIC: Retrieve the list of additional images
      final petImagesList = (data['pet_images'] as List<dynamic>?)
          ?.cast<String>()
          .where((url) =>
      url.isNotEmpty &&
          url != petImage) // Filter out empty strings and the main image
          .toList() ??
          [];

      Widget sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: primaryColor,
          ),
        ),
      );

      Widget detailText(String label, dynamic value) {
        if (value == null || (value is String && value.isEmpty)) {
          return const SizedBox();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                TextSpan(
                  text: value.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      cards.add(SizedBox(
        width: 580,
        child: Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Enhanced Pet Header (Name + Image) ────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pet Image (Circular Avatar)
                    GestureDetector(
                      onTap: () {
                        // Navigate to the FullScreenImageViewer
                        Navigator.of(context).push(
                          // <--- Correct use of context
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imageUrl: petImage,
                              // Use a unique tag for the Hero animation
                              tag: 'pet-image-$petId',
                            ),
                          ),
                        );
                      },
                      child: Hero(
                        // Wrap with Hero for smooth animation
                        tag:
                        'pet-image-$petId', // Must match the tag in FullScreenImageViewer
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl:
                            petImage, // Using the safely retrieved image URL
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.pets, color: Colors.grey),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.error_outline,
                                  color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Pet Name
                    Text(petName,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        )),
                  ],
                ),
                const Divider(height: 30, thickness: 1),

                // ── Basic Info Chips ────────────────
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _petDetailChip('Gender', data['gender']),
                    _petDetailChip('Type', data['pet_type']),
                    _petDetailChip('Breed', data['pet_breed']),
                    _petDetailChip('Age', data['pet_age']),
                    if (data['weight_type'] == 'exact')
                      _petDetailChip('Weight', '${data['weight']} kg'),
                    if (data['weight_type'] == 'range')
                      _petDetailChip('Weight', data['weight_range']),
                    _petDetailChip(
                        'Neutered', data['is_neutered'] == true ? 'Yes' : 'No'),
                  ],
                ),

                // ── Detailed Sections ────────────────
                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle('Vet & Emergency Info'),
                          detailText('Vet', data['vet_name']),
                          // ✅✅✅ HERE IS THE FIX ✅✅✅
                          detailText('Vet Phone', data['vet_phone']),
                          detailText(
                              'Emergency Contact', data['emergency_contact']),
                          // ✅✅✅ END OF FIX ✅✅✅
                          sectionTitle('Preferences'),
                          if ((data['likes'] as List<dynamic>?)?.isNotEmpty ??
                              false)
                            detailText(
                                'Likes', (data['likes'] as List).join(', ')),
                          if ((data['dislikes'] as List<dynamic>?)?.isNotEmpty ??
                              false)
                            detailText('Dislikes',
                                (data['dislikes'] as List).join(', ')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle('Medical Info'),
                          detailText(
                              'Medical History', data['medical_history']),
                          detailText(
                              'Conditions', data['medical_conditions']),
                          detailText('Allergies', data['allergies']),
                          detailText('Diet Notes', data['diet_notes']),

                          // Vaccination / Report Section
                          if (data['report_type'] == 'pdf' &&
                              data['report_url'] != null)
                            _buildPdfReportSection(data['report_url']),
                          if (data['report_type'] == 'manually_entered' &&
                              (data['vaccines'] as List?)?.isNotEmpty == true)
                            _buildVaccinationSection(data['vaccines']),
                          if (data['report_type'] == 'never')
                            _buildNeverVaccinatedSection(),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Additional Images Gallery ────────────────
                if (petImagesList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  sectionTitle('Additional Photos'), // Uses your existing helper
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100, // Fixed height for the horizontal list
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: petImagesList.length,
                      itemBuilder: (ctx, index) {
                        final imageUrl = petImagesList[index];

                        // 1. Define the common prefix for all Hero tags for this pet
                        final heroTagPrefix = 'pet-gallery-image-$petId';

                        // 2. Create the unique tag for this specific image thumbnail
                        final tag = '${heroTagPrefix}-${index}';

                        return GestureDetector(
                          onTap: () {
                            // 3. Push to the new swipable gallery
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageGallery(
                                  imageUrls:
                                  petImagesList, // Pass the whole list
                                  initialIndex:
                                  index, // Pass the tapped index
                                  heroTagPrefix:
                                  heroTagPrefix, // Pass the tag prefix
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: tag, // This tag now matches the one in PageView
                            child: Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.pets,
                                        color: Colors.grey),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.error_outline,
                                            color: Colors.red),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // ── End of Additional Images ────────────────
              ],
            ),
          ),
        ),
      ));
    }

    return cards;
  }

  // --- All the helper methods ---

  Widget _buildPdfReportSection(String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('View Health Report (PDF)',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVaccinationSection(List<dynamic> vaccines) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vaccination Records:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              )),
          const SizedBox(height: 6),
          for (final v in vaccines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '• ${v['name']} — ${DateFormat.yMMMd().format((v['dateGiven'] as Timestamp).toDate())}',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNeverVaccinatedSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text('Vaccination: Never Vaccinated',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade800,
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _petDetailChip(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poppins(
            color: primaryColor, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _petDetailInfo(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value,
              style:
              GoogleFonts.poppins(color: Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }




  /// A small helper to render a label/value pair as a pill.
  Widget _detailChip(String label, String value) {
    return Chip(
      backgroundColor: Colors.grey.shade200,
      label: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }




  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}


class ExpandableDateList extends StatefulWidget {
  final List<DateTime> dates;
  final Color highlightColor;
  final bool Function(DateTime) isHighlighted;
  const ExpandableDateList({
    Key? key,
    required this.dates,
    required this.highlightColor,
    required this.isHighlighted,
  }) : super(key: key);

  @override
  _ExpandableDateListState createState() => _ExpandableDateListState();
}

class _ExpandableDateListState extends State<ExpandableDateList> {
  bool _expanded = false;

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year}';

  Widget _buildBubble(DateTime dt) {
    final high = widget.isHighlighted(dt);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: high
            ? widget.highlightColor.withOpacity(0.2)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _format(dt),
        style: TextStyle(
          fontSize: 12,
          color: high ? widget.highlightColor : Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.dates.length - 1;
    final toShow = _expanded ? widget.dates : widget.dates.take(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ← toggle between horizontal vs vertical
        _expanded
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: toShow.map(_buildBubble).toList(),
        )
            : Wrap(
          spacing: 6,
          runSpacing: 6,
          children: toShow.map(_buildBubble).toList(),
        ),

        if (extra > 0)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: primary,
            ),
            label: Text(
              _expanded
                  ? 'Show less'
                  : 'Show $extra more date${extra > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
          ),
      ],
    );
  }
}

