import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_enterprise.dart';

// 1️⃣ recaptcha enterprise imports

import '../HomeScreen/HomeScreen.dart';

class UserDetailsPage extends StatefulWidget {
  final String phoneNumber;
  const UserDetailsPage({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  bool _saving = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Make sure you've already called `RecaptchaEnterprise.initClient(...)`
    // in your main.dart with your site key.
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  /// 2️⃣ Invisible reCAPTCHA Enterprise check
  Future<bool> _runRecaptcha() async {
    try {
      final token = await RecaptchaEnterprise.execute(
        // Use whatever action name you registered in GCP
        RecaptchaAction.custom('CREATE_PROFILE'),
        timeout: 10000,
      );
      debugPrint('🔐 reCAPTCHA token: $token');
      return token.isNotEmpty;
    } catch (e) {
      debugPrint('reCAPTCHA failed: $e');
      return false;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // 3️⃣ run invisible recaptcha
    final success = await _runRecaptcha();
    if (!success) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'reCAPTCHA validation failed. Please try again.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    // 4️⃣ on recaptcha success, write to Firestore
    final uid = _auth.currentUser?.uid;
    final data = {
      'uid': uid,
      'name': _nameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'phone_number': widget.phoneNumber,
    };

    try {
      await _firestore.collection('users').doc(uid).set(data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile created!', style: GoogleFonts.poppins())),
      );
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed. Try again.', style: GoogleFonts.poppins())),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF25ADAD);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: teal,
        elevation: 0,
        title: Text('Complete Profile', style: GoogleFonts.poppins(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Almost there!',
                  style: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('We need a few more details to set up your account.',
                  style: GoogleFonts.poppins(color: Colors.grey[600])),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                validator: (v) => v!.contains('@') ? null : 'Enter valid email',
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Submit', style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
