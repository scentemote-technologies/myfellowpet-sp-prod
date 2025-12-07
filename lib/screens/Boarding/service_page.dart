import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePage extends StatelessWidget {
  const ServicePage({super.key});

  Future<Map<String, dynamic>> fetchServiceData() async {
    final doc = await FirebaseFirestore.instance
        .collection('company_documents')
        .doc('general_info')
        .get();
    return doc.data()!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchServiceData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data found.'));
          }

          final data = snapshot.data!;
          final String tagline = data['tagline'] ?? '';
          final String description = data['description'] ?? '';
          final String imageUrl = data['main_image'] ?? '';
          print(imageUrl);
          final List<dynamic> services = data['services'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with text and image
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Texts
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How It Started',
                            style: TextStyle(
                              color: Color(0xFF2CB4B6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tagline,
                            style: const TextStyle(
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Right side: Image
                    // Right side: Image (shallower box)
                    Expanded(
                      flex: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 290, // Adjust height to make the image shallower
                          color: Colors.grey[200],
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image, size: 40, color: Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height:10),

                // Services section
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: services.map((service) {
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets,
                              size: 36, color: Color(0xFF2CB4B6)),
                          const SizedBox(height: 8),
                          Text(
                            service.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
