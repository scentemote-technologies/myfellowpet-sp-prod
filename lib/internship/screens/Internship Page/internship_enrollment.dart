import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Import FilePicker package
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage package
import 'package:http/http.dart' as http;
import 'dart:convert';



class InternshipEnrollment extends StatefulWidget {
  final String courseName;
  final String uid;

  InternshipEnrollment({
    required this.courseName,
    required this.uid,
  });

  @override
  _EnrollmentFormPageState createState() => _EnrollmentFormPageState();
}

class _EnrollmentFormPageState extends State<InternshipEnrollment> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String middleName = '';
  String lastName = '';
  int age = 0;
  String gender = 'Male'; // Default gender
  String profession = 'Student'; // Default profession
  String email = '';
  String phoneNumber = '';
  String collegeName = '';
  bool isSubmitting = false;

  String state = '';
  String district = '';
  String pinCode = '';
  Uint8List? selectedImageBytes; // Store the selected image bytes
  String? courseImageUrl; // Store the image URL after upload
  Uint8List? selected12thMarkscardBytes;
  Uint8List? selected10thMarkscardBytes;
  Uint8List? selectedResumeBytes;


  double uploadProgress = 0.0;

  // Function to pick an image from the file system
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

  Future<void> pick12thMarkscard() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selected12thMarkscardBytes = result.files.first.bytes;
      });
      upload12thMarkscard();
    }
  }

  Future<void> pick10thMarkscard() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        selected10thMarkscardBytes = result.files.first.bytes;
      });
      upload10thMarkscard();
    }
  }

  Future<void> pickResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any, // Choose appropriate file type for resume
    );

    if (result != null) {
      setState(() {
        selectedResumeBytes = result.files.first.bytes;
      });
      uploadResume();
    }
  }
  Future<void> upload12thMarkscard() async {
    if (selected12thMarkscardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the 12th marks card first')),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('internship_images/12th_markscard_${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = imageRef.putData(selected12thMarkscardBytes!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      await uploadTask;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading 12th marks card: $e')),
      );
    }
  }

  Future<void> upload10thMarkscard() async {
    if (selected10thMarkscardBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the 10th marks card first')),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('internship_images/10th_markscard_${DateTime.now().millisecondsSinceEpoch}.jpg');
      UploadTask uploadTask = imageRef.putData(selected10thMarkscardBytes!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      await uploadTask;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading 10th marks card: $e')),
      );
    }
  }

  Future<void> uploadResume() async {
    if (selectedResumeBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the resume first')),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final resumeRef = storageRef.child('internship_images/resume_${DateTime.now().millisecondsSinceEpoch}.pdf');
      UploadTask uploadTask = resumeRef.putData(selectedResumeBytes!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        });
      });

      await uploadTask;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading resume: $e')),
      );
    }
  }



  // Function to upload the image to Firebase Storage
  Future<void> uploadImage() async {
    if (selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child('internship_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
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

  // Function to submit the enrollment form data
  Future<void> _submitEnrollment() async {
    if (_formKey.currentState!.validate()) {
      if (selectedImageBytes == null ||
          selected12thMarkscardBytes == null ||
          selected10thMarkscardBytes == null ||
          selectedResumeBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload all required images!')),
        );
        return; // Prevent submission if any image is missing
      }

      setState(() {
        isSubmitting = true; // Show the loading indicator
      });

      String formattedPhoneNumber = "+91$phoneNumber";
      String? idCardUrl = courseImageUrl; // Use the URL of the uploaded image
      String? twelveMarksCardUrl;
      String? tenMarksCardUrl;
      String? resumeUrl;

      try {
        // Upload images and get their URLs
        if (selected12thMarkscardBytes != null) {
          final twelveMarksCardRef = FirebaseStorage.instance
              .ref()
              .child('internship_images/12th_markscard_${DateTime.now().millisecondsSinceEpoch}.jpg');
          UploadTask twelveMarksCardUploadTask = twelveMarksCardRef.putData(selected12thMarkscardBytes!);
          await twelveMarksCardUploadTask;
          twelveMarksCardUrl = await twelveMarksCardRef.getDownloadURL();
        }

        if (selected10thMarkscardBytes != null) {
          final tenMarksCardRef = FirebaseStorage.instance
              .ref()
              .child('internship_images/10th_markscard_${DateTime.now().millisecondsSinceEpoch}.jpg');
          UploadTask tenMarksCardUploadTask = tenMarksCardRef.putData(selected10thMarkscardBytes!);
          await tenMarksCardUploadTask;
          tenMarksCardUrl = await tenMarksCardRef.getDownloadURL();
        }

        if (selectedResumeBytes != null) {
          final resumeRef = FirebaseStorage.instance
              .ref()
              .child('internship_images/resume_${DateTime.now().millisecondsSinceEpoch}.pdf');
          UploadTask resumeUploadTask = resumeRef.putData(selectedResumeBytes!);
          await resumeUploadTask;
          resumeUrl = await resumeRef.getDownloadURL();
        }

        // Save data to Firestore
        await FirebaseFirestore.instance.collection('internship-submission').add({
          'uid': widget.uid,
          'courseName': widget.courseName,
          'firstName': firstName,
          'middleName': middleName,
          'lastName': lastName,
          'age': age,
          'gender': gender,
          'profession': profession,
          'seen' : false,
          'applied' : false,
          'email': email,
          'phoneNumber': formattedPhoneNumber,
          'collegeName': collegeName,
          'state': state,
          'district': district,
          'pinCode': pinCode,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'idCardImage': idCardUrl,
          '12thMarkscard': twelveMarksCardUrl,
          '10thMarkscard': tenMarksCardUrl,
          'resume': resumeUrl,
        });

        // Send WhatsApp Message

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment successful!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting enrollment: $e')),
        );
      } finally {
        setState(() {
          isSubmitting = false; // Hide the loading indicator
        });
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white, // White text color
          ),
        ),
        backgroundColor: Colors.black, // Black background color
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // White back arrow icon
          onPressed: () {
            Navigator.pop(context); // Go back to the previous screen
          },
        ),

      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'First Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    firstName = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Middle Name'),
                  onChanged: (value) {
                    middleName = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Last Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    lastName = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    age = int.tryParse(value) ?? 0;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: InputDecoration(labelText: 'Gender'),
                  items: ['Male', 'Female', 'Other']
                      .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      gender = value!;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  value: profession,
                  decoration: InputDecoration(labelText: 'Profession'),
                  items: ['Student', 'Working Professional', 'Other']
                      .map((profession) => DropdownMenuItem(
                    value: profession,
                    child: Text(profession),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      profession = value!;
                    });
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    email = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your phone number without +91', // Adding hint text
                    helperText: 'Please do not add +91', // Adding helper text as an instruction
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    phoneNumber = value;
                  },
                ),

                TextFormField(
                  decoration: InputDecoration(labelText: 'College Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your college name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    collegeName = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'State'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your state';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    state = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'District'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your district';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    district = value;
                  },
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Pin Code'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length != 6) {
                      return 'Please enter a valid pin code';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    pinCode = value;
                  },
                ),
                // Image upload section
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: pickImage,
                  child: Text('Pick ID Card Image'),
                ),
                if (selectedImageBytes != null)
                  Text('Image selected. Progress: ${uploadProgress.toStringAsFixed(0)}%'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: pick12thMarkscard,
                  child: Text('Pick 12th Markscard'),
                ),
                SizedBox(height: 8),
                if (selected12thMarkscardBytes != null)
                  Text('12th Markscard selected. Progress: ${uploadProgress.toStringAsFixed(0)}%'),

                SizedBox(height: 16),

                ElevatedButton(
                  onPressed: pick10thMarkscard,
                  child: Text('Pick 10th Markscard'),
                ),
                SizedBox(height: 8),
                if (selected10thMarkscardBytes != null)
                  Text('10th Markscard selected. Progress: ${uploadProgress.toStringAsFixed(0)}%'),

                SizedBox(height: 16),

                ElevatedButton(
                  onPressed: pickResume,
                  child: Text('Pick Resume'),
                ),
                SizedBox(height: 8),
                if (selectedResumeBytes != null)
                  Text('Resume selected. Progress: ${uploadProgress.toStringAsFixed(0)}%'),

                if (isSubmitting)
                  Center(child: CircularProgressIndicator()),
                if (!isSubmitting)
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _submitEnrollment,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black, // White text color
                    ),
                    child: Text('Submit'),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
