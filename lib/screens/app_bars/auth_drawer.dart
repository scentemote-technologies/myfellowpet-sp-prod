// lib/auth_drawer.dart
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../Colors/AppColor.dart';
import '../../models/General_user.dart';
import '../Boarding/SPChatWidget.dart';

class AuthDrawer extends StatefulWidget {
  const AuthDrawer({super.key});

  @override
  _AuthDrawerState createState() => _AuthDrawerState();
}

class _AuthDrawerState extends State<AuthDrawer> {

  String _errorMessage = '';

  // ✨ FIX 2: Define the missing setter method
  void _setErrorMessage(String message) {
    if (mounted) setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }
  bool _isLoading = false;
  XFile? _pickedFile;
  String? _photoUrl; // The final URL after upload

  Future<void> _storeUserDetails(fb_auth.User user) async {
    final CollectionReference users = FirebaseFirestore.instance.collection('web-users');
    final DocumentReference userRef = users.doc(user.uid);

    await userRef.set({
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoURL': user.photoURL,
      'number': user.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Function to pick the file from the user's device
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      // Use source: ImageSource.gallery or ImageSource.camera
      // For web, ImageSource.gallery allows picking files.
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        setState(() {
          _pickedFile = file;
          _errorMessage = '';
        });
      }
    } catch (e) {
      _setErrorMessage('Error picking image: $e');
    }
  }

// Function to upload the file and get the public URL
  Future<String?> _uploadImage(String uid) async {
    if (_pickedFile == null) return null;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Upload the file bytes (essential for web)
      final bytes = await _pickedFile!.readAsBytes();
      final uploadTask = storageRef.putData(bytes);

      // Get the download URL once the upload is complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _isLoading = false;
        _photoUrl = downloadUrl; // Store the final URL
      });

      return downloadUrl;

    } catch (e) {
      _setErrorMessage('Error uploading image. Try again.');
      debugPrint('Upload Error: $e');
      setState(() {
        _isLoading = false;
      });
      return null;
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // This is the old, simple pop-up method.
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user closed the pop-up.
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print("✅ Google Sign-in successful for user: ${user.uid}");
        await _storeUserDetails(user);
        await Future.delayed(const Duration(milliseconds: 200));
        html.window.location.reload();
      }
    } catch (e) {
      debugPrint("🔥 Google Sign-in failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width.clamp(300.0, 400.0);
    final userNotifier = context.watch<GeneralUserNotifier>();
    final me = userNotifier.me;

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 16,
          child: Container(
            width: drawerWidth,
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: me == null ? _buildLoggedOutView() : _buildProfileView(me),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedOutView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in to your account',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: primaryColor),
        ),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : OutlinedButton.icon(
          onPressed: _signInWithGoogle,
          // Using an asset for the Google logo is a nice touch.
          icon: Image.asset('assets/google_logo.png', height: 20.0, width: 20.0),
          label: const Text('Sign in with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
  Widget _buildProfileView(GeneralAppUser user) {
    // Determine login type
    final bool isPhoneLogin = user.phoneNumber != null && user.phoneNumber!.isNotEmpty
        && (user.email == null || user.email!.isEmpty);

    final bool isEmailLogin = user.email != null && user.email!.isNotEmpty
        && (user.phoneNumber == null || user.phoneNumber!.isEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: primaryColor.withOpacity(0.2),
              foregroundColor: primaryColor,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                user.name?.isNotEmpty == true ? user.name![0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24),
              )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${user.name ?? "Guest"}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isEmailLogin
                        ? user.email!
                        : (isPhoneLogin ? user.phoneNumber! : 'No contact info'),
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          onTap: () => _showEditProfileDialog(user),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          onTap: () async {
            // Sign out of both Google and Firebase for a clean logout.
            await GoogleSignIn().signOut();
            await fb_auth.FirebaseAuth.instance.signOut();
            html.window.location.reload();
          },
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(GeneralAppUser user) async {
    final nameController = TextEditingController(text: user.name ?? '');
    final emailController = TextEditingController(text: user.email ?? '');
    final numberController = TextEditingController(text: user.phoneNumber ?? '');
    final photoController = TextEditingController(text: user.photoUrl ?? '');

    // Determine login type
    final bool isPhoneLogin = user.phoneNumber != null && user.phoneNumber!.isNotEmpty
        && (user.email == null || user.email!.isEmpty);

    final bool isEmailLogin = user.email != null && user.email!.isNotEmpty
        && (user.phoneNumber == null || user.phoneNumber!.isEmpty);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: primaryColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // Name field always editable
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins( color: Colors.black87)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await _updateUserDetails(
                  uid: user.uid!,
                  name: nameController.text.trim(),
                  email: isEmailLogin ? emailController.text.trim() : null,
                  number: isPhoneLogin ? numberController.text.trim() : null,
                  photoUrl: photoController.text.trim(),
                );
                Navigator.of(ctx).pop();
                html.window.location.reload();
              },
              child: Text(
                'Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _updateUserDetails({
    required String uid,
    String? name,
    String? number,
    String? email,
    String? photoUrl,
  }) async {
    final users = FirebaseFirestore.instance.collection('web-users');
    final userRef = users.doc(uid);

    await userRef.set({
      if (name != null && name.isNotEmpty) 'displayName': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (number != null && number.isNotEmpty) 'number': number,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoURL': photoUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

}