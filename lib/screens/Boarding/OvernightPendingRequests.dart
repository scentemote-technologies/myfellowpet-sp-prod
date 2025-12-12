import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Colors/AppColor.dart';
import '../../Colors/AppColor.dart' as AppColor;
import '../../shared/highlight_mode.dart';
import 'boarding_requests.dart';
import 'chat_support/ChatScreen.dart';
import 'chat_support/chat_support.dart';


double _parseRate(Map<String, String> map, String size) {
  final raw = map[size];
  if (raw == null || raw.isEmpty) return 0.0;
  return double.tryParse(raw) ?? 0.0;
}


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
    total += dailyTotalCost ;
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
  print('🔔 handleCancel called for booking ${bookingDoc.id}');
  final data = bookingDoc.data() as Map<String, dynamic>;
  final now = DateTime.now();
  // rate maps

  // pet‐size list & lookup
  // pull in the two rate‐maps once
  final petSizes = (data['pet_sizes'] as List)
      .cast<Map<String, dynamic>>()
      .map((ps) {
    return {
      // copy over the fields you actually wrote into Firestore
      'id'      : ps['id']      as String,
      'size'    : (ps['size']    as String).toLowerCase(),
      'price'   : (ps['price']   as num).toDouble(),
      'walkFee' : (ps['walkFee'] as num).toDouble(),
      'mealFee' : (ps['mealFee'] as num).toDouble(),
    };
  }).toList();


  final petIds   = (data['pet_id'] as List).cast<String>();
  final petNames = (data['pet_name'] as List).cast<String>();

  // cancellation policy
  final settingsDoc       = await FirebaseFirestore.instance
      .collection('settings')
      .doc('cancellation_time_brackets')
      .get();
  final brackets          = (settingsDoc['brackets'] as List).cast<Map<String, dynamic>>();
  final providerPolicyMap = (data['refund_policy'] as Map).map((k,v)=> MapEntry(k.toString(), int.parse(v.toString())));

  // boarding prices by pet
  final boardingPriceByPet = <String,double>{
    for (var i = 0; i < petIds.length; i++)
      petIds[i] : (petSizes[i]['price'] as num).toDouble(),
  };


  double grossTotal = 0.0;
  final attendanceUpdates = <String, List<String>>{};




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
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      // map each date to its selected pet‐indexes
      final selectedPerDate = <DateTime, Set<int>>{
        for (var d in openPoints) d: <int>{},
      };
      return DraggableScrollableSheet(
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
                    color: primaryColor.withOpacity(0.4),
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
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 24),
              // Date sections
              for (final date in openPoints) ...[
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(petNames.length, (i) {
                    final name = petNames[i];
                    final isSel = selectedPerDate[date]!.contains(i);
                    final key = DateFormat('yyyy-MM-dd').format(date);
                    final cancelledOnDate = overrides[key] ?? <String>[];

                    return Tooltip(
                      message: cancelledOnDate.contains(petIds[i])
                          ? 'This pet has already been cancelled for this date.'
                          : '',
                      triggerMode: TooltipTriggerMode.tap,
                      child: FilterChip(
                        label: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                            color: cancelledOnDate.contains(petIds[i])
                                ? Colors.grey
                                : isSel
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        selected: isSel,
                        onSelected: cancelledOnDate.contains(petIds[i])
                            ? null
                            : (on) {
                          if (on) {
                            selectedPerDate[date]!.add(i);
                          } else {
                            selectedPerDate[date]!.remove(i);
                          }
                          (ctx as Element).markNeedsBuild();
                        },
                        backgroundColor: cancelledOnDate.contains(petIds[i])
                            ? Colors.grey.shade300
                            : Color(0xFFDAF6F7).withOpacity(0.1),
                        selectedColor: cancelledOnDate.contains(petIds[i])
                            ? null
                            : const Color(0xFF2CB4B6),
                        disabledColor: Colors.grey.shade300,
                        checkmarkColor: cancelledOnDate.contains(petIds[i])
                            ? Colors.grey
                            : Colors.white,
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
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    final cancellations = <DateTime, List<String>>{};
                    selectedPerDate.forEach((date, idxs) {
                      if (idxs.isNotEmpty) {
                        cancellations[date] = idxs.map((i) => petIds[i]).toList();
                      }
                    });
                    if (cancellations.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Select at least one pet on any date',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
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
      );
    },
  );


  if (selection == null) return;

  final cb = data['cost_breakdown'] as Map<String, dynamic>? ?? {};

  final adminPct = int.tryParse(
      settingsDoc.data()?['admin_cancel_fee_percentage']?.toString() ?? '0') ??
      0;

  for (final entry in selection.cancellations.entries) {
    final date          = entry.key;
    final petsOnThatDate = entry.value;    // e.g. ['pet1','pet3']

    // 1) boarding + walk + meal for one pet
// 1) boarding + walk + meal for one pet, summing across all pets
    final perPetDaily = petSizes.fold<double>(0.0, (sum, ps) {
      final boarding = (ps['price']   as num).toDouble();
      final walkFee  = (ps['walkFee'] as num).toDouble();
      final mealFee  = (ps['mealFee'] as num).toDouble();
      return sum + boarding + walkFee + mealFee;
    });

    // 2) refund for one pet on that date
    final singleDailyRefund = calculateTotalRefund(
      now: now,
      bookedDays: [date],
      dailyTotalCost: perPetDaily,
      brackets: brackets,
      providerPolicy: providerPolicyMap,
    );

    // 3) multiply by number of pets cancelled
    grossTotal += singleDailyRefund * petsOnThatDate.length;

    // 4) record override
    attendanceUpdates[
    DateFormat('yyyy-MM-dd').format(date)
    ] = petsOnThatDate;
  }



  // 7) Build petNamesMap for invoice dialog
  final petNamesMap = Map<String, String>.fromIterables(petIds, petNames);
  showCancellationInvoiceDialog(
    context: context,
    cancellations: selection.cancellations,
    petNamesMap: petNamesMap,
    petSizes: petSizes,
    boardingPriceByPet: boardingPriceByPet,
    adminPct: adminPct,
    providerPolicyMap: providerPolicyMap,
    brackets: brackets,
    requestRefund: requestRefund,
    bookingDoc: bookingDoc,
  );
}

Future<void> triggerAdminCancellationPayout({
  required String orderId,
  required double adminFee,
}) async {
  try {
    // fetch admin Razorpay fund account from settings
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('cancellation_time_brackets')
        .get();

    final adminFundAccountId = settingsDoc.data()?['admin_razorpay_fund_acc_id'];
    if (adminFundAccountId == null || adminFundAccountId.isEmpty) {
      print('❌ Admin fund account not found.');
      return;
    }

    final url = "https://us-central1-petproject-test-g.cloudfunctions.net/v2initiatePayout";

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "serviceProviderId": "ADMIN", // label only
        "orderId": orderId,
        "fundAccountId": adminFundAccountId,
        "amount": (adminFee * 100).toInt(), // in paise
      }),
    );

    print("📤 Admin payout response: ${response.body}");
  } catch (e) {
    print("🚨 Admin payout error: $e");
  }
}

