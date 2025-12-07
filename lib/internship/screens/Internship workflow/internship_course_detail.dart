import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'internship_view_courses.dart';

class InternshipCourseDetailPage extends StatefulWidget {
  final String courseName;
  final String imageUrl;
  final String description;
  final List<String> sectionIds;
  final String internship_name;

  InternshipCourseDetailPage({
    required this.courseName,
    required this.imageUrl,
    required this.description,
    required this.sectionIds,
    required this.internship_name,
  });

  @override
  _InternshipCourseDetailPageState createState() => _InternshipCourseDetailPageState();
}

class _InternshipCourseDetailPageState extends State<InternshipCourseDetailPage> {
  late String currentUid;
  int totalVideos = 0;
  int downloadableDocuments = 0;

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
          totalVideos = int.tryParse(courseDoc['total_videos']?.toString() ?? '29') ?? 29;
          downloadableDocuments =
              int.tryParse(courseDoc['downloadableDocuments']?.toString() ?? '25') ?? 25;
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
    // Determine screen size and set breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;    // phone
    final isTablet = screenWidth >= 600 && screenWidth < 900;  // tablet
    final isDesktop = screenWidth >= 900; // desktop and larger

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
      floatingActionButton: isPhone
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InternshipViewCoursePage(
                currentUid: currentUid,
                courseName: widget.courseName,
                internship_name: widget.internship_name,
              ),
            ),
          );
        },
        label: Text(
          'Start Learning',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: Icon(
          Icons.play_arrow,
          color: Colors.white,
        ),
        backgroundColor: Colors.black,
      )
          : null,
        body: FutureBuilder<bool>(
          future: checkIfEnrolled(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            bool isEnrolled = snapshot.data ?? false;
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 16.0 : 20.0,
                  vertical: isPhone ? 10.0 : 20.0,
                ),
                child: Column(
                  children: [
                    // Adjust layout for phone/tablet/desktop
                    isPhone
                        ? Column(
                      children: [
                        _buildCourseDetails(context, isPhone, isTablet),
                        SizedBox(height: 20),
                        _buildImageEnrollSection(context, isPhone, isTablet),
                      ],
                    )
                        : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildCourseDetails(context, isPhone, isTablet),
                        ),
                        SizedBox(width: isTablet ? 16 : 20),
                        _buildImageEnrollSection(context, isPhone, isTablet),
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

  /// Builds the left side of the hero section: course title, description, "What is Included"
  Widget _buildCourseDetails(BuildContext context, bool isPhone, bool isTablet) {
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

                  // On small screens, display these items in a column;
                  // on larger screens, side-by-side.
                  isPhone
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIncludedRow(Icons.video_library, '$totalVideos videos'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.download_for_offline,
                          '$downloadableDocuments downloadable resources'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.quiz, 'Quizzes'),
                      SizedBox(height: 10),
                      _buildIncludedRow(Icons.check_circle, 'Certification of Completion'),
                    ],
                  )
                      : Row(
                    children: [
                      // Left Column
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
                      // Right Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIncludedRow(Icons.download_for_offline,
                                '$downloadableDocuments downloadable resources'),
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

  /// Small helper widget to build a row in the "What is Included" section
  Widget _buildIncludedRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.black),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  /// Builds the right side of the hero section: course image and "Start Learning" button.
  Widget _buildImageEnrollSection(BuildContext context, bool isPhone, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;
    final containerHeight = isPhone
        ? screenHeight * 0.3  // smaller for phone
        : screenHeight * 0.58;

    final containerWidth = isPhone
        ? double.infinity
        : (isTablet
        ? MediaQuery.of(context).size.width * 0.25
        : MediaQuery.of(context).size.width * 0.2);

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
          // "Start Learning" Button for non-phone layouts
          if (!isPhone)
            Expanded(
              flex: 1,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InternshipViewCoursePage(
                            currentUid: currentUid,
                            courseName: widget.courseName,
                            internship_name: widget.internship_name,
                          ),
                        ),
                      );
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
                      'Start Learning',
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


  /// Builds the Course Curriculum section with a list of course sections
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No sections available.'));
              }
              var sections = snapshot.data!.docs;
              // Sort sections by 'order' field (ascending)
              sections.sort((a, b) {
                int orderA = int.tryParse(a['order'] ?? '0') ?? 0;
                int orderB = int.tryParse(b['order'] ?? '0') ?? 0;
                return orderA.compareTo(orderB);
              });
              return Column(
                children: List.generate(sections.length, (index) {
                  var section = sections[index];
                  var sectionName = section.id;
                  var order = int.tryParse(section['order'] ?? '1') ?? 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        // Index number container
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        // Section title
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
