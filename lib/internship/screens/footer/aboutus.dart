import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wild About Us',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: const AboutUsPage(),
    );
  }
}

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({Key? key}) : super(key: key);

  @override
  _AboutUsPageState createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _textSlide;
  final ScrollController _scrollController = ScrollController();

  // Content variables
  String mission = "";
  String vision = "";
  String values = "";
  String email = '';
  String emailBody = '';
  String emailSubject = '';
  String emailUrl = '';
  String whatsappMessage = '';
  String whatsappUrl = '';
  String instagramProfileUrl = '';
  String linkedinProfileUrl = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutQuint,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));

    _fetchCompanyData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels > 300) {
      _controller.forward();
    }
  }

  Future<void> _fetchCompanyData() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('About Us')
          .get();

      if (docSnapshot.exists) {
        setState(() {
          mission = docSnapshot['mission'] ?? 'No mission available';
          vision = docSnapshot['vision'] ?? 'No vision available';
          values = docSnapshot['values'] ?? 'No values available';
          email = docSnapshot['email'] ?? 'No email available';
          emailBody = docSnapshot['email_body'] ?? 'No email body available';
          emailSubject = docSnapshot['email_subject'] ?? 'No email subject available';
          emailUrl = docSnapshot['email_url'] ?? 'No email URL available';
          whatsappMessage = docSnapshot['whatsapp_message'] ?? 'No message available';
          whatsappUrl = docSnapshot['whatsapp_url'] ?? 'No WhatsApp URL available';
          instagramProfileUrl = docSnapshot['instagram_profile_url'] ?? 'No Instagram URL available';
          linkedinProfileUrl = docSnapshot['linkedin_profile_url'] ?? 'No LinkedIn URL available';
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _launchWhatsApp() async {
    final url =
        'https://wa.me/$whatsappUrl?text=${Uri.encodeComponent(whatsappMessage)}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildModernAppBar(),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            _controller.forward();
          }
          return true;
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildHeroSection(),
            _buildContentSection(),
            _buildSocialSection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'About Us',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHeroSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 500,
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/bgm_main_about_us.jpg'),
            fit: BoxFit.cover,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Center(
          child: SlideTransition(
            position: _textSlide,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'About Us',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Creative. Bold. Inspiring.',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Color(0xFF414141),
                      letterSpacing: 1.2,
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

  SliverList _buildContentSection() {
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildSectionCard('🚀 Our Mission', mission),
        _buildSectionCard('👁️ Our Vision', vision),
        _buildSectionCard('💎 Our Values', values),
        _buildBrochureSection(),
      ]),
    );
  }

  Widget _buildSectionCard(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade100],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrochureSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Image.asset('assets/MSME.png', width: 200),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _downloadBrochure,
            icon: const Icon(Icons.download, size: 24, color: Colors.white,),
            label: const Text('Download Brochure'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade800,
              foregroundColor: Colors.white, // Set text color to white
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }


  SliverToBoxAdapter _buildSocialSection() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Text(
              'Connect With Us',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.indigo.shade800,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(FontAwesomeIcons.instagram, Colors.pink, instagramProfileUrl),
                _buildSocialButton(FontAwesomeIcons.linkedin, Colors.blue.shade800, linkedinProfileUrl),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Colors.green, // Green background
                  ),
                  child: IconButton(
                    icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.white),
                    onPressed: _launchWhatsApp,
                  ),
                ),

                _buildSocialButton(FontAwesomeIcons.envelope, Colors.red, 'mailto:$email'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FloatingActionButton(
        backgroundColor: color,
        onPressed: () => _launchURL(url),
        elevation: 4,
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _downloadBrochure() async {
    try {
      const filePath = 'BROCHURE.pdf';
      final storageRef = FirebaseStorage.instance.ref(filePath);
      final url = await storageRef.getDownloadURL();
      html.window.open(url, 'Download Brochure');
    } catch (e) {
      print('Error downloading brochure: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}