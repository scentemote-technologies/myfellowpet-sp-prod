import 'dart:html' as html;
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Keep alias for clarity in copied methods
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../Colors/AppColor.dart'; // Assuming primaryColor is defined here
import '../../models/General_user.dart';
// Import PhoneAuthDialog from mainhomescreen.dart (adjust path if needed)
import '../HomePage/mainhomescreen.dart' show PhoneAuthDialog;

// --- Callbacks & Constants ---
typedef OnMenuSelect = void Function(int index);
typedef OnHoverChange = void Function(int? index);

// --- The Final AppBar ---
class HomePageAppBar extends StatefulWidget implements PreferredSizeWidget {
  final List<String> menuItems;
  final int selectedIndex;
  final int? hoveredIndex;
  final OnMenuSelect onMenuSelect;
  final OnHoverChange onHover;
  final VoidCallback onPartnerTap;

  const HomePageAppBar({
    Key? key,
    required this.menuItems,
    required this.selectedIndex,
    this.hoveredIndex,
    required this.onMenuSelect,
    required this.onHover,
    required this.onPartnerTap,
  }) : super(key: key);

  @override
  _HomePageAppBarState createState() => _HomePageAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

class _HomePageAppBarState extends State<HomePageAppBar> {
  bool _isLoadingGoogleSignIn = false; // State variable for loading indicator

  // --- Methods copied/adapted from AuthDrawer ---

  Future<void> _storeUserDetails(fb_auth.User user) async {
    final CollectionReference users =
    FirebaseFirestore.instance.collection('web-users');
    final DocumentReference userRef = users.doc(user.uid);

    // Use specific types for clarity
    final Map<String, dynamic> userData = {
      'uid': user.uid,
      'displayName': user.displayName,
      'number': "",
      'email': user.email,
      'photoURL': user.photoURL,
      'lastLogin': FieldValue.serverTimestamp(),
    };
    await userRef.set(userData, SetOptions(merge: true));
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    // Check for mounted state before accessing context or setting state
    if (!mounted) return;

    setState(() => _isLoadingGoogleSignIn = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoadingGoogleSignIn = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final fb_auth.AuthCredential credential =
      fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print("✅ Google Sign-in successful for user: ${user.uid}");
        await _storeUserDetails(user);
        // Short delay before reload can sometimes help ensure state updates
        await Future.delayed(const Duration(milliseconds: 200));
        // Check mounted again before reload
        if (mounted) {
          html.window.location.reload();
        }
      } else {
        // Handle case where sign-in succeeded but user object is null (rare)
        if (mounted) {
          _showSignInError('Sign-in completed but user data is unavailable.');
          setState(() => _isLoadingGoogleSignIn = false);
        }
      }
    } catch (e) {
      debugPrint("🔥 Google Sign-in failed: $e");
      if (mounted) {
        // Provide a more user-friendly error
        _showSignInError('Sign-in failed. Please try again.');
        setState(() => _isLoadingGoogleSignIn = false);
      }
    }
    // No finally block needed for setState as it's handled in catch/success paths
  }

  // Helper to show snackbar safely
  void _showSignInError(String message) {
    // Use maybeOf to safely check if ScaffoldMessenger exists in the context
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      // Fallback if no ScaffoldMessenger is found (less likely in normal apps)
      print("Error showing SnackBar: ScaffoldMessenger not found.");
    }
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 950;

