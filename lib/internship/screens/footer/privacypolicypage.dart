import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore dependency

class PrivacyPolicyPage extends StatefulWidget {
  @override
  _PrivacyPolicyPageState createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  // Variables to hold the content fetched from Firestore
  String introduction = '';
  String informationWeCollect = '';
  String howWeUseYourInformation = '';
  String cookiesAndTrackingTechnologies = '';
  String confidentialityAndSecurity = '';
  String sharingAndDisclosure = '';
  String dataRetention = '';
  String yourRights = '';
  String childrenPrivacy = '';
  String changesToPrivacyPolicy = '';
  String contactInformation = '';

  @override
  void initState() {
    super.initState();
    // Fetch data from Firestore
    _fetchPrivacyPolicyData();
  }

  // Fetch the privacy policy data from Firestore
  Future<void> _fetchPrivacyPolicyData() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('Privacy Policy')
          .get();

      if (docSnapshot.exists) {
        print('Privacy Policy Document found, setting state...');

        setState(() {
          introduction = _getStringField(docSnapshot, 'introduction');
          informationWeCollect = _getStringField(docSnapshot, 'information_we_collect');
          howWeUseYourInformation = _getStringField(docSnapshot, 'how_we_use_your_information');
          cookiesAndTrackingTechnologies = _getStringField(docSnapshot, 'cookies_and_tracking_technologies');
          confidentialityAndSecurity = _getStringField(docSnapshot, 'confidentiality_and_security');
          sharingAndDisclosure = _getStringField(docSnapshot, 'sharing_and_disclosure_of_information');
          dataRetention = _getStringField(docSnapshot, 'data_retention');
          yourRights = _getStringField(docSnapshot, 'your_rights');
          childrenPrivacy = _getStringField(docSnapshot, 'children_privacy');
          changesToPrivacyPolicy = _getStringField(docSnapshot, 'changes_to_privacy_policy');
          // Handle the nested map for contact_information
          contactInformation = _getContactInformation(docSnapshot['contact_information']);
        });
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error fetching Privacy Policy data: $e');
    }
  }

  // Helper function to safely extract a string from the document
  String _getStringField(DocumentSnapshot docSnapshot, String field) {
    var fieldValue = docSnapshot[field];
    if (fieldValue is String) {
      return fieldValue;
    } else if (fieldValue is Map || fieldValue is List) {
      // Convert complex objects into a string if needed
      return fieldValue.toString();
    } else {
      return 'No data available';
    }
  }

  // Helper function to extract contact information from a nested map
  String _getContactInformation(dynamic contactInfo) {
    if (contactInfo is Map) {
      String email = contactInfo['email'] ?? 'No email available';
      String phone = contactInfo['phone'] ?? 'No phone available';
      return 'Email: $email\nPhone: $phone';
    } else {
      return 'No contact information available';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
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
      // SingleChildScrollView + Column to ensure vertical scrolling on all devices
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main heading
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            Text(
              introduction,
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
            SizedBox(height: 16),

            // Sections
            _buildSection('1. Information We Collect', informationWeCollect),
            _buildSection('2. How We Use Your Information', howWeUseYourInformation),
            _buildSection('3. Cookies and Tracking Technologies', cookiesAndTrackingTechnologies),
            _buildSection('4. Confidentiality and Security', confidentialityAndSecurity),
            _buildSection('5. Sharing and Disclosure of Information', sharingAndDisclosure),
            _buildSection('6. Data Retention', dataRetention),
            _buildSection('7. Your Rights', yourRights),
            _buildSection('8. Children’s Privacy', childrenPrivacy),
            _buildSection('10. Changes to This Privacy Policy', changesToPrivacyPolicy),
            _buildSection('Contact Us', contactInformation, isContactUs: true),
          ],
        ),
      ),
    );
  }

  // Helper method to build each section
  Widget _buildSection(String title, String content, {bool isContactUs = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isContactUs ? Colors.black : Colors.black,
            ),
          ),
          SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
