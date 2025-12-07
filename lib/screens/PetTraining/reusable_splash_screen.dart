import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class ReusableSplashScreen extends StatefulWidget {
  const ReusableSplashScreen({super.key});

  @override
  State<ReusableSplashScreen> createState() => _ReusableSplashScreenState();
}

class _ReusableSplashScreenState extends State<ReusableSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  double _progressValue = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    print("DEBUG_SPLASH: SplashScreen initState called."); // DEBUG PRINT
    _controller = AnimationController(vsync: this);

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue += 0.01;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel(); // Timer is correctly cancelled
        }
      });
    });
  }
  @override
  void dispose() {
    print("DEBUG_SPLASH: SplashScreen dispose called."); // DEBUG PRINT
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG_SPLASH: SplashScreen build method running."); // DEBUG PRINT
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/Loading.json',
              controller: _controller,
              height: isMobile ? 180 : 250,
              width: isMobile ? 180 : 250,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..forward()
                  ..repeat();
              },
            ),
            const SizedBox(height: 20),
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
            // ... rest of your UI
          ],
        ),
      ),
    );
  }
}