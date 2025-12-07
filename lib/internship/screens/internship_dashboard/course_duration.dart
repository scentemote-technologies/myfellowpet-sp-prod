import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseDurationPage extends StatefulWidget {
  @override
  _CourseDurationPageState createState() => _CourseDurationPageState();
}

class _CourseDurationPageState extends State<CourseDurationPage> {
  String? enrolledInternshipId;
  Map<String, dynamic>? internshipDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEnrolledInternship();
  }

  // Function to retrieve the enrolled internship ID and its details
  Future<void> _fetchEnrolledInternship() async {
    try {
      // Fetch current user's UID
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Fetch the user's document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // Ensure the document contains the field 'enrolled_internship_id'
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        enrolledInternshipId = userData['enrolled_internship_id'];

        if (enrolledInternshipId != null && enrolledInternshipId!.isNotEmpty) {
          // Fetch internship details from the internships collection
          DocumentSnapshot internshipDoc = await FirebaseFirestore.instance
              .collection('internships')
              .doc(enrolledInternshipId)
              .get();

          if (internshipDoc.exists && internshipDoc.data() != null) {
            setState(() {
              internshipDetails = internshipDoc.data() as Map<String, dynamic>;
              isLoading = false;
            });
          } else {
            setState(() {
              internshipDetails = null;
              isLoading = false;
            });
          }
        } else {
          setState(() {
            internshipDetails = null;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          internshipDetails = null;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching enrolled internship: $e");
      setState(() {
        internshipDetails = null;
        isLoading = false;
      });
    }
  }

  // Helper function to safely format Firestore fields
  String formatText(dynamic value) {
    if (value is List<dynamic>) {
      return value.join(", "); // Convert list to a comma-separated string
    }
    return value?.toString() ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Enrolled Internship")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : internshipDetails == null
          ? Center(
        child: Text(
          "You are not enrolled in any internship.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : Padding(
        padding: EdgeInsets.all(16.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              internshipDetails!['durationimage_url'] != null
                  ? Image.network(
                internshipDetails!['durationimage_url'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              )
                  : Icon(Icons.work, size: 100, color: Colors.grey),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatText(internshipDetails!['title']),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                        "Domain: ${formatText(internshipDetails!['domain'])}"),
                    Text(
                        "Location: ${formatText(internshipDetails!['location'])}"),
                    Text(
                        "Stipend: ${formatText(internshipDetails!['stipend'])}"),
                    Text(
                        "Duration: ${formatText(internshipDetails!['duration'])}"),
                    SizedBox(height: 10),
                    Text(
                      "Description:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(formatText(internshipDetails!['description_1'])),
                    SizedBox(height: 5),
                    Text(formatText(internshipDetails!['description_2'])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
