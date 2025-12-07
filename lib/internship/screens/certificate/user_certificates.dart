import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class CertificateViewPage extends StatefulWidget {
  @override
  _CertificateViewPageState createState() => _CertificateViewPageState();
}

class _CertificateViewPageState extends State<CertificateViewPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController certificateIdController = TextEditingController();
  final TextEditingController userIdController = TextEditingController();

  bool isCertificateIdSearch = false;
  bool isUserIdSearch = false;
  Map<String, dynamic>? certificateData;
  List<Map<String, dynamic>> userCertificates = [];

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 2 tabs
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // Fetch certificate details by certificate ID (either course or internship)
  Future<void> fetchCertificateDetails(String certificateId, bool isInternship) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final collection = isInternship
            ? 'user-internship-certificates'
            : 'user-certificates';

        final certDoc = await FirebaseFirestore.instance
            .collection('certifications')
            .doc(userId)
            .collection(collection)
            .doc(certificateId)
            .get();

        if (certDoc.exists) {
          setState(() {
            certificateData = certDoc.data();
            isCertificateIdSearch = true;
            isUserIdSearch = false;
          });
        } else {
          setState(() {
            certificateData = null;
            isCertificateIdSearch = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching certificate: $e');
    }
  }

  // Fetch all certificates for a specific user by their user ID
  Future<void> fetchUserCertificates(String userId, bool isInternship) async {
    try {
      final collection = isInternship
          ? 'user-internship-certificates'
          : 'user-certificates';

      final certDocs = await FirebaseFirestore.instance
          .collection('certifications')
          .doc(userId)
          .collection(collection)
          .get();

      if (certDocs.docs.isNotEmpty) {
        setState(() {
          userCertificates = certDocs.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          isUserIdSearch = true;
          isCertificateIdSearch = false;
        });
      } else {
        setState(() {
          userCertificates = [];
          isUserIdSearch = false;
        });
      }
    } catch (e) {
      print('Error fetching user certificates: $e');
    }
  }

  // Open the PDF URL in a browser
  Future<void> openPdf(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not open the URL: $url';
    }
  }

  // Reset search fields
  void _resetSearchFields() {
    certificateIdController.clear();
    userIdController.clear();
    setState(() {
      certificateData = null;
      userCertificates = [];
      isCertificateIdSearch = false;
      isUserIdSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Certificate Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => _resetSearchFields(), // reset when switching
          tabs: [
            Tab(
              child: Text(
                'Courses',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
            Tab(
              child: Text(
                'Internships',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: COURSES
          _buildCertificateTab(context, isDesktop, isInternship: false),
          // TAB 2: INTERNSHIPS
          _buildCertificateTab(context, isDesktop, isInternship: true),
        ],
      ),
    );
  }

  // Reusable method to build the "Courses" or "Internships" tab content
  Widget _buildCertificateTab(BuildContext context, bool isDesktop,
      {required bool isInternship}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: isDesktop
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Search forms
          Expanded(
            flex: 1,
            child: _buildSearchSection(isInternship),
          ),
          SizedBox(width: 20),
          // Right side: Results
          Expanded(
            flex: 2,
            child: _buildResultsSection(isInternship),
          ),
        ],
      )
          : Column(
        children: [
          _buildSearchSection(isInternship),
          SizedBox(height: 16),
          _buildResultsSection(isInternship),
        ],
      ),
    );
  }

  // Builds the left-side search forms
  Widget _buildSearchSection(bool isInternship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Certificate by ID:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: certificateIdController,
          decoration: InputDecoration(
            hintText: 'Enter Certificate ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            if (certificateIdController.text.isNotEmpty) {
              fetchCertificateDetails(
                certificateIdController.text,
                isInternship,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Search by Certificate ID',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Search by User ID:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: userIdController,
          decoration: InputDecoration(
            hintText: 'Enter User ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_search),
          ),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            if (userIdController.text.isNotEmpty) {
              fetchUserCertificates(userIdController.text, isInternship);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Search by User ID',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // Builds the right-side results
  Widget _buildResultsSection(bool isInternship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // If searching by certificate ID
        if (isCertificateIdSearch)
          certificateData == null
              ? Center(
            child: Text(
              'Certificate not found!',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          )
              : _buildCertificateDetails(isInternship),

        // If searching by user ID
        if (isUserIdSearch)
          userCertificates.isEmpty
              ? Center(
            child: Text(
              'No certificates found for this user!',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          )
              : Column(
            children: userCertificates.map((cert) {
              return GestureDetector(
                onTap: () {
                  fetchCertificateDetails(cert['certificateId'], isInternship);
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name: ${cert['name']}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isInternship
                              ? 'Internship: ${cert['internshipName']}'
                              : 'Course: ${cert['courseName']}',
                        ),
                        Text('Date: ${cert['date']}'),
                        if (cert['pdfUrl'] != null)
                          ElevatedButton(
                            onPressed: () => openPdf(cert['pdfUrl']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF03589E),
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Download PDF',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // Helper widget to show details of a single certificate
  Widget _buildCertificateDetails(bool isInternship) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certificate Details:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('Name: ${certificateData!['name']}'),
        Text(
          isInternship
              ? 'Internship: ${certificateData!['internshipName']}'
              : 'Course: ${certificateData!['courseName']}',
        ),
        Text('Date: ${certificateData!['date']}'),
        SizedBox(height: 12),
        if (certificateData!['pdfUrl'] != null)
          ElevatedButton(
            onPressed: () => openPdf(certificateData!['pdfUrl']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF03589E),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Download PDF',
              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
