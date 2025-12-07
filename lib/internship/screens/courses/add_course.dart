import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCoursePage extends StatefulWidget {
  const AddCoursePage({super.key});

  @override
  _AddCoursePageState createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  String courseName = "";
  String courseDescription = "";
  String? courseImageUrl;
  String totalCourseTime = "";
  String currentCourseCost = "";
  String actualCourseCost = "";
  String domain = "Mobile Development"; // Default selected domain
  String downloadableDocuments = "";
  String totalvideos = "";
  List<Section> sections = [];
  Uint8List? selectedImageBytes;
  double uploadProgress = 0.0;

  // Image upload logic for the course
  Future<void> pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selectedImageBytes = result.files.first.bytes;
      });
      uploadImage();
    }
  }

  Future<void> uploadImage() async {
    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef
          .child('courses/${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = imageRef.putData(selectedImageBytes!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        courseImageUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  // Adding a section
  void addSection() {
    setState(() {
      sections.add(Section());
    });
  }

  // Save course with sections to Firestore
  Future<void> saveCourse() async {
    if (courseName.isEmpty || courseImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    try {
      // Save the course document with the name of the course as the document ID
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseName)
          .set({
        'course_name': courseName,
        'description': courseDescription,
        'current_cost': currentCourseCost,
        'actual_cost': actualCourseCost,
        'image_url': courseImageUrl,
        'total_course_time': totalCourseTime,
        'domain': domain, // Save the selected domain
        'downloadableDocuments': downloadableDocuments,
        'total_videos': totalvideos,
        'created_at': Timestamp.now(),
      });

      // For each section, add media (video, PDF, and quizzes) to the respective section
      for (int i = 0; i < sections.length; i++) {
        Section section = sections[i];

        // Get the section name (the section will be the name of the document)
        String sectionName = section.sectionName.isNotEmpty
            ? section.sectionName
            : 'Section ${i + 1}'; // Fallback to Section X if no name is provided

        // Create a section document in the sections collection of the course
        DocumentReference sectionDocRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(courseName)
            .collection('sections')
            .doc(sectionName);

        // Add quizzes (if any)
        for (var quiz in section.quizzes) {
          await sectionDocRef.collection('quizzes').add({
            'question': quiz.question,
            'options': quiz.options,
            'correct_answer': quiz.correctAnswer,
          });
        }

        // Add video (if it exists)
        if (section.videoUrl != null) {
          await sectionDocRef.collection('media').doc('video').set({
            'video_url': section.videoUrl,
          });
        }

        // Add PDF (if it exists)
        if (section.pdfUrl != null) {
          await sectionDocRef.collection('media').doc('pdf').set({
            'pdf_url': section.pdfUrl,
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Course'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Name Input
              TextField(
                decoration: const InputDecoration(labelText: 'Course Name'),
                onChanged: (value) {
                  setState(() {
                    courseName = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              TextField(
                decoration:
                const InputDecoration(labelText: 'Course Description'),
                maxLines: 3,
                onChanged: (value) {
                  setState(() {
                    courseDescription = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Total Course Time Input
              TextField(
                decoration: const InputDecoration(
                    labelText: 'Total Course Time (in hours)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    totalCourseTime = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Dropdown for domain selection
              DropdownButton<String>(
                value: domain,
                onChanged: (String? newValue) {
                  setState(() {
                    domain = newValue!;
                  });
                },
                items: <String>[
                  'Mobile Development',
                  'Web Development',
                  'Database'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                hint: const Text("Select Domain"),
              ),
              const SizedBox(height: 16),

              // Upload Course Image
              ElevatedButton(
                onPressed: pickImage,
                child: const Text('Select Course Image'),
              ),
              if (selectedImageBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Image.memory(selectedImageBytes!),
                ),
              const SizedBox(height: 16),

              // Section Management UI
              const Text('Sections:'),
              for (int i = 0; i < sections.length; i++) ...[
                SectionWidget(
                  section: sections[i],
                  sectionIndex: i + 1,
                  onUpdate: () {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: addSection,
                child: const Text('Add Section'),
              ),
              const SizedBox(height: 32),

              // Save Course
              ElevatedButton(
                onPressed: saveCourse,
                child: const Text('Save Course'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class Section {
  String sectionName = ''; // Allow section name to be editable
  Uint8List? videoBytes; // Store video as bytes (not URL)
  Uint8List? pdfBytes; // Store PDF as bytes (not URL)
  String? videoUrl; // Store URL after successful upload
  String? pdfUrl; // Store URL after successful upload
  List<Quiz> quizzes = []; // Store multiple quizzes

  Section(
      {this.videoBytes,
        this.pdfBytes,
        this.videoUrl,
        this.pdfUrl,
        this.quizzes = const []});
}

class Quiz {
  String question;
  List<String> options;
  String correctAnswer;

  Quiz(
      {required this.question,
        required this.options,
        required this.correctAnswer});
}

class SectionWidget extends StatefulWidget {
  final Section section;
  final int sectionIndex;
  final VoidCallback onUpdate;

  const SectionWidget(
      {super.key,
        required this.section,
        required this.sectionIndex,
        required this.onUpdate});

  @override
  _SectionWidgetState createState() => _SectionWidgetState();
}

class _SectionWidgetState extends State<SectionWidget> {
  double uploadProgress = 0.0;

  // Video upload logic for each section
  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      setState(() {
        widget.section.videoBytes = result.files.first.bytes;
        widget.section.videoUrl =
            result.files.first.name; // Save file name temporarily
      });

      // Now upload the actual video bytes
      uploadVideo(result.files.first.bytes!, result.files.first.name);
    }
  }

  Future<void> uploadVideo(Uint8List videoBytes, String videoName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final videoRef = storageRef.child('courses/videos/$videoName');
      UploadTask uploadTask = videoRef.putData(videoBytes);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        widget.section.videoUrl = downloadUrl; // Save the URL after uploading
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading video: $e')),
      );
    }
  }

  // PDF upload logic for each section
  Future<void> pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        widget.section.pdfBytes = result.files.first.bytes;
        widget.section.pdfUrl =
            result.files.first.name; // Save file name temporarily
      });

      // Now upload the actual PDF bytes
      uploadPdf(result.files.first.bytes!, result.files.first.name);
    }
  }

  Future<void> uploadPdf(Uint8List pdfBytes, String pdfName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final pdfRef = storageRef.child('courses/pdfs/$pdfName');
      UploadTask uploadTask = pdfRef.putData(pdfBytes);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        widget.section.pdfUrl = downloadUrl; // Save the URL after uploading
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading PDF: $e')),
      );
    }
  }

  // Quiz input logic for each section
  TextEditingController questionController = TextEditingController();
  TextEditingController optionController1 = TextEditingController();
  TextEditingController optionController2 = TextEditingController();
  TextEditingController optionController3 = TextEditingController();

  String? selectedCorrectAnswer;

  List<Quiz> quizzes = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Section ${widget.sectionIndex}:'),

        // Section name input
        TextField(
          decoration: const InputDecoration(labelText: 'Section Name'),
          onChanged: (value) {
            setState(() {
              widget.section.sectionName = value;
            });
          },
        ),

        // Video Selection Button
        ElevatedButton(
          onPressed: pickVideo,
          child: Text('Select Video for Section ${widget.sectionIndex}'),
        ),
        if (widget.section.videoUrl != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Video uploaded'),
          ),

        // PDF Selection Button
        ElevatedButton(
          onPressed: pickPdf,
          child: Text('Select PDF for Section ${widget.sectionIndex}'),
        ),
        if (widget.section.pdfUrl != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('PDF uploaded'),
          ),

        // Displaying already added quizzes as Tiles
        if (widget.section.quizzes.isNotEmpty)
          Column(
            children: quizzes.map((quiz) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(quiz.question),
                  subtitle: Text('Correct Answer: ${quiz.correctAnswer}'),
                ),
              );
            }).toList(),
          ),

        // Quiz Inputs for new quizzes
        TextField(
          controller: questionController,
          decoration: const InputDecoration(labelText: 'Quiz Question'),
        ),
        TextField(
          controller: optionController1,
          decoration: const InputDecoration(labelText: 'Option 1'),
        ),
        TextField(
          controller: optionController2,
          decoration: const InputDecoration(labelText: 'Option 2'),
        ),
        TextField(
          controller: optionController3,
          decoration: const InputDecoration(labelText: 'Option 3'),
        ),
        const SizedBox(height: 8),

        // Dropdown to select correct answer
        DropdownButton<String>(
          hint: const Text("Select Correct Answer"),
          value: selectedCorrectAnswer, // The selected value
          items: [
            optionController1.text,
            optionController2.text,
            optionController3.text,
          ]
              .where((option) => option.isNotEmpty) // Avoid empty options
              .map((option) {
            return DropdownMenuItem<String>(value: option, child: Text(option));
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedCorrectAnswer = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Add Quiz button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (questionController.text.isNotEmpty &&
                    selectedCorrectAnswer != null &&
                    optionController1.text.isNotEmpty &&
                    optionController2.text.isNotEmpty &&
                    optionController3.text.isNotEmpty) {
                  // Add quiz to the state's quizzes list
                  setState(() {
                    quizzes.add(Quiz(
                      question: questionController.text,
                      options: [
                        optionController1.text,
                        optionController2.text,
                        optionController3.text,
                      ],
                      correctAnswer: selectedCorrectAnswer!,
                    ));
                  });

                  // Clear input fields after adding the quiz
                  questionController.clear();
                  optionController1.clear();
                  optionController2.clear();
                  optionController3.clear();
                  selectedCorrectAnswer = null;

                  // Update the section's quizzes list
                  widget.section.quizzes = quizzes;

                  widget.onUpdate(); // Trigger a rebuild to update UI
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                        Text('Please fill out all fields to add a quiz')),
                  );
                }
              },
            ),
            const Text("Add Quiz")
          ],
        ),
      ],
    );
  }
}