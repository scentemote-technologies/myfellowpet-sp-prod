// lib/widgets/PartnerAppbar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myfellowpet_sp/screens/Partner/email_signin.dart';
import 'package:myfellowpet_sp/screens/Partner/partnerSpFaqs.dart';

// --- Brand Colors ---
const Color primaryColor = Color(0xFF2CB4B6);
const Color accentColor = Color(0xFFF67B0D);
const Color textColor = Color(0xFF2D3748);
const Color subtleTextColor = Color(0xFF718096);
const Color backgroundColor = Colors.white;

class PartnerAppbar extends StatelessWidget implements PreferredSizeWidget {
  // Pass the Scaffold key to control the drawer on mobile
  final GlobalKey<ScaffoldState> scaffoldKey;

  const PartnerAppbar({
    Key? key,
    required this.scaffoldKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define breakpoints for responsive layout changes
        const double mobileBreakpoint = 600.0;
        const double tabletBreakpoint = 1000.0;

        // Determine the horizontal padding based on screen width
        double horizontalPadding;
        if (constraints.maxWidth > tabletBreakpoint) {
          horizontalPadding = 100.0; // Desktop
        } else if (constraints.maxWidth > mobileBreakpoint) {
          horizontalPadding = 40.0; // Tablet
        } else {
          horizontalPadding = 20.0; // Mobile
        }

        // Return the mobile app bar for narrow screens
        if (constraints.maxWidth < mobileBreakpoint) {
          return _buildMobileAppBar(context, horizontalPadding);
        }

        // Return the desktop app bar for wider screens
        return _buildDesktopAppBar(context, horizontalPadding);
      },
    );
  }

  // --- Desktop/Tablet AppBar ---
  Widget _buildDesktopAppBar(BuildContext context, double horizontalPadding) {
    return Container(
      height: preferredSize.height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: const BoxDecoration(
        color: Colors.white, // ✅ Always white
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Logo
          Image.asset('assets/myfellowpet_web_logo.jpg', height: 50),

          // 2. FAQ's Button
          ElevatedButton.icon(
            onPressed: () {
              // 🚀 Replacing context.go('/partner-with-us/faqs')
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PartnerFaqPage(), // Assuming PartnerFaqPage is the target
                ),
              );
            },
            icon: const Icon(Icons.quiz_outlined, size: 20, color: Colors.white,),
            label: const Text("FAQ's"),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Mobile AppBar ---
  PreferredSizeWidget _buildMobileAppBar(BuildContext context, double horizontalPadding) {
    return AppBar(
      backgroundColor: Colors.white, // ✅ Always white
      foregroundColor: Colors.black, // ✅ Force dark icons/text
      surfaceTintColor: Colors.transparent, // ✅ Remove overlay tint

      elevation: 1.0,
      shadowColor: Colors.black.withOpacity(0.1),
      automaticallyImplyLeading: false, // We use a custom leading widget
      titleSpacing: horizontalPadding,
      title: Image.asset('assets/myfellowpet_web_logo.jpg', height: 40),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: textColor, size: 28),
          onPressed: () {
            // Use the scaffold key to open the drawer
            scaffoldKey.currentState?.openDrawer();
          },
          tooltip: 'Menu',
        ),
      ),
    );
  }

  // A separate widget for the navigation drawer on mobile
  static Widget buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Color(0xFF1A7F81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Menu',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.quiz_outlined,
            text: "FAQ's",
            onTap: () {
              // 🚀 Replacing context.go('/partner-with-us/faqs')
              // Use push to keep the current page (Sign In) in history, allowing a back button.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PartnerFaqPage(), // Assuming PartnerFaqPage is the target
                ),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            icon: Icons.home_outlined,
            text: 'Home',
            onTap: () {
              // 🚀 Replacing context.go('/')
              // Use push to navigate to the main Home screen (MainHomeScreen).
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SignInPage(), // Assuming MainHomeScreen is the target of '/'
                ),
              );
            },
          ),
          // Add more navigation items here...
        ],
      ),
    );
  }

  static ListTile _buildDrawerItem(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: subtleTextColor),
      title: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      onTap: () {
        // Close the drawer before navigating
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
