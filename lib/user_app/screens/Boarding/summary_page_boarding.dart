import 'dart:convert';

import 'dart:math';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:http/http.dart' as http;

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:shimmer/shimmer.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:video_player/video_player.dart';

import '../../main.dart';

import 'BoardingChatScreen.dart';

import 'OpenCloseBetween.dart';

import 'boarding_confirmation_page.dart';



// --------------------------------------------------------------------------

// --- Main Widget

// --------------------------------------------------------------------------



class SummaryPage extends StatefulWidget {

  static const routeName = '/summary';

  final String serviceId, shopImage, shopName, walkingFee, sp_id, bookingId;

  final DateTime? startDate, endDate;

  final double totalCost;

  final double? transportCost, pickupDistance, dropoffDistance, foodCost, walkingCost;

  final bool? dailyWalkingRequired, pickupRequired, dropoffRequired;

  final String transportVehicle, openTime, closeTime, areaName, foodOption;

  final List<String> petIds, petNames, petImages;

  final int numberOfPets, availableDaysCount;

  final List<DateTime> selectedDates;

  final GeoPoint sp_location;

  final Map<String, dynamic>? foodInfo;

  final String mode;

  final Map<String, int> rates;

  final Map<String, int> mealRates;

  final Map<String, int> refundPolicy;

  final String fullAddress;

  final Map<String, int> walkingRates;

  final Map<String, Map<String, dynamic>> perDayServices;

  final List<Map<String, dynamic>> petSizesList;



  const SummaryPage({

    super.key,

    required this.totalCost,

    required this.transportCost,

    required this.foodCost,

    required this.walkingCost,

    required this.perDayServices,

    required this.serviceId,

    required this.shopImage,

    required this.shopName,

    required this.sp_id,

    this.startDate,

    this.endDate,

    this.dailyWalkingRequired,

    this.pickupDistance,

    this.dropoffDistance,

    required this.petIds,

    required this.petNames,

    required this.numberOfPets,

    this.pickupRequired,

    this.dropoffRequired,

    this.transportVehicle = 'Default Vehicle',

    required this.availableDaysCount,

    required this.selectedDates,

    required this.openTime,

    required this.closeTime,

    required this.sp_location,

    required this.areaName,

    required this.foodOption,

    required this.foodInfo,

    required this.petImages,

    required this.bookingId,

    required this.mode,

    required this.rates,

    required this.mealRates,

    required this.refundPolicy,

    required this.fullAddress,

    required this.walkingRates,

    required this.walkingFee,

    required this.petSizesList,

  });



  @override

  _SummaryPageState createState() => _SummaryPageState();

}



class _SummaryPageState extends State<SummaryPage> {

// --- State & Theme Variables ---

  static const Color primaryColor = Color(0xFF00C2CB);

  static const Color secondaryColor = Color(0xFF0097A7);

  static const Color accentColor = Color(0xFFFF9800);

  static const Color darkColor = Color(0xFF263238);

  static const Color lightTextColor = Color(0xFF757575);

  static const Color backgroundColor = Color(0xFFFFFFFF);



  bool _isProcessingPayment = false;

  late Razorpay _razorpay;

  late FirebaseMessaging _messaging;

  late final Future<_FeesData> _feesFuture;

  late final List<DateTime> _sortedDates;

  Future<void> _fetchCancellationReasons() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('tnc_cancellation_reasons')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final boardingMap = data['boarding'] as Map<String, dynamic>?;

        if (boardingMap != null) {
          final Map<String, String> fetchedReasons = {};
          boardingMap.forEach((key, value) {
            fetchedReasons[key] = value as String;
          });
          setState(() {
            cancellationReasonsMap = fetchedReasons;
          });
        } else {
          _setHardcodedReasons();
        }
      } else {
        _setHardcodedReasons();
      }
    } catch (e) {
      print('Error fetching cancellation reasons: $e');
      _setHardcodedReasons();
    }
  }

  void _setHardcodedReasons() {
    setState(() {
      cancellationReasonsMap = {
        'admin_timeout': 'Admin took too long to respond',
        'change_plans': 'Change of plans',
        'cost_high': 'Cost was too high',
        'other': 'Other',
        'sp_timeout': 'Service provider took too long to respond',
      };
    });
  }



// --- Logic & Controllers ---

  final String _createOrderUrl = 'https://createrazorpayordertest-urjpiqxoca-uc.a.run.app/createOrder';
  late Map<String, String> cancellationReasonsMap;

  /*final Map<String, String> cancellationReasonsMap = {

    'Service provider took too long to respond': 'sp_timeout',

    'Admin took too long to respond': 'admin_timeout',

    'Cost was too high': 'cost_high',

    'Change of plans': 'change_plans',

    'Other': 'other',

  };*/



  @override
  void initState() {
    super.initState();
    _sortedDates = List<DateTime>.from(widget.selectedDates)..sort();
    _feesFuture = _fetchFees();
    _messaging = FirebaseMessaging.instance;
    _messaging.subscribeToTopic('chat_${widget.sp_id}');
    _messaging.requestPermission(alert: true, badge: true, sound: true);
    _saveFcmToken();
    _fetchCancellationReasons(); // New call here
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }


  @override

  void dispose() {

    _razorpay.clear();

    super.dispose();

  }



// --- Data Handling Methods ---

  Future<String> _generateSingleUniquePin(String boarderId, {String? excludePin}) async {

    final random = Random();

    final firestore = FirebaseFirestore.instance;

    String pin = '';

    bool isUnique = false;

    while (!isUnique) {

      pin = (1000 + random.nextInt(9000)).toString();

      if (pin == excludePin) continue;

      final startPinQuery = firestore.collectionGroup('service_request_boarding').where('sp_id', isEqualTo: boarderId).where('isStartPinUsed', isEqualTo: false).where('startPinRaw', isEqualTo: pin).limit(1).get();

      final endPinQuery = firestore.collectionGroup('service_request_boarding').where('sp_id', isEqualTo: boarderId).where('isEndPinUsed', isEqualTo: false).where('endPinRaw', isEqualTo: pin).limit(1).get();

      final results = await Future.wait([startPinQuery, endPinQuery]);

      isUnique = results[0].docs.isEmpty && results[1].docs.isEmpty;

    }

    return pin;

  }



  Future<Map<String, dynamic>> _generateUniquePins(String boarderId) async {

    final startPin = await _generateSingleUniquePin(boarderId);

    final endPin = await _generateSingleUniquePin(boarderId, excludePin: startPin);

    final startPinHash = sha256.convert(utf8.encode(startPin)).toString();

    final endPinHash = sha256.convert(utf8.encode(endPin)).toString();

    return {

      'startPinRaw': startPin,

      'startPinHash': startPinHash,

      'isStartPinUsed': false,

      'endPinRaw': endPin,

      'endPinHash': endPinHash,

      'isEndPinUsed': false,

      'pinsCreatedAt': FieldValue.serverTimestamp(),

    };

  }



  Future<_FeesData> _fetchFees() async {

    final snap = await FirebaseFirestore.instance.collection('company_documents').doc('fees').get();

    final data = snap.data() ?? {};

    final platformFee = double.tryParse(data['user_app_platform_fee'] ?? '0') ?? 0;

    final gstPct = double.tryParse(data['gst_percentage'] ?? '0') ?? 0;

    return _FeesData(platformFee, platformFee * gstPct / 100);

  }



  Future<void> _saveFcmToken() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final token = await _messaging.getToken();

    if (token != null) {

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'fcmToken': token}, SetOptions(merge: true));

    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) => FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': t}));

  }



