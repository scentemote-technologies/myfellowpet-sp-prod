import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
class DaycareComingSoonPage extends StatefulWidget {
  const DaycareComingSoonPage({Key? key}) : super(key: key);

  @override
  State<DaycareComingSoonPage> createState() =>
      _DaycareComingSoonPageState();
}

class _DaycareComingSoonPageState extends State<DaycareComingSoonPage>
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
                    mainAxisSize: MainAxisSize.min, // ✅ shrink-wrap to content
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center, // ✅ horizontal center
                    children: [
                      // Animated Main Heading
                      _AnimatedFadeSlide(
                        animation: _titleAnimation,
                        child: Text(
                          'Payment Dashboard',
                          textAlign: TextAlign.center, // ✅ make sure text centers too
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
                          'Coming Soon',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: isMobile ? 16 : 22,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
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
