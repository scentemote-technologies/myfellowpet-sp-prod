import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../app_colors.dart';
import '../Boarding/OpenCloseBetween.dart';
import '../Boarding/boarding_confirmation_page.dart';



// BEFORE: Future<void> requestRefund(...)
Future<Map<String, dynamic>> requestRefund({
  required String paymentId,
  required int amountInPaise,
}) async {
  final uri = Uri.parse(
    'https://us-central1-petproject-test-g.cloudfunctions.net/initiateTestRazorpayRefund',
  );
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'payment_id': paymentId,
      'amount': amountInPaise,
    }),
  );
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  if (resp.statusCode != 200) {
    throw Exception('Refund failed: ${body['error'] ?? resp.body}');
  }
  return body;
}

/// Calculate refund % based on time-to-start vs policy brackets
int calculateRefundPercent({
  required double timeToStartInHours,
  required List<Map<String, dynamic>> brackets,
  required Map<String, int> providerPolicy,
}) {
  brackets.sort((a, b) =>
      (b['min_hours'] as num).compareTo(a['min_hours'] as num));
  for (final bracket in brackets) {
    final min = (bracket['min_hours'] as num).toDouble();
    final max = bracket['max_hours'] != null
        ? (bracket['max_hours'] as num).toDouble()
        : double.infinity;
    final label = bracket['label'] as String;
    if (timeToStartInHours >= min && timeToStartInHours < max) {
      return providerPolicy[label] ?? 0;
    }
  }
  return 0;
}

/// Sum refund across days
double calculateTotalRefund({
  required DateTime now,
  required List<DateTime> bookedDays,
  required double dailyTotalCost,
  required List<Map<String, dynamic>> brackets,
  required Map<String, int> providerPolicy,
}) {
  var total = 0.0;
  for (final day in bookedDays) {
    if (!now.isBefore(day)) continue;
    final hoursUntil = day.difference(now).inHours.toDouble();
    final pct = calculateRefundPercent(
      timeToStartInHours: hoursUntil,
      brackets: brackets,
      providerPolicy: providerPolicy,
    );
    total += dailyTotalCost * (pct / 100);
  }
  return total;
}

/// Selection per date → pet IDs
class _CancelSelectionPerDate {
  final Map<DateTime, List<String>> cancellations;
  _CancelSelectionPerDate({required this.cancellations});
}