    return Material(
      elevation: 1.0,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        color: Colors.white,
        height: widget.preferredSize.height, // Access via widget
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            _buildLogo(),
            if (isDesktop) const Spacer(),
            // Pass properties via widget.variableName
            if (isDesktop) _buildMenuItems(widget.menuItems, widget.selectedIndex, widget.hoveredIndex, widget.onMenuSelect, widget.onHover),
            const Spacer(),
            _buildActions(context, isDesktop),
          ],
        ),
      ),
    );
  }

  // --- Helper Build Methods ---

  Widget _buildLogo() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          html.window.location.reload();
        },
        child: Image.asset(
          'assets/myfellowpet_web_logo.jpg',
          height: 50,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildMenuItems(
      List<String> menuItems,
      int selectedIndex,
      int? hoveredIndex,
      OnMenuSelect onMenuSelect,
      OnHoverChange onHover,
      ) {
    return Row(
      children: List.generate(menuItems.length, (index) {
        final item = menuItems[index];
        final bool isSelected = selectedIndex == index;
        final bool isHovered = hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) => onHover(index),
          onExit: (_) => onHover(null),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onMenuSelect(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? primaryColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 2.5,
                    width: isSelected || isHovered ? 25 : 0,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActions(BuildContext context, bool isDesktop) {
    // Watch for auth changes using Provider
    final GeneralAppUser? me = context.watch<GeneralUserNotifier>().me;

    return Row(
      children: [
        if (isDesktop) ...[
          _buildStoreLogo('assets/AppStoreLogo.png',
                  () => showStoreComingSoonDialog(context, 'App Store')),
          const SizedBox(width: 12),
          _buildStoreLogo('assets/GooglePlayLogo.png',
                  () => showStoreComingSoonDialog(context, 'Google Play')),
          const SizedBox(width: 24),
          _buildPartnerButton(widget.onPartnerTap), // Pass callback
          const SizedBox(width: 16),
        ],
        // Conditionally build based on login state
        me == null
            ? _buildLoggedOutButtons(context, isDesktop)
            : _buildLoggedInWidget(context, me, isDesktop),
      ],
    );
  }

  Widget _buildPartnerButton(VoidCallback onPartnerTap) { // Accept callback
    // No need to check user here, the parent decides when to show this
    return ElevatedButton(
      onPressed: onPartnerTap, // Use the passed callback
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle:
        GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      child: const Text("Partner with us"),
    );
  }

  Widget _buildLoggedOutButtons(BuildContext context, bool isDesktop) {
    final Icon iconWidget = isDesktop
        ? const Icon(Icons.account_circle_outlined,
        color: Colors.black54, size: 30)
        : const Icon(Icons.account_circle_outlined,
        color: Colors.black, size: 35);

    return PopupMenuButton<String>(
      tooltip: 'Sign In / Register',
      icon: iconWidget,
      onSelected: (String result) {
        if (result == 'google') {
          // Prevent multiple clicks while loading
          if (!_isLoadingGoogleSignIn) {
            _signInWithGoogle(context);
          }
        } else if (result == 'phone') {
          showDialog(
            context: context,
            builder: (context) => const PhoneAuthDialog(),
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'google',
          enabled: !_isLoadingGoogleSignIn, // Disable while loading
          child: ListTile(
            leading: _isLoadingGoogleSignIn
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Image.asset('assets/google_logo.png',
                height: 22.0, width: 22.0),
            title: Text('Sign in with Google',
                style: GoogleFonts.poppins(fontSize: 15)),
          ),
        ),
        PopupMenuItem<String>(
          value: 'phone',
          // Assuming phone sign-in doesn't have its own loading indicator here
          enabled: !_isLoadingGoogleSignIn,
          child: ListTile(
            leading: const Icon(Icons.phone_outlined, color: primaryColor), // Use primaryColor
            title: Text('Sign in with Phone',
                style: GoogleFonts.poppins(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedInWidget(
      BuildContext context, GeneralAppUser user, bool isDesktop) {
    String initials =
    user.name?.isNotEmpty == true ? user.name![0].toUpperCase() : 'U';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Scaffold.of(context).openEndDrawer(),
        child: Row(
          children: [
            if (isDesktop)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Hi, ${user.name ?? 'Guest'}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis, // Prevent overflow
                  maxLines: 1,
                ),
              ),
            CircleAvatar(
              radius: isDesktop ? 20 : 22, // Slightly different radius maybe?
              backgroundColor: primaryColor.withOpacity(0.2),
              foregroundColor: primaryColor,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!) as ImageProvider
                  : null,
              child: user.photoUrl == null
                  ? Text(
                initials,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreLogo(String assetPath, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Image.asset(assetPath, height: 40),
      ),
    );
  }

  // --- Utility Methods --- (Like showStoreComingSoonDialog) ---

  // Keep the showStoreComingSoonDialog method here or move it to a shared utils file
  Future<void> showStoreComingSoonDialog(
      BuildContext context, String storeName) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) {
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 45),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 65,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.8),
                                primaryColor
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                          child: Column(
                            children: [
                              Text(
                                'Launching Soon!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: Colors.black54,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Our app on '),
                                    TextSpan(
                                      text: storeName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87),
                                    ),
                                    const TextSpan(
                                        text:
                                        ' is getting its final polish.\nStay tuned!'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text(
                                    'Got It!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: primaryColor,
                        child: Icon(
                          Icons.rocket_launch_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} // End of _HomePageAppBarState