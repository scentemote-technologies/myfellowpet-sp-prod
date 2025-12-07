import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Internship Page/internship_enrollment.dart';
import '../internship/Internship_dasboard.dart';

class InternshipPage extends StatefulWidget {
  @override
  _InternshipPageState createState() => _InternshipPageState();
}

class _InternshipPageState extends State<InternshipPage> {
  final TextEditingController _searchController = TextEditingController();

  // Internships & filtering
  List<DocumentSnapshot> internships = [];
  List<DocumentSnapshot> filteredInternships = [];
  String userId = '';
  String searchQuery = '';

  // Filter variables
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? selectedWorkModel;
  int? selectedDuration;
  String? selectedCompensationType;

  // Track the currently selected internship for detail display
  String _selectedInternship = '';

  @override
  void initState() {
    super.initState();
    _getUserId();
    _fetchInternships();
  }

  void _getUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
    }
  }

  void _fetchInternships() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('internships').get();
    setState(() {
      internships = snapshot.docs;
      filteredInternships = internships;
    });
  }

  // Called whenever the user changes the search bar or updates filters
  void _filterInternships(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      _selectedInternship = ''; // reset selected internship

      filteredInternships = internships.where((internship) {
        // Match search text
        String title = (internship['title'] ?? '').toLowerCase();
        bool matchesSearch = title.contains(searchQuery);

        // Match other filters
        return matchesSearch && _applyFilters(internship);
      }).toList();
    });
  }

  // Original bool _applyFilters remains unchanged:
  bool _applyFilters(DocumentSnapshot internship) {
    bool matchesWorkModel = selectedWorkModel == null ||
        internship['work_model'] == selectedWorkModel;
    bool matchesDuration = selectedDuration == null ||
        (internship['duration'] != null &&
            int.parse(internship['duration'].toString().split(' ')[0]) == selectedDuration);
    bool matchesCompensationType = _filterByCompensationType(internship);
    return matchesWorkModel && matchesDuration && matchesCompensationType;
  }

// Renamed void function for applying filters:
  // Inside your _InternshipPageState:

// Rename the void function for applying filters:
  void _applyFiltersAction() {
    // Only when "Apply" is tapped, re-filter the internships.
    _filterInternships(searchQuery);
    Navigator.of(context).pop(); // close the filter drawer
  }

// Keep _resetFilters as-is:
  void _resetFilters() {
    setState(() {
      selectedWorkModel = null;
      selectedDuration = null;
      selectedCompensationType = null;
      searchQuery = '';
      _searchController.clear();
      _selectedInternship = '';
      filteredInternships = internships; // revert to all
    });
    Navigator.of(context).pop(); // close the filter drawer
  }




  bool _filterByCompensationType(DocumentSnapshot internship) {
    if (selectedCompensationType == null) return true;
    String compensationType = internship['compensation_type'] ?? '';
    return compensationType == selectedCompensationType;
  }

  // Called when user taps the 'Apply' button in the filter drawer



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          'Find Internships',
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
          // Filter icon opens the endDrawer
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.filter_alt, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60.0),
          child: Container(
            color: Colors.black,
            padding: EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterInternships,
                decoration: InputDecoration(
                  hintText: "Search internships...",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[600]),
                    onPressed: () {
                      _searchController.clear();
                      _filterInternships('');
                    },
                  )
                      : null,
                  contentPadding: EdgeInsets.all(10.0),
                ),
              ),
            ),
          ),
        ),
      ),
      // Filter drawer on the right
      endDrawer: Drawer(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filters',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('Work Model', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Select Work Model"),
                  value: selectedWorkModel,
                  onChanged: (value) {
                    setState(() {
                      selectedWorkModel = value;
                    });
                  },
                  items: ["Remote", "In-office", "Hybrid"]
                      .map((workModel) => DropdownMenuItem(
                    value: workModel,
                    child: Text(workModel),
                  ))
                      .toList(),
                ),
                SizedBox(height: 16),
                Text('Duration', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  isExpanded: true,
                  hint: Text("Select Duration"),
                  value: selectedDuration,
                  onChanged: (value) {
                    setState(() {
                      selectedDuration = value;
                    });
                  },
                  items: [30, 45, 90, 180]
                      .map((days) => DropdownMenuItem(
                    value: days,
                    child: Text("$days Days"),
                  ))
                      .toList(),
                ),
                SizedBox(height: 16),
                Text('Compensation Type', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Select Compensation"),
                  value: selectedCompensationType,
                  onChanged: (value) {
                    setState(() {
                      selectedCompensationType = value;
                    });
                  },
                  items: ["Unpaid", "Paid", "Stipend"]
                      .map((compType) => DropdownMenuItem(
                    value: compType,
                    child: Text(compType),
                  ))
                      .toList(),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _applyFiltersAction,
                      child: Text("Apply"),
                    ),
                    ElevatedButton(
                      onPressed: _resetFilters,
                      child: Text("Clear"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isPhone = constraints.maxWidth < 600;
            // Remove fixed height so that the entire content scrolls naturally
            return isPhone ? _buildPhoneLayout() : _buildDesktopLayout();
          },
        ),
      ),
    );
  }


  // PHONE LAYOUT: List on top, details below
  // Updated _buildPhoneLayout for vertical scrolling of the entire page
  // Phone layout: list on top, details below, all scrollable.
  Widget _buildPhoneLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInternshipList(),
        SizedBox(height: 16),
        _selectedInternship.isNotEmpty
            ? _buildInternshipDetails(
            filteredInternships.firstWhere(
                    (internship) => internship['title'] == _selectedInternship))
            : Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Select an internship to view details",
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

