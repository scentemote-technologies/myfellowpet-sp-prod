/*  summary_page_boarding.dart  */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'HourlyConfirmationPage.dart';
import 'OpenCloseBetween.dart';
import 'boarding_confirmation_page.dart';
import 'boarding_parameters_selection_page.dart';

/* ───────────────────────── WIDGET ───────────────────────── */

class HourlySummaryPage extends StatefulWidget {
  static const routeName = '/summary';
  /* incoming data (unchanged) */
  final String serviceId, shopImage, shopName, walkingFee, sp_id;
  final double pricePerHour, totalCost;
  final double? foodCost;
  final bool? dailyWalkingRequired;
  final String openTime, closeTime, areaName, foodOption;
  final List<String> petIds, petNames, petImages;
  final int numberOfPets;
  final DateTime selectedDate;
  final GeoPoint sp_location;
  final Map<String, dynamic>? foodInfo;
  final List<String> selectedTimeSlots;

  const HourlySummaryPage({
    Key? key,
    required this.serviceId,
    required this.shopImage,
    required this.shopName,
    required this.sp_id,
    required this.pricePerHour,
    this.dailyWalkingRequired,
    required this.totalCost,
    required this.petIds,
    required this.petNames,
    required this.numberOfPets,
    required this.walkingFee,
    required this.foodCost,
    required this.openTime,
    required this.closeTime,
    required this.sp_location,
    required this.areaName,
    required this.foodOption,
    required this.foodInfo, required this.petImages, required this.selectedTimeSlots, required this.selectedDate,
  }) : super(key: key);

  @override
  _HourlySummaryPageState createState() => _HourlySummaryPageState();
}

/* ───────────────────────── STATE ───────────────────────── */

class _HourlySummaryPageState extends State<HourlySummaryPage> {
  /* dual‑tone palette */

  static const Color accentColor = Color(0xFF00C2CB);
  bool _hasConfirmedFirstDateRemoval = false;
  bool _hasConfirmedFirstPetRemoval  = false;
  static const Color darkColor   = Colors.black;
  bool _isProcessingPayment = false;

  late Razorpay _razorpay;
  late FirebaseMessaging _messaging;
  int get _petsSelected => widget.petIds.length;
  double? FoodCostPerDay = 0;

  double _updatedTotalCost = 0;
  late final Future<_FeesData> _feesFuture;

  late final List<String> _sortedSlots;
  int get _slotsSelected => _sortedSlots.length;

  final String _createOrderUrl =
      'https://createrazorpayorder-urjpiqxoca-uc.a.run.app/createOrder';

  LinearGradient get _gradient =>
      const LinearGradient(colors: [accentColor, darkColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);

  double get _boardingCost =>
      widget.pricePerHour * _slotsSelected * _petsSelected;


  double get _mealsCost {
    if (widget.foodOption == 'provider') {
      final perSlot = double.tryParse(widget.foodInfo?['cost_per_day']?.toString() ?? '0') ?? 0;
      return perSlot * _slotsSelected * _petsSelected;
    }
    return 0;
  }

  double get _walkingCost {
    if (widget.dailyWalkingRequired == true) {
      return (double.tryParse(widget.walkingFee) ?? 0) * _slotsSelected * _petsSelected;
    }
    return 0;
  }


  double _grandTotal(_FeesData f) => _boardingCost +
      _mealsCost +
      _walkingCost +
      f.platform +
      f.gst;



  @override
  void initState() {
    super.initState();
    _updateFoodPrice();
    _feesFuture  = _fetchFees();

    _messaging = FirebaseMessaging.instance;
    _messaging.requestPermission(alert: true, badge: true, sound: true);
    _saveFcmToken();

    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR,   _handlePaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);


    _sortedSlots = List.from(widget.selectedTimeSlots)
      ..sort((a, b) {
        final fmt = DateFormat('h:mm a');
        final ta = fmt.parse(a.split(' – ')[0]);
        final tb = fmt.parse(b.split(' – ')[0]);
        return ta.compareTo(tb);
      });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  /* ─────────────────────── Helpers ─────────────────────── */

  Future<_FeesData> _fetchFees() async {
    final snap = await FirebaseFirestore.instance
        .collection('company_documents').doc('fees').get();
    final data        = snap.data() ?? {};
    final platformFee = double.tryParse(data['user_app_platform_fee'] ?? '0') ?? 0;
    final gstPct      = double.tryParse(data['gst_percentage']        ?? '0') ?? 0;
    return _FeesData(platformFee, platformFee * gstPct / 100);
  }

  Future<void> _saveFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(
            (t) => FirebaseFirestore.instance
            .collection('users').doc(user.uid).update({'fcmToken': t}));
  }

