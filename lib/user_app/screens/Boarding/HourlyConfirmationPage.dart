import 'package:cloud_firestore/cloud_firestore.dart';   // for GeoPoint
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';         // to open the map URL
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../Boarding/boarding_confirmation_page.dart';
import '../HomeScreen/HomeScreen.dart';

class HourlyConfirmationPage extends StatelessWidget {
  final String shopName;
  final bool fromSummary;
  final String shopImage;
  final DateTime selectedDate;
  final double totalCost;
  final List<String> petNames;
  final String openTime;
  final String closeTime;
  final String bookingId;
  final Widget buildOpenHoursWidget;
  final List<String> petImages;
  final String serviceId;


  const HourlyConfirmationPage({
    Key? key,
    required this.shopName,
    required this.shopImage,
    required this.totalCost,
    required this.petNames,
    required this.openTime,
    required this.closeTime,
    required this.bookingId,
    required this.buildOpenHoursWidget,
    required this.petImages, required this.serviceId, required this.fromSummary, required this.selectedDate,
  }) : super(key: key);

  String _formatDate(DateTime date) =>
      DateFormat('MMM dd, yyyy hh:mm a').format(date);

  static const Color accentColor = Color(0xFF00C2CB);


  Widget _dateChip(DateTime d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accentColor),
    ),
    child: Text(
      DateFormat('MMM d, yyyy').format(d),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: accentColor,
      ),
    ),
  );

  Future<GeoPoint> _fetchShopLocation() async {
    final doc = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data['shopLocation'] == null) {
      throw 'No location found';
    }
    return data['shopLocation'] as GeoPoint;
  }

  Future<String> _fetchPhoneNumber() async {
    final doc = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .get();
    final data = doc.data();
    if (data == null || data['phoneNumber'] == null) {
      throw 'No Number';
    }
    return data['phoneNumber'] as String;    // ← corrected
  }


  Future<void> _openPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri)) throw 'Could not call $number';
  }

  Future<void> _openWhatsApp(String number) async {
    // using wa.me which doesn’t require the app-link intent:
    final uri = Uri.parse('https://wa.me/$number');
    if (!await launchUrl(uri)) throw 'Could not open WhatsApp';
  }


  Future<String> _fetchWhatsappNumber() async {
    final doc = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data['WhatsappNumber'] == null) {
      throw 'No Whatsapp';
    }
    return data['WhatsappNumber'] as String;
  }