// Internship list using shrinkWrap and non-scrollable physics
  Widget _buildInternshipList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: filteredInternships.length,
        itemBuilder: (context, index) {
          var internship = filteredInternships[index];
          String title = internship['title'] ?? 'No Title';
          String domain = internship['domain'] ?? 'No Domain';
          String location = internship['work_model'] ?? 'No Location';
          List<dynamic> imageUrls = internship['image_url'] ?? [];
          String imageUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';

          return Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedInternship = title;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 80,
                          width: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Domain: $domain',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Location: $location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }




  // DESKTOP LAYOUT: List on left, details on right
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // List
        Expanded(
          flex: 1,
          child: _buildInternshipList(),
        ),
        // Details
        Expanded(
          flex: 2,
          child: _selectedInternship.isNotEmpty
              ? _buildInternshipDetails(
              filteredInternships.firstWhere((intern) =>
              intern['title'] == _selectedInternship))
              : Center(
            child: Text(
              "Select an internship to view details",
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }



  // Internship Details
  Widget _buildInternshipDetails(DocumentSnapshot internship) {
    String title = internship['title'] ?? 'No Title';
    String domain = internship['domain'] ?? 'No Domain';
    String location = internship['work_model'] ?? 'No Location';
    String duration = internship['duration'] ?? 'No Duration';
    String description1 = internship['description_1'] ?? 'No Description';
    String description2 = internship['description_2'] ?? 'No Description';
    bool ongoing = internship['ongoing'] ?? false;
    List<dynamic> imageUrls = internship['image_url'] ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('internship-submission')
          .where('courseName', isEqualTo: title)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          );
        }

        bool isUidMissing = true;
        bool isSeen = true;
        bool isApplied = false;
        String buttonText = 'Apply Now';
        VoidCallback? onPressed = () async {};

        for (var doc in snapshot.data!.docs) {
          String docUid = doc['uid'];
          bool docSeen = doc['seen'] ?? true;
          bool docApplied = doc['applied'] ?? false;
          if (docUid == userId) {
            isUidMissing = false;
            isSeen = docSeen;
            isApplied = docApplied;
            break;
          }
        }

        // Determine button text & action
        if (isUidMissing) {
          buttonText = 'Apply Now';
          onPressed = () async {
            bool enrollmentComplete = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InternshipEnrollment(
                  courseName: title,
                  uid: userId,
                ),
              ),
            );
            if (enrollmentComplete == true) {
              setState(() {});
            }
          };
        } else if (isSeen && !isApplied) {
          buttonText = 'Apply Now';
          onPressed = () async {
            bool enrollmentComplete = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InternshipEnrollment(
                  courseName: title,
                  uid: userId,
                ),
              ),
            );
            if (enrollmentComplete == true) {
              setState(() {});
            }
          };
        } else if (isSeen && isApplied) {
          buttonText = 'APPLIED';
          onPressed = null;
        } else if (!isSeen && !isApplied) {
          buttonText = 'APPLIED';
          onPressed = null;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Internship Images (Horizontal Scroll)
              if (imageUrls.isNotEmpty)
                Container(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrls[index],
                            width: 250,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 24),

              // Title + Apply Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonText == "APPLIED"
                          ? Colors.green
                          : (ongoing ? Colors.black : Colors.grey[400]),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (isApplied && isSeen)
                Text(
                  'Your enrollment is being reviewed',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              SizedBox(height: 24),

              Text(
                'Description',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                description1,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                description2,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 14),

              // Internship Details
              _buildDetailCard(
                icon: Icons.work_outline,
                label: 'Domain',
                value: domain,
              ),
              _buildDetailCard(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: location,
              ),
              _buildDetailCard(
                icon: Icons.calendar_today_outlined,
                label: 'Duration',
                value: duration,
              ),
              _buildDetailCard(
                icon: Icons.currency_rupee,
                label: 'Compensation Type',
                value: internship['compensation_type'] ?? 'Not Specified',
              ),
            ],
          ),
        );
      },
    );
  }

  /// Updated _buildDetailCard method:
  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align at the top
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            SizedBox(width: 16),
            // Expanded ensures text can wrap instead of overflowing horizontally
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label (e.g. "Domain")
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  // Value (e.g. "Web Development / Full Stack Developer ...")
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    // Allow wrapping to new lines
                    softWrap: true,
                    // Optionally limit lines or show ellipsis:
                    // maxLines: 3,
                    // overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