// --- Dialog & Cancellation Logic ---

  Future<void> _confirmAndCancelBooking() async {
    // First pop-up: Confirmation of cancellation
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade600, size: 50),
              const SizedBox(height: 16),
              Text(
                'Cancel Request?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel this request?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: lightTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('NO', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('YES, CANCEL', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

// Second pop-up: Reasons for cancellation
    List<String> selectedReasons = [];
    TextEditingController otherController = TextEditingController();
    bool showOtherText = false;

// --- FIX #1: DECLARE THE VALIDATION MESSAGE HERE ---
    String? validationMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // The Dialog now correctly uses the `validationMessage` from the outer scope
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (unchanged)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Why are you canceling?',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: darkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Checkbox list (unchanged)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: cancellationReasonsMap.keys.map((code) {
                            final isSelected = selectedReasons.contains(code);
                            final reasonText = cancellationReasonsMap[code]!;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: CheckboxListTile(
                                title: Text(
                                  reasonText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isSelected ? primaryColor : darkColor,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedReasons.add(code);
                                    } else {
                                      selectedReasons.remove(code);
                                    }
                                    showOtherText = selectedReasons.contains('other');
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: primaryColor,
                                tileColor: isSelected ? primaryColor.withOpacity(0.05) : Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // "Other" reason text field (unchanged)
                    if (showOtherText)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextField(
                          controller: otherController,
                          maxLines: 3,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Enter other reason...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                        ),
                      ),

                    // --- FIX #2: USE THE OUTER 'validationMessage' VARIABLE ---
                    if (validationMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          validationMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            'GO BACK',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: lightTextColor,
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            final userReason = otherController.text.trim();
                            final isOtherSelected = selectedReasons.contains('other');

                            // --- FIX #3: UPDATE THE OUTER 'validationMessage' ---
                            if (selectedReasons.isEmpty) {
                              setState(() {
                                validationMessage = 'Please select at least one reason.';
                              });
                              return;
                            }

                            if (isOtherSelected && userReason.isEmpty) {
                              setState(() {
                                validationMessage = 'Please enter your reason in the text box.';
                              });
                              return;
                            }

                            final Map<String, String> reasonMap = {};
                            for (final reasonCode in selectedReasons) {
                              if (reasonCode == 'other') {
                                reasonMap[reasonCode] = userReason;
                              } else {
                                reasonMap[reasonCode] = cancellationReasonsMap[reasonCode]!;
                              }
                            }

                            navigator.pop();
                            await _finalizeCancellation(reasonMap);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 3,
                          ),
                          child: Text(
                            'SUBMIT',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // [REPLACE] your _finalizeCancellation method with this

  Future<void> _finalizeCancellation(Map<String, String> reasonMap) async {
    final firestore = FirebaseFirestore.instance;
    final ref = firestore
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .doc(widget.bookingId);

    final cancelledRef = firestore
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('cancelled_requests')
        .doc(widget.bookingId);

    try {
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;

        // --- NEW: Decrement logic starts here ---

        // 1. Get the booking details needed for the decrement.
        final bookedDates = (data['selectedDates'] as List<dynamic>? ?? [])
            .cast<Timestamp>();
        final numberOfPets = data['numberOfPets'] as int? ?? 0;

        // 2. Start a batch write to ensure all operations succeed or fail together.
        final batch = firestore.batch();

        // 3. Loop through each date of the booking to decrement its summary count.
        if (numberOfPets > 0 && bookedDates.isNotEmpty) {
          for (final timestamp in bookedDates) {
            final date = timestamp.toDate();
            final dateString = DateFormat('yyyy-MM-dd').format(date);
            final summaryRef = firestore
                .collection('users-sp-boarding')
                .doc(widget.serviceId)
                .collection('daily_summary')
                .doc(dateString);

            // Use FieldValue.increment with a negative number to decrement the count.
            batch.update(summaryRef, {
              'bookedPets': FieldValue.increment(-numberOfPets)
            });
          }
        }
        // --- End of new logic ---

        // 4. Add the existing cancellation operations to the same batch.
        batch.set(cancelledRef, {
          ...?data,
          'cancelled_at': FieldValue.serverTimestamp(),
          'cancellation_reason': reasonMap,
        });
        batch.delete(ref);

        // 5. Commit all operations at once.
        await batch.commit();
      }

      // Navigate away after successful cancellation.
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeWithTabs()),
        );
      }
    } catch (e) {
      print("Error during cancellation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking. Please try again.')),
        );
      }
    }
  }



