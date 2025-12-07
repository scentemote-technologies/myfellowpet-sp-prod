import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController = TextEditingController();

  Uint8List? pdfBytes;
  String? pdfFileName;
  double pdfUploadProgress = 0;

  Uint8List? zipBytes;
  String? zipFileName;
  double zipUploadProgress = 0;

  bool isUploading = false;

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
    }
  }

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
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading $folder: $e')));
      return '';
    }
  }

  Future<void> submitProject() async {
    if (_projectNameController.text.isEmpty ||
        _projectDescriptionController.text.isEmpty ||
        pdfBytes == null ||
        zipBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields and upload files.')));
      return;
    }

    setState(() {
      isUploading = true;
    });

    String pdfUrl = await uploadFile(pdfBytes!, pdfFileName!, 'pdfs');
    String zipUrl = await uploadFile(zipBytes!, zipFileName!, 'zips');

    if (pdfUrl.isNotEmpty && zipUrl.isNotEmpty) {
      await FirebaseFirestore.instance.collection('projects').add({
        'projectName': _projectNameController.text,
        'projectDescription': _projectDescriptionController.text,
        'pdfUrl': pdfUrl,
        'zipUrl': zipUrl,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project submitted successfully!')));

      // Clear form
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading files. Please try again.')));
      setState(() {
        isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Project'),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _projectNameController,
              decoration: InputDecoration(labelText: 'Project Name'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _projectDescriptionController,
              maxLines: 5,
              decoration: InputDecoration(labelText: 'Project Description'),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => pickFile('pdf'),
              icon: Icon(Icons.picture_as_pdf),
              label: Text(pdfFileName ?? 'Upload PDF'),
            ),
            if (pdfUploadProgress > 0)
              LinearProgressIndicator(value: pdfUploadProgress / 100),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => pickFile('zip'),
              icon: Icon(Icons.folder_zip),
              label: Text(zipFileName ?? 'Upload ZIP'),
            ),
            if (zipUploadProgress > 0)
              LinearProgressIndicator(value: zipUploadProgress / 100),
            SizedBox(height: 32),
            isUploading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: submitProject,
              child: Text('Submit Project'),
            ),
          ],
        ),
      ),
    );
  }
}
