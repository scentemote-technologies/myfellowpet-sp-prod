import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class ReusableSplashScreen extends StatefulWidget {
  const ReusableSplashScreen({super.key});

  @override
  // Removed: with TickerProviderStateMixin
  State<ReusableSplashScreen> createState() => _ReusableSplashScreenState();
}

class _ReusableSplashScreenState extends State<ReusableSplashScreen> {
  // Removed: late final AnimationController _controller;
  double _progressValue = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    print("DEBUG_SPLASH: SplashScreen initState called.");

    // Timer logic is kept for the LinearProgressIndicator
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue += 0.01;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    print("DEBUG_SPLASH: SplashScreen dispose called.");
    // Removed: _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG_SPLASH: SplashScreen build method running.");
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      // Ensure the background color is the same as the web splash
      backgroundColor: const Color(0xFFF0F8F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // **FIX: Simplified Lottie.asset**
            Lottie.asset(
              // **CRITICAL: Verify this asset path is correct and matches pubspec.yaml**
              'assets/animations/Loading.json',
              // Removed: controller: _controller,
              height: isMobile ? 180 : 250,
              width: isMobile ? 180 : 250,
              repeat: true, // Ensures it loops
              // Removed: onLoaded callback logic
            ),
            const SizedBox(height: 20),
            // The "Loading..." text that sometimes appears with the warning icon
            const Text('Loading...'),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progressValue,
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2CB4B6)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}