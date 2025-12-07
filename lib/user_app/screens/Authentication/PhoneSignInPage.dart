import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../HomeScreen/HomeScreen.dart';
import 'FirstTimeUserLoginDeyts.dart';
import 'OtpInputPage.dart';

class PhoneAuthPage extends StatefulWidget {
  @override
  _PhoneAuthPageState createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final _phoneController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _loading = false;
  bool _phoneExists = false;

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))
        ],
      ),
    );
  }

  void _goNext() {
    if (_phoneExists) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserDetailsPage(phoneNumber: '+91${_phoneController.text.trim()}'),
        ),
      );
    }
  }

  Future<void> _checkAndSend() async {
    final phone = '+91' + _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 13) {
      _showError('Please enter a valid phone number.');
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          await _auth.signInWithCredential(cred);
          if (!mounted) return;

          // ✅ Move to OTP page to check Firestore later
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpInputPage(
                initialVerificationId: '',
                phoneNumber: phone,
                phoneExists: false, // doesn't matter now
              ),
            ),
          );
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _loading = false);
          _showError(e.message ?? 'OTP send failed');
        },
        codeSent: (vid, _) async {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpInputPage(
                initialVerificationId: vid,
                phoneNumber: phone,
                phoneExists: false, // doesn't matter now
              ),
            ),
          );
          setState(() => _loading = false);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _showError('Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA), // Light blue background for a fresh look
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                // ─── Input Card with Gradient ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Lets get Started!",
                        style: GoogleFonts.poppins( // Using a modern font like Poppins
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF25ADAD),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Enter your mobile number to get started.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 40),
                      // ─── IMPROVED TEXT FIELD ──────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 20, right: 8),
                              child: Text(
                                '+91',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: '9876543210',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                                  border: InputBorder.none, // Remove the default border
                                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ───────────────────────────────────────────────────
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _checkAndSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF25ADAD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: Color(0xFF25ADAD).withOpacity(0.4),
                          ),
                          child: _loading
                              ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : Text(
                            'Send Verification Code',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'MyFellowPet',
                  style: GoogleFonts.pacifico(
                    fontSize: 32,
                    color: Colors.grey.shade700,
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