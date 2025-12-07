import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PawsomePetFoodSection extends StatelessWidget {
  const PawsomePetFoodSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // A bright red background
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Circular image of pet food
          Expanded(
            child: Center(
              child: ClipOval(
                child: Image.asset(
                  'assets/MSME.png', // Replace with your actual image asset
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
          // Right side: Heading, text, bullet points, and button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAWSOME PET FOOD',
                  style: GoogleFonts.sigmar(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'We offer all natural, healthy food and meal plans just for your pet. '
                      'Our vets work on recipes and portions designed specifically for your pet. '
                      'All delivered directly to your door, when you need it.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                // Bullet points
                _buildBulletPoint('Personalized Meal Plans for your pet'),
                _buildBulletPoint('All natural and healthy pet food'),
                _buildBulletPoint('Delivered directly to your door'),
                const SizedBox(height: 30),
                // CTA Button
                ElevatedButton(
                  onPressed: () {
                    // TODO: Handle button action
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'TAKE THE SURVEY',
                    style: GoogleFonts.sigmar(
                      fontSize: 16,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget to build a single bullet point row.
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}