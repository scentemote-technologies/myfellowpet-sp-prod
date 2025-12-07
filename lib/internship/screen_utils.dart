class ScreenUtils {
  static double threshold = 0.0; // Static variable to hold the threshold

  // Method to initialize the threshold
  static void initializeThreshold(double screenWidth) {
    threshold = screenWidth - 100; // Calculate threshold based on initial screen width
  }
}
