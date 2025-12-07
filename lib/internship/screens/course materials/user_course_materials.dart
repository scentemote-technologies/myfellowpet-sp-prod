import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../Profile/profile_services.dart';
import '../Profile/profile_widgets.dart';

// Optional: For modern fonts, you can use the Google Fonts package.
// import 'package:google_fonts/google_fonts.dart';

// Import modular services and widgets.


class UserCourseMaterials extends StatefulWidget {
  final String uid;
  UserCourseMaterials({required this.uid});

  @override
  _UserCourseMaterialsState createState() => _UserCourseMaterialsState();
}

class _UserCourseMaterialsState extends State<UserCourseMaterials> {

  String? _userID;
  // Profile Data
  File? _imageFile;
  String? _displayName;
  String? _email;
  String? _photoURL;
  String? _phoneNumber;
  String? _instituteName;
  String? _district;
  String? _state;
  String? _age;
  String? _gender;
  bool _isHovering = false;

  // Controllers for the Complete Profile dialog.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _instituteController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  // Lists for courses and internships.
  List<Map<String, dynamic>> courseDetails = [];
  String noCoursesMessage = '';
  List<String> internshipsEnrolled = [];

  // Image picker instance.
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Fetch basic user details and additional data.
    ProfileServices.fetchUserDetails(widget.uid).then((userData) {
      if (userData != null) {
        setState(() {
          _displayName = userData['displayName'];
          _email = userData['email'];
          _photoURL = userData['photoURL'];
          _userID = userData['uid'];
        });
        ProfileServices.fetchProfileInfo(_userID!).then((profileData) {
          if (profileData != null) {
            setState(() {
              _phoneNumber = profileData['phoneNumber'];
              _instituteName = profileData['instituteName'];
              _district = profileData['district'];
              _state = profileData['state'];
              _age = profileData['age'];
              _gender = profileData['gender'];
            });
          }
        });
        ProfileServices.fetchCoursesEnrolled(_userID!).then((coursesResult) {
          setState(() {
            noCoursesMessage = coursesResult['message'];
            courseDetails = coursesResult['courses'];
          });
        });
        ProfileServices.fetchInternshipsEnrolled(_userID!).then((internshipIds) {
          setState(() {
            internshipsEnrolled = internshipIds;
          });
        });
      }
    });
  }

  // Upload image method calling service.
  Future<void> _getImage() async {
    File? image = await ProfileServices.pickAndUploadImage(picker);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
      // After upload, refresh the photoURL.
      ProfileServices.getUpdatedPhotoURL(FirebaseAuth.instance.currentUser!.uid)
          .then((url) {
        setState(() {
          _photoURL = url;
        });
      });
    }
  }

  // Open complete profile dialog.
  void _openCompleteProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => ProfileWidgets.buildCompleteProfileDialog(
        context: context,
        nameController: _nameController..text = _displayName ?? "",
        emailController: _emailController..text = _email ?? "",
        phoneController: _phoneController..text = _phoneNumber ?? "",
        instituteController: _instituteController..text = _instituteName ?? "",
        districtController: _districtController..text = _district ?? "",
        stateController: _stateController..text = _state ?? "",
        ageController: _ageController..text = _age ?? "",
        genderController: _genderController..text = _gender ?? "",
        onSave: (updatedData) {
          ProfileServices.updateUserProfile(_userID!, updatedData).then((_) {
            setState(() {
              _displayName = updatedData['displayName'];
              _email = updatedData['email'];
              _phoneNumber = updatedData['phoneNumber'];
              _instituteName = updatedData['instituteName'];
              _district = updatedData['district'];
              _state = updatedData['state'];
              _age = updatedData['age'];
              _gender = updatedData['gender'];
            });
          });
        },
      ),
    );
  }

  // Build responsive content using LayoutBuilder.
  Widget _buildResponsiveContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust grid columns based on available width.
        int gridColumns = 1;
        if (constraints.maxWidth > 1200) {
          gridColumns = 3;
        } else if (constraints.maxWidth > 800) {
          gridColumns = 2;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header section with modern design enhancements.

            SizedBox(height: 20),
            // Courses grid section.
            ProfileWidgets.buildCoursesGrid(
              context,
              courseDetails,
              noCoursesMessage,
              gridColumns: gridColumns,
            ),
            SizedBox(height: 20),
            // Internships grid section.
            ProfileWidgets.buildInternshipsGrid(
              context,
              internshipsEnrolled,
              _userID,
              gridColumns: gridColumns,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Modern design: Gradient AppBar and modern typography.
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            // Uncomment the next line to use Google Fonts.
            // fontFamily: GoogleFonts.poppins().fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: responsiveValue(context, 18, 20, 22, 24),
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: _buildResponsiveContent(),
      ),
      backgroundColor: Colors.grey[200],

    );
  }
}

/// Helper function for responsive values.
double responsiveValue(BuildContext context, double mobile, double tablet, double laptop, double desktop) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 1440) return desktop;
  if (screenWidth > 1024) return laptop;
  if (screenWidth > 600) return tablet;
  return mobile;
}
