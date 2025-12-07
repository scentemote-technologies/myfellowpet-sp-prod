// lib/screens/profile_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Assuming AppUser and UserNotifier are correctly defined in this imported file
// NOTE: Ensure your AppUser class has the 'serviceType' property.
import '../Boarding/roles/role_service.dart';

const Color primaryColor = Color(0xFF2CB4B6);
const Color accentColor = Color(0xFFF67B0D);
const Color storeColor = Color(0xFFDD6B20); // Orange/Brown for store
const Color boardingColor = Color(0xFF319795); // Teal for boarding
const Color employeeColor = Color(0xFF4299E1); // Blue for employees

// 1. Converted to a StatefulWidget
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UserNotifier>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[100]!,
            ],
          ),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final horizontalPadding = isWide ? (constraints.maxWidth - 550) / 2 : 24.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.person_search_outlined, size: 60, color: primaryColor.withOpacity(0.8)),
                    const SizedBox(height: 16),
                    Text(
                      'Choose Your Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select an account to continue to your dashboard.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (notifier.ownerProfiles.isNotEmpty) ...[
                      _buildSectionHeader('Owner Profiles'),
                      ...notifier.ownerProfiles.map((profile) => _buildProfileCard(context, profile)),
                      const SizedBox(height: 32),
                    ],
                    _buildAddShopCard(context),
                    const SizedBox(height: 32),
                    if (notifier.employeeProfiles.isNotEmpty) ...[
                      _buildSectionHeader('Employee Roles'),
                      ...notifier.employeeProfiles.map((profile) => _buildProfileCard(context, profile)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  // 🛑 UPDATED: Function to build a card with dynamic icons/colors based on service type
  Widget _buildProfileCard(BuildContext context, AppUser profile) {
    final notifier = Provider.of<UserNotifier>(context, listen: false);

    // --- Dynamic Styling Logic ---
    IconData icon;
    Color iconColor;
    String typeSuffix;

    // Determine color and icon based on the serviceType field from AppUser
    if (profile.serviceType.contains('Store')) {
      icon = Icons.store_mall_directory_outlined;
      iconColor = storeColor;
      typeSuffix = '(Pet Store)';
    } else { // Assumes 'Boarding' or 'Home Run'
      icon = Icons.home_work_outlined;
      iconColor = boardingColor;
      typeSuffix = '(Boarding)';
    }

    // Override styling for employees
    if (profile.isEmployee) {
      icon = Icons.work_outline;
      iconColor = employeeColor;
      typeSuffix = '(${profile.role})';
    }

    // Construct the display name
    final displayShopName = "${profile.shopName} ${profile.isEmployee ? '' : typeSuffix}";


    return Card(
      elevation: 4,
      shadowColor: iconColor.withOpacity(0.1), // Use dynamic color for shadow
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          print("✅ Tapped on profile: ${profile.shopName}");
          notifier.setSelectedUser(profile);
          print("🔄 State updated.");

          if (mounted) {
            // 🚀 Check the profile type or Firestore collection name
            if (profile.serviceType.contains('Store')) {
              // If it's a Pet Store, go to the Pet Profile route
              context.go('/partner/pet-store/${profile.serviceId}/profile');
              print("🧡 Navigated to Pet Store Profile: /partner/pet-store/${profile.serviceId}/profile");
            } else {
              // Otherwise, go to the standard partner profile route
              context.go('/partner/${profile.serviceId}/profile');
              print("💚 Navigated to Boarding Profile: /partner/${profile.serviceId}/profile");
            }
          } else {
            print("❌ Widget not mounted. Navigation cancelled.");
          }
        },

        borderRadius: BorderRadius.circular(16),
        hoverColor: iconColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Dynamic Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display Shop Name with Type Suffix
                    Text(
                      displayShopName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.areaName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Display Role (Owner/Staff) and Type Suffix for Employees
                    Text(
                      '${profile.role} ${profile.isEmployee ? typeSuffix : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddShopCard(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      child: InkWell(
        onTap: () => context.go('/business-type'),
        borderRadius: BorderRadius.circular(16),
        hoverColor: accentColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_business_outlined, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Register a New Business',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
