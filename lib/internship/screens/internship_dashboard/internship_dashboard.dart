import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../internship/course_tiles.dart';
import '../internship_dashboard/announcement.dart';
import '../internship_dashboard/internship_overview.dart';
import '../internship_dashboard/feedback.dart';
import '../internship_dashboard/qna.dart';
import '../internship_dashboard/tasks.dart';
import '../internship_dashboard/learning_modules.dart';
import '../internship_dashboard/projects.dart';
import '../projects/add_form.dart';
import 'PROGRESS_TILE_DASHBOARD.dart';

/// A helper function that returns a responsive value based on screen width.
/// Pass values for mobile, tablet, laptop, and desktop.
double responsiveValue(
    BuildContext context,
    double mobile,
    double tablet,
    double laptop,
    double desktop,
    ) {
  double width = MediaQuery.of(context).size.width;
  if (width >= 1440) return desktop;
  if (width >= 1024) return laptop;
  if (width >= 600) return tablet;
  return mobile;
}

class InternshipCoursePage extends StatelessWidget {
  final String userId;
  final String documentId;

  InternshipCoursePage({required this.userId, required this.documentId});

  Future<bool> _checkDisplayStatus() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('internships')
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.get('display') ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Determine the number of grid columns based on screen width.
    int gridColumns;
    if (screenWidth < 700) {
      gridColumns = 1;
    } else if (screenWidth < 721) {
      gridColumns = 2;
    } else if (screenWidth < 960) {
      gridColumns = 3;
    } else if (screenWidth < 1230) {
      gridColumns = 3;
    } else if (screenWidth < 1495) {
      gridColumns = 4;
    } else if (screenWidth < 1500) {
      gridColumns = 4;
    } else {
      gridColumns = 5;
    }

    // Determine the grid tile's aspect ratio based on screen width.
    double aspectRatio;
    if (screenWidth < 190) {
      aspectRatio = 0.4;
    } else if (screenWidth < 250) {
      aspectRatio = 0.6;
    } else if (screenWidth < 307) {
      aspectRatio = 0.8;
    } else if (screenWidth < 373) {
      aspectRatio = 1.0;
    } else if (screenWidth < 435) {
      aspectRatio = 1.2;
    } else if (screenWidth < 521) {
      aspectRatio = 1.4;
    } else if (screenWidth < 565) {
      aspectRatio = 1.7;
    } else if (screenWidth < 680) {
      aspectRatio = 1.8;
    } else if (screenWidth < 700) {
      aspectRatio = 2.0;
    } else if (screenWidth < 710) {
      aspectRatio = 1.0;
    } else {
      aspectRatio = 0.70;
    }

    return FutureBuilder<bool>(
      future: _checkDisplayStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError || !snapshot.hasData || !snapshot.data!) {
          // Display repair page if the display flag is false or error occurs.
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  title: Text(
                    'Repair Needed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: responsiveValue(context, 20, 22, 24, 26),
                      color: Colors.white,
                    ),
                  ),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  pinned: false,
                  floating: false,
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'This internship page is currently under repair. Please try again later.',
                        style: TextStyle(
                          fontSize: responsiveValue(context, 16, 18, 20, 22),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Display internship dashboard if display flag is true.
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.black,
                  title: Text(
                    '$documentId Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: responsiveValue(context, 13, 23, 27, 31),
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    softWrap: true,
                  ),
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  pinned: false, // Set to false so it scrolls out of view
                  floating: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),


                // Use a SliverGrid to show the feature boxes
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                      horizontal: responsiveValue(context, 16, 20, 24, 28), vertical: responsiveValue(context, 16, 20, 24, 28)),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                      crossAxisSpacing: responsiveValue(context, 12, 14, 16, 18),
                      mainAxisSpacing: responsiveValue(context, 12, 14, 16, 18),
                      childAspectRatio: aspectRatio,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        return HoverableFeatureBox(
                          index: index,
                          userId: userId,
                          documentId: documentId,
                        );
                      },
                      childCount: 8,
                    ),
                  ),
                ),
                // Add some extra spacing at the bottom
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: responsiveValue(context, 16, 20, 24, 28)),
                ),
              ],
            ),
          );

        }
      },
    );
  }
}