// 2️⃣ Launch Google Maps at that lat/lng
  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  Widget _sectionTitle(String text) => Row(
    children: [
      Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    ],
  );

  Widget _bookingCard() {
    return StatefulBuilder(builder: (context, setSB) {
      bool showAll = false;
      final allDates = <DateTime>[ selectedDate ];        // <- here
      // compute how many to show as you like (maxChips etc)...
      final w       = MediaQuery.of(context).size.width;
      final maxChips= (w/108).floor();
      final dates   = allDates.length>maxChips
          ? allDates.sublist(0,maxChips)
          : allDates;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        // Wrap the Row in IntrinsicHeight so that its children share a finite height
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dates column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Selected Dates'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dates.map(_dateChip).toList(),
                    ),

                  ],
                ),
              ),

              // Replace that full‐height Container + VerticalDivider with a plain VerticalDivider
              const VerticalDivider(
                color: Colors.grey,
                thickness: 1,
                width: 24, // you can adjust the horizontal spacing here
              ),

              // Pets column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Selected Pets'),
                    const SizedBox(height: 12),
                    Column(
                      children: List.generate(petNames.length, (i) {
                        final img = (i < petImages.length) ? petImages[i] : null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: img != null && img.isNotEmpty
                                    ? Image.network(
                                  img,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                                    : const ColoredBox(
                                  color: Colors.grey,
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.pets, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  petNames[i],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<DocumentSnapshot> _bookingDoc() {
    return FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('service_request_boarding')
        .doc(bookingId)
        .get();
  }


  Future<String> _fetchAreaName() async {
    final doc = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .get();

    if (!doc.exists) return 'Unknown area';
    final data = doc.data();         // ← cast to map
    if (data == null) return 'Unknown area';
    return data['areaName']?.toString() ?? 'Unknown area';
  }

  Future<String> _fetchBookingDate() async {
    final doc = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('service_request_boarding')
        .doc(bookingId)
        .get();

    if (!doc.exists) return 'Unknown date';
    final data = doc.data() as Map<String, dynamic>?;         // ← cast to map
    if (data == null) return 'Unknown date';

    final raw = data['timestamp'];
    if (raw is! Timestamp) return 'Unknown date';
    return DateFormat('dd MMM yyyy').format(raw.toDate());
  }



  @override
  Widget build(BuildContext context) {
    final earliestDate = selectedDate;

    final canCancel =
    DateTime.now().isBefore(earliestDate.subtract(const Duration(hours: 24)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Order #$bookingId",
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          softWrap: true,
          maxLines: 2,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        // Add a TextButton (or GestureDetector) in the actions list:
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  // TODO: Handle Help tap
                },
                child: const Text(
                  "Help",
                  style: TextStyle(
                    color: Colors.orange, // orange color
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: Container(
          color: Colors.white,       // <— container guarantees white
          width: double.infinity,
          height: double.infinity,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Flexible text to allow wrapping
                          Flexible(
                            child: Text(
                              "Booking has been Confirmed!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22, // Slightly reduced to fit better
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131313),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),


                          // Green circular tick
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    "Shop Details",
                    style: GoogleFonts.poppins(
                      fontSize: 15, // Slightly reduced to fit better
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0,left: 0,right: 220), // push it 4px down
                    child: Container(
                      height: 2,
                      width: 30, // underneath “Order Details”
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),

// gap after the underline before the next widget
                  const SizedBox(height: 10),

                  // Shop info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          shopImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shopName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),


                            FutureBuilder<String>(
                              future: _fetchAreaName(),
                              builder: (ctx, snap) {
                                if (snap.connectionState != ConnectionState.done) {
                                  return const SizedBox(
                                    height: 16,
                                    width: 16,
                                  );
                                }
                                final area = snap.data ?? '—';
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Area: $area",
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),


                  // Wrap the entire Row in a Center widget:
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // so the Row only takes as much width as its children
                      children: [
                        FutureBuilder<GeoPoint>(
                          future: _fetchShopLocation(),
                          builder: (ctx, snap) {
                            if (snap.connectionState != ConnectionState.done || !snap.hasData)
                              return const SizedBox.shrink();

                            final gp = snap.data!;
                            return ElevatedButton(
                              onPressed: () => _openMap(gp.latitude, gp.longitude),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accentColor,
                                side: BorderSide(color: accentColor, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/google_maps_logo.png',
                                    width: 18,
                                    height: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),

                        FutureBuilder<String>(
                          future: _fetchPhoneNumber(),
                          builder: (ctx, snap) {
                            if (snap.connectionState != ConnectionState.done || !snap.hasData)
                              return const SizedBox.shrink();
                            return ElevatedButton(
                              onPressed: () => _openPhone(snap.data!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accentColor,
                                side: BorderSide(color: accentColor, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(FontAwesomeIcons.phone, size: 15, color: CupertinoColors.activeGreen),
                                  SizedBox(width: 8),
                                  Text(
                                    'Call',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 8),

                        // WhatsApp button
                        FutureBuilder<String>(
                          future: _fetchWhatsappNumber(),
                          builder: (ctx, snap) {
                            if (snap.connectionState != ConnectionState.done || !snap.hasData)
                              return const SizedBox.shrink();
                            return ElevatedButton(
                              onPressed: () => _openWhatsApp(snap.data!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accentColor,
                                side: BorderSide(color: accentColor, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(FontAwesomeIcons.whatsapp, size: 22, color: CupertinoColors.activeGreen),
                                  SizedBox(width: 8),
                                  Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  buildOpenHoursWidget,
                  const SizedBox(height: 20),
                  Text(
                    "Order Details",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),

// small gap between the text and the underline
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0,left: 0,right: 220), // push it 4px down
                    child: Container(
                      height: 2,
                      width: 30, // underneath “Order Details”
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),

// gap after the underline before the next widget
                  const SizedBox(height: 10),


                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: "Booking ID: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: bookingId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),


                  // Inline FutureBuilder for Booking Date
                  FutureBuilder<String>(
                    future: _fetchBookingDate(),
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final date = snap.data ?? '—';
                      return Row(
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Booking Date: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text: date,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                    },
                  ),
                  const SizedBox(height: 8),

                  // Total cost row
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: "Total Cost: ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: "₹${totalCost.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),




                  const SizedBox(height: 10),



                  // Dates & pets card
                  _bookingCard(),



                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context, canCancel),
    );
  }

  Widget _buildBottomActions(BuildContext context, bool canCancel) {
    final w = MediaQuery.of(context).size.width;

    // Base scale factors
    final fontSize  = w * 0.04;   // e.g. 16px at 400px width
    final iconSize  = w * 0.04;   // match text
    final padV      = w * 0.045;  // vertical padding (~18px)
    final padHDone  = w * 0.06;   // horizontal padding for Done (~24px)
    final padHCancel= w * 0.04;   // horizontal padding for Cancel (~16px)
    final borderW   = w * 0.0075; // border width (~3px)
    final gap       = w * 0.03;   // spacing (~12px)
    final circleSz  = w * 0.06;   // circle icon container (~24px)

    return Container(
      padding: EdgeInsets.all(w * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: w * 0.05,
            offset: Offset(0, -w * 0.025),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // DONE button + tick
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: padV, horizontal: padHDone),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(w * 0.04),
                side: BorderSide(color: Color(0xFF00C2CB), width: borderW),
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (fromSummary) {
                // Pop all the way back to home
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Then show the follow-up dialog
                // Delay to ensure HomeScreen's build is complete
                Future.microtask(() => _showTicketInfoDialog(context));
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Done",
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                SizedBox(width: gap),
                Container(
                  width: circleSz,
                  height: circleSz,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: iconSize, color: Colors.white),
                ),
              ],
            ),
          ),

          // CANCEL BOOKING + cross
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canCancel ? Colors.white : Colors.grey,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: padV, horizontal: padHCancel),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(w * 0.04),
                side: canCancel
                    ? BorderSide(color: const Color(0xFF00C2CB), width: borderW)
                    : BorderSide.none,
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (canCancel) {
                _cancelBooking(context);
              } else {
                showDialog(
                  context: context,
                  barrierDismissible: false, // Prevents tapping outside to dismiss
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    title: Text(
                      "Cancellation Not Allowed",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    content: Text(
                      "Refund is allowed 24 hours before the selected date.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          'OK',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00C2CB), // teal accent
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Cancel Booking",
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                SizedBox(width: gap),
                Container(
                  width: circleSz,
                  height: circleSz,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: iconSize, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTicketInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: Color(0xFF00C2CB)),
              SizedBox(height: 16),
              Text(
                "Your booking is saved under your account. To view it again:\n\n"
                    "1️⃣ Tap on “Accounts.”\n"
                    "2️⃣ Scroll to “My Orders.”\n"
                    "3️⃣ Select the “Boarding” section.\n"
                    "4️⃣ Find and open your ticket from the list.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF00C2CB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Got it!', style: TextStyle(color: Color(0xFF00C2CB))),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _cancelBooking(BuildContext context) async {
    print("Starting booking cancellation for bookingId: $bookingId");
    try {
      // Show a modal progress indicator while processing.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Processing...", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );

      // Query Firestore for the booking document.
      print("Querying Firestore for booking document...");
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('service_request_boarding')
          .where('bookingId', isEqualTo: bookingId)
          .get();
      print("Query completed. Number of documents found: ${querySnapshot.docs.length}");

      // If a matching document was found:
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        print("Document found: ${doc.id} with data: $data");

        // Retrieve the payment ID and the document's timestamp.
        final paymentId = data['payment_id'];
        final Timestamp firestoreTimestamp = data['timestamp'];
        final DateTime refundTimestamp = firestoreTimestamp.toDate();

        // Calculate the refund amount.
        final int refundAmountPaise = await _calculateRefundAmount(refundTimestamp);
        final double refundAmountRupees = refundAmountPaise / 100.0;

        // Dismiss the “Processing…” indicator.
        Navigator.pop(context);

        // Show a custom‐styled confirmation dialog:
        final bool? confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // user must tap a button
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(
              'Confirm Cancellation',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            content: Text(
              "Cancelling this booking will result in a refund of ₹"
                  "${refundAmountRupees.toStringAsFixed(2)}. Do you want to proceed?",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'No',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Yes',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00C2CB), // teal accent
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm != true) {
          // User cancelled the operation.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Cancellation aborted.",
                style: GoogleFonts.poppins(),
              ),
            ),
          );
          return;
        }

        // Show modal again while actually cancelling / generating refund:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Cancelling...", style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );

        print("Initiating refund for paymentId: $paymentId using timestamp: $refundTimestamp");
        final refundId = await _refundPayment(paymentId, refundTimestamp);

        if (refundId == null) {
          Navigator.pop(context); // Dismiss the “Cancelling...” dialog.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Refund failed. Booking cancellation aborted.",
                style: GoogleFonts.poppins(),
              ),
            ),
          );
          return;
        }

        // Update document status and add refund ID.
        data['status'] = 'user_cancellation';
        data['refund_id'] = refundId;
        print("Updated status to 'user_cancellation' and added refund_id: $refundId.");

        // Move the document to "rejected-boarding-bookings".
        print("Moving document to 'rejected-boarding-bookings' collection.");
        await FirebaseFirestore.instance
            .collection('rejected-boarding-bookings')
            .doc(doc.id)
            .set(data);
        print("Document moved successfully.");

        // Delete the original document.
        print("Deleting the original booking document.");
        await doc.reference.delete();
        print("Original booking document deleted.");

        // Dismiss the “Cancelling...” dialog.
        Navigator.pop(context);

        // Show a styled success dialog:
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(
              "Booking Cancelled",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            content: Text(
              "Refund has been initiated",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00C2CB),
                  ),
                ),
              ),
            ],
          ),
        );

        // Wait a few seconds, then pop that dialog.
        await Future.delayed(const Duration(seconds: 3));
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Booking cancelled and refund initiated.",
              style: GoogleFonts.poppins(),
            ),
          ),
        );

        // Navigate to HomePage.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
              (route) => false,
        );
      }
      else {
        // No document found:
        Navigator.pop(context);
        print("No document found with bookingId: $bookingId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Booking not found.",
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
    catch (e) {
      Navigator.pop(context);
      print("Error cancelling booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error cancelling booking.",
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    print("Booking cancellation process completed for bookingId: $bookingId");
  }


  // Updated _refundPayment method:
  Future<String?> _refundPayment(String paymentId, DateTime refundTimestamp) async {
    print("Starting refund for paymentId: $paymentId");
    final url = 'https://razorpayrefundtest-urjpiqxoca-uc.a.run.app/razorpayRefundTest';

    // Fetch platform fee and GST from Firestore.
    final feesDoc = await FirebaseFirestore.instance
        .collection('company_documents')
        .doc('fees')
        .get();
    final platformFeeStr = feesDoc.data()?['user_app_platform_fee'] ?? '0';
    final gstPercentageStr = feesDoc.data()?['gst_percentage'] ?? '0';
    print("Fetched feesDoc - user_app_platform_fee: $platformFeeStr, gst_percentage: $gstPercentageStr");

    final double platformFee = double.parse(platformFeeStr);
    final double gstPercentage = double.parse(gstPercentageStr);
    final double gstAmount = (platformFee * gstPercentage) / 100.0;
    print("Computed platformFee: $platformFee, gstAmount: $gstAmount");

    print("totalCost: $totalCost");

    // Convert all amounts to paise.
    final int totalCostPaise = (totalCost * 100).toInt();
    final int platformFeePaise = (platformFee * 100).toInt();
    final int gstAmountPaise = (gstAmount * 100).toInt();
    print("totalCost in paise: $totalCostPaise, platformFee in paise: $platformFeePaise, gstAmount in paise: $gstAmountPaise");

    // Calculate refundable base in paise.
    final int refundableBasePaise =
        totalCostPaise - (platformFeePaise + gstAmountPaise);
    print("Refundable base (paise) = totalCostPaise ($totalCostPaise) - (platformFeePaise ($platformFeePaise) + gstAmountPaise ($gstAmountPaise)) = $refundableBasePaise");

    // Calculate elapsed time and determine refund percentage.
    final DateTime now = DateTime.now();
    final double diffHours = now.difference(refundTimestamp).inHours.toDouble();
    double refundPercentage = 0;
    if (diffHours < 12) {
      refundPercentage = 1; // full refund
    } else if (diffHours < 24) {
      refundPercentage = 0.5; // 50% refund
    } else if (diffHours < 36) {
      refundPercentage = 0.25; // 25% refund
    } else {
      refundPercentage = 0; // no refund
    }
    print("Time difference (hours): $diffHours, refundPercentage: $refundPercentage");

    // Compute refund amount in paise.
    final int computedRefundAmountPaise =
    (refundableBasePaise * refundPercentage).floor();
    print("Computed refund amount (in paise): $computedRefundAmountPaise");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentId': paymentId,
          'timestamp': refundTimestamp.toIso8601String(),
          'totalCost': totalCostPaise,
          'platformFee': platformFeePaise,
          'gstAmount': gstAmountPaise,
        }),
      );

      if (response.statusCode == 200) {
        final refundResponse = jsonDecode(response.body);
        // Extract refund details from the "refund" property.
        final refundData = refundResponse['refund'];
        final refundId = refundData['id'];
        print("Refund initiated successfully. Refund ID: $refundId");
        return refundId;
      } else {
        print("Refund failed: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (error) {
      print("Error calling cloud function: $error");
      return null;
    } finally {
      print("Refund process completed for paymentId: $paymentId");
    }
  }
  Future<int> _calculateRefundAmount(DateTime refundTimestamp) async {
    // Fetch platform fee and GST from Firestore.
    final feesDoc = await FirebaseFirestore.instance
        .collection('company_documents')
        .doc('fees')
        .get();
    final platformFeeStr = feesDoc.data()?['user_app_platform_fee'] ?? '0';
    final gstPercentageStr = feesDoc.data()?['gst_percentage'] ?? '0';
    print("Fetched fees: platformFeeStr = $platformFeeStr, gstPercentageStr = $gstPercentageStr");

    final double platformFee = double.parse(platformFeeStr);
    final double gstPercentage = double.parse(gstPercentageStr);
    final double gstAmount = (platformFee * gstPercentage) / 100.0;
    print("Parsed values: platformFee = $platformFee, gstPercentage = $gstPercentage, gstAmount = $gstAmount");

    // Convert amounts to paise.
    final int totalCostPaise = (totalCost * 100).toInt();
    final int platformFeePaise = (platformFee * 100).toInt();
    final int gstAmountPaise = (gstAmount * 100).toInt();
    print("Converted to paise: totalCostPaise = $totalCostPaise, platformFeePaise = $platformFeePaise, gstAmountPaise = $gstAmountPaise");

    // The refundable base is total cost minus the non-refundable fees.
    final int refundableBasePaise = totalCostPaise - (platformFeePaise + gstAmountPaise);
    print("Refundable base (paise): $refundableBasePaise");

    // Calculate elapsed time (in hours) from the stored timestamp.
    final DateTime now = DateTime.now();
    final double diffHours = now.difference(refundTimestamp).inHours.toDouble();
    print("Elapsed time since refundTimestamp (hours): $diffHours");

    // Determine refund percentage based on elapsed time.
    double refundPercentage = 0;
    if (diffHours < 12) {
      refundPercentage = 1; // full refund (excluding fees)
    } else if (diffHours < 24) {
      refundPercentage = 0.5; // 50% refund
    } else if (diffHours < 36) {
      refundPercentage = 0.25; // 25% refund
    } else {
      refundPercentage = 0; // no refund
    }
    print("Calculated refundPercentage: $refundPercentage");

    final int computedRefundAmountPaise = (refundableBasePaise * refundPercentage).floor();
    print("Computed refund amount (paise): $computedRefundAmountPaise");
    return computedRefundAmountPaise;
  }
}