// --- Payment & Booking Logic ---

  Future<void> _book() async {

    if (_isProcessingPayment) return;

    final ok = await showDialog<bool>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => AlertDialog(

        title: Text('Confirm Booking'),

        content: Text('Are you sure you want to book now?'),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),

          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Confirm')),

        ],

      ),

    ) ?? false;

    if (!ok) return;



    try {

      setState(() => _isProcessingPayment = true);

      double newBoardingCost = 0.0;

      widget.perDayServices.forEach((petId, serviceDetails) {

        final petSize = serviceDetails['size'] as String;

        final dailyDetails = serviceDetails['dailyDetails'] as Map<String, dynamic>;

        final rateForPet = (widget.rates[petSize] ?? 0).toDouble();

        newBoardingCost += (rateForPet * dailyDetails.length);

      });

      final subTotal = newBoardingCost + (widget.foodCost ?? 0) + (widget.walkingCost ?? 0) + (widget.transportCost ?? 0);

      final f = await _feesFuture;

      final double total = subTotal + f.platform + f.gst;



      final ord = await _createOrder((total * 100).toInt());

      final orderId = (ord['id'] ?? (ord['order'] is Map ? ord['order']['id'] : null))?.toString();

      if (orderId == null || orderId.isEmpty) throw Exception('Order-id missing in response: $ord');

      await _openCheckout(orderId);

    } catch (e) {

      setState(() => _isProcessingPayment = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating order: $e')));

    }

  }



  Future<void> _bookSlot() async {

    setState(() => _isProcessingPayment = true);



    try {

      final pinData = await _generateUniquePins(widget.sp_id);

      final ref = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('service_request_boarding').doc(widget.bookingId);

      await ref.set({

        'order_status': 'confirmed',

        'status': 'Confirmed',

        'payment_skipped': true,

        'sp_confirmation': true,

        'user_confirmation': true,

        'user_t&c_acceptance': true,

        'confirmed_at': FieldValue.serverTimestamp(),

        ...pinData,

      }, SetOptions(merge: true));



      Navigator.pushReplacement(

        context,

        MaterialPageRoute(

          builder: (_) => ConfirmationPage(
            perDayServices:widget.perDayServices,

            sortedDates: _sortedDates,

            buildOpenHoursWidget: buildOpenHoursWidget(widget.openTime, widget.closeTime, _sortedDates),

            shopName: widget.shopName,

            shopImage: widget.shopImage,

            selectedDates: widget.selectedDates,

            totalCost: widget.totalCost,

            petNames: widget.petNames,

            petImages: widget.petImages,

            openTime: widget.openTime,

            closeTime: widget.closeTime,

            bookingId: widget.bookingId,

            serviceId: widget.serviceId,

            fromSummary: true, petIds: widget.petIds,
            foodCost: widget.foodCost,
            walkingCost: widget.walkingCost,
            transportCost: widget.transportCost,
            rates: widget.mealRates,
            mealRates: widget.mealRates,
            walkingRates: widget.walkingRates,
            fullAddress: widget.fullAddress,
            sp_location: widget.sp_location,

          ),

        ),

      );

    } catch (e) {

      setState(() => _isProcessingPayment = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to book slot: $e')));

    }

  }



  Future<Map<String, dynamic>> _createOrder(int amountPaise) async {

    final res = await http.post(Uri.parse(_createOrderUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'amount': amountPaise, 'currency': 'INR', 'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}'}));

    if (res.statusCode != 200) throw Exception('Order API failed: ${res.body}');

    return jsonDecode(res.body) as Map<String, dynamic>;

  }



  Future<void> _openCheckout(String orderId) async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in.')));

      return;

    }



    double newBoardingCost = 0.0;

    widget.perDayServices.forEach((petId, serviceDetails) {

      final petSize = serviceDetails['size'] as String;

      final dailyDetails = serviceDetails['dailyDetails'] as Map<String, dynamic>;

      final rateForPet = (widget.rates[petSize] ?? 0).toDouble();

      newBoardingCost += (rateForPet * dailyDetails.length);

    });

    final subTotal = newBoardingCost + (widget.foodCost ?? 0) + (widget.walkingCost ?? 0) + (widget.transportCost ?? 0);

    final f = await _feesFuture;

    final double total = subTotal + f.platform + f.gst;



    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final d = snap.data() ?? {};

    final opts = {

      'key': 'rzp_test_bVo1FO7Zzowm5T',

      'amount': (total * 100).toInt(),

      'order_id': orderId,

      'name': widget.shopName,

      'description': 'Booking Payment',

      'prefill': {'contact': d['phone_number'] ?? '', 'email': d['email'] ?? ''},

      'external': {'wallets': ['googlepay']},

    };

    _razorpay.open(opts);

  }



  // [REPLACE] your entire _buildBookingFlow method with this

  // [REPLACE] your entire _buildBookingFlow method with this
  Widget _buildBookingFlow() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .get(),
      builder: (context, spSnapshot) {
        if (!spSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final spData = spSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final policyUrl = spData['partner_policy_url'] as String?;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(widget.serviceId)
              .collection('service_request_boarding')
              .doc(widget.bookingId)
              .snapshots(),
          builder: (context, bookingSnapshot) {
            if (!bookingSnapshot.hasData || !bookingSnapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }

            final data = bookingSnapshot.data!.data() as Map<String, dynamic>;
            final currentUser = FirebaseAuth.instance.currentUser!;

            final spConfirmationValue = data['sp_confirmation'];
            final spConfirmed = spConfirmationValue is bool && spConfirmationValue == true;
            final isRejected = spConfirmationValue is bool && spConfirmationValue == false; // The rejection condition

            final tncAccepted = data['user_t&c_acceptance'] ?? false;

            // 💡 NEW LOGIC: Return the rejection widget if rejected
            if (isRejected) {
              return _buildRejectionNotice();
            }

            // Return the normal confirmation steps if pending or confirmed
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Next Steps",
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: darkColor),
                  ),
                  const SizedBox(height: 9),

                  // Step 1: Chat with Boarder
                  _BookingStep(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconSize: 19,
                    title: 'Chat with the Boarder',
                    subtitle: 'Confirm availability and details.',
                    status: _StepStatus.completed,
                    action: _buildChatButton(currentUser.uid),
                    titleFontSize: 13,
                    subtitleFontSize: 11,
                  ),
                  const _StepConnector(),

                  // Step 2: Boarder Confirmation
                  _BookingStep(
                    icon: Icons.storefront_rounded,
                    iconSize: 19,
                    title: 'Boarder Confirmation',
                    subtitle: 'Waiting for the boarder to accept.',
                    status: spConfirmed ? _StepStatus.completed : _StepStatus.active,
                    titleFontSize: 13,
                    subtitleFontSize: 11,
                  ),
                  const _StepConnector(),

                  // Step 3: Review & Accept Terms
                  _BookingStep(
                    icon: Icons.verified_user_outlined,
                    iconSize: 19,
                    title: 'Review & Accept Terms',
                    subtitle: 'By confirming, you accept the Boarding Center\'s terms & conditions.',
                    status: !spConfirmed
                        ? _StepStatus.inactive
                        : (tncAccepted ? _StepStatus.completed : _StepStatus.active),
                    action: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (policyUrl != null && policyUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              icon: Icon(Icons.picture_as_pdf_outlined, color: secondaryColor, size: 16),
                              label: Text(
                                'View Partner Policy',
                                style: GoogleFonts.poppins(
                                  color: secondaryColor,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              onPressed: () => _launchURL(policyUrl),
                            ),
                          ),
                        if (spConfirmed && !tncAccepted)
                          _buildTncButtons(),
                      ],
                    ),
                    titleFontSize: 13,
                    subtitleFontSize: 11,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _handlePaymentSuccess(PaymentSuccessResponse r) async {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Successful! ID: ${r.paymentId}')));

    final ref = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('service_request_boarding').doc(widget.bookingId);

    await ref.set({'payment_id': r.paymentId, 'order_id': r.orderId, 'razorpay_signature': r.signature}, SetOptions(merge: true));

    await ref.update({'order_status': 'confirmed'});

    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder: (_) => ConfirmationPage(
          perDayServices:widget.perDayServices,
          petIds:widget.petIds,


          sortedDates: _sortedDates,

          buildOpenHoursWidget: buildOpenHoursWidget(widget.openTime, widget.closeTime, _sortedDates),

          shopName: widget.shopName,

          shopImage: widget.shopImage,

          selectedDates: widget.selectedDates,

          totalCost: widget.totalCost,

          petNames: widget.petNames,

          petImages: widget.petImages,

          openTime: widget.openTime,

          closeTime: widget.closeTime,

          bookingId: widget.bookingId,

          serviceId: widget.serviceId,
          foodCost: widget.foodCost,
          walkingCost: widget.walkingCost,
          transportCost: widget.transportCost,
          rates: widget.mealRates,
          mealRates: widget.mealRates,
          walkingRates: widget.walkingRates,
          fullAddress: widget.fullAddress,
          sp_location: widget.sp_location,

          fromSummary: true,

        ),

      ),

    );

  }



  void _handlePaymentError(PaymentFailureResponse r) {

    setState(() => _isProcessingPayment = false);

    _alert('Payment Failed', 'Code: ${r.code}\nDescription: ${r.message}');

  }



  void _handleExternalWallet(ExternalWalletResponse r) => _alert('External Wallet Selected', r.walletName ?? '');



  void _alert(String t, String m) => showDialog(context: context, builder: (_) => AlertDialog(title: Text(t), content: Text(m)));



