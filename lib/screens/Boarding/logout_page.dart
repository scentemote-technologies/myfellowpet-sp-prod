import 'dart:html' as html;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myfellowpet_sp/screens/Boarding/roles/role_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_service_info/Edit_Profile_Page.dart';


class SettingsPage extends StatefulWidget {
  final String serviceId;
  final VoidCallback onContactSupport;
  final VoidCallback onFAQ;

  const SettingsPage({Key? key, required this.serviceId, required this.onContactSupport, required this.onFAQ}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? ownerName;
  String? shop_user_id;
  String? ownerEmail;
  String? ownerPhone;
  bool loadingOwnerDetails = true;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    fetchOwnerDetails();
  }

  Future<void> fetchOwnerDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(widget.serviceId)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data();
            setState(() {
              ownerName = data?['owner_name'] ?? '';
              shop_user_id = data?['shop_user_id'] ?? '';
              ownerEmail = data?['notification_email'] ?? '';
              ownerPhone = data?['owner_phone'] ?? '';
              loadingOwnerDetails = false;
            });
          }

    } catch (e) {
      print('Error fetching owner details: $e');
      setState(() => loadingOwnerDetails = false);
    }
  }
  Future<void> _launchUrlFromFirestore(String fieldName) async {
    final messenger = ScaffoldMessenger.of(context);


    try {
      final doc = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('footer')
          .get();

      if (doc.exists && doc.data() != null) {
        final urlString = doc.data()![fieldName] as String?;
        if (urlString != null && urlString.isNotEmpty) {
          final uri = Uri.parse(urlString);
          // This opens the URL in a new tab on web
          await launchUrl(uri, webOnlyWindowName: '_blank');
        } else {
          throw 'Link for $fieldName is not available.';
        }
      } else {
        throw 'Could not find the document.';
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
  final me = context.watch<UserNotifier>().me;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🚀 disables the back arrow

        title: Text('Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (me?.role == 'Owner')
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loadingOwnerDetails)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (!loadingOwnerDetails && ownerName != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: $ownerName', style: GoogleFonts.poppins(fontSize: 14)),
                          Text('Email: $ownerEmail', style: GoogleFonts.poppins(fontSize: 14)),
                          Text('Phone: $ownerPhone', style: GoogleFonts.poppins(fontSize: 14)),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(
                            serviceId: widget.serviceId,
                            currentEmail: ownerEmail!,
                            currentPhone: ownerPhone!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFF2CB4B6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            // Profile Header
            /*Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null ? Icon(Icons.person, size: 40, color: Colors.white) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User Name',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),*/


            // Shop Owner Info




            /* ListTile(
              leading: Icon(Icons.lock, color: Colors.blue),
              title: Text('Change Password', style: GoogleFonts.poppins()),
              onTap: () {/* TODO: navigate to change password */},
            ),
            ListTile(
              leading: Icon(Icons.mail, color: Colors.blue),
              title: Text('Update Email', style: GoogleFonts.poppins()),
              onTap: () {/* TODO: navigate to update email */},
            ),*/
            /* const Divider(height: 32),

            // Preferences
            Text('Preferences', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text('Dark Mode', style: GoogleFonts.poppins()),
              value: false,
              onChanged: (v) {/* TODO: toggle theme */},
            ),
            ListTile(
              leading: Icon(Icons.language, color: Colors.blue),
              title: Text('Language', style: GoogleFonts.poppins()),
              trailing: Text('English', style: GoogleFonts.poppins()),
              onTap: () {/* TODO: select language */},
            ),*/
            if (me?.role == 'Owner')

              const Divider(height: 32),

            if (me?.role != 'Staff')
              Text('App Information', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (me?.role != 'Staff')
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('company_documents')
                    .doc('versions')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: Icon(Icons.info_outline, color: Color(0xFF2CB4B6)),
                      title: Text('App Version', style: GoogleFonts.poppins()),
                      trailing: const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  } else if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return ListTile(
                      leading: Icon(Icons.info_outline, color: Color(0xFF2CB4B6)),
                      title: Text('App Version', style: GoogleFonts.poppins()),
                      trailing: Text('Unavailable', style: GoogleFonts.poppins()),
                    );
                  }

                  final version = snapshot.data!.get('myfellowpet_web_app_version') ?? 'Unknown';

                  return ListTile(
                    leading: Icon(Icons.info_outline, color: Color(0xFF2CB4B6)),
                    title: Text('App Version', style: GoogleFonts.poppins()),
                    trailing: Text(version, style: GoogleFonts.poppins()),
                  );
                },
              ),
            if (me?.role != 'Staff')
              const Divider(height: 32),

            // Help & Feedback
            if (me?.role != 'Staff')

              Text('Support', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (me?.role != 'Staff')

              ListTile(
              leading: Icon(Icons.question_answer_outlined, color: Color(0xFF2CB4B6)),
              title: Text("FAQ's", style: GoogleFonts.poppins()),
              onTap: widget.onFAQ, // Navigate to FAQ page
              ),
            if (me?.role != 'Staff')

              ListTile(
              leading: Icon(Icons.help_outline, color: Color(0xFF2CB4B6)),
              title: Text('Help & Support', style: GoogleFonts.poppins()),
              onTap: widget.onContactSupport,
              ),


            if (me?.role != 'Staff')
              const Divider(height: 32),

            // Legal
            if (me?.role != 'Staff')
              Text('Legal', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (me?.role != 'Staff')
              ListTile(
                leading: Icon(Icons.shield_outlined, color: Color(0xFF2CB4B6)),
                title: Text('Privacy Policy', style: GoogleFonts.poppins()),
                onTap: () => _launchUrlFromFirestore('privacy_policy'),
              ),
            if (me?.role != 'Staff')
              ListTile(
                leading: Icon(Icons.article_outlined, color: Color(0xFF2CB4B6)),
                title: Text('Terms of Service', style: GoogleFonts.poppins()),
                onTap: () => _launchUrlFromFirestore('terms_of_use'),
              ),
            if (me?.role != 'Staff')
              const Divider(height: 32),


            // Sign Out and Delete Service
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 1. Update your button:
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _confirmAndSignOut,  // ← call our new helper
                ),

                SizedBox(width: 15),
                if (me?.role == 'Owner')
                  OutlinedButton(
                    onPressed: () => _sendDeletionEmail(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Suspend This Service',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),


              ],
            ),
          ],
        ),
      ),
    );
  }


  // 2. Add this helper inside your State class:

  Future<void> _confirmAndSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w600
          ),
        ),
        content: Text(
          'Are you sure you want to sign out? You’ll need to log in again to continue.',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldSignOut) return;

    // proceed with actual sign-out
    await FirebaseAuth.instance.signOut();
    // Now, reload the page instead of navigating
    if (mounted) {
      // Correct navigation using context.go()
      context.go('/');
    }}


  /// Your existing HTTP POST wrapped in a method:
  Future<void> _sendDeletionEmail() async {
    // 1️⃣ Ask for confirmation first
    final shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Are you sure?',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will send you a confirmation email to finalize suspension. Continue?',
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldSend) return;

    // 2️⃣ Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF2CB4B6),
              ),
              const SizedBox(height: 16),
              Text(
                'Sending confirmation email...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 3️⃣ Perform the HTTP request
    final url = Uri.parse(
        'https://us-central1-petproject-test-g.cloudfunctions.net/sendDeletionEmail');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'serviceId': widget.serviceId,
          'initiatorEmail': ownerEmail,
        }),
      );

      // 4️⃣ Close loader before showing snackbar
      Navigator.of(context, rootNavigator: true).pop();

      final msg = response.statusCode == 200
          ? 'Confirmation email sent.'
          : 'Error ${response.statusCode}: ${response.body}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.poppins())),
      );
    } catch (e) {
      // 4️⃣ Close loader before showing snackbar
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text('Failed to send email: $e', style: GoogleFonts.poppins()),
        ),
      );
    }
  }

}
