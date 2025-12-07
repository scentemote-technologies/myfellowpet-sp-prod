import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class InternshipProgressDashboardTile extends StatefulWidget {
  final String internship_name;
  final String userid;

  InternshipProgressDashboardTile({required this.internship_name, required this.userid});

  @override
  _InternshipProgressDashboardTileState createState() =>
      _InternshipProgressDashboardTileState();
}

class _InternshipProgressDashboardTileState extends State<InternshipProgressDashboardTile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double quizCompletionPercentage = 0.0;
  double acceptedProjectsPercentage = 0.0;
  String courseName = '';

  // Stream to fetch the course data
  Stream<Map<String, String>> fetchCourseDataStream() async* {
    try {
      print('Fetching course data for internship: ${widget.internship_name}');
      var internshipRef = FirebaseFirestore.instance.collection('internships').doc(widget.internship_name);
      var learningModulesSnapshot = await internshipRef.collection('learning-modules').get();

      if (learningModulesSnapshot.docs.isNotEmpty) {
        String courseName = learningModulesSnapshot.docs[0]['course_name'];
        print('Course name fetched: $courseName');

        var courseSnapshot = await FirebaseFirestore.instance.collection('courses').doc(courseName).get();

        if (courseSnapshot.exists) {
          var courseData = courseSnapshot.data() as Map<String, dynamic>;
          print('Course data fetched successfully: $courseData');
          yield {
            'course_name': courseData['course_name'],
            'description': courseData['description'],
            'image_url': courseData['image_url'],
          };
        } else {
          print('Course snapshot does not exist.');
          yield {};
        }
      } else {
        print('No learning modules found.');
        yield {};
      }
    } catch (e) {
      print("Error fetching course data: $e");
      yield {};
    }
  }

  // Stream to fetch quiz completion progress data
  Stream<Map<String, dynamic>> fetchQuizCompletionDataStream() async* {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    print('Fetching quiz completion data for user: $userId, course: $courseName');
    if (userId.isEmpty || courseName.isEmpty) {
      yield {'progressPercentage': 0.0};
      return;
    }

    try {
      QuerySnapshot courseSectionsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseName)
          .collection('sections')
          .get();

      int totalSections = courseSectionsSnapshot.docs.length;
      int completedSections = 0;

      DocumentSnapshot userProgressDoc = await FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .get();

      if (userProgressDoc.exists) {
        Map<String, dynamic> userProgress = userProgressDoc.data() as Map<String, dynamic>;
        Map<String, dynamic> sectionsCompleted = userProgress['sectionsCompleted'] ?? {};

        sectionsCompleted.forEach((section, progress) {
          if (progress['quizCompleted'] == true) {
            completedSections++;
          }
        });

        double quizCompletionPercentage = totalSections > 0 ? (completedSections / totalSections) : 0.0;
        print('Quiz completion: $completedSections / $totalSections = ${quizCompletionPercentage * 100}%');

        yield {'progressPercentage': quizCompletionPercentage};
      } else {
        print('User progress document not found.');
        yield {'progressPercentage': 0.0};
      }
    } catch (e) {
      print("Error fetching quiz completion data: $e");
      yield {'progressPercentage': 0.0};
    }
  }

  Future<String> _getInternshipStartDate(String userId, String internshipName) async {
    print('Fetching internship start date...');
    final userInternshipRef = FirebaseFirestore.instance
        .collection('web-users')
        .doc(userId)
        .collection('user-internship')
        .doc(internshipName);

    final userInternshipDoc = await userInternshipRef.get();
    final timestamp = userInternshipDoc['timestamp'] as Timestamp;
    final startDate = timestamp.toDate();
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);

    print('Start Date: $formattedStartDate');
    return formattedStartDate;
  }

  Future<String> _getInternshipEndDate(String internshipName, String startDate) async {
    print('Fetching internship end date...');
    final internshipRef = FirebaseFirestore.instance.collection('internships').doc(internshipName);

    final internshipDoc = await internshipRef.get();
    final durationDays = int.parse(internshipDoc['duration_days']);

    final startDateTime = DateTime.parse(startDate);
    final endDateTime = startDateTime.add(Duration(days: durationDays));

    final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDateTime);

    print('End Date: $formattedEndDate');
    return formattedEndDate;
  }

  // Stream to fetch accepted projects progress data
  Stream<double> fetchAcceptedProjectsDataStream() async* {
    String userId = widget.userid;
    print('Fetching accepted projects data for user: $userId');
    try {
      QuerySnapshot acceptedProjectsSnapshot = await _firestore
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .collection('accepted-user-projects')
          .where('internId', isEqualTo: userId)
          .get();

      int totalAcceptedProjects = acceptedProjectsSnapshot.docs.length;
      double acceptedProjectsPercentage = totalAcceptedProjects > 0
          ? totalAcceptedProjects / acceptedProjectsSnapshot.size
          : 0.0;

      print('Accepted projects: $totalAcceptedProjects / ${acceptedProjectsSnapshot.size} = ${acceptedProjectsPercentage * 100}%');

      yield acceptedProjectsPercentage;
    } catch (e) {
      print('Error fetching accepted projects: $e');
      yield 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    print('Initializing internship progress dashboard...');
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width to decide responsive layout
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmallScreen = screenWidth < 600;
    // Adjust percent indicator radius based on screen size
    double indicatorRadius = isSmallScreen ? 70.0 : 100.0;
    // Spacing between the two sections
    double spacingBetweenIndicators = isSmallScreen ? 20.0 : 40.0;

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Internship Progress',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Track Your Internship Progress",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Icon(
                  Icons.trending_up,
                  size: isSmallScreen ? 40 : 50,
                  color: Colors.blue,
                ),
                SizedBox(height: isSmallScreen ? 20 : 40),
                // StreamBuilder for course data and nested progress indicators
                StreamBuilder<Map<String, String>>(
                  stream: fetchCourseDataStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (!snapshot.hasData || snapshot.data?.isEmpty == true) {
                      return Text("No course data available.");
                    }

                    courseName = snapshot.data!['course_name'] ?? '';
                    print('Course name in the UI: $courseName');

                    Widget quizIndicator = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          color: Colors.green,
                          size: isSmallScreen ? 25 : 30,
                        ),
                        SizedBox(height: 10),
                        StreamBuilder<Map<String, dynamic>>(
                          stream: fetchQuizCompletionDataStream(),
                          builder: (context, quizSnapshot) {
                            if (quizSnapshot.connectionState == ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            double progress = quizSnapshot.data?['progressPercentage'] ?? 0.0;
                            return CircularPercentIndicator(
                              radius: indicatorRadius,
                              lineWidth: 12.0,
                              percent: progress,
                              center: Text(
                                "${(progress * 100).toInt()}%",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 16 : 20,
                                ),
                              ),
                              progressColor: Color(0xFF2CAF31),
                              backgroundColor: Colors.grey[300]!,
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Course Completion',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    );

                    Widget projectsIndicator = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.blue,
                          size: isSmallScreen ? 25 : 30,
                        ),
                        SizedBox(height: 10),
                        StreamBuilder<double>(
                          stream: fetchAcceptedProjectsDataStream(),
                          builder: (context, acceptedProjectsSnapshot) {
                            if (acceptedProjectsSnapshot.connectionState == ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            double acceptedProjectsProgress = acceptedProjectsSnapshot.data ?? 0.0;
                            return CircularPercentIndicator(
                              radius: indicatorRadius,
                              lineWidth: 12.0,
                              percent: acceptedProjectsProgress,
                              center: Text(
                                "${(acceptedProjectsProgress * 100).toInt()}%",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 16 : 20,
                                ),
                              ),
                              progressColor: Color(0xFF2360A4),
                              backgroundColor: Colors.grey[300]!,
                            );
                          },
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Project Completion',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    );

                    // For smaller screens, stack vertically. For larger screens, arrange in a row.
                    return isSmallScreen
                        ? Column(
                      children: [
                        quizIndicator,
                        SizedBox(height: spacingBetweenIndicators),
                        projectsIndicator,
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        quizIndicator,
                        SizedBox(width: spacingBetweenIndicators),
                        projectsIndicator,
                      ],
                    );
                  },
                ),
                SizedBox(height: isSmallScreen ? 20 : 30),
                // StreamBuilder for the download button visibility logic
                StreamBuilder<bool>(
                  stream: Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
                    // Fetch the progress and date conditions
                    final quizData = await fetchQuizCompletionDataStream().first;
                    final acceptedData = await fetchAcceptedProjectsDataStream().first;

                    // Get the internship start and end dates
                    String startDate = await _getInternshipStartDate(widget.userid, widget.internship_name);
                    String endDate = await _getInternshipEndDate(widget.internship_name, startDate);

                    // Get the current date
                    String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                    // Check if the progress is complete and the end date is today or in the future
                    bool isProgressComplete = quizData['progressPercentage'] == 1.0 && acceptedData == 1.0;
                    bool isEndDateValid = currentDate.compareTo(endDate) >= 0;

                    return isProgressComplete && isEndDateValid;
                  }),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    bool showDownloadButton = snapshot.data ?? false;

                    return showDownloadButton
                        ? ElevatedButton(
                      onPressed: () {
                        // Navigate to the certificate page
                       /* Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InternshipCertificatePage(
                              internship_name: widget.internship_name,
                              userId: widget.userid,
                            ),
                          ),
                        );*/
                      },
                      child: Text('Download Course Materials'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 15,
                          horizontal: isSmallScreen ? 30 : 50,
                        ),
                        textStyle: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                        ),
                      ),
                    )
                        : Text(
                      "Your progress is not yet complete, or the end date hasn't been reached.",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),

    );
  }
}