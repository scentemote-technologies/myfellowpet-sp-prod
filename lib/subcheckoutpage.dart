import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubscriptionCheckoutPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String serviceId;
  final String planId;

  const SubscriptionCheckoutPage({
    super.key,
    required this.plan,
    required this.planId, required this.serviceId,
  });

  @override
  State<SubscriptionCheckoutPage> createState() =>
      _SubscriptionCheckoutPageState();
}

class _SubscriptionCheckoutPageState extends State<SubscriptionCheckoutPage> {
  late Razorpay _razorpay;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(
        Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(
        Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ---------------- DATE LOGIC ----------------
  DateTime calculateEndDate(DateTime start, int monthsToAdd) {
    int year = start.year;
    int month = start.month + monthsToAdd;
    while (month > 12) {
      year++;
      month -= 12;
    }
    int lastDay = DateTime(year, month + 1, 0).day;
    int day = start.day > lastDay ? lastDay : start.day;
    return DateTime(year, month, day);
  }

  // ---------------- ORDER API ----------------
  Future<Map<String, dynamic>> _createOrder(
      int amountPaise, String url) async {
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amountPaise,
        'currency': 'INR',
        'receipt': 'sub_${DateTime.now().millisecondsSinceEpoch}',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Order creation failed");
    }
    return jsonDecode(res.body);
  }

  // ---------------- PAYMENT ----------------
  void _startPayment() async {
    setState(() => _isProcessing = true);

    try {
      const String orderUrl =
          "https://us-central1-myfellowpet-prod.cloudfunctions.net/createRazorpayOrder/createOrder";

      // ✅ Parse & validate price safely
      final double price =
          double.tryParse(widget.plan['price'].toString()) ?? 0;
      final int amountPaise = (price * 100).toInt();

      if (amountPaise <= 0) {
        throw Exception("Invalid price amount");
      }

      // ✅ Create order via backend (secrets live there)
      final response = await _createOrder(amountPaise, orderUrl);

      if (response['success'] != true) {
        throw Exception("Order creation failed");
      }

      final String orderId = response['order']['id'];
      final String razorpayKey = response['keyId']; // 👈 FROM SECRET MANAGER

      final user = FirebaseAuth.instance.currentUser;

      // ✅ Open Razorpay Checkout
      _razorpay.open({
        'key': razorpayKey,
        'amount': amountPaise,
        'order_id': orderId,
        'name': 'MyFellowPet',
        'description': 'Subscription: ${widget.plan['planName']}',
        'image':
        'https://firebasestorage.googleapis.com/v0/b/myfellowpet-prod.firebasestorage.app/o/mfp_logo%2Fweb_app_logo.png?alt=media',
        'prefill': {
          'contact': user?.phoneNumber ?? '',
          'email': user?.email ?? '',
        },
        'readonly': {
          'contact': true,
          'email': true,
        },
        'theme': {
          'color': '#00C2CB',
        },
        'notes': {
          'serviceId': widget.serviceId,
          'planId': widget.planId,
        },
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment error: $e")),
      );
    }
  }


  // ---------------- SUCCESS ----------------
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final res = await http.post(
        Uri.parse(
          "https://us-central1-myfellowpet-prod.cloudfunctions.net/verifyRazorpayPayment",
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentId': response.paymentId,
          'orderId': response.orderId,
          'signature': response.signature,
          'serviceId': widget.serviceId,
          'planId': widget.planId,
          'plan': {
            'planName': widget.plan['planName'],
            'price': widget.plan['price'],
            'durationMonths': widget.plan['durationMonths'],
          },
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode != 200 || body['success'] != true) {
        throw Exception("Payment verification failed");
      }

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subscription Activated")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Payment received but verification failed. Please contact support.",
          ),
        ),
      );
    }
  }


  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed")),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Checkout",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(0.05),
          ),
        ),
      ),

      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _planCard(),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _paymentCard(),
                    ),
                  ],
                ),

              ),
            ),
          ),
          if (_isProcessing) const _ProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _planCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Plan Summary",
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _row("Plan", widget.plan['planName']),
          _row("Duration",
              "${widget.plan['durationMonths']} Month(s)"),
          _row("Price", "₹${widget.plan['price']}",
              highlight: true),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Payment",
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Text(
            "You’ll be redirected to Razorpay’s secure checkout.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Pay Securely",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "🔒 Secure payment powered by Razorpay",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _row(String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.teal : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- PROCESSING OVERLAY ----------------
class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 20),
              Text(
                "Preparing secure payment…",
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                "Please don’t refresh or close this page.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
