import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../certificate/certificate_generator.dart';
import '../internship_dashboard/internship_details.dart';
import '../internship_dashboard/internship_overview.dart';
import 'course_thank_you.dart';
import 'internship_certificate.dart';

class InternshipProgressPage extends StatefulWidget {
  final String courseName;
  final String internship_name;

  InternshipProgressPage({required this.courseName, required this.internship_name});

  @override
  _InternshipProgressPageState createState() => _InternshipProgressPageState();
}

class _InternshipProgressPageState extends State<InternshipProgressPage> {
  int totalSections = 0;
  bool isLoading = true;
  String currentUserId = '';
  String displayName = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  // Fetch the current user UID
  Future<void> _getCurrentUserId() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
        });
        await _getDisplayName(user.uid);  // Fetch the displayName after userId is set
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No user is logged in.")),
        );
      }
    } catch (e) {
      print("Error fetching user UID: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch the display name from Firestore
  Future<void> _getDisplayName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('web-users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          displayName = userDoc.get('displayName') ?? 'User';
          isLoading = false;  // Set loading to false once the name is fetched
        });
      } else {
        setState(() {
          displayName = 'User';  // Default name if not found
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching display name: $e");
      setState(() {
        displayName = 'User';  // Default name if error occurs
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // If the user is not logged in, show a simple message
    if (userId.isEmpty) {
      return Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    // Show loading indicator until the display name is fetched
    if (isLoading || displayName.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .snapshots(),
      builder: (context, userProgressSnapshot) {
        if (!userProgressSnapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        var userProgressData = userProgressSnapshot.data?.data();
        if (userProgressData is Map<String, dynamic>) {
          Map<String, dynamic> sectionsCompleted =
              userProgressData['sectionsCompleted'] ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .doc(widget.courseName)
                .collection('sections')
                .snapshots(),
            builder: (context, courseSnapshot) {
              if (!courseSnapshot.hasData) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              totalSections = courseSnapshot.data!.docs.length;
              int completedSections = 0;

              sectionsCompleted.forEach((section, progress) {
                if (progress['quizCompleted'] == true) {
                  completedSections++;
                }
              });

              double progressPercentage =
              totalSections > 0 ? (completedSections / totalSections) : 0.0;

              return Scaffold(
                body: SingleChildScrollView(  // Make the content scrollable
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Display User Name
                      Column(
                        children: [
                          Text(
                            'Hello, $displayName',  // Display the fetched name here
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // Course Progress Information
                      Column(
                        children: [
                          Text(
                            'Course Progress',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Total Sections: $totalSections',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Completed Sections: $completedSections',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Progress: ${(progressPercentage * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // Overall Progress Circular Indicator
                      Column(
                        children: [
                          Text(
                            'Overall Progress',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 15),
                          CircularPercentIndicator(
                            radius: 60.0,
                            lineWidth: 8.0,
                            animation: true,
                            animationDuration: 1000,
                            percent: progressPercentage,
                            center: Text(
                              '${(progressPercentage * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            progressColor: Colors.blueAccent,
                            backgroundColor: Colors.grey[300]!,
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // Completed Sections Circular Indicator
                      Column(
                        children: [
                          Text(
                            'Sections Completed',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 15),
                          CircularPercentIndicator(
                            radius: 60.0,
                            lineWidth: 8.0,
                            animation: true,
                            animationDuration: 1000,
                            percent: completedSections / totalSections,
                            center: Text(
                              '$completedSections/$totalSections',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            progressColor: Colors.greenAccent,
                            backgroundColor: Colors.grey[300]!,
                          ),
                        ],
                      ),
                      SizedBox(height: 30),

                      // Show Get Your Certificate button when progress is 100%
                      if (progressPercentage == 1.0)
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to the certificate page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CourseCompletionPage(),
                              ),
                            );
                          },
                          child: Text('Next', style: TextStyle(color: Colors.black),),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        } else {
          return Scaffold(
            body: Center(child: Text('Invalid user progress data')),
          );
        }
      },
    );
  }
}
