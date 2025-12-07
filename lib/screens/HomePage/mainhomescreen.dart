import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:math';
import 'dart:ui';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Colors/AppColor.dart';
import '../../Colors/AppColor.dart' as AppColors;
import '../../models/General_user.dart';
import '../../user_app/screens/Boarding/boarding_servicedetailspage.dart';
import '../Boarding/preloaders/BoardingCardsForBoardingHomePage.dart';
import '../Boarding/preloaders/distance_provider.dart';
import '../Boarding/preloaders/favorites_provider.dart';
import '../Boarding/preloaders/hidden_services_provider.dart';
import '../Footer/footercompanypage.dart';
import '../app_bars/auth_drawer.dart';
import '../app_bars/main_home_screen_app_bar.dart';

const Color kPrimary = Color(0xFF2CB4B6);


Future<Map<String, dynamic>> fetchRatingStats(String serviceId) async {
  final coll = FirebaseFirestore.instance
      .collection('public_review')
      .doc('service_providers')
      .collection('sps')
      .doc(serviceId)
      .collection('reviews');

  final snap = await coll.get();
  // Extract only ratings > 0
  final ratings = snap.docs
      .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
      .where((r) => r > 0)
      .toList();

  final count = ratings.length;
  final avg = count > 0
      ? ratings.reduce((a, b) => a + b) / count
      : 0.0;

  return {
    'avg': avg.clamp(0.0, 5.0),
    'count': count,
  };
}

/// In your SPChatPage State:
double scale = 1.0;
final runStripHeight = 24 * scale;

Gradient _runTypeGradient(String type) {
  switch (type) {
    case 'Home Run':
      return LinearGradient(
        colors: [
          const Color(0xFF556B2F),
          const Color(0xFFBADE7D),
        ],
      );
    case 'Business Run':
      return LinearGradient(
        colors: [
          const Color(0xFF4682B4),
          const Color(0xFF7EB6E5),
        ],
      );
    case 'NGO Run':
      return LinearGradient(
        colors: [
          const Color(0xFFFF5252),
          const Color(0xFFFF8A80),
        ],
      );
    case 'Govt Run':
      return LinearGradient(
        colors: [
          const Color(0xFFB0BEC5),
          const Color(0xFF90A4AE),
        ],
      );
    case 'Vet Run':
      return LinearGradient(
        colors: [
          const Color(0xFFCE93D8).withOpacity(0.85),
          const Color(0xFFBA68C8).withOpacity(0.85),
        ],
      );
    default:
      return LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]);
  }
}


String _runTypeLabel(String type) {
  switch (type) {
    case 'Home Run':      return 'Home Run';
    case 'Business Run':  return 'Business';
    case 'NGO Run':       return 'NGO';
    case 'Govt Run':      return 'Govt Run';
    case 'Vet Run':       return 'Vet Run';
    default:               return type;
  }
}


class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {

  final Map<String, int> _serviceMaxAllowed = {};
  final String myCurrentServiceId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Set<String> _selectedPetTypes = {};
  String _selectedDistanceOption = ''; // New distance filter selection
  bool isLiked = false;
  Set<String> likedServiceIds = {};
  Map<String, Map<DateTime, int>> _allBookingCounts = {};
  int _filterPetCount = 0;
  List<DateTime> _filterDates = [];
  bool _showAllMobileCards = false; // ← Add this as a state variable in your StatefulWidget




  final List<String> sliderImages = [
    'assets/pet1.png',
    'assets/pet.jpg',
    'assets/pet.jpg',
    'assets/pet.jpg',
    'assets/pet.jpg',
  ];

  final List<String> sliderImagesMobile = [
    'assets/pet2.png',
    'assets/pet2.png',
    'assets/pet2.png',
    'assets/pet2.png',
    'assets/pet2.png',
  ];

  RangeValues _selectedPriceRange = const RangeValues(0, 1000);




  final List<Map<String, String>> cards = [
    {'image': 'assets/mainpageimg.jpg', 'title': 'Daycare Boarding'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'Overnight Boarding'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'Grooming'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'Vet Care'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'Pet Store'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'Pet Walking'},
    {'image': 'assets/mainpageimg.jpg', 'title': 'MFP Hub'},
  ];

  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentSlide = 0;
  bool _showAll = false; // Add this as a class variable at the top

