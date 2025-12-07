import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescriptionController = TextEditingController();
  final TextEditingController _projectCostController = TextEditingController();
  bool _addReadme = false;
  String _zipFileName = '';
  String _readmeFileName = '';
  List<String> _imageFileNames = [];
  List<Uint8List?> _selectedImageBytes = [];
  List<String> _imageUrls = [];
  String? _zipFileUrl;
  String? _readmeFileUrl;

  Future<void> _pickZipFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result != null) {
      setState(() {
        _zipFileName = result.files.single.name;
      });
      await _uploadFile(result.files.single.bytes!, 'projects/zipfiles/$_zipFileName', 'zip');
    }
  }

  Future<void> _pickReadmeFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (result != null) {
      setState(() {
        _readmeFileName = result.files.single.name;
      });
      await _uploadFile(result.files.single.bytes!, 'projects/readmefiles/$_readmeFileName', 'readme');
    }
  }

  Future<void> _pickImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() {
        _imageFileNames = result.files.map((e) => e.name).toList();
        _selectedImageBytes = result.files.map((e) => e.bytes).toList();
      });
    }
  }

  Future<void> _uploadFile(Uint8List fileData, String path, String fileType) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final fileRef = storageRef.child(path);
      UploadTask uploadTask = fileRef.putData(fileData);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      if (fileType == 'zip') {
        setState(() {
          _zipFileUrl = downloadUrl;
        });
      } else if (fileType == 'readme') {
        setState(() {
          _readmeFileUrl = downloadUrl;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading $fileType file: $e')));
    }
  }

  Future<void> uploadImages() async {
    List<String> imageUrls = [];

    for (int i = 0; i < _selectedImageBytes.length; i++) {
      if (_selectedImageBytes[i] != null) {
        try {
          final storageRef = FirebaseStorage.instance.ref();
          final imageRef = storageRef.child('projects/images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
          UploadTask uploadTask = imageRef.putData(_selectedImageBytes[i]!);

          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          imageUrls.add(downloadUrl);

        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
          return;
        }
      }
    }

    setState(() {
      _imageUrls = imageUrls;
    });
  }

  Future<void> addProjectToFirestore() async {
    String projectName = _projectNameController.text;
    String projectDescription = _projectDescriptionController.text;
    String projectCost = _projectCostController.text;

    await uploadImages();

    try {
      await FirebaseFirestore.instance.collection('projects').add({
        'projectName': projectName,
        'projectDescription': projectDescription,
        'projectCost': projectCost,
        'zipFileUrl': _zipFileUrl,
        'readmeFileUrl': _readmeFileUrl,
        'imageUrls': _imageUrls,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project Added Successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding project: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Project"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _projectNameController,
                    decoration: InputDecoration(
                      labelText: 'Project Name',
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _projectDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Project Description',
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: _projectCostController,
                    decoration: InputDecoration(
                      labelText: 'Project Cost',
                      hintText: 'Enter the cost of the project',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _pickZipFile,
                    child: Text("Pick Zip File"),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _zipFileName.isEmpty ? "No file chosen" : "Zip File: $_zipFileName",
                    style: TextStyle(color: _zipFileName.isEmpty ? Colors.red : Colors.green),
                  ),
                  SizedBox(height: 20),
                  CheckboxListTile(
                    title: Text("Include Readme File"),
                    value: _addReadme,
                    onChanged: (bool? value) {
                      setState(() {
                        _addReadme = value!;
                      });
                    },
                  ),
                  if (_addReadme) ...[
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _pickReadmeFile,
                      child: Text("Pick README File"),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _readmeFileName.isEmpty ? "No README file chosen" : "README File: $_readmeFileName",
                      style: TextStyle(color: _readmeFileName.isEmpty ? Colors.red : Colors.green),
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _pickImages,
                    child: Text("Pick Project Images (Up to 5)"),
                  ),
                  SizedBox(height: 20),
                  if (_imageFileNames.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(_imageFileNames.length, (index) {
                            return Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.memory(
                                _selectedImageBytes[index]!,
                                fit: BoxFit.cover,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: addProjectToFirestore,
                    child: Text("Upload Project"),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text("Instructions will go here."),
              ),
            ),
          ],
        ),
      ),
    );
  }
}