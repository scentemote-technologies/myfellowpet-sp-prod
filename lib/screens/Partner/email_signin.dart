import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show AuthCredential, FirebaseAuth, GoogleAuthProvider, User, UserCredential;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myfellowpet_sp/screens/Partner/profile_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart'; // REQUIRED: For UserNotifier access
import '../../providers/boarding_details_loader.dart';
import '../Boarding/EmployeeSignInPage.dart';
import '../Boarding/boarding_type.dart';
import '../Boarding/partner_shell.dart';
import 'partner_appbar.dart';

// --- REQUIRED IMPORTS FOR NAVIGATION ---
import '../Boarding/roles/role_service.dart'; // UserNotifier, AuthState
// ----------------------------------------


final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

const Color primaryColor = Color(0xFF2CB4B6); // Define the color

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // Firebase instances
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Sign-in state
  bool _isLoading    = false;
  String _errorMessage = '';

  // Other state variables (kept from original code)
  final List<String> _generalStepTitles = [
    "Business Details",
    "Proof & Compliance",
    "Review & Activation"
  ];

  final List<String> _stepSubtitles = [
    "Name, Email & Phone Number",
    "Shop name, CIN & logo",
    "IFSC & Account number",
    "Shop name, CIN & logo",
    "Service Details",
    "Upload Signed Agreement"
  ];
  final List<String> _menuItems = ['Home', 'Products', 'About', 'Contact'];
  bool _noGstCheckbox = false;


  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _uploadedLogoUrl;

  int _selectedIndex = 0;
  int? _hoveredIndex;

  int _currentCarouselIndex = 0;
  final PageController _pageController = PageController();


  @override
  void initState() {
    super.initState();
    // No initialization needed for Google Sign-In
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- NEW REDIRECTOR LOGIC ---
  void _redirectToAuthenticatedUser(BuildContext context, UserNotifier userNotifier) {

    // Safety check: ensure user is logged in and state has been resolved
    if (userNotifier.authState == AuthState.loading ||
        userNotifier.authState == AuthState.initializing) {
      // Should not happen, but safe to ignore if still loading
      return;
    }

    final authState = userNotifier.authState;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (authState == AuthState.onboardingNeeded && currentUser != null) {
      // Navigate to /business-type
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => RunTypeSelectionPage(
            fromOtherbranches: false,
            uid: currentUser.uid,
            phone: currentUser.phoneNumber ?? '',
            email: currentUser.email ?? '',
            serviceId: null,
          ),
        ),
            (route) => false,
      );
      return;
    }

    if (authState == AuthState.profileSelectionNeeded) {
      // Navigate to /profile-selection
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => const ProfileSelectionScreen(),
        ),
            (route) => false,
      );
      return;
    }

    // If authenticated AND we have a serviceId, go directly to the profile
    if (authState == AuthState.authenticated && userNotifier.me?.serviceId != null) {
      final serviceId = userNotifier.me!.serviceId!;
      // Navigate to /partner/:serviceId/profile
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => PartnerShell(
            serviceId: serviceId,
            currentPage: PartnerPage.profile,
            child: BoardingDetailsLoader(serviceId: serviceId),
          ),
        ),
            (route) => false,
      );
      return;
    }

    // Fallback: If logged in but somehow missed the checks (e.g., waiting for profile data),
    // redirect to the Profile Selection screen as the safe hub.
    if (currentUser != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => const ProfileSelectionScreen(),
        ),
            (route) => false,
      );
    }
  }
  // -----------------------------


  // In _SignInPageState
  Future<void> _signInWithGoogle() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in with Firebase
        await _auth.signInWithCredential(credential);
        print("✅ Google Sign-in successful. UserNotifier will now take over.");

        // --- NEW: Force profile refresh and redirect ---
        // Access the UserNotifier instance
        if (mounted) {
          final userNotifier = Provider.of<UserNotifier>(context, listen: false);

          // Wait for the user profile to be fetched and auth state to be finalized
          await userNotifier.refreshUserProfile();

          if (mounted) {
            _redirectToAuthenticatedUser(context, userNotifier);
          }
        }
        // ----------------------------------------------
      }
    } catch (e) {
      print("🔥 Google Sign-in failed: $e");

      final error = e.toString();

      if (error.contains("popup_closed")) {
        // ✅ Ignore when user closes the popup manually
        print("ℹ️ Google sign-in popup was closed by the user.");
      } else {
        // ✅ Show friendly message instead of raw error
        setState(() {
          _errorMessage = "Sign-in failed. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Widget _buildLoginCard() {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              } else if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                );
              } else {
                final imageUrl = snapshot.data!['main_image'];
                return Container(
                  height: 200,
                  // Assuming imageUrl is String
                  child: Image.network(
                    imageUrl as String,
                    fit: BoxFit.contain,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
              children: const <TextSpan>[
                TextSpan(text: 'Sign in to '),
                TextSpan(
                  text: 'Login/Register',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Google Sign-In button
          OutlinedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: const BorderSide(color: primaryColor, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: GoogleFonts.poppins(fontSize: 16),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/google_logo.png', height: 24.0),
                const SizedBox(width: 8.0),
                const Text('Sign in with Google'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_errorMessage.isNotEmpty)
            Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.red,
              ),
            ),

          const SizedBox(height: 16),



          const SizedBox(height: 16),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('company_documents')
                .doc('footer')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final phoneNumber = data?['phone_number'] ?? '';

              if (phoneNumber.isEmpty) {
                return const SizedBox();
              }

              return Align(
                alignment: Alignment.centerRight,
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Contact Us ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: phoneNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget buildFooterLinks() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('company_documents')
          .doc('footer')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }

        final data = snapshot.data!;
        final termsUrl = data['terms_of_use'];
        final privacyUrl = data['privacy_policy'];
        final cancelUrl = data['cancellation_refund'];

        return Padding(
          padding: const EdgeInsets.only(top: 32.0, bottom: 16),
          child: Column(
            children: [
              Text(
                'By continuing, you agree to our',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  _buildFooterLink('Terms of Use', termsUrl as String),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  _buildFooterLink('Privacy Policy', privacyUrl as String),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  _buildFooterLink('Cancellation & Refund', cancelUrl as String),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildFooterLink(String label, String url) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      },
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.grey.shade700,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: PartnerAppbar(scaffoldKey: _scaffoldKey),
      // Assuming buildMobileDrawer is defined in PartnerAppbar or accessible globally
      drawer: PartnerAppbar.buildMobileDrawer(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 50),
          child: Center(
            child: Column(
              children: [
                _buildLoginCard(),
                buildFooterLinks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}