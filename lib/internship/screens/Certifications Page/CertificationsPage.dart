import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../course grid view/course_grid_view.dart';
import '../dashboard.dart';
class CertificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Certifications")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Certifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: CourseGridView(searchQuery: '',)),
        ],
      ),
    );
  }
}