/// Main cancel handler
Future<void> handleCancel(
    DocumentSnapshot bookingDoc,
    BuildContext context,
    ) async {
  final data = bookingDoc.data() as Map<String, dynamic>;
  final now = DateTime.now();

  final petNames = (data['pet_name'] as List<dynamic>? ?? [])
      .map((e) => e.toString())
      .toList();
  final petIds = (data['pet_id'] as List<dynamic>? ?? [])
      .map((e) => e.toString())
      .toList();
  final Map<String, List<String>> overrides =
      (data['attendance_override'] as Map<String, dynamic>?)
          ?.map((k,v) => MapEntry(
        k,
        (v as List<dynamic>).cast<String>(),
      ))
          ?? {};
  // 1) Build list of open-points
  final rawDates = (data['selectedDates'] as List<dynamic>? ?? [])
      .map<DateTime?>((d) => d is Timestamp ? d.toDate() : d as DateTime?)
      .whereType<DateTime>()
      .toList()
    ..sort();
  final openTimeStr = data['openTime'] as String? ?? '12:00 AM';
  final parsedOpen = DateFormat('h:mm a').parse(openTimeStr);
  final openPoints = rawDates
  // 1) skip any date where ALL pets already cancelled
      .where((d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    final cancelled = overrides[key] ?? <String>[];
    return !petIds.every((id) => cancelled.contains(id));
  })
  // 2) then map to your open-time DateTimes
      .map((d) => DateTime(
    d.year, d.month, d.day,
    parsedOpen.hour, parsedOpen.minute,
  ))
  // 3) keep only today/future
      .where((dt) {
    final today = DateTime(now.year, now.month, now.day);
    return dt.isAtSameMomentAs(today) || dt.isAfter(now);
  })
      .toSet()
      .toList()
    ..sort();


  // 2) Extract pet lists


  // 3) Show per-date pet-selection sheet
  final selection = await showModalBottomSheet<_CancelSelectionPerDate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      // map each date to its selected pet-indexes
      final selectedPerDate = <DateTime, Set<int>>{
        for (var d in openPoints) d: <int>{}
      };
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black45,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              maxChildSize: 0.85,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              builder: (ctx, ctrl) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ListView(
                  controller: ctrl,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Title
                    Text(
                      'Cancel Booking',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 24),
                    // For each date: show header + pet chips
                    for (final date in openPoints) ...[
                      Text(
                        DateFormat('MMM dd, yyyy').format(date),
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: List.generate(petNames.length, (i) {
                          final name = petNames[i];
                          final isSel = selectedPerDate[date]!.contains(i);
                          final key = DateFormat('yyyy-MM-dd').format(date);
                          final cancelledOnDate = overrides[key] ?? <String>[];
                          final dateKey = DateFormat('yyyy-MM-dd').format(date);

                          // inside your List.generate …
                          return Tooltip(
                            message: 'This pet has already been cancelled for this date.',
                            triggerMode: TooltipTriggerMode.tap,
                            child: FilterChip(
                              label: Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                  color: cancelledOnDate.contains(petIds[i])
                                      ? Colors.grey                       // grey text if disabled
                                      : isSel
                                      ? Colors.white                 // white text when selected
                                      : Colors.black87,              // normal text when unselected
                                ),
                              ),
                              selected: isSel,
                              onSelected: cancelledOnDate.contains(petIds[i])
                                  ? null                               // disable taps
                                  : (on) {
                                if (on) selectedPerDate[date]!.add(i);
                                else selectedPerDate[date]!.remove(i);
                                (ctx as Element).markNeedsBuild();
                              },
                              backgroundColor: cancelledOnDate.contains(petIds[i])
                                  ? Colors.grey.shade300               // grey bg when disabled
                                  : AppColors.secondary.withOpacity(0.1), // your normal bg
                              selectedColor: cancelledOnDate.contains(petIds[i])
                                  ? null                               // no special color for disabled
                                  : const Color(0xFF2CB4B6),           // primary color when selected
                              disabledColor: Colors.grey.shade300,    // fallback disabled color
                              checkmarkColor: cancelledOnDate.contains(petIds[i])
                                  ? Colors.grey                       // grey checkmark if somehow selected
                                  : Colors.white,                     // white checkmark normally
                            ),
                          );

                        }),
                      ),
                      SizedBox(height: 24),
                    ],
                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          final cancellations = <DateTime, List<String>>{};
                          selectedPerDate.forEach((date, idxs) {
                            if (idxs.isNotEmpty) {
                              cancellations[date] =
                                  idxs.map((i) => petIds[i]).toList();
                            }
                          });
                          if (cancellations.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Select at least one pet on any date',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          Navigator.of(ctx).pop(
                            _CancelSelectionPerDate(cancellations: cancellations),
                          );
                        },
                        child: Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  if (selection == null) return;

  // 4) Pull cost data
  final petSizes = (data['pet_sizes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final cb = data['cost_breakdown'] as Map<String, dynamic>? ?? {};
  final walkCostPerDay =
      double.tryParse(cb['daily_walking_per_day']?.toString() ?? '') ?? 0.0;
  final mealCostPerDay =
      double.tryParse(cb['meal_per_day']?.toString() ?? '') ?? 0.0;

  // 5) Compute daily per-pet cost
  final rawIds = (data['pet_id'] as List<dynamic>).cast<String>();
  final settingsDoc = await FirebaseFirestore.instance
      .collection('settings')
      .doc('cancellation_time_brackets')
      .get();
  final brackets = (settingsDoc.data()?['brackets'] as List<dynamic>?)
      ?.cast<Map<String, dynamic>>() ??
      [];
  final adminPct = int.tryParse(
      settingsDoc.data()?['admin_cancel_fee_percentage']?.toString() ?? '0') ??
      0;
  final providerPolicyMap = (data['refund_policy'] as Map<dynamic, dynamic>? ??
      {})
      .map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
  final Map<String,double> boardingPriceByPet = {
    for (var i=0; i<petIds.length; i++)
      petIds[i] : (petSizes[i]['price'] as num).toDouble(),
  };

  // 6) For each date & its selected pets, compute refunds and update
  double grossTotal = 0.0;
  final attendanceUpdates = <String, List<String>>{};
  for (final entry in selection.cancellations.entries) {
    final date = entry.key;
    final petsOnThatDate = entry.value;

    // daily cost per booking = sum of boarding + walk + meal per pet
    final perPetDaily = petSizes
        .map((ps) => (ps['price'] as num).toDouble())
        .fold<double>(walkCostPerDay + mealCostPerDay,
            (sum, price) => sum + price);

    final dailyRefund = calculateTotalRefund(
      now: now,
      bookedDays: [date],
      dailyTotalCost: perPetDaily,
      brackets: brackets,
      providerPolicy: providerPolicyMap,
    ) *
        petsOnThatDate.length;

    grossTotal += dailyRefund;
    attendanceUpdates[DateFormat('yyyy-MM-dd').format(date)] =
        petsOnThatDate;
  }


  // 7) Build petNamesMap for invoice dialog
  final petNamesMap = Map<String, String>.fromIterables(petIds, petNames);
  showCancellationInvoiceDialog(
    context: context,
    cancellations: selection.cancellations,
    petNamesMap: petNamesMap,
    petSizes: petSizes,
    boardingPriceByPet: boardingPriceByPet,
    walkCostPerDay: walkCostPerDay,
    mealCostPerDay: mealCostPerDay,
    adminPct: adminPct,
    providerPolicyMap: providerPolicyMap,
    brackets: brackets,
    requestRefund: requestRefund,
    bookingDoc: bookingDoc,
  );
}

void showCancellationInvoiceDialog({
  required BuildContext context,
  required Map<DateTime,List<String>> cancellations,
  required Map<String, String> petNamesMap,
  required List<Map<String, dynamic>> petSizes,
  required double walkCostPerDay,
  required Map<String, double> boardingPriceByPet,
  required double mealCostPerDay,
  required int adminPct,
  required Map<String, int> providerPolicyMap,       // <-- int values
  required List<Map<String, dynamic>> brackets,
  required Future<Map<String, dynamic>> Function({
  required String paymentId,
  required int amountInPaise,
  }) requestRefund,
  required DocumentSnapshot bookingDoc,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final now = DateTime.now();
      final dates = cancellations.keys.toList()..sort();
      // ── Compute gross via your helper, not by hand ─────────────────
      // ── Build per-pet daily cost ─────────────────────────────
      final perPetDaily = petSizes
          .map((ps) => (ps['price'] as num).toDouble())
          .fold<double>(walkCostPerDay + mealCostPerDay, (sum, price) => sum + price);

// ── Compute a per-day total (all pets) ────────────────────
      // ── Compute a per-day total by summing each pet’s refund ───
      final Map<DateTime, double> dayTotals = {
        for (final day in dates)
          day: cancellations[day]!.fold<double>(0, (sum, petId) {
            // 1) boarding price for this pet
            final boarding = boardingPriceByPet[petId]!;

            // 2) full subtotal (boarding + walk + meal)
            final subtotal = boarding + walkCostPerDay + mealCostPerDay;

            // 3) find refund % for this date
            final hoursUntil = day.difference(now).inHours.toDouble();
            final pct = calculateRefundPercent(
              timeToStartInHours: hoursUntil,
              brackets: brackets,
              providerPolicy: providerPolicyMap,
            );

            // 4) that pet’s refund amount
            final petRefund = subtotal * (pct / 100);

            return sum + petRefund;
          }),
      };



// ── Compute gross (all days × all pets) ───────────────────
      final computedGross = dayTotals.values.fold(0.0, (sum, v) => sum + v);
      final adminFeeFinal =(computedGross*(adminPct/100));
      final netRefund = computedGross - adminFeeFinal;


      return SafeArea(
        child: Center(
          child: Material(
            color: Colors.white,
            elevation: 24,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title ───────────────────────────
                    Text(
                      'Cancellation Invoice',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showGeneralDialog(
                          context: ctx,
                          barrierDismissible: true,
                          barrierLabel: 'Dismiss',
                          pageBuilder: (ctx3, anim, secAnim) {
                            return Stack(
                              children: [
                                // Semi-transparent scrim to dismiss when tapping outside
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(ctx3).pop(),
                                    child: Container(color: Colors.black38),
                                  ),
                                ),

                                // Centered popup
                                Center(
                                  child: Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      width: MediaQuery.of(ctx3).size.width * 0.9,
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // ── Title ───────────────────────────
                                          Text(
                                            'Service Provider Refund Policy',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2CB4B6),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // ── Policy lines ────────────────────
                                          // 1) “greater than Xh” cases, skipping any 0-hour bracket
                                          for (final bracket in brackets.where((b) => (b['min_hours'] as num) > 0)) ...[
                                            Builder(builder: (_) {
                                              final minH = (bracket['min_hours'] as num).toInt();
                                              final pct  = providerPolicyMap[bracket['label']] ?? 0;
                                              return Text.rich(
                                                TextSpan(children: [
                                                  TextSpan(
                                                    text: 'If the time difference between now and the start of service is ',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                  TextSpan(
                                                    text: 'more than ${minH} hours',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ': ',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                  TextSpan(
                                                    text: '${pct}%',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' refund',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                ]),
                                              );
                                            }),
                                            const SizedBox(height: 8),
                                          ],

                                          // 2) “less than smallest non-zero bracket” case
                                          if (brackets.any((b) => (b['min_hours'] as num) > 0)) ...[
                                            Builder(builder: (_) {
                                              final nonZero = brackets.where((b) => (b['min_hours'] as num) > 0).toList();
                                              final cutoff  = (nonZero.last['min_hours'] as num).toInt();
                                              return Text.rich(
                                                TextSpan(children: [
                                                  TextSpan(
                                                    text: 'If the time difference between now and the start of service is ',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                  TextSpan(
                                                    text: 'less than ${cutoff} hours',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ': ',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                  TextSpan(
                                                    text: '0%',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' refund',
                                                    style: GoogleFonts.poppins(fontSize: 13),
                                                  ),
                                                ]),
                                              );
                                            }),
                                            const SizedBox(height: 8),
                                          ],

                                          // ── Footnote ────────────────────────
                                          const SizedBox(height: 4),
                                          Text(
                                            'Note: “start of service” refers to the provider’s operating hours on that day.',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // ── Close button ────────────────────
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () => Navigator.of(ctx3).pop(),
                                              child: Text(
                                                'Close',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFF2CB4B6),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),


                              ],
                            );
                          },
                          transitionBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        );
                      },
                      child: Text(
                        '(Service Provider Refund Policy)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          color: const Color(0xFF2CB4B6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Per-date breakdown ───────────────────────────
                    for (final day in dates) ...[
                      Text(
                        DateFormat('MMM dd, yyyy').format(day),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      for (final petId in cancellations[day]!) ...[
                        Builder(builder: (ctx2) {
                          final petName = petNamesMap[petId] ?? petId;
// look up the index of this petId in the original petIds list
                          final boarding = boardingPriceByPet[petId]!;
                          final subtotal =
                              boarding + walkCostPerDay + mealCostPerDay;
                          final hoursUntil =
                          day.difference(now).inHours.toDouble();
                          final pct = calculateRefundPercent(
                            timeToStartInHours: hoursUntil,
                            brackets: brackets,
                            providerPolicy: providerPolicyMap,
                          );
                          final refundAmt = subtotal * pct / 100;

                          return Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• $petName: ₹${subtotal.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 1) the percent line
                                    Text(
                                      '× $pct% refund',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '= ₹${refundAmt.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Date total
                      Builder(builder: (ctx2) {
                        final dayTotal = cancellations[day]!.fold<double>(0, (sum, petId) {
                          // directly pull boarding price from your map
                          final boarding = boardingPriceByPet[petId]!;
                          final subtotal = boarding + walkCostPerDay + mealCostPerDay;
                          final hoursUntil = day.difference(now).inHours.toDouble();
                          final pct = calculateRefundPercent(
                            timeToStartInHours: hoursUntil,
                            brackets: brackets,
                            providerPolicy: providerPolicyMap,
                          );
                          return sum + (subtotal * pct / 100);
                        });


                        return Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total refund for this date: ₹${dayTotal.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(),
                    ],

                    // ── Summary ─────────────────────────────
                    const SizedBox(height: 8),

                    Text(
                      'Gross refund: ₹${computedGross.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total before admin fee',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin fee ($adminPct%): –₹${adminFeeFinal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Deducted by provider',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Net you’ll receive: ₹${(computedGross-adminFeeFinal).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Amount credited to your account',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Actions ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,                             // fill black
                            side: BorderSide(color: AppColors.primary, width: 1.5),         // white outline
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'No',
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,                                   // black text
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,                             // fill black
                            side: BorderSide(color: AppColors.primary, width: 1.5),         // white outline
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          // Inside showCancellationInvoiceDialog, find the "Yes, Cancel" TextButton
// and replace its onPressed callback with this entire block.

                          onPressed: () async {
                            // --- Start of Cancellation Logic ---
                            final raw = bookingDoc.data()! as Map<String, dynamic>;
                            final nowTs = DateTime.now();
                            final firestore = FirebaseFirestore.instance;
                            final ref = bookingDoc.reference;

                            // 1️⃣ Create a WriteBatch to handle all DB changes atomically.
                            final batch = firestore.batch();

                            // 2️⃣ NEW: Loop through the cancellations to decrement daily_summary counts.
                            cancellations.forEach((date, petsToCancel) {
                              final dateString = DateFormat('yyyy-MM-dd').format(date);
                              final summaryRef = firestore
                                  .collection('users-sp-boarding')
                                  .doc(raw['service_id'] as String)
                                  .collection('daily_summary')
                                  .doc(dateString);

                              // Decrement by the number of pets cancelled on this specific day.
                              batch.update(summaryRef, {
                                'bookedPets': FieldValue.increment(-petsToCancel.length)
                              });
                            });

                            // 3️⃣ Compute adjusted total for the booking document.
                            final cb = raw['cost_breakdown'] as Map<String, dynamic>? ?? {};
                            final originalTotal = double.tryParse(cb['total_amount']?.toString() ?? '0') ?? 0.0;
                            final adjustedTotal = originalTotal - computedGross;

                            // 4️⃣ Build the update map for the main booking document.
                            final updates = <String, dynamic>{
                              'refund_amount': netRefund,
                              'cancellation_requested_at': nowTs,
                              'cost_breakdown.total_amount': adjustedTotal,
                            };
                            for (final d in dates) {
                              final key = DateFormat('yyyy-MM-dd').format(d);
                              updates['attendance_override.$key'] =
                                  FieldValue.arrayUnion(cancellations[d]!);
                            }

                            // Add this update to the batch.
                            batch.update(ref, updates);

                            // 5️⃣ Handle Razorpay refund if enabled.
                            final payDoc = await firestore.collection('company_documents').doc('payment').get();
                            final bool refundEnabled = (payDoc.data()?['checkoutEnabled'] as bool?) ?? false;
                            String? refundId;

                            if (refundEnabled) {
                              final String? paymentId = raw['payment_id'] as String?;
                              if (paymentId == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Refund failed: no payment ID found')),
                                );
                                return;
                              }
                              try {
                                final amountInPaise = (netRefund * 100).toInt();
                                final resp = await requestRefund(
                                  paymentId: paymentId,
                                  amountInPaise: amountInPaise,
                                );
                                refundId = resp['id'] as String?; // Adjusted based on your cloud function response
                              } catch (e) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Refund API failed: $e')),
                                );
                                return;
                              }
                            }

                            // 6️⃣ Add the cancellation history entry to the batch.
                            final historyEntry = {
                              'refund_requested_at': nowTs,
                              'cancellation_details': {
                                for (final date in cancellations.keys)
                                  DateFormat('yyyy-MM-dd').format(date): cancellations[date]!
                                      .map((petId) => {'id': petId, 'name': petNamesMap[petId] ?? 'Unknown'})
                                      .toList(),
                              },
                              'computed_gross': computedGross,
                              'admin_fee': adminFeeFinal,
                              'admin_fee_pct': adminPct,
                              'adjusted_total': adjustedTotal,
                              'net_refund': netRefund,
                              'payment_id': raw['payment_id'] as String?,
                              'refund_id': refundId,
                              'created_at': nowTs,
                            };

                            // Use .doc() to create a new entry with an auto-ID.
                            final historyRef = ref.collection('user_cancellation_history').doc();
                            batch.set(historyRef, historyEntry);

                            // 7️⃣ Commit all batched writes to Firestore.
                            await batch.commit();

                            // Show success message.
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  refundId != null
                                      ? 'Refund of ₹${netRefund.toStringAsFixed(2)} initiated (ID: $refundId)'
                                      : 'Booking successfully updated.',
                                ),
                              ),
                            );

                            // 8️⃣ Determine if the booking is fully cancelled and move the document if necessary.
                            // This logic runs AFTER the main updates are committed.
                            final updatedDoc = await ref.get(); // Re-fetch the doc to get the latest override data
                            final latestData = updatedDoc.data() as Map<String, dynamic>;
                            final fullDates = (latestData['selectedDates'] as List<dynamic>)
                                .map((d) => (d as Timestamp).toDate())
                                .toList();
                            final fullPets = (latestData['pet_id'] as List<dynamic>).cast<String>();
                            final effectiveOverrides = (latestData['attendance_override'] as Map<String, dynamic>?)
                                ?.map((k, v) => MapEntry(k, (v as List).cast<String>())) ?? {};

                            final isFullCancel = fullDates.every((d) {
                              final key = DateFormat('yyyy-MM-dd').format(d);
                              return fullPets.every((petId) => effectiveOverrides[key]?.contains(petId) ?? false);
                            });

                            if (isFullCancel) {
                              // This logic to move the document can remain as you have it.
                              // It will now run on the fully updated document.
                              final serviceId = raw['service_id'] as String? ?? bookingDoc.id;
                              final destRef = firestore
                                  .collection('users-sp-boarding')
                                  .doc(serviceId)
                                  .collection('cancellations')
                                  .doc(bookingDoc.id);
                              final moveBatch = firestore.batch();

                              moveBatch.set(destRef, latestData);
                              // You would also move subcollections here if needed, then delete the original.
                              moveBatch.delete(ref);

                              await moveBatch.commit();
                              print('Booking fully cancelled and moved to cancellations collection.');
                            }

                            // 9️⃣ Close the dialog.
                            Navigator.of(ctx).pop();
                          },

                          child: Text(
                            'Yes, Cancel',
                            style: GoogleFonts.poppins(
                              color: AppColors.primary,                                   // black text
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),                        ),


                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secAnim, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 200),
  );
}

/// Helper to return the user’s choices.
/// Helper to return the user’s choices.
class _CancelSelection {
  final List<DateTime> dates;
  final List<String> petIds;
  final int   numPets;
  _CancelSelection({
    required this.dates,
    required this.petIds,
    required this.numPets,
  });
}



class BoardingOrders extends StatelessWidget {
  final String userId;
  const BoardingOrders({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFffffff),
        title: Text(
          'My Bookings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        // The `bottom` property is removed completely.
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade100,
              Colors.white,
            ],
          ),
        ),
        // The body now directly holds `ConfirmedBookingsNav`
        child: ConfirmedBookingsNav(userId: userId),
      ),
    );
  }
}


class ConfirmedBookingsNav extends StatefulWidget {
  final String userId;
  const ConfirmedBookingsNav({Key? key, required this.userId}) : super(key: key);

  @override
  _ConfirmedBookingsNavState createState() => _ConfirmedBookingsNavState();
}

class _ConfirmedBookingsNavState extends State<ConfirmedBookingsNav> {
  int _selectedIndex = 0; // 0 = Ongoing, 1 = Upcoming
  String _searchTerm = '';

  // Place this inside the _ConfirmedBookingsNavState class

  void _showCannotCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Cancellation Not Allowed", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Bookings can only be cancelled up to 24 hours before the service start time.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  dynamic openTime;
  dynamic closeTime;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1) Search bar at top, full width:
        _buildSearchBar(),

        // 2) Main content below:
        Expanded(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white, // Match the card background
                selectedLabelTextStyle: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                ),
                selectedIconTheme: IconThemeData(
                  color: AppColors.primary,
                  size: 24,
                ),
                unselectedIconTheme: IconThemeData(
                  color: Colors.black54,
                  size: 24,
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.play_arrow_outlined),
                    selectedIcon: Icon(Icons.play_arrow),
                    label: Text('Ongoing'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.schedule_outlined),
                    selectedIcon: Icon(Icons.schedule),
                    label: Text('Upcoming'),
                  ),
                ],
              ),

              // ---- content area ----
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('service_request_boarding')
                      .where('user_id', isEqualTo: widget.userId)
                      .where('order_status', isEqualTo: 'confirmed')
                      .snapshots(),
                  // In _ConfirmedBookingsNavState -> build() method -> StreamBuilder
                  builder: (_, snap) {
                    // 1. Check if the stream is still loading data
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    // 2. ADD THIS: Check if the stream produced an error
                    if (snap.hasError) {
                      return Center(child: Text('Something went wrong. Please try again.'));
                    }

                    // 3. ADD THIS: Check if the stream is empty or has no data
                    // This is the check that prevents the crash.
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return Center(child: Text('No confirmed bookings found.'));
                    }

                    // --- Only now is it safe to access the data ---
                    final orders = snap.data!.docs.map((d) => OrderSummary(d)).toList();
                    final today = DateTime.now();
                    final todayStart = DateTime(today.year, today.month, today.day);

                    // The rest of your existing logic is correct...
                    final ongoing = orders.where((o) => o.dates.any((d) => _isSameDay(d, today))).toList();
                    final upcoming = orders.where((o) => o.dates.every((d) => d.isAfter(todayStart))).toList();

                    var listToShow = _selectedIndex == 0 ? ongoing : upcoming;

                    if (_searchTerm.isNotEmpty) {
                      final term = _searchTerm.toLowerCase();
                      listToShow = listToShow.where((o) {
                        return o.shopName.toLowerCase().contains(term)
                            || o.doc.id.toLowerCase().contains(term);
                      }).toList();
                    }

                    if (listToShow.isEmpty) {
                      return Center(child: Text('No bookings match your search.'));
                    }

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: listToShow.length,
                      itemBuilder: (_, i) => _buildOrderCard(listToShow[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Search by shop name or order ID',
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchTerm = '';
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade600, width: 1.5),
          ),
        ),
        onChanged: (val) {
          setState(() => _searchTerm = val.trim());
        },
      ),
    );
  }

  // REPLACE your entire _buildOrderCard method with this one

  Widget _buildOrderCard(OrderSummary order) {
    // --- MODIFICATION START ---
    // 1. Find the earliest date that is today or in the future
    final now = DateTime.now();
    final upcomingDates = order.dates.where((d) => !d.isBefore(now.subtract(const Duration(days: 1)))).toList();
    upcomingDates.sort();

    bool canCancel = false;
    if (upcomingDates.isNotEmpty) {
      final earliestUpcomingDate = upcomingDates.first;
      // 2. Calculate the cancellation deadline (24 hours before the earliest upcoming date)
      final deadline = earliestUpcomingDate.subtract(const Duration(hours: 24));
      // 3. Check if the current time is before the deadline
      canCancel = now.isBefore(deadline);
    }
    // --- MODIFICATION END ---

    // Extract raw data
    final data = order.doc.data() as Map<String, dynamic>;
    final rawList = data['selectedDates'] as List<dynamic>? ?? [];

    // convert each entry (Timestamp or ISO‐string) into a DateTime
    final selectedDates = rawList
        .map<DateTime>((e) {
      if (e is Timestamp) return e.toDate();
      if (e is String) return DateTime.parse(e);
      throw StateError('Unknown date type: $e');
    })
    // (optional) strip off any time component so you only have YYYY‑MM‑DD
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toList();
    final dates = order.dates;
    final sortedDates = List<DateTime>.from(dates)..sort();
    final openTime = data['openTime'] as String? ?? '12:00 AM';
    final closeTime = data['closeTime'] as String? ?? '11:59 PM';
    final petNamesList = order.petNames;

    final startedAtTs = (data['startedAt'] as Timestamp?)?.toDate();
    final startedAtStr = startedAtTs != null
        ? DateFormat('dd-MM-yyyy hh:mm a').format(startedAtTs)
        : 'Not started';

    final furthestDate = selectedDates.isNotEmpty
        ? selectedDates.reduce((a, b) => b.isAfter(a) ? b : a)
        : null;
    final completesOnStr = furthestDate != null
        ? DateFormat('dd-MM-yyyy').format(furthestDate)
        : '–––';

    final petImages = (data['pet_images'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ??
        <String>[];
    final totalCost = double.tryParse(
      (data['cost_breakdown'] as Map<String, dynamic>?)?['total_amount']
          ?.toString() ??
          '0',
    ) ?? 0.0;
    final serviceId = data['service_id'] as String? ?? order.doc.id;

    return Padding(
      padding: const EdgeInsets.all(0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // ----------------- START OF CHANGES -----------------
        onTap: () async {
          final bookingDoc = order.doc;

          // 1. Fetch data directly from the booking document
          final data = bookingDoc.data() as Map<String, dynamic>;
          final costBreakdown = data['cost_breakdown'] as Map<String, dynamic>? ?? {};
          final foodCost = double.tryParse(costBreakdown['meals_cost'] ?? '0') ?? 0.0;
          final walkingCost = double.tryParse(costBreakdown['daily_walking_cost'] ?? '0') ?? 0.0;
          final transportCost = double.tryParse(costBreakdown['transport_cost'] ?? '0') ?? 0.0;

          final petIds = List<String>.from(data['pet_id'] ?? []);
          final rates = Map<String, int>.from(data['rates'] ?? {});
          final mealRates = Map<String, int>.from(data['mealRates'] ?? {});
          final walkingRates = Map<String, int>.from(data['walkingRates'] ?? {});
          final fullAddress = data['fullAddress'] ?? 'Address not found';
          final spLocation = data['sp_location'] as GeoPoint? ?? const GeoPoint(0, 0);

          // 2. Fetch perDayServices from the subcollection
          final Map<String, Map<String, dynamic>> perDayServices = {};
          final petServicesSnapshot = await bookingDoc.reference.collection('pet_services').get();

          for (var petDoc in petServicesSnapshot.docs) {
            perDayServices[petDoc.id] = petDoc.data();
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConfirmationPage(
                // --- Passing all the newly fetched data ---
                perDayServices: perDayServices,
                petIds: petIds,
                foodCost: foodCost,
                walkingCost: walkingCost,
                transportCost: transportCost,
                rates: rates,
                mealRates: mealRates,
                walkingRates: walkingRates,
                fullAddress: fullAddress,
                sp_location: spLocation,

                // --- Previously existing parameters ---
                buildOpenHoursWidget:
                buildOpenHoursWidget(openTime, closeTime, dates),
                shopName: order.shopName,
                shopImage: order.shopImage,
                selectedDates: dates,
                totalCost: totalCost,
                petNames: petNamesList,
                openTime: openTime,
                closeTime: closeTime,
                bookingId: order.doc.id,
                sortedDates: sortedDates,
                petImages: petImages,
                serviceId: serviceId,
                fromSummary: false,
              ),
            ),
          );
        },
        // ------------------ END OF CHANGES ------------------
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF2CB4B6), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header with Image ──────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Order details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.poppins(fontSize: 13),
                              children: [
                                TextSpan(
                                  text: 'Name - ',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: order.shopName,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.poppins(fontSize: 11),
                              children: [
                                TextSpan(
                                  text: 'Order ID - ',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: order.doc.id,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        order.shopImage,
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.store, size: 50, color: Colors.grey),
                      ),
                    ),
                  ],
                ),

                // ── Booking & Amount ───────────────────────
                const SizedBox(height: 8),
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 11),
                    children: [
                      TextSpan(
                        text: 'Booked on - ',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: order.timestampStr,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 11),
                    children: [
                      TextSpan(
                        text: 'Amount - ',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: "₹ ${order.Amount}",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Date → Pets lines ───────────────────────
                for (final d in order.dates) ...[
                  Builder(builder: (_) {
                    final key = DateFormat('yyyy-MM-dd').format(d);
                    final cancelled = order.attendanceOverride[key] ?? <String>[];
                    final attendingPets = <String>[];
                    for (int i = 0; i < order.petIds.length; i++) {
                      if (!cancelled.contains(order.petIds[i])) {
                        attendingPets.add(order.petNames[i]);
                      }
                    }
                    if (attendingPets.isEmpty) return const SizedBox.shrink();

                    final isToday = DateTime(d.year, d.month, d.day) ==
                        DateTime.now().toLocal().copyWith(
                          hour: 0,
                          minute: 0,
                          second: 0,
                        );
                    final dateBg = isToday
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.grey.shade200;

                    return Padding(
                      padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      child: Row(
                        children: [
                          // Date bubble
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: dateBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              DateFormat('dd MMM').format(d),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            " - ",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pet names
                          Expanded(
                            child: Text(
                              attendingPets.join(', '),
                              style: GoogleFonts.poppins(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                _infoRow('Started At', startedAtStr),
                _infoRow('Completes On', completesOnStr),

                // --- MODIFICATION START ---
                // ── CANCEL Button ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 1) Cancel button
                    ElevatedButton(
                      onPressed: () {
                        if (canCancel) {
                          handleCancel(order.doc, context);
                        } else {
                          _showCannotCancelDialog(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: canCancel ? Colors.red : Colors.grey, width: 1.5),
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
                          color: canCancel ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                    // --- MODIFICATION END ---

                    const SizedBox(width: 8),

                    // 2) Cancellation History button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CancellationHistoryPage(
                              bookingDoc: order.doc,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.primary, width: 1.5),
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
                          color: AppColors.primary,
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
}

class SubBooking {
  final QueryDocumentSnapshot doc;
  final DateTime date;
  SubBooking({required this.doc, required this.date});
}

class OrderSummary {
  final QueryDocumentSnapshot doc;
  final String shopName;
  final String Amount;
  final String shopImage;
  final List<DateTime> dates;
  final List<String> petIds;
  final List<String> petNames;
  final Map<String, List<String>> attendanceOverride;
  final String timestampStr; // 👈 your new field

  OrderSummary(this.doc)
      : shopName = (doc.data() as Map<String, dynamic>)['shopName'] as String? ?? 'Unknown Shop',
        shopImage = (doc.data() as Map<String, dynamic>)['shop_image'] as String? ?? 'Unknown Shop',
        Amount       = (() {
          final data = doc.data() as Map<String, dynamic>;
          final cost = data['cost_breakdown'] as Map<String, dynamic>?;
          final rawAmt = cost?['total_amount'];
          if (rawAmt is num) {
            // Format to two decimals (or use intl for currency formatting)
            return rawAmt.toDouble().toStringAsFixed(2);
          }
          return rawAmt;
        })(),

        timestampStr = (() {
          final ts = (doc.data() as Map<String, dynamic>)['timestamp'];
          if (ts is Timestamp) {
            final dt = ts.toDate();
            final date = DateFormat('dd MMM yyyy').format(dt);
            final time = DateFormat('h:mm a').format(dt); // 12-hour format with AM/PM
            return '$date ($time)';
          }
          return 'No Timestamp';
        })(),

        dates = _extractDates(doc),

        petIds = ((doc.data() as Map<String, dynamic>)['pet_id'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? <String>[],

        petNames = ((doc.data() as Map<String, dynamic>)['pet_name'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? <String>[],

        attendanceOverride = (() {
          final raw = (doc.data() as Map<String, dynamic>)['attendance_override'];
          if (raw is Map<String, dynamic>) {
            return raw.map((key, val) {
              final list = (val as List<dynamic>).map((e) => e.toString()).toList();
              return MapEntry(key, list);
            });
          }
          return <String, List<String>>{};
        })();
}

List<DateTime> _extractDates(QueryDocumentSnapshot doc) {
  final raw = (doc.data() as Map<String, dynamic>)['selectedDates'] as List<dynamic>? ?? [];
  return raw
      .map((d) {
    if (d is Timestamp) return d.toDate();
    if (d is DateTime) return d;
    return null;
  })
      .whereType<DateTime>()
      .map((dt) => DateTime(dt.year, dt.month, dt.day))
      .toList()
    ..sort();
}


class CancellationHistoryPage extends StatelessWidget {
  final DocumentSnapshot bookingDoc;

  const CancellationHistoryPage({Key? key, required this.bookingDoc}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serviceId = bookingDoc['service_id'] as String;
    final bookingId = bookingDoc.id;
    final basePath = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('service_request_boarding')
        .doc(bookingId);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('Cancellation History', style: GoogleFonts.poppins()),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
              tabs: [
                Tab(
                  child: Text(
                    'User History',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
                Tab(
                  child: Text(
                    'Provider History',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHistoryStream(basePath.collection('user_cancellation_history')),
            _buildHistoryStream(basePath.collection('sp_cancellation_history')),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryStream(CollectionReference col) {
    return StreamBuilder<QuerySnapshot>(
      stream: col.orderBy('created_at', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('No history entries.', style: GoogleFonts.poppins()));
        }
        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final when = (data['refund_requested_at'] as Timestamp).toDate();
            final details = data['cancellation_details'] as Map<String, dynamic>;

            return Card(
              color: Colors.white,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.primary),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    //_infoRow('Gross Refund', data['computed_gross']),
                  //  _infoRow('Admin Fee (${data['admin_fee_pct']}%)', data['admin_fee']),

                    // …then your loop:
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✨ Nice title
                        Text(
                          'Cancelled Pets by Date',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 5),
                    for (final entry in details.entries) ...[
                      Text(
                        DateFormat('dd MMM yyyy').format(DateTime.parse(entry.key)),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Wrap(
                        spacing: 3,
                        children: (entry.value as List<dynamic>).map<Widget>((pet) {
                          return Chip(
                            label: Text(
                              pet['name'],
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            backgroundColor: Colors.white,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: AppColors.primary,  // your border color
                                width: 1.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _infoRow('Net Refund', data['net_refund']),
                    _infoRow('Refund ID', data['refund_id'] ?? 'N/A'),
                    Text('Cancelled at ${DateFormat('dd MMM yyyy, h:mm a').format(when)}',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 5),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, dynamic value) {
    final display = (value is num) ? '₹${value.toStringAsFixed(2)}' : value.toString();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: display),
          ],
        ),
      ),
    );
  }
}
