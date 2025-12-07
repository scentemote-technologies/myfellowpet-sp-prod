import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BoardingHomePage extends StatelessWidget {
  final List<String> galleryImages = [
    'assets/MSME.png',
    'assets/MSME.png',
    'assets/MSME.png',
    'assets/MSME.png',
  ];

  BoardingHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 280,
            collapsedHeight: 80,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Pet Sanctuary',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      )],
                  )),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/boarding_hero.jpg',
                      fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded),
                onPressed: () {},
              ),
            ],
          ),

          // Main Content
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Actions
                _buildQuickActions(),

                SizedBox(height: 40),

                // Categories
                SectionHeader(
                    title: "Boarding Types",
                    subtitle: "Find perfect stay for your pet"),
                SizedBox(height: 20),
                _buildCategoryGrid(),

                SizedBox(height: 40),

                // Top Providers
                SectionHeader(
                    title: "Featured Homes",
                    subtitle: "Top-rated boarding facilities"),
                SizedBox(height: 20),
                _buildProvidersGrid(),

                SizedBox(height: 40),

                // Gallery
                SectionHeader(
                    title: "Our Spaces",
                    subtitle: "See where your pet will stay"),
                SizedBox(height: 20),
                _buildGallery(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.date_range_rounded,
            label: "Book Now",
            color: Colors.teal,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _ActionChip(
            icon: Icons.video_camera_back_rounded,
            label: "Live Tour",
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'icon': Icons.home_work_rounded, 'label': 'Luxury Suites'},
      {'icon': Icons.grass_rounded, 'label': 'Outdoor Play'},
      {'icon': Icons.medication_rounded, 'label': 'Medical Care'},
      {'icon': Icons.group_rounded, 'label': 'Group Stays'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            SizedBox(width: 16),
            Icon(categories[index]['icon'] as IconData,
                color: Colors.teal),
            SizedBox(width: 12),
            Text(categories[index]['label'] as String,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorPlaceholder();
        if (!snapshot.hasData) return _LoadingGrid();

        final docs = snapshot.data!.docs;
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ProviderCard(
              name: data['shopName'] ?? 'Unnamed',
              image: data['shop_image'] ?? '',
              rating: 4.8,
              distance: 2.5,
            );
          },
        );
      },
    );
  }

  Widget _buildGallery() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: galleryImages.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.asset(galleryImages[index],
                    width: 280, fit: BoxFit.cover),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Text("Play Area ${index + 1}",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class ProviderCard extends StatelessWidget {
  final String name;
  final String image;
  final double rating;
  final double distance;

  const ProviderCard({
    Key? key,
    required this.name,
    required this.image,
    required this.rating,
    required this.distance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Overall container styling
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Image Section (takes 3 parts)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Show image from URL or a placeholder if empty
                  image.isNotEmpty
                      ? Image.network(
                    image,
                    fit: BoxFit.contain,
                    height: double.infinity,
                    width: double.infinity,
                  )
                      : const _ImagePlaceholder(),
                  // Positioned rating badge at the top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details Section (takes 2 parts)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${distance}km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Open Now',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(Icons.store, size: 40, color: Colors.grey[400]),
    );
  }
}

// ----------------- Helper Widgets -----------------
class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            )),
        SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            )),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}



class _ErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(height: 8),
            Text('Failed to load providers',
                style: GoogleFonts.poppins(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}