// --------------------------------------------------------------------------

// --- BUILD METHOD

// --------------------------------------------------------------------------

  @override

  // --------------------------------------------------------------------------
// --- BUILD METHOD (MODIFIED)
// --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isProcessingPayment) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 💡 NEW: StreamBuilder wrapped around PopScope to get the current status
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('service_request_boarding')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle loading/missing data
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final spConfirmationValue = data['sp_confirmation'];

        // Define the rejection condition
        // Assuming rejection is marked by sp_confirmation: false
        final isRejected = spConfirmationValue is bool && spConfirmationValue == false;

        return PopScope(
          // 💡 NEW LOGIC: Only prevent pop and show cancellation dialog if NOT rejected
          canPop: isRejected,
          onPopInvoked: (didPop) async {
            if (didPop) return;

            // Only show cancellation dialog if the request is still pending/confirmed
            if (!isRejected) {
              await _confirmAndCancelBooking();
            } else {
              // If rejected, simply navigate back to the previous screen/home
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 350,
                    child: Stack(
                      children: [
                        // Video background
                        const ClipRRect(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: _BackgroundVideoPlayer(),
                        ),

                        // Back button overlay (must be inside the StreamBuilder scope)
                        Positioned(
                          top: 40, // adjust for status bar
                          left: 16,
                          child: GestureDetector(
                            // 💡 NEW LOGIC: Tapping the back button manually triggers pop logic
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              if (isRejected) {
                                navigator.pop();
                              } else {
                                await _confirmAndCancelBooking();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBookingFlow(),
                ],
              ),
            ),
            bottomNavigationBar: _bottomBar(context),
          ),
        );
      },
    );
  }





// --------------------------------------------------------------------------

// --- UI WIDGETS

// --------------------------------------------------------------------------

  // ADD THIS NEW METHOD
  // ADD THIS NEW WIDGET inside _SummaryPageState
  // [REPLACE] your existing _buildRejectionNotice() with this
  // [REPLACE] your existing _buildRejectionNotice() method with this

  Widget _buildRejectionNotice() {
    // Format the dates for display
    final datesDisplay = widget.selectedDates.length == 1
        ? DateFormat('MMM d, yyyy').format(widget.selectedDates.first)
        : '${widget.selectedDates.length} days: ${DateFormat('MMM d').format(_sortedDates.first)} - ${DateFormat('MMM d').format(_sortedDates.last)}';

    // 1. Split the message into components to apply bold styling dynamically
    final messageParts = [
      const TextSpan(
        text: "We're so sorry! ",
        style: TextStyle(fontWeight: FontWeight.normal),
      ),
      TextSpan(
        text: widget.shopName,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: darkColor), // Apply bold directly
      ),
      const TextSpan(
        text: " couldn't quite fit your request into their schedule right now. Don't worry, we’ll help you find another cozy corner!✨",
        style: TextStyle(fontWeight: FontWeight.normal),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 💡 Tweak 1: New Header (Removed "A Little Paw-se..." title)
            Row(
              children: [
                Icon(Icons.sentiment_dissatisfied_outlined, color: Colors.red.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Booking Request Denied",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600, // Make the main title stand out in red/dark
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.transparent),

            // 💡 Tweak 2: Use RichText for dynamic bolding of the shop name
            RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: lightTextColor,
                  height: 1.4,
                ),
                children: messageParts,
              ),
            ),
            const SizedBox(height: 24),

            // Details Chip Container (Improved styling for visual hierarchy)
            Container(
              padding: const EdgeInsets.all(16), // Increased padding
              decoration: BoxDecoration(
                color: Colors.grey.shade50, // Lighter background for the search box
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Search Criteria:',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: darkColor),
                  ),
                  const SizedBox(height: 12),

                  // Row for chips
                  Wrap(
                    spacing: 12.0, // horizontal space between chips
                    runSpacing: 8.0, // vertical space between lines of chips
                    children: [
                      _buildFilterDetailChip(
                        icon: Icons.pets_rounded,
                        label: '${widget.numberOfPets} Pet${widget.numberOfPets > 1 ? 's' : ''}',
                      ),
                      _buildFilterDetailChip(
                        icon: Icons.calendar_today_rounded,
                        label: datesDisplay,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Call to Action Button
            ElevatedButton(
              onPressed: () {
                // Navigate to the homepage and trigger the availability dialog
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomeWithTabs(
                      // FIX APPLIED: Changed initialTabIndex from 0 to 1 to land on BoardingHomepage tab
                      initialTabIndex: 1,
                      initialBoardingFilter: {
                        'petCount': widget.numberOfPets,
                        'dates': _sortedDates.map((dt) => DateTime(dt.year, dt.month, dt.day)).toList(),
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: Text(
                'Find Other Available Shops',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
// Add this helper method inside the _SummaryPageState class for chip styling
  Widget _buildFilterDetailChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: secondaryColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryColor,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionsRow() {

    return Row(

      children: [

// Shop Details Button

        Expanded(

          child: _actionDialogButton(

            "Shop Details",

            _showShopDetailsDialog,

          ),

        ),

        const SizedBox(width: 4), // minimal spacing

// Booking Details Button

        Expanded(

          child: _actionDialogButton(

            "Booking Details",

            _showBookingDetailsDialog,

          ),

        ),

        const SizedBox(width: 4),

// Invoice Button

        Expanded(

          child: _actionDialogButton(

            "Invoice",

            _showInvoiceDialog,

          ),

        ),

      ],

    );

  }





  Widget _actionDialogButton(String label, VoidCallback onPressed) {

    return OutlinedButton.icon(

      onPressed: onPressed,

      label: Text(label),

      style: OutlinedButton.styleFrom(

        foregroundColor: darkColor,

        side: BorderSide(color: Colors.grey.shade300, width: 1.5),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

        textStyle: GoogleFonts.poppins(

          fontWeight: FontWeight.w600,

          fontSize: 11,

        ),

      ),

    );

  }



  void _showShopDetailsDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

// Consistent rounded corners

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

// Responsive padding for different screen sizes

          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),

          backgroundColor: backgroundColor,

          titlePadding: EdgeInsets.zero,

          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

          title: _buildDialogHeader("Shop Details", context),

          content: SizedBox(

// Ensures the dialog width is responsive

            width: MediaQuery.of(context).size.width * 0.9,

// We now use a new, more detailed content widget

            child: SingleChildScrollView(

              child: _buildShopDetailsContent(),

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.of(context).pop(),

              child: Text(

                'CLOSE',

                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor),

              ),

            ),

          ],

          actionsPadding: const EdgeInsets.only(right: 16, bottom: 8),

        );

      },

    );

  }



// Add this new widget to your _SummaryPageState

  Widget _buildShopDetailsContent() {

    return Column(

      mainAxisSize: MainAxisSize.min,

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

// Your existing header with name and area

        _shopHeader(),

        const Divider(height: 24, thickness: 1),



// New section for the full address

        Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Icon(Icons.location_pin, size: 18, color: darkColor.withOpacity(0.7)),

            const SizedBox(width: 12),

            Expanded(

              child: Text(

                widget.fullAddress, // Using the full address for more detail

                style: GoogleFonts.poppins(fontSize: 14, color: lightTextColor, height: 1.5),

              ),

            ),

          ],

        ),

        const SizedBox(height: 20),



// New "View on Map" button for better functionality

        SizedBox(

          width: double.infinity,

          child: ElevatedButton.icon(

            label: const Text("View on Map"),

            onPressed: () {

              launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${widget.sp_location.latitude},${widget.sp_location.longitude}'));

              ScaffoldMessenger.of(context).showSnackBar(

                const SnackBar(content: Text("Map functionality to be implemented.")),

              );

            },

            style: ElevatedButton.styleFrom(

              padding: const EdgeInsets.symmetric(vertical: 12),

              backgroundColor: secondaryColor,

              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),

            ),

          ),

        ),

      ],

    );

  }

  Widget _shopHeader() {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 8.0),

      child: Row(

        children: [

          ClipRRect(

            borderRadius: BorderRadius.circular(12),

            child: Image.network(

              widget.shopImage,

              width: 60,

              height: 60,

              fit: BoxFit.cover,

              errorBuilder: (_, __, ___) => Container(

                width: 60,

                height: 60,

                color: backgroundColor,

                child: const Icon(Icons.store, size: 30, color: lightTextColor),

              ),

            ),

          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  widget.shopName,

                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: darkColor),

                ),

                const SizedBox(height: 4),

              ],

            ),

          ),

        ],

      ),

    );

  }

