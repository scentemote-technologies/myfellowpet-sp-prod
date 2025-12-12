// lib/screens/holiday_declaration_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../Colors/AppColor.dart';
import '../Partner/email_signin.dart' hide primaryColor;



class HolidayDeclarationPage extends StatefulWidget {
  final String serviceId;
  const HolidayDeclarationPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _HolidayDeclarationPageState createState() => _HolidayDeclarationPageState();
}

class _HolidayDeclarationPageState extends State<HolidayDeclarationPage> {
  final Set<DateTime> _persistedHolidays = {};
  final Set<DateTime> _pendingHolidays = {};
  final Map<DateTime, int> _bookingCount = {};
  final Set<DateTime> _orderDates = {}, _nextDates = {};
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  late final DocumentReference _svcRef;
  int _monthlyAllowance = 7;

  @override
  void initState() {
    super.initState();
    _svcRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId);
    _loadAllData();
  }

  // In _HolidayDeclarationPageState

  Future<void> _loadAllData() async {
    try {
      // 1) Global allowance (no changes needed here)
      final cfg = await FirebaseFirestore.instance.collection('company_documents')
          .doc('unavailability').get();
      if (cfg.exists) {
        _monthlyAllowance = int.tryParse(
          (cfg.data()?['boarding_unavailability_allowance'] ?? '7').toString(),
        ) ?? 7;
      }

      // 2) Existing unavailabilities (with the fix)
      _persistedHolidays.clear();
      final uaSnap = await _svcRef.collection('unavailabilities').get();
      for (var d in uaSnap.docs) {
        // --- THIS IS THE FIX ---
        // Instead of a direct cast, we safely parse the list.
        final datesList = d.data()['dates'] as List<dynamic>? ?? [];
        for (var item in datesList) {
          if (item is Timestamp) {
            final dt = item.toDate();
            _persistedHolidays.add(DateTime(dt.year, dt.month, dt.day));
          }
        }
        // --- END OF FIX ---
      }

      // 3) Bookings (with the fix)
      _bookingCount.clear();
      final bSnap = await _svcRef.collection('service_request_boarding').get();
      for (var d in bSnap.docs) {
        final data = d.data();
        final status = data['status'] as String? ?? '';
        if (status != 'Pending' && status != 'Confirmed') continue;
        final cnt = data['numberOfPets'] as int? ?? 1;

        // --- THIS IS THE FIX ---
        // Safely parse the selectedDates list.
        final selectedDatesList = data['selectedDates'] as List<dynamic>? ?? [];
        for (var item in selectedDatesList) {
          if (item is Timestamp) {
            final dt = item.toDate();
            final norm = DateTime(dt.year, dt.month, dt.day);
            _bookingCount[norm] = (_bookingCount[norm] ?? 0) + cnt;
          }
        }
        // --- END OF FIX ---
      }
      _orderDates
        ..clear()
        ..addAll(_bookingCount.keys);
      _nextDates
        ..clear()
        ..addAll(_orderDates.map((d) => d.add(const Duration(days: 1))));

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isOrderDay(DateTime d) => _orderDates.contains(_norm(d));
  bool _isNextDay(DateTime d) => _nextDates.contains(_norm(d));
  DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  // [REPLACE] your entire _onDone function with this

  Future<void> _onDone() async {
    if (_pendingHolidays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No new dates selected.', style: GoogleFonts.poppins())),
      );
      return;
    }

    // Confirm with reason (This part remains unchanged)
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 64, vertical: 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Confirm Unavailability', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                Text(
                  'You are blocking ${_pendingHolidays.length} date${_pendingHolidays.length > 1 ? 's' : ''}:',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                SizedBox(height: 8),
                ..._pendingHolidays.map((d) => Text('• ${DateFormat.yMMMd().format(d)}', style: GoogleFonts.poppins(fontSize: 14))),
                SizedBox(height: 16),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reason for blocking',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) Navigator.pop(context, true);
                        },
                        child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
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

    if (ok != true) return;

    // --- CHANGED: Write to Firestore using a WriteBatch ---
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Keep the existing logic for the 'unavailabilities' collection
    final datesTs = _pendingHolidays.map((d) => Timestamp.fromDate(d)).toList();
    final unavailabilitiesRef = _svcRef.collection('unavailabilities').doc(); // Create a new doc ref
    batch.set(unavailabilitiesRef, {
      'dates': datesTs,
      'reason': reasonCtrl.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. NEW: Update the 'daily_summary' collection for each holiday
    for (final holiday in _pendingHolidays) {
      final dateString = DateFormat('yyyy-MM-dd').format(holiday);
      final summaryRef = _svcRef.collection('daily_summary').doc(dateString);
      batch.set(
        summaryRef,
        {'isHoliday': true},
        SetOptions(merge: true), // This creates the document if it doesn't exist
      );
    }

    // 3. Commit all changes at once
    await batch.commit();
    // --- END OF CHANGES ---

    setState(() {
      _persistedHolidays.addAll(_pendingHolidays);
      _pendingHolidays.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unavailability saved.', style: GoogleFonts.poppins())),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child:
        Column(
          children: [
            // Calendar card
            Padding(
              padding: EdgeInsets.all(0),
              child: Card(
color: Colors.white,                shape: RoundedRectangleBorder(
                  side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Column(
                  children: [
                    // ✦ Styled header bar
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      child: Text(
                        'Declare Unavailable Dates',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),

                    // ✦ Calendar body with your existing handlers
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TableCalendar(
                        enabledDayPredicate: (day) => !day.isBefore(DateTime.now()),

                        firstDay: DateTime.now().subtract(Duration(days: 365)),
                        lastDay: DateTime.now().add(Duration(days: 365)),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (d) => _pendingHolidays.contains(_norm(d)),
                        // In your TableCalendar widget, replace the onDaySelected callback

                        onDaySelected: (sel, foc) async {
                          final norm = _norm(sel);

                          // 1️⃣ If it’s a persisted holiday (UA), prompt to unblock
                          if (_persistedHolidays.contains(norm)) {
                            final remove = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                title: Text('Remove Unavailability?', style: GoogleFonts.poppins()),
                                content: Text(
                                  'Do you want to make ${DateFormat.yMMMd().format(norm)} available again?',
                                  style: GoogleFonts.poppins(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('No', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Yes, Remove', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (remove == true) {
                              // --- CHANGED: Use a WriteBatch for atomic updates ---
                              final firestore = FirebaseFirestore.instance;
                              final batch = firestore.batch();
                              final col = _svcRef.collection('unavailabilities');

                              // 1. NEW: Add the daily_summary update to the batch
                              final dateString = DateFormat('yyyy-MM-dd').format(norm);
                              final summaryRef = _svcRef.collection('daily_summary').doc(dateString);
                              batch.set(
                                summaryRef,
                                {'isHoliday': false},
                                SetOptions(merge: true),
                              );

                              // 2. Keep existing logic but add operations to the batch
                              final snap = await col.where('dates', arrayContains: Timestamp.fromDate(norm)).get();
                              for (var doc in snap.docs) {
                                final oldDates = (doc['dates'] as List<dynamic>).cast<Timestamp>();
                                final newDates = oldDates.where((ts) {
                                  final d = ts.toDate();
                                  return !(d.year == norm.year && d.month == norm.month && d.day == norm.day);
                                }).toList();

                                if (newDates.isEmpty) {
                                  batch.delete(doc.reference);
                                } else {
                                  batch.update(doc.reference, {'dates': newDates});
                                }
                              }

                              // 3. Commit all changes
                              await batch.commit();
                              // --- END OF CHANGES ---

                              setState(() {
                                _persistedHolidays.remove(norm);
                                _pendingHolidays.remove(norm);
                                _focusedDay = foc;
                              });
                            }
                            return;
                          }

                          // 2️⃣ Otherwise, handle pending selection (This part remains unchanged)
                          if (_isOrderDay(sel) || _isNextDay(sel)) return;
                          final monthUsed = [
                            ..._persistedHolidays,
                            ..._pendingHolidays
                          ].where((d) => d.year == norm.year && d.month == norm.month).length;
                          setState(() => _focusedDay = foc);

                          if (_pendingHolidays.remove(norm)) {
                            // un-select pending
                          } else if (monthUsed >= _monthlyAllowance) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                                ),
                                title: Text(
                                  'Monthly Allowance Reached',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                content: Text(
                                  "You have reached your monthly limit of $_monthlyAllowance unavailable days for ${DateFormat.yMMMM().format(norm)}. For further assistance, please visit the Support tab and select General Queries.",
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),

                                actions: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor, // Consistent primary color
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'OK',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            _pendingHolidays.add(norm);
                          }

                          setState(() {});
                        },

                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (ctx, day, foc) {
                            final norm = _norm(day);
                            if (_isOrderDay(day))   return _buildMarker(day, primaryColor, 'OD');
                            if (_isNextDay(day))    return _buildMarker(day, primaryColor.withOpacity(0.5), 'ND');
                            if (_persistedHolidays.contains(norm)) return _buildMarker(day, Colors.redAccent, 'UA');
                            return null;
                          },
                          todayBuilder: (ctx, day, foc) {
                            final norm = _norm(day);
                            if (_isOrderDay(day))   return _buildMarker(day, primaryColor, 'OD');
                            if (_isNextDay(day))    return _buildMarker(day, primaryColor.withOpacity(0.5), 'ND');
                            if (_persistedHolidays.contains(norm)) return _buildMarker(day, Colors.redAccent, 'UA');
                            return Container(
                              margin: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                border: Border.all(color: primaryColor, width: 2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text('${day.day}', style: GoogleFonts.poppins())),
                            );
                          },
                          selectedBuilder: (ctx, day, foc) {
                            return Container(
                              margin: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text('${day.day}', style: GoogleFonts.poppins(color: Colors.white))),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),


            // Legend
            // Legend + Help section
            // Legend + Explanations
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Legend
                  Row(
                    children: [
                      _legendItem('OD', primaryColor, ''),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'OD – Order Day\n',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'You already have one or more pets booked in on this day, so you can’t mark it as unavailable.',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendItem('ND', primaryColor.withOpacity(0.5), ''),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'ND – Next Day\n',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'This is the morning after a stay ends and is reserved for pet pick‑ups—also cannot be blocked as a holiday.',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendItem('UA', Colors.redAccent, ''),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'UA – Unavailable\n',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'Days you’ve blocked off yourself (vacation, maintenance, etc.); these dates won’t accept any new bookings until you unblock them.',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),


                  // Tips
                  const SizedBox(height: 16),
                  Text(
                    'Tips:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Updated guidance tips using “activities”:
                  Text(
                    '• To view the activities for any date, go to the Calendar section.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• To add an offline booking, go to the Calendar section and tap the date.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Tap on any blocked date (UA) to make it available again.',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• You can block up to $_monthlyAllowance dates per month. '
                        '(Contact admin to increase this limit.)',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onDone,
        backgroundColor: primaryColor,
        label: Text(
          'Save Unavailable Days',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }



  Widget _buildMarker(DateTime day, Color color, String label) => Container(
    margin: EdgeInsets.all(6),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Center(
      child: Text(label,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    ),
  );

  Widget _legendItem(String label, Color color, String desc) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(width: 6),
        Text(desc, style: GoogleFonts.poppins(fontSize: 14)),
      ],
    );
  }
}
