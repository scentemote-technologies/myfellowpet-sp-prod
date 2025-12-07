import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewsletterSection extends StatelessWidget {
  const NewsletterSection({Key? key}) : super(key: key);

  // Subscription function: saves the email to Firestore in the "subscribers" collection.
  Future<void> _subscribe(BuildContext context, TextEditingController emailController) async {
    String email = emailController.text.trim();
    if (email.isEmpty) return;

    // Check if the user is signed in.
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to subscribe.')),
      );
      return;
    }

    String docId = user.uid; // Use the user's UID as the document ID.
    try {
      await FirebaseFirestore.instance
          .collection('subscribers')
          .doc(docId)
          .set({'email': email});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscribed successfully!')),
      );
      emailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscription failed. Please try again.')),
      );
      print('Subscription error: $e');
    }
  }


  Widget _buildDesktopForm(TextEditingController emailController, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
        const SizedBox(width: 20),
        _buildSubscribeButton(emailController, context),
      ],
    );
  }

  Widget _buildMobileForm(TextEditingController emailController, BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSubscribeButton(emailController, context),
      ],
    );
  }

  Widget _buildSubscribeButton(TextEditingController emailController, BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          backgroundColor: const Color(0xFFFFD543),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        onPressed: () => _subscribe(context, emailController),
        child: Text(
          'Subscribe',
          style: GoogleFonts.marcellus(
            fontSize: 15,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    return Container(
      color: Colors.white.withOpacity(0.9),
      padding: EdgeInsets.symmetric(
        vertical: 80,
        horizontal: MediaQuery.of(context).size.width < 600 ? 20 : 40,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 600;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFD7B43B), Color(0xFFEC9248)],
                  stops: [0.3, 0.8],
                  transform: GradientRotation(0.785),
                ).createShader(bounds),
                child: Text(
                  'Stay Updated',
                  style: TextStyle(
                    fontSize: isMobile ? 36 : 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 40),
                child: Text(
                  'Subscribe to our newsletter for the latest pet care updates.',
                  style: GoogleFonts.marcellus(
                    fontSize: 15,
                    color: const Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              isMobile ? _buildMobileForm(emailController, context) : _buildDesktopForm(emailController, context),
            ],
          );
        },
      ),
    );
  }
}
