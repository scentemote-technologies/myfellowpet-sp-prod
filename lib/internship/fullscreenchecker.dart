import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'screen_utils.dart'; // Import the ScreenUtils class

class FullscreenCheckWrapper extends StatelessWidget {
  final Widget child;

  FullscreenCheckWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    // Get the current screen width
    double screenWidth = MediaQuery.of(context).size.width;

    // Check if the screen width is less than 870
    if (screenWidth < 870) {
      return Scaffold(
        backgroundColor: Colors.blueGrey[50],
        body: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 4,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fullscreen,
                  color: Colors.black,
                  size: 70,
                ),
                SizedBox(height: 20),
                Text(
                  "For the best experience, please switch to fullscreen mode.",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  "This application is currently optimized for desktops and laptops. Mobile support is coming soon.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    }

    // If screen width is greater than or equal to 870, use the pre-calculated threshold from ScreenUtils
    double threshold = ScreenUtils.threshold;

    // Check if it's a web platform and if the screen width is below the threshold
    if (kIsWeb && screenWidth < threshold) {
      return Scaffold(
        backgroundColor: Colors.blueGrey[50],
        body: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 4,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fullscreen,
                  color: Colors.black,
                  size: 70,
                ),
                SizedBox(height: 20),
                Text(
                  "For the best experience, please switch to fullscreen mode.",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  "This application is currently optimized for desktops and laptops. Mobile support is coming soon.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    }

    // If the screen width is above the threshold, return the child widget
    return child;
  }
}
