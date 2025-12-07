import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileServices {
  /// Fetches basic user details from FirebaseAuth.
  static Future<Map<String, dynamic>?> fetchUserDetails(String uid) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return {
        'displayName': user.displayName ?? "No Name",
        'email': user.email,
        'photoURL': user.photoURL,
        'uid': user.uid,
      };
    }
    return null;
  }

  /// Fetches extended profile information from Firestore.
  static Future<Map<String, dynamic>?> fetchProfileInfo(String uid) async {
    final userDocRef = FirebaseFirestore.instance.collection('web-users').doc(uid);
    final docSnapshot = await userDocRef.get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }

  /// Fetches courses the user is enrolled in.
  static Future<Map<String, dynamic>> fetchCoursesEnrolled(String uid) async {
    String message = '';
    List<Map<String, dynamic>> courses = [];
    try {
      final userDocRef = FirebaseFirestore.instance.collection('web-users').doc(uid);
      final docSnapshot = await userDocRef.get();
      if (docSnapshot.exists) {
        final userCoursesCollection = userDocRef.collection('user courses');
        final userCoursesSnapshot = await userCoursesCollection.get();
        if (userCoursesSnapshot.docs.isEmpty) {
          message = 'You are not enrolled in any courses.';
        } else {
          for (var doc in userCoursesSnapshot.docs) {
            final courseId = doc.id;
            final courseDocRef = FirebaseFirestore.instance.collection('courses').doc(courseId);
            final courseSnapshot = await courseDocRef.get();
            if (courseSnapshot.exists) {
              final courseData = courseSnapshot.data();
              courses.add({
                'name': courseData?['course_name'] ?? 'No Name',
                'description': courseData?['description'] ?? 'No Description',
                'image': courseData?['image_url'] ?? '',
              });
            }
          }
        }
      } else {
        message = 'User not found.';
      }
    } catch (e) {
      message = 'Error fetching courses. Please try again.';
      print("Error fetching enrolled courses: $e");
    }
    return {'message': message, 'courses': courses};
  }

  /// Fetches internships the user is enrolled in (returns a list of internship IDs).
  static Future<List<String>> fetchInternshipsEnrolled(String uid) async {
    List<String> internships = [];
    try {
      final userDocRef = FirebaseFirestore.instance.collection('web-users').doc(uid);
      final docSnapshot = await userDocRef.get();
      if (docSnapshot.exists) {
        internships = List<String>.from(docSnapshot['internshipEnrolled'] ?? []);
      }
    } catch (e) {
      print("Error fetching internships: $e");
    }
    return internships;
  }

  /// Picks an image from the gallery and uploads it to Firebase Storage.
  static Future<File?> pickAndUploadImage(ImagePicker picker) async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures/${FirebaseAuth.instance.currentUser!.uid}');
      await storageRef.putFile(imageFile);
      return imageFile;
    }
    return null;
  }

  /// Retrieves the updated photo URL after an image upload.
  static Future<String> getUpdatedPhotoURL(String uid) async {
    final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/$uid');
    return await storageRef.getDownloadURL();
  }

  /// Updates the user profile in FirebaseAuth and Firestore.
  static Future<void> updateUserProfile(String uid, Map<String, String> updatedData) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(updatedData['displayName']);
        await user.updateEmail(updatedData['email']!);
        await FirebaseFirestore.instance.collection('web-users').doc(uid).update({
          'displayName': updatedData['displayName'],
          'email': updatedData['email'],
          'phoneNumber': updatedData['phoneNumber'],
          'instituteName': updatedData['instituteName'],
          'district': updatedData['district'],
          'state': updatedData['state'],
          'age': updatedData['age'],
          'gender': updatedData['gender'],
        });
      }
    } catch (e) {
      print("Error updating profile: $e");
      throw e;
    }
  }
}