// REPLACE your old _showInvoiceDialog with this new one

  void _showInvoiceDialog() {

    showDialog(

      context: context,

      builder: (context) {

// The state variable now lives here and will be updated correctly.

        bool showPetDetails = false;



        return Dialog(

          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),

          child: ConstrainedBox(

            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),

// StatefulBuilder manages the state locally.

            child:
            StatefulBuilder(

              builder: (BuildContext context, StateSetter setState) {

// --- All the logic is now safely inside the builder ---



                double newBoardingCost = 0.0;

                widget.perDayServices.forEach((petId, serviceDetails) {

                  final petSize = serviceDetails['size'] as String;

                  final dailyDetails = serviceDetails['dailyDetails'] as Map<String, dynamic>;

                  final rateForPet = (widget.rates[petSize] ?? 0).toDouble();

                  newBoardingCost += (rateForPet * dailyDetails.length);

                });

                final double subTotal = newBoardingCost + (widget.foodCost ?? 0) + (widget.walkingCost ?? 0) + (widget.transportCost ?? 0);



                return Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    _buildDialogHeader("Invoice Summary", context),

                    Flexible(

                      child: SingleChildScrollView(

                        child: FutureBuilder<_FeesData>(

                          future: _feesFuture,

                          builder: (_, snap) {

                            if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));

                            final fees = snap.data!;

                            final double grandTotal = subTotal;



                            return Padding(

                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  _buildItemRow('Boarding Fee', newBoardingCost),

                                  if ((widget.foodCost ?? 0) > 0) _buildItemRow('Meal Fee', widget.foodCost!),

                                  if ((widget.walkingCost ?? 0) > 0) _buildItemRow('Walking Fee', widget.walkingCost!),

                                  if ((widget.transportCost ?? 0) > 0) _buildItemRow('Transport Fee', widget.transportCost!),

                                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: DottedDivider()),

                                  _buildItemRow('Grand Total', grandTotal, isTotal: true),

                                  const SizedBox(height: 16),

                                  InkWell(

// This now correctly modifies the 'showPetDetails' variable

                                    onTap: () => setState(() => showPetDetails = !showPetDetails),

                                    child: Row(

                                      mainAxisAlignment: MainAxisAlignment.center,

                                      children: [

                                        Text(showPetDetails ? 'Hide Details' : 'Show Per-Pet Breakdown', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: secondaryColor)),

                                        Icon(showPetDetails ? Icons.expand_less : Icons.expand_more, color: secondaryColor, size: 20),

                                      ],

                                    ),

                                  ),

                                  AnimatedCrossFade(

                                    firstChild: const SizedBox.shrink(),

                                    secondChild: _buildPerPetDailyBreakdown(),

                                    crossFadeState: showPetDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,

                                    duration: const Duration(milliseconds: 300),

                                  ),

                                ],

                              ),

                            );

                          },

                        ),

                      ),

                    ),

                  ],

                );

              },

            ),

          ),

        );

      },

    );

  }





  void _showBookingDetailsDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

// Set padding around the dialog to control its distance from screen edges.

          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),

// A rounded shape looks more modern than the previous circular(0).

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

          backgroundColor: backgroundColor,

// Remove default padding for title and content to use our own.

          titlePadding: EdgeInsets.zero,

          contentPadding: const EdgeInsets.only(top: 12),

// Your existing header widget goes here.

          title: _buildDialogHeader("Booking Details", context),

          content: SizedBox(

// Make the dialog's width a percentage of the screen width.

            width: MediaQuery.of(context).size.width * 0.9,

// Your existing scrollable content.

            child: SingleChildScrollView(

              child: Padding(

                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),

                child: _bookingDetailsContent(),

              ),

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.of(context).pop(),

              child: Text(

                'CLOSE',

                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor),

              ),

            ),

          ],

          actionsPadding: const EdgeInsets.only(right: 16, bottom: 8),

        );

      },

    );

  }



