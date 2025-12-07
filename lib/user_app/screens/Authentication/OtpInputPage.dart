import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../homescreen/HomeScreen.dart';
import 'FirstTimeUserLoginDeyts.dart';

class OtpInputPage extends StatefulWidget {
  final String initialVerificationId;
  final String phoneNumber;
  final bool phoneExists;

  const OtpInputPage({
    required this.initialVerificationId,
    required this.phoneNumber,
    required this.phoneExists,
  });

  @override
  _OtpInputPageState createState() => _OtpInputPageState();
}

class _OtpInputPageState extends State<OtpInputPage> {
  late String _verificationId;
  final _pinController = TextEditingController();
  bool _verifying = false;
  Timer? _timer;
  int _secondsLeft = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.initialVerificationId;
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        setState(() => _canResend = true);
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verifyPin(String code) async {
    setState(() => _verifying = true);

    print('🔐 Verifying OTP code: $code');
    print('📞 Phone number: ${widget.phoneNumber}');

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(cred);
      print('✅ OTP verified, user signed in: ${userCredential.user?.uid}');

      // 🔍 Now check if user document exists in Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_number', isEqualTo: widget.phoneNumber)
          .get();

      print('🔎 Firestore returned ${snapshot.docs.length} documents');
      if (snapshot.docs.isNotEmpty) {
        print('✅ User document FOUND in Firestore. Navigating to HomeScreen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        print('🆕 No existing user document. Navigating to UserDetailsPage...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsPage(phoneNumber: widget.phoneNumber),
          ),
        );
      }
    } catch (e) {
      print('❌ Error during OTP verification or Firestore check: $e');
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid code or something went wrong. Please try again.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  void _resendCode() {
    print('🔄 Resending code to ${widget.phoneNumber}');
    _startTimer();
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (_) {
        print('✅ Auto verification completed');
      },
      verificationFailed: (e) {
        print('❌ Resend verification failed: ${e.message}');
      },
      codeSent: (newVid, _) {
        print('📩 Code resent, new verification ID received');
        setState(() => _verificationId = newVid);
      },
      codeAutoRetrievalTimeout: (_) {
        print('⏳ Auto-retrieval timed out');
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Verify OTP',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Text(
                  'A 6-digit code was sent to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                SizedBox(height: 24),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _pinController,
                  enablePinAutofill: true,
                  useExternalAutoFillGroup: true,
                  animationType: AnimationType.fade,
                  keyboardType: TextInputType.number,
                  autoFocus: true,
                  onChanged: (_) {},
                  onCompleted: _verifyPin,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    fieldHeight: 50,
                    fieldWidth: 45,
                    borderRadius: BorderRadius.circular(8),
                    activeColor: Color(0xFF25ADAD),
                    selectedColor: Color(0xFF25ADAD),
                    inactiveColor: Colors.grey.shade400,
                    activeFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                if (_verifying)
                  CircularProgressIndicator(
                    color: Color(0xFF25ADAD),
                    strokeWidth: 3,
                  )
                else if (_canResend)
                  TextButton(
                    onPressed: _resendCode,
                    child: Text(
                      'Resend Code',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF25ADAD),
                      ),
                    ),
                  )
                else
                  Text(
                    'Resend available in $_secondsLeft s',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
