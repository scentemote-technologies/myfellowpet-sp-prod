import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:myfellowpet_sp/internship/screens/courses/progressbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../fullscreenchecker.dart';

/// MAIN PAGE WITH RESPONSIVE LAYOUT
class ViewCoursePage extends StatefulWidget {
  final String courseName;

  ViewCoursePage({required this.courseName});

  @override
  _ViewCoursePageState createState() => _ViewCoursePageState();
}

class _ViewCoursePageState extends State<ViewCoursePage> {
  String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String selectedSection = ''; // To keep track of the selected section
  String selectedSubsection = ''; // To keep track of the selected subsection (Media or Quizzes)
  Map<String, Map<String, dynamic>> sectionCompletionStatus = {}; // To store completion status

  @override
  void initState() {
    super.initState();
    _fetchUserProgress();
  }

  // Fetch user progress from Firestore
  Future<void> _fetchUserProgress() async {
    DocumentSnapshot progressSnapshot = await FirebaseFirestore.instance
        .collection('courses')
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
        .collection('courses')
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

  // Phone layout using drawers
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
            // Right drawer for progress
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
      drawer: Drawer(
        child: SectionSelectionPanel(
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
        endDrawer: Drawer(
          child: ProgressPage(courseName: widget.courseName),
        ),
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
              Container(
                height: MediaQuery.of(context).size.height * 0.75,
                color: Colors.white,
                child: ContentPanel(
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tablet/Desktop layout using a row of panels
  Widget _buildTabletDesktopLayout() {
    return FullscreenCheckWrapper(
      child: Scaffold(
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
              child: ProgressPage(courseName: widget.courseName),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to decide which layout to use based on screen width.
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isPhone = constraints.maxWidth < 600;
        return isPhone ? _buildPhoneLayout() : _buildTabletDesktopLayout();
      },
    );
  }
}

/// SECTION SELECTION PANEL
class SectionSelectionPanel extends StatefulWidget {
  final String courseName;
  final Function(String) onSectionSelected;
  final Function(String) onSubsectionSelected;

  SectionSelectionPanel({
    required this.courseName,
    required this.onSectionSelected,
    required this.onSubsectionSelected,
  });

  @override
  _SectionSelectionPanelState createState() => _SectionSelectionPanelState();
}

class _SectionSelectionPanelState extends State<SectionSelectionPanel> {
  String? _selectedSection;
  String? _selectedSubsection;
  Map<String, Map<String, dynamic>> sectionCompletionStatus = {};
  final ScrollController _scrollController = ScrollController();

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

  // Fetch section completion status from Firestore
  Future<void> _fetchSectionCompletionStatus() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    try {
      var userProgressDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
          .collection('userProgress')
          .doc(userId)
          .get();

      if (userProgressDoc.exists &&
          userProgressDoc.data() != null &&
          userProgressDoc.data()!.isNotEmpty) {
        var data = userProgressDoc.data();
        var sectionsCompleted = data?['sectionsCompleted'] ?? {};
        setState(() {
          sectionCompletionStatus = Map<String, Map<String, dynamic>>.from(sectionsCompleted);
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
    return Scaffold(
      body: SingleChildScrollView(
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
              // Header text
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Chapters',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Explore the topics for the course: ${widget.courseName}\nTrack your progress and complete each section.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              // Stream builder to listen to user progress changes
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('courses')
                    .doc(widget.courseName)
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
      ),
    );
  }

  // Build sections when no progress data exists
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
        sectionDocs.sort((a, b) {
          int orderA = int.parse(a['order']);
          int orderB = int.parse(b['order']);
          return orderA.compareTo(orderB);
        });
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

  // Build sections with completion status
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
        sectionDocs.sort((a, b) {
          int orderA = int.parse(a['order']);
          int orderB = int.parse(b['order']);
          return orderA.compareTo(orderB);
        });
        return _buildSectionTiles(sectionDocs, sectionsCompleted);
      },
    );
  }

  // Build section tiles
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

  // Show dialog when quiz is already completed
  void _showQuizCompletedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Quiz Completed'),
          content: Row(
            children: [
              Text('You have already passed that quiz!'),
              SizedBox(width: 10),
              Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

/// CONTENT PANEL: Switches between Media and Quizzes
class ContentPanel extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    if (subsection == 'Media') {
      return MediaContent(
        courseName: courseName,
        sectionName: sectionName,
        sectionCompletionStatus: sectionCompletionStatus,
        updateProgress: updateProgress,
      );
    } else if (subsection == 'Quizzes') {
      return QuizContent(
        courseName: courseName,
        sectionName: sectionName,
        sectionCompletionStatus: sectionCompletionStatus,
        updateProgress: updateProgress,
      );
    } else {
      return Center(child: Text('Please select a subsection.'));
    }
  }
}

/// MEDIA CONTENT
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
        if (!mediaSnapshot.hasData || mediaSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No media available for this section.'));
        }
        var mediaDocs = mediaSnapshot.data!.docs;
        return ListView(
          children: mediaDocs.map((mediaDoc) {
            String mediaType = mediaDoc.id;
            Map<String, dynamic> mediaData = mediaDoc.data() as Map<String, dynamic>;
            if (mediaType == 'video') {
              return MediaCard(mediaType: 'Video', url: mediaData['video_url']);
            } else if (mediaType == 'pdf') {
              return MediaCard(mediaType: 'PDF', url: mediaData['pdf_url']);
            }
            return SizedBox.shrink();
          }).toList(),
        );
      },
    );
  }
}
// Video Player using Chewie - CORRECTED VERSION
class VideoPlayerCard extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerCard({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerCardState createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<VideoPlayerCard> {
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isLoading = true; // This handles the loading state

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  // We put the logic in its own method to keep initState clean
  Future<void> initializePlayer() async {
    // Make sure the URL is not empty before trying to use it
    if (widget.videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading if there's no URL
        });
      }
      return;
    }

    // Use the correct, non-deprecated constructor
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    // Wait for the controller to initialize
    await _videoPlayerController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: 16 / 9,
      autoPlay: false,
      looping: false,
    );

    // Once everything is ready, update the UI to show the player
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    // Only dispose chewieController if it was successfully initialized
    if (!_isLoading) {
      _chewieController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.25,
      width: double.infinity,
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(), // Show this while loading
      )
          : Chewie(controller: _chewieController), // Show this when loaded
    );
  }
}
/// QUIZ CONTENT
class QuizContent extends StatefulWidget {
  final String courseName;
  final String sectionName;
  final Map<String, Map<String, dynamic>> sectionCompletionStatus;
  final Function(String, bool, bool, int) updateProgress;

