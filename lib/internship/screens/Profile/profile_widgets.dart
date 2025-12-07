import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../courses/course_detail.dart';
import '../internship_dashboard/internship_dashboard.dart';
import '../certificate/user_certificates.dart';

class ProfileWidgets {
  /// Responsive helper function.
  static double responsiveValue(
      BuildContext context, double mobile, double tablet, double laptop, double desktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1440) return desktop;
    if (screenWidth > 1024) return laptop;
    if (screenWidth > 600) return tablet;
    return mobile;
  }

  /// Builds a modern, responsive profile header with well-placed information.
  static Widget buildProfileHeader({
    required BuildContext context,
    required String? displayName,
    required String? email,
    required String? photoURL,
    required String uid,
    required String? phoneNumber,
    required String? instituteName,
    required String? district,
    required String? state,
    required String? age,
    required String? gender,
    required VoidCallback onGetImage,
    required VoidCallback onOpenDialog,
    required VoidCallback onSignOut,
    required bool isHovering,
    required Function(bool) onHoverChanged,
    BoxDecoration? headerDecoration,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double avatarRadius = responsiveValue(context, 50, 60, 70, 80);

    Widget _buildInfoRow(String label, String value, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: responsiveValue(context, 14, 15, 16, 17),
                    color: Colors.grey[800],
                  ),
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget desktopLayout = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: onGetImage,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundImage: photoURL != null
                          ? NetworkImage(photoURL)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake, size: 16, color: Colors.blue[800]),
                  const SizedBox(width: 8),
                  Text(
                    age ?? 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gender ?? '',
                    style: TextStyle(color: Colors.blue[800]),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName ?? 'No Name',
                      style: TextStyle(
                        fontSize: responsiveValue(context, 22, 24, 26, 28),
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                  _buildCopyUIDButton(context, uid),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Email', email ?? 'Not provided', Icons.email),
                    _buildInfoRow('Phone', phoneNumber ?? 'Not provided', Icons.phone),
                    _buildInfoRow('Institute', instituteName ?? 'Not provided', Icons.school),
                    _buildInfoRow('Location', '${district ?? ''}, ${state ?? ''}', Icons.location_on),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget mobileLayout = Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: onGetImage,
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundImage: photoURL != null
                    ? NetworkImage(photoURL)
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
                backgroundColor: Colors.grey[200],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 20, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          displayName ?? 'No Name',
          style: TextStyle(
            fontSize: responsiveValue(context, 20, 22, 24, 26),
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 8),
        _buildCopyUIDButton(context, uid),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildInfoRow('Age', age ?? 'N/A', Icons.cake),
              _buildInfoRow('Email', email ?? 'Not provided', Icons.email),
              _buildInfoRow('Phone', phoneNumber ?? 'Not provided', Icons.phone),
              _buildInfoRow('Institute', instituteName ?? 'Not provided', Icons.school),
              _buildInfoRow('Location', '${district ?? ''}, ${state ?? ''}', Icons.location_on),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: headerDecoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              )
            ],
          ),
      child: Column(
        children: [
          isMobile ? mobileLayout : desktopLayout,
          const SizedBox(height: 24),
          _buildActionButtons(
            context: context,
            onOpenDialog: onOpenDialog,
            onSignOut: onSignOut,
            isHovering: isHovering,
            onHoverChanged: onHoverChanged,
          ),
        ],
      ),
    );
  }

  static Widget _buildCopyUIDButton(BuildContext context, String uid) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: uid));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID copied to clipboard')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UID: ${uid.substring(0, 6)}...',
                style: TextStyle(
                  fontSize: responsiveValue(context, 12, 13, 14, 15),
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy, size: 16, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildActionButtons({
    required BuildContext context,
    required VoidCallback onOpenDialog,
    required VoidCallback onSignOut,
    required bool isHovering,
    required Function(bool) onHoverChanged,
  }) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.edit,
          label: 'Edit Profile',
          onPressed: onOpenDialog,
          color: Colors.deepPurple,
        ),
        _buildActionButton(
          context: context,
          icon: Icons.assignment,
          label: 'Certificates',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CertificateViewPage()),
          ),
          color: Colors.deepPurple,
        ),
        MouseRegion(
          onEnter: (_) => onHoverChanged(true),
          onExit: (_) => onHoverChanged(false),
          child: _buildActionButton(
            context: context,
            icon: Icons.logout,
            label: 'Sign Out',
            onPressed: onSignOut,
            color: Colors.deepPurple,
            isHovering: isHovering,
          ),
        ),
      ],

    );
  }

  static Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isHovering = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: responsiveValue(context, 16, 18, 20, 22),
        color: Colors.white,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: responsiveValue(context, 14, 16, 18, 20),
          color: Colors.white, // White font color
          fontWeight: FontWeight.bold, // Bold text
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: responsiveValue(context, 20, 22, 24, 26),
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: isHovering ? 8 : 4,
      ),
    );
  }


  /// The following grid builder methods remain unchanged.
  static Widget buildCoursesGrid(BuildContext context, List<Map<String, dynamic>> courseDetails,
      String noCoursesMessage,
      {int? gridColumns}) {
    if (courseDetails.isEmpty) return Center(child: Text(noCoursesMessage));

    final screenWidth = MediaQuery.of(context).size.width;
    int columns;
    if (screenWidth < 600) {
      columns = 1;
    } else if (screenWidth < 800) {
      columns = 2;
    } else if (screenWidth < 1024) {
      columns = 3;
    } else {
      columns = gridColumns ?? 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Courses Enrolled',
            style: TextStyle(
              fontSize: responsiveValue(context, 18, 20, 22, 24),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 250,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: courseDetails.length,
          itemBuilder: (context, index) {
            final course = courseDetails[index];
            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          course['image'],
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course['name'],
                          style: TextStyle(
                            fontSize: responsiveValue(context, 16, 18, 20, 22),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          course['description'],
                          style: TextStyle(
                            fontSize: responsiveValue(context, 14, 16, 18, 20),
                            color: Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseDetailPage(
                                courseName: course['name'],
                                imageUrl: course['image'],
                                description: course['description'],
                                sectionIds: [],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A3A3A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(
                            horizontal: responsiveValue(context, 20, 22, 24, 26),
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'Go to Course',
                          style: TextStyle(
                            fontSize: responsiveValue(context, 14, 16, 18, 20),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static Widget buildInternshipsGrid(
      BuildContext context, List<String> internships, String? userID,
      {int? gridColumns}) {
    final screenWidth = MediaQuery.of(context).size.width;
    int columns;
    if (screenWidth < 600) {
      columns = 1;
    } else if (screenWidth < 800) {
      columns = 2;
    } else if (screenWidth < 1024) {
      columns = 3;
    } else {
      columns = gridColumns ?? 4;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Internships Enrolled',
            style: TextStyle(
              fontSize: responsiveValue(context, 18, 20, 22, 24),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        internships.isNotEmpty
            ? GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 270,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: internships.length,
          itemBuilder: (context, index) {
            final internshipId = internships[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('internships').doc(internshipId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: Text('Error loading internship data'));
                }
                var internshipData = snapshot.data!.data() as Map<String, dynamic>;
                String imageUrl = '';
                if (internshipData['image_url'] is List) {
                  imageUrl = internshipData['image_url'][0] ?? '';
                } else if (internshipData['image_url'] is String) {
                  imageUrl = internshipData['image_url'] ?? '';
                }
                return Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 120,
                            color: Colors.grey[300],
                            alignment: Alignment.center,
                            child: const Icon(Icons.image, color: Colors.white, size: 40),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          internshipData['title'] ?? 'No Title',
                          style: TextStyle(
                            fontSize: responsiveValue(context, 16, 18, 20, 22),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InternshipCoursePage(
                                  userId: userID ?? "",
                                  documentId: internshipId,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3A3A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: responsiveValue(context, 20, 22, 24, 26),
                            ),
                          ),
                          child: Text(
                            'Start',
                            style: TextStyle(
                              fontSize: responsiveValue(context, 14, 16, 18, 20),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        )
            : const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  /// Builds a complete profile dialog with modern styling.
  static Widget buildCompleteProfileDialog({
    required BuildContext context,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
    required TextEditingController instituteController,
    required TextEditingController districtController,
    required TextEditingController stateController,
    required TextEditingController ageController,
    required TextEditingController genderController,
    required Function(Map<String, String> updatedData) onSave,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        "Complete Your Profile",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: responsiveValue(context, 18, 20, 22, 24),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone Number")),
            TextField(controller: instituteController, decoration: const InputDecoration(labelText: "Institute Name")),
            TextField(controller: districtController, decoration: const InputDecoration(labelText: "District")),
            TextField(controller: stateController, decoration: const InputDecoration(labelText: "State")),
            TextField(
              controller: ageController,
              decoration: const InputDecoration(labelText: "Age"),
              keyboardType: TextInputType.number,
            ),
            TextField(controller: genderController, decoration: const InputDecoration(labelText: "Gender")),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Map<String, String> updatedData = {
              'displayName': nameController.text.trim(),
              'email': emailController.text.trim(),
              'phoneNumber': phoneController.text.trim(),
              'instituteName': instituteController.text.trim(),
              'district': districtController.text.trim(),
              'state': stateController.text.trim(),
              'age': ageController.text.trim(),
              'gender': genderController.text.trim(),
            };
            onSave(updatedData);
            Navigator.pop(context);
          },
          child: Text(
            "Save",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: responsiveValue(context, 16, 18, 20, 22),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(fontSize: responsiveValue(context, 16, 18, 20, 22)),
          ),
        ),
      ],
    );
  }
}
