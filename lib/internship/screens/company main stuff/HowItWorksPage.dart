import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_grid/responsive_grid.dart';

class FurristoWorksSection extends StatelessWidget {
  const FurristoWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('company_documents')
          .doc('HowItWorks')
          .get(),
      builder: (context, snapshot) {
        // Fallback hardcoded values
        String sectionTitle = 'HOW WE WORK';
        String sectionDescription =
            'We are the First Pet Wellness Brand dedicated to keeping your pet healthy, happy and safe. We bring you recommendations based on your pet’s lifestyle, breed, age and personal needs to personalize their diet, vet experience, training, grooming and health insurance offerings. We offer personalized experiences in:';
        List<Map<String, dynamic>> features = [
          {
            'image': 'marketplace.jpg',
            'title': 'Unified Marketplace',
            'description': 'Find boarding, grooming, vet care, and more—all in one place.',
          },
          {
            'image': 'Personalized.webp',
            'title': 'Personalized Matching',
            'description': 'Tailored recommendations based on your pet’s unique needs.',
          },
          {
            'image': 'seemlessbooking.webp',
            'title': 'Seamless Booking',
            'description': 'Effortless scheduling and management for all pet services.',
          },
          {
            'image': 'verified.webp',
            'title': 'Verified Quality',
            'description': 'Curated providers with trusted reviews ensuring top care.',
          },
        ];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          sectionTitle = data['title'] ?? sectionTitle;
          sectionDescription = data['description'] ?? sectionDescription;
          if (data['features'] != null && data['features'] is List) {
            final List featuresList = data['features'];
            if (featuresList.length >= 4) {
              features = featuresList.map<Map<String, dynamic>>((e) {
                if (e is Map<String, dynamic>) {
                  return {
                    'image': e['image'] ?? 'marketplace.jpg',
                    'title': e['title'] ?? 'Unified Marketplace',
                    'description': e['description'] ??
                        'Find boarding, grooming, vet care, and more—all in one place.',
                  };
                }
                return {};
              }).toList();
            }
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 0),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Wrap the title with responsive horizontal padding.
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsiveValue(context, 20, 30, 40, 50),
                  ),
                  child: Text(
                    sectionTitle,
                    style: GoogleFonts.marcellus(
                      fontSize: responsiveValue(context, 24, 30, 36, 42),
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 2.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 5),
                // Wrap the description with responsive horizontal padding.
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsiveValue(context, 20, 30, 40, 50),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      bool isMobile = constraints.maxWidth < 600;
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? constraints.maxWidth * 0.9 : 1000,
                          ),
                          child: Text(
                            sectionDescription,
                            style: GoogleFonts.marcellus(
                              fontSize: responsiveValue(context, 14, 16, 18, 20),
                              color: const Color(0xFF1A1A1A),
                            ),
                            softWrap: true,
                            textAlign: isMobile ? TextAlign.center : TextAlign.justify,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                _buildFeaturesGrid(features),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeaturesGrid(List<Map<String, dynamic>> features) {
    return ResponsiveGridRow(
      children: features.map((feature) {
        return ResponsiveGridCol(
          xs: 12,
          md: 6,
          xl: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _FeatureCard(
              image: feature['image'],
              title: feature['title'],
              description: feature['description'],
            ),
          ),
        );
      }).toList(),
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

class _FeatureCard extends StatefulWidget {
  final String image;
  final String title;
  final String description;

  const _FeatureCard({
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  __FeatureCardState createState() => __FeatureCardState();
}

class __FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Use NetworkImage if the image string starts with "http", otherwise use AssetImage.
    final bool isRemote = widget.image.trim().toLowerCase().startsWith('http');
    final ImageProvider imageProvider =
    isRemote ? NetworkImage(widget.image) : AssetImage(widget.image);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _isHovered
                ? [
              BoxShadow(
                color: const Color(0xFFFFC107).withOpacity(0.4),
                spreadRadius: 4,
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ]
                : [],
            border: Border.all(
              color: const Color(0xFFFFFFFF).withOpacity(0.5),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: GoogleFonts.marcellus(
                  fontSize: responsiveValue(context, 24, 24, 24, 24),
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.description,
                style: GoogleFonts.marcellus(
                  fontSize: responsiveValue(context, 18, 18, 18, 18),
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
