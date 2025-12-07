import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadVideoScreen extends StatefulWidget {
  @override
  _UploadVideoScreenState createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  Uint8List? selectedVideoBytes;
  String? selectedVideoName;
  double uploadProgress = 0.0;

  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      setState(() {
        selectedVideoBytes = result.files.first.bytes;
        selectedVideoName = result.files.first.name;
      });
    } else {
      // User canceled the picker
      setState(() {
        selectedVideoBytes = null;
        selectedVideoName = null;
      });
    }
  }

  Future<void> uploadVideo() async {
    if (selectedVideoBytes == null || selectedVideoName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    setState(() {
      uploadProgress = 0.0;
    });

    try {
      // Firebase Storage upload
      final storageRef = FirebaseStorage.instance.ref();
      final videoRef = storageRef.child('videos/$selectedVideoName');
      UploadTask uploadTask = videoRef.putData(selectedVideoBytes!);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata in Firestore
      await FirebaseFirestore.instance.collection('videos').add({
        'url': downloadUrl,
        'name': selectedVideoName,
        'uploaded_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video uploaded successfully!')),
      );

      setState(() {
        selectedVideoBytes = null;
        selectedVideoName = null;
        uploadProgress = 0.0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Video'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selectedVideoName != null)
              Column(
                children: [
                  Text(
                    'Selected Video: $selectedVideoName',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: uploadProgress / 100,
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: uploadProgress > 0.0 && uploadProgress < 100.0
                        ? null
                        : uploadVideo,
                    child: Text('Upload Video'),
                  ),
                ],
              ),
            if (selectedVideoName == null)
              ElevatedButton(
                onPressed: pickVideo,
                child: Text('Select Video'),
              ),
          ],
        ),
      ),
    );
  }
}