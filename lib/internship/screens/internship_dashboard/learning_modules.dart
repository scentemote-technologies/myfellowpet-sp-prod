import 'package:flutter/material.dart';

class LearningModulesPage extends StatefulWidget {
  @override
  _LearningModulesPageState createState() => _LearningModulesPageState();
}

class _LearningModulesPageState extends State<LearningModulesPage> {
  // List of modules (with dummy data)
  final List<Map<String, String>> modules = [
    {
      'title': 'Module 1: Introduction to Programming',
      'desc': 'Learn the basics of programming concepts.',
      'status': 'Not Started',
      'duration': '2 hours',
      'video': 'https://www.example.com/video1',
    },
    {
      'title': 'Module 2: Object-Oriented Programming',
      'desc': 'Deep dive into OOP principles and practices.',
      'status': 'In Progress',
      'duration': '3 hours',
      'video': 'https://www.example.com/video2',
    },
    {
      'title': 'Module 3: Web Development',
      'desc': 'Learn HTML, CSS, and JavaScript for web design.',
      'status': 'Completed',
      'duration': '4 hours',
      'video': 'https://www.example.com/video3',
    },
  ];

  // Placeholder for module feedback, quiz status, and completion
  Map<String, String> moduleProgress = {
    'Module 1: Introduction to Programming': '0%',
    'Module 2: Object-Oriented Programming': '50%',
    'Module 3: Web Development': '100%',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learning Modules'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            // Fetch progress using module['title'], or fallback to '0%' if not found
            final progress = moduleProgress[module['title']] ?? '0%';

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module['title']!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      module['desc']!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Duration: ${module['duration']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Spacer(),
                        Text(
                          'Status: ${module['status']}',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress == '100%' ? 1.0 : double.parse(progress.replaceAll('%', '')) / 100,
                      backgroundColor: Colors.grey[300],
                      color: Colors.blue,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Progress: $progress',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to the video or learning material
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Learning Material'),
                            content: Text('Open video: ${module['video']}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('View Learning Material'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Optionally navigate to quizzes/assignments page
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Quiz/Assignment'),
                            content: Text('Navigate to Quiz for ${module['title']}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('Take Quiz'),
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // Provide feedback option
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Provide Feedback'),
                            content: Text('Provide feedback for ${module['title']}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text('Provide Feedback'),
                    ),
                    Divider(),
                    Text(
                      'Discussion:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Ask a question or comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
