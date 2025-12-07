import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../internship/screens/dashboard.dart';

class CompanyFooterSection extends StatefulWidget {
  @override
  _CompanyFooterSectionState createState() => _CompanyFooterSectionState();
}

class _CompanyFooterSectionState extends State<CompanyFooterSection> {
  String instagramProfileUrl = '';
  String whatsappNumber = '';
  String whatsappMessage = '';
  String aboutUsUrl = '';
  String cancellationRefundUrl = '';
  String careersEmail = '';
  String contactUsUrl = '';
  String mailUsEmail = '';
  String privacyPolicyUrl = '';
  String termsOfUseUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchFooterData();
  }

  Future<void> _fetchFooterData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('footer')
          .get();
      if (doc.exists) {
        setState(() {
          instagramProfileUrl = doc['instagram'] ?? instagramProfileUrl;
          whatsappNumber = doc['whatsapp'] ?? whatsappNumber;
          whatsappMessage = doc['whatsapp_message'] ?? whatsappMessage;
          aboutUsUrl = doc['about_us'] ?? aboutUsUrl;
          cancellationRefundUrl = doc['cancellation_refund'] ?? cancellationRefundUrl;
          careersEmail = doc['careers'] ?? careersEmail;
          contactUsUrl = doc['contact_us'] ?? contactUsUrl;
          mailUsEmail = doc['mail_us'] ?? mailUsEmail;
          privacyPolicyUrl = doc['privacy_policy'] ?? privacyPolicyUrl;
          termsOfUseUrl = doc['terms_of_use'] ?? termsOfUseUrl;
        });
      }
    } catch (e) {
      debugPrint('Error fetching footer data: $e');
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      throw 'Could not launch $url';
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchGmail() async {
    try {
      if (mailUsEmail.isEmpty) return;
      final subject = '';
      final body = '';
      final baseUrl = 'https://mail.google.com/mail/';
      final url =
          '$baseUrl?view=cm&fs=1&to=$mailUsEmail&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      await _launchURL(url);
    } catch (e) {
      debugPrint('Error launching Gmail: $e');
    }
  }

  Future<void> _launchCareersGmail() async {
    try {
      if (careersEmail.isEmpty) return;
      final baseUrl = 'https://mail.google.com/mail/';
      final url = '$baseUrl?view=cm&fs=1&to=$careersEmail';
      await _launchURL(url);
    } catch (e) {
      debugPrint('Error launching Careers Gmail: $e');
    }
  }

  Future<void> _launchWhatsApp() async {
    if (whatsappNumber.isEmpty) return;
    final formattedNumber = whatsappNumber.replaceAll(RegExp(r'[ +]'), '');
    final url =
        'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(whatsappMessage)}';
    try {
      await _launchURL(url);
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 20.0 : 40.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: horizontalPadding),
      color: const Color(0xFF0F1018),
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final user = FirebaseAuth.instance.currentUser;


            final companyColumn = _FooterColumn(
              title: "Company",
              items: ["About Us", "Careers", "Contact Us", "Courses/Materials"], // 👈 added new item
              isMobile: isMobile,
              onItemTap: (item) {
                if (item == "About Us") {
                  _launchURL(aboutUsUrl);
                } else if (item == "Careers") {
                  if (user == null) {
                    // 👇 User not logged in
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please log in."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // 👇 navigate to HomePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HomePage()),
                    );
                  }
                } else if (item == "Contact Us") {
                  _launchURL(contactUsUrl);

                } else if (item == "Courses/Materials") {

                if (user == null) {
                // 👇 User not logged in
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                content: Text("Please log in to access Courses/Materials."),
                duration: Duration(seconds: 2),
                ),
                );
                } else {
                // 👇 navigate to HomePage
                Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
                );
                }
                }
              },
            );


            final policiesColumn = _FooterColumn(
              title: "Policies",
              items: ["Privacy Policy", "Terms of Service", "Cancellation and Refund Policy"],
              isMobile: isMobile,
              onItemTap: (item) {
                if (item == "Privacy Policy") {
                  _launchURL(privacyPolicyUrl);
                } else if (item == "Terms of Service") {
                  _launchURL(termsOfUseUrl);
                } else if (item == "Cancellation and Refund Policy") {
                  _launchURL(cancellationRefundUrl);
                }
              },
            );

            final connectColumn = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(
                crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    "Connect",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "We’d love to hear from you!",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: isMobile ? TextAlign.center : TextAlign.start,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisAlignment:
                    isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.instagram, color: Colors.grey),
                        onPressed: () => _launchURL(instagramProfileUrl),
                      ),
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.grey),
                        onPressed: _launchWhatsApp,
                      ),
                      IconButton(
                        icon: const Icon(FontAwesomeIcons.envelope, color: Colors.grey),
                        onPressed: _launchGmail,
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(child: companyColumn),
                  const SizedBox(height: 30),
                  Center(child: policiesColumn),
                  const SizedBox(height: 30),
                  Center(child: connectColumn),
                ],
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: companyColumn),
                  Expanded(child: policiesColumn),
                  Expanded(child: connectColumn),
                ],
              );
            }
          }),
          const SizedBox(height: 40),
          Divider(color: Colors.grey[800]),
          const SizedBox(height: 30),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('company_documents')
                .doc('footer')
                .get(),
            builder: (context, snapshot) {
              String footerText = "";
              if (snapshot.connectionState != ConnectionState.waiting &&
                  snapshot.hasData &&
                  snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                footerText = data['footer_text'] ?? "";
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    footerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;
  final void Function(String item)? onItemTap;
  final bool isMobile;

  const _FooterColumn({
    required this.title,
    required this.items,
    this.onItemTap,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onItemTap?.call(item),
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: isMobile ? TextAlign.center : TextAlign.start,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