// Placeholder for your header widget.

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

            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: darkColor),

          ),

          InkWell(

            onTap: () => Navigator.of(context).pop(),

            customBorder: const CircleBorder(),

            child: const Padding(

              padding: EdgeInsets.all(4.0),

              child: Icon(Icons.close, color: darkColor, size: 24),

            ),

          ),

        ],

      ),

    );

  }



// Your _bookingDetailsContent widget remains unchanged. It is already well-built.

  Widget _bookingDetailsContent() {

    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: 16.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: List.generate(widget.petIds.length, (index) {

          final petId = widget.petIds[index];

          final petName = widget.petNames[index];

          final petImage = widget.petImages[index];

          final petServiceDetails = widget.perDayServices[petId];

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

              title: Text(petName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkColor)),

              subtitle: Text("${dailyDetails.length} day${dailyDetails.length > 1 ? 's' : ''} booked", style: GoogleFonts.poppins(fontSize: 12, color: lightTextColor)),

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

                        Icon(Icons.calendar_today_rounded, size: 16, color: darkColor.withOpacity(0.7)),

                        const SizedBox(width: 12),

                        Text(DateFormat('EEE, dd MMM yyyy').format(date), style: GoogleFonts.poppins(fontSize: 14, color: darkColor, fontWeight: FontWeight.w500)),

                        const Spacer(),

                        if (hasMeal) Tooltip(message: "Meal Included", child: Icon(Icons.restaurant_menu_rounded, size: 18, color: secondaryColor)),

                        if (hasMeal && hasWalk) const SizedBox(width: 12),

                        if (hasWalk) Tooltip(message: "Walk Included", child: Icon(Icons.directions_walk_rounded, size: 18, color: secondaryColor)),

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

  }





  Widget _bottomBar(BuildContext context) {

// This calculation logic remains the same

    double newBoardingCost = 0.0;

    widget.perDayServices.forEach((petId, serviceDetails) {

      final petSize = serviceDetails['size'] as String;

      final dailyDetails = serviceDetails['dailyDetails'] as Map<String, dynamic>;

      final rateForPet = (widget.rates[petSize] ?? 0).toDouble();

      newBoardingCost += (rateForPet * dailyDetails.length);

    });

    final subTotal = newBoardingCost + (widget.foodCost ?? 0) + (widget.walkingCost ?? 0) + (widget.transportCost ?? 0);



    return FutureBuilder<_FeesData>(

      future: _feesFuture,

      builder: (_, feesSnap) {

        if (!feesSnap.hasData) return const SizedBox.shrink();

        final fees = feesSnap.data!;

        final total = subTotal;



        return StreamBuilder<DocumentSnapshot>(

          stream: FirebaseFirestore.instance.collection('company_documents').doc('payment').snapshots(),

          builder: (ctxPay, paySnap) {

            if (!paySnap.hasData) return const SizedBox.shrink();

            final paymentData = (paySnap.data?.data() as Map<String, dynamic>?) ?? {};

            final checkoutEnabled = paymentData['checkoutEnabled'] as bool? ?? false;



            return StreamBuilder<DocumentSnapshot>(

              stream: FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('service_request_boarding').doc(widget.bookingId).snapshots(),

              builder: (ctxBook, bookSnap) {

                bool readyForConfirmation = false;

                if (bookSnap.hasData && bookSnap.data!.exists) {

                  final d = bookSnap.data!.data() as Map<String, dynamic>;

// NEW LOGIC

                  readyForConfirmation = (d['sp_confirmation'] ?? false) && (d['user_t&c_acceptance'] ?? false); }

                final useCheckout = readyForConfirmation && checkoutEnabled;



                return ClipRRect(

                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                  child: Container(

                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 24),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      boxShadow: [

                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -5)),

                      ],

                    ),

                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

// --- NEWLY ADDED SECTION ---

                        _buildMainActionsRow(),

                        const Divider(),

// --- END OF NEW SECTION ---



// NEW: Added Padding and replaced Row with Wrap for responsiveness

                        Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 24.0),

                          child: Row(

                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [

                              Text(

                                'Total Payable',

                                style: GoogleFonts.poppins(

                                  fontSize: 14,

                                  color: lightTextColor,

                                  fontWeight: FontWeight.w500,

                                ),

                              ),

                              Text(

                                '₹${total.toStringAsFixed(2)}',

                                style: GoogleFonts.poppins(

                                  fontSize: 18,

                                  fontWeight: FontWeight.bold,

                                  color: darkColor,

                                ),

                              ),

                            ],

                          ),

                        ),





                        if (!checkoutEnabled && readyForConfirmation)

                          Padding(

                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),

                            child: _buildDirectPaymentMessage(),

                          ),



                        const SizedBox(height: 5),



                        Padding(

                          padding: const EdgeInsets.symmetric(horizontal: 24.0),

                          child: SizedBox(

                            width: double.infinity,

                            child: _confirmationButton(

                              label: useCheckout ? 'Proceed to Pay' : (readyForConfirmation ? 'Confirm Booking Slot' : 'Awaiting Confirmation'),

                              enabled: readyForConfirmation && !_isProcessingPayment,

                              onTap: useCheckout ? _book : _bookSlot,

                            ),

                          ),

                        ),

                      ],

                    ),

                  ),

                );

              },

            );

          },

        );

      },

    );

  }



  Widget _buildDirectPaymentMessage() {

    return Padding(

      padding: const EdgeInsets.only(top: 5.0),

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        decoration: BoxDecoration(

          color: const Color(0xFFE0F7FA),

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: const Color(0xFFB2EBF2)),

        ),

        child: Row(

          children: [

            const Icon(Icons.info_outline, color: secondaryColor, size: 24),

            const SizedBox(width: 12),

            Expanded(

              child: Text(

                "Payment for this booking is handled directly at the center.",

                style: GoogleFonts.poppins(color: darkColor.withOpacity(0.8), fontWeight: FontWeight.w500, fontSize: 13),

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildConfirmationButtons() {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        _actionChip(

            icon: Icons.cancel_rounded,

            color: Colors.red.shade400,

            onTap: () async {

              final reason = await _getCancelReason();

              if (reason != null) await _finalizeCancellation({'user_declined': reason});

            }),

        const SizedBox(width: 8),

        _actionChip(

            icon: Icons.check_circle_rounded,

            color: Colors.green.shade500,

            onTap: () {

              FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('service_request_boarding').doc(widget.bookingId).update({'user_confirmation': true});

            }),

      ],

    );

  }

// Add this helper method inside your _SummaryPageState class

  // [REPLACE] this helper method inside your _SummaryPageState class

  // [REPLACE] this helper method inside your _SummaryPageState class

  // [REPLACE] this helper method inside your _SummaryPageState class

  Future<void> _launchURL(String urlString) async {
    // --- THIS IS THE FIX ---
    // We must URL-encode the Firebase link before passing it to the viewer.
    final String encodedUrl = Uri.encodeComponent(urlString);

    // Now, we build the viewer URL with the *encoded* link.
    final String googleDocsUrl =
        'https://docs.google.com/gview?url=$encodedUrl&embedded=true';
    // --- END OF FIX ---

    final Uri url = Uri.parse(googleDocsUrl);

    // This part remains the same. It will open in the phone's default browser.
    if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the policy document.')),
        );
      }
    }
  }

  Future<String?> _getCancelReason() async {
    final reasonController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with a branded icon and title
              Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cancel Booking',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: darkColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                'Please tell us why you are canceling. This helps us improve our service.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: lightTextColor,
                ),
              ),
              const SizedBox(height: 20),
              // Text field with enhanced styling
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your reason here...',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(
                      'GO BACK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: lightTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Cancellation reason is required.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        Navigator.pop(context, reason);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      elevation: 3,
                    ),
                    child: Text(
                      'CANCEL BOOKING',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTncButtons() {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        _actionChip(

            icon: Icons.cancel_rounded,

            color: Colors.red.shade400,

            onTap: () async {

              final reason = await _getCancelReason();

              if (reason != null) await _finalizeCancellation({'user_declined_tnc': reason});

            }),

        const SizedBox(width: 8),

        _actionChip(

            icon: Icons.check_circle_rounded,

            color: Colors.green.shade500,

            onTap: () {

              FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('service_request_boarding').doc(widget.bookingId).update({'user_t&c_acceptance': true});

            }),

      ],

    );

  }



  Widget _actionChip({required IconData icon, required Color color, required VoidCallback onTap}) {

    return GestureDetector(

      onTap: onTap,

      child: Container(

        padding: const EdgeInsets.all(8),

        decoration: BoxDecoration(

          color: color.withOpacity(0.1),

          shape: BoxShape.circle,

        ),

        child: Icon(icon, color: color, size: 24),

      ),

    );

  }



  Widget _buildChatButton(String userId) {

    return StreamBuilder<QuerySnapshot>(

      stream: FirebaseFirestore.instance.collection('chats').doc('${widget.serviceId}_${widget.bookingId}').collection('messages').orderBy('timestamp', descending: false).snapshots(),

      builder: (ctx, msgSnap) {

        return ElevatedButton(

          onPressed: () {

            final chatId = '${widget.serviceId}_${widget.bookingId}';

            FirebaseFirestore.instance.collection('chats').doc(chatId).update({'lastReadBy_$userId': FieldValue.serverTimestamp()});

            Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoardingChatScreen(chatId: chatId)));

          },

          style: ElevatedButton.styleFrom(

            backgroundColor: primaryColor,

            foregroundColor: Colors.white,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),

          ),

          child: Text('Chat Now', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),

        );

      },

    );

  }



  Widget _buildItemRow(String label, double amount, {bool isTotal = false}) {

    final textStyle = GoogleFonts.poppins(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, color: isTotal ? darkColor : lightTextColor);

    final amountStyle = GoogleFonts.poppins(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: darkColor);

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(

        children: [

          Text(label, style: textStyle),

          const Spacer(),

          Text('₹${amount.toStringAsFixed(2)}', style: amountStyle),

        ],

      ),

    );

  }



  Widget _confirmationButton({required String label, required bool enabled, required VoidCallback onTap}) {

    return ElevatedButton(

      onPressed: enabled ? onTap : null,

      style: ElevatedButton.styleFrom(

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

        backgroundColor: secondaryColor,

        foregroundColor: Colors.white,

        disabledBackgroundColor: Colors.grey.shade300,

        disabledForegroundColor: Colors.grey.shade500,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        elevation: enabled ? 5 : 0,

      ),

      child: Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),

    );

  }







