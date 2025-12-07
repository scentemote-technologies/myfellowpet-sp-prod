import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InternshipGridPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Internships'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('internships').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No internships available.'));
          }

          final internships = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // Number of tiles per row
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 3 / 4, // Adjust tile size
              ),
              itemCount: internships.length,
              itemBuilder: (context, index) {
                final internship = internships[index];
                final data = internship.data() as Map<String, dynamic>;

                List<dynamic> imageUrls = data['image_urls'] ?? [];

                return InternshipTile(
                  title: data['title'] ?? 'No title',
                  imageUrls: imageUrls.isNotEmpty ? [imageUrls[0]] : [],
                  description: data['description'] ?? 'No description',
                  domain: data['domain'] ?? 'No domain',
                  duration: data['duration'] ?? 'No duration',
                  stipend: data['stipend'] ?? 'No stipend',
                  location: data['location'] ?? 'No location',
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class InternshipTile extends StatelessWidget {
  final String title;
  final List<dynamic> imageUrls;
  final String description;
  final String domain;
  final String duration;
  final String stipend;
  final String location;

  const InternshipTile({
    Key? key,
    required this.title,
    required this.imageUrls,
    required this.description,
    required this.domain,
    required this.duration,
    required this.stipend,
    required this.location,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display only the first image
            if (imageUrls.isNotEmpty)
              Container(
                height: 100,
                width: double.infinity, // Make image span full width
                child: Image.network(
                  imageUrls[0], // Display only the first image
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 8),
            // Title in header font
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            // Description
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            // Details as bullet points
            Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(height: 4),
            BulletPoint(text: 'Domain: $domain'),
            BulletPoint(text: 'Duration: $duration'),
            BulletPoint(text: 'Stipend: $stipend'),
            BulletPoint(text: 'Location: $location'),
          ],
        ),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('• ', style: TextStyle(fontSize: 14)),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
    );
  }
}