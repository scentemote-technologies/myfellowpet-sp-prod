// lib/screens/EmployeeSignInPage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';

import '../../Colors/AppColor.dart';
import '../../providers/boarding_details_loader.dart'; // Import Google Sign-In


class EmployeeSignInPage extends StatefulWidget {
  const EmployeeSignInPage({Key? key}) : super(key: key);

  @override
  _EmployeeSignInPageState createState() => _EmployeeSignInPageState();
}

class _EmployeeSignInPageState extends State<EmployeeSignInPage> {
  bool _loading = false;

  /// Handles the entire Google Sign-In flow.
  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    debugPrint('🔑 Starting Google Sign-In flow...');

    try {
      // 1. Trigger the Google Authentication flow.
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // If the user cancels the process, googleUser will be null.
      if (googleUser == null) {
        debugPrint('❌ Google Sign-In cancelled by user.');
        setState(() => _loading = false);
        return;
      }

      // 2. Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential for Firebase.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential.
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception("Sign-in successful, but no user object was returned.");
      }
      debugPrint('✅ Firebase auth succeeded, uid=${user.uid}');

      // 5. Get the serviceId from the user's custom claims.
      // This is much more efficient than looking it up in Firestore.
      final idTokenResult = await user.getIdTokenResult(true); // Force refresh
      final claims = idTokenResult.claims;
      final String? serviceId = claims?['serviceId'];

      if (serviceId == null || serviceId.isEmpty) {
        throw Exception("No serviceId assigned to this employee. Please contact your administrator.");
      }
      debugPrint('✅ Found serviceId in custom claims: $serviceId');

      // 6. Navigate to the employee's dashboard.
      if (mounted) {
        // 🚀 Replacing context.go('/partner/$serviceId/profile')
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PartnerShell(
              serviceId: serviceId, // Assuming 'serviceId' is available in the current scope
              currentPage: PartnerPage.profile, // Use the specific enum for the Profile page
              child: BoardingDetailsLoader(serviceId: serviceId), // The target widget for the profile view
            ),
          ),
              (Route<dynamic> route) => false, // Clears the entire history below this route
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 Firebase Auth Exception: ${e.message}');
      _showErrorDialog('Sign-In Failed', e.message ?? 'An unknown authentication error occurred.');
    } catch (e) {
      debugPrint('🔥 A general error occurred: $e');
      _showErrorDialog('Error', e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Helper function to show a consistent error dialog.
  Future<void> _showErrorDialog(String title, String content) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // We no longer need dispose() as there are no controllers.

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Employee Portal', style: GoogleFonts.poppins()),
        backgroundColor: primaryColor,
      ),
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // This part for displaying the logo remains the same.
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('company_documents')
                    .doc('general_info')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox(
                      height: 180,
                      child: Center(child: Icon(Icons.business, size: 48, color: Colors.grey)),
                    );
                  }
                  final imageUrl = snapshot.data!.get('main_image');
                  return SizedBox(
                    height: 200,
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, please sign in to continue.', // Updated text
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // The email and password fields are replaced by this single button.
              ElevatedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 1,
                  shadowColor: Colors.transparent,
                ),
                icon: _loading
                    ? Container() // Hide icon when loading
                    : Image.asset('assets/google_logo.png', height: 24.0), // Note: Add a Google logo to your assets
                label: _loading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3, color: primaryColor),
                )
                    : Text(
                  'Sign in with Google',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}