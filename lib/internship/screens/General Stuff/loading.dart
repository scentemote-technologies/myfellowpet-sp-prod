import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: screenHeight * 0.5, // Adjust animation size manually
              child: Lottie.asset(
                'assets/loading.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20), // Space between animation and text
            AnimatedTextKit(
              repeatForever: true,
              animatedTexts: [
                TyperAnimatedText(
                  '.    .    .    Loading',
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  speed: const Duration(milliseconds: 300),
                ),
                TyperAnimatedText(
                  '.    .    .    Loading',
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  speed: const Duration(milliseconds: 300),
                ),
                TyperAnimatedText(
                  '.    .    .    Loading',
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  speed: const Duration(milliseconds: 300),
                ),
                TyperAnimatedText(
                  '.    .    .    Loading',
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  speed: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}