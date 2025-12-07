import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myfellowpet_sp/internship/screens/courses/view_courses.dart';
import 'course_enrollment_page.dart';

class CourseDetailPage extends StatefulWidget {
  final String courseName;
  final String imageUrl;
  final String description;
  final List<String> sectionIds;

  CourseDetailPage({
    required this.courseName,
    required this.imageUrl,
    required this.description,
    required this.sectionIds,
  });

  @override
  _CourseDetailPageState createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late String currentUid;
  int totalVideos = 29;
  int downloadableDocuments = 25;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser!.uid;
    fetchCourseDetails();
  }

  // Fetch course details based on courseName (document ID)
  Future<void> fetchCourseDetails() async {
    try {
      DocumentSnapshot courseDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
          .get();

      if (courseDoc.exists) {
        setState(() {
          totalVideos =
              int.tryParse(courseDoc['total_videos']?.toString() ?? '29') ?? 29;
          downloadableDocuments = int.tryParse(
              courseDoc['downloadableDocuments']?.toString() ?? '25') ??
              25;
        });
      }
    } catch (e) {
      print('Error fetching course details: $e');
    }
  }

  // Check if the user is enrolled in the course
  Future<bool> checkIfEnrolled() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('web-users')
          .doc(currentUid)
          .collection('user courses')
          .doc(widget.courseName)
          .get();
      return userDoc.exists;
    } catch (e) {
      print('Error checking enrollment: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define breakpoints: phone, tablet, desktop
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    // final isDesktop = screenWidth >= 900; // Not used explicitly here

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Use a floating button on phones only
      floatingActionButton: isPhone
          ? FutureBuilder<bool>(
        future: checkIfEnrolled(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return SizedBox.shrink();
          bool isEnrolled = snapshot.data ?? false;
          return FloatingActionButton.extended(
            onPressed: () {
              if (isEnrolled) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewCoursePage(courseName: widget.courseName),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnrollmentFormPage(courseName: widget.courseName, uid: currentUid),
                  ),
                );
              }
            },
            label: Text(
              isEnrolled ? 'Start Learning' : 'Enroll Now',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.black,
          );
        },
      )
          : null,

      body: FutureBuilder<bool>(
        future: checkIfEnrolled(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          bool isEnrolled = snapshot.data ?? false;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 16.0 : 20.0,
                vertical: isPhone ? 10.0 : 20.0,
              ),
              child: Column(
                children: [
                  // For phones, stack details and image in a column;
                  // for larger screens, use a row layout.
                  isPhone
                      ? Column(
                    children: [
                      _buildCourseDetails(context, isPhone, isTablet, isEnrolled),
                      SizedBox(height: 20),
                      _buildImageEnrollSection(context, isPhone, isTablet, isEnrolled),
                    ],
                  )
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildCourseDetails(context, isPhone, isTablet, isEnrolled),
                      ),
                      SizedBox(width: isTablet ? 16 : 20),
                      _buildImageEnrollSection(context, isPhone, isTablet, isEnrolled),
                    ],
                  ),
                  SizedBox(height: isPhone ? 16 : 20),
                  _buildCourseCurriculum(context, isPhone),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the left side (course details and "What is Included" section)
  Widget _buildCourseDetails(BuildContext context, bool isPhone, bool isTablet, bool isEnrolled) {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      padding: EdgeInsets.symmetric(
        vertical: isPhone ? 20.0 : 30.0,
        horizontal: isPhone ? 16.0 : 20.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course Name
          Text(
            widget.courseName,
            style: TextStyle(
              fontSize: isPhone ? 24 : (isTablet ? 30 : 36),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 10),
          // Duration
          Text(
            'Duration: 3 weeks',
            style: TextStyle(
              fontSize: isPhone ? 14 : 16,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 10),
          // Description
          Text(
            widget.description,
            style: TextStyle(
              fontSize: isPhone ? 14 : 16,
              color: Colors.black87,
              height: 1.6,
            ),
            textAlign: TextAlign.justify,
          ),
          SizedBox(height: isPhone ? 16 : 20),
          // "What is Included" section
          Card(
            elevation: 5,
            color: Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(isPhone ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What is Included',
                    style: TextStyle(
                      fontSize: isPhone ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: isPhone ? 8 : 10),
                  // Layout in a column on phones; two-column row on larger screens.
                  isPhone
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIncludedRow(Icons.video_library, '$totalVideos videos'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.quiz, 'Quizzes'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.download_for_offline, '$downloadableDocuments downloadable resources'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.check_circle, 'Certification of Completion'),
                    ],
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIncludedRow(Icons.video_library, '$totalVideos videos'),
                            SizedBox(height: 10),
                            _buildIncludedRow(Icons.quiz, 'Quizzes'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIncludedRow(Icons.download_for_offline, '$downloadableDocuments downloadable resources'),
                            SizedBox(height: 10),
                            _buildIncludedRow(Icons.check_circle, 'Certification of Completion'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for a row in the "What is Included" section.
  Widget _buildIncludedRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.black),
        SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(color: Colors.black))),
      ],
    );
  }

  /// Builds the image section with enroll/start button (for non-phone layouts)
  Widget _buildImageEnrollSection(BuildContext context, bool isPhone, bool isTablet, bool isEnrolled) {
    final screenHeight = MediaQuery.of(context).size.height;
    final containerHeight = isPhone ? screenHeight * 0.3 : screenHeight * 0.58;
    final containerWidth = isPhone
        ? double.infinity
        : (isTablet ? MediaQuery.of(context).size.width * 0.25 : MediaQuery.of(context).size.width * 0.2);

    return Container(
      width: containerWidth,
      height: containerHeight,
      margin: EdgeInsets.only(top: isPhone ? 16.0 : 0.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey[200],
      ),
      child: Column(
        children: [
          // Image Section
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.imageUrl),
                  fit: BoxFit.contain,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
            ),
          ),
          // Enroll/Start button shown on non-phone devices
          if (!isPhone)
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: ElevatedButton(
                    onPressed: () {
                      if (isEnrolled) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewCoursePage(courseName: widget.courseName),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EnrollmentFormPage(courseName: widget.courseName, uid: currentUid),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      isEnrolled ? 'Start Learning' : 'Enroll Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the Course Curriculum section
  Widget _buildCourseCurriculum(BuildContext context, bool isPhone) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 0.0 : 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Curriculum',
            style: TextStyle(
              fontSize: isPhone ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: isPhone ? 8 : 10),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('courses')
                .doc(widget.courseName)
                .collection('sections')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(child: Text('No sections available.'));
              var sections = snapshot.data!.docs;
              // Sort sections by the 'order' field (ascending)
              sections.sort((a, b) {
                int orderA = int.tryParse(a['order']?.toString() ?? '0') ?? 0;
                int orderB = int.tryParse(b['order']?.toString() ?? '0') ?? 0;
                return orderA.compareTo(orderB);
              });
              return Column(
                children: List.generate(sections.length, (index) {
                  var section = sections[index];
                  var sectionName = section.id;
                  var order = int.tryParse(section['order']?.toString() ?? '1') ?? 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '$order',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            sectionName,
                            style: TextStyle(
                              fontSize: isPhone ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