// REPLACE your entire _buildPerPetDailyBreakdown function with this

  Widget _buildPerPetDailyBreakdown() {

// We MUST iterate by an index to correctly access the separate lists of pet data (petIds, petNames, etc.)

// This now matches the logic in your working _bookingDetailsContent widget.

    return Column(

      children: List.generate(widget.petIds.length, (index) {

        final petId = widget.petIds[index];

        final petName = widget.petNames[index]; // <-- THE FIX: Get the name from the correct list.

        final serviceDetails = widget.perDayServices[petId];



// A safety check in case there are no service details for a pet.

        if (serviceDetails == null) {

          return const SizedBox.shrink();

        }



        final dailyDetails = serviceDetails['dailyDetails'] as Map<String, dynamic>;

        final petSize = serviceDetails['size'] as String;

        final List<Widget> dailyRows = [];

        final sortedDates = dailyDetails.keys.toList()..sort((a, b) => a.compareTo(b));

        final double boardingRate = (widget.rates[petSize] ?? 0).toDouble();

        final double walkingRate = (widget.walkingRates[petSize] ?? 0).toDouble();

        final double mealRate = (widget.mealRates[petSize] ?? 0).toDouble();



        for (final dateString in sortedDates) {

          final date = DateFormat('yyyy-MM-dd').parse(dateString);

          final daily = dailyDetails[dateString] as Map<String, dynamic>;

          final bool hasWalk = daily['walk'] ?? false;

          final bool hasMeals = daily['meals'] ?? false;

          dailyRows.add(

            Padding(

              padding: const EdgeInsets.only(top: 8.0),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text('• ${DateFormat('EEEE, MMM d').format(date)}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: darkColor)),

                  Padding(

                    padding: const EdgeInsets.only(left: 16.0),

                    child: Column(

                      children: [

                        _buildItemRow('Boarding', boardingRate),

                        if (hasWalk) _buildItemRow('Daily Walking', walkingRate),

                        if (hasMeals) _buildItemRow('Meals', mealRate),

                      ],

                    ),

                  ),

                ],

              ),

            ),

          );

        }



        return Padding(

          padding: const EdgeInsets.only(top: 16.0),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                'Pet: $petName ($petSize)', // Use the correct petName and petSize

                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: secondaryColor),

              ),

              ...dailyRows,

            ],

          ),

        );

      }),

    );

  }

}



// --------------------------------------------------------------------------

// --- HELPER CLASSES AND WIDGETS

// --------------------------------------------------------------------------



// [REPLACE] your old _BackgroundVideoPlayer and its State with this new version.


class _BackgroundVideoPlayer extends StatefulWidget {
  const _BackgroundVideoPlayer();
  @override
  _BackgroundVideoPlayerState createState() => _BackgroundVideoPlayerState();
}

