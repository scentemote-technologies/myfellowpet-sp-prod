import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'ExploreOurStory.dart';

class BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.7, 0);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.1, size.width, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.6, size.width * 0.7, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.4, size.height, size.width * 0.2, size.height * 0.8);
    path.quadraticBezierTo(0, size.height * 0.6, 0, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.1, size.width * 0.3, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class WeArePawsomeSection extends StatelessWidget {
  const WeArePawsomeSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 0,
        horizontal: 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;

          if (screenWidth > 1440) {
            return _buildDesktopLayout(context);
          } else if (screenWidth > 1024) {
            return _buildLaptopLayout(context);
          } else if (screenWidth > 600) {
            return _buildTabletLayout(context);
          } else {
            return _buildMobileLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(responsiveValue(context, 0, 0, 0, 0)),
            child: _ContentSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildLaptopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: _ContentSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(25),
          child: _ContentSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: _ContentSection(),
        ),
      ],
    );
  }

  double responsiveValue(BuildContext context,
      double mobile, double tablet, double laptop, double desktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1440) return desktop;
    if (screenWidth > 1024) return laptop;
    if (screenWidth > 600) return tablet;
    return mobile;
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fetch dynamic content from Firestore document "WhatWeDo"
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('company_documents')
          .doc('WhatWeDo')
          .get(),
      builder: (context, snapshot) {
        // Fallback hardcoded values
        String title = "Your Pet's Happiness,\nOur Ultimate Mission";
        String description = "We understand that pets are family. Our innovative approach combines cutting-edge technology "
            "with genuine love for animals to create products that truly make a difference.";
        String buttonText = "Explore Our Story";

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          title = data['title'] ?? title;
          description = data['description'] ?? description;
          buttonText = data['buttonText'] ?? buttonText;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(responsiveValue(context, 0, 0, 0, 0)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: responsiveValue(context, 5, 7, 10, 12),
              sigmaY: responsiveValue(context, 5, 7, 10, 12),
            ),
            child: Container(
              padding: EdgeInsets.all(responsiveValue(context, 16, 20, 24, 28)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(1),
                borderRadius: BorderRadius.circular(responsiveValue(context, 0, 0, 0, 0)),
                border: Border.all(color: Colors.white.withOpacity(1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Wrap title text with horizontal padding.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.marcellus(
                        fontSize: responsiveValue(context, 24, 30, 36, 42),
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: responsiveValue(context, 20, 25, 30, 35)),
                  // Wrap description text with horizontal padding.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isMobile = constraints.maxWidth < 600;
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? constraints.maxWidth * 0.9 : 1000,
                            ),
                            child: Text(
                              description,
                              style: GoogleFonts.marcellus(
                                fontSize: responsiveValue(context, 14, 16, 18, 20),
                                height: 1.8,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w400,
                              ),
                              softWrap: true,
                              textAlign: isMobile ? TextAlign.center : TextAlign.justify,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: responsiveValue(context, 20, 25, 30, 35)),
                  Column(
                    children: [
                      const SizedBox(height: 20),
                      _ModernButton(buttonText: buttonText), // Pass dynamic button text
                      const SizedBox(height: 20),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double responsiveValue(BuildContext context,
      double mobile, double tablet, double laptop, double desktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1440) return desktop;
    if (screenWidth > 1024) return laptop;
    if (screenWidth > 600) return tablet;
    return mobile;
  }
}

class _ModernButton extends StatefulWidget {
  final String buttonText;
  const _ModernButton({Key? key, required this.buttonText}) : super(key: key);

  @override
  State<_ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<_ModernButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final scale = isMobile ? 1.0 : (_isHovered ? 1.05 : 1.0);

    return MouseRegion(
      onEnter: (_) {
        if (!isMobile) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!isMobile) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReadOurStory()),
          );
        },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isMobile ? double.infinity : null,
            constraints: BoxConstraints(
              minWidth: isMobile ? 0 : 160,
              minHeight: isMobile ? 0 : 50,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 40,
              vertical: isMobile ? 12 : 18,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered
                    ? [const Color(0xFF6A82FB), const Color(0xFFFC5C7D)]
                    : [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 20 : 30),
              boxShadow: _isHovered && !isMobile
                  ? [
                BoxShadow(
                  color: Colors.pinkAccent.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 15),
                )
              ]
                  : [],
            ),
            child: Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile)
                  const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                if (!isMobile) const SizedBox(width: 12),
                Text(
                  widget.buttonText,
                  textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
