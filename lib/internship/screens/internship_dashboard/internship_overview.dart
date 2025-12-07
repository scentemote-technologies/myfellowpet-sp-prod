import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';

class InternshipDetailsPage extends StatelessWidget {
  final String internshipId;

  InternshipDetailsPage({required this.internshipId});

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to determine screen width for responsiveness
    double screenWidth = MediaQuery.of(context).size.width;
    bool isSmallScreen = screenWidth < 600;

    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Internship Details',
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: isSmallScreen
            // On small screens stack the left and right containers vertically.
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeftContainer(context),
                SizedBox(height: 16),
                _buildRightContainerSection(),
              ],
            )
            // On larger screens, arrange the containers in a row.
                : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left container (3/4)
                Expanded(
                  flex: 3,
                  child: _buildLeftContainer(context),
                ),
                SizedBox(width: 16),
                // Right container (1/4)
                Expanded(
                  flex: 2,
                  child: _buildRightContainerSection(),
                ),
              ],
            ),
          ),
        ),

    );
  }

  Widget _buildLeftContainer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Card
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('internships')
              .doc(internshipId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData || !snapshot.data!.exists)
              return Center(child: Text('Internship not found.'));
            var internship =
            snapshot.data!.data() as Map<String, dynamic>;
            return _buildTitleCard(internship);
          },
        ),
        SizedBox(height: 10),
        // Project Details
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('internships')
              .doc(internshipId)
              .collection('project')
              .get(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState ==
                ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            if (projectSnapshot.hasError)
              return Center(
                  child: Text(
                      'Error fetching project details: ${projectSnapshot.error}'));
            if (!projectSnapshot.hasData ||
                projectSnapshot.data!.docs.isEmpty)
              return Center(child: Text('No project details available.'));
            var project = projectSnapshot.data!.docs[0].data()
            as Map<String, dynamic>;
            return _buildProjectDetails(project);
          },
        ),
      ],
    );
  }

  Widget _buildRightContainerSection() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Right container: Domain, Compensation, Stipend, Work Model, Benefits
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('internships')
                  .doc(internshipId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return Center(child: Text('Internship not found.'));
                var internship =
                snapshot.data!.data() as Map<String, dynamic>;
                return _buildRightContainer(
                  title1: 'Domain',
                  value1: internship['domain'],
                  title2: 'Compensation',
                  value2: internship['compensation_type'],
                  title3: 'Stipend',
                  value3: internship['stipend'],
                  secondRowTitle1: 'Work Model',
                  secondRowTitle2: 'Benefits',
                  secondRowValue1: internship['work_model'],
                  secondRowValue2: internship['benefits'],
                );
              },
            ),
            SizedBox(height: 10),
            // Right container: Qualifications, Skills Required
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('internships')
                  .doc(internshipId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return Center(child: Text('Internship not found.'));
                var internship =
                snapshot.data!.data() as Map<String, dynamic>;
                return _buildRightContainer(
                  title1: 'Qualifications',
                  value1: internship['qualifications'],
                  title2: 'Skills Required',
                  value2: internship['skills_required'],
                );
              },
            ),
            SizedBox(height: 10),
            // Right container: Supervisor, Supervisor Contact
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('internships')
                  .doc(internshipId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return Center(child: Text('Internship not found.'));
                var internship =
                snapshot.data!.data() as Map<String, dynamic>;
                return _buildRightContainer(
                  title1: 'Supervisor',
                  value1: internship['supervisor_name'],
                  title2: 'Supervisor Contact',
                  value2: internship['supervisor_contact'],
                );
              },
            ),
            SizedBox(height: 10),
            // Right container: Health & Safety
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('internships')
                  .doc(internshipId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData || !snapshot.data!.exists)
                  return Center(child: Text('Internship not found.'));
                var internship =
                snapshot.data!.data() as Map<String, dynamic>;
                return _buildRightContainer(
                  title1: 'Health & Safety',
                  value1: internship['health_and_safety'],
                  title2: '',
                  value2: '',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleCard(Map<String, dynamic> internship) {
    return Card(
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              internship['title'] ?? 'No Title Available',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey),
                SizedBox(width: 5),
                Text(
                  internship['duration'] ?? 'No Duration Info',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey),
                SizedBox(width: 5),
                Text(
                  internship['location'] ?? 'No Location Info',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 15),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                internship['description_1'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                internship['description_2'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 15),
            _buildImageSection(internship),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(Map<String, dynamic> internship) {
    List<dynamic> imageUrls = internship['image_url'] ?? [];
    if (imageUrls.isEmpty) return SizedBox();

    return Card(
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CarouselSlider(
          options: CarouselOptions(
            height: 125.0,
            enlargeCenterPage: false,
            autoPlay: true,
            autoPlayInterval: Duration(seconds: 3),
            aspectRatio: 1 / 1,
            viewportFraction: 0.25,
            initialPage: 0,
          ),
          items: imageUrls.map((imageUrl) {
            return Builder(
              builder: (BuildContext context) {
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: 150,
                      height: 150,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProjectDetails(Map<String, dynamic> project) {
    return Card(
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Details',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              project['project_title'] ?? 'No Project Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                project['project_description'] ??
                    'No Project Description',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Technologies:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 10),
                ...project['technologies_used']
                    .map<Widget>((tech) {
                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Chip(
                      label: Text(tech),
                      backgroundColor: Colors.transparent,
                    ),
                  );
                }).toList(),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Project Goals:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project['project_goals'] ??
                        'No Goal Info',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Project Outcomes:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project['project_outcomes'] ??
                        'No Outcomes Info',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightContainer({
    required String title1,
    required String value1,
    required String title2,
    required String value2,
    String? title3,
    String? value3,
    String? secondRowTitle1,
    String? secondRowTitle2,
    String? secondRowValue1,
    String? secondRowValue2,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // Title 1 and Value 1
          Text(
            title1,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value1,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          // Title 2 and Value 2
          Text(
            title2,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value2,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          // Title 3 and Value 3 (Optional)
          if (title3 != null && value3 != null) ...[
            Text(
              title3,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value3,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
          ],
          // Second row with optional titles and values
          if (secondRowTitle1 != null &&
              secondRowValue1 != null) ...[
            Text(
              secondRowTitle1,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              secondRowValue1,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
          ],
          if (secondRowTitle2 != null &&
              secondRowValue2 != null) ...[
            Text(
              secondRowTitle2,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              secondRowValue2,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