class _BackgroundVideoPlayerState extends State<_BackgroundVideoPlayer> {
  VideoPlayerController? _controller;
  String? _placeholderImageUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('photos_and_videos')
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final videoUrl = data['summary_page'] as String?;
        _placeholderImageUrl = data['summary_page_placeholder'] as String?;

        // Show placeholder first
        setState(() {});

        if (videoUrl != null && videoUrl.isNotEmpty) {
          // --- Caching Logic Starts Here ---
          print("Getting video from cache or network...");
          final fileInfo = await DefaultCacheManager().getFileFromCache(videoUrl);

          if (fileInfo != null && fileInfo.file.existsSync()) {
            // 1. Video is in cache, play from file (instant)
            print("Video found in cache. Playing from file.");
            _controller = VideoPlayerController.file(fileInfo.file);
          } else {
            // 2. Video not in cache, play from network and cache it
            print("Video not in cache. Playing from network and caching.");
            // This also downloads the file and saves it for next time.
            DefaultCacheManager().downloadFile(videoUrl);
            _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          }
          // --- Caching Logic Ends Here ---

          await _controller!.initialize();
          if (!mounted) return;

          _controller!.setLooping(true);
          _controller!.setVolume(0.0);
          _controller!.play();

          // Switch from image to video
          setState(() {});
        }
      }
    } catch (e) {
      print("Error initializing video player: $e");
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _controller!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    } else if (_placeholderImageUrl != null && _placeholderImageUrl!.isNotEmpty) {
      return Image.network(
        _placeholderImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: Colors.black),
      );
    } else {
      return Container(color: Colors.black);
    }
  }
}


enum _StepStatus { inactive, active, completed }

class _BookingStep extends StatefulWidget {

  final IconData icon;

  final String title;

  final String subtitle;

  final _StepStatus status;

  final Widget? action;



// NEW optional params

  final double iconSize;

  final double titleFontSize;

  final double subtitleFontSize;



  const _BookingStep({

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.status,

    this.action,

    this.iconSize = 18,

    this.titleFontSize = 13,

    this.subtitleFontSize = 11,

  });



  @override

  __BookingStepState createState() => __BookingStepState();

}



class __BookingStepState extends State<_BookingStep>

    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;

  late Animation<double> _scaleAnimation;



  @override

  void initState() {

    super.initState();

    _animationController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 300),

    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(

      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),

    );

    if (widget.status == _StepStatus.completed) {

      _animationController.forward();

    }

  }



  @override

  void didUpdateWidget(covariant _BookingStep oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.status == _StepStatus.completed &&

        oldWidget.status != _StepStatus.completed) {

      _animationController.forward(from: 0.0);

    }

  }



  @override

  void dispose() {

    _animationController.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    Color iconColor;

    Color iconBgColor;

    FontWeight titleWeight;

    Widget iconWidget;



    switch (widget.status) {

      case _StepStatus.completed:

        iconColor = Colors.white;

        iconBgColor = const Color(0xFF4CAF50);

        titleWeight = FontWeight.w600;

        iconWidget = ScaleTransition(

          scale: _scaleAnimation,

          child: Icon(Icons.check_rounded,

              color: iconColor, size: widget.iconSize),

        );

        break;

      case _StepStatus.active:

        iconColor = _SummaryPageState.primaryColor;

        iconBgColor = Colors.grey.shade200;

        titleWeight = FontWeight.w600;

        iconWidget = ProgressIcon(

          icon: widget.icon,

          color: iconColor,

          size: widget.iconSize,

        );

        break;

      case _StepStatus.inactive:

        iconColor = Colors.grey.shade400;

        iconBgColor = Colors.grey.shade200;

        titleWeight = FontWeight.normal;

        iconWidget =

            Icon(widget.icon, color: iconColor, size: widget.iconSize);

        break;

    }



    return Row(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Container(

          width: widget.iconSize + 16,

          height: widget.iconSize + 16,

          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),

          child: Center(child: iconWidget),

        ),

        const SizedBox(width: 10),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                widget.title,

                style: GoogleFonts.poppins(

                  fontSize: widget.titleFontSize,

                  fontWeight: titleWeight,

                  color: _SummaryPageState.darkColor,

                ),

              ),

              widget.status == _StepStatus.active

                  ? Shimmer.fromColors(

                baseColor: _SummaryPageState.lightTextColor,

                highlightColor: Colors.grey.shade300,

                child: Text(

                  widget.subtitle,

                  style: GoogleFonts.poppins(

                    fontSize: widget.subtitleFontSize,

                    color: _SummaryPageState.lightTextColor,

                  ),

                ),

              )

                  : Text(

                widget.subtitle,

                style: GoogleFonts.poppins(

                  fontSize: widget.subtitleFontSize,

                  color: _SummaryPageState.lightTextColor,

                ),

              ),

              if (widget.action != null)

                Padding(

                  padding: const EdgeInsets.only(top: 6.0),

                  child: widget.action,

                ),

            ],

          ),

        ),

      ],

    );

  }

}



class ProgressIcon extends StatelessWidget {

  final IconData icon;

  final Color color;

  final double size;



  const ProgressIcon({

    super.key,

    required this.icon,

    required this.color,

    this.size = 18.0,

  });



  @override

  Widget build(BuildContext context) {

    return SizedBox(

      width: size,

      height: size,

      child: Stack(

        alignment: Alignment.center,

        children: [

          SizedBox(

            width: size,

            height: size,

            child: CircularProgressIndicator(

              strokeWidth: 2,

              valueColor: AlwaysStoppedAnimation<Color>(color),

            ),

          ),

          Icon(icon, color: color, size: size * 0.65),

        ],

      ),

    );

  }

}



class _StepConnector extends StatelessWidget {

  final double thickness;

  final double height;



  const _StepConnector({

    this.thickness = 1.5,

    this.height = 16,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),

      child: Container(

        height: height,

        width: thickness,

        color: Colors.grey.shade300,

      ),

    );

  }

}



class DottedDivider extends StatelessWidget {

  const DottedDivider({super.key, this.height = 1, this.color = Colors.grey});

  final double height;

  final Color color;



  @override

  Widget build(BuildContext context) {

    return LayoutBuilder(

      builder: (BuildContext context, BoxConstraints constraints) {

        final boxWidth = constraints.constrainWidth();

        const dashWidth = 5.0;

        final dashHeight = height;

        final dashCount = (boxWidth / (2 * dashWidth)).floor();

        return Flex(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          direction: Axis.horizontal,

          children: List.generate(dashCount, (_) {

            return SizedBox(width: dashWidth, height: dashHeight, child: DecoratedBox(decoration: BoxDecoration(color: color)));

          }),

        );

      },

    );

  }

}



class _FeesData {

  final double platform, gst;

  _FeesData(this.platform, this.gst);

}