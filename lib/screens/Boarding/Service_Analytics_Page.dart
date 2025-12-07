import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';


import 'charts/boarding_requests_chart.dart';
import 'charts/raw_line_chart.dart';
// A constant for your primary color to avoid repetition
const Color primaryColor = Color(0xFF2CB4B6);

// An enum to manage the different states of the page
enum PageState { loading, comingSoon, needsSubscription, showAnalytics }

class ServiceAnalyticsPage extends StatefulWidget {
  final String serviceId;
  const ServiceAnalyticsPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _ServiceAnalyticsPageState createState() => _ServiceAnalyticsPageState();
}

class _ServiceAnalyticsPageState extends State<ServiceAnalyticsPage> {
  // State management variables
  PageState _pageState = PageState.loading;
  Map<String, dynamic>? _settingsData;
  List<QueryDocumentSnapshot> _bookings = [];
  List<QueryDocumentSnapshot> _requests = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  /// Handles the multi-step data fetching and validation process.
  Future<void> _initializePage() async {
    // 1. Check global settings first
    final settingsSnap = await FirebaseFirestore.instance
        .collection('settings')
        .doc('performance_monitors')
        .get();

    if (!settingsSnap.exists || (settingsSnap.data()?['status'] != true)) {
      if (mounted) {
        setState(() => _pageState = PageState.comingSoon);
      }
      return;
    }

    // 2. If global status is true, check user's subscription
    final userSnap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .get();

    if (!userSnap.exists || (userSnap.data()?['mfp_certified'] != true)) {
      if (mounted) {
        setState(() => _pageState = PageState.needsSubscription);
      }
      return;
    }

    // 3. If all checks pass, fetch the analytics data
    final bookingsSnap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('completed_orders')
        .get();

    final requestsSnap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('cancelled_requests')
        .get();

    if (mounted) {
      setState(() {
        _bookings = bookingsSnap.docs;
        _requests = requestsSnap.docs;
        _settingsData = settingsSnap.data();
        _pageState = PageState.showAnalytics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildContent(),
    );
  }

  /// Builds the appropriate UI based on the current page state.
  Widget _buildContent() {
    switch (_pageState) {
      case PageState.loading:
        return const Center(child: CircularProgressIndicator(color: primaryColor));
      case PageState.comingSoon:
        return const PerformanceMonitorComingSoonPage();
      case PageState.needsSubscription:
        return _buildSubscriptionPrompt();
      case PageState.showAnalytics:
        return _buildAnalyticsPage();
    }
  }

  /// The main analytics view with the NavigationRail and charts.
  Widget _buildAnalyticsPage() {
    final data = _settingsData!;
    final showTrend = data['booking_trend'] == true;
    final showCancelled = data['cancelled_requests'] == true;

    final destinations = <NavigationRailDestination>[];
    if (showTrend) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.bar_chart),
          label: Text('Booking Trend'),
        ),
      );
    }
    if (showCancelled) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.cancel_outlined),
          label: Text('Cancelled Requests'),
        ),
      );
    }

    if (destinations.isEmpty) {
      return const Center(child: Text('No analytics modules are currently enabled.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile layout with BottomNavigationBar
          return Scaffold(

            body: Padding(
              padding: const EdgeInsets.only(top: 16.0), // Adds padding below the app bar
              child: _buildSelectedPage(showTrend, showCancelled),
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: Colors.white,
                  indicatorColor: Colors.transparent, // remove pill
                  elevation: 8, // adds subtle shadow like BottomNavigationBar
                  height: 60, // tighter height
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  iconTheme: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return IconThemeData(color: primaryColor);
                    }
                    return IconThemeData(color: Colors.grey.shade600);
                  }),
                  labelTextStyle: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      );
                    }
                    return GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    );
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
                onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                destinations: destinations.map((d) {
                  return NavigationDestination(
                    icon: d.icon,
                    selectedIcon: d.icon, // already styled via theme
                    label: (d.label as Text).data!,
                  );
                }).toList(),
              ),
            ),

          );
        }
        else {
          // Tablet and Desktop layout with NavigationRail
          return Row(
            children: [
              NavigationRailTheme(
                data: NavigationRailThemeData(
                  backgroundColor: Colors.white,
                  selectedIconTheme: const IconThemeData(color: primaryColor),
                  unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
                  selectedLabelTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                  unselectedLabelTextStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                  labelType: NavigationRailLabelType.all,
                ),
                child: NavigationRail(
                  selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  destinations: destinations,
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSelectedPage(showTrend, showCancelled),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  /// A message prompting the user to subscribe to access the feature.
  Widget _buildSubscriptionPrompt() {
    return const SubscriptionPromptPage();
  }

  /// Dynamically determines which page to show based on settings and index.
  Widget _buildSelectedPage(bool showTrend, bool showCancelled) {
    // This logic maps the visible destinations to the selected index
    int currentVisibleIndex = 0;
    if (showTrend && _selectedIndex == currentVisibleIndex++) {
      return _buildBookingTrendPage();
    }
    if (showCancelled && _selectedIndex == currentVisibleIndex) {
      return _buildCancelledRequestsPage();
    }

    // Fallback if the index is somehow out of sync
    return _buildBookingTrendPage();
  }

  Widget _buildBookingTrendPage() {
    return ListView(
      children: [

        BookingTrendChart(data: _bookings),
      ],
    );
  }

  Widget _buildCancelledRequestsPage() {
    return ListView(
      children: [

       RequestsTrendChart(cancelledRequests: _requests),
      ],
    );
  }


}

class PerformanceMonitorComingSoonPage extends StatefulWidget {
  const PerformanceMonitorComingSoonPage({Key? key}) : super(key: key);

  @override
  State<PerformanceMonitorComingSoonPage> createState() =>
      _PerformanceMonitorComingSoonPageState();
}

class _PerformanceMonitorComingSoonPageState extends State<PerformanceMonitorComingSoonPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _subtitleAnimation;
  late Animation<double> _socialsAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller setup
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Staggered animation setup
    _iconAnimation = _createAnimation(0.0, 0.5);
    _titleAnimation = _createAnimation(0.25, 0.65);
    _subtitleAnimation = _createAnimation(0.5, 0.8);
    _socialsAnimation = _createAnimation(0.75, 1.0);

    // Start the animation
    _controller.forward();
  }

  // Helper function to create curved animations with intervals
  Animation<double> _createAnimation(double begin, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder for responsive UI adjustments
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          body: Container(
            // Recreating the background gradient
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2DD4BF), Color(0xFF136C61)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon
                      _AnimatedFadeSlide(
                        animation: _iconAnimation,
                        child: FaIcon(
                          FontAwesomeIcons.hourglassHalf,
                          size: isMobile ? 70 : 80,
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animated Main Heading
                      _AnimatedFadeSlide(
                        animation: _titleAnimation,
                        child: Text(
                          'Coming Soon!',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 32 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Animated Subheading
                      _AnimatedFadeSlide(
                        animation: _subtitleAnimation,
                        child: Text(
                          'Performance analytics are under development and will be available shortly.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Animated Social Links
                      _AnimatedFadeSlide(
                        animation: _socialsAnimation,
                        child: Column(
                          children: [
                            Text(
                              'Stay tuned for updates!',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialIcon(icon: FontAwesomeIcons.whatsapp),
                                _SocialIcon(icon: FontAwesomeIcons.instagram),
                                _SocialIcon(icon: FontAwesomeIcons.linkedinIn),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// A reusable widget for the fade and slide animation
class _AnimatedFadeSlide extends StatelessWidget {
  const _AnimatedFadeSlide({
    Key? key,
    required this.animation,
    required this.child,
  }) : super(key: key);

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

// A reusable widget for social media icons
class _SocialIcon extends StatelessWidget {
  const _SocialIcon({Key? key, required this.icon}) : super(key: key);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: FaIcon(
        icon,
        color: Colors.grey.shade400,
        size: 28,
      ),
    );
  }
}

class SubscriptionPromptPage extends StatefulWidget {
  const SubscriptionPromptPage({Key? key}) : super(key: key);

  @override
  State<SubscriptionPromptPage> createState() =>
      _SubscriptionPromptPageState();
}

class _SubscriptionPromptPageState extends State<SubscriptionPromptPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _subtitleAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller setup
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Staggered animation setup, matching the delays from the CSS
    _iconAnimation = _createAnimation(0.0, 0.5); // 0s delay
    _titleAnimation = _createAnimation(0.15, 0.65); // ~0.3s delay
    _subtitleAnimation = _createAnimation(0.3, 0.8); // ~0.6s delay
    _buttonAnimation = _createAnimation(0.45, 0.95); // ~0.9s delay

    // Start the animation
    _controller.forward();
  }

  // Helper function to create curved animations with specific intervals
  Animation<double> _createAnimation(double begin, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder ensures the UI is responsive to screen size changes
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          body: Container(
            // Recreating the background gradient from the HTML
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF209183), Color(0xFF50C4B5), Color(0xFF209183)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Premium Icon
                      _AnimatedFadeSlide(
                        animation: _iconAnimation,
                        child: FaIcon(
                          FontAwesomeIcons.gem,
                          size: isMobile ? 70 : 80,
                          color: const Color(0xFFF67B0D), // amber-400
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animated Main Heading
                      _AnimatedFadeSlide(
                        animation: _titleAnimation,
                        child: Text(
                          'Subscription Required',
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 32 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Animated Subheading
                      _AnimatedFadeSlide(
                        animation: _subtitleAnimation,
                        child: Text(
                          'Access to performance analytics is a premium feature. Please subscribe to unlock this page.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 18,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Animated Subscribe Button
                      _AnimatedFadeSlide(
                        animation: _buttonAnimation,
                        child: ElevatedButton.icon(
                          icon: const FaIcon(FontAwesomeIcons.star, size: 18, color: Colors.white,),
                          label: Text(
                            'Subscribe Now',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () {
                            // Navigation to subscription page goes here
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF67B0D), // amber-500
                            foregroundColor: const Color(0xFF111827), // gray-900
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}