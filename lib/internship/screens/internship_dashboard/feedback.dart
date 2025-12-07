import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  double _rating = 0.0;
  TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Firebase Authentication instance to get user UID
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Simulated submission of feedback to Firestore
  Future<void> _submitFeedback() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      // Get the current user
      User? user = _auth.currentUser;
      String uid = user != null ? user.uid : 'Anonymous';

      // Get the feedback data
      double rating = _rating;
      String comments = _commentsController.text;

      try {
        // Add feedback to Firestore collection
        await FirebaseFirestore.instance.collection('feedback').add({
          'rating': rating,
          'uid': uid,
          'additional_comments': comments,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feedback submitted successfully!')),
        );
      } catch (e) {
        // Show error message if submission fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting feedback: $e')),
        );
      } finally {
        // Reset form state
        setState(() {
          _isSubmitting = false;
        });

        // Optionally, clear the form
        _commentsController.clear();
        setState(() {
          _rating = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Provide Feedback',
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
                  // Header Section
                  Text(
                    'Your feedback is important to us. Please rate and provide comments about your experience.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  SizedBox(height: 16),

                  // Rating System
                  Text('Rate the Program:', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.yellow,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 16),

                  // Feedback Form
                  TextFormField(
                    controller: _commentsController,
                    decoration: InputDecoration(
                      labelText: 'Additional Comments',
                      hintText: 'Please share any feedback or suggestions...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please provide some feedback.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Submit Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Submit Feedback', style: TextStyle(color: Colors.white)),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Thank You Note after Submission
                  if (_isSubmitting)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Thank you for your feedback!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
