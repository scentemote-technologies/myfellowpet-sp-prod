import 'dart:ui';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myfellowpet_sp/internship/screens/projects/all_projects.dart';
import 'package:myfellowpet_sp/internship/screens/projects/project_detail.dart';
import 'package:myfellowpet_sp/internship/screens/projects/project_grid_view.dart';

// Import your custom screens/widgets.
import 'package:shimmer/shimmer.dart';
import '../../screens/Footer/footercompanypage.dart';
import 'Courses Page/CoursesPage.dart';
import 'Internship Page/InternshipPage.dart';
import 'Profile/profile_page.dart';
import 'course grid view/course_grid_view.dart';
import 'course materials/user_course_materials.dart';
import 'courses/course_detail.dart';
import 'footer/aboutus.dart';
import 'footer/main_footer.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

// Responsive helper function
double responsiveValue(BuildContext context,
    double mobile, double tablet, double laptop, double desktop) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 1440) return desktop;
  if (screenWidth > 1024) return laptop;
  if (screenWidth > 600) return tablet;
  return mobile;
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late Future<List<Map<String, String>>> imgList;
  String searchQuery = "";
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Add this at the top of your widget class
  final List<Map<String, dynamic>> _drawerItems = [
    {
      'icon': Icons.school,
      'title': 'Courses',
      'page': CourseGrid(),
    },
    {
      'icon': Icons.code,
      'title': 'Projects',
      'page': AllProjectsPage(),
    },
    {
      'icon': Icons.work,
      'title': 'Internship',
      'page': InternshipPage(),
    },
    {
      'icon': Icons.info,
      'title': 'Course Materials',
      'page': UserCourseMaterials(uid: FirebaseAuth.instance.currentUser!.uid),
    },
  ];

  @override
  void initState() {
    super.initState();
    imgList = _fetchInternshipImages();
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _scaleController.forward();
  }

  // Retrieve internship images from Firestore (for the hero carousel)
  Future<List<Map<String, String>>> _fetchInternshipImages() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('internships').get();
    List<Map<String, String>> courseData = [];
    for (var doc in snapshot.docs) {
      // Safely extract the first image from the 'image_url' array
      String firstImageUrl = (doc['image_url'] as List).isNotEmpty
          ? doc['image_url'][0]
          : '';
      courseData.add({
        'image_url': firstImageUrl, // Add the first image URL
        'title': doc['title'], // Add the title
      });
    }
    return courseData;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallOrTabletScreen = MediaQuery.of(context).size.width < 1110;

    // Wrap your Scaffold with a StreamBuilder listening to auth state changes.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // snapshot.data is the current user, or null if signed out.
        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          appBar: _buildModernAppBar(context, isSmallOrTabletScreen),
          drawer: isSmallOrTabletScreen ? _buildModernDrawer() : null,
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                _scaleController.forward();
              }
              return true;
            },
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) => Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
              child: CustomScrollView(
                slivers: [
                  if (isSmallOrTabletScreen) ...[
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildSearchBarFullWidth(),
                      ),
                    ),
                    if (searchQuery.isNotEmpty) ...[
                      _buildCoursesSearchResults(),
                      _buildProjectsSearchResults(),
                    ] else ...[
                      _buildHeroSection(),
                      _buildSectionHeader('Featured Certifications', context),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: CourseGridView(searchQuery: searchQuery),
                        ),
                      ),
                      _buildSectionHeader('Academic Projects', context),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: ProjectGridView(searchQuery: searchQuery),
                        ),
                      ),
                      SliverToBoxAdapter(child: CompanyFooterSection()),
                    ],
                  ] else ...[
                    if (searchQuery.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "Courses",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: responsiveValue(context, 20, 24, 28, 32),
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                          child: CourseGridView(searchQuery: searchQuery),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            "Projects",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: responsiveValue(context, 20, 24, 28, 32),
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                          child: ProjectGridView(searchQuery: searchQuery),
                        ),
                      ),
                    ] else ...[
                      _buildHeroSection(),
                      _buildSectionHeader('Featured Certifications', context),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: CourseGridView(searchQuery: searchQuery),
                        ),
                      ),
                      _buildSectionHeader('Academic Projects', context),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: ProjectGridView(searchQuery: searchQuery),
                        ),
                      ),
                      SliverToBoxAdapter(child: CompanyFooterSection()),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  // Build a SliverList of horizontal search result tiles for courses.
  // Updated horizontal tile builder that accepts an onTap callback.
  Widget _buildHorizontalSearchTile({
    required String title,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Title on the left
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12, // very small font size
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Image on the right
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

// Build a SliverList of horizontal search result tiles for courses.
  Widget _buildCoursesSearchResults() {
    return SliverToBoxAdapter(
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('courses').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final courses = snapshot.data!.docs.where((course) {
            final data = course.data() as Map<String, dynamic>;
            bool display = data.containsKey('display') && data['display'] == true;
            final name = course.id.toLowerCase();
            return display && name.contains(searchQuery.toLowerCase());
          }).toList();
          if (courses.isEmpty) return const SizedBox();
          return Column(
            children: courses.map((course) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildHorizontalSearchTile(
                  title: course.id,
                  imageUrl: course['image_url'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseDetailPage(
                          courseName: course.id,
                          imageUrl: course['image_url'],
                          description: course['description'] ?? 'No description available',
                          sectionIds: [], // You may fetch sections or pass an empty list.
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

// Build a SliverList of horizontal search result tiles for projects.
  Widget _buildProjectsSearchResults() {
    return SliverToBoxAdapter(
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('projects').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final projects = snapshot.data!.docs.where((project) {
            final name = (project['projectName'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();
          if (projects.isEmpty) return const SizedBox();
          return Column(
            children: projects.map((project) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _buildHorizontalSearchTile(
                  title: project['projectName'] ?? project.id,
                  imageUrl: (project['imageUrls'] as List).isNotEmpty ? project['imageUrls'][0] : '',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectDetailPage(
                          projectId: project.id,
                          imageUrl: (project['imageUrls'] as List).isNotEmpty ? project['imageUrls'][0] : '',
                          description: project['projectDescription'] ?? 'No description available',
                          projectName: project['projectName'] ?? project.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }


// Builds a horizontal tile with the title on the left and image on the right.



  AppBar _buildModernAppBar(BuildContext context, bool isSmallScreen) {
    // Check if the current route can be popped.
    final bool canPop = Navigator.canPop(context);

    if (isSmallScreen) {
      return AppBar(
        backgroundColor: Colors.white.withOpacity(0.97),
        elevation: 4,
        leadingWidth: 100,
        leading: Row(
          children: [
            if (canPop)
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: Colors.black87, size: 26),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ],
        ),
        title: Center(
          child: Hero(
            tag: 'logo',
            child: Image.asset(
              'logotrans.png',
              height: 32,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildUserAvatar(context),
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: Colors.white.withOpacity(0.97),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        toolbarHeight: 88,
        leadingWidth: 100,
        leading: Row(
          children: [
            if (canPop)
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.black87, size: 26),
                onPressed: () => Navigator.pop(context),
              ),

          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Hero(
              tag: 'logo',
              child: Image.asset(
                'logotrans.png',
                height: 40,
              ),
            ),
            _buildNavButton('Courses', CourseGrid()),
            _buildNavButton('Projects', AllProjectsPage()),
            _buildNavButton('Internship', InternshipPage()),
            _buildNavButton('Course Materials', UserCourseMaterials(uid: FirebaseAuth.instance.currentUser!.uid)),
            SizedBox(
              width: 300,
              child: _buildSearchBar(),
            ),
            _buildUserAvatar(context),
          ],
        ),
      );
    }
  }




  /// A full-width search bar for small/tablet screens.
  Widget _buildSearchBarFullWidth() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search courses, projects...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: responsiveValue(context, 14, 15, 16, 17),
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
    );
  }


  Widget _buildUserAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // Sign in if not already signed in.
          User? signedInUser = await _signInWithGoogle(context);
          if (signedInUser != null) {
            await _storeUserDetails(signedInUser);
          }
        } else {
          // Navigate to ProfilePage if signed in.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage(uid: user.uid)),
          );
        }
      },
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[200],
        child: FirebaseAuth.instance.currentUser?.photoURL != null
            ? ClipOval(
          child: Image.network(
            FirebaseAuth.instance.currentUser!.photoURL!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        )
            : Icon(Icons.account_circle,
            color: Colors.black,
            size: responsiveValue(context, 24, 26, 28, 30)),
      ),
    );
  }
  bool _isActive(Widget page) => false;

  Widget _buildSearchBar() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 480, minWidth: 120),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search courses, projects...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: responsiveValue(context, 14, 15, 16, 17),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHoverIcon({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.all(10),
          child: Icon(icon, color: Colors.black87, size: 26),
        ),
      ),
    );
  }

  Widget _buildNavButton(String label, Widget page) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TextButton(
        onPressed: () => _handleNavigation(page),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          // Always show the underline by setting the blue bottom border.
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.blueAccent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: responsiveValue(context, 15, 16, 17, 18),
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildModernDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7,
      elevation: 16,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: ListView(
        padding: EdgeInsets.only(top: 24),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    )),
                Divider(height: 36, color: Colors.grey.shade100),
              ],
            ),
          ),
          ..._drawerItems.map((item) => ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: Icon(item['icon'], color: Colors.grey.shade700, size: 22),
            title: Text(item['title'],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                )),
            onTap: () => _handleNavigation(item['page']),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )),
        ],
      ),
    );
  }

  Future<User?> _signInWithGoogle(BuildContext context) async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final GoogleSignIn _googleSignIn = GoogleSignIn(
      clientId: "1061644693775-ne1i44hes0e8gq57uu76ditl3biim01j.apps.googleusercontent.com", // Replace with your actual client ID.
    );
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) {
        googleUser = await _googleSignIn.signIn();
      }
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Trigger a rebuild so that the updated profile picture is shown.
        setState(() {});
      }
      return user;
    } catch (e) {
      print('Error during Google sign-in: $e');
      return null;
    }
  }


  Future<void> _storeUserDetails(User user) async {
    final userDocRef =
    FirebaseFirestore.instance.collection('web-users').doc(user.uid);
    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      await userDocRef.set({
        'email': user.email,
        'photoURL': user.photoURL,
        'uid': user.uid,
        'displayName': user.displayName ?? "No Name",
      });
      print("User data stored in Firestore.");
    } else {
      print("User already exists in Firestore.");
    }
  }

  void _handleNavigation(Widget page) {
    if (!isUserLoggedIn()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to access this feature',
            style: GoogleFonts.poppins(
              fontSize: responsiveValue(context, 14, 16, 18, 20),
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  bool isUserLoggedIn() => FirebaseAuth.instance.currentUser != null;

  // ----------------------- UI Sections -----------------------

  SliverToBoxAdapter _buildHeroSection() {
    return SliverToBoxAdapter(
      child: Container(
        constraints: BoxConstraints(minHeight: 500, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: isMobile ? 40 : 0,
              ),
              child: Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: isMobile ? 0 : 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: isMobile
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Launch Your Career",
                          textAlign:
                          isMobile ? TextAlign.center : TextAlign.left,
                          style: GoogleFonts.poppins(
                            fontSize:
                            responsiveValue(context, 32, 40, 48, 56),
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        Text(
                          "Discover curated internships, real-world projects, and professional courses to accelerate your career growth.",
                          textAlign:
                          isMobile ? TextAlign.center : TextAlign.left,
                          style: GoogleFonts.poppins(
                            fontSize:
                            responsiveValue(context, 16, 18, 20, 22),
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                        ),
                        SizedBox(height: isMobile ? 24 : 40),
                        _buildAnimatedButton(isMobile: isMobile),
                      ],
                    ),
                  ),
                  if (!isMobile) SizedBox(width: 40),
                  if (!isMobile)
                    Flexible(
                        flex: 1, child: _buildInternshipCarousel()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({bool isMobile = false}) {
    return ElevatedButton(
      onPressed: () => _handleNavigation(InternshipPage()),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 40,
          vertical: isMobile ? 16 : 20,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      child: Text(
        "Explore Opportunities",
        style: GoogleFonts.poppins(
          fontSize: responsiveValue(context, 14, 16, 18, 20),
          fontWeight: FontWeight.w600,
          color: Color(0xFF6366F1),
        ),
      ),
    );
  }

  Widget _buildInternshipCarousel() {
    return FutureBuilder<List<Map<String, String>>>(
      future: imgList,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: _buildShimmerEffect());

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 600;
            return CarouselSlider.builder(
              itemCount: snapshot.data!.length,
              options: CarouselOptions(
                height: isMobile ? 180 : 240,
                viewportFraction: isMobile ? 0.8 : 0.5,
                autoPlay: true,
                enlargeCenterPage: true,
                autoPlayInterval: Duration(seconds: 3),
                autoPlayCurve: Curves.easeInOutCubic,
                enableInfiniteScroll: true,
              ),
              itemBuilder: (context, index, _) {
                final item = snapshot.data![index];
                return Container(
                  margin: EdgeInsets.all(isMobile ? 8 : 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Image.network(
                          item['image_url']!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildShimmerEffect();
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7)
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 15,
                          left: 15,
                          right: 15,
                          child: Text(
                            item['title']!,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize:
                              responsiveValue(context, 14, 16, 18, 20),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }

  SliverPadding _buildSectionHeader(String title, BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: [
            Text(
              title,
              textAlign: TextAlign.center, // Center the text within its container
              style: GoogleFonts.poppins(
                fontSize: responsiveValue(context, 20, 24, 28, 32), // Adjusted responsive font sizes
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 100,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
