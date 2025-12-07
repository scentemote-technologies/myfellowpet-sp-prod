import 'package:flutter/material.dart';

import '../../fullscreenchecker.dart';

class CourseCompletionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FullscreenCheckWrapper(
      child: Scaffold(
        backgroundColor: Colors.white, // White background for a modern feel
        appBar: AppBar(
          backgroundColor: Colors.black, // Black AppBar for contrast
          title: Text(
            'Course Completion',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white), // Back button
            onPressed: () {
              Navigator.pop(context); // Navigate back
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Heading
                Text(
                  "Congratulations!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),

                // Subheading with message
                Text(
                  "You have successfully completed the course. Your dedication and hard work have been truly commendable!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 40),

                // Instruction message
                Text(
                  "Please be patient while the admin assigns your project work. You will be notified once the task is ready for you.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 60),

                // Footer Text
                Text(
                  "Thank you for being a part of our learning community.",
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),

                // Go Back Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Navigate back to the previous screen
                  },
                  child: Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.black, // Text color
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