  bool _showFavoritesOnly = false;


  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  Future<void> showStoreComingSoonDialog(BuildContext context, String storeName) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: Text(
            'Stay Tuned',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Our app on the '),
                  TextSpan(
                    text: storeName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' is Coming Soon!\n\n'),
                  const TextSpan(text: 'We’re putting the finishing touches on a seamless experience for you.'),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.only(bottom: 12),
          actions: [
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the navigation drawer for mobile and tablet screens.
  /// Builds the navigation drawer for mobile and tablet screens.
  Widget _buildNavigationDrawer(BuildContext context) {
    const double storeLogoHeight = 40;
    const double menuSpacing = 16;
    final me = Provider.of<GeneralUserNotifier>(context).me;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: kPrimary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/mfplogo.jpg',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'MyFellowPet',
                  style: GoogleFonts.poppins(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.handshake, color: kPrimary),
            title: Text('Partner with us', style: GoogleFonts.poppins(fontSize: 16)),
            onTap: () => context.go('/partner-with-us'),
          ),
          const Spacer(),
          // This is the dynamic part: show Logout only if user is logged in
          if (me != null)
            ListTile(
              leading: const Icon(Icons.logout, color: kPrimary),
              title: Text('Logout', style: GoogleFonts.poppins(fontSize: 16)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => showStoreComingSoonDialog(context, 'App Store'),
                  child: Image.asset('assets/AppStoreLogo.png', height: storeLogoHeight),
                ),
                const SizedBox(width: menuSpacing),
                GestureDetector(
                  onTap: () => showStoreComingSoonDialog(context, 'Google Play'),
                  child: Image.asset('assets/GooglePlayLogo.png', height: storeLogoHeight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
      ),
    );

    final w = MediaQuery.of(context).size.width;

    const minW = 400.0;
    const maxW = 600.0;
    const mobileBreakpoint = 900.0; // Breakpoint for switching to drawer menu
    final t = ((w - minW) / (maxW - minW)).clamp(0.0, 1.0);
    double lerp(double a, double b) => a + (b - a) * t;

    // sizes
    final logoSize   = lerp(40, 60);
    final fontSize   = lerp(14, 18);
    final iconSize   = lerp(20, 32);
    final partnerH   = lerp(36, 44);
    final partnerPad = lerp(12, 20);
    final menuSpacing = lerp(16, 32);
    return Scaffold(
      backgroundColor: const Color(0xFFffffff),

      // Use a standard AppBar for smaller screens, and the custom one for larger screens.
      appBar: w < mobileBreakpoint
          ? AppBar(
        iconTheme: const IconThemeData(color: kPrimary),
        backgroundColor: Colors.white,
        title: GestureDetector(
            onTap: () {
              html.window.location.reload();
            },
            child: Image.asset(
                'assets/myfellowpet_web_logo.jpg',
                fit: BoxFit.fitHeight,
                height: kToolbarHeight,
                ),
            ),
        scrolledUnderElevation: 0.0, // <-- Add this line to prevent the shadow on scroll
        actions: [
          // Add this condition here
          if (w >= 600)
            ElevatedButton(
              onPressed: () => context.go('/partner-with-us'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: const StadiumBorder(),
                side: BorderSide(color: kPrimary, width: 2),
                elevation: 0,
              ),
              child: Text(
                'Partner with us',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          // Inside your AppBar's actions list:

          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Get the current user from the stream
              final user = snapshot.data;

              if (user != null && user.photoURL != null) {
                // --- LOGGED IN VIEW ---
                // Display their profile picture, tapping opens the end drawer (AuthDrawer)
                return IconButton(
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.black, size: 35),

                  // V V V --- THIS IS THE CRUCIAL PART --- V V V
                  // Make absolutely sure this onPressed ONLY calls showDialog
                  onPressed: () {
                    print('DEBUG: Showing PhoneAuthDialog from AppBar icon'); // Add this for confirmation
                    showDialog(
                      context: context,
                      builder: (context) => const PhoneAuthDialog(), // This MUST be here
                    );
                  },

                  tooltip: 'Account / Sign In',
                );
              }
              // This handles cases where user is logged in via phone (user != null but no photoURL)
              // OR if the user is completely logged out (user == null)
              else {
                // --- LOGGED OUT VIEW ---
                // Display the default account icon
                return IconButton(
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.black, size: 35),

                  // On tap, show the Phone Authentication Dialog
                  onPressed: () {
                    print('DEBUG: Logged-out icon pressed, showing PhoneAuthDialog'); // Optional debug print
                    showDialog(
                      context: context,
                      builder: (context) => const PhoneAuthDialog(), // <--- This shows your phone login
                    );
                  },
                  tooltip: 'Account / Sign In', // Updated tooltip
                );
              }
            },
          ), // End of StreamBuilder
        ],
      )
          : HomePageAppBar(
        menuItems: const [],
        selectedIndex: 0,
        hoveredIndex: null,
        onMenuSelect: (index) {},
        onHover: (_) {},
        onPartnerTap: () async {
          context.go('/partner-with-us');
        },
      ),


      // The navigation drawer is only available on smaller screens.
      drawer: w < mobileBreakpoint ? _buildNavigationDrawer(context) : null,

      endDrawer: AuthDrawer(),
      body: Stack(
        children: [


          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  /*Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Container(
                      // increase the vertical padding for height
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black54, // slightly softer border
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.search, color: kPrimary, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              cursorColor: kPrimary,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Search nearby services…',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.black26,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),*/
                  // Curved bottom image slider
                  /*LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 700;

                      final currentSliderImages = isMobile ? sliderImagesMobile : sliderImages;
                      final aspectRatio = isMobile ? 16 / 9 : 1920 / 550;

                      return ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(isMobile ? 0 : 70),
                          bottomRight: Radius.circular(isMobile ? 0 : 70),
                        ),
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  setState(() => _currentSlide = index);
                                },
                                itemCount: currentSliderImages.length,
                                itemBuilder: (context, index) {
                                  return Image.asset(
                                    currentSliderImages[index],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  );
                                },
                              ),

                              if (!isMobile)
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  left: 10,
                                  child: Center(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                                        color: Colors.black,
                                        onPressed: () {
                                          if (_currentSlide > 0) {
                                            _currentSlide--;
                                          } else {
                                            _currentSlide = currentSliderImages.length - 1;
                                          }
                                          _pageController.animateToPage(
                                            _currentSlide,
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeInOut,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                              if (!isMobile)
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  right: 10,
                                  child: Center(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 22),
                                        color: Colors.black,
                                        onPressed: () {
                                          if (_currentSlide < currentSliderImages.length - 1) {
                                            _currentSlide++;
                                          } else {
                                            _currentSlide = 0;
                                          }
                                          _pageController.animateToPage(
                                            _currentSlide,
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeInOut,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ),

                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: currentSliderImages.asMap().entries.map((entry) {
                                    final isActive = _currentSlide == entry.key;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      height: isActive ? 12 : 8,
                                      width: isActive ? 12 : 8,
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.white : Colors.white54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Horizontal scrollable cards
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;

                        // Responsive card width: between 180 and 300, roughly 1/3 of width
                        double cardWidth = (w / 3).clamp(180, 300);

                        // Keep height proportional to width to keep rectangle shape (e.g., height = 60% of width)
                        double cardHeight = cardWidth * 0.6; // rectangle (wider than tall)

                        // Responsive font size for title
                        double fontSize = (w / 50).clamp(12, 16);

                        return SizedBox(
                          height: cardHeight,
                          child: Listener(
                            onPointerSignal: (event) {
                              if (event is PointerScrollEvent) {
                                _scrollController.jumpTo(
                                  (_scrollController.offset + event.scrollDelta.dy * 1.5)
                                      .clamp(_scrollController.position.minScrollExtent,
                                      _scrollController.position.maxScrollExtent),
                                );
                              }
                            },
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                _scrollController.jumpTo(
                                  (_scrollController.offset - details.delta.dx)
                                      .clamp(_scrollController.position.minScrollExtent,
                                      _scrollController.position.maxScrollExtent),
                                );
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: cards.length,
                                itemBuilder: (context, index) {
                                  final cardData = cards[index];
                                  final title = (cardData['title'] ?? '').toString();
                                  final titleLower = title.toLowerCase();

                                  return GestureDetector(
                                    onTap: () {
                                      if (titleLower != 'overnight boarding' &&
                                          titleLower != 'pet daycare') {
                                        showComingSoonDialog(context, title);
                                      }
                                    },
                                    child: Container(
                                      width: cardWidth,
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Material(
                                              elevation: 4,
                                              borderRadius: BorderRadius.circular(12),
                                              shadowColor: Colors.black54,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.black, width: 0.5),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.asset(
                                                    cardData['image']!,
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            title,
                                            style: GoogleFonts.poppins(
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),*/

                  SizedBox(height: 15),
                  AggregatorLandingPage (),
                  Divider(
                    color: Colors.grey.shade300, // soft color
                    thickness: 1.2,
                    height: 32, // space above and below the divider
                  ),



                  /* const WhatWeDoSection(
                imageAssetPath: 'assets/pet.jpg',
                // optional: override the default lines
                lines: [
                  "We bring all your pet needs into one app.",
                  "We help you find and compare trusted services.",
                  "We let you book instantly with real-time confirmation.",
                  "We support you and your pet every step of the way."
                ],
              ),
              Divider(
                color: Colors.grey.shade300, // soft color
                thickness: 1.2,
                height: 32, // space above and below the divider
              ),*/



                  Builder(
                    builder: (context) {
                      final cardsProv = context.watch<BoardingCardsProvider>();
                      final favProv = context.watch<FavoritesProvider>();
                      final hideProv = context.watch<HiddenServicesProvider>();
                      final distMap = context.watch<DistanceProvider>().distances;

                      if (!cardsProv.ready) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filtered = cardsProv.cards.where((service) {
                        final display = service['display'] as bool? ?? true;
                        if (!display) return false;

                        final id = service['service_id']?.toString() ?? '';
                        if (hideProv.hidden.contains(id)) return false;
                        if (_showFavoritesOnly && !favProv.liked.contains(id)) return false;

                        if (_selectedDistanceOption.isNotEmpty) {
                          final maxKm = double.tryParse(_selectedDistanceOption.replaceAll(' km', '')) ?? double.infinity;
                          if ((distMap[id] ?? double.infinity) > maxKm) return false;
                        }

                        if (_filterDates.isNotEmpty && _filterPetCount > 0) {
                          final bookingCounts = _allBookingCounts[id] ?? {};
                          final maxAllowed = _serviceMaxAllowed[id] ?? 0;
                          for (final d in _filterDates) {
                            if ((bookingCounts[d] ?? 0) + _filterPetCount > maxAllowed) {
                              return false;
                            }
                          }
                        }

                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth;
                          final bool isSmallScreen = maxWidth < 800;
                          final double headingFontSize = (maxWidth / 1200 * 42).clamp(28.0, 42.0);
                          final double subheadingFontSize = (maxWidth / 1200 * 18).clamp(15.0, 18.0);
                          final int cardsPerRow = isSmallScreen ? 1 : 3;
                          final double cardWidth = 380.0;
                          final double spacing = isSmallScreen ? 12.0 : 16.0;

                          final displayList = isSmallScreen && !_showAllMobileCards && filtered.length > 4
                              ? filtered.take(4).toList()
                              : filtered;

                          List<Widget> rows = [];
                          for (int i = 0; i < displayList.length; i += cardsPerRow) {
                            final rowItems = displayList
                                .skip(i)
                                .take(cardsPerRow)
                                .map((data) => SizedBox(
                              width: cardWidth,
                              child: WebServiceCard(service: data), // 👈 Change it to this
                            ))
                                .toList();

                            Widget row = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int j = 0; j < rowItems.length; j++) ...[
                                  if (j > 0) SizedBox(width: spacing),
                                  rowItems[j],
                                ],
                              ],
                            );

                            rows.add(
                              Padding(
                                padding: EdgeInsets.only(bottom: spacing),
                                child: FittedBox(
                                  alignment: Alignment.center,
                                  fit: BoxFit.scaleDown,
                                  child: row,
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Search nearby ',
                                          style: GoogleFonts.poppins(
                                            fontSize: headingFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'boarding centers',
                                          style: GoogleFonts.poppins(
                                            fontSize: headingFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: kPrimary,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' today!',
                                          style: GoogleFonts.poppins(
                                            fontSize: headingFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Trusted care for your pets. Convenient, safe, and affordable.',
                                  style: GoogleFonts.poppins(
                                    fontSize: subheadingFontSize,
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ...rows,

                                // Show More / Show Less
                                if (isSmallScreen && filtered.length > 4)
                                  Align(
                                    alignment: Alignment.center,
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _showAllMobileCards = !_showAllMobileCards;
                                        });
                                      },
                                      child: Text(
                                        _showAllMobileCards ? 'Show less' : 'Show more',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: kPrimary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  Divider(
                    color: Colors.grey.shade300, // soft color
                    thickness: 1.2,
                    height: 32, // space above and below the divider
                  ),
                  MfpPromotionCard(
                    card_buildStaticServiceCard: _buildStaticServiceCard(
                      context,
                    ),
                  ),

                  Divider(
                    color: Colors.grey.shade300, // soft color
                    thickness: 1.2,
                    height: 32, // space above and below the divider
                  ),

                  const SizedBox(height: 16),
                  const ClientsSection(),
                  const SizedBox(height: 16),
                  _buildFinalCta(context),
                  CompanyFooterSection(),
                ],
              ),

            ),

          ),

          const WhatsAppFab()

        ],
      ),
      /*floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Theme(
        data: Theme.of(context).copyWith(
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            extendedPadding: EdgeInsets.zero, // for extended FAB
            shape: RoundedRectangleBorder(), // optional
          ),
        ),
        child: Container(
          margin: EdgeInsets.zero, // Ensure no margin
          child: ChatbotFloatingButton(serviceId: myCurrentServiceId),
        ),
      ),*/
    );

  }

  Widget _buildServiceCardFromMap(
      BuildContext context,
      Map<String, dynamic> service, {
        int mode = 1,
        double scale = 1.0,
      }) {
    final width = MediaQuery.of(context).size.width;
    final fontScale = (width > 800 ? 1.2 : 1.0) * scale;

    final serviceId = service['service_id']?.toString() ?? '';
    final shopName = service['shopName']?.toString() ?? 'Unknown Shop';
    // v v v ADD THIS LINE TO DEBUG v v v
    print('DEBUG for "$shopName": pre_calculated_standard_prices = ${service['pre_calculated_standard_prices']}');


    // --- v v v THIS IS THE CORRECTED LINE v v v ---
    final rawRates = Map<String, dynamic>.from(service['rates_daily'] ?? {});

    final Map<String, int> rates =
    rawRates.map((key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0));
    final areaName = service['areaName']?.toString() ?? 'Unknown Area';
    final shopImage = service['shop_image']?.toString() ?? '';

    final priceStr = service['price']?.toString();
    final price = int.tryParse(priceStr ?? '') ?? 0;
    print('Checking service data for "${service['shopName']}": ${service['rates_daily']}');

    final rawPets = service['pets'];
    final petList = (rawPets is List)
        ? rawPets
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList()
        : <String>[];

    final distances = context.watch<DistanceProvider>().distances;
    final dKm = distances[serviceId] ?? 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        builder: (_, animationScale, __) => Transform.scale(
          scale: animationScale,
          child: Card(
            margin: EdgeInsets.all(6.0 * scale),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18 * scale),
            ),
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18 * scale),
              onTap: () {
                // Handle tap based on `mode` if needed
              },
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Image + Like Button ─────────────────
                      Stack(
                        children: [
                          Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(14 * scale),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14 * scale),
                              child: Container(
                                width: 120 * scale,
                                height: 150 * scale,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(14 * scale),
                                ),
                                child: Image.network(
                                  shopImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Icon(Icons.image_not_supported,
                                        size: 24 * scale, color: Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 20.0, // runStripHeight
                              decoration: BoxDecoration( // _runTypeGradient("Business Run")
                                gradient: LinearGradient(colors: [Colors.blue, Colors.lightBlue]),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(fontScale * 0.8),
                                  bottomRight: Radius.circular(fontScale * 0.8),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "Business Run", // _runTypeLabel("Business Run")
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.0, // runStripHeight * 0.6
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4 * scale,
                            right: 4 * scale,
                            child: Consumer<FavoritesProvider>(
                              builder: (_, favProv, __) {
                                final isLiked = favProv.liked.contains(serviceId);
                                return Container(
                                  height: 32 * scale,
                                  width: 32 * scale,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.transparent,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => favProv.toggle(serviceId),
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (c, a) =>
                                          ScaleTransition(scale: a, child: c),
                                      child:
                                      Icon(
                                        Icons.favorite,
                                        key: ValueKey(isLiked),
                                        size: 20 * scale,
                                        color:  const Color(0xFFFF5B20),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // ─── Details Column ───────────────────────
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              12 * scale, 16 * scale, 10 * scale, 8 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                style: TextStyle(
                                  fontSize: 16 * fontScale,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2 * scale),
                              if (rates.isNotEmpty)
                                Text("Price Dropdown Here") // buildPriceDropdown(rates) - Placeholder
                              else
                                Text('$price / day'), // _buildInfoRow
                              SizedBox(height: 2 * scale),
                              Text(areaName), // _buildInfoRow
                              SizedBox(height: 8 * scale),
                              SizedBox(
                                height: 28 * scale,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: petList
                                      .map((pet) => Padding(
                                    padding: EdgeInsets.only(
                                        right: 6.0 * scale),
                                    child: Chip(label: Text(pet)), // _buildPetChip
                                  ))
                                      .toList(),
                                ),
                              ),
                              SizedBox(height: 2 * scale),
                              Text(
                                '${dKm.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  fontSize: 10 * fontScale,
                                  color: const Color(0xFF4F4F4F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ─── Hide popup ───────────────────────────
                  Positioned(
                    top: 6 * scale,
                    right: 6 * scale,
                    child: Consumer<HiddenServicesProvider>(
                      builder: (_, hideProv, __) {
                        final isHidden = hideProv.hidden.contains(serviceId);
                        const accent = Colors.black54;
                        return Container(
                          height: 40 * scale,
                          width: 40 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(
                              color: Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.more_vert,
                            color:  Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A static card widget that looks exactly like WebServiceCard but uses dummy data.
  Widget _buildStaticServiceCard(BuildContext context) {
    // --- All data is now hardcoded dummy values ---
    const String shopName = "MyFellowPet";
    const String shopImage = "assets/mfplogo.jpg"; // Using your logo as a placeholder
    const String areaName = "Oxford Towers";
    const String runType = "Business Run";
    const List<String> petList = ['Dog', 'Cat', 'Bird'];
    const String distance = "5.0 km away";
    const bool isOfferActive = true; // Set to true to show the offer banner
    const bool isCertified = true;   // Set to true to show the certified badge
    const bool isAdminApproved = true; // Included for completeness

    // Helper widget for pet chips, kept local for simplicity
    Widget _buildPetChip(String pet) {
      String displayText = pet.isNotEmpty ? pet[0].toUpperCase() + pet.substring(1).toLowerCase() : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.1),
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ),
      );
    }

    // --- Main Card Build ---
    return Stack(
      clipBehavior: Clip.none, // Allow badge to sit slightly outside
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Left Side: Image & Overlays ---
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 110,
                            height: 140,
                            color: Colors.grey.shade200,
                            child: Image.asset(
                              shopImage,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.storefront, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: _runTypeGradient(runType),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _runTypeLabel(runType),
                                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        // Static Favorite Icon
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            child: const Icon(
                              Icons.favorite_border,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // --- Right Side: Details ---
                    Expanded(
                      child: SizedBox(
                        height: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Static Star Rating
                            Row(
                              children: [
                                for (int i = 0; i < 5; i++)
                                  Icon(i < 4 ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text('4.0 (1)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
                              ],
                            ),
                            // --- Static replacement for PriceAndPetSelector ---
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Starts from ₹450',
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Dog',
                                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // --- Static replacement for BranchSelector ---
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 12, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    areaName,
                                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFF67B0D), size: 20),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Pet Chips
                            SizedBox(
                              height: 25,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: petList.map((pet) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildPetChip(pet),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(distance, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Offer Banner
              // Offer Banner
              if (isOfferActive)
              // REMOVED THE Positioned(...) WIDGET AROUND THIS CONTAINER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFF67B0D), Color(0xFFD96D0B)]),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('SPECIAL OFFER', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Positioned Certified Badge
        Positioned(
          top: 10,
          right: 10,
          child: Tooltip(
            message: isCertified ? "MFP Certified" : (isAdminApproved ? "Profile Verified" : ""),
            child: Builder(
              builder: (context) {
                if (isCertified) {
                  return const IconBadge(icon: Icons.workspace_premium, color: AppColors.accentColor);
                }
                if (isAdminApproved) {
                  return const IconBadge(icon: Icons.verified_user, color: AppColors.primaryColor);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> fetchRatingStats(String serviceId) async {
    final coll = FirebaseFirestore.instance
        .collection('public_review')
        .doc('service_providers')
        .collection('sps')
        .doc(serviceId)
        .collection('reviews');

    final snap = await coll.get();
    // Extract only ratings > 0
    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
        .where((r) => r > 0)
        .toList();

    final count = ratings.length;
    final avg = count > 0
        ? ratings.reduce((a, b) => a + b) / count
        : 0.0;

    return {
      'avg': avg.clamp(0.0, 5.0),
      'count': count,
    };
  }

  Widget buildPriceDropdown(Map<String, int> rates) {
    return PopupMenuButton<String>(
      onSelected: (size) {
        print('Selected: $size');
      },
      itemBuilder: (_) => rates.entries.map((e) {
        return PopupMenuItem<String>(
          value: e.key,
          child: Text('${e.key} pets: ₹${e.value}'),
        );
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Starts from ₹${rates.entries.first.value}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }




  Widget _buildInfoRow(String text, IconData icon, Color iconColor, double scale) {
    return Row(
      children: [
        Icon(icon, size: 14 * scale, color: iconColor),
        const SizedBox(width: 4),
        // 👇 Wrap the Text widget with Expanded
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12 * scale,
              color: Colors.black87,
            ),
            maxLines: 1, // Keep it to a single line for consistency
            overflow: TextOverflow.ellipsis, // Add ellipsis for long text
          ),
        ),
      ],
    );
  }

  Widget _buildStaticInfoRow(String text, IconData icon, Color iconColor, double scale) {
    return Row(
      children: [
        Icon(icon, size: 23 * scale, color: iconColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 21 * scale,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }


  Widget _buildPetChip(String pet, [double scale = 1.0]) {
    return Chip(
      label: Text(
        pet,
        style: TextStyle(fontSize: 12 * scale),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      backgroundColor: Colors.grey[200],
    );
  }

}


/*class WhatWeDoSection extends StatelessWidget {
  static const Color primary = Color(0xFF2CB4B6);

  final String imageAssetPath;
  final List<String> lines;
  final double maxBoxHeight;

  const WhatWeDoSection({
    Key? key,
    required this.imageAssetPath,
    this.maxBoxHeight = 300,
    this.lines = const [
      "We bring all your pet needs into one app.",
      "We help you find and compare trusted services.",
      "We let you book instantly with real-time confirmation.",
      "We support you and your pet every step of the way.",
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(94, 24, 94, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: title + bullets
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What Do We Really Do?",
                      style: GoogleFonts.poppins(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Indented bullet list
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lines.map((line) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // bullet
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // text
                                Expanded(
                                  child: Text(
                                    line,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      height: 1.5,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Right: image box with max height
              Expanded(
                flex: 2,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxBoxHeight,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16), // 👈 Adjust corner radius here
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(
                        imageAssetPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }
}*/

class ClientsSection extends StatefulWidget {
  const ClientsSection({Key? key}) : super(key: key);

  @override
  State<ClientsSection> createState() => _ClientsSectionState();
}

class _ClientsSectionState extends State<ClientsSection> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    const scrollSpeed = 25.0; // Pixels per second
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      if (currentScroll >= maxScroll) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: ((maxScroll - currentScroll) / scrollSpeed * 1000).toInt()),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users-sp-boarding').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Text("Error: ${snap.error}", style: GoogleFonts.poppins(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['display'] == true;
        }).toList();

        if (filtered.isEmpty) {
          return const SizedBox.shrink();
        }

        // Duplicate the list to create a seamless loop
        final loopedList = [...filtered];

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 60.0),
          child: Column(
            children: [
              Text(
                "Our Top Trusted Partners",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 150, // Height of the carousel
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(), // Disable manual scroll
                  itemCount: loopedList.length,
                  itemBuilder: (context, i) {
                    final data = loopedList[i].data() as Map<String, dynamic>;
                    return _buildPartnerCard(data);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerCard(Map<String, dynamic> data) {
    final logoUrl = data['shop_logo'] as String?;
    final name = data['shop_name'] as String? ?? '—';

    return HoverCard(
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? FadeInImage.memoryNetwork(
                placeholder: kTransparentImage,
                image: logoUrl,
                fit: BoxFit.contain,
                imageErrorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.storefront, size: 48, color: Colors.grey),
              )
                  : const Icon(Icons.storefront, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// A helper widget to add a hover effect
class HoverCard extends StatefulWidget {
  final Widget child;
  const HoverCard({Key? key, required this.child}) : super(key: key);

  @override
  _HoverCardState createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final transform = _isHovered ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity();
    final shadow = _isHovered ? [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 10),
      )
    ] : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 5),
      )
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: transform,
        decoration: BoxDecoration(
            boxShadow: shadow,
            borderRadius: BorderRadius.circular(16)
        ),
        child: widget.child,
      ),
    );
  }
}

class MfpPromotionCard extends StatelessWidget {
  final Widget card_buildStaticServiceCard;

  const MfpPromotionCard({
    super.key,
    required this.card_buildStaticServiceCard,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final bool isVertical = maxWidth < 900;

        // Responsive font sizes (your existing logic is great!)
        final double headingFontSize = (maxWidth / 1200 * 42).clamp(28.0, 42.0);
        final double subheadingFontSize = (maxWidth / 1200 * 18).clamp(15.0, 18.0);
        final double bulletFontSize = (maxWidth / 1200 * 16).clamp(14.0, 16.0);
        final double buttonFontSize = (maxWidth / 1200 * 16).clamp(14.0, 16.0);

        final Widget textContent = Padding(
          padding: EdgeInsets.only(right: isVertical ? 0 : 48.0, bottom: isVertical ? 32 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Join Us and Get ',
                      style: GoogleFonts.poppins(
                        fontSize: headingFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white, // Changed for dark theme
                      ),
                    ),
                    TextSpan(
                      text: 'MFP Certified',
                      style: GoogleFonts.poppins(
                        fontSize: headingFontSize,
                        fontWeight: FontWeight.w700,
                        color: kPrimary, // Accent color stands out
                      ),
                    ),
                    TextSpan(
                      text: ' Today!',
                      style: GoogleFonts.poppins(
                        fontSize: headingFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Boost your trust, get more leads,\nand stand out from the crowd.',
                style: GoogleFonts.poppins(
                  fontSize: subheadingFontSize,
                  color: Colors.white.withOpacity(0.8), // Softer white for subtitle
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint('Verified badge on your profile', bulletFontSize),
                  _buildBulletPoint('Increased visibility to users', bulletFontSize),
                  _buildBulletPoint('More credibility & higher bookings', bulletFontSize),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, color: primaryColor,),
                onPressed: () {
                  context.go('/partner-with-us');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // Contrasting button color
                  foregroundColor: kPrimary, // Text and icon color
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                label: Text(
                  'Join / Apply for Certification',
                  style: GoogleFonts.poppins(
                    fontSize: buttonFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        final Widget cardContent = Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: card_buildStaticServiceCard,
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            // --- New Premium Background ---
            gradient: const LinearGradient(
              colors: [Color(0xFF2D3436), Color(0xFF1E272E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isVertical
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [textContent, cardContent],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: textContent),
              const SizedBox(width: 24),
              // --- Decorative Divider ---
              Container(
                width: 1.5,
                height: 200, // Adjust height as needed
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: cardContent),
            ],
          ),
        );
      },
    );
  }

  /// Updated to use a styled icon instead of a text bullet.
  Widget _buildBulletPoint(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: kPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

////////


class ServiceIcon {
  final String svgAsset;
  final String label;
  const ServiceIcon({required this.svgAsset, required this.label});
}

class PetJourneyStage {
  final String title;
  final String subtitle;
  final String description;
  final String imageAsset;
  final Color accentColor;
  final List<ServiceIcon> services;

  const PetJourneyStage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageAsset,
    required this.accentColor,
    required this.services,
  });
}


// --- DATA MODELS ---
class ServiceCategory {
  final IconData icon;
  final String name;
  const ServiceCategory({required this.icon, required this.name});
}

class Metric {
  final String value;
  final String label;
  const Metric({required this.value, required this.label});
}

// --- MAIN WIDGET ---
class AggregatorLandingPage extends StatelessWidget {
  const AggregatorLandingPage({Key? key}) : super(key: key);

  // --- DATA LISTS (Easy to update) ---
  static const List<ServiceCategory> _services = [
    ServiceCategory(icon: Icons.home, name: "Boarding"),
    ServiceCategory(icon: Icons.content_cut_outlined, name: "Grooming"),
    ServiceCategory(icon: Icons.medical_services_outlined, name: "Vets"),
    ServiceCategory(icon: Icons.shopping_bag_outlined, name: "Supplies"),
    ServiceCategory(icon: Icons.school_outlined, name: "Training"),
    ServiceCategory(icon: Icons.favorite_border_outlined, name: "Farewell"),
  ];

  static const List<Metric> _metrics = [
    Metric(value: "50+", label: "Cities in India"),
    Metric(value: "10,000+", label: "Verified Providers"),
    Metric(value: "500k+", label: "Services Booked"),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(),
            _buildServicesSection(),
         //   _buildPanIndiaSection(),
         //   _buildHowItWorksSection(),
          ],
        ),
      ),
    );
  }

  // --- Your App Colors ---
  static const Color primaryColor = Color(0xFF2CB4B6);
  static const Color accentColor = Color(0xFFF67B0D);


// --- 1. THE UPDATED HERO SECTION ---
  Widget _buildHeroSection() {
    // We use a Stack to layer the custom background behind the main content.
    return Stack(
      children: [
        // --- The new background layer ---
        Positioned.fill(
          child: CustomPaint(
            // This painter is responsible for drawing the circles.
            painter: _BackgroundPainter(),
          ),
        ),

        // --- Your original content goes on top ---
        Container(
          // The container is now transparent to let the background show through.
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 30),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isMobile = constraints.maxWidth < 800;
                return isMobile
                    ? _buildMobileHeroContent(constraints)
                    : _buildDesktopHeroContent(constraints);
              },
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildDesktopHeroContent(constraints) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildHeroText(constraints),
        ),
        const SizedBox(width: 60),
        Expanded(
          flex: 2,
          child:
            Image.asset('assets/mfplogo.jpg', height: 400), // Add a nice pet image
        ),
      ],
    );
  }

  Widget _buildMobileHeroContent(constraints) {
    return Column(
      children: [
        _buildHeroText(constraints),
      ],
    );
  }
  Widget _buildHeroText(BoxConstraints constraints) {
    bool isMobile = constraints.maxWidth < 1000;

    return Column(
        crossAxisAlignment:
        isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 32 : 45, // smaller on mobile
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              children: const [
                TextSpan(text: "All Pet Services.\nOne App. "),
                TextSpan(
                  text: "Across India.",
                  style: TextStyle(color: primaryColor),
                ),
              ],
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: 20),
          Text(
            isMobile
                ? "India’s No.1 Pet Service Aggregator"
                : "India’s No.1 Pet Service Aggregator — trusted by thousands of pet parents. "
                "From grooming to boarding, food to healthcare, everything your pet needs is here.",
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 16 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),

          const SizedBox(height: 40),
          _buildSearchWidget(),
        ],
    );
  }


  Widget _buildSearchWidget() {
    // Use a LayoutBuilder to make decisions based on available width
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define a breakpoint for switching to the mobile layout
        final bool isMobile = constraints.maxWidth < 400;

        // The main container with consistent styling
        return Container(
          padding: isMobile ? const EdgeInsets.all(12.0) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: isMobile
              ? _buildMobileLayout(context)
              : _buildDesktopLayout(context),
        );
      },
    );
  }

  /// Builds the stacked layout for mobile phones.
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        TextField(
          style: GoogleFonts.poppins(fontSize: 16),
          decoration: InputDecoration(
            hintText: "Search for services...",
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, // Make the button full-width
          child: ElevatedButton(
            onPressed: () => showStoreComingSoonDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              "Find Care",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the horizontal layout for desktops and tablets.
  Widget _buildDesktopLayout(BuildContext context) {
    return TextField(
      style: GoogleFonts.poppins(fontSize: 16),
      decoration: InputDecoration(
        hintText: "Search for services...",
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () => showStoreComingSoonDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Find Care",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 700;

        // your dynamic spacing
        final double spacing = isMobile ? 20 : 80;

        // approx card width (match your card)
        const double cardWidth = 180;

        // how many tiles fit in one row WITH spacing between them
        final int maxPerRow = ((constraints.maxWidth + spacing) / (cardWidth + spacing))
            .floor()
            .clamp(1, 1000);

        final bool needsMore = _services.length > maxPerRow;

        // how many real services to show (reserve 1 slot for "More +" if needed)
        final int showCount = needsMore
            ? (maxPerRow - 1).clamp(0, _services.length)
            : _services.length;

        final List<Widget> rowItems = [];

        for (int i = 0; i < showCount; i++) {
          rowItems.add(
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildServiceCard(_services[i]),
            ),
          );
          // spacing between tiles (but not after the last one if no "More +")
          final bool addGap = i != showCount - 1 || needsMore;
          if (addGap) rowItems.add(SizedBox(width: spacing));
        }

        if (needsMore) {
          rowItems.add(
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildMoreCard(context),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: backgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowItems,
          ),
        );
      },
    );
  }
  Widget _buildMoreCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final isMobile = MediaQuery.of(context).size.width < 600;

        // This local function builds the UI for both mobile and desktop
        // to avoid code duplication.
        Widget buildContent(ScrollController? scrollController) {
          final crossAxisCount = isMobile ? 2 : 4;

          return Container(
            // Constrain width on desktop
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isMobile
                  ? const BorderRadius.vertical(top: Radius.circular(24))
                  : BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Custom Header ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isMobile)
                        Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: isMobile ? 16.0 : 0),
                        child: Text(
                          "All Services",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!isMobile)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // --- Scrollable Grid ---
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: scrollController,
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: _services.length,
                      itemBuilder: (context, index) {
                        // Assuming you have a _buildServiceCard method
                        return _buildServiceCard(_services[index]);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (isMobile) {
          // --- On MOBILE, show a modern Bottom Sheet ---
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, controller) => buildContent(controller),
            ),
          );
        } else {
          // --- On DESKTOP, show a polished Dialog ---
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: buildContent(null), // Pass null controller for dialog
            ),
          );
        }
      },
      // --- The "More" Card UI ---
      child:Container(
          width: 180,
          height: 120,
          color: Colors.grey.withOpacity(0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_view_rounded, color: Colors.black54),
              const SizedBox(height: 8),
              Text(
                "View All",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
      ),
    );
  }


  Widget _buildServiceCard(ServiceCategory service) {
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(service.icon, size: 40, color: primaryColor),
              const SizedBox(height: 16),
              Text(service.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600), maxLines: 1,),
            ],
          ),
        ),
      ),
    );
  }
}


Future<void> showComingSoonDialog(BuildContext context, String serviceName) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true, // tap outside to dismiss
    builder: (BuildContext ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Text(
          'Stay tuned $serviceName Coming Soon',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kPrimary,
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 8),
        actions: [
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
Future<void> showStoreComingSoonDialog(BuildContext context) {
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
            // --- THIS CONTROLS THE WIDTH ---
            constraints: const BoxConstraints(maxWidth: 400),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // --- Main Content Card ---
                Container(
                  margin: const EdgeInsets.only(top: 45), // Space for half the avatar
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Gradient
                      Container(
                        height: 65,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimary.withOpacity(0.8), kPrimary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                      ),
                      // Content Below Header
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
                                children: const [
                                  TextSpan(text: 'Our app'),
                                  TextSpan(
                                      text: ' is getting its final polish.\nStay tuned!'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
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

                // --- Overlapping Icon ---
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: kPrimary,
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
// --- 5. FINAL CTA SECTION ---
// --- 5. FINAL CTA SECTION ---
Widget _buildFinalCta(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
    color: primaryColor,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Ready to Find the Best Care for Your Pet?",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3, // 👈 improves readability
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => showStoreComingSoonDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30), // 👈 modern rounded
              ),
              elevation: 6, // 👈 makes button pop
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text("Download The App"),
          ),
        ],
      ),
    ),
  );
}


class WhatsAppFab extends StatelessWidget {
  const WhatsAppFab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24, // Standard FAB positioning
      right: 24,
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('company_documents')
            .doc('About Us')
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox(); // Don't show if no data
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final whatsappUrl = data['whatsapp_url']?.trim() ?? '';
          final whatsappMessage = data['whatsapp_message']?.trim() ?? '';

          if (whatsappUrl.isEmpty || whatsappMessage.isEmpty) {
            return const SizedBox();
          }

          final Uri url = Uri.parse(
              'https://wa.me/$whatsappUrl?text=${Uri.encodeComponent(whatsappMessage)}');

          // Use the animate_do package for a pulsing effect
          return Pulse(
            infinite: true,
            duration: const Duration(seconds: 3),
            child: FloatingActionButton(
              onPressed: () async {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('❌ Could not launch $url');
                }
              },
              backgroundColor: const Color(0xFF25D366), // Official WhatsApp Green
              tooltip: 'Chat on WhatsApp',
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}



class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire background with white first.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    // A predefined list of circle properties for a consistent design.
    final List<Map<String, dynamic>> circles = [
      {
        'offset': Offset(size.width * 0.55, size.height * 0.2), // upper left, near middle
        'radius': 120.0,
        'color': primaryColor,
      },
      {
        'offset': Offset(size.width * 0.3, size.height * 0.33), // mid-left
        'radius': 100.0,
        'color': accentColor,
      },
      {
        'offset': Offset(size.width * 0.0, size.height * 0.8), // further left
        'radius': 140.0,
        'color': primaryColor,
      },
      {
        'offset': Offset(size.width * 0.0, size.height * 0.0), // further left
        'radius': 140.0,
        'color': accentColor,
      },
      {
        'offset': Offset(size.width * 0.45, size.height * 0.75), // lower mid-left
        'radius': 90.0,
        'color': accentColor,
      },
    ];

    // Loop through the predefined list and draw each circle.
    for (var circle in circles) {
      final Offset offset = circle['offset'];
      final double radius = circle['radius'];
      final Color color = circle['color'];

      // Create a radial gradient for a softer effect.
      final Gradient gradient = RadialGradient(
        colors: [
          color.withOpacity(0.05), // almost solid center
          color.withOpacity(0.05), // edges less transparent
        ],
        stops: [0.6, 1.0], // center stays solid longer, fade at the edge
      );


      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: offset, radius: radius));

      // Draw the circle on the canvas.
      canvas.drawCircle(offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class WebServiceCard extends StatefulWidget {
  final Map<String, dynamic> service;

  const WebServiceCard({Key? key, required this.service}) : super(key: key);

  @override
  _WebServiceCardState createState() => _WebServiceCardState();
}

class _WebServiceCardState extends State<WebServiceCard> {

  String _slugify(String input) {
    if (input.isEmpty) return '';
    // Replace non-alphanumeric characters with hyphens and convert to lowercase
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Trim leading/trailing hyphens
  }

  // New function to build the full SEO-friendly URL
  String _buildSeoUrl(Map<String, dynamic> service) {
    // We'll use hardcoded 'india' and 'boarding' for now, as in the example
    const String country = 'india';
    const String serviceType = 'boarding';

    // Safely retrieve and slugify data
    final state = _slugify(service['state']?.toString() ?? 'unknown-state');
    final district = _slugify(service['district']?.toString() ?? 'unknown-district');
    final area = _slugify(service['areaName']?.toString() ?? 'unknown-area');
    final shopName = _slugify(service['shopName']?.toString() ?? 'pet-service');

    // Use the first pet type for the URL if available
    final pet = _slugify(List<String>.from(service['pets'] ?? ['pet']).first);

    // Combine everything into the desired long URL structure
    return '/$country/$serviceType/$state/$district/$area/${shopName}-${pet}-center';
  }


  String? _selectedPet;

  @override
  void initState() {
    super.initState();
    final standardPrices = Map<String, dynamic>.from(widget.service['pre_calculated_standard_prices'] ?? {});
    if (standardPrices.isNotEmpty) {
      _selectedPet = standardPrices.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    // --- Data Extraction ---
    final serviceId = service['service_id']?.toString() ?? '';
    final seoPath = _buildSeoUrl(service);
    final shopName = service['shopName']?.toString() ?? 'Unknown Shop';
    final shopImage = service['shop_image']?.toString() ?? '';
    final areaName = service['areaName']?.toString() ?? 'Unknown Area';
    final runType = service['type'] as String? ?? '';
    final petList = List<String>.from(service['pets'] ?? []);
    final dKm = (service['distance'] as double? ?? 0.0);
    final isOfferActive = service['isOfferActive'] as bool? ?? false;
    final isCertified = service['mfp_certified'] as bool? ?? false;

    // 1. Get the 'adminApproved' status for the "Verified" badge
    final isAdminApproved = service['adminApproved'] as bool? ?? false;

    final standardPricesMap = Map<String, dynamic>.from(service['pre_calculated_standard_prices'] ?? {});
    final offerPricesMap = Map<String, dynamic>.from(service['pre_calculated_offer_prices'] ?? {});
    final otherBranches = List<String>.from(service['other_branches'] ?? []);

    // 2. The main Stack now holds the Card and the Badge
    return Stack(
      clipBehavior: Clip.none, // Allow badge to sit slightly outside
      children: [
        Card(
          color: Colors.white,
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: Colors.black.withOpacity(0.87), // black87 border
              width: 1.0, // adjust thickness if needed
            ),
          ),          child: InkWell(
          onTap: () {
            // ❌ REPLACE the old Navigator.push
            // ✅ WITH the go_router call:
            context.go(
                '$seoPath?id=$serviceId',
                extra: { // Pass the data via `extra` as a performance optimization
                  'serviceData': service,
                }
            );
          },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Left Side: Image & Overlays ---
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 110,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: Image.network(
                                shopImage,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.storefront, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: _runTypeGradient(runType),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _runTypeLabel(runType),
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Consumer<FavoritesProvider>(
                              builder: (_, favProv, __) {
                                final isLiked = favProv.liked.contains(serviceId);
                                return Container(
                                  height: 32,
                                  width: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => favProv.toggle(serviceId),
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      size: 18,
                                      color: isLiked ? Colors.redAccent : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // --- Right Side: Details ---
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              FutureBuilder<Map<String, dynamic>>(
                                future: fetchRatingStats(serviceId),
                                builder: (ctx, snap) {
                                  if (!snap.hasData || (snap.data!['count'] as int) == 0) {
                                    return const SizedBox(height: 18);
                                  }
                                  final avg = snap.data!['avg'] as double;
                                  final count = snap.data!['count'] as int;
                                  return Row(
                                    children: [
                                      for (int i = 0; i < 5; i++)
                                        Icon(i < avg.round() ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text('${avg.toStringAsFixed(1)} ($count)', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
                                    ],
                                  );
                                },
                              ),
                              PriceAndPetSelector(
                                standardPrices: standardPricesMap,
                                offerPrices: offerPricesMap,
                                isOfferActive: isOfferActive,
                                initialSelectedPet: _selectedPet,
                                onPetSelected: (pet) => setState(() => _selectedPet = pet),
                              ),
                              BranchSelector(
                                currentServiceId: serviceId,
                                currentAreaName: areaName,
                                otherBranches: otherBranches,
                                onBranchSelected: (newBranchId) {
                                  // TODO: Implement branch switching logic
                                },
                              ),
                              const Spacer(),
                              if (petList.isNotEmpty)
                                SizedBox(
                                  height: 25,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: petList.map((pet) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _buildPetChip(pet),
                                    )).toList(),
                                  ),
                                ),
                              const SizedBox(height: 3),
                              Text('${dKm.toStringAsFixed(1)} km away', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOfferActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFF67B0D), Color(0xFFD96D0B)]),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('SPECIAL OFFER', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. Position the badge on the top-right of the whole card
        Positioned(
          top: 10,
          right: 10,
          child: Tooltip(
            message: isCertified ? "MFP Certified" : (isAdminApproved ? "Profile Verified" : ""),
            child: Builder(
              builder: (context) {
                // 4. Logic to show the correct badge (Certified has priority)
                if (isCertified) {
                  return const IconBadge(icon: Icons.workspace_premium, color: AppColors.accentColor);
                }
                if (isAdminApproved) {
                  return const IconBadge(icon: Icons.verified_user, color: AppColors.primaryColor);
                }
                // Return an empty container if neither is true
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetChip(String pet) {
    String displayText = pet.isNotEmpty ? pet[0].toUpperCase() + pet.substring(1).toLowerCase() : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const IconBadge({
    Key? key,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 14,
      ),
    );
  }
}


void _showHideConfirmationDialog(
    BuildContext context,
    String serviceId,
    bool isHidden,
    HiddenServicesProvider provider,
    ) {
  showDialog(
    context: context,
    barrierDismissible: true, // Allow dismissing by tapping outside
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icon
              Icon(
                isHidden ? Icons.refresh_rounded : Icons.block_rounded,
                size: 48,
                color: isHidden ? AppColors.primaryColor : Colors.red.shade700,
              ),
              const SizedBox(height: 20),

              // 2. Title
              Text(
                isHidden ? 'Make Service Visible?' : 'Hide This Service?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // 3. Subtitle
              Text(
                isHidden
                    ? 'This service will reappear in your search results.'
                    : 'You won\'t see this service in your feed anymore. You can un-hide it later from your account settings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Dismiss the dialog first
                        Navigator.of(dialogContext).pop();

                        // Then, perform the action
                        provider.toggle(serviceId);

                        // And finally, show the SnackBar feedback
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.grey.shade800,
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              isHidden ? 'Service is now visible.' : 'Service has been hidden.',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            action: SnackBarAction(
                              label: 'Undo',
                              textColor: AppColors.accentColor,
                              onPressed: () => provider.toggle(serviceId),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHidden ? AppColors.primaryColor : Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        isHidden ? 'Yes, Show' : 'Yes, Hide',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class VerifiedBadge extends StatelessWidget {
  final bool isCertified;
  const VerifiedBadge({Key? key, required this.isCertified}) : super(key: key);

  Future<void> _showDialog(BuildContext context, String field) async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('testaments')
        .get();

    final message = doc.data()?[field] ?? 'No info available';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        title: Text(
          isCertified ? "MFP Certified" : "Verified Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: () => _showDialog(
          context,
          isCertified ? 'mfp_certified_user_app' : 'profile_verified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
            borderRadius: BorderRadius.circular(20), // pill-like modern shape
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                isCertified ? "MFP Certified" : "Verified",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileVerified extends StatelessWidget {
  const ProfileVerified({Key? key}) : super(key: key);

  Future<void> _showDialog(BuildContext context, String field) async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('testaments')
        .get();

    final message = doc.data()?[field] ?? 'No info available';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        title: Text(
          "Profile Verified",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: () => _showDialog(
          context,
          'profile_verified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(20), // pill-like modern shape
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                "Profile Verified",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceAndPetSelector extends StatefulWidget {
  final Map<String, dynamic> standardPrices;
  final Map<String, dynamic> offerPrices;
  final bool isOfferActive;
  final String? initialSelectedPet;
  final Function(String) onPetSelected; // Callback to update the parent

  const PriceAndPetSelector({
    Key? key,
    required this.standardPrices,
    required this.offerPrices,
    required this.isOfferActive,
    this.initialSelectedPet,
    required this.onPetSelected,
  }) : super(key: key);

  @override
  _PriceAndPetSelectorState createState() => _PriceAndPetSelectorState();
}

class _PriceAndPetSelectorState extends State<PriceAndPetSelector> {
  String? _selectedPet;

  @override
  void initState() {
    super.initState();
    _selectedPet = widget.initialSelectedPet;

    // --- ADD THIS LOGIC ---
    // If no initial pet is selected, but we have price data,
    // automatically select the first available pet.
    if (_selectedPet == null && widget.standardPrices.isNotEmpty) {
      _selectedPet = widget.standardPrices.keys.first;

      // Notify the parent card about the automatic selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPetSelected(_selectedPet!);
        }
      });
    }
    // --------------------
  }

  @override
  void didUpdateWidget(covariant PriceAndPetSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initial pet from the parent changes, update the state
    if (widget.initialSelectedPet != oldWidget.initialSelectedPet) {
      setState(() {
        _selectedPet = widget.initialSelectedPet;
      });
    }
  }

  Widget _buildPetSelector() {
    final standardPrices = Map<String, dynamic>.from(
        widget.standardPrices ?? {});
    final availablePets = standardPrices.keys.toList();
    if (availablePets.isEmpty) return const SizedBox.shrink();

    String capitalize(String s) =>
        s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    return PopupMenuButton<String>(
      color: Colors.white, // white background for dropdown
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onSelected: (pet) => setState(() => _selectedPet = pet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedPet != null ? capitalize(_selectedPet!) : 'Pet',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
          ],
        ),
      ),
      itemBuilder: (context) => availablePets
          .map((pet) => PopupMenuItem<String>(
        value: pet,
        child: Text(
          capitalize(pet),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ))
          .toList(),
    );

  }

  Widget _buildPriceDisplay(bool isOfferActive) {
    if (_selectedPet == null) {
      return const Text('Pricing not available',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    // --- START: NEW ROBUST CODE ---

    // 1. Safely get the price data for the selected pet
    final dynamic standardPricesForPet = widget.standardPrices[_selectedPet];
    final dynamic offerPricesForPet = widget.offerPrices[_selectedPet];

    // 2. Determine the correct source, BUT ONLY if it's a valid Map
    final dynamic rawRatesSource = (isOfferActive && offerPricesForPet is Map)
        ? offerPricesForPet
        : (standardPricesForPet is Map ? standardPricesForPet : null);

    // 3. If we don't have a valid source map, show a message and stop.
    if (rawRatesSource == null) {
      return const Text('No price set',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey));
    }

    // 4. Now that we know it's a Map, it's safe to convert it.
    final ratesSource = Map<String, num>.from(rawRatesSource);

    // --- END: NEW ROBUST CODE ---

    if (ratesSource.isEmpty) {
      return const Text('No price set',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey));
    }

    final minPrice = ratesSource.values.reduce(min);
    int? minOldPrice;

    if (isOfferActive && standardPricesForPet is Map) {
      final oldPricesForPet = Map<String, num>.from(standardPricesForPet);
      if (oldPricesForPet.isNotEmpty) {
        minOldPrice = oldPricesForPet.values.reduce(min).toInt();
      }
    }

    return PopupMenuButton<String>(
      color: Colors.white, // white background for dropdown
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      itemBuilder: (_) => ratesSource.entries
          .map((entry) => PopupMenuItem<String>(
        enabled: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              '₹${entry.value}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: isOfferActive && minOldPrice != null
                    ? Row(
                  children: [
                    Text(
                      '₹$minOldPrice',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFFF9A9A),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹$minPrice',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                )
                    : Text(
                  'Starts from ₹$minPrice',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPriceDisplay(widget.isOfferActive)),
        const SizedBox(width: 8),
        _buildPetSelector(),
      ],
    );
  }
}

class BranchSelector extends StatefulWidget {
  final String currentServiceId;
  final String currentAreaName;
  final List<String> otherBranches;
  final Function(String?) onBranchSelected;

  const BranchSelector({
    Key? key,
    required this.currentServiceId,
    required this.currentAreaName,
    required this.otherBranches,
    required this.onBranchSelected,
  }) : super(key: key);

  @override
  _BranchSelectorState createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<BranchSelector> {
  List<Map<String, String>> _branchOptions = [];
  bool _isLoadingBranches = true;

  @override
  void initState() {
    super.initState();
    _fetchBranchDetails();
  }

  @override
  void didUpdateWidget(covariant BranchSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentServiceId != oldWidget.currentServiceId) {
      _fetchBranchDetails();
    }
  }

  Future<void> _fetchBranchDetails() async {
    setState(() {
      _isLoadingBranches = true;
      _branchOptions = [];
    });

    List<Map<String, String>> branches = [{
      'id': widget.currentServiceId,
      'areaName': widget.currentAreaName
    }];

    if (widget.otherBranches.isNotEmpty) {
      final futures = widget.otherBranches
          .map((id) => FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(id)
          .get())
          .toList();
      final results = await Future.wait(futures);
      for (var doc in results) {
        if (doc.exists) {
          branches.add({
            'id': doc.id,
            'areaName': doc.data()?['area_name'] ?? 'Unknown'
          });
        }
      }
    }
    if (mounted) {
      setState(() {
        _branchOptions = branches;
        _isLoadingBranches = false;
      });
    }
  }

  Widget _buildInfoRow(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color), // was 16
        const SizedBox(width: 4),
        Expanded( // ⬅️ makes sure the text uses remaining space
          child: Text(
            text,
            maxLines: 1, // single line only
            overflow: TextOverflow.ellipsis, // show "..." if too long
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBranches) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_branchOptions.length <= 1) {
      return _buildInfoRow(
          widget.currentAreaName, Icons.location_on, Colors.black54);
    }

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: widget.onBranchSelected,
      itemBuilder: (_) => _branchOptions
          .map((branch) => PopupMenuItem<String>(
        value: branch['id'],
        child: Text(
          branch['areaName']!,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 12, color: Colors.black54),
            const SizedBox(width: 4),
            Text(
              widget.currentAreaName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                color: Color(0xFFF67B0D), size: 20),
          ],
        ),
      ),
    );
  }
}
// --- Enum for Dialog State ---
enum PhoneAuthState { phoneInput, detailsInput, otpInput }

// --- The Amazing Modern Dialog ---

class PhoneAuthDialog extends StatefulWidget {
  const PhoneAuthDialog({super.key});

  @override
  State<PhoneAuthDialog> createState() => _PhoneAuthDialogState();
}

class _PhoneAuthDialogState extends State<PhoneAuthDialog> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Note: RecaptchaVerifier initialization is often managed outside or
  // needs the actual web implementation which is complex in a small snippet.
  // We keep the logic but simplify the declaration here for clarity.
  RecaptchaVerifier? _recaptchaVerifier;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  PhoneAuthState _state = PhoneAuthState.phoneInput;
  String? _verificationId;
  String _errorMessage = '';
  bool _isLoading = false;

  // Data collected across steps
  String _phoneNumber = '';
  String? _displayName;
  String? _email;

  @override
  void initState() {
    super.initState();
    // Initialize reCAPTCHA (essential for web)
    // For simplicity, we just declare the function here.
    _initializeRecaptcha();
  }

  void _initializeRecaptcha() {
    // Production code would use a proper web-compatible RecaptchaVerifier setup here.
    try {
      _recaptchaVerifier = RecaptchaVerifier(auth: FirebaseAuthPlatform.instance,);
    } catch (e) {
      // Handle web platform specific errors
      debugPrint('Recaptcha init failed: $e');
    }
  }

  void _setErrorMessage(String message) {
    if (mounted) setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    // Important: Do NOT dispose _recaptchaVerifier if it was initialized externally
    // or by a widget that manages its lifecycle.
    super.dispose();
  }

  // --- Core Flow Functions ---

  /// Step 1 Handler: Validates phone and moves to details.
  // --- Core Flow Functions ---

  /// Step 1 Handler: Validates phone, checks existence, and moves state.
  Future<void> _submitPhoneNumber() async { // ✨ MAKE IT ASYNC
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _setErrorMessage("Please enter your phone number.");
      return;
    }
    // Standardize phone number format
    if (!phone.startsWith("+")) phone = "+91$phone";

    _phoneNumber = phone;

    setState(() {
      _isLoading = true; // Show loading while checking existence
      _errorMessage = '';
    });

    // 1. Look for a matching user document in Firestore by phone number
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('web-users')
      // Assuming you have a Firestore index on the 'phoneNumber' field
          .where('number', isEqualTo: _phoneNumber)
          .limit(1)
          .get();

      if (mounted) setState(() => _isLoading = false); // Hide loading

      if (querySnapshot.docs.isNotEmpty) {
        // 2. Doc EXISTS: Skip details, go straight to sending OTP
        // You can optionally pre-fill name/email if needed,
        // but for simplicity, we just move on.
        _displayName = querySnapshot.docs.first.data()['displayName'] as String?;
        _email = querySnapshot.docs.first.data()['email'] as String?;

        await _submitDetailsAndSendOtp(skipDetails: true); // ✨ Call with skip flag
      } else {
        // 3. Doc DOES NOT EXIST: Move to details input (new user flow)
        setState(() => _state = PhoneAuthState.detailsInput);
      }
    } catch (e) {
      debugPrint('Firestore lookup error: $e');
      _setErrorMessage('Could not check user status. Please try again.');
    }
  }

  /// Step 2 Handler: Collects optional data and sends OTP.
  Future<void> _submitDetailsAndSendOtp({bool skipDetails = false}) async {

    // If we skip details, we don't need to read the controllers again.
    if (!skipDetails) {
      _displayName = _nameController.text.trim();
      _email = _emailController.text.trim();
    }

    if (_recaptchaVerifier == null) {
      _setErrorMessage("Authentication system not ready. Please refresh.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: (credential) async {
          // Auto sign-in
          await _auth.signInWithCredential(credential);
          await _saveUserData(); // Save data after successful sign-in
          if (mounted) {
            Navigator.of(context).pop();
            html.window.location.reload();
          }
        },
        verificationFailed: (e) => _setErrorMessage(e.message ?? "Verification failed."),
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          setState(() {
            _state = PhoneAuthState.otpInput;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (vid) {},
        // verifier: _recaptchaVerifier, // Typically not needed if using the RecaptchaVerifier constructor
      );
    } catch (e) {
      _setErrorMessage('Error sending OTP: ${e.toString()}');
    }
  }

  /// Step 3 Handler: Verifies OTP and signs in.
  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otpController.text.length != 6) {
      _setErrorMessage("Please enter the 6-digit OTP.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _auth.signInWithCredential(cred);

      // Crucial: The UID is now confirmed by Firebase Auth
      await _saveUserData();

      if (mounted) {
        Navigator.of(context).pop();
        html.window.location.reload();
      }
    } catch (e) {
      _setErrorMessage("Invalid OTP. Please check the code and try again.");
    }
  }

  /// Final Step: Save/Update user data in Firestore using the *confirmed* Firebase UID.
  Future<void> _saveUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userData = {
      // Crucial: Use 'displayName' because that is what your GeneralAppUser expects
      // when loading data from 'web-users' with fallback logic.
      "displayName": _displayName?.isNotEmpty == true ? _displayName : _auth.currentUser?.displayName ?? "",
      "number": _phoneNumber, // Use the stored, standardized phone number
      "photoUrl": _auth.currentUser?.photoURL ?? "", // Optional: If Firebase provides one
      "lastLogin": FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('web-users')
        .doc(uid) // KEY FIX: Document ID is the confirmed Firebase UID
        .set(userData, SetOptions(merge: true));
  }


  // --- UI Builders ---

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Phone Number',
        prefixText: '+91 ',
        prefixStyle: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kPrimary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDetailsInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Your Name (Optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email (Optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Phone: $_phoneNumber',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        // Note: Photo URL upload/input is complex for a small example, excluded for brevity.
      ],
    );
  }

  Widget _buildOtpInput() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      textInputAction: TextInputAction.done,
      style: GoogleFonts.poppins(fontSize: 18, letterSpacing: 3),
      decoration: InputDecoration(
        labelText: '6-Digit OTP',
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kPrimary, width: 2),
        ),
      ),
    );
  }

  // --- Widget Build ---

  @override
  Widget build(BuildContext context) {
    String titleText;
    Widget currentContent;
    VoidCallback? primaryAction;
    String primaryButtonText;

    switch (_state) {
      case PhoneAuthState.phoneInput:
        titleText = 'Sign in with Phone';
        currentContent = _buildPhoneInput();
        primaryAction = _submitPhoneNumber;
        primaryButtonText = 'Continue';
        break;
      case PhoneAuthState.detailsInput:
        titleText = 'Your Details (Optional)';
        currentContent = _buildDetailsInput();
        primaryAction = _submitDetailsAndSendOtp;
        primaryButtonText = 'Send OTP';
        break;
      case PhoneAuthState.otpInput:
        titleText = 'Enter Verification Code';
        currentContent = _buildOtpInput();
        primaryAction = _verifyOtp;
        primaryButtonText = 'Verify & Sign In';
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        titleText,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kPrimary, fontSize: 20),
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text(
              _state == PhoneAuthState.phoneInput
                  ? 'We\'ll send a code to verify your account.'
                  : (_state == PhoneAuthState.detailsInput
                  ? 'Add your name/email to personalize your account.'
                  : 'A code has been sent to $_phoneNumber.'),
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // Main Content Area
            currentContent,

            // Error Message Display
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage,
                  style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey.shade700),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isLoading ? null : primaryAction,
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : Text(
            primaryButtonText,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}