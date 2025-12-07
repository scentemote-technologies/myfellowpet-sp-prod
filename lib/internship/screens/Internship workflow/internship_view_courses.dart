import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'internship_progress_page.dart';

/// MAIN PAGE
class InternshipViewCoursePage extends StatefulWidget {
  final String courseName;
  final String internship_name;
  final String currentUid;

  InternshipViewCoursePage({
    required this.courseName,
    required this.internship_name,
    required this.currentUid,
  });

  @override
  _InternshipViewCoursePageState createState() => _InternshipViewCoursePageState();
}

class _InternshipViewCoursePageState extends State<InternshipViewCoursePage> {
  String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String selectedSection = ''; // Selected section name
  String selectedSubsection = ''; // "Media" or "Quizzes"
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, Map<String, dynamic>> sectionCompletionStatus = {};

  @override
  void initState() {
    super.initState();
    _fetchUserProgress();
  }

  // Fetch user progress from Firestore
  Future<void> _fetchUserProgress() async {
    DocumentSnapshot progressSnapshot = await FirebaseFirestore.instance
        .collection('internships')
        .doc(widget.courseName)
        .collection('userProgress')
        .doc(userId)
        .get();

    if (progressSnapshot.exists) {
      Map<String, dynamic> progressData =
      progressSnapshot.data() as Map<String, dynamic>;
      setState(() {
        progressData.forEach((sectionName, sectionData) {
          sectionCompletionStatus[sectionName] = sectionData;
        });
      });
    }
  }

  // Update progress in Firestore
  Future<void> _updateProgress(
      String sectionName, bool mediaCompleted, bool quizCompleted, int quizScore) async {
    await FirebaseFirestore.instance
        .collection('internships')
        .doc(widget.courseName)
        .collection('userProgress')
        .doc(userId)
        .update({
      'sectionsCompleted.$sectionName': {
        'quizCompleted': quizCompleted,
        'quizScore': quizScore,
      }
    });
  }

  // For phone: layout with left drawer for sections and right drawer for progress.
  Widget _buildPhoneLayout() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.courseName, style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF2562E8),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Right drawer action for progress
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.bar_chart, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      // Left drawer for section selection
      drawer: Drawer(
        child: SectionSelectionPanel(
          internship_name: widget.internship_name,
          courseName: widget.courseName,
          onSectionSelected: (sectionName) {
            setState(() {
              selectedSection = sectionName;
              selectedSubsection = 'Media'; // default to Media
            });
            _scaffoldKey.currentState?.closeDrawer();
          },
          onSubsectionSelected: (subsection) {
            setState(() {
              selectedSubsection = subsection;
            });
            _scaffoldKey.currentState?.closeDrawer();
          },
        ),
      ),
      // Right drawer for progress statistics
      endDrawer: Drawer(
        child: InternshipProgressPage(
          courseName: widget.courseName,
          internship_name: widget.internship_name,
        ),
      ),
      // Floating Action Button opens the left drawer (menu)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        icon: Icon(Icons.menu),
        label: Text('Menu'),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Content panel
            Container(
              height: MediaQuery.of(context).size.height * 0.75,
              color: Colors.white,
              child: ContentPanel(
                internship_name: widget.internship_name,
                courseName: widget.courseName,
                sectionName: selectedSection,
                subsection: selectedSubsection,
                sectionCompletionStatus: sectionCompletionStatus,
                updateProgress: _updateProgress,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Tablet/Desktop layout: use left drawer for sections and right drawer for progress.
  Widget _buildTabletDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.courseName, style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF2562E8),
      ),
      body: Row(
        children: [
          // Left Panel: Section Selection
          Expanded(
            flex: 2,
            child: SectionSelectionPanel(
              internship_name: widget.internship_name,
              courseName: widget.courseName,
              onSectionSelected: (sectionName) {
                setState(() {
                  selectedSection = sectionName;
                  selectedSubsection = 'Media';
                });
              },
              onSubsectionSelected: (subsection) {
                setState(() {
                  selectedSubsection = subsection;
                });
              },
            ),
          ),
          // Middle Panel: Content
          Expanded(
            flex: 3,
            child: ContentPanel(
              internship_name: widget.internship_name,
              courseName: widget.courseName,
              sectionName: selectedSection,
              subsection: selectedSubsection,
              sectionCompletionStatus: sectionCompletionStatus,
              updateProgress: _updateProgress,
            ),
          ),
          // Divider
          Container(width: 2, color: Colors.grey),
          // Right Panel: Progress
          Expanded(
            flex: 1,
            child: InternshipProgressPage(
              courseName: widget.courseName,
              internship_name: widget.internship_name,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          bool isPhone = constraints.maxWidth < 600;
          return isPhone ? _buildPhoneLayout() : _buildTabletDesktopLayout();
        },
    );
  }
}

