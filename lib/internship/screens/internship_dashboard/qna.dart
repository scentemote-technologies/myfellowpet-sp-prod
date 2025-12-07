import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QnaPage extends StatefulWidget {
  @override
  _QnaPageState createState() => _QnaPageState();
}

class _QnaPageState extends State<QnaPage> {
  TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Function to submit a question to Firestore
  Future<void> _submitQuestion() async {
    if (_questionController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      // Get the current user
      User? user = _auth.currentUser;
      String uid = user != null ? user.uid : 'Anonymous';

      try {
        // Save question to Firestore in 'qna' collection
        await FirebaseFirestore.instance.collection('qna').add({
          'question': _questionController.text,
          'uid': uid,
          'timestamp': FieldValue.serverTimestamp(),
          'answer': 'Kindly wait for the admin to respond.', // Set answer to "TBD"
          'answeredTimestamp': FieldValue.serverTimestamp(), // Set answeredTimestamp to current timestamp
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question submitted successfully!')),
        );
      } catch (e) {
        // Show error message if submission fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting question: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
        _questionController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    String uid = user != null ? user.uid : 'Anonymous';

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Q&A Section',
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
          child: Column(
            children: [
              // Question Submission Section
              TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: "Ask a Question",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitQuestion,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Submit Question"),
              ),
              SizedBox(height: 16),

              // Display submitted questions with answers
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('qna')
                      .where('uid', isEqualTo: uid) // Filter by logged-in user's questions
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No questions found.'));
                    }

                    var qnaList = snapshot.data!.docs;

                    // Filter out questions older than 5 days if answered
                    var filteredQnaList = qnaList.where((qna) {
                      var answeredTimestamp = qna['answeredTimestamp'];
                      if (answeredTimestamp != null) {
                        DateTime answeredDate =
                        (answeredTimestamp as Timestamp).toDate();
                        return DateTime.now().difference(answeredDate).inDays <= 5;
                      }
                      return true; // Include questions that are not yet answered
                    }).toList();

                    if (filteredQnaList.isEmpty) {
                      return Center(child: Text('No questions found.'));
                    }

                    return ListView.builder(
                      itemCount: filteredQnaList.length,
                      itemBuilder: (context, index) {
                        var qna = filteredQnaList[index];
                        var question = qna['question'];
                        var answer = qna['answer'] ?? 'Awaiting response...';
                        var answeredTimestamp = qna['answeredTimestamp'];

                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              question,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Answer: $answer'),
                                if (answeredTimestamp != null)
                                  Text(
                                    'Answered on: ${(answeredTimestamp as Timestamp).toDate()}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

    );
  }
}