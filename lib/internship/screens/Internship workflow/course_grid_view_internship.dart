import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../courses/course_detail.dart';
import 'internship_course_detail.dart';

class InternshipCourseTile extends StatelessWidget {
  final String courseName;
  final String imageUrl;
  final String description;
  final String internship_name;

  InternshipCourseTile({
    required this.courseName,
    required this.imageUrl,
    required this.description, required this.internship_name,
  });

  // Function to fetch section document IDs from the 'courses' sub-collection
  Future<List<String>> _fetchCourseSections() async {
    try {
      var sectionsSnapshot = await FirebaseFirestore.instance
          .collection('courses')  // This is the parent collection
          .doc(courseName)  // This is the course document ID
          .collection('sections') // 'courses' sub-collection
          .get();

      return sectionsSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching course sections: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double padding = screenWidth < 600 ? 8.0 : 16.0; // Smaller padding for smaller screens
    double fontSize = screenWidth < 600 ? 14.0 : 16.0; // Smaller font size for smaller screens

    // Dynamic number of lines based on screen size
    // Set the maximum lines for the title and description based on screen width
    int maxLinesForTitle;
    int maxLinesForDescription;

// Adjust based on screen width and gridColumns
    if (screenWidth < 1) {
      // Very small screens
      maxLinesForTitle = 1; // 1 line for title
      maxLinesForDescription = 1; // 1 line for description

    }
    else if (screenWidth < 188) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2  ; // 2 lines for description
    }
    else if (screenWidth < 214) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }
    else if (screenWidth < 249) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 4; // 2 lines for description
    }else if (screenWidth < 268) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }

    else if (screenWidth < 268) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }
    else if (screenWidth < 307) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 lines for description
    }

    else if (screenWidth < 323) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }
    else if (screenWidth < 355) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 lines for description
    }
    else if (screenWidth < 377) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 4; // 2 lines for description
    }
    else if (screenWidth < 398) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }
    else if (screenWidth < 400) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 lines for description
    }
    else if (screenWidth < 470) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 lines for description
    }
    else if (screenWidth < 506) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 3; // 2 lines for description
    }
    else if (screenWidth < 530) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 4; // 2 lines for description
    }
    else if (screenWidth < 573) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 1; // 2 lines for description
    }
    else if (screenWidth < 910) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 lines for description
    }
    else if (screenWidth < 1080) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 4; // 2 lines for description
    }
    else if (screenWidth < 1130) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 3; // 2 lines for description
    }
    else if (screenWidth < 1226) {
      // Small screens (e.g., tablets or small laptops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 4; // 2 lines for description
    }else if (screenWidth < 1260) {
      // Medium screens (larger tablets or small desktops)
      maxLinesForTitle = 2; // 2 lines for title
      maxLinesForDescription = 2; // 2 or 3 lines for description
    } else if (screenWidth < 1300) {
      // Larger screens (small laptops)
      maxLinesForTitle = 3; // 3 lines for title
      maxLinesForDescription = 3; // 3 lines for description
    } else if (screenWidth < 1495) {
      // Larger screens (small laptops)
      maxLinesForTitle = 3; // 3 lines for title
      maxLinesForDescription = 3; // 3 lines for description
    } else if (screenWidth < 1500) {
      // Large screens (larger desktops)
      maxLinesForTitle = 2; // 3 lines for title
      maxLinesForDescription = 2; // 3 lines for description
    } else {
      // Extra large screens (e.g., very large desktops)
      maxLinesForTitle = 2; // 4 lines for title
      maxLinesForDescription = 2; // 4 lines for description
    }


    // Dynamic size for the button padding
    double buttonPadding = screenWidth < 600 ? 10.0 : 14.0;
    Future<String> _fetchDomain() async {
      try {
        var courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseName)
            .get();
        return courseDoc['domain'] ?? 'No domain'; // Fallback in case no domain is found
      } catch (e) {
        print("Error fetching domain: $e");
        return 'No domain';
      }
    }

    // Fetching 'total_course_time' from the course document
    Future<String> _fetchTotalCourseTime() async {
      try {
        var courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseName)
            .get();
        return courseDoc['total_course_time'] ?? 'Unknown'; // Fallback if not found
      } catch (e) {
        print("Error fetching total_course_time: $e");
        return 'Unknown';
      }
    }

    return GestureDetector(
      onTap: () async {
        List<String> sections = await _fetchCourseSections();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InternshipCourseDetailPage(
              courseName: courseName,
              imageUrl: imageUrl,
              internship_name:internship_name,
              description: description,
              sectionIds: sections,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.transparent,
              blurRadius: 2,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: 100, // Adjust this value if needed
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4.0),
              child: Text(
                courseName,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                maxLines: maxLinesForTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 15),




            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    List<String> sections = await _fetchCourseSections();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InternshipCourseDetailPage(
                          courseName: courseName,
                          imageUrl: imageUrl,
                          internship_name:internship_name,
                          description: description,
                          sectionIds: sections,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFF2562E8),
                    padding: EdgeInsets.symmetric(vertical: buttonPadding), // Dynamic padding for the button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Start',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InternshipCourseGridView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Set grid columns based on screen width
    int gridColumns;

    if (screenWidth < 700) {
      gridColumns = 1; // 1 column for very small screens
    } else if (screenWidth < 960) {
      gridColumns = 2;// 2 columns for small screens
    } else if (screenWidth < 1230) {
      gridColumns = 3; // 3 columns for medium screens
    } else if (screenWidth < 1495) {
      gridColumns = 4;

    } else if (screenWidth < 1500) {
      gridColumns = 5;// 4 columns for larger tablets or small laptops
    } else {
      gridColumns = 5; // 5 columns for large screens
    }

    // Set dynamic aspect ratio
    double aspectRatio;
    if (screenWidth < 190) {
      aspectRatio = 0.4;
    }else if (screenWidth < 250) {
      aspectRatio = 0.6;
    }else if (screenWidth < 307) {
      aspectRatio = 0.8;
    }else if (screenWidth < 373) {
      aspectRatio = 1;
    }else if (screenWidth < 435) {
      aspectRatio = 1.2;
    }else if (screenWidth < 521) {
      aspectRatio = 1.4;
    }else if (screenWidth < 565) {
      aspectRatio = 1.7;
    }else if (screenWidth < 680) {
      aspectRatio = 1.8;
    } else if (screenWidth < 700) {
      aspectRatio = 2;
    }
    else if (screenWidth < 710) {
      aspectRatio = 1; // Slightly larger aspect ratio for very small screens906
    }
    else if (screenWidth < 750) {
      aspectRatio = 0.95; // Slightly larger aspect ratio for very small screens906
    }
    else if (screenWidth < 850) {
      aspectRatio = 1.1; // Slightly larger aspect ratio for very small screens906
    }

    else if (screenWidth < 960) {
      aspectRatio = 1.2; // Slightly larger aspect ratio for very small screens906
    }
    else if (screenWidth < 985) {
      aspectRatio = 0.75;
    } else if (screenWidth < 1000) {
      aspectRatio = 0.8;
    }
    else if (screenWidth < 1100) {
      aspectRatio = 0.85;
    }
    else if (screenWidth < 1200) {
      aspectRatio = 0.95;
    }
    else if (screenWidth < 1226) {
      aspectRatio = 1;
    }
    else if (screenWidth < 1365) {
      aspectRatio = 0.85;
    }
    else if (screenWidth < 1450) {
      aspectRatio = 0.9;
    } else if (screenWidth < 1500) {
      aspectRatio = 0.95; // Smaller aspect ratio for larger tablets or small laptops
    } else {
      aspectRatio = 0.8; // Even smaller aspect ratio for large screens (desktops)
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('courses').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No courses available.'));
        }

        var courses = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns, // Adjust the number of columns dynamically
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 16.0,
            childAspectRatio: aspectRatio, // Dynamically adjust aspect ratio
          ),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            var course = courses[index];
            String courseName = course.id;
            String imageUrl = course['image_url'];
            String description = course['description'] ?? 'No description';

            return InternshipCourseTile(
              internship_name: "",
              courseName: courseName,
              imageUrl: imageUrl,
              description: description,
            );
          },
        );
      },
    );
  }
}
