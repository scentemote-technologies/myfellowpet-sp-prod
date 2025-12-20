import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Partner/email_signin.dart';
import '../Pet_Store/PetStoreOnboarding.dart';
import 'HomeBoarderOnboardPage.dart';
import 'ShopDetailsPage.dart'; // Keep if needed

class RunTypeSelectionPage extends StatelessWidget {
  final String uid;
  final String phone;
  final bool fromOtherbranches;
  final String email;
  final String? serviceId;
  final String? shopName;

  const RunTypeSelectionPage({
    Key? key,
    required this.uid,
    required this.phone,
    this.serviceId,
    required this.email, required this.fromOtherbranches, this.shopName,
  }) : super(key: key);

  static const Color primaryColor = Color(0xFF00838F); // A deeper teal
  static const Color accentColor = Color(0xFF00BCD4); // A brighter cyan

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
          // --- 1. Main Content (Existing StreamBuilder) ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('partner_run_types')
                .doc('Boarding')
                .collection('types')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final List<_RunTypeOption> options = [
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _RunTypeOption(
                    data['title'] ?? '',
                    data['subtitle'] ?? '',
                    _getIcon(data['icon'] ?? 'home'),
                    doc.id == 'home_boarding'
                        ? Homeboarderonboardpage(
                      fromOtherbranches:fromOtherbranches,
                      uid: uid,
                      phone: phone,
                      email: email,
                      runType: 'Home Run',
                      serviceId: serviceId ?? '',
                    )
                        : ComingSoonPage(title: data['title'] ?? ''),
                    isComingSoon: data['isComingSoon'] ?? true,
                  );
                }).toList(),

              ];

              return Container(
                // Your main content styling and structure
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withOpacity(0.9),
                      accentColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        child: Text(
                          'Become a Partner',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'How would you like to partner with us?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Select the option that best describes your service.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 40),
                              Wrap(
                                spacing: 20,
                                runSpacing: 20,
                                alignment: WrapAlignment.center,
                                children: options
                                    .map((opt) => _OptionCard(option: opt))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // --- 2. Floating Back Arrow Button (Layered on top) ---
          Positioned(
            top: 30, // Adjust this value for vertical spacing (inside SafeArea)
            left: 10, // Adjust this value for horizontal spacing
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new, // A slightly better-looking back arrow
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                // Optional: Add a subtle background for better visibility
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.2),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 10,
            child: SafeArea(
              child: GestureDetector(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => SignInPage()),
                        (route) => false, // POP ALL ROUTES
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Sign out',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  IconData _getIcon(String key) {
    switch (key) {
      case 'business':
        return Icons.business_center_outlined;
      case 'ngo':
        return Icons.volunteer_activism_outlined;
      case 'vet':
        return Icons.local_hospital_outlined;
      default:
        return Icons.home_work_outlined;
    }
  }
}

class _RunTypeOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  final bool isComingSoon;

  _RunTypeOption(this.title, this.subtitle, this.icon, this.page,
      {this.isComingSoon = false});
}

class _OptionCard extends StatefulWidget {
  final _RunTypeOption option;

  const _OptionCard({Key? key, required this.option}) : super(key: key);

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !widget.option.isComingSoon;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isEnabled
            ? () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => widget.option.page),
        )
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          height: 220,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (isEnabled && _isHovered)
                BoxShadow(
                  color: RunTypeSelectionPage.primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            gradient: isEnabled
                ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            )
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade300,
              ],
            ),
            border: Border.all(
              color: isEnabled && _isHovered
                  ? RunTypeSelectionPage.accentColor
                  : Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.option.icon,
                    size: 40,
                    color: isEnabled
                        ? RunTypeSelectionPage.primaryColor
                        : Colors.grey.shade500,
                  ),
                  const Spacer(),
                  Text(
                    widget.option.title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isEnabled ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.option.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isEnabled ? Colors.black54 : Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              if (!isEnabled)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'COMING SOON',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: RunTypeSelectionPage.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded,
                color: RunTypeSelectionPage.primaryColor, size: 80),
            const SizedBox(height: 20),
            Text(
              'Coming Soon!',
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is under development.\nStay tuned!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