class HoverableFeatureBox extends StatefulWidget {
  final int index;
  final String userId;
  final String documentId;

  HoverableFeatureBox({
    required this.index,
    required this.userId,
    required this.documentId,
  });

  @override
  _HoverableFeatureBoxState createState() => _HoverableFeatureBoxState();
}

class _HoverableFeatureBoxState extends State<HoverableFeatureBox> {
  bool _isHovered = false;

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Feature definitions for each tile.
    List<Map<String, String>> features = [
      {
        'title': 'Internship Overview',
        'desc': 'Overview of the internship',
        'img': 'internship_overview.png'
      },
      {
        'title': 'Progress Tracking',
        'desc': 'Track your progress',
        'img': 'progress_tracking.png'
      },
      {
        'title': 'Learning Modules',
        'desc': 'Explore the course content',
        'img': 'learning_modules.png'
      },
      {
        'title': 'Assigned Tasks',
        'desc': 'View your assignments',
        'img': 'assigned_tasks.png'
      },
      {
        'title': 'Q&A Section',
        'desc': 'Get answers to your questions',
        'img': 'qa_section.png'
      },
      {
        'title': 'Feedback',
        'desc': 'Provide feedback and queries',
        'img': 'feedback.png'
      },
      {
        'title': 'Announcements',
        'desc': 'Stay updated with announcements',
        'img': 'announcements.png'
      },
      {
        'title': 'Projects',
        'desc': 'Submit your Projects here',
        'img': 'projects.png'
      },
    ];

    final feature = features[widget.index];

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: () {
            switch (feature['title']) {
              case 'Internship Overview':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        InternshipDetailsPage(internshipId: widget.documentId),
                  ),
                );
                break;
              case 'Announcements':
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AnnouncementPage()));
                break;
              case 'Feedback':
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FeedbackPage()));
                break;
              case 'Q&A Section':
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => QnaPage()));
                break;
              case 'Assigned Tasks':
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => UserTasksPage(documentId: '')));
                break;
              case 'Learning Modules':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InternshipCourseTiles(
                        userId: widget.userId, documentId: widget.documentId),
                  ),
                );
                break;
              case 'Projects':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InternProjectDisplayPage(
                        internId: widget.userId,
                        internshipId: widget.documentId),
                  ),
                );
                break;
              default:
                break;
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE3F9E5),
                  Color(0xFFEBF9FC),
                  Color(0xFFFFF0E1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(2, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding:
                  EdgeInsets.all(responsiveValue(context, 10, 12, 14, 16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.asset(
                      feature['img']!,
                      height:
                      responsiveValue(context, 140, 160, 180, 200),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.broken_image,
                          size: responsiveValue(context, 40, 45, 50, 55),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                    EdgeInsets.all(responsiveValue(context, 8, 10, 12, 14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          feature['title']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: responsiveValue(context, 16, 18, 20, 22),
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                            height:
                            responsiveValue(context, 4, 6, 8, 10)),
                        Text(
                          feature['desc']!,
                          style: TextStyle(
                            fontSize: responsiveValue(context, 12, 14, 16, 18),
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                            height:
                            responsiveValue(context, 8, 10, 12, 14)),
                        ElevatedButton(
                          onPressed: () {
                            switch (feature['title']) {
                              case 'Internship Overview':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InternshipDetailsPage(
                                                internshipId:
                                                widget.documentId)));
                                break;
                              case 'Announcements':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AnnouncementPage()));
                                break;
                              case 'Progress Tracking':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InternshipProgressDashboardTile(
                                                userid: widget.userId,
                                                internship_name:
                                                widget.documentId)));
                                break;
                              case 'Feedback':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            FeedbackPage()));
                                break;
                              case 'Q&A Section':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => QnaPage()));
                                break;
                              case 'Assigned Tasks':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            UserTasksPage(documentId: '')));
                                break;
                              case 'Learning Modules':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InternshipCourseTiles(
                                                userId: widget.userId,
                                                documentId:
                                                widget.documentId)));
                                break;
                              case 'Projects':
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            InternProjectDisplayPage(
                                                internId: widget.userId,
                                                internshipId:
                                                widget.documentId)));
                                break;
                              default:
                                break;
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:
                              responsiveValue(context, 12, 14, 16, 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
