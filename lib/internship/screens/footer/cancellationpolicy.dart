import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CancellationPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Refund and Cancellation Policy',
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
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('company_documents')
              .doc('cancellation_policy')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error loading data'));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('No data available'));
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;

            // Extracting the fields from Firestore document
            var title = data['title'] ??
                'Refund and Cancellation Policy for Scentmonte';
            var introText = data['intro_text'] ?? 'Intro text not available';
            var sections = data['sections'] as List<dynamic>? ?? [];
            var contactEmail = data['contact_email'] ?? 'Email not available';

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    introText,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 20),
                  // Handle sections dynamically
                  for (var section in sections)
                    if (section['title'] != null && section['content'] != null)
                      _buildSection(
                        section['title'],
                        section['content'],
                      ),

                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Build each section with title and content
  Widget _buildSection(String title, List<dynamic> content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          SizedBox(height: 8),
          for (var item in content)
            if (item['point'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  item['point'],
                  style: TextStyle(fontSize: 14),
                ),
              ),
        ],
      ),
    );
  }
}

