import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatefulWidget {
  @override
  _TermsAndConditionsPageState createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  // Create a variable to hold the fetched data
  late Map<String, dynamic> termsData;

  // This function fetches the data from Firestore
  Future<void> _fetchTermsData() async {
    try {
      // Fetch document from Firestore
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('terms_and_conditions')
          .get();

      if (docSnapshot.exists) {
        setState(() {
          termsData = docSnapshot.data() as Map<String, dynamic>;
        });
      } else {
        // Handle case if document doesn't exist
        setState(() {
          termsData = {};
        });
      }
    } catch (e) {
      print("Error fetching terms: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    // Fetch data when the widget is initialized
    _fetchTermsData();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator if data is not yet fetched
    if (termsData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Terms & Conditions',
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                termsData['title'] ?? 'No Title Available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Text(
                termsData['intro_text'] ?? 'No Intro Text Available',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
              SizedBox(height: 20),

              // Fetch and display each section dynamically
              if (termsData['sections'] != null)
                ...termsData['sections'].map<Widget>((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(section['title'] ?? 'No Title'),
                      _buildSectionContent(
                        (section['content'] as List<dynamic>)
                            .map((content) => content['point'])
                            .join('\n'), // Combine the points
                      ),
                      SizedBox(height: 20),
                    ],
                  );
                }).toList(),

            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create section title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  // Helper method to create section content
  Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Colors.black87,
      ),
    );
  }


}