// 🔽 V V V ADD THIS NEW METHOD INSIDE THE PendingBoardingRequestCard CLASS 🔽 V V V

/// Handles the logic for rejecting and moving a booking request.
void showLoadingOverlay(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF2CB4B6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void hideLoadingOverlay(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}



void showCancellationInvoiceDialog({
  required BuildContext context,
  required Map<DateTime,List<String>> cancellations,
  required Map<String, String> petNamesMap,
  required List<Map<String, dynamic>> petSizes,
  required Map<String, double> boardingPriceByPet,
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

       // ── Compute a per‑day total by summing each pet’s refund ───
      final Map<DateTime, double> dayTotals = {
        for (final day in dates)
          day: cancellations[day]!.fold<double>(0, (sum, petId) {
            // 1) boarding price for this pet

            final ps = petSizes.firstWhere((m) => m['id'] == petId);
            final boarding = (ps['price']   as num).toDouble();
            final walk     = (ps['walkFee'] as num).toDouble();
            final meal     = (ps['mealFee'] as num).toDouble();
            final subtotal = boarding + walk + meal;

            // 4) find refund % for this date

            // 5) that pet’s refund amount
            final petRefund = subtotal;

            return sum + petRefund;
          }),
      };

      // BEFORE building the FutureBuilder, you already have:
      final computedGross = dayTotals.values.fold(0.0, (sum, v) => sum + v);
      final adminFeeFinal = computedGross * (adminPct / 100);
      final refundableBase = computedGross;      // ← base actually
      final netRefund = computedGross;

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
                    // ── Per‑date breakdown ───────────────────────────
                    for (final day in dates) ...[
                      // Date header
                      Text(
                        DateFormat('MMM dd, yyyy').format(day),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      // 1) Per‑pet refund lines
                      for (final petId in cancellations[day]!) ...[
                        Builder(builder: (ctx2) {
                          final petName = petNamesMap[petId] ?? petId;

                          // lookup this pet’s rates by ID
                          final ps = petSizes.firstWhere((m) => m['id'] == petId);
                          final boarding = (ps['price']   as num).toDouble();
                          final walk     = (ps['walkFee'] as num).toDouble();
                          final meal     = (ps['mealFee'] as num).toDouble();
                          final subtotal = boarding + walk + meal;

                          final refundAmt = subtotal;

                          return Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• $petName:',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '    Boarding: ₹${boarding.toStringAsFixed(2)}   '
                                      'Walk: ₹${walk.toStringAsFixed(2)}   '
                                      'Meal: ₹${meal.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // 2) Date‑total line
                      Builder(builder: (ctx2) {
                        final dayTotal = cancellations[day]!
                            .fold<double>(0, (sum, petId) {
                          // lookup rates again
                          final ps = petSizes.firstWhere((m) => m['id'] == petId);
                          final boarding = (ps['price']   as num).toDouble();
                          final walk     = (ps['walkFee'] as num).toDouble();
                          final meal     = (ps['mealFee'] as num).toDouble();
                          final subtotal = boarding + walk + meal;

                          return sum + (subtotal);
                        });

                        return Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 12),
                          child: Text(
                            'Total refund for this date: ₹${dayTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                        );
                      }),

                      const Divider(),
                    ],

                    const Divider(),

                    // ── Summary ─────────────────────────────
                    const SizedBox(height: 8),

                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('company_documents')
                          .doc('fees')
                          .get(),
                      builder: (context, feeSnap) {
                        // default 18%
                        double gstFraction = 0.18;
                        if (feeSnap.hasData && feeSnap.data!.data() != null) {
                          final fees = feeSnap.data!.data() as Map<String, dynamic>;
                          final parsed = double.tryParse(fees['gst_rate_percent']?.toString() ?? '') ?? 18.0;
                          gstFraction = parsed > 1 ? parsed / 100.0 : parsed;
                        }

                        final gstRefund = refundableBase * gstFraction;
                        print('🧾 GST TRACE → refundableBase: $refundableBase, gstFraction: $gstFraction, gstRefund: $gstRefund');

                        final netRefundWithGst = refundableBase + gstRefund;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gross refund (base): ₹${computedGross.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'GST refund: ₹${gstRefund.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            Text('Calculated on refundable base', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 12),

                            Text(
                              'Final refund (base + GST): ₹${netRefundWithGst.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text('Amount credited to your account', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 32),
                            Text(
                              'Admin fee ($adminPct%): –₹${adminFeeFinal.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text('Deducted by Admin', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600)),

                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Actions ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'No',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        const SizedBox(width: 12),

// 1. Wrap the action button in a StatefulBuilder to manage loading state
                        StatefulBuilder(
                          builder: (ctx2, setState) {
                            bool _isLoading = false;

                            return TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                setState(() => _isLoading = true);
                                // Show overlay loader
                                showLoadingOverlay(context, "Processing cancellation...");

                                try {
                                  // --- Your Existing Cancellation Logic Starts Here ---

                                  final raw = bookingDoc.data()! as Map<String, dynamic>;
                                  final nowTs = DateTime.now();
                                  final firestore = FirebaseFirestore.instance;
                                  final batch = firestore.batch();
                                  final ref = bookingDoc.reference;

                                  // 1️⃣ Update daily_summary decrements
                                  cancellations.forEach((date, petsToCancel) {
                                    final dateString = DateFormat('yyyy-MM-dd').format(date);
                                    final summaryRef = firestore
                                        .collection('users-sp-boarding')
                                        .doc(raw['service_id'] as String)
                                        .collection('daily_summary')
                                        .doc(dateString);
                                    batch.update(summaryRef, {
                                      'bookedPets': FieldValue.increment(-petsToCancel.length),
                                    });
                                  });

                                  // 2️⃣ Recompute adjusted amounts, update booking
                                  final cb = raw['cost_breakdown'] as Map<String, dynamic>? ?? {};
                                  final double originalSpFee =
                                      double.tryParse(cb['sp_service_fee']?.toString() ?? '0') ?? 0.0;
                                  final double originalSpGst =
                                      double.tryParse(cb['sp_service_gst_fee']?.toString() ?? '0') ?? 0.0;
                                  final double originalTotal =
                                      double.tryParse(cb['total_amount']?.toString() ?? '0') ?? 0.0;
                                  final double adjustedTotal = originalTotal - computedGross;

                                  final settingsSnap = await firestore
                                      .collection('company_documents')
                                      .doc('fees')
                                      .get();

                                  final parsed =
                                      double.tryParse(settingsSnap.data()?['gst_rate_percent']?.toString() ?? '') ??
                                          18.0;
                                  final gstFraction = parsed > 1 ? parsed / 100.0 : parsed;

                                  final gstRefund = refundableBase * gstFraction;
                                  final adjustedSpFee = (originalSpFee - computedGross).clamp(0, double.infinity);
                                  final adjustedSpGst = (originalSpGst - gstRefund).clamp(0, double.infinity);
                                  final netRefundWithGst = netRefund + gstRefund;

                                  final updates = <String, dynamic>{
                                    'refund_amount': netRefundWithGst,
                                    'cancellation_requested_at': nowTs,
                                    'cost_breakdown.sp_service_fee': adjustedSpFee,
                                    'cost_breakdown.sp_service_gst_fee': adjustedSpGst,
                                    'cost_breakdown.sp_total_with_gst': adjustedSpFee + adjustedSpGst,
                                  };

                                  for (final d in dates) {
                                    final key = DateFormat('yyyy-MM-dd').format(d);
                                    updates['attendance_override.$key'] =
                                        FieldValue.arrayUnion(cancellations[d]!);
                                  }

                                  batch.update(ref, updates);

                                  // 3️⃣ Handle Razorpay refund if enabled
                                  final payDoc = await firestore
                                      .collection('company_documents')
                                      .doc('payment')
                                      .get();
                                  final refundEnabled =
                                      (payDoc.data()?['checkoutEnabled'] as bool?) ?? false;

                                  String? refundId;
                                  if (refundEnabled) {
                                    final razorpayPaymentId = raw['payment_id'] as String?;
                                    if (razorpayPaymentId != null) {
                                      final int amountInPaise = (netRefundWithGst * 100).round();
                                      final refundResp = await requestRefund(
                                        paymentId: razorpayPaymentId,
                                        amountInPaise: amountInPaise,
                                      );
                                      refundId = refundResp['id'] as String?;
                                    }
                                  }

                                  // 4️⃣ Add to history and commit batch
                                  final historyRef =
                                  ref.collection('sp_cancellation_history').doc();
                                  final historyEntry = {
                                    'refund_requested_at': nowTs,
                                    'net_refund_including_gst': netRefundWithGst,
                                    'refund_id': refundId,
                                    'created_at': nowTs,
                                  };
                                  batch.set(historyRef, historyEntry);
                                  await batch.commit();

                                  // 5️⃣ Admin fee payout (optional)
                                  if (adminFeeFinal > 0) {
                                    await triggerAdminCancellationPayout(
                                      orderId: bookingDoc.id,
                                      adminFee: adminFeeFinal,
                                    );
                                  }

                                  // Hide loader before showing snackbar
                                  hideLoadingOverlay(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Refund of ₹${netRefundWithGst.toStringAsFixed(2)} (incl. GST) has been initiated successfully.',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.green.shade600,
                                    ),
                                  );

                                  Navigator.of(context).pop(); // Close dialog

                                } catch (e) {
                                  hideLoadingOverlay(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('An error occurred: $e')),
                                  );
                                } finally {
                                  setState(() => _isLoading = false);
                                }
                              },
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                                  : Text('Yes, Cancel', style: GoogleFonts.poppins(color: Colors.red)),
                            );
                          },
                        ),
                      ],
                    ),
                ]),
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


class OvernightPendingRequests extends StatefulWidget {
  final String serviceId;

  const   OvernightPendingRequests({required this.serviceId});

  @override
  _OvernightPendingRequestsState createState() =>
      _OvernightPendingRequestsState();
}

class _OvernightPendingRequestsState extends State<OvernightPendingRequests>
    with SingleTickerProviderStateMixin {
  late final DateTime today;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  StreamSubscription<DocumentSnapshot>? _verificationSub;


  // --- UPDATED: Filter state variables ---
  SortOrder _sortOrder = SortOrder.ascending;
  DateTimeRange? _selectedRange; // Changed from DateTime to DateTimeRange
  bool _isSearchActive = false;



  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _verificationSub?.cancel();
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
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

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
// In _OvernightPendingRequestsState class:

// ADD THIS NEW HELPER METHOD
// This method attempts to deduce the GST rate based on the amounts.
  String _getGstPercentageLabel(double netValue, double gstAmount) {
    if (netValue == 0) return '';
    final double percentage = (gstAmount / netValue) * 100;

    // Only display if the GST amount is actually non-zero
    if (gstAmount > 0.01) {
      if (percentage > 0 && percentage < 100) {
        return '(${percentage.toStringAsFixed(0)}%)';
      }
    }
    return '';
  }


// REPLACE _buildInvoiceRow
  Widget _buildInvoiceRow(String label, double amount, {bool isDeduction = false, bool isPrimary = false, bool isBold = false, bool isTotal = false}) {
    const Color primaryColor = Color(0xFF2CB4B6);

    Color color;
    if (isTotal) {
      color = primaryColor;
    } else if (isDeduction) {
      color = Colors.red.shade600;
    } else {
      color = Colors.black87;
    }

    String amountText;
    if (isDeduction) {
      // Deductions show with a minus sign
      amountText = '-₹${amount.toStringAsFixed(2)}';
    } else {
      // Positive amounts show normally
      amountText = '₹${amount.toStringAsFixed(2)}';
    }

    final weight = isBold || isTotal ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: weight,
              color: color,
            ),
          ),
          Text(
            amountText,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: weight,
              color: color,
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



// V V V PASTE AND REPLACE THE METHODS YOU COPIED WITH THESE VERSIONS V V V

  void _showBookingDetailsDialog(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.only(top: 12),
          // This helper function now needs the document data
          title: _buildDialogHeader("Booking Details", context),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                // Pass the document data to the content widget
                child: _bookingDetailsContent(doc),              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CLOSE',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 8),
        );
      },
    );
  }

// Helper for the dialog header (you can add this too for consistency)

  // In _OvernightPendingRequestsState

// 🔽 V V V ADD THIS NEW HELPER FUNCTION 🔽 V V V
// This function fetches the details from the 'pet_services' subcollection for all pets.
  Future<Map<String, Map<String, dynamic>>> _fetchPetServiceDetails(DocumentSnapshot bookingDoc) async {
    final data = bookingDoc.data() as Map<String, dynamic>;
    final petIds = (data['pet_id'] as List<dynamic>?)?.cast<String>() ?? [];
    final Map<String, Map<String, dynamic>> fetchedServices = {};

    for (final petId in petIds) {
      // Correctly reference the subcollection document
      final petServiceDoc = await bookingDoc.reference.collection('pet_services').doc(petId).get();
      if (petServiceDoc.exists) {
        fetchedServices[petId] = petServiceDoc.data() as Map<String, dynamic>;
      }
    }
    return fetchedServices;
  }


// This method now accepts the data map directly
  // 🔽 V V V REPLACE your old _bookingDetailsContent method with this new one 🔽 V V V
  Widget _bookingDetailsContent(DocumentSnapshot doc) {

    const Color secondaryColor = Color(0xFF0097A7);


    const Color lightTextColor = Color(0xFF757575);

    // Extract top-level details needed for the list
    final data = doc.data() as Map<String, dynamic>;
    final petIds = (data['pet_id'] as List<dynamic>?)?.cast<String>() ?? [];
    final petNames = (data['pet_name'] as List<dynamic>?)?.cast<String>() ?? [];
    final petImages = (data['pet_images'] as List<dynamic>?)?.cast<String>() ?? [];

    // Use a FutureBuilder to handle the async data fetch from the subcollection
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _fetchPetServiceDetails(doc), // Call the new fetching function
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No detailed service data found."));
        }

        final perDayServices = snapshot.data!;

        // Once data is fetched, build the UI as before
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(petIds.length, (index) {
              final petId = petIds[index];
              final petName = petNames[index];
              final petImage = (petImages.length > index) ? petImages[index] : 'https://via.placeholder.com/150';

              // Now we get the details from our fetched map
              final petServiceDetails = perDayServices[petId];

              if (petServiceDetails == null) return const SizedBox.shrink();

              final dailyDetails = petServiceDetails['dailyDetails'] as Map<String, dynamic>;
              final sortedDatesForPet = dailyDetails.keys.toList()..sort();

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(petImage),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  title: Text(petName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.black87)),
                  subtitle: Text(
                      "${dailyDetails.length} day${dailyDetails.length > 1 ? 's' : ''} booked",
                      style: GoogleFonts.poppins(fontSize: 12, color: lightTextColor)),
                  childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  expandedAlignment: Alignment.topLeft,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ...sortedDatesForPet.map((dateString) {
                      final date = DateFormat('yyyy-MM-dd').parse(dateString);
                      final details = dailyDetails[dateString] as Map<String, dynamic>;
                      final hasMeal = details['meals'] == true;
                      final hasWalk = details['walk'] == true;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 16, color: Colors.black87.withOpacity(0.7)),
                            const SizedBox(width: 12),
                            Text(DateFormat('EEE, dd MMM yyyy').format(date),
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            if (hasMeal)
                              Tooltip(
                                  message: "Meal Included",
                                  child: Icon(Icons.restaurant_menu_rounded,
                                      size: 18, color: secondaryColor)),
                            if (hasMeal && hasWalk) const SizedBox(width: 12),
                            if (hasWalk)
                              Tooltip(
                                  message: "Walk Included",
                                  child: Icon(Icons.directions_walk_rounded,
                                      size: 18, color: secondaryColor)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _onRejectOrder(DocumentSnapshot docSnap) async {
    final fs = FirebaseFirestore.instance;
    final batch = fs.batch();
    final data = docSnap.data() as Map<String, dynamic>;

    try {
      // 1. Get the list of booked dates and number of pets
      final bookedDates = (data['selectedDates'] as List<dynamic>? ?? []).cast<Timestamp>();
      final numberOfPets = data['numberOfPets'] as int? ?? 0;
      final serviceId = data['service_id'] as String; // Should be available from doc.data()

      // 2. Decrement bookedPets count in daily_summary for each date
      if (numberOfPets > 0 && bookedDates.isNotEmpty) {
        for (final ts in bookedDates) {
          final date = ts.toDate();
          final dateId = DateFormat('yyyy-MM-dd').format(date);
          final summaryRef = fs
              .collection('users-sp-boarding')
              .doc(serviceId)
              .collection('daily_summary')
              .doc(dateId);

          // Use a negative increment to reduce the count
          batch.update(summaryRef, {
            'bookedPets': FieldValue.increment(-numberOfPets),
          });
        }
      }

      // 3. Update the booking status (the original reject logic)
      batch.update(docSnap.reference, {
        'sp_confirmation': false,
        'order_status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(), // Optional: record rejection time
      });

      // 4. Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${docSnap.id} rejected and slots freed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting order: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    final baseQuery = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .where('order_status',    isEqualTo: 'pending_payment')
        .where('timestamp',       isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp',     descending: false);

    return Scaffold(
      backgroundColor: Colors.white70,
      body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // The old UI is replaced with a single call to the new responsive bar
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: baseQuery.snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // 🔴 1. ADD PRINT HERE TO CHECK ERRORS
              if (snap.hasError) {
                print("❌ ERROR in Stream: ${snap.error}");
              }

              // 🟡 2. ADD PRINT HERE TO CHECK LOADING STATE
              if (snap.connectionState == ConnectionState.waiting) {
                print("⏳ Stream is loading...");
                return const Center(child: CircularProgressIndicator());
              }

              // 🟢 3. ADD PRINT HERE TO CHECK DOCUMENT COUNT
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                print("⚠️ Stream has data but list is EMPTY. Docs count: 0");
                return const Center(child: Text('No pending orders found.'));
              }

              // 🔵 4. PRINT FOUND DOCS DETAILS
              print("✅ SUCCESS: Found ${snap.data!.docs.length} documents.");
              for (var doc in snap.data!.docs) {
                print("Found Order ID: ${doc.id} | Status: ${doc['order_status']}");
              }

              var filteredDocs = snap.data!.docs;

              // Date Range Filter Logic
              if (_selectedRange != null) {
                filteredDocs = filteredDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderDates = (data['selectedDates'] as List)
                      .map((e) => (e as Timestamp).toDate())
                      .map((d) => DateTime(d.year, d.month, d.day))
                      .toList();

                  return orderDates.any((orderDate) {
                    final start = _selectedRange!.start;
                    final end = _selectedRange!.end;
                    return (orderDate.isAfter(start) ||
                        orderDate.isAtSameMomentAs(start)) &&
                        (orderDate.isBefore(end) ||
                            orderDate.isAtSameMomentAs(end));
                  });
                }).toList();
              }

              // Sorting Logic
              if (_sortOrder == SortOrder.descending) {
                filteredDocs = filteredDocs.reversed.toList();
              }

              // Search Filter
              final rawDocs = filteredDocs.where((d) {
                return searchQuery.isEmpty ||
                    d.id.toLowerCase().contains(searchQuery.toLowerCase());
              });

              if (rawDocs.isEmpty) {
                return Center(
                  child: Text(
                    'No pending orders match your filters.',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }

              final items = rawDocs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final dates = (data['selectedDates'] as List)
                    .map((e) => (e as Timestamp).toDate())
                    .map((dt) => DateTime(dt.year, dt.month, dt.day))
                    .toList();
                return {
                  'doc': d,
                  'dates': dates,
                  'spConfirmed': data['sp_confirmation'] == true,
                };
              }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final m = entry.value;
                      final docSnap = m['doc'] as DocumentSnapshot;
                      final dates = m['dates'] as List<DateTime>;
                      final spConfirmed = m['spConfirmed'] as bool;
                      final email = (docSnap.data()
                      as Map<String, dynamic>)['email'] ??
                          '';

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${idx + 1})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: 350, minWidth: 100),
                            child: Stack(
                              children: [
                                PendingBoardingRequestCard(
                                  serviceId: widget.serviceId,
                                  doc: docSnap,
                                  selectedDates: dates,
                                  mode: HighlightMode.ongoing,
                                  frompending: true,
                                  onComplete: () => _onCompleteOrder(
                                      docSnap.id, email, docSnap),
                                  onReject: () => _onRejectOrder(docSnap), // <--- ADD THIS
                                ),
                                if (spConfirmed)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),);
  }
  // --- NEW: Unified and responsive filter bar ---
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
                  icon: const Icon(Icons.filter_list, size: 18, color: Colors.black87),
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
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: CircleAvatar(radius: 4, backgroundColor: accentColor),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, color: primaryColor),
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

  Future<void> _onCompleteOrder(
      String id, String email, DocumentSnapshot docSnap) async {
    try {
      await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('service_request_boarding')
          .doc(id)
          .update({'order_status': 'completed'});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $id marked as completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing order: $e')),
      );
    }
  }

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


class PendingBoardingRequestCard extends StatelessWidget {
  final VoidCallback? onReject; // <--- ADD THIS
  final DocumentSnapshot doc;
  final String serviceId;
  final List<DateTime> selectedDates;
  final HighlightMode mode;
  final VoidCallback onComplete;
  final bool frompending;

  const PendingBoardingRequestCard({
    Key? key,
    required this.doc,
    required this.selectedDates,
    required this.mode,
    required this.onComplete,
    required this.serviceId,
    required this.frompending, this.onReject,
  }) : super(key: key);

  // ⚠️ THE _rejectAndMoveRequest FUNCTION HAS BEEN REMOVED ENTIRELY ⚠️
  // It is no longer included in this class.

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    final hasSpConfirmation = data.containsKey('sp_confirmation');
    final isConfirmed = data['sp_confirmation'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            stops: const [0.015, 0.015],
            colors: [
              hasSpConfirmation
                  ? (isConfirmed ? Colors.green : Colors.red)
                  : accentColor,
              Colors.white
            ],
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 650;

          // --- TWEAK 1: Use dynamic padding based on screen width ---
          return Padding(
            padding: EdgeInsets.all(isWide ? 16.0 : 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TWEAK 2: Pass isWide to the header for dynamic font sizes ---
                _buildHeader(context, id, data, isWide),
                Divider(height: isWide ? 24 : 20),
                Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: isWide ? 2 : 0,
                        child: _buildUserInfo(context, data)),
                    if (isWide) const SizedBox(width: 16),
                    // --- TWEAK 3: Reduce vertical spacing on mobile ---
                    if (!isWide) const SizedBox(height: 12),
                    Expanded(
                        flex: isWide ? 3 : 0,
                        child: _buildBookingInfo(context, data)),
                  ],
                ),
                SizedBox(height: isWide ? 16 : 12),
                _buildDatesSection(),
                const SizedBox(height: 8),
                // --- TWEAK 4: Fixed layout for action buttons ---
                _buildActionButtons(context, id, data),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String id, Map<String, dynamic> data, bool isWide) {
    final hasSpConfirmation = data.containsKey('sp_confirmation');
    final isConfirmed = data['sp_confirmation'] == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order Request',
                style: GoogleFonts.poppins(
                  // Use a smaller font size on narrow screens
                    fontSize: isWide ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'ID: $id',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Order ID copied to clipboard")),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy Order ID',
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (hasSpConfirmation)
              _buildStatusBadge(isConfirmed ? 'Confirmed' : 'Rejected',
                  isConfirmed ? Colors.green : Colors.red)
            else
              _buildStatusBadge('Pending Confirmation', accentColor),
            const SizedBox(height: 8),
            // NEW CODE WITH FLEXIBLE WRAP
            if (!hasSpConfirmation)
              Wrap(
                spacing: 8, // Horizontal space between buttons
                runSpacing: 8, // Vertical space if they stack
                alignment: WrapAlignment.end, // Keeps them aligned to the right
                children: [
                  _styledButton(
                    'Accept',
                    Icons.check,
                    Colors.green,
                        () => doc.reference.update({
                      'sp_confirmation': true,
                    }),
                  ),
                  // ✅ MODIFIED: Simple update to 'rejected' status in place
                  // MODIFIED REJECT BUTTON:
                  _styledButton(
                    'Reject',
                    Icons.close,
                    Colors.red,
                        () {
                      if (onReject != null) {
                        onReject!();
                      } else {
                        // Fallback simple update if no callback is provided
                        doc.reference.update({
                          'sp_confirmation': false,
                          'order_status': 'rejected',
                        });
                      }
                    },
                  ),
                ],
              )

            else if (frompending == false && mode == HighlightMode.ongoing)
              _styledButton(
                  'Complete', Icons.done_all, primaryColor, onComplete),
          ],
        ),
      ],
    );
  }

  // Inside the _OvernightPendingRequestsState class:




// V V V REPLACE this entire method V V V
  Widget _buildActionButtons(BuildContext context, String id, Map<String, dynamic> data) {
    // Extract chat-related data safely
    final serviceId = data['service_id'] as String?;
    final shopName = data['shopName'] as String?;
    final owner_phone = data['owner_phone'] as String?;
    final notification_email = data['notification_email'] as String?;
    final bookingId = doc.id;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 👇 THIS IS THE NEW BUTTON YOU'RE ADDING 👇
        TextButton(
          child: Text(
            "Booking Details",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          onPressed: () {
            // 1. Find the parent state object.
            final state = context.findAncestorStateOfType<_OvernightPendingRequestsState>();
            // 2. Call the dialog method on that state object, passing the booking document.
            state?._showBookingDetailsDialog(context, doc);
          },
        ),
        // The SizedBox is optional for spacing
        const SizedBox(width: 4),

        // Your existing Support Ticket Button
        IconButton(
          icon: const Icon(Icons.headset_mic),
          color: primaryColor,
          tooltip: 'Raise Support Ticket',
          onPressed: () async {
            // ... existing onPressed logic for support ticket ...
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Raise Ticket'),
                content: Text('Do you want to raise a ticket for Order #$id?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                ],
              ),
            );
            if (confirm == true) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SPChatPage(
                    initialOrderId: id,
                    serviceId: this.serviceId,
                    shop_name: shopName ?? "", // Replace with actual data if available
                    shop_phone_number: owner_phone ?? "", // Replace with actual data
                    shop_email: notification_email ?? "ownerEmail", // Replace with actual data
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 8),

        // Your existing Chat Button
        if (serviceId != null && shopName != null)
          Builder(builder: (ctx) {
            // ... existing chat button logic ...
            final chatId = '${serviceId}_$bookingId';
            final me = FirebaseAuth.instance.currentUser!.uid;
            final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

            return StreamBuilder<DocumentSnapshot>(
              stream: chatDoc.snapshots(),
              builder: (ctx1, chatSnap) {
                final chatData = (chatSnap.data?.data() as Map<String, dynamic>?) ?? {};
                final rawLastRead = chatData['lastReadBy_$me'];
                final lastRead = (rawLastRead is Timestamp)
                    ? rawLastRead.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0);

                return StreamBuilder<QuerySnapshot>(
                  stream: chatDoc.collection('messages').orderBy('timestamp', descending: false).snapshots(),
                  builder: (ctx2, msgSnap) {
                    final docs = msgSnap.data?.docs ?? [];
                    final unreadCount = docs.where((d) {
                      final ts = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final sender = d['senderId'] as String? ?? '';
                      return sender != me && ts.isAfter(lastRead);
                    }).length;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          color: primaryColor,
                          tooltip: 'Chat with parent',
                          onPressed: () {
                            chatDoc.set({'lastReadBy_$me': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                            Navigator.of(ctx).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreenSP(
                                  chatId: chatId,
                                  serviceId: serviceId,
                                  shop_name: shopName,
                                  bookingId: bookingId,
                                ),
                              ),
                            );
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          }),
      ],
    );
  }



  Widget _buildDatesSection() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Dates',
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
        const SizedBox(height: 8),
        ExpandableDateList(
          dates: selectedDates,
          highlightColor: primaryColor,
          isHighlighted: (dt) {
            return (mode == HighlightMode.ongoing && dt == todayDate) ||
                (mode == HighlightMode.past && dt.isBefore(todayDate)) ||
                (mode == HighlightMode.upcoming && dt.isAfter(todayDate));
          },
        ),
      ],
    );
  }

// In PendingBoardingRequestCard class:
// In PendingBoardingRequestCard class:

// 1. UPDATE _buildBookingInfo to correctly pass context and access state.
  Widget _buildBookingInfo(BuildContext context, Map<String, dynamic> data) {
    // Access state safely using the context passed to the build method.
    final state = (context).findAncestorStateOfType<_OvernightPendingRequestsState>();
    final ts = (data['timestamp'] is Timestamp)
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    // Use the new standardized field for accurate earnings display.
    // Fallback to old 'sp_service_fee' if the new field is missing (for older bookings).
    final earnings = data['sp_service_fee_exc_gst'] as double? ??
        data['sp_service_fee_inc_gst'] as double? ?? // Fallback 2: Try Inc GST
        data['sp_service_fee'] as double? ?? // Fallback 3: Old cost_breakdown field
        0.0;

    final isConfirmed = data['sp_confirmation'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoColumn('Booked On', DateFormat.yMMMd().add_jm().format(ts),
              icon: Icons.event_available_outlined),
          const SizedBox(height: 12),

          // WRAP the Earnings row in a GestureDetector
          GestureDetector(
            // Only allow tap if the order is confirmed
            onTap: state != null
                ? () => state._showEarningsBreakdownDialog(context, doc)
                : null,
            child: _buildInfoColumn(
              'Your Earnings',
              '₹${earnings.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
              // Pass the suffix icon
              valueSuffix: const Icon(
                Icons.info_outline,
                size: 16,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

// 2. UPDATE _buildUserInfo to accept context (required by build method updates)
  Widget _buildUserInfo(BuildContext context, Map<String, dynamic> data) {
    final owner = data['user_name'] as String? ?? 'N/A';
    final phone = data['phone_number'] as String? ?? 'N/A';
    final pets = (data['pet_name'] as List<dynamic>?)?.cast<String>() ?? [];
    final petIds = (data['pet_id'] as List<dynamic>?)?.cast<String>() ?? [];
    final userId = data['user_id'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The original calls are correct here (only passing label, value, named icon)
        _buildInfoColumn('Pet Parent', owner, icon: Icons.person_outline),
        const SizedBox(height: 12),
        _buildInfoColumn('Contact', "The number will be displayed after the order is confirmed", icon: Icons.phone_outlined),
        const SizedBox(height: 12),
        _buildInfoColumn('Pets', pets.join(', '), icon: Icons.pets_outlined),
        const SizedBox(height: 4),
        TextButton.icon(
          icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.black87),
          label: Text('View Pet Details', style: GoogleFonts.poppins(fontSize: 12)),
          style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
          onPressed: () =>
              _showPetDetailsDialog(context, pets, petIds, userId),
        ),
      ],
    );
  }

// 3. UPDATE _buildInfoColumn to support valueSuffix and fix wrapping (REQUIRED)
// New:
  Widget _buildInfoColumn(String label, String value,
      {required IconData icon, Widget? valueSuffix}) { // <-- CONFIRMED FINAL SIGNATURE
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
              // Use Row + Expanded to control wrapping and display suffix
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
                  if (valueSuffix != null) ...[
                    const SizedBox(width: 6),
                    valueSuffix,
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _styledButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

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
            // The function signature now expects context first, then names, ids, userId
            future: _buildPetCards(context, petNames, petIds, userId),
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryColor));
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
      BuildContext context,
      List<String> names,
      List<String> ids,
      String userId) async {
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
      url.isNotEmpty && url != petImage) // Filter out empty strings and the main image
          .toList() ??
          [];

      print(
          'Pet Name: $petName, Main Image: $petImage, Additional: ${petImagesList.length}');

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
                    // Pet Image (Circular Avatar)
                    GestureDetector(
                      onTap: () {
                        // Navigate to the FullScreenImageViewer
                        Navigator.of(context).push( // <--- Correct use of context
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imageUrl: petImage,
                              // Use a unique tag for the Hero animation
                              tag: 'pet-image-$petId',
                            ),
                          ),
                        );
                      },
                      child: Hero( // Wrap with Hero for smooth animation
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
                          detailText(
                              'Vet Phone',
                              "The number will be displayed after the order is confirmed"),
                          detailText(
                              'Emergency Contact',
                              "The number will be displayed after the order is confirmed"),
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
                                  imageUrls: petImagesList,  // Pass the whole list
                                  initialIndex: index,         // Pass the tapped index
                                  heroTagPrefix: heroTagPrefix, // Pass the tag prefix
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
                                    child:
                                    const Icon(Icons.pets, color: Colors.grey),
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
  // To be added inside the PendingBoardingRequestCard class

  Widget _buildPdfReportSection(String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
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
}

// You'll need to import 'package:cached_network_image/cached_network_image.dart';
// and 'package:flutter/material.dart'

class FullScreenImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String heroTagPrefix;

  const FullScreenImageGallery({
    Key? key,
    required this.imageUrls,
    required this.initialIndex,
    required this.heroTagPrefix,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background
      body: Stack(
        children: [
          // The Swipable Gallery
          PageView.builder(
            controller: PageController(initialPage: initialIndex), // Start on the tapped image
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              // This dynamic tag MUST match the one on the thumbnail
              final tag = '${heroTagPrefix}-${index}';

              return Hero(
                tag: tag,
                child: InteractiveViewer(
                  clipBehavior: Clip.none,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain, // Use 'contain' for full-screen
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// You'll need to import 'package:cached_network_image/cached_network_image.dart';
// and 'package:flutter/material.dart'
// and 'package:google_fonts/google_fonts.dart' (optional for the close button style)

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    required this.tag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background for the image
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: tag, // Must match the tag on the original image
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
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
              color: primaryColor,
            ),
            label: Text(
              _expanded
                  ? 'Show less'
                  : 'Show $extra more date${extra > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primaryColor,
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
            indicatorColor: primaryColor,
            tabs: [
              Tab(
                child: Text(
                  'User History',
                  style: TextStyle(color: primaryColor),
                ),
              ),
              Tab(
                child: Text(
                  'Provider History',
                  style: TextStyle(color: primaryColor),
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
            final num boarding = data['total_boarding_fee']   as num;
            final num walk     = data['total_walk_fee']   as num;
            final num meal     = data['total_meal_fee']   as num;
            final num net      = boarding + walk + meal;
            final num refundableBase = data['net_refund_excluding_gst'] as num? ?? 0;
            final num gstRefund = data['cancelled_gst'] as num? ?? 0;
            final num finalRefund = data['net_refund_including_gst'] as num? ?? (refundableBase + gstRefund);

            return Card(
              color: Colors.white,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: primaryColor),
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
                                color: primaryColor,  // your border color
                                width: 1.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
// show the three raw fee totals
            _infoRow('Total boarding fee', '₹${(data['total_boarding_fee'] as num).toStringAsFixed(2)}'),
            _infoRow('Total walk fee',     '₹${(data['total_walk_fee'] as num).toStringAsFixed(2)}'),
            _infoRow('Total meal fee',     '₹${(data['total_meal_fee'] as num).toStringAsFixed(2)}'),
            _infoRow('Refundable base', '₹${refundableBase.toStringAsFixed(2)}'),
            _infoRow('GST refund',      '₹${gstRefund.toStringAsFixed(2)}'),
            _infoRow('Final refund',    '₹${finalRefund.toStringAsFixed(2)}'),

            const SizedBox(height: 8),

// then

            _infoRow('Net Refund', '₹${net.toStringAsFixed(2)}'),
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