  QuizContent({
    required this.courseName,
    required this.sectionName,
    required this.sectionCompletionStatus,
    required this.updateProgress,
  });

  @override
  _QuizContentState createState() => _QuizContentState();
}

class _QuizContentState extends State<QuizContent> {
  Map<String, String> selectedAnswers = {};
  Map<String, bool> answerStatus = {};
  int correctAnswersCount = 0;
  bool showResult = false;
  bool showRetry = false;
  int quizScore = 0;
  bool isQuizAttempted = false;
  List<QueryDocumentSnapshot> quizDocs = [];
  ScrollController _scrollController = ScrollController();

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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseName)
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
      await FirebaseFirestore.instance.collection('courses').doc(widget.courseName).collection('userProgress').doc(userId).set({
        'sectionsCompleted': {
          widget.sectionName: {
            'quizCompleted': false,
            'quizScore': 0,
          },
        },
      });
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
          Text(
            'You passed with a score of $quizScore!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
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
        if (quizSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!quizSnapshot.hasData || quizSnapshot.data!.docs.isEmpty) {
          return Center(child: Text('No quizzes available for this section.'));
        }
        quizDocs = quizSnapshot.data!.docs;
        return SingleChildScrollView(
          key: PageStorageKey("quizContent_${widget.sectionName}"),
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuizHeader(),
              _buildQuizRules(),
              SizedBox(height: 20),
              Column(
                children: quizDocs.map((quizDoc) {
                  var quizData = quizDoc.data() as Map<String, dynamic>;
                  String question = quizData['question'];
                  List<String> options = List<String>.from(quizData['options']);
                  String correctAnswer = quizData['correct_answer'];
                  return QuizCard(
                    question: question,
                    options: options,
                    correctAnswer: correctAnswer,
                    selectedAnswer: selectedAnswers[quizDoc.id] ?? '',
                    isSubmitted: showResult,
                    onAnswerSelected: (String selectedOption) {
                      setState(() {
                        selectedAnswers[quizDoc.id] = selectedOption;
                        answerStatus[quizDoc.id] = selectedOption == correctAnswer;
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitQuiz,
                child: Text('Submit Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 50),
                ),
              ),
              if (showResult) ...[
                SizedBox(height: 20),
                if (showRetry) _buildRetryUI(),
              ]
            ],
          ),
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
        .collection('courses')
        .doc(widget.courseName)
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
        Text(
          'Your score is $quizScore. Try again!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
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
          .collection('courses')
          .doc(widget.courseName)
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
        Text(
          'Quiz',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
        ),
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
          Text(
            'Points to remember:',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          SizedBox(height: 10),
          Text(
            '• Each question is worth 1 point.\n• You need at least 80% to pass the quiz.\n• Once submitted, your score will be displayed.',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

/// QUIZ CARD
class QuizCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String selectedAnswer;
  final bool isSubmitted;
  final Function(String) onAnswerSelected;

  const QuizCard({
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
            Text(
              question,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 15),
            ...options.map((option) {
              bool isSelected = selectedAnswer == option;
              bool isCorrect = correctAnswer == option;
              bool isIncorrect = selectedAnswer == option && !isCorrect;
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
                        softWrap: true,
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

/// MEDIA CARD
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
            Text(
              '$mediaType:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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

/// DOWNLOAD BUTTON FOR PDF
class DownloadButton extends StatelessWidget {
  final String url;

  DownloadButton({required this.url});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunch(uri.toString())) {
      await launch(uri.toString());
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
            Text(
              'Download PDF',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
