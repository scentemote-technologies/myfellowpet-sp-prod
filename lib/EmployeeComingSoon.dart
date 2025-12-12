import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EmployeeComingSoon extends StatefulWidget {
  const EmployeeComingSoon({super.key});

  @override
  State<EmployeeComingSoon> createState() => _EmployeeComingSoonState();
}

class _EmployeeComingSoonState extends State<EmployeeComingSoon>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _iconAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _subtitleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconAnimation =
        CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4));
    _titleAnimation =
        CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.6));
    _subtitleAnimation =
        CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      body: Container(
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
                 // Title
                  FadeTransition(
                    opacity: _titleAnimation,
                    child: Text(
                      "Coming Soon",
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 32 : 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  FadeTransition(
                    opacity: _subtitleAnimation,
                    child: Text(
                      "This feature is not yet available.\nWe’re working on something amazing!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 16 : 18,
                        color: Colors.grey.shade200,
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
  }
}