  Future<bool> _confirmFirstRemoval(String what) async {
    final result = await showDialog<bool>(
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
          'Remove $what?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'Do you really want to remove this $what?',
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
                color: const Color(0xFF00C2CB),
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }






// Call this for pets:
  Future<void> _removePet(int idx) async {
    if (!_hasConfirmedFirstPetRemoval) {
      final ok = await _confirmFirstRemoval('pet');
      if (!ok) return;
      _hasConfirmedFirstPetRemoval = true;
    }
    if (widget.petIds.length == 1) {
      final lastOk = await _confirmLastRemoval('pet');
      if (!lastOk) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      widget.petIds.removeAt(idx);
      widget.petNames.removeAt(idx);
      widget.petImages.removeAt(idx);
    });
  }


  /* ─────────────────────── UI BUILD ─────────────────────── */

  @override
  Widget build(BuildContext context) {
    // If processing payment, show a full‐screen loader
    if (_isProcessingPayment) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Otherwise, build the normal page
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6F6F6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: darkColor, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: darkColor,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Everything inside padding except _costCard
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shopHeader(),

                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bookingCard(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Cost Breakdown'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // Cost card with no padding
              _costCard(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildOpenHoursWidget(widget.openTime, widget.closeTime, [widget.selectedDate]),const SizedBox(height: 12),
                  ],
                ),
              ),

