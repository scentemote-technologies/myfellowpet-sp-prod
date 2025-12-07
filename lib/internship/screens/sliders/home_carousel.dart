import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

// Carousel with image and slider in a row
class CarouselWithImageAndSlider extends StatefulWidget {
  @override
  _CarouselWithImageAndSliderState createState() =>
      _CarouselWithImageAndSliderState();
}

class _CarouselWithImageAndSliderState extends State<CarouselWithImageAndSlider> {
  int _currentIndex2 = 0;
  late Future<List<Map<String, String>>> imgList;

  // Fetching images and data from Firestore collection
  @override
  void initState() {
    super.initState();
    imgList = _fetchCourseImages();
  }

  Future<List<Map<String, String>>> _fetchCourseImages() async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').get();
    List<Map<String, String>> courseData = [];
    for (var doc in snapshot.docs) {
      courseData.add({
        'image_url': doc['image_url'],
        'title': doc.id, // Document ID as title
      });
    }
    return courseData;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: imgList,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No images available.'));
        }

        List<Map<String, String>> courseData = snapshot.data!;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Static content on the left
            Container(
              width: MediaQuery.of(context).size.width * 0.45, // Adjust width
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent, // Background color
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "Looking for Internships?",
                    style: TextStyle(
                      fontSize: 36.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 15),
                  // Description
                  Text(
                    "Explore Projects, Courses, and Internships that can help you build your career. "
                        "Take the next step and unlock endless learning opportunities.",
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.black,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 25),
                  // Button
                  ElevatedButton(
                    onPressed: () {
                      // Define the action for the button, e.g., navigate to another page
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black, backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Find Opportunities",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Carousel Slider on the right
            _buildCarouselSlider(
              courseData,
              _currentIndex2,
                  (index) {
                setState(() {
                  _currentIndex2 = index;
                });
              },
            ),
          ],
        );
      },
    );
  }

  // Function to build a carousel slider
  Widget _buildCarouselSlider(List<Map<String, String>> courseData, int currentIndex, Function(int) onPageChanged) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.45, // 45% of the screen width
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0), // Rounded corners for modern look
        border: Border.all(color: Color(0xFFF1A602), width: 3), // Yellow border with thickness
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            blurRadius: 8.0,
            offset: Offset(0, 4), // Shadow position
          ),
        ],
      ),
      child: Column(
        children: [
          // CarouselSlider itself
          CarouselSlider(
            options: CarouselOptions(
              height: 250.0, // Set the height for the carousel
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 1.0,
              onPageChanged: (index, reason) {
                onPageChanged(index);
              },
            ),
            items: courseData.map((course) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 5.0),
                child: Stack(
                  children: [
                    // Image background
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.0),
                      child: Image.network(
                        course['image_url']!,
                        fit: BoxFit.contain,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                    Spacer(),
                    // Title overlay with background container
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6), // Semi-transparent background
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          course['title']!, // Document ID as the title
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          // Dots indicator centered at the bottom
          Align(
            alignment: Alignment.center,
            child: DotsIndicator(currentIndex: currentIndex, itemCount: courseData.length),
          ),
        ],
      ),
    );
  }
}

// Dots indicator widget
class DotsIndicator extends StatelessWidget {
  final int currentIndex;
  final int itemCount;

  DotsIndicator({required this.currentIndex, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
            (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4.0),
          width: 12.0,
          height: 12.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index ? Colors.orange : Colors.grey,
          ),
        ),
      ),
    );
  }
}
