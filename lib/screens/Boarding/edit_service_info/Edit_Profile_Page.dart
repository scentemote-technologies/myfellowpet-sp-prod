// lib/screens/edit_profile_page.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../../Colors/AppColor.dart';
import '../../Partner/email_signin.dart' hide primaryColor;

class EditProfilePage extends StatefulWidget {
  final String serviceId;
  final String currentEmail;
  final String currentPhone;

  const EditProfilePage({
    Key? key,
    required this.serviceId,
    required this.currentEmail,
    required this.currentPhone,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // This file no longer needs http, TextEditingControllers at the top level,
  // or the direct docRef, as they are managed within each function.

  @override
  void dispose() {
    // No controllers to dispose of at this level anymore.
    super.dispose();
  }

  Future<void> _showChangeLoginEmailDialog() async {
    final newEmailController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Login Email', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: newEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(hintText: 'Enter new login email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(newEmailController.text.trim()), child: Text('Continue')),
        ],
      ),
    );

    final newEmail = result;
    if (newEmail == null || newEmail.isEmpty) return;

    // --- IMPROVED ERROR HANDLING ---
    try {
      debugPrint("Step 1: Starting re-authentication...");
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("User cancelled the Google Sign-In prompt.");
        return;
      }

      final googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);
      debugPrint("✅ Step 1: Re-authentication successful.");

    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 Step 1 FAILED: Security check failed. Code: ${e.code}, Message: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Security check failed: ${e.message}')));
      return; // Stop the process
    } catch (e) {
      debugPrint("🔥 Step 1 FAILED: An unexpected error occurred during re-authentication: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected security error occurred.')));
      return; // Stop the process
    }

    try {
      debugPrint("Step 2: Calling the 'changeLoginEmail' Cloud Function...");
      final callable = FirebaseFunctions.instance.httpsCallable('changeLoginEmail');
      await callable.call({'newEmail': newEmail});
      debugPrint("✅ Step 2: Cloud Function call successful.");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login email updated! Please log in again.'), backgroundColor: Colors.green),
      );

      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SignInPage(), // Use 'const' if possible
          ),
        );
      }

    } on FirebaseFunctionsException catch (e) {
      debugPrint("🔥 Step 2 FAILED: Cloud Function returned an error. Code: ${e.code}, Message: ${e.message}");
      // This is where the "internal error" is caught.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.message}')));
    } catch (e) {
      debugPrint("🔥 Step 2 FAILED: An unexpected error occurred while calling the function: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred.')));
    }
  }


  // --- The "Change Notification Email" and "Change Phone" functions are unchanged ---
  // ... (Your existing _showChangeEmailDialog and _showChangePhoneDialog functions go here) ...
  Future<void> _showChangeEmailDialog() async {
    final docRef = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId);

    // 0️⃣ PRE-CHECK: see when they last changed
    final snap = await docRef.get();
    final lastChangedTs = (snap.data()?['EmailLastChanged'] as Timestamp?);
    if (lastChangedTs != null) {
      final daysSince = DateTime.now()
          .difference(lastChangedTs.toDate())
          .inDays;
      if (daysSince < 14) {
        final daysLeft = 14 - daysSince;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('Change Notification Email',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You last changed your email on '
                      '${DateFormat.yMMMd().format(lastChangedTs.toDate())}.',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can change it again in $daysLeft '
                      'day${daysLeft>1?"s":""}.',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 12),
                Text(
                  'If you need to change it immediately, '
                      'please go to Support → Raise a ticket '
                      'or Request a Callback.',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK', style: GoogleFonts.poppins()),
              )
            ],
          ),
        );
        return;
      }
    }

    // ↘️ If we reach here, it’s been ≥14d (or never changed): proceed
    bool requestSent = false, isSending = false;
    String newEmail = '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        if (!requestSent) {
          final ctrl = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('Change Notification Email',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Old Email:',
                    style:
                    GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                Text(widget.currentEmail,
                    style: GoogleFonts.poppins(color: Colors.black54)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter new email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black87)),
              ),
              if (isSending)
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: Text('Please wait…',
                      style: GoogleFonts.poppins(color: Colors.white)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    final val = ctrl.text.trim();
                    if (val.isEmpty) return;
                    newEmail = val;
                    setState(() => isSending = true);

                    final url = Uri.parse(
                        'https://asia-south1-myfellowpet-prod.cloudfunctions.net/emailUpdateService/api/requestEmailChange');
                    final resp = await http.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'serviceId': widget.serviceId,
                        'newEmail': newEmail,
                      }),
                    );
                    setState(() => isSending = false);

                    if (resp.statusCode == 200) {
                      setState(() => requestSent = true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to send links (${resp.statusCode})',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: Text('Next',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
            ],
          );
        }

        // ── Step 2: show verify‐links UI (same as before) ──
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Text('Verify Emails',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: StreamBuilder<DocumentSnapshot>(
              stream: docRef.snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData)
                  return Center(
                      child: CircularProgressIndicator(color: Colors.red));
                final data = snap.data!.data()! as Map<String, dynamic>;
                final ec = data['emailChange'] as Map<String, dynamic>?;

                if (ec == null)
                  return Center(
                      child: CircularProgressIndicator(color: Colors.red));

                final oldOK = ec['oldVerified'] == true;
                final newOK = ec['newVerified'] == true;

                Widget row(String label, bool done) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    done
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.red, strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: GoogleFonts.poppins())),
                  ]),
                );

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification links sent to both emails.\n'
                            'Please click each link to verify.',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      row(data['notification_email'], oldOK),
                      row(newEmail, newOK),
                    ]);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black87)),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: docRef.snapshots(),
              builder: (ctx, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final ec = data?['emailChange'] as Map<String, dynamic>?;
                final bothOK = ec != null &&
                    ec['oldVerified'] == true &&
                    ec['newVerified'] == true;

                return ElevatedButton(
                  onPressed: bothOK
                      ? () async {
                    // finalize
                    final url = Uri.parse(
                        'https://asia-south1-myfellowpet-prod.cloudfunctions.net/emailUpdateService/api/finalizeEmailChange');
                    await http.post(url,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(
                            {'serviceId': widget.serviceId}));
                    // stamp the change time
                    await docRef.update({
                      'EmailLastChanged': FieldValue.serverTimestamp()
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Email updated!',
                              style: GoogleFonts.poppins())),
                    );
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    bothOK ? primaryColor : Colors.grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Update Email',
                      style: GoogleFonts.poppins(color: Colors.white)),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showChangePhoneDialog() async {
    final docRef = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId);

    // 0️⃣ CHECK 14-day restriction
    final snap = await docRef.get();
    final lastChangedTs = snap.data()?['PhoneNumLastChanged'] as Timestamp?;
    if (lastChangedTs != null) {
      final days = DateTime.now().difference(lastChangedTs.toDate()).inDays;
      if (days < 14) {
        final left = 14 - days;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Change Phone Number"),
            content: Text(
              "You changed your phone recently.\n"
                  "You can change it again in $left day${left > 1 ? 's' : ''}.",
              style: GoogleFonts.poppins(),
            ),

          ),
        );
        return;
      }
    }

    // 1️⃣ STATE VARIABLES
    String newPhone = "";
    String otp = "";
    bool sendingOtp = false;
    bool verifyingOtp = false;
    bool verified = false;

    // Determine if test mode or live mode
    Future<String> getSmsFunctionName() async {
      final settingsSnap = await FirebaseFirestore.instance
          .collection("settings")
          .doc("employees")
          .get();
      final data = settingsSnap.data() ?? {};
      final live = data["number_verification"] == true;
      return live ? "sendSms" : "sendTestSms";
    }

    Future<String> getVerifyFunctionName() async {
      final settingsSnap = await FirebaseFirestore.instance
          .collection("settings")
          .doc("employees")
          .get();
      final data = settingsSnap.data() ?? {};
      final live = data["number_verification"] == true;
      return live ? "verifySmsCode" : "verifyTestSmsCode";
    }

    // 2️⃣ SHOW DIALOG
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text("Change Phone Number", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current phone number
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Current: ${widget.currentPhone}",
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                    if (verified)
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 14),
                      )
                  ],
                ),

                const SizedBox(height: 16),

                // New number field
                TextField(
                  enabled: !verified,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "New Phone Number",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => newPhone = v.startsWith("+") ? v : "+91$v",
                ),

                const SizedBox(height: 16),

                if (!verified) ...[
                  // Send OTP Button
                  ElevatedButton(
                    onPressed: sendingOtp
                        ? null
                        : () async {
                      if (newPhone.isEmpty) return;
                      setState(() => sendingOtp = true);

                      final fn = await getSmsFunctionName();
                      final callable = FirebaseFunctions.instance.httpsCallable(fn);

                      try {
                        await callable.call({
                          "phoneNumber": newPhone,
                          "docId": widget.serviceId,
                          "verificationType": "sms",
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("OTP sent!")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("OTP failed: $e")),
                        );
                      }

                      setState(() => sendingOtp = false);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: sendingOtp
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Sending...", style: GoogleFonts.poppins(color: Colors.white)),
                      ],
                    )
                        : Text("Send OTP", style: GoogleFonts.poppins(color: Colors.white)),
                  ),

                  const SizedBox(height: 16),

                  // OTP field
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Enter OTP",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => otp = v,
                  ),

                  const SizedBox(height: 16),

                  // Verify OTP Button
                  ElevatedButton(
                    onPressed: verifyingOtp
                        ? null
                        : () async {
                      if (otp.isEmpty) return;
                      setState(() => verifyingOtp = true);

                      final verifyFn = await getVerifyFunctionName();
                      final callable = FirebaseFunctions.instance.httpsCallable(verifyFn);

                      try {
                        final result = await callable.call({
                          "code": otp,
                          "docId": widget.serviceId,
                        });

                        if (result.data["success"] == true) {
                          await docRef.update({
                            "owner_phone": newPhone,
                            "PhoneNumLastChanged": FieldValue.serverTimestamp(),
                          });

                          setState(() => verified = true);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Phone updated!")),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Verification failed: $e")),
                        );
                      }

                      setState(() => verifyingOtp = false);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: verifyingOtp
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Verifying...", style: GoogleFonts.poppins(color: Colors.white)),
                      ],
                    )
                        : Text("Verify OTP", style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
                  SizedBox(height: 5),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black87)),
                  ),

                if (verified) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Number verified and updated!",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("Done", style: GoogleFonts.poppins()),
                  )
                ]
              ],
            ),
          );
        },
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: Icon(Icons.email, color: primaryColor),
            title: Text('Change Notification Email', style: GoogleFonts.poppins()),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showChangeEmailDialog,
          ),
          Divider(),

          ListTile(
            leading: Icon(Icons.phone, color: primaryColor),
            title: Text('Change Phone Number', style: GoogleFonts.poppins()),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showChangePhoneDialog,
          ),
        ],
      ),
    );
  }
}