              // Spacer above the bottom bar
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomSheet: _bottomBar(context),
    );
  }




  void _showFoodInfoDialog() {
    final opt  = widget.foodOption.isEmpty ? 'Not selected' : widget.foodOption;
    final info = widget.foodInfo ?? {};

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Food details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Option : $opt'),
            const SizedBox(height: 6),
            if (info.isNotEmpty) ...[
              Text('Description : ${info['Description'] ?? '-'}'),
              const SizedBox(height: 6),
              Text('Cost / day : ₹${info['cost_per_day'] ?? '-'}'),
            ] else
              const Text('No extra information.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }


  /* ---------- small builders ---------- */



  Widget _shopHeader() => Container(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(0),
      boxShadow: const [BoxShadow(color: Colors.transparent,blurRadius:1,offset:Offset(0,4))],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _image(widget.shopImage),
      const SizedBox(width:16),
      _shopDetails(),
    ]),
  );

  Widget _image(String url)=> Container(
    width:100,height:100,
    decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow:[BoxShadow(color:Colors.grey.withOpacity(.2),blurRadius:6,offset:const Offset(0,3))]),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(url,fit:BoxFit.cover,
          errorBuilder:(_,__,___)=>Icon(Icons.store,size:50,color: Colors.grey.shade400)),
    ),
  );

  Widget _shopDetails() {
    TextStyle body = TextStyle(color:Colors.grey.shade600,fontSize:16);
    return Expanded(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(
        widget.shopName,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black, // or any color you prefer
        ),
      ),

      const SizedBox(height:2),
      Row(children:[
        const Icon(Icons.location_on,size:18,color:darkColor),const SizedBox(width:4),
        Expanded(
          child: Text(
            widget.areaName,
            style: GoogleFonts.poppins(
              fontSize: 16,          // adjust as needed
              fontWeight: FontWeight.normal,
              color: Colors.black87,  // or your desired color
            ),
          ),
        ),

      ]),//widget.pricePerDay.toStringAsFixed(2)
      const SizedBox(height:2),
      Row(children:[
        const Icon(Icons.currency_rupee,size:16,color:darkColor),const SizedBox(width:4),
        Expanded(child:Text('${widget.pricePerHour.toStringAsFixed(2)} / day', style: body)
        ),
      ]),
    ]));
  }

  /// Grabs the “cost_per_day” field from the current boarding service
  /// and returns it as a `double`.
  ///
  /// • Looks up the document in **users‑sp‑boarding** whose `service_id`
  ///   matches `widget.sp_id`.
  /// • If the `food.cost_per_day` field is missing or invalid, returns 0.0.
  ///
  /// Usage (inside any async function in this State class):
  /// ```dart
  /// final double perDay = await _fetchFoodCostPerDay();
  /// ```
  Future<double> _fetchFoodCostPerDay() async {
    try {
      // 1. Find the service document for this sp_id
      final query = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .where('service_id', isEqualTo: widget.sp_id)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return 0.0;

      // 2. Read the nested food map
      final data     = query.docs.first.data();
      final foodMap  = data['food'] as Map<String, dynamic>?;

      if (foodMap == null) return 0.0;

      // 3. Parse and return the price
      return double.tryParse(foodMap['cost_per_day'].toString()) ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching food cost: $e');
      return 0.0;
    }
  }

  void _updateFoodPrice() async {
    final price = await _fetchFoodCostPerDay();   // <-- returns the value
    setState(() {
      FoodCostPerDay = price;                     // your existing variable
    });
  }



  Widget _buildYouAreReady() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      margin: EdgeInsets.only(top: 12), // spacing below shop card
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE272), Color(0xFFFFE272)], // blue (peace) to yellow
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'You are just a few steps away',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<bool> _confirmLastRemoval(String what) async {
    final result = await showDialog<bool>(
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
          'Action required',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: Text(
          'At least one $what is required to book.\n'
              'Do you still want to remove the last $what?',
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
                color: const Color(0xFF00C2CB),
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }


  Widget _dateChip(DateTime d) => GestureDetector(
   // onTap: () => _changeDate(d),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // slightly bigger
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor),
          ),
          child: Text(
            DateFormat('MMM d, yyyy').format(d),
            style: const TextStyle(
              fontSize: 15, // increased from 13
              fontWeight: FontWeight.w500,
              color: accentColor,
            ),
          ),
        ),

      ],
    ),
  );






  /* ---------- booking card ---------- */

  Widget _bookingCard() {
    return StatefulBuilder(builder: (context, setSB) {
      // ────────────────────────────────────────────────────────────────
      // Prepare date & slots
      // ────────────────────────────────────────────────────────────────
      final dateLabel = widget.selectedDate;
      final sortedSlots = List<String>.from(widget.selectedTimeSlots)
        ..sort((a, b) {
          final fmt = DateFormat('h:mm a');
          final ta = fmt.parse(a.split(' – ')[0]);
          final tb = fmt.parse(b.split(' – ')[0]);
          return ta.compareTo(tb);
        });

      // ────────────────────────────────────────────────────────────────
      // Prepare pets (unchanged)
      // ────────────────────────────────────────────────────────────────
      final allPets = List.generate(
        widget.petNames.length,
            (i) => {
          'name': widget.petNames[i],
          'image': (i < widget.petImages.length) ? widget.petImages[i] : null,
        },
      );

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ───────────────────────────
            // SELECTED DATE
            // ───────────────────────────
            _sectionTitle('Selected Date'),
            Chip(
              label: Text(
                DateFormat.yMMMd().format(dateLabel),
                style: TextStyle(color: Color(0xFF00C2CB)),
              ),
              backgroundColor: Color(0xFF00C2CB).withOpacity(.1),
            ),

            const SizedBox(height: 16),

            // ───────────────────────────
            // TIME SLOTS
            // ───────────────────────────
            _sectionTitle('Time Slots'),
            ...sortedSlots.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('• $s', style: TextStyle(fontSize: 14)),
            )),

            const SizedBox(height: 24),

            // ───────────────────────────
            // SELECTED PETS
            // ───────────────────────────
            _sectionTitle('Selected Pets'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: allPets.map((pet) {
                final name = pet['name']!;
                final img  = pet['image'] as String?;
                final idx  = widget.petNames.indexOf(name);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: img != null && img.isNotEmpty
                            ? Image.network(
                          img,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const ColoredBox(
                            color: Colors.grey,
                            child: Icon(Icons.pets, size: 24),
                          ),
                        )
                            : const ColoredBox(
                          color: Colors.grey,
                          child: Icon(Icons.pets, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removePet(idx),
                        child: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }



  /// Shared section title
  Widget _sectionTitle(String text) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.transparent, thickness: 1)),
      ],
    );
  }

  /// A simple vertical list of your pets with removable “×”
  Widget _petList() {
    return Column(
      children: List.generate(widget.petNames.length, (i) {
        final img = (i < widget.petImages.length) ? widget.petImages[i] : null;
        final name = widget.petNames[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              // thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: img != null && img.isNotEmpty
                    ? Image.network(
                  img,
                  width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.grey, child: Icon(Icons.pets, size: 24)),
                )
                    : const ColoredBox(color: Colors.grey, child: Icon(Icons.pets, size: 24)),
              ),
              const SizedBox(width: 12),

              // name
              Expanded(
                child: Text(
                  '$name',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),

              // remove button
              GestureDetector(
                onTap: () => _removePet(i),
                child: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
        );
      }),
    );
  }





  /* ---------- additional services ---------- */

  Widget _additionalServices()=> Container(
      decoration:BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.circular(20),
          boxShadow:[BoxShadow(color:accentColor.withOpacity(.15),
              blurRadius:20,offset:const Offset(0,10))]),
      child:Column(children:[
        _serviceTile(Icons.directions_walk_rounded,'Daily Walking',
            'Regular exercise for your pet',widget.dailyWalkingRequired??false),
        Divider(height:1,color:Colors.grey.shade200),
        Padding(
          padding:const EdgeInsets.all(16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Food Options',style:TextStyle(
                fontSize:16,fontWeight:FontWeight.w600,color:darkColor)),
            const SizedBox(height:12),
            if(widget.foodOption=='provider')
              _foodTile('Provider Food',
                  widget.foodInfo?['Description'] ?? '-',
                  double.tryParse(widget.foodInfo?['cost_per_day']?.toString()??'0')??0),
            if(widget.foodOption=='self')
              _foodTile('Bring Your Own',
                  'Supply your pet\'s regular food',0),
          ]),
        ),
      ]));

  Widget _serviceTile(IconData icon, String title, String subtitle, bool isActive) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? accentColor : Colors.grey,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: isActive,
        onChanged: (_) {}, // You can pass a real handler here if needed
        activeColor: accentColor,
      ),
    );
  }


  Widget _foodTile(String t,String sub,double cost)=> ListTile(
    tileColor:accentColor.withOpacity(.08),
    title:Text(t,style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:Text(sub),
    trailing:Text('₹$cost',style:const TextStyle(fontWeight:FontWeight.bold)),
  );

  /* ---------- cost card ---------- */

  Widget _costCard() => FutureBuilder<_FeesData>(
    future: _feesFuture,
    builder: (_, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      final f = snap.data!;
      _updatedTotalCost = _grandTotal(f);

      // Generate a simple invoice number & date
      final invoiceNo = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final invoiceDate = DateFormat.yMMMd().format(DateTime.now());

      final dateWidget = Text(
        'Date: $invoiceDate',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      );

      return Container(
        margin: const EdgeInsets.all(0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF008585))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    dateWidget
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Line items ──
            _buildItemRow(
              'Boarding ($_slotsSelected Slot(s) × $_petsSelected Pet(s))',
              _boardingCost,
            ),

            if (_mealsCost > 0)
              _buildItemRow(
                'Meals ($_slotsSelected Slot(s) × $_petsSelected Pet(s))',
                _mealsCost,
                infoCallback: _showFoodInfoDialog,
              ),


            if (_walkingCost > 0)
              _buildItemRow(
                'Daily Walks ($_slotsSelected Slot(s) × $_petsSelected Pet(s))',
                _walkingCost,
              ),

            const Divider(height: 32, color: Colors.grey),

            // ── Fees & tax ──
            _buildItemRow('App service fee', f.platform),
            _buildItemRow('GST (18%)', f.gst),

            const Divider(height: 32, color: Colors.grey),

            // ── Total ──
            _buildItemRow(
              'Grand Total',
              _updatedTotalCost,
              isTotal: true,
            ),

            const SizedBox(height: 16),
            Text(
              'Thank you for choosing MyFellowPet!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildItemRow(
      String label,
      double amount, {
        bool isTotal = false,
        VoidCallback? infoCallback,
      }) {
    final textStyle = TextStyle(
      fontSize: isTotal ? 18 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? Color(0xFF008585) : Colors.black87,
    );
    final amountStyle = TextStyle(
      fontSize: isTotal ? 18 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
      color: isTotal ? Color(0xFF008585) : Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(label, style: textStyle)),
                if (infoCallback != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: infoCallback,
                    child: Icon(Icons.info_outline, size: 18, color: Color(0xFF008585)),
                  ),
                ],
              ],
            ),
          ),
          Text('₹${amount.toStringAsFixed(2)}', style: amountStyle),
        ],
      ),
    );
  }



  /* ---------- bottom bar ---------- */

  /// ✨ Drop‑in replacement for your existing `_bottomBar`
  /// – Keeps all logic intact but adds better responsiveness,
  ///   safe‑area support, and polished material styling.
  Widget _bottomBar(BuildContext context) => FutureBuilder<_FeesData>(
    future: _feesFuture,
    builder: (_, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      final fees  = snap.data!;
      final total = _grandTotal(fees);
      final size   = MediaQuery.of(context).size;
      final wide   = size.width > 600; // tablet / desktop

      return SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 20,
            vertical: wide ? 24 : 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// ▸ Total section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Total Amount',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Color(0xFF212121)),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20, // 👈 set your desired font size here
                                fontWeight: FontWeight.bold,
                                color: darkColor,
                              ),
                            ),
                          ),

                        ],
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(width: 15),


              /// ▸ Checkout button (gradient preserved)
              if (_isProcessingPayment)
                Container(
                  width: 160,        // same approximate width as your button
                  height: 48,        // same approximate height
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFF2BCECE), width: 2),
                  ),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFF2BCECE), width: 2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _book,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 44 : 32,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Checkout',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 20,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


            ],
          ),
        ),
      );
    },
  );
  /* ---------- booking flow ---------- */

  Future<void> _book() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Booking'),
        content: Text('Are you sure you want to book now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text('Confirm')),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    setState(() => _isProcessingPayment = true);

    try {
      // 1) compute your live total
      final f = await _feesFuture;
      _updatedTotalCost = _grandTotal(f);

      // 2) build the same costBreakdown map you use in the success handler
      final costBreakdown = {
        'daily_walking_per_day': (widget.dailyWalkingRequired == true
            ? (double.tryParse(widget.walkingFee) ?? 0)
            : 0
        ).toString(),
        'meal_per_day': (widget.foodOption == 'provider'
            ? (double.tryParse(widget.foodInfo?['cost_per_day']?.toString() ?? '0') ?? 0)
            : 0
        ).toString(),
        'per_day_cost': widget.pricePerHour.toString(),
        'platform_fee_plus_gst': (f.platform + f.gst).toString(),
        'total_amount': _grandTotal(f).toString(),
      };

      // 3) write into Firestore exactly as in _handlePaymentSuccess()
      final user = FirebaseAuth.instance.currentUser!;
      final uSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final uData = uSnap.data()!;
      final ref = FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('hourly_service_request_boarding')
          .doc();

      await ref.set({
        'user_id': user.uid,
        'user_name': uData['name'] ?? '',
        'pet_name': widget.petNames,
        'pet_images': widget.petImages,
        'pet_id': widget.petIds,
        'service_id': widget.sp_id,
        'numberOfPets': widget.petIds.length,
        'bookingId': ref.id,
        'walking_service_everyday': widget.dailyWalkingRequired == true ? 'Yes' : 'No',
        'status': 'Confirmed',
        'phone_number': uData['phone_number'] ?? '',
        'email': uData['email'] ?? '',
        'user_location': uData['user_location'],
        'timestamp': FieldValue.serverTimestamp(),
        'cost_breakdown': costBreakdown,
        'shopName': widget.shopName,
        'shop_image': widget.shopImage,
        'selectedDate': widget.selectedDate,
        'selectedTimeSlots': widget.selectedTimeSlots,
        'openTime': widget.openTime,
        'closeTime': widget.closeTime,
        // since you’re bypassing payment, you can leave these blank or null:
        'payment_id': null,
        'order_id': null,
        'razorpay_signature': null,
      });

      // 4) navigate
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) =>
          HourlyConfirmationPage(
            buildOpenHoursWidget: buildOpenHoursWidget(widget.openTime, widget.closeTime, [widget.selectedDate]),
            shopName: widget.shopName,
            shopImage: widget.shopImage,
            selectedDate: widget.selectedDate,
            totalCost: _updatedTotalCost,
            petNames: widget.petNames,
            petImages: widget.petImages,
            openTime: widget.openTime,
            closeTime: widget.closeTime,
            bookingId: ref.id,
            serviceId: widget.serviceId,
            fromSummary: true,
          )
      ));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting booking: $e'))
      );
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }



  Future<Map<String, dynamic>> _createOrder(int amountPaise) async {
    final res = await http.post(
      Uri.parse(_createOrderUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amountPaise,
        'currency': 'INR',
        'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Order API failed: ${res.body}');
    }

    // Return **exactly** what the service gave you – the caller handles the shape.
    return jsonDecode(res.body) as Map<String, dynamic>;
  }



  /* ---------------- rows & chips helpers ---------------- */

  Widget _detailRow(String l,String v)=> Padding(
    padding:const EdgeInsets.symmetric(vertical:8),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Text(l,style:TextStyle(color:Colors.grey.shade600)),
      Text(v,style:const TextStyle(color:darkColor,fontWeight:FontWeight.w500)),
    ]),);

  Widget _costRow(String l,String v,{bool total=false})=> Padding(
    padding:const EdgeInsets.symmetric(vertical:8),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Text(l,style:TextStyle(
          color:total?darkColor:Colors.grey.shade600,
          fontSize: total?18:14,
          fontWeight:total?FontWeight.w600:FontWeight.normal)),
      Text(v,style:TextStyle(
          color:total?darkColor:darkColor,
          fontSize: total?18:14,
          fontWeight:total?FontWeight.w700:FontWeight.w500)),
    ]),);

  /* ─────────────────────── Booking flow ─────────────────────── */



  /* --- Fixed: this now returns Future<void> and never returns a value --- */
  Future<void> _openCheckout(String orderId, int amountPaise) async {
    final user = FirebaseAuth.instance.currentUser;
    if(user==null){
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content:Text('User not logged in.')));
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final d = snap.data()??{};
    final opts = {
      'key':'rzp_test_bVo1FO7Zzowm5T',
      'amount': amountPaise,
      'order_id':orderId,
      'name':widget.shopName,
      'description':'Booking Payment',
      'prefill':{'contact':d['phone_number']??'',
        'email'  :d['email']??''},
      'external':{'wallets':['googlepay']},
    };
    _razorpay.open(opts);
  }

  /* --- Razorpay callbacks --- */

  void _handlePaymentSuccess(PaymentSuccessResponse r) async {

    final openHoursWidget = buildOpenHoursWidget(widget.openTime, widget.closeTime, [widget.selectedDate]);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Payment Successful! ID: ${r.paymentId}')));

    final user = FirebaseAuth.instance.currentUser; if(user==null) return;
    final uSnap = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    final uData = uSnap.data()??{};

    // 1️⃣ Grab the fees (platform & gst)
    final _FeesData f = await _feesFuture;

    // 2️⃣ Build your breakdown map
    final costBreakdown = {
      'daily_walking_per_day': (widget.dailyWalkingRequired == true
          ? (double.tryParse(widget.walkingFee) ?? 0)
          : 0
      ).toString(),
      'meal_per_day': (widget.foodOption == 'provider'
          ? (double.tryParse(widget.foodInfo?['cost_per_day']?.toString() ?? '0') ?? 0)
          : 0
      ).toString(),
      'per_day_cost': widget.pricePerHour.toString(),
      'platform_fee_plus_gst': (f.platform + f.gst).toString(),
      'total_amount': _grandTotal(f).toString(),
    };

    final ref = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('service_request_boarding')
        .doc();

    await ref.set({
      'user_id':user.uid,
      'user_name':uData['name']??'',
      'pet_name':widget.petNames,
      'pet_images':widget.petImages,
      'pet_id':widget.petIds,
      'service_id':widget.sp_id,
      'numberOfPets':widget.petIds.length,
      'bookingId':ref.id,
      'walking_service_everyday':widget.dailyWalkingRequired==true?'Yes':'No',
      'status':'Confirmed',
      'phone_number':uData['phone_number']??'',
      'email':uData['email']??'',
      'user_location':uData['user_location'],
      'timestamp':FieldValue.serverTimestamp(),
      'cost_breakdown': costBreakdown,
      'shopName':widget.shopName,
      'shop_image':widget.shopImage,
      'selectedDate': widget.selectedDate,
      'selectedTimeSlots': widget.selectedTimeSlots,
      'openTime':widget.openTime,
      'closeTime':widget.closeTime,
      'payment_id':r.paymentId,
      'order_id':r.orderId,
      'razorpay_signature':r.signature,
    });

    final invoiceDate = DateFormat.yMMMd().format(DateTime.now());
    final dateWidget = Text(
      'Date: $invoiceDate',
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );

    Navigator.pushReplacement(context,
        MaterialPageRoute(builder:(_)=>HourlyConfirmationPage(
            buildOpenHoursWidget:buildOpenHoursWidget(widget.openTime, widget.closeTime, [widget.selectedDate]),
            shopName:widget.shopName,
            shopImage:widget.shopImage,
            selectedDate:widget.selectedDate,
            totalCost:_updatedTotalCost,
            petNames:widget.petNames,
            petImages:widget.petImages,
            openTime:widget.openTime,
            closeTime:widget.closeTime,
            bookingId:ref.id,
            serviceId: widget.serviceId,
            fromSummary: true

        )));
  }

  void _handlePaymentError(PaymentFailureResponse r) {
    // ── Reset the spinner flag ──
    setState(() => _isProcessingPayment = false);

    // ── Then show the error dialog/snackbar ──
    _alert(
      'Payment Failed',
      'Code: ${r.code}\nDescription: ${r.message}',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse r)=>
      _alert('External Wallet Selected',r.walletName??'');

  void _alert(String t,String m)=> showDialog(
      context:context,
      builder:(_)=>AlertDialog(title:Text(t),content:Text(m)));
}

/* ───────────── Simple data holder for fees ───────────── */

class _FeesData{
  final double platform,gst;
  _FeesData(this.platform,this.gst);
}
