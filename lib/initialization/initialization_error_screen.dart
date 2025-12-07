import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:html' as html; // Required for the web-specific page reload

class InitializationErrorScreen extends StatelessWidget {
  // Your app's primary color
  static const Color primaryColor = Color(0xFF2CB4B6);

  const InitializationErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We wrap this in a MaterialApp to make it a self-contained screen
    // with proper text direction and theme defaults.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // A friendly, non-alarming icon
                Icon(
                  Icons.cloud_off_outlined,
                  size: 80,
                  color: primaryColor.withOpacity(0.8),
                ),
                const SizedBox(height: 24),

                // The main headline
                Text(
                  "Oops! We Hit a Snag",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // The encouraging subtext
                Text(
                  "We're having a little trouble connecting right now.\nPlease check your internet connection and give it another go.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // The "Try Again" button
                ElevatedButton(
                  onPressed: () {
                    // A full page reload is the cleanest way to retry initialization.
                    html.window.location.reload();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // Modern pill shape
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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