// ----------------------------------------------------------------
// SECTION SELECTION PANEL
// ----------------------------------------------------------------
class SectionSelectionPanel extends StatefulWidget {
  final String courseName;
  final String internship_name;
  final Function(String) onSectionSelected;
  final Function(String) onSubsectionSelected;

  SectionSelectionPanel({
    required this.courseName,
    required this.onSectionSelected,
    required this.onSubsectionSelected,
    required this.internship_name,
  });

  @override
  _SectionSelectionPanelState createState() => _SectionSelectionPanelState();
}

class _SectionSelectionPanelState extends State<SectionSelectionPanel> {
  String? _selectedSection;
  String? _selectedSubsection;
  Map<String, Map<String, dynamic>> sectionCompletionStatus = {};
  final ScrollController _scrollController = ScrollController(); // New controller

  @override
  void initState() {
    super.initState();
    _fetchSectionCompletionStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSectionCompletionStatus() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    try {
      var userProgressDoc = await FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .get();

      if (userProgressDoc.exists &&
          userProgressDoc.data() != null &&
          userProgressDoc.data()!.isNotEmpty) {
        var data = userProgressDoc.data();
        var sectionsCompleted = data?['sectionsCompleted'] ?? {};
        setState(() {
          sectionCompletionStatus =
          Map<String, Map<String, dynamic>>.from(sectionsCompleted);
        });
      } else {
        setState(() {
          sectionCompletionStatus = {};
        });
      }
    } catch (e) {
      setState(() {
        sectionCompletionStatus = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Color(0xFF284A0E), width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderText(),
            SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('internships')
                  .doc(widget.internship_name)
                  .collection('userProgress')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, progressSnapshot) {
                if (progressSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!progressSnapshot.hasData ||
                    !progressSnapshot.data!.exists ||
                    (progressSnapshot.data!.data() as Map<String, dynamic>?)?.isEmpty == true) {
                  return _buildSections();
                }
                var userProgressData = progressSnapshot.data!.data() as Map<String, dynamic>;
                var sectionsCompleted = userProgressData['sectionsCompleted'] ?? {};
                return _buildSectionsWithCompletionStatus(sectionsCompleted);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chapters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            'Explore chapters, videos, quizzes.\nTrack your progress & master the course.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSections() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
          .collection('sections')
          .snapshots(),
      builder: (context, sectionSnapshot) {
        if (sectionSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!sectionSnapshot.hasData || sectionSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No sections available.'));
        }
        var sectionDocs = sectionSnapshot.data!.docs;
        sectionDocs.sort((a, b) => int.parse(a['order'] ?? '0').compareTo(int.parse(b['order'] ?? '0')));
        if (_selectedSection == null && sectionDocs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedSection = sectionDocs.first.id;
              _selectedSubsection = 'Media';
            });
            widget.onSectionSelected(_selectedSection!);
            widget.onSubsectionSelected('Media');
          });
        }
        return _buildSectionTiles(sectionDocs, {});
      },
    );
  }

  Widget _buildSectionsWithCompletionStatus(Map<String, dynamic> sectionsCompleted) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
          .collection('sections')
          .snapshots(),
      builder: (context, sectionSnapshot) {
        if (sectionSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!sectionSnapshot.hasData || sectionSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No sections available.'));
        }
        var sectionDocs = sectionSnapshot.data!.docs;
        sectionDocs.sort((a, b) => int.parse(a['order'] ?? '0').compareTo(int.parse(b['order'] ?? '0')));
        return _buildSectionTiles(sectionDocs, sectionsCompleted);
      },
    );
  }

  Widget _buildSectionTiles(List<DocumentSnapshot> sectionDocs, Map<String, dynamic> sectionsCompleted) {
    return ListView(
      key: PageStorageKey("sectionPanelList"),
      controller: _scrollController,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(), // if already inside a scrollable parent
      children: sectionDocs.asMap().entries.map((entry) {
        final index = entry.key;
        final sectionDoc = entry.value;
        final sectionName = sectionDoc.id;
        bool quizCompleted = sectionsCompleted[sectionName]?['quizCompleted'] ?? false;
        int quizScore = sectionsCompleted[sectionName]?['quizScore'] ?? 0;
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header row
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: Color(0xFF2562E8), shape: BoxShape.circle),
                    child: Center(child: Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 16))),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sectionName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      maxLines: 10, // Allow up to two lines
                      overflow: TextOverflow.ellipsis, // Optional: will only ellipsize if it exceeds 2 lines
                    ),

                  ),
                ],
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  children: [
                    // Media row
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSection = sectionName;
                          _selectedSubsection = 'Media';
                        });
                        widget.onSectionSelected(sectionName);
                        widget.onSubsectionSelected('Media');
                      },
                      child: Container(
                        color: _selectedSection == sectionName && _selectedSubsection == 'Media'
                            ? Colors.blue.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          title: Row(
                            children: [
                              Icon(Icons.arrow_forward, color: Colors.grey),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${index + 1}.1 Video & PDF Material',
                                  maxLines: 10,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),

                              ),
                            ],
                          ),
                          trailing: quizCompleted ? Icon(Icons.check, color: Colors.green) : null,
                        ),
                      ),
                    ),
                    // Quizzes row
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSection = sectionName;
                          _selectedSubsection = 'Quizzes';
                        });
                        widget.onSectionSelected(sectionName);
                        widget.onSubsectionSelected('Quizzes');
                      },
                      child: Container(
                        color: _selectedSection == sectionName && _selectedSubsection == 'Quizzes'
                            ? Colors.blue.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          title: Row(
                            children: [
                              Icon(Icons.arrow_forward, color: Colors.grey),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${index + 1}.2 Quizzes',
                                  maxLines: 10,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                          trailing: (quizCompleted && quizScore >= 80)
                              ? Icon(Icons.check, color: Colors.green)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ----------------------------------------------------------------
// CONTENT PANEL: Switches between Media and Quizzes
// ----------------------------------------------------------------
class ContentPanel extends StatelessWidget {
  final String internship_name;
  final String courseName;
  final String sectionName;
  final String subsection;
  final Map<String, Map<String, dynamic>> sectionCompletionStatus;
  final Function(String, bool, bool, int) updateProgress;

  ContentPanel({
    required this.courseName,
    required this.sectionName,
    required this.subsection,
    required this.sectionCompletionStatus,
    required this.updateProgress,
    required this.internship_name,
  });

  @override
  Widget build(BuildContext context) {
    if (sectionName.isEmpty) {
      return Center(child: Text('Please select a section from the menu.'));
    }
    if (subsection == 'Media') {
      return MediaContent(
        courseName: courseName,
        sectionName: sectionName,
        sectionCompletionStatus: sectionCompletionStatus,
        updateProgress: updateProgress,
      );
    } else if (subsection == 'Quizzes') {
      return QuizContent(
        internship_name: internship_name,
        courseName: courseName,
        sectionName: sectionName,
        sectionCompletionStatus: sectionCompletionStatus,
        updateProgress: updateProgress,
      );
    } else {
      return Center(child: Text('Please select Media or Quizzes.'));
    }
  }
}

// ----------------------------------------------------------------
// MEDIA CONTENT
// ----------------------------------------------------------------
class MediaContent extends StatelessWidget {
  final String courseName;
  final String sectionName;
  final Map<String, Map<String, dynamic>> sectionCompletionStatus;
  final Function(String, bool, bool, int) updateProgress;

  MediaContent({
    required this.courseName,
    required this.sectionName,
    required this.sectionCompletionStatus,
    required this.updateProgress,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(courseName)
          .collection('sections')
          .doc(sectionName)
          .collection('media')
          .get(),
      builder: (context, mediaSnapshot) {
        if (mediaSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (mediaSnapshot.hasError) {
          // This will show the actual exception message
          return Center(
            child: Text(
              'Error loading media:\n${mediaSnapshot.error}',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!mediaSnapshot.hasData || mediaSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No media available for this section.'));
        }
        var mediaDocs = mediaSnapshot.data!.docs;
        return ListView(
          children: mediaDocs.map((mediaDoc) {
            Map<String, dynamic> mediaData =
            mediaDoc.data() as Map<String, dynamic>;

            // Guard against missing or invalid URLs
            final url = mediaData[mediaDoc.id == 'video' ? 'video_url' : 'pdf_url'];
            if (url == null || url is! String || url.trim().isEmpty) {
              return ListTile(
                title: Text(
                  'Skipping ${mediaDoc.id}: missing ${mediaDoc.id == 'video' ? 'video_url' : 'pdf_url'}',
                  style: TextStyle(color: Colors.orange),
                ),
              );
            }

            if (mediaDoc.id == 'video') {
              return MediaCard(mediaType: 'Video', url: url);
            } else if (mediaDoc.id == 'pdf') {
              return MediaCard(mediaType: 'PDF', url: url);
            }
            return SizedBox.shrink();
          }).toList(),
        );
      },
    );
  }
}

// A card for Video or PDF content
class MediaCard extends StatelessWidget {
  final String mediaType;
  final String url;

  MediaCard({required this.mediaType, required this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(top: 10, left: 15, right: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Color(0xFFFDFDFD),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$mediaType:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            if (mediaType == 'Video') ...[
              VideoPlayerCard(videoUrl: url),
            ] else if (mediaType == 'PDF') ...[
              DownloadButton(url: url),
            ],
          ],
        ),
      ),
    );
  }
}

// Button to download/open PDF
class DownloadButton extends StatelessWidget {
  final String url;

  DownloadButton({required this.url});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _launchURL(url),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        side: BorderSide(color: Colors.transparent, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, spreadRadius: 2)],
        ),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FontAwesomeIcons.filePdf, size: 24, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('Download PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

// Video Player using Chewie
class VideoPlayerCard extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerCard({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerCardState createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;

  @override
  void initState() {
    super.initState();
    // 1. Lock the orientation (e.g., portrait only).
    //    If you prefer landscape only, replace with landscapeLeft / landscapeRight.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: 16 / 9,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      showControls: true,
      allowMuting: true,
      showControlsOnInitialize: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.red,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
      ),
      autoInitialize: true,
    );
    _videoPlayerController.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // 2. Reset orientation to all possible orientations when leaving this page.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    _chewieController.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget’s code remains unchanged, except for locking orientation.
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.25,
      width: double.infinity,
      child: Chewie(controller: _chewieController),
    );
  }
}
// ----------------------------------------------------------------
// QUIZ CONTENT
// ----------------------------------------------------------------
class QuizContent extends StatefulWidget {
  final String internship_name;
  final String courseName;
  final String sectionName;
  final Map<String, Map<String, dynamic>> sectionCompletionStatus;
  final Function(String, bool, bool, int) updateProgress;

  QuizContent({
    required this.courseName,
    required this.sectionName,
    required this.sectionCompletionStatus,
    required this.updateProgress,
    required this.internship_name,
  });

  @override
  _QuizContentState createState() => _QuizContentState();
}

class _QuizContentState extends State<QuizContent> with AutomaticKeepAliveClientMixin {
  // State variables remain the same
  Map<String, String> selectedAnswers = {};
  Map<String, bool> answerStatus = {};
  int correctAnswersCount = 0;
  bool showResult = false;
  bool showRetry = false;
  int quizScore = 0;
  bool isQuizAttempted = false;
  List<QueryDocumentSnapshot> quizDocs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // Preserve state across rebuilds

  @override
  void didUpdateWidget(QuizContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionName != widget.sectionName) {
      _resetQuizState();
    }
  }

  void _resetQuizState() {
    setState(() {
      selectedAnswers.clear();
      answerStatus.clear();
      correctAnswersCount = 0;
      showResult = false;
      showRetry = false;
      quizScore = 0;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important when using AutomaticKeepAliveClientMixin
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get(),
      builder: (context, userProgressSnapshot) {
        if (userProgressSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!userProgressSnapshot.hasData || userProgressSnapshot.data!.data() == null) {
          _createUserProgress();
          return _buildQuizUI();
        }
        var userProgressData = userProgressSnapshot.data!.data() as Map<String, dynamic>;
        isQuizAttempted = userProgressData['sectionsCompleted']?[widget.sectionName]?['quizCompleted'] ?? false;
        if (isQuizAttempted) {
          quizScore = userProgressData['sectionsCompleted']?[widget.sectionName]?['quizScore'] ?? 0;
          return quizScore >= 80 ? _buildPassedUI() : _buildRetryUI();
        } else {
          return _buildQuizUI();
        }
      },
    );
  }

  Future<void> _createUserProgress() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .set({
        'sectionsCompleted': {
          widget.sectionName: {
            'quizCompleted': false,
            'quizScore': 0,
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating user progress: $e');
    }
  }

  Widget _buildPassedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 30),
          SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(maxWidth: 300),
            child: Text(
              'You passed with a score of $quizScore!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizUI() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
          .collection('sections')
          .doc(widget.sectionName)
          .collection('quizzes')
          .get(),
      builder: (context, quizSnapshot) {
        // 1) Still loading?
        if (quizSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        // 2) Did Firestore throw an exception?
        if (quizSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error loading quizzes for section:\n"${widget.sectionName}"',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    quizSnapshot.error.toString(),
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: Text('Retry', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
          );
        }

        // 3) No data or empty subcollection?
        if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No quizzes found for section:\n"${widget.sectionName}".',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        }

        // 4) We do have at least one document.
        final allDocs = quizSnapshot.data!.docs;
        quizDocs = allDocs; // save for later use

        // 5) Run validation pass across each quiz doc. Collect any errors.
        List<String> invalidSummaries = [];
        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) {
            invalidSummaries.add(
              '• Quiz ID "${doc.id}" has no data map at all.',
            );
            continue;
          }

          // Check for missing keys:
          List<String> missingKeys = [];
          if (!data.containsKey('question')) missingKeys.add('question');
          if (!data.containsKey('options')) missingKeys.add('options');
          if (!data.containsKey('correct_answer')) missingKeys.add('correct_answer');

          if (missingKeys.isNotEmpty) {
            invalidSummaries.add(
              '• Quiz "${doc.id}" is missing field(s): ${missingKeys.join(', ')}.',
            );
            continue;
          }

          // Check that question is a non-empty string
          final questionField = data['question'];
          if (questionField is! String || questionField.trim().isEmpty) {
            invalidSummaries.add(
              '• Quiz "${doc.id}" has an invalid "question" (should be a non-empty String).',
            );
          }

          // Check that options is a List<String> of length ≥ 2
          final rawOptions = data['options'];
          if (rawOptions is! List) {
            invalidSummaries.add(
              '• Quiz "${doc.id}" has "options" that is not a List.',
            );
          } else {
            // Further check each element is a non-empty String
            List<String> badEntries = [];
            for (var opt in rawOptions) {
              if (opt is! String || opt.trim().isEmpty) {
                badEntries.add(opt.toString());
              }
            }
            if (badEntries.isNotEmpty) {
              invalidSummaries.add(
                '• Quiz "${doc.id}" has invalid entries in "options": ${badEntries.join(', ')}.',
              );
            }
            if (rawOptions.length < 2) {
              invalidSummaries.add(
                '• Quiz "${doc.id}" needs at least 2 options, but only found ${rawOptions.length}.',
              );
            }
          }

          // Check that correct_answer is a String and one of the options
          final correctField = data['correct_answer'];
          if (correctField is! String || correctField.trim().isEmpty) {
            invalidSummaries.add(
              '• Quiz "${doc.id}" has an invalid "correct_answer" (must be non-empty String).',
            );
          } else if (data['options'] is List<String>) {
            List<String> opts = List<String>.from(data['options']);
            if (!opts.contains(correctField)) {
              invalidSummaries.add(
                '• Quiz "${doc.id}": "correct_answer" not found among options.',
              );
            }
          }
        }

        // 6) If there are any invalid quizzes, show them all at once.
        if (invalidSummaries.isNotEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issues detected in quiz data for section:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                SizedBox(height: 8),
                Text(
                  '"${widget.sectionName}" (${allDocs.length} doc(s) fetched)',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 16),
                ...invalidSummaries.map((msg) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    msg,
                    style: TextStyle(fontSize: 15, color: Colors.orange.shade900),
                  ),
                )),
                SizedBox(height: 24),
                Text(
                  'Please fix the above field errors in Firestore under:\n'
                      'courses → ${widget.courseName} → sections → ${widget.sectionName} → quizzes',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('Re‐check Now'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          );
        }

        // 7) All quizzes are valid → proceed to build the normal quiz list:
        return ListView(
          key: PageStorageKey("quizContent_${widget.sectionName}"),
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            _buildQuizHeader(),
            _buildQuizRules(),
            SizedBox(height: 20),
            ...allDocs.map((quizDoc) {
              final quizData = quizDoc.data() as Map<String, dynamic>;
              final question = quizData['question'] as String;
              final options = List<String>.from(quizData['options']);
              final correctAnswer = quizData['correct_answer'] as String;

              return QuizCard(
                question: question,
                options: options,
                correctAnswer: correctAnswer,
                selectedAnswer: selectedAnswers[quizDoc.id] ?? '',
                isSubmitted: showResult,
                onAnswerSelected: (String selectedOption) {
                  setState(() {
                    selectedAnswers[quizDoc.id] = selectedOption;
                    answerStatus[quizDoc.id] = (selectedOption == correctAnswer);
                  });
                },
              );
            }).toList(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitQuiz,
              child: Text('Submit Quiz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
              ),
            ),
            if (showResult) ...[
              SizedBox(height: 20),
              if (showRetry) _buildRetryUI(),
            ],
          ],
        );
      },
    );
  }


  void _submitQuiz() {
    setState(() {
      correctAnswersCount = 0;
      for (var quizDoc in quizDocs) {
        var quizData = quizDoc.data() as Map<String, dynamic>;
        String correctAnswer = quizData['correct_answer'].trim();
        String userAnswer = selectedAnswers[quizDoc.id]?.trim() ?? '';
        if (userAnswer == correctAnswer) {
          correctAnswersCount++;
        }
      }
      quizScore = ((correctAnswersCount / quizDocs.length) * 100).round();
      widget.updateProgress(widget.sectionName, false, true, quizScore);
      _updateQuizCompletion(widget.sectionName, quizScore);
      showResult = true;
      showRetry = quizScore < 80;
    });
  }

  Future<void> _updateQuizCompletion(String sectionName, int quizScore) async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    bool quizCompleted = quizScore >= 80;
    await FirebaseFirestore.instance
        .collection('internships')
        .doc(widget.internship_name)
        .collection('userProgress')
        .doc(userId)
        .update({
      'sectionsCompleted.$sectionName.quizCompleted': quizCompleted,
      'sectionsCompleted.$sectionName.quizScore': quizScore,
    });
  }

  Widget _buildRetryUI() {
    return Column(
      children: [
        Icon(Icons.warning, color: Colors.red, size: 30),
        SizedBox(height: 10),
        Container(
          constraints: BoxConstraints(maxWidth: 300),
          child: Text(
            'Your score is $quizScore. Try again!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _retryQuiz,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 10),
              Text('Retry Quiz', style: TextStyle(color: Colors.white)),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
          ),
        ),
      ],
    );
  }

  void _retryQuiz() async {
    setState(() {
      selectedAnswers.clear();
      correctAnswersCount = 0;
      showResult = false;
      showRetry = false;
      quizScore = 0;
    });
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('internships')
          .doc(widget.internship_name)
          .collection('userProgress')
          .doc(userId)
          .update({
        'sectionsCompleted.${widget.sectionName}': FieldValue.delete(),
      });
    } catch (e) {
      print('Error resetting quiz: $e');
    }
  }

  Widget _buildQuizHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quiz', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 8),
        Text(
          'Answer the questions below to proceed. Make sure you understand each topic before attempting the quiz.',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildQuizRules() {
    return Container(
      padding: EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Points to remember:',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
          SizedBox(height: 10),
          Text(
            '• Each question is worth 1 point.\n• You need at least 80% to pass.\n• Once submitted, your score will be displayed.',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}


// ----------------------------------------------------------------
// QUIZ CARD
// ----------------------------------------------------------------
class QuizCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String selectedAnswer;
  final bool isSubmitted;
  final Function(String) onAnswerSelected;

  QuizCard({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.isSubmitted,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(top: 15),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      shadowColor: Colors.blueGrey,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            SizedBox(height: 15),
            ...options.map((option) {
              bool isSelected = (selectedAnswer == option);
              bool isCorrect = (correctAnswer == option);
              bool isIncorrect = (selectedAnswer == option && !isCorrect);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    if (isSubmitted)
                      Icon(
                        isCorrect ? Icons.check_circle : isIncorrect ? Icons.cancel : null,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () => onAnswerSelected(option),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
