import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class InternProjectDisplayPage extends StatefulWidget {
  final String internshipId;
  final String internId;

  InternProjectDisplayPage({required this.internshipId, required this.internId});

  @override
  _InternProjectDisplayPageState createState() => _InternProjectDisplayPageState();
}

class _InternProjectDisplayPageState extends State<InternProjectDisplayPage> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController = TextEditingController();

  Uint8List? pdfBytes;
  String? pdfFileName;
  double pdfUploadProgress = 0;

  Uint8List? zipBytes;
  String? zipFileName;
  double zipUploadProgress = 0;

  bool isUploading = false;

  // Function to pick a file (PDF or ZIP)
  Future<void> pickFile(String fileType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: fileType == 'pdf' ? ['pdf'] : ['zip'],
    );

    if (result != null) {
      setState(() {
        if (fileType == 'pdf') {
          pdfBytes = result.files.first.bytes;
          pdfFileName = result.files.first.name;
        } else {
          zipBytes = result.files.first.bytes;
          zipFileName = result.files.first.name;
        }
      });
      if (fileType == 'pdf') {
        print("Picked PDF file: $pdfFileName");
      } else {
        print("Picked ZIP file: $zipFileName");
      }
    }
  }

  // Function to upload a file to Firebase Storage and return its download URL
  Future<String> uploadFile(Uint8List fileBytes, String fileName, String folder) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('$folder/$fileName');
      UploadTask uploadTask = storageRef.putData(fileBytes);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          if (folder == 'pdfs') {
            pdfUploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          } else {
            zipUploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          }
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading $folder: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading $folder: $e')));
      return '';
    }
  }

  // Function to submit project details to Firestore
  Future<void> submitProject() async {
    if (_projectNameController.text.isEmpty ||
        _projectDescriptionController.text.isEmpty ||
        pdfBytes == null ||
        zipBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields and upload files.')));
      return;
    }

    setState(() {
      isUploading = true;
    });

    String pdfUrl = await uploadFile(pdfBytes!, pdfFileName!, 'pdfs');
    String zipUrl = await uploadFile(zipBytes!, zipFileName!, 'zips');

    if (pdfUrl.isNotEmpty && zipUrl.isNotEmpty) {
      try {
        final currentUserUid = FirebaseAuth.instance.currentUser!.uid;

        final internshipRef = FirebaseFirestore.instance.collection('internships').doc(widget.internshipId);
        final userProgressRef = internshipRef.collection('userProgress');
        final userDocRef = userProgressRef.doc(currentUserUid);
        final userProjectsRef = userDocRef.collection('user-projects');

        await userProjectsRef.add({
          'internId': widget.internId,
          'projectName': _projectNameController.text,
          'projectDescription': _projectDescriptionController.text,
          'pdfUrl': pdfUrl,
          'zipUrl': zipUrl,
          'createdAt': Timestamp.now(),
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Project submitted successfully!')));

        setState(() {
          _projectNameController.clear();
          _projectDescriptionController.clear();
          pdfBytes = null;
          pdfFileName = null;
          pdfUploadProgress = 0;
          zipBytes = null;
          zipFileName = null;
          zipUploadProgress = 0;
          isUploading = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error submitting project: $e')));
        setState(() {
          isUploading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error uploading files. Please try again.')));
      setState(() {
        isUploading = false;
      });
    }
  }

  // Fetch Accepted/Rejected Projects
  Future<List<Map<String, dynamic>>> _fetchProjects(String status) async {
    List<Map<String, dynamic>> projects = [];

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('internships')
        .doc(widget.internshipId)
        .collection('userProgress')
        .doc(widget.internId)
        .collection(status)
        .where('internId', isEqualTo: widget.internId)
        .get();

    for (var doc in snapshot.docs) {
      projects.add(doc.data() as Map<String, dynamic>);
    }

    return projects;
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen width and adjust layout accordingly
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideScreen = screenWidth > 800;
    bool isSmallScreen = screenWidth < 600;

    Widget projectFormSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _projectNameController,
          decoration: InputDecoration(
            labelText: 'Project Name',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _projectDescriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Project Description',
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () => pickFile('pdf'),
                icon: Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                label: Text(pdfFileName ?? 'Upload PDF',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: ElevatedButton.icon(
                onPressed: () => pickFile('zip'),
                icon: Icon(Icons.folder_zip, color: Colors.blueAccent),
                label: Text(zipFileName ?? 'Upload ZIP',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              ),
            ),
            SizedBox(width: 10),
            Flexible(
              child: ElevatedButton(
                onPressed: isUploading ? null : submitProject,
                child: Text('Submit Project', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              ),
            ),
          ],
        ),
        if (pdfUploadProgress > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LinearProgressIndicator(value: pdfUploadProgress / 100),
          ),
        if (zipUploadProgress > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LinearProgressIndicator(value: zipUploadProgress / 100),
          ),
      ],
    );

    Widget projectsSection = isSmallScreen
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProjectsSection('Accepted Projects', 'accepted-user-projects'),
        SizedBox(height: 16),
        _buildProjectsSection('Rejected Projects', 'rejected-user-projects'),
      ],
    )
        : Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildProjectsSection('Accepted Projects', 'accepted-user-projects')),
        SizedBox(width: 16),
        Expanded(child: _buildProjectsSection('Rejected Projects', 'rejected-user-projects')),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Project',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: isWideScreen
              ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  projectFormSection,
                  SizedBox(height: 32),
                  projectsSection,
                ],
              ),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              projectFormSection,
              SizedBox(height: 32),
              projectsSection,
            ],
          ),
        ),
    );
  }

  Widget _buildProjectsSection(String title, String collectionName) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchProjects(collectionName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Text('Error fetching $title.');
        final projects = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...projects.map((project) {
              return ListTile(
                title: Text(project['projectName']),
                subtitle: Text(
                  collectionName == 'accepted-user-projects'
                      ? (project['outcome'] ?? 'No outcomes')
                      : project['rejection_reason'] ?? '',
                ),
                trailing: collectionName == 'rejected-user-projects'
                    ? IconButton(
                  icon: Icon(Icons.download),
                  onPressed: () => _launchURL(project['pdfUrl']),
                )
                    : null,
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
