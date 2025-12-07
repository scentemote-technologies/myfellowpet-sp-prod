  import 'dart:async';
  import 'dart:convert';
  import 'dart:math';
  
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:csv/csv.dart';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:intl/intl.dart';
  import 'package:universal_html/html.dart' as html;
  import 'package:url_launcher/url_launcher.dart';
  

  import '../../shared/highlight_mode.dart';
import 'boarding_requests.dart';
  
  // --- Color constants ---
  const Color primaryColor = Color(0xFF2CB4B6);
  const Color accentColor = Color(0xFFF67B0D);
  const Color kPrimary = Color(0xFF2CB4B6);
  const Color _ongoingColor = Color(0xFF4CAF50);
  const Color _completedColor = Color(0xFF757575);
  const Color _offlineColor = Color(0xFF558194); // A professional Blue-Gray
  final Color _borderColor = Colors.grey.shade500;
  // ---
  
  enum CalendarType { confirmed, completed }
  
  class MonthDateInfo {
    final DateTime firstDayOfMonth;
    final int daysInMonth;
    final int startingWeekday;
  
    MonthDateInfo(DateTime focusedMonth)
        : firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1),
          daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month),
          startingWeekday = DateTime(focusedMonth.year, focusedMonth.month, 1).weekday;
  
    int get weeksInMonth {
      final days = startingWeekday - 1 + daysInMonth;
      return (days / 7).ceil();
    }
  }
  
  class BookingEvent {
    final DocumentSnapshot doc;
    final DateTimeRange range;
    final List<DateTime> allSelectedDates;
  
    BookingEvent({required this.doc, required this.range, required this.allSelectedDates});
  
    String get orderId => doc.id;
    Map<String, dynamic> get rawData => doc.data() as Map<String, dynamic>;
  }

  class MonthlyBookingCalendar extends StatefulWidget {
    final String serviceId;
    final CalendarType calendarType;
    // ADD THESE TWO LINES BACK
    final Function(DocumentSnapshot) onStart;
    final Function(DocumentSnapshot) onComplete;

    const MonthlyBookingCalendar({
      Key? key,
      required this.serviceId,
      required this.calendarType, required this.onStart, required this.onComplete,
    }) : super(key: key);
  
    @override
    State<MonthlyBookingCalendar> createState() => _MonthlyBookingCalendarState();
  }

  class _MonthlyBookingCalendarState extends State<MonthlyBookingCalendar> {
    // --- STATE VARIABLES ---
    bool _isLoading = true;
    DateTime? _hoveredDate; // <-- ADD THIS LINE
  
    late DateTime _focusedMonth;
  
    // Data from Firestore
    int _maxPetsAllowed = 0;
    final Map<DateTime, int> _bookingCountMap = {};
    final Set<DateTime> _unavailDates = {};
    List<BookingEvent> _bookingEvents = [];
    // --- START OF MODIFICATIONS ---
    // Replace the old _allDocs and _bookingSub
    List<DocumentSnapshot> _confirmedDocs = [];
    List<DocumentSnapshot> _completedDocs = [];
    StreamSubscription? _confirmedBookingSub;
    StreamSubscription? _completedBookingSub;
    StreamSubscription? _bookingSub;
    // ---
  
    // --- STYLE CONSTANTS ---
    final double _dayNumberHeaderHeight = 35.0;
    final double _bookingChipHeight = 46.0; // Total height (30 for main label + 16 for status)
    final double _bookingRowVerticalPadding = 4.0;
    final double _indicatorBarHeight = 3.0;
    final double _minWeekRowHeight = 120.0; // <--
    final TextStyle _slotTextStyle = GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700);
  // ADD THIS LINE
  
    // ---

    @override
    void initState() {
      super.initState();

      _focusedMonth = DateTime.now();
      _initializeCalendarData();
    }

    // In _MonthlyBookingCalendarState
    @override
    void dispose() {
      _confirmedBookingSub?.cancel(); // <-- MODIFIED
      _completedBookingSub?.cancel(); // <-- MODIFIED
      super.dispose();
    }
  
    // In _MonthlyBookingCalendarState
  
  // 1. REWRITE the _initializeCalendarData method
    Future<void> _initializeCalendarData() async {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final serviceRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId);

      // This part is unchanged
      final doc = await serviceRef.get();
      if (doc.exists) {
        _maxPetsAllowed = int.tryParse((doc.data()?['max_pets_allowed'] ?? '0').toString()) ?? 0;
      }
      final uaSnap = await serviceRef.collection('unavailabilities').get();
      _unavailDates.clear();
      for (var doc in uaSnap.docs) {
        final dates = (doc.data()['dates'] as List<dynamic>?)?.cast<Timestamp>() ?? [];
        for (var ts in dates) {
          _unavailDates.add(DateUtils.dateOnly(ts.toDate()));
        }
      }

      // Cancel any previous subscriptions
      _confirmedBookingSub?.cancel();
      _completedBookingSub?.cancel();
      _confirmedDocs = [];
      _completedDocs = [];

      // This is the new combined listener logic
      if (widget.calendarType == CalendarType.confirmed) {
        // Listen to confirmed requests
        _confirmedBookingSub = serviceRef.collection('service_request_boarding').snapshots().listen((snapshot) {
          _confirmedDocs = snapshot.docs;
          _reprocessAllDocs();
        });
        // ALSO listen to completed orders
        _completedBookingSub = serviceRef.collection('completed_orders').snapshots().listen((snapshot) {
          _completedDocs = snapshot.docs;
          _reprocessAllDocs();
        });
      } else {
        // For completed view, only listen to completed orders
        _completedBookingSub = serviceRef.collection('completed_orders').snapshots().listen((snapshot) {
          _completedDocs = snapshot.docs;
          _reprocessAllDocs();
        });
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

  // 2. ADD this new helper method to combine data from the streams
    void _reprocessAllDocs() {
      final combined = <DocumentSnapshot>[..._confirmedDocs, ..._completedDocs];
      // Pass the combined list to the processor
      _processBookingSnapshot(combined);
    }
  
  
  // 3. MODIFY the _processBookingSnapshot method
    void _processBookingSnapshot(List<DocumentSnapshot> docs) {
      final newBookingEvents = <BookingEvent>[];
      final newBookingCounts = <DateTime, int>{};

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isCompleted = doc.reference.parent.id == 'completed_orders';

        if (!isCompleted) {
          final mode = (data['mode'] as String?) ?? '';
          if (!['Pending', 'Confirmed', 'Offline', 'Online'].contains(mode)) continue;
        }

        final rawDates = (data['selectedDates'] as List<dynamic>?)?.map((e) => (e as Timestamp).toDate()).toList() ?? [];
        if (rawDates.isEmpty) continue;

        // --- FIX IS HERE ---
        // 1. Create a new list with time components removed.
        final allDates = rawDates.map((d) => DateUtils.dateOnly(d)).toList();
        allDates.sort();

        // Use the original rawDates list to preserve the original timestamps for the BookingEvent
        final originalDatesSorted = List<DateTime>.from(rawDates)..sort();


        final numPets = data['numberOfPets'] as int? ?? (data['pet_id'] as List<dynamic>? ?? []).length;

        // This part is now correct as it uses the clean `allDates` list
        for (final date in allDates) {
          newBookingCounts[date] = (newBookingCounts[date] ?? 0) + numPets;
        }

        // 2. Use the clean `allDates` list for the grouping logic.
        DateTime start = allDates.first;
        DateTime end = allDates.first;
        for (int i = 1; i < allDates.length; i++) {
          if (allDates[i].difference(end).inDays == 1) {
            end = allDates[i];
          } else {
            newBookingEvents.add(BookingEvent(doc: doc, range: DateTimeRange(start: start, end: end), allSelectedDates: originalDatesSorted));
            start = allDates[i];
            end = allDates[i];
          }
        }
        newBookingEvents.add(BookingEvent(doc: doc, range: DateTimeRange(start: start, end: end), allSelectedDates: originalDatesSorted));
      }

      if (mounted) {
        setState(() {
          _bookingEvents = newBookingEvents;
          _bookingCountMap.clear();
          _bookingCountMap.addAll(newBookingCounts);
        });
      }
    }
    void _changeMonth(int monthIncrement) {
      setState(() {
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + monthIncrement, 1);
      });
    }
    /// A responsive color key legend for the calendar bookings.
    Widget buildColorIndicator() {
      // Define the colors and their meanings
      const Color kPrimary = Color(0xFF2CB4B6);
      const Color _ongoingColor = Color(0xFF4CAF50);
      const Color _completedColor = Color(0xFF757575);
      const Color _offlineColor = Color(0xFF558194);
  
      return LayoutBuilder(
        builder: (context, constraints) {
          // Compact layout = mobile (force horizontal scroll)
          final bool isMobile = constraints.maxWidth < 500;
  
          final items = [
            _buildLegendItem(_ongoingColor, 'Ongoing'),
            _buildLegendItem(kPrimary, 'Upcoming'),
            _buildLegendItem(_completedColor, 'Past'),
            _buildLegendItem(_offlineColor, 'Offline'),
            _buildNAItem('No slots left'),
            _buildUAItem('Unavailable'),
          ];
  
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isMobile
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items
                    .map((w) => Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: w,
                ))
                    .toList(),
              ),
            )
                : Wrap(
              spacing: 24.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: items,
            ),
          );
        },
      );
    }
  
  
    /// Builds a stylish text-based indicator for "Not Available".
    Widget _buildNAItem(String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text("NA", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kPrimary)),
            backgroundColor: kPrimary.withOpacity(0.1),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            side: BorderSide.none,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
  
    /// Builds a stylish text-based indicator for "Unavailable".
    Widget _buildUAItem(String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text("UA", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            backgroundColor: Colors.red.withOpacity(0.1),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            side: BorderSide.none,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
  
    /// Builds a legend item with a colored dot and a label.
    Widget _buildLegendItem(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14, // Slightly smaller dot
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2), // White border for contrast
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
  
  
  // --- END: LEGEND SNIPPET ---
  
    // ... (build methods and helpers from previous responses) ...
    @override
    Widget build(BuildContext context) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator(color: kPrimary));
      }
      const double mobileBreakpoint = 650.0;
  
      return Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                // Only show the Mon-Sun labels for the grid view
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < mobileBreakpoint) {
                    return const SizedBox.shrink(); // Hide labels in agenda view
                  }
                  return _buildDayOfWeekLabels();
                }),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              // *** THE CORE LOGIC SWITCH ***
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < mobileBreakpoint) {
                    // Use Agenda View for narrow screens
                    return _buildAgendaView();
                  } else {
                    // Use Grid View for wide screens
                    return _buildCalendarGrid();
                  }
                },
              ),
            ),
          ),
          buildColorIndicator(),
        ],
      );
    }
  
    /// Builds a scrollable list view for mobile screens.
    Widget _buildAgendaView() {
      final monthInfo = MonthDateInfo(_focusedMonth);
      final today = DateUtils.dateOnly(DateTime.now());
  
      return ListView.builder(
        itemCount: monthInfo.daysInMonth,
        itemBuilder: (context, index) {
          final date = DateTime(monthInfo.firstDayOfMonth.year, monthInfo.firstDayOfMonth.month, index + 1);
          final bool isToday = DateUtils.isSameDay(date, today);
  
          // Find all bookings that occur on this specific day
          final dailyEvents = _bookingEvents.where((event) {
            return event.allSelectedDates.any((d) => DateUtils.isSameDay(d, date));
          }).toList();
  
  // Add this line to check for unavailability
          final bool isUnavailable = _unavailDates.contains(date);
  
  // Pass it as a new argument
          return _buildAgendaDayItem(date, isToday, dailyEvents, isUnavailable);
        },
      );
    }
  
    /// Builds the list item for a single day in the agenda view.
    /// This is the main method you requested.
    Widget _buildAgendaDayItem(DateTime date, bool isToday, List<BookingEvent> dailyEvents, bool isUnavailable) {
      // First, check if the date is unavailable and show a special UI for it.
      if (isUnavailable) {
        return _buildUnavailableAgendaDayItem(date, isToday);
      }
  
      // If the day is available, build the regular tappable item.
      final bookedCount = _bookingCountMap[date] ?? 0;
      final slotsLeft = _maxPetsAllowed > 0 ? _maxPetsAllowed - bookedCount : -1; // -1 for unlimited
  
      return InkWell(
        onTap: () => _onDaySelected(date), // Makes the entire row tappable
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isToday ? kPrimary.withOpacity(0.05) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
              left: isToday ? const BorderSide(color: kPrimary, width: 4.0) : BorderSide.none,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Date display
              _buildAgendaDate(date, isToday),
              const SizedBox(width: 16),
              // Right side: Bookings for the day
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show available slots
                    if (_maxPetsAllowed > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          slotsLeft > 0 ? '$slotsLeft slots left' : 'No slots left',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: slotsLeft > 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    // List bookings or show "No bookings" message
                    if (dailyEvents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No bookings',
                          style: GoogleFonts.poppins(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ...dailyEvents.map((event) => _buildAgendaBookingCard(event)).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  
    /// Helper method to build the UI for an unavailable day.
    Widget _buildUnavailableAgendaDayItem(DateTime date, bool isToday) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100, // Muted background for disabled look
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAgendaDate(date, isToday),
            const SizedBox(width: 16),
            // Show a clear "Unavailable" chip instead of booking info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text('Unavailable', style: GoogleFonts.poppins(fontSize: 12)),
                    backgroundColor: Colors.grey.shade300,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  
    /// Helper to build the date part of the agenda item for reusability.
    Widget _buildAgendaDate(DateTime date, bool isToday) {
      return SizedBox(
        width: 50,
        child: Column(
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 3), // e.g., "Tue"
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isToday ? kPrimary : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 16,
              backgroundColor: isToday ? kPrimary : Colors.grey.shade200,
              child: Text(
                '${date.day}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }
  
    /// Builds a single booking card for the agenda list view.
    Widget _buildAgendaBookingCard(BookingEvent event) {
      final mode = event.rawData['mode'] as String? ?? '';
      final isOfficiallyCompleted = event.doc.reference.parent.id == 'completed_orders';
      final bool isCancelled = event.rawData['cancelled'] == true ||
          event.doc.reference.parent.id == 'cancelled_offline_bookings';
      final List<DateTime> allDates = event.allSelectedDates;
      final DateTime today = DateUtils.dateOnly(DateTime.now());
      final List<DateTime> remainingDates =
      allDates.where((d) => !d.isBefore(today)).toList();
      final int remainingPets = (event.rawData['numberOfPets'] ?? 0);

      // --- REUSE YOUR EXISTING COLOR LOGIC ---
      final Color statusColor;
      if (mode == 'Offline') {
        statusColor = _offlineColor;
      } else if (event.allSelectedDates.any((d) => DateUtils.isSameDay(d, today))) {
        statusColor = _ongoingColor;
      } else if (event.allSelectedDates.every((d) => d.isBefore(today))) {
        statusColor = _completedColor;
      } else {
        statusColor = kPrimary;
      }
      // ---
  
      final petCount = (event.rawData['pet_name'] as List<dynamic>? ?? []).length;
      final userName = event.rawData['user_name'] ?? 'N/A';
      final HighlightMode dialogMode = isOfficiallyCompleted ? HighlightMode.past
          : (event.allSelectedDates.any((d) => DateUtils.isSameDay(d, today)) ? HighlightMode.ongoing
          : (event.allSelectedDates.every((d) => d.isBefore(today)) ? HighlightMode.awaitingFinalization
          : HighlightMode.upcoming));

      if (isCancelled && remainingDates.isEmpty && remainingPets == 0) {        return Card(
          color: Colors.white,
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Text(
                    "Order Cancelled",
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
  
  
      return Card(
        color: Colors.white,
        elevation: 1.5,
        margin: const EdgeInsets.only(bottom: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          // --- REUSE YOUR EXISTING ONTAP LOGIC ---
          onTap: () {
            if (mode == 'Offline') {
              _onDaySelected(event.range.start);
            } else {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  contentPadding: const EdgeInsets.all(16),
                  content: SizedBox(
                    width: 400,
                    child: BoardingRequestCard(
                      doc: event.doc,
                      selectedDates: event.allSelectedDates,
                      serviceId: widget.serviceId,
                      mode: dialogMode,
                      frompending: false,
                      onStart: () { Navigator.pop(ctx); widget.onStart(event.doc); },
                      onComplete: () { Navigator.pop(ctx); widget.onComplete(event.doc); },
                    ),
                  ),
                ),
              );
            }
          },
          child: Row(
            children: [
              // Status color bar
              Container(
                width: 6,
                height: 60, // Adjust height as needed
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.orderId}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$userName • $petCount Pet${petCount == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
    }

    Widget _buildHeader() {
      // Your brand colors
      const Color primaryColor = Color(0xFF2CB4B6);
      // Using a strong red for the offline button as requested
      const Color offlineButtonColor = Color(0xFFD32F2F); // A strong Material red

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade500)),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          // The breakpoint for switching to a compact layout.
          bool isCompact = constraints.maxWidth < 600;

          // --- DYNAMIC STYLES BASED ON SCREEN WIDTH ---
          final double titleFontSize = isCompact ? 18.0 : 22.0;
          final String monthFormat = isCompact ? 'MMM yyyy' : 'MMMM yyyy'; // "Aug 2025" vs "August 2025"
          final double arrowIconSize = isCompact ? 28.0 : 32.0;
          // ---

          return Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, size: arrowIconSize), // Use dynamic size
                onPressed: () => _changeMonth(-1),
                tooltip: 'Previous Month',
                color: Colors.grey.shade600,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat(monthFormat).format(_focusedMonth), // Use dynamic format
                    style: GoogleFonts.poppins(
                        fontSize: titleFontSize, // Use dynamic font size
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
              ),
              if (isCompact) ...[
                // --- COMPACT VIEW (PHONE) ---
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: offlineButtonColor),
                  onPressed: _showMultiDateOfflineBookingDialog,
                  tooltip: 'Add Offline Booking',
                ),
              ] else ...[
                // --- WIDE VIEW (TABLET / LAPTOP) ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18, color: Colors.white,),
                  label: Text('Offline Booking',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onPressed: _showMultiDateOfflineBookingDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: offlineButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, size: arrowIconSize), // Use dynamic size
                onPressed: () => _changeMonth(1),
                tooltip: 'Next Month',
                color: Colors.grey.shade600,
              ),
            ],
          );
        }),
      );
    }

    Widget _buildDayOfWeekLabels() {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          children: days
              .map((day) => Expanded(
            child: Center(
              child: Text(
                day,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500),
              ),
            ),
          ))
              .toList(),
        ),
      );
    }
  
    Widget _buildCalendarGrid() {
      final monthInfo = MonthDateInfo(_focusedMonth);
      return LayoutBuilder(builder: (context, constraints) {
        final double dayWidth = constraints.maxWidth / 7;
        return SingleChildScrollView(
          child: Column(
            children: List.generate(monthInfo.weeksInMonth, (weekIndex) {
              return _buildWeekRow(weekIndex, monthInfo, dayWidth);
            }),
          ),
        );
      });
    }
  
    Future<void> _showUnavailableDatesDialog(BuildContext context, List<DateTime> unavailableDates) async {
      final formattedDates = unavailableDates.map((d) => DateFormat.yMMMd().format(d)).join(', ');
  
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Icon for visual feedback ---
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.red.shade100,
                    child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
                  ),
                  const SizedBox(height: 20),
  
                  // --- Styled Title ---
                  Text(
                    'Invalid Date Range',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
  
                  // --- Styled Message ---
                  Text(
                    'The range you selected includes dates that are unavailable:\n\n$formattedDates',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
                  ),
                  const SizedBox(height: 32),
  
                  // --- Styled "OK" Button ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('TRY AGAIN', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  
  // Helper function to check for unavailable dates within a range
    List<DateTime> _getUnavailableDatesInRange(DateTimeRange range, int petCount) {
      final unavailable = <DateTime>[];
      // Loop through each day in the selected range
      for (int i = 0; i <= range.end.difference(range.start).inDays; i++) {
        final day = DateUtils.dateOnly(range.start.add(Duration(days: i)));
  
        // Check against the two conditions from your selectableDayPredicate
        final isMarkedUnavailable = _unavailDates.contains(day);
        final bookedCount = _bookingCountMap[day] ?? 0;
        final hasEnoughSlots = (_maxPetsAllowed - bookedCount) >= petCount;
  
        if (isMarkedUnavailable || !hasEnoughSlots) {
          unavailable.add(day);
        }
      }
      return unavailable;
    }


    Future<void> _showMultiDateOfflineBookingDialog() async {
      // --- DIALOG STEP 1: Get number of pets ---
      // This part is already well-designed and responsive, no changes needed.
      final qtyCtrl = TextEditingController();
      final qtyForm = GlobalKey<FormState>();
      final petCount = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView( // Added for small screen safety
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Styled Title ---
                  Text(
                    'Offline Booking (Step 1 of 3)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  // --- Styled Subtitle ---
                  Text(
                    'How many pets will be staying?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  // --- Styled Form Field ---
                  Form(
                    key: qtyForm,
                    child: TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true, // Good UX to focus the field
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Number of Pets',
                        labelStyle: GoogleFonts.poppins(),
                        prefixIcon: Icon(Icons.pets_rounded, color: Colors.grey.shade500),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: kPrimary, width: 2.0),
                        ),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Enter at least 1';
                        if (_maxPetsAllowed > 0 && n > _maxPetsAllowed) return 'You can only host $_maxPetsAllowed pets at a time';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  // --- Styled Buttons ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade800,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (qtyForm.currentState!.validate()) {
                              Navigator.pop(context, int.parse(qtyCtrl.text));
                            }
                          },
                          child: Text('Next', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (petCount == null || petCount == 0) return;

      // --- DIALOG STEP 2: Get date range with THE NEW VALIDATION LOGIC ---
      DateTimeRange? selectedRange;
      bool isValidRange = false;
      final today = DateUtils.dateOnly(DateTime.now());

      // This loop will continue until a valid range is selected or the user cancels.
      while (!isValidRange) {
        final tempRange = await showDateRangePicker(
          context: context,
          initialDateRange: null,
          firstDate: today,
          lastDate: today.add(const Duration(days: 365)),
          helpText: 'SELECT BOOKING DATES',
          builder: (context, child) {
            final textTheme = Theme.of(context).textTheme;
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(primary: kPrimary, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
                textTheme: GoogleFonts.poppinsTextTheme(textTheme).apply(bodyColor: Colors.grey.shade800, displayColor: Colors.black),
                dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0))),
                textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700, textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: kPrimary,
                  elevation: 2,
                  titleTextStyle: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
              ),
              child: child!,
            );
          },
          selectableDayPredicate: (date, _, __) {
            final dayOnly = DateUtils.dateOnly(date);
            if (_unavailDates.contains(dayOnly)) return false;

            final bookedCount = _bookingCountMap[dayOnly] ?? 0;
            final availableSlots = _maxPetsAllowed - bookedCount;
            return availableSlots >= petCount;
          },
        );

        if (tempRange == null) return;

        final unavailableDates = _getUnavailableDatesInRange(tempRange, petCount);

        if (unavailableDates.isEmpty) {
          isValidRange = true;
          selectedRange = tempRange;
        } else {
          await _showUnavailableDatesDialog(context, unavailableDates);
        }
      }

      // --- DIALOG STEP 3: Get owner and pet details ---
      final nameCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      final petNameCtrls = List.generate(petCount, (_) => TextEditingController());
      final detailsForm = GlobalKey<FormState>();

      final detailsOk = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Offline Booking (Step 3 of 3)', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text('Please enter the owner and pet details.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  Form(
                    key: detailsForm,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Owner Name',
                            labelStyle: GoogleFonts.poppins(),
                            prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.grey.shade500),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: kPrimary, width: 2.0)),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneCtrl,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Owner Phone No.',
                            labelStyle: GoogleFonts.poppins(),
                            prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade500),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: kPrimary, width: 2.0)),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: notesCtrl,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Notes about pet(s) (Optional)',
                            labelStyle: GoogleFonts.poppins(),
                            prefixIcon: Icon(Icons.notes_rounded, color: Colors.grey.shade500),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: kPrimary, width: 2.0)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text('Pet Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(
                          petCount,
                              (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextFormField(
                              controller: petNameCtrls[i],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                labelText: 'Pet ${i + 1} Name',
                                labelStyle: GoogleFonts.poppins(),
                                prefixIcon: Icon(Icons.pets_rounded, color: Colors.grey.shade500),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: kPrimary, width: 2.0)),
                              ),
                              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade800, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), padding: const EdgeInsets.symmetric(vertical: 14.0)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (detailsForm.currentState!.validate()) {
                              Navigator.pop(context, true);
                            }
                          },
                          child: Text('Submit Booking', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), padding: const EdgeInsets.symmetric(vertical: 14.0), elevation: 2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (detailsOk != true) return;

      // --- FINAL STEP: Save to Firestore atomically with a WriteBatch ---
      final allDatesInRange = <DateTime>[];
      for (int i = 0; i <= selectedRange!.end.difference(selectedRange.start).inDays; i++) {
        allDatesInRange.add(DateUtils.dateOnly(selectedRange.start.add(Duration(days: i))));
      }

      try {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();
        final serviceRef = firestore.collection('users-sp-boarding').doc(widget.serviceId);

        // 1. Create a reference for the new booking document.
        final newBookingRef = serviceRef.collection('service_request_boarding').doc();

        // 2. Define the booking data.
        final bookingData = {
          'selectedDates': allDatesInRange.map((d) => Timestamp.fromDate(d)).toList(),
          'numberOfPets': petCount,
          'user_name': nameCtrl.text.trim(),
          'notes': notesCtrl.text.trim(),
          'phone_number': phoneCtrl.text.trim(),
          'pet_name': petNameCtrls.map((c) => c.text.trim()).toList(),
          'mode': 'Offline',
          'timestamp': FieldValue.serverTimestamp(),
        };

        // 3. Add the new booking creation to the batch.
        batch.set(newBookingRef, bookingData);

        // 4. Loop through dates and add summary increments to the batch.
        for (final date in allDatesInRange) {
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          final summaryRef = serviceRef.collection('daily_summary').doc(dateString);
          batch.set(
            summaryRef,
            {'bookedPets': FieldValue.increment(petCount)},
            SetOptions(merge: true), // Creates doc if it doesn't exist, otherwise updates
          );
        }

        // 5. Commit all operations at once.
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline booking for multiple dates saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save offline booking: $e')),
        );
      }
    }
  // In your _MonthlyBookingCalendarState class...
  
    // In _MonthlyBookingCalendarState class
  
    Widget _buildWeekRow(int weekIndex, MonthDateInfo monthInfo, double dayWidth) {
      final firstDayOfWeek = monthInfo.firstDayOfMonth
          .subtract(Duration(days: monthInfo.startingWeekday - 1))
          .add(Duration(days: weekIndex * 7));
      final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
  
      final weeklyEvents = _bookingEvents.where((e) {
        return e.range.start.isBefore(lastDayOfWeek.add(const Duration(days: 1))) &&
            e.range.end.isAfter(firstDayOfWeek.subtract(const Duration(days: 1)));
      }).toList();
  
      final Map<BookingEvent, int> weeklyLayouts = _calculateWeeklyLanes(weeklyEvents);
      final int maxLanesForWeek =
          weeklyLayouts.values.fold(0, (max, v) => v > max ? v : max) +
              (weeklyEvents.isEmpty ? 0 : 1);
  
      final double calculatedHeight = _dayNumberHeaderHeight +
          (maxLanesForWeek * (_bookingChipHeight + _bookingRowVerticalPadding));
      final double rowHeight = max(_minWeekRowHeight, calculatedHeight);
  
      return SizedBox(
        height: rowHeight,
        child: Stack(
          children: [
            // LAYER 1 (BOTTOM): The clickable day cells
            Row(
              children: List.generate(7, (dayIndex) {
                final date = firstDayOfWeek.add(Duration(days: dayIndex));
                final isHovered = DateUtils.isSameDay(date, _hoveredDate);
                final isCurrentMonth = date.month == monthInfo.firstDayOfMonth.month;
                // --- CHANGE 1: Check for unavailability here ---
                final bool isUnavailable = _unavailDates.contains(date);
  
                return MouseRegion(
                  onEnter: (_) {
                    if (isCurrentMonth) {
                      setState(() { _hoveredDate = date; });
                    }
                  },
                  onExit: (_) {
                    setState(() { _hoveredDate = null; });
                  },
                  child: Container(
                    width: dayWidth,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      // --- CHANGE 2: Set background color based on isUnavailable ---
                      color: isUnavailable
                          ? Colors.red.shade100
                          : (isHovered ? Colors.grey.shade100 : null),
                      border: Border.all(color: _borderColor, width: 0.5),
                    ),
                    // --- CHANGE 3: Pass isUnavailable flag to the cell builder ---
                    child: _buildDayCell(date, monthInfo, isHovered, isUnavailable),
                  ),
                );
              }),
            ),
  
            // LAYER 2 (TOP): The booking labels are drawn on top of the day cells.
            ..._buildBookingOverlaysForWeek(
                weeklyEvents, weeklyLayouts, firstDayOfWeek, dayWidth),
          ],
        ),
      );
    }
  
  
    // CORRECTED: _buildDayCell now accepts dayWidth again
    // UPDATED: _buildDayCell now accepts 'isUnavailable' and handles it as a special case
    Widget _buildDayCell(DateTime date, MonthDateInfo monthInfo, bool isHovered, bool isUnavailable) {
      // --- NEW: Handle the unavailable case first to show a special UI ---
      if (isUnavailable) {
        return Center(
          child: Text(
            'UA',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      // --- If not unavailable, build the standard day cell ---
  
      final today = DateUtils.dateOnly(DateTime.now());
      final bool isCurrentMonth = date.month == monthInfo.firstDayOfMonth.month;
      final bool isToday = DateUtils.isSameDay(date, today);
  
      final int bookedCount = _bookingCountMap[date] ?? 0;
      final bool isFullyBooked = _maxPetsAllowed > 0 && bookedCount >= _maxPetsAllowed;
  
      Widget statusWidget;
  
      // The 'isUnavailable' case is now handled by the block above
      if (isFullyBooked) {
        statusWidget = Text('(NA)', style: _slotTextStyle.copyWith(color: kPrimary, fontWeight: FontWeight.bold));
      } else {
        final slotsLeft = _maxPetsAllowed - bookedCount;
        statusWidget = Text('($slotsLeft left)', style: _slotTextStyle);
      }
  
      return GestureDetector(
        onTap: () => _onDaySelected(date),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Top row for the date number and availability status
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isCurrentMonth ? (isToday ? kPrimary : Colors.black87) : Colors.grey.shade400,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrentMonth && _maxPetsAllowed > 0) statusWidget,
                ],
              ),
            ),
  
            // Conditionally display the hover text in the center
            if (isHovered && isCurrentMonth)
              Center(
                child: Text(
                  'Click to see details',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );
    }
  
    Map<BookingEvent, int> _calculateWeeklyLanes(
        List<BookingEvent> weeklyEvents) {
      final Map<BookingEvent, int> layouts = {};
      weeklyEvents.sort((a, b) => a.range.start.compareTo(b.range.start));
      List<List<DateTimeRange>> lanes = [];
      for (var event in weeklyEvents) {
        int targetLane = 0;
        while (true) {
          if (lanes.length <= targetLane) lanes.add([]);
          bool hasConflict = lanes[targetLane].any((range) =>
          event.range.start
              .isBefore(range.end.add(const Duration(days: 1))) &&
              event.range.end
                  .isAfter(range.start.subtract(const Duration(days: 1))));
          if (!hasConflict) {
            lanes[targetLane].add(event.range);
            layouts[event] = targetLane;
            break;
          }
          targetLane++;
        }
      }
      return layouts;
    }
  
  
  
    List<Widget> _buildBookingOverlaysForWeek(
        List<BookingEvent> weeklyEvents,
        Map<BookingEvent, int> weeklyLayouts,
        DateTime firstDayOfWeek,
        double dayWidth) {
      return weeklyEvents.map((event) {
        final verticalLane = weeklyLayouts[event]!;
        final DateTime spanStart = event.range.start.isBefore(firstDayOfWeek)
            ? firstDayOfWeek
            : event.range.start;
        final DateTime lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
        final DateTime spanEnd = event.range.end.isAfter(lastDayOfWeek)
            ? lastDayOfWeek
            : event.range.end;
        final double left =
            max(0, spanStart.difference(firstDayOfWeek).inDays) * dayWidth;
        final int duration = spanEnd.difference(spanStart).inDays + 1;
        final double width = duration * dayWidth - 4.0;
        final double top = _dayNumberHeaderHeight +
            (verticalLane * (_bookingChipHeight + _bookingRowVerticalPadding));
        return Positioned(
          top: top,
          left: left + 2.0,
          width: width,
          height: _bookingChipHeight,
          child: _buildBookingChip(event, spanStart, spanEnd),
        );
      }).toList();
    }
  
    // In your _MonthlyBookingCalendarState class...
  
    // In _MonthlyBookingCalendarState class...

    Widget _buildBookingChip(
        BookingEvent event,
        DateTime spanStart,
        DateTime spanEnd,
        ) {
      final today = DateUtils.dateOnly(DateTime.now());
      final allDates = event.allSelectedDates;
      final String mode = event.rawData['mode'] as String? ?? '';
      // 🚫 Skip showing chip if order_status is pending_payment
      final String? orderStatus = event.rawData['order_status']?.toString().toLowerCase();
      if (orderStatus == 'pending_payment') {
        print('⚪ Skipping chip for ${event.orderId} — order_status = pending_payment');
        return const SizedBox.shrink();
      }

      final bool isCancelled = event.rawData['cancelled'] == true ||
          event.doc.reference.parent.id == 'cancelled_offline_bookings';

      final List<DateTime> remainingDates =
      allDates.where((d) => !d.isBefore(today)).toList();

      final int remainingPets = (event.rawData['numberOfPets'] ?? 0);
      final bool isOfficiallyCompleted =
          event.doc.reference.parent.id == 'completed_orders';

      // 🧾 DEBUG PRINTS
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🧩 BOOKING DEBUG INFO');
      print('Order ID: ${event.orderId}');
      print('Mode: $mode');
      print('Cancelled: $isCancelled');
      print('Officially Completed: $isOfficiallyCompleted');
      print('All Dates: $allDates');
      print('Remaining Dates: $remainingDates');
      print('Remaining Pets: $remainingPets');
      print('Parent Collection: ${event.doc.reference.parent.id}');
      print('Today: $today');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // --- UPDATED COLOR LOGIC ---
      final Color chipColor;
      if (isCancelled && remainingDates.isEmpty && remainingPets == 0) {
        print('🔴 Marking ${event.orderId} as CANCELLED — No pets/dates left');
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  "${event.orderId} • Order Cancelled",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            Container(
              height: 16.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                'Order Cancelled',
                style: GoogleFonts.poppins(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        );
      }

      if (mode == 'Offline') {
        chipColor = _offlineColor;
        print('🟣 Offline Booking — color = $_offlineColor');
      } else {
        if (allDates.any((d) => DateUtils.isSameDay(d, today))) {
          chipColor = _ongoingColor;
          print('🟢 ${event.orderId} → Ongoing (contains today’s date)');
        } else if (allDates.every((d) => d.isBefore(today))) {
          chipColor = _completedColor;
          print('⚫ ${event.orderId} → Completed (all before today)');
        } else {
          chipColor = kPrimary;
          print('🟦 ${event.orderId} → Upcoming (future dates present)');
        }
      }
      print('🎨 Final Color for ${event.orderId}: $chipColor');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // --- STATUS LABEL ---
      Widget statusIndicator;
      TextSpan? statusTextSpan;
      final bool isPast = allDates.every((d) => d.isBefore(today));
      final bool isOngoing = allDates.any((d) => DateUtils.isSameDay(d, today));

      if (!isOfficiallyCompleted) {
        if (isPast) {
          statusTextSpan = TextSpan(
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.black87),
            children: const [
              TextSpan(text: 'yet to '),
              TextSpan(
                text: 'complete',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          );
        } else if (isOngoing) {
          final bool hasStarted = event.rawData['startedAt'] != null;
          if (!hasStarted) {
            statusTextSpan = TextSpan(
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.black87),
              children: const [
                TextSpan(text: 'yet to '),
                TextSpan(
                  text: 'start',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            );
          } else {
            statusTextSpan = TextSpan(
              text: 'Ongoing',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: _ongoingColor,
              ),
            );
          }
        }
      }

      if (statusTextSpan != null) {
        statusIndicator = Container(
          height: 16.0,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          alignment: Alignment.center,
          child: RichText(text: statusTextSpan),
        );
      } else {
        statusIndicator = const SizedBox.shrink();
      }

      final int petCount =
          (event.rawData['pet_name'] as List<dynamic>? ?? []).length;

      final HighlightMode dialogMode;
      if (isOfficiallyCompleted) {
        dialogMode = HighlightMode.past;
      } else if (isOngoing) {
        dialogMode = HighlightMode.ongoing;
      } else if (isPast) {
        dialogMode = HighlightMode.awaitingFinalization;
      } else {
        dialogMode = HighlightMode.upcoming;
      }

      return GestureDetector(
        onTap: () {
          if (mode == 'Offline') {
            _onDaySelected(event.range.start);
          } else {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                contentPadding: const EdgeInsets.all(16),
                content: SizedBox(
                  width: 400,
                  child: BoardingRequestCard(
                    doc: event.doc,
                    selectedDates: event.allSelectedDates,
                    serviceId: widget.serviceId,
                    mode: dialogMode,
                    frompending: false,
                    onStart: () {
                      Navigator.pop(ctx);
                      widget.onStart(event.doc);
                    },
                    onComplete: () {
                      Navigator.pop(ctx);
                      widget.onComplete(event.doc);
                    },
                  ),
                ),
              ),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(4),
                    bottomLeft: statusTextSpan == null
                        ? const Radius.circular(4)
                        : Radius.zero,
                    bottomRight: statusTextSpan == null
                        ? const Radius.circular(4)
                        : Radius.zero,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  "${event.orderId} • $petCount Pet${petCount == 1 ? '' : 's'}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            statusIndicator,
          ],
        ),
      );
    }

    // --- DIALOG AND REPORT METHODS ---
  // In _MonthlyBookingCalendarState class...

    Future<void> _onDaySelected(DateTime date) async {
      print('CLICK REGISTERED for date: $date'); // <-- ADD THIS LINE

      final dayOnly = DateUtils.dateOnly(date);

      // --- FIX: Combine the two lists here ---
      final allCurrentDocs = [..._confirmedDocs, ..._completedDocs];

      // Use the new combined list to find matches
      final matchedDocs = allCurrentDocs.where((doc) {
        final dates = (doc.data() as Map<String, dynamic>)['selectedDates']
            ?.map<DateTime>((e) => (e as Timestamp).toDate())
            .toList() ??
            [];
        return dates.any((d) => DateUtils.isSameDay(d, dayOnly));
      }).toList();

      await showDialog(
        context: context,
        builder: (_) =>
            _buildDetailsDialog(context,dayOnly, matchedDocs),
      );
    }

    Widget _buildDetailsDialog(
        BuildContext context, DateTime date, List<DocumentSnapshot> matchedDocs) {
      // Helper function for a visually appealing empty state
      Widget buildEmptyState() {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No Bookings Found',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                Text(
                  'There are no bookings for this date.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      }

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Redesigned Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bookings — ${DateFormat.yMMMd().format(date)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- Scrollable Body ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: matchedDocs.isEmpty
                      ? buildEmptyState() // Using the new empty state
                      : Column(
                    children: matchedDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      // Assuming _buildBookingInfoCard exists and is styled
                      return _buildBookingInfoCard(doc, data);
                    }).toList(),
                  ),
                ),
              ),

              // --- Redesigned Footer Buttons ---
              if (widget.calendarType == CalendarType.confirmed)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showOfflineBookingDialog(date);
                          },
                          child: const Text('Add Offline'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            backgroundColor:
                            kPrimary, // Assumes kPrimary is your color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget _buildBookingInfoCard(DocumentSnapshot doc, Map<String, dynamic> data) {
      // Define your brand colors here for use in the card
      const Color primaryColor = Color(0xFF2CB4B6);
      const Color accentColor = Color(0xFFF67B0D);

      final petNames =
          (data['pet_name'] as List<dynamic>?)?.cast<String>() ?? [];
      final isOnline = data['mode'] == 'Online';
      final numPets = data['numberOfPets'] ?? petNames.length;

      // Determine the highlight color based on the booking mode
      final Color highlightColor = isOnline ? primaryColor : accentColor;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(
            left: BorderSide(color: highlightColor, width: 5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['user_name'] ?? 'Customer',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                  Chip(
                    label: Text(
                      data['mode'] ?? 'N/A',
                      style: GoogleFonts.poppins(
                        color: highlightColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: highlightColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: highlightColor.withOpacity(0.2)),
                    ),
                  ),
                ],
              ),
              Text(
                '$numPets pet${numPets > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
              ),
              const Divider(height: 24),
              _buildInfoRow(
                Icons.phone_outlined,
                data['phone_number'] ?? "N/A",
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.pets_outlined,
                'Pets: ${petNames.join(', ')}',
              ),
              const SizedBox(height: 12),
              if (!isOnline) ...[
                _buildInfoRow(
                  Icons.note_alt_outlined,
                  'Notes: ${data['notes'] ?? 'None'}',
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isOnline)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade400),
                      tooltip: 'Cancel offline booking',
                      onPressed: () async {
                        final cancel = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Text('Confirm Cancellation',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                            content: Text(
                                'Are you sure you want to cancel this booking?',
                                style: GoogleFonts.poppins()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('No', style: GoogleFonts.poppins()),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Yes, Cancel',
                                    style: GoogleFonts.poppins(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (cancel != true) return;

                        // --- NEW: Atomic deletion using a WriteBatch ---
                        final firestore = FirebaseFirestore.instance;
                        final batch = firestore.batch();
                        final serviceRef = firestore.collection('users-sp-boarding').doc(widget.serviceId);

                        // 1. Get data needed for decrement.
                        final dates = (data['selectedDates'] as List<dynamic>).map((d) => (d as Timestamp).toDate()).toList();
                        final numPets = data['numberOfPets'] as int? ?? 0;

                        // 2. Add summary decrements to the batch.
                        if (numPets > 0) {
                          for (final date in dates) {
                            final dateString = DateFormat('yyyy-MM-dd').format(date);
                            final summaryRef = serviceRef.collection('daily_summary').doc(dateString);
                            batch.update(summaryRef, {'bookedPets': FieldValue.increment(-numPets)});
                          }
                        }

                        // 3. Add the move and delete operations to the batch.
                        final cancelledRef = serviceRef.collection('cancelled_offline_bookings').doc(doc.id);
                        batch.set(cancelledRef, data);
                        batch.delete(doc.reference);

                        // 4. Commit all operations.
                        await batch.commit();

                        Navigator.pop(context); // Close the details dialog
                        // The UI will refresh automatically due to the StreamBuilder
                      },
                    ),
                  const Spacer(),
                  if (isOnline)
                    ElevatedButton.icon(
                      onPressed: () => _showPetDetailsDialog(
                        context,
                        petNames,
                        (data['pet_id'] as List<dynamic>?)?.cast<String>() ?? [],
                        data['user_id'],
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.white,),
                      label: const Text('View Pet Details'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: primaryColor,
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      );
    }
  
  // You can add this helper row widget inside your State class for clean code
    Widget _buildInfoRow(IconData icon, String text) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      );
    }

    Future<void> _showOfflineBookingDialog(DateTime date) async {
      final norm = DateTime(date.year, date.month, date.day);
      final already = _bookingCountMap[norm] ?? 0;
      final avail = _maxPetsAllowed - already;

      // The responsive logic: shows a bottom sheet on mobile, dialog on desktop.
      // Both will contain the new stateful form widget.
      if (MediaQuery.of(context).size.width < 600) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _OfflineBookingForm(
            date: norm,
            availableSlots: avail,
            serviceId: widget.serviceId,
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: _OfflineBookingForm(
              date: norm,
              availableSlots: avail,
              serviceId: widget.serviceId,
            ),
          ),
        );
      }
      // After the modal closes, refresh the state to show the new booking
      setState(() {});
    }
  // In _MonthlyBookingCalendarState class...
  
    Future<void> _downloadMonthlyReport(DateTime month) async {
      final monthName = DateFormat('MMMM_yyyy').format(month);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Download Report?', style: GoogleFonts.poppins()),
          content: Text(
            'Download daily summary for ${DateFormat('MMMM yyyy').format(month)}?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Download')),
          ],
        ),
      );
  
      if (confirm != true) return;
  
      // --- FIX: Combine the two authoritative lists here ---
      final allCurrentDocs = [..._confirmedDocs, ..._completedDocs];
  
      // Use the new combined list to find relevant documents for the report
      final relevantDocs = allCurrentDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dates = (data['selectedDates'] as List<dynamic>?)?.whereType<Timestamp>().toList() ?? [];
        return dates.any((ts) {
          final date = ts.toDate();
          return date.year == month.year && date.month == month.month;
        });
      }).toList();
  
      if (relevantDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bookings found for this month.')));
        return;
      }
  
      final List<List<dynamic>> rows = [];
      rows.add(['Index', 'Date', 'Orders']);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  
      for (int i = 1; i <= daysInMonth; i++) {
        final currentDate = DateTime(month.year, month.month, i);
        final bookingsForThisDay = relevantDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dates = (data['selectedDates'] as List<dynamic>?)?.whereType<Timestamp>().toList() ?? [];
          return dates.any((ts) => DateUtils.isSameDay(ts.toDate(), currentDate));
        }).toList();
  
        String ordersDetails = bookingsForThisDay.isNotEmpty
            ? bookingsForThisDay.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // --- FIX: Add a check to label completed orders in the report ---
          final isCompleted = doc.reference.parent.id == 'completed_orders';
          final status = isCompleted ? 'Completed' : (data['mode'] ?? 'N/A');
  
          return 'ID: ${doc.id}\n'
              'Status: $status\n'
              'Owner: ${data['user_name'] ?? 'N/A'}\n'
              'Phone: ${data['phone_number'] ?? 'N/A'}\n'
              'Pets: ${(data['pet_name'] as List<dynamic>? ?? []).join(', ')}\n'
              'Notes: ${data['notes'] ?? ''}';
        }).join('\n\n')
            : 'No bookings';
  
        rows.add([i, DateFormat('yyyy-MM-dd').format(currentDate), ordersDetails]);
      }
  
      String csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Daily_Summary_${monthName}.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }
  
  // --- TOP-LEVEL HELPER FUNCTIONS FOR PET DETAILS DIALOG ---
  void _showPetDetailsDialog(
      BuildContext context,
      List<String> petNames,
      List<String> petIds,
      String userId,
      ) {
    final count = min(petNames.length, petIds.length);
  
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pet Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: FutureBuilder<List<Widget>>(
            future: _buildPetCards(petNames, petIds, userId),
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
  
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No pet data found', style: GoogleFonts.poppins()));
              }
  
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: snapshot.data!,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  Future<List<Widget>> _buildPetCards(
      List<String> names, List<String> ids, String userId) async {
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
  
      Widget sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
      );
  
      Widget detailText(String label, dynamic value) {
        if (value == null || (value is String && value.isEmpty)) return const SizedBox();
  
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555), // Slightly darker gray
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['pet_images'] != null && (data['pet_images'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text('Images', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (data['pet_images'] as List).map<Widget>((url) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                const SizedBox(height: 5),
  
                Text(petName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    detailText('Gender', data['gender']),
                    detailText('Type', data['pet_type']),
                    detailText('Breed', data['pet_breed']),
                    detailText('Age', data['pet_age']),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle('Weight'),
                          if (data['weight_type'] == 'exact')
                            detailText('Weight', '${data['weight']} kg'),
                          if (data['weight_type'] == 'range')
                            detailText('Range', data['weight_range']),
                          sectionTitle('Preferences'),
                          if ((data['likes'] as List<dynamic>?)?.isNotEmpty ?? false)
                            detailText('Likes', (data['likes'] as List).join(', ')),
                          if ((data['dislikes'] as List<dynamic>?)?.isNotEmpty ?? false)
                            detailText('Dislikes', (data['dislikes'] as List).join(', ')),
                          sectionTitle('Vet Info'),
                          detailText('Vet', data['vet_name']),
                          detailText('Vet Phone', data['vet_phone']),
                          detailText('Emergency Contact', data['emergency_contact']),
  
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle('Medical Info'),
                          detailText('Medical History', data['medical_history']),
                          detailText('Conditions', data['medical_conditions']),
                          detailText('Allergies', data['allergies']),
                          detailText('Diet Notes', data['diet_notes']),
                          detailText('Neutered', data['is_neutered'] == true ? 'Yes' : 'No'),
                        ],
                      ),
                    ),
                  ],
                ),
  
  
                if (data['report_type'] == 'pdf' && data['report_url'] != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: () => launchUrl(Uri.parse(data['report_url'])),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Download PDF',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (data['report_type'] == 'manually_entered' && (data['vaccines'] as List?)?.isNotEmpty == true) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vaccination Records:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 6),
                        for (final v in data['vaccines'] as List<dynamic>)
                          Text(
                            '${v['name']} — ${DateFormat.yMMMd().format((v['dateGiven'] as Timestamp).toDate())}'
                                '${v['nextDue'] != null ? ' (Next due: ${DateFormat.yMMMd().format((v['nextDue'] as Timestamp).toDate())})' : ''}',
                            style: GoogleFonts.poppins(),
                          ),
                      ],
                    ),
                  ),
                ] else if (data['report_type'] == 'never') ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Never Vaccinated',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ],
  
              ],
            ),
          ),
        ),
      ));
    }
    return cards;
  }

  class _OfflineBookingForm extends StatefulWidget {
    final DateTime date;
    final int availableSlots;
    final String serviceId;

    const _OfflineBookingForm({
      Key? key,
      required this.date,
      required this.availableSlots,
      required this.serviceId,
    }) : super(key: key);

    @override
    __OfflineBookingFormState createState() => __OfflineBookingFormState();
  }

  class __OfflineBookingFormState extends State<_OfflineBookingForm> {
    int _step = 1;
    int _petCount = 0;
    bool _isSubmitting = false;

    // Step 1 controllers
    final _qtyFormKey = GlobalKey<FormState>();
    final _qtyCtrl = TextEditingController();

    // Step 2 controllers
    final _detailsFormKey = GlobalKey<FormState>();
    final _nameCtrl = TextEditingController();
    final _notesCtrl = TextEditingController();
    final _phoneCtrl = TextEditingController();
    List<TextEditingController> _petNameCtrls = [];

    @override
    void dispose() {
      _qtyCtrl.dispose();
      _nameCtrl.dispose();
      _notesCtrl.dispose();
      _phoneCtrl.dispose();
      for (var ctrl in _petNameCtrls) {
        ctrl.dispose();
      }
      super.dispose();
    }

    // [REPLACE] your _goToStep2 method with this

    void _goToStep2() {
      if (_qtyFormKey.currentState!.validate()) {
        setState(() {
          _petCount = int.parse(_qtyCtrl.text);
          // Initialize controllers for the pet name fields in step 2
          _petNameCtrls =
          // --- THIS LINE IS FIXED ---
          List.generate(_petCount, (_) => TextEditingController());
          _step = 2;
        });
      }
    }

    // --- THIS IS THE UPDATED METHOD ---
    Future<void> _submitForm() async {
      if (!_detailsFormKey.currentState!.validate()) return;

      setState(() => _isSubmitting = true);

      try {
        // 1. Initialize Firestore and a new WriteBatch for atomic operations.
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();
        final serviceRef = firestore.collection('users-sp-boarding').doc(widget.serviceId);

        // 2. Create a reference for the new booking document.
        final newBookingRef = serviceRef.collection('service_request_boarding').doc();

        // 3. Define the booking data.
        final bookingData = {
          'selectedDates': [Timestamp.fromDate(widget.date)],
          'numberOfPets': _petCount,
          'user_name': _nameCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim(),
          'pet_name': _petNameCtrls.map((c) => c.text.trim()).toList(),
          'mode': 'Offline',
          'timestamp': FieldValue.serverTimestamp(),
        };

        // 4. Add the new booking creation to the batch.
        batch.set(newBookingRef, bookingData);

        // 5. Add the daily_summary increment and timestamp operation to the batch.
        final dateString = DateFormat('yyyy-MM-dd').format(widget.date);
        final summaryRef = serviceRef.collection('daily_summary').doc(dateString);

        batch.set(
          summaryRef,
          {
            'bookedPets': FieldValue.increment(_petCount),
            'lastUpdated': FieldValue.serverTimestamp(), // <-- This line is added
          },
          SetOptions(merge: true), // Creates the doc if it doesn't exist, otherwise updates.
        );

        // 6. Commit all database changes at once.
        await batch.commit();

        if (mounted) {
          Navigator.pop(context); // Close the dialog/sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offline booking saved.', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save booking: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
    // --- END OF UPDATED METHOD ---

    @override
    Widget build(BuildContext context) {
      final isBottomSheet = MediaQuery.of(context).size.width < 600;

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isBottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header ---
              Text(
                'Add Offline Booking',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'For ${DateFormat.yMMMd().format(widget.date)}',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),

              // --- Body (Switches between Step 1 and 2) ---
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _step == 1 ? _buildStep1() : _buildStep2(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Footer Buttons ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_step == 1) {
                          Navigator.pop(context);
                        } else {
                          setState(() => _step = 1);
                        }
                      },
                      child: Text(_step == 1 ? 'Cancel' : 'Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (_step == 1 ? _goToStep2 : _submitForm),
                      child: _isSubmitting
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_step == 1 ? 'Next' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    }

    Widget _buildStep1() {
      return Form(
        key: _qtyFormKey,
        child: Column(
          key: const ValueKey('step1'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 1 of 2: How many pets?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Available slots: ${widget.availableSlots}',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _qtyCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Number of Pets',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) return 'Enter at least 1';
                if (n > widget.availableSlots) return 'Only ${widget.availableSlots} slots left';
                return null;
              },
            ),
          ],
        ),
      );
    }

    Widget _buildStep2() {
      return Form(
        key: _detailsFormKey,
        child: Column(
          key: const ValueKey('step2'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 2 of 2: Guest Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: 'Owner Phone No.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const Divider(height: 32),
            ...List.generate(_petCount, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _petNameCtrls[i],
                  decoration: InputDecoration(labelText: 'Pet ${i + 1} Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              );
            }),
          ],
        ),
      );
    }
  }
  
  
  
  
  
  
