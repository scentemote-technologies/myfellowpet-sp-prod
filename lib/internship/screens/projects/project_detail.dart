import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:myfellowpet_sp/internship/screens/projects/project_enrollment.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  final dynamic imageUrl;
  final String projectName;
  final String description;

  const ProjectDetailPage({
    required this.projectId,
    required this.imageUrl,
    required this.description,
    required this.projectName,
  });

  @override
  _ProjectDetailPageState createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late String currentUid;
  late String projectCost;
  late String domain;
  final _pagePadding = const EdgeInsets.symmetric(horizontal: 24.0);
  final _sectionSpacing = const SizedBox(height: 32.0);

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser!.uid;
    projectCost = '';
    domain = '';
    fetchProjectCost();
  }

  Future<bool> checkIfEnrolled() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('web-users')
          .doc(currentUid)
          .collection('user projects')
          .doc(widget.projectId)
          .get();
      return userDoc.exists;
    } catch (e) {
      print('Error checking enrollment: $e');
      return false;
    }
  }

  Future<void> fetchProjectCost() async {
    try {
      DocumentSnapshot projectDoc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      if (projectDoc.exists) {
        setState(() {
          projectCost = projectDoc['projectCost'].toString();
          domain = projectDoc['domainId'].toString();
        });
      }
    } catch (e) {
      print('Error fetching project cost: $e');
    }
  }

  Widget _buildInfoCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProcessStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> imageUrls = List<String>.from(
        widget.imageUrl is List ? widget.imageUrl : [widget.imageUrl]);

    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<bool>(
          future: checkIfEnrolled(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final isEnrolled = snapshot.data ?? false;

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF2D2D2D),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Image Carousel
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 400,
                            viewportFraction: 1,
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 3),
                            enableInfiniteScroll: false,
                          ),
                          items: imageUrls.map((url) {
                            return Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(url),
                                  fit: BoxFit.contain,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Content Section
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Price
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.projectName,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹$projectCost',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Domain and Description
                              _buildInfoCard('DOMAIN', domain),
                              const SizedBox(height: 16),
                              _buildInfoCard('DESCRIPTION', widget.description),
                              const SizedBox(height: 32),

                              // Process Steps
                              const Text(
                                'Purchase Process',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Column(
                                children: [
                                  _buildProcessStep(
                                    1,
                                    'Contact Us',
                                    'Click "Inquire To Purchase" to initiate the process',
                                  ),
                                  const SizedBox(height: 24),
                                  _buildProcessStep(
                                    2,
                                    'Make Payment',
                                    'Complete the secure payment process',
                                  ),
                                  const SizedBox(height: 24),
                                  _buildProcessStep(
                                    3,
                                    'Receive Project',
                                    'Get instant access to project files in ZIP format',
                                  ),
                                  const SizedBox(height: 24),
                                  _buildProcessStep(
                                    4,
                                    'Support Assistance',
                                    '24/7 technical support available after purchase',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // Floating Action Button
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.indigoAccent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isEnrolled
                            ? null
                            : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProjectEnrollmentPage(
                                projectName: widget.projectName),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          isEnrolled ? 'Already Purchased' : 'Inquire To Purchase',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }
}