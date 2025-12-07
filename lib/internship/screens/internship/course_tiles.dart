import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Internship workflow/course_grid_view_internship.dart';

class InternshipCourseTiles extends StatelessWidget {
  final String? userId;
  final String documentId;

  InternshipCourseTiles({required this.userId, required this.documentId});

  Future<List<Map<String, String>>> fetchCourseData() async {
    List<Map<String, String>> courseDetails = [];
    try {
      // Fetch course names from learning-modules subcollection
      var internshipRef =
      FirebaseFirestore.instance.collection('internships').doc(documentId);
      var learningModulesSnapshot =
      await internshipRef.collection('learning-modules').get();

      List<String> courseNames = [];
      for (var doc in learningModulesSnapshot.docs) {
        // Add course_name field to the list
        courseNames.add(doc['course_name']);
      }

      // Now fetch details for each course from the courses collection
      for (String courseName in courseNames) {
        var courseSnapshot =
        await FirebaseFirestore.instance.collection('courses').doc(courseName).get();
        if (courseSnapshot.exists) {
          var courseData = courseSnapshot.data() as Map<String, dynamic>;
          courseDetails.add({
            'course_name': courseData['course_name'],
            'description': courseData['description'],
            'image_url': courseData['image_url'],
          });
        }
      }
    } catch (e) {
      print("Error fetching course data: $e");
    }

    return courseDetails;
  }

  /// Determine grid configuration based on screen width.
  Map<String, dynamic> _getGridConfig(double screenWidth) {
    int columns;
    double aspectRatio;

    if (screenWidth < 600) {
      // Phones
      columns = 1;
      aspectRatio = 0.5;
    } else if (screenWidth < 900) {
      // Small tablets
      columns = 1;
      aspectRatio = 1;
    } else if (screenWidth < 1200) {
      // Large tablets / small laptops
      columns = 2;
      aspectRatio = 1.5;
    } else {
      // Desktops / larger screens
      columns = 3;
      aspectRatio = 1.2;
    }

    return {'columns': columns, 'aspectRatio': aspectRatio};
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final gridConfig = _getGridConfig(screenWidth);

    return Scaffold(
        appBar: AppBar(
          title: Text(
            documentId,
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text(
                'Internship ID: $documentId',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, String>>>(
                  future: fetchCourseData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No courses found.'));
                    }

                    var courses = snapshot.data!;

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridConfig['columns'],
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: gridConfig['aspectRatio'],
                      ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        var course = courses[index];
                        return InternshipCourseTile(
                          internship_name: documentId,
                          courseName: course['course_name']!,
                          description: course['description']!,
                          imageUrl: course['image_url']!,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

    );
  }
}
