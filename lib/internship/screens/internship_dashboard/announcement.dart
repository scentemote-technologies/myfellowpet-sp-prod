import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementPage extends StatefulWidget {
  @override
  _AnnouncementPageState createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  // Fetch announcements from Firestore
  Stream<QuerySnapshot> getAnnouncementsStream() {
    return FirebaseFirestore.instance.collection('announcements').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen width to adjust layout and styling.
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideScreen = screenWidth > 800;
    double horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Latest Announcements',
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
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() {}); // Refresh the page
              },
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: SingleChildScrollView(
            child: isWideScreen
                ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 800),
                child: _buildContent(),
              ),
            )
                : _buildContent(),
          ),
        ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Section with introductory text
        Container(
          margin: EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to the Announcements page!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Find all the latest updates here.\nStay informed and never miss out on important news.\nCheck out the most recent announcements below.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        // Announcements list
        Container(
          height: 500, // A fixed height to allow ListView builder to work inside Column.
          child: StreamBuilder<QuerySnapshot>(
            stream: getAnnouncementsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                    child: Text(
                      'Error loading announcements',
                      style: TextStyle(color: Colors.white),
                    ));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return Center(
                    child: Text(
                      'No announcements found',
                      style: TextStyle(color: Colors.white),
                    ));

              var announcements = snapshot.data!.docs;

              return ListView.builder(
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  var announcement = announcements[index];
                  return InkWell(
                    onTap: () {
                      // Navigate to announcement detail page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnnouncementDetailPage(
                            title: announcement['announcement_name'] ?? '',
                            details: announcement['description'] ?? '',
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 10,
                      margin: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Announcement Index
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF202B62),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            // Announcement Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    announcement['announcement_name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Short Description (truncated)
                                  Text(
                                    (announcement['description'] as String).length > 100
                                        ? '${announcement['description'].substring(0, 100)}...'
                                        : announcement['description'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Arrow Icon
                            Icon(Icons.arrow_forward_ios, color: Color(0xFF202B62)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AnnouncementDetailPage extends StatelessWidget {
  final String title;
  final String details;

  AnnouncementDetailPage({required this.title, required this.details});

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Announcement Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF202B62),
      ),
      body: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Text(
                details,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 20),
              Divider(color: Colors.black, thickness: 2),
              SizedBox(height: 20),
              Text(
                'Stay updated with the latest news!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
