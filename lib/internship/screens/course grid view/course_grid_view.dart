import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../courses/course_detail.dart';

/// Responsive helper function
double responsiveValue(BuildContext context, double mobile, double tablet, double laptop, double desktop) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 1440) return desktop;
  if (screenWidth > 1024) return laptop;
  if (screenWidth > 600) return tablet;
  return mobile;
}

class CourseTile extends StatelessWidget {
  final String courseName;
  final String imageUrl;
  final String description;

  const CourseTile({
    Key? key,
    required this.courseName,
    required this.imageUrl,
    required this.description,
  }) : super(key: key);

  // Fetch section document IDs from the 'courses' sub-collection.
  Future<List<String>> _fetchCourseSections() async {
    try {
      var sectionsSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseName)
          .collection('sections')
          .get();
      return sectionsSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print("Error fetching course sections: $e");
      return [];
    }
  }

  // Fetch the domain for the course.
  Future<String> _fetchDomain() async {
    try {
      var courseDoc =
      await FirebaseFirestore.instance.collection('courses').doc(courseName).get();
      return courseDoc['domain'] ?? 'No domain';
    } catch (e) {
      print("Error fetching domain: $e");
      return 'No domain';
    }
  }

  // Fetch the total course time for the course.
  Future<String> _fetchTotalCourseTime() async {
    try {
      var courseDoc =
      await FirebaseFirestore.instance.collection('courses').doc(courseName).get();
      return courseDoc['total_course_time'] ?? 'Unknown';
    } catch (e) {
      print("Error fetching total_course_time: $e");
      return 'Unknown';
    }
  }

  // Handle tap on the course tile.
  void _handleCourseTap(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Sign In Required',
            style: TextStyle(
              fontSize: responsiveValue(context, 16, 18, 20, 22),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please sign in to access this course.',
            style: TextStyle(
              fontSize: responsiveValue(context, 14, 16, 18, 20),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: responsiveValue(context, 14, 16, 18, 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      List<String> sections = await _fetchCourseSections();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseDetailPage(
            courseName: courseName,
            imageUrl: imageUrl,
            description: description,
            sectionIds: sections,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleCourseTap(context),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top image with gradient overlay.
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover, // Ensures the image scales to fit within the defined height.
                        height: 180,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                      // Gradient overlay to improve text readability.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content area.
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap widget for domain and total time badges.
                      Wrap(
                        spacing: 8, // space between badges horizontally
                        runSpacing: 4, // space between badges vertically (when wrapping)
                        children: [
                          FutureBuilder<String>(
                            future: _fetchDomain(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              String domain = snapshot.data ?? 'No domain';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  domain,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: responsiveValue(context, 10, 12, 14, 16),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                          FutureBuilder<String>(
                            future: _fetchTotalCourseTime(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              String totalTime = snapshot.data ?? 'Unknown';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  totalTime,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: responsiveValue(context, 10, 12, 14, 16),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Course name and description follow...
                      Text(
                        courseName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: responsiveValue(context, 16, 18, 20, 22),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: responsiveValue(context, 12, 14, 16, 18),
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // "Start" button positioned at the bottom right.
            Positioned(
              bottom: 20,
              right: 16,
              child: SizedBox(
                height: 40, // Adjust this value to reduce or increase the button's height.
                child: FloatingActionButton.extended(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  onPressed: () => _handleCourseTap(context),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Start',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: responsiveValue(context, 10, 12, 14, 16),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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

class CourseGridView extends StatelessWidget {
  final String searchQuery;

  const CourseGridView({Key? key, required this.searchQuery}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('courses').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading courses: ${snapshot.error}',
              style: TextStyle(
                fontSize: responsiveValue(context, 14, 16, 18, 20),
              ),
            ),
          );
        }

        final courses = snapshot.data?.docs ?? [];
        final filteredCourses = courses.where((course) {
          // Retrieve the course data as a Map
          final data = course.data() as Map<String, dynamic>;
          // Check for "display" field; if missing or false, exclude it.
          bool display = data.containsKey('display') && data['display'] == true;
          // Also check if the course name matches the search query.
          final name = course.id.toLowerCase();
          return display && name.contains(searchQuery.toLowerCase());
        }).toList();

        if (filteredCourses.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: responsiveValue(context, 48, 52, 56, 60),
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No courses found',
                  style: TextStyle(
                    fontSize: responsiveValue(context, 16, 18, 20, 22),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: GridView.builder(
            padding: EdgeInsets.zero, // remove default GridView padding
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 360, // Increased height from 340 to 360
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              return CourseTile(
                courseName: course.id,
                imageUrl: course['image_url'],
                description: course['description'] ?? 'No description available',
              );
            },
          ),
        );
      },
    );
  }
}
