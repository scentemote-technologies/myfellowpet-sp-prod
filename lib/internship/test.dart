import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String selectedInternship = ''; // Selected internship
  List<String> selectedCourses = []; // List of selected courses

  // Fetch all internships
  Future<List<QueryDocumentSnapshot>> _fetchInternships() async {
    try {
      var internshipsSnapshot = await FirebaseFirestore.instance
          .collection('internships')
          .get();
      return internshipsSnapshot.docs;
    } catch (e) {
      print("Error fetching internships: $e");
      return [];
    }
  }

  // Fetch all courses
  Future<List<QueryDocumentSnapshot>> _fetchCourses() async {
    try {
      var coursesSnapshot = await FirebaseFirestore.instance
          .collection('courses')
          .get();
      return coursesSnapshot.docs;
    } catch (e) {
      print("Error fetching courses: $e");
      return [];
    }
  }

  // Save selected courses as individual documents in "learning-modules" collection
  Future<void> _saveSelectedCourses() async {
    try {
      if (selectedInternship.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Please select an internship first."),
        ));
        return;
      }

      // Save each selected course as a document
      for (String courseId in selectedCourses) {
        await FirebaseFirestore.instance
            .collection('internships')
            .doc(selectedInternship)
            .collection('learning-modules')
            .doc(courseId)
            .set({'course_id': courseId});
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Selected courses saved successfully!"),
      ));
    } catch (e) {
      print("Error saving selected courses: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error saving courses."),
      ));
    }
  }

  // Fetch learning modules from the "learning-modules" collection of the selected internship
  Future<List<Map<String, dynamic>>> _fetchLearningModules() async {
    try {
      if (selectedInternship.isEmpty) return [];
      var modulesSnapshot = await FirebaseFirestore.instance
          .collection('internships')
          .doc(selectedInternship)
          .collection('learning-modules')
          .get();
      return modulesSnapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id; // Include document ID for deletion
        return data;
      }).toList();
    } catch (e) {
      print("Error fetching learning modules: $e");
      return [];
    }
  }

  // Delete a course from the "learning-modules" collection
  Future<void> _deleteLearningModule(String courseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('internships')
          .doc(selectedInternship)
          .collection('learning-modules')
          .doc(courseId)
          .delete();

      setState(() {}); // Refresh UI after deletion

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Course deleted successfully!"),
      ));
    } catch (e) {
      print("Error deleting course: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error deleting course."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin - Course Selection"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown to select internship
              FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchInternships(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No internships found.');
                  }

                  var internships = snapshot.data!;
                  return DropdownButton<String>(
                    value: selectedInternship.isNotEmpty
                        ? selectedInternship
                        : null,
                    hint: Text("Select Internship"),
                    onChanged: (value) {
                      setState(() {
                        selectedInternship = value!;
                        selectedCourses = []; // Clear selected courses
                      });
                    },
                    items: internships.map((internship) {
                      return DropdownMenuItem<String>(
                        value: internship.id,
                        child: Text(internship['title']),
                      );
                    }).toList(),
                  );
                },
              ),

              SizedBox(height: 20),

              // Fetch and display all courses with checkboxes
              FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchCourses(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No courses available.');
                  }

                  var courses = snapshot.data!;
                  return ListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: courses.map((course) {
                      return CheckboxListTile(
                        title: Text(course['course_name']),
                        value: selectedCourses.contains(course.id),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedCourses.add(course.id);
                            } else {
                              selectedCourses.remove(course.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              // Button to save selected courses
              ElevatedButton(
                onPressed: _saveSelectedCourses,
                child: Text("Save Selected Courses"),
              ),

              SizedBox(height: 20),

              // Display selected courses for the internship
              Text(
                "Selected Courses for ${selectedInternship.isNotEmpty ? selectedInternship : 'N/A'}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchLearningModules(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No learning modules found.');
                  }

                  var learningModules = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: learningModules.map((module) {
                      return ListTile(
                        title: Text(module['course_id'] ?? 'No Course ID'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteLearningModule(module['id']);
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}