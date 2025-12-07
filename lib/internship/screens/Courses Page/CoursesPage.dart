import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../course grid view/course_grid_view.dart';

class CourseGrid extends StatefulWidget {
  @override
  _CourseGridState createState() => _CourseGridState();
}

class _CourseGridState extends State<CourseGrid> {
  TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // Decide how many columns to show
    int gridColumns;
    if (screenWidth < 630) {
      gridColumns = 1;
    } else if (screenWidth < 860) {
      gridColumns = 2;
    } else if (screenWidth < 960) {
      gridColumns = 2;
    } else if (screenWidth < 1105) {
      gridColumns = 2;
    } else if (screenWidth < 1200) {
      gridColumns = 3;
    } else if (screenWidth < 1400) {
      gridColumns = 3;
    } else if (screenWidth < 1600) {
      gridColumns = 4;
    } else {
      gridColumns = 5;
    }

    // Decide child aspect ratio
    double aspectRatio;
    if (screenWidth < 530) {
      aspectRatio = 1;
    }else if (screenWidth < 630) {
      aspectRatio = 1.5;
    } else if (screenWidth < 860) {
      aspectRatio = 0.8;  // near-square tiles on phones
    } else if (screenWidth < 960) {
      aspectRatio = 1.2;   // slightly wider on small tablets
    } else if (screenWidth < 1200) {
      aspectRatio = 1.0;   // moderate for medium screens
    } else if (screenWidth < 1600) {
      aspectRatio = 0.9;   // narrower for large screens
    } else {
      aspectRatio = 0.8;   // even narrower for extra large
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Courses',
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (query) {
                  setState(() {
                    searchQuery = query.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search for a course...',
                  prefixIcon: Icon(Icons.search, color: Colors.black),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10.0),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('courses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Filter courses by search query
          var courses = snapshot.data!.docs.where((doc) {
            String courseName = doc.id.toLowerCase();
            return courseName.contains(searchQuery);
          }).toList();

          // Also filter by display == true
          courses = courses.where((course) {
            var data = course.data() as Map<String, dynamic>;
            return data.containsKey('display') && data['display'] == true;
          }).toList();

          if (courses.isEmpty) {
            return Center(child: Text('No courses found.'));
          }

          // Wrap the grid in a SingleChildScrollView to avoid overflow
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  // Use shrinkWrap so the Grid doesn't expand infinitely
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: courses.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    var course = courses[index];
                    String courseName = course.id;
                    var data = course.data() as Map<String, dynamic>;
                    String description = data['description'] ?? 'No description available';
                    String imgUrl = data['image_url'] ?? '';

                    return CourseTile(
                      courseName: courseName,
                      imageUrl: imgUrl,
                      description: description,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
