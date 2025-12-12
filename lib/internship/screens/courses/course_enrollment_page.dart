import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EnrollmentFormPage extends StatefulWidget {
  final String courseName;
  final String uid;

  EnrollmentFormPage({
    required this.courseName,
    required this.uid,
  });

  @override
  _EnrollmentFormPageState createState() => _EnrollmentFormPageState();
}

class _EnrollmentFormPageState extends State<EnrollmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String middleName = '';
  String lastName = '';
  int age = 0;
  String gender = 'Male'; // Default gender is Male
  String profession = 'Student'; // Default profession
  String email = '';
  String phoneNumber = '';
  String collegeName = '';
  String state = '';
  String district = '';
  String pinCode = '';

  bool isLoading = false; // Track the loading state



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Course Enrollment Form',
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
                // First Name field
                TextFormField(
                  decoration: InputDecoration(labelText: 'First Name'),
                  onChanged: (value) => setState(() {
                    firstName = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your first name';
                    }
                    return null;
                  },
                ),
                // Middle Name field (optional)
                TextFormField(
                  decoration: InputDecoration(labelText: 'Middle Name (optional)'),
                  onChanged: (value) => setState(() {
                    middleName = value;
                  }),
                ),
                // Last Name field
                TextFormField(
                  decoration: InputDecoration(labelText: 'Last Name'),
                  onChanged: (value) => setState(() {
                    lastName = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your last name';
                    }
                    return null;
                  },
                ),
                Text(
                  'This name will be printed on your certificate.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                // Age field
                TextFormField(
                  decoration: InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    age = int.tryParse(value) ?? 0;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    return null;
                  },
                ),
                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: gender,
                  items: ['Male', 'Female', 'Other']
                      .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      gender = value ?? 'Male';
                    });
                  },
                  decoration: InputDecoration(labelText: 'Gender'),
                ),
                // Profession Dropdown
                DropdownButtonFormField<String>(
                  value: profession,
                  items: ['Student', 'Teacher', 'Other']
                      .map((profession) => DropdownMenuItem(
                    value: profession,
                    child: Text(profession),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      profession = value ?? 'Student';
                    });
                  },
                  decoration: InputDecoration(labelText: 'Profession'),
                ),
                // Email field
                TextFormField(
                  decoration: InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) => setState(() {
                    email = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                // Phone number field
                TextFormField(
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) => setState(() {
                    phoneNumber = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                // College Name field
                TextFormField(
                  decoration: InputDecoration(labelText: 'College Name'),
                  onChanged: (value) => setState(() {
                    collegeName = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your college name';
                    }
                    return null;
                  },
                ),
                // State field
                TextFormField(
                  decoration: InputDecoration(labelText: 'State'),
                  onChanged: (value) => setState(() {
                    state = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your state';
                    }
                    return null;
                  },
                ),
                // District field
                TextFormField(
                  decoration: InputDecoration(labelText: 'District'),
                  onChanged: (value) => setState(() {
                    district = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your district';
                    }
                    return null;
                  },
                ),
                // Pin Code field
                TextFormField(
                  decoration: InputDecoration(labelText: 'Pin Code'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {
                    pinCode = value;
                  }),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your pin code';
                    }
                    return null;
                  },
                ),
                // Submit Button
                SizedBox(height: 20),
                isLoading
                    ? Center(child: CircularProgressIndicator()) // Show progress indicator while loading
                    : ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        isLoading = true; // Start loading
                      });

                      // Format the phone number to include country code (+91 for India)
                      String formattedPhoneNumber = "+91$phoneNumber";

                      // Save data to Firestore
                      await FirebaseFirestore.instance.collection('internship-requests').add({
                        'uid': widget.uid,
                        'courseName': widget.courseName,
                        'firstName': firstName,
                        'middleName': middleName,
                        'lastName': lastName,
                        'age': age,
                        'gender': gender,
                        'profession': profession,
                        'email': email,
                        'phoneNumber': formattedPhoneNumber,
                        'collegeName': collegeName,
                        'state': state,
                        'district': district,
                        'pinCode': pinCode,
                        'timestamp': FieldValue.serverTimestamp(),
                        'status': 'pending',  // Default status is 'pending'
                      });

                      // Send WhatsApp message to user via Twilio

                      setState(() {
                        isLoading = false; // Stop loading
                      });

                      // Show confirmation message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Enrollment submitted successfully!')),
                      );

                      // Navigate back to the course page
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Submit', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
