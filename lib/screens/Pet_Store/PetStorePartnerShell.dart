import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:go_router/go_router.dart'; // <<< REMOVED
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../Boarding/partner_shell.dart';
import '../Boarding/roles/role_service.dart';
// Assuming PartnerPage enum is imported from here or another shared file
import '../Pet_Store/pet_store_details_loader.dart'; // REQUIRED IMPORT
import '../Pet_Store/store stuff/inventory.dart'; // REQUIRED IMPORT
import '../Partner/email_signin.dart'; // REQUIRED IMPORT (for sign out target)


const Color primary = Color(0xFF2CB4B6);
const double sidebarWidth = 300.0;
const double kDesktopBreakpoint = 1000.0;

// --- NEW MENU ITEM DEFINITION using the existing PartnerPage Enum ---
const _petStoreMenuItems = [
  {'label': 'Overview', 'icon': Icons.dashboard, 'page': PartnerPage.profile},
  {'label': 'Inventory', 'icon': Icons.inventory_2_outlined, 'page': PartnerPage.other}, // Using 'other' for simplicity
];
// -------------------------------------------------------------------


class PetStorePartnerShell extends StatelessWidget {
  final String serviceId;
  // REMOVED: final String? currentLocation;
  final PartnerPage currentPage; // <<< NEW PROPERTY
  final Widget child;
  final Widget? phonePreview;

  const PetStorePartnerShell({
    Key? key,
    required this.serviceId,
    // REMOVED: required this.currentLocation,
    required this.currentPage, // <<< REQUIRED
    required this.child,
    this.phonePreview,
  }) : super(key: key);

  // UPDATED: Now uses currentPage enum for title
  String _getCurrentTitle() {
    for (final item in _petStoreMenuItems) {
      if (item['page'] == currentPage) return item['label'] as String;
    }
    return 'Partner Panel';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kDesktopBreakpoint;

        if (isWide) {
          double mainContentWidth = constraints.maxWidth - sidebarWidth - 1;
          if (phonePreview != null) {
            mainContentWidth -= 400;
          }

          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: sidebarWidth,
                  color: Colors.white,
                  child: _SidebarContent(
                    serviceId: serviceId,
                    currentPage: currentPage, // <<< PASS NEW PROPERTY
                    onSignOut: () => _confirmAndSignOut(context),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: mainContentWidth,
                  child: child,
                ),
                if (phonePreview != null)
                  Container(
                    width: 400,
                    color: Colors.grey.shade100,
                    child: phonePreview,
                  ),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              // UPDATED: Use the new title method
              title: Text(
                _getCurrentTitle(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              actions: [
                if (phonePreview != null)
                  IconButton(
                    icon: const Icon(Icons.phone_iphone_outlined),
                    onPressed: () => _showPhonePreviewDialog(context),
                  ),
              ],
            ),
            drawer: Drawer(
              width: sidebarWidth,
              child: _SidebarContent(
                serviceId: serviceId,
                currentPage: currentPage, // <<< PASS NEW PROPERTY
                onSignOut: () {
                  Navigator.of(context).pop();
                  _confirmAndSignOut(context);
                },
              ),
            ),
            body: child,
          );
        }
      },
    );
  }
  Future<void> _confirmAndSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldSignOut) return;

    await FirebaseAuth.instance.signOut();

    // 🚀 REPLACED context.go('/') with standard pushAndRemoveUntil
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => SignInPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showPhonePreviewDialog(BuildContext context) {
    if (phonePreview == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 350,
          height: 700,
          padding: const EdgeInsets.all(8),
          child: phonePreview,
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final String serviceId;
  final PartnerPage currentPage; // <<< NEW PROPERTY
  final VoidCallback onSignOut;

  const _SidebarContent({
    Key? key,
    required this.serviceId,
    required this.currentPage, // <<< REQUIRED
    required this.onSignOut,
  }) : super(key: key);

  // --- HELPER FUNCTION TO GET THE WIDGET FOR NAVIGATION ---
  Widget _getPetStoreChildWidget(PartnerPage page, String sid) {
    switch (page) {
      case PartnerPage.profile:
        return PetStoreDetailsLoader(serviceId: sid);
      case PartnerPage.other: // This is where Inventory is mapped
        return InventoryPage(serviceId: sid);
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // REMOVED: final base = '/partner/pet-store/$serviceId';
    // REMOVED: final location = GoRouterState.of(context).uri.toString();
    final me = context.watch<UserNotifier>().me;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ... (Header remains the same)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/mfplogo.jpg', height: 50, width: 50),
              const SizedBox(width: 8),
              Text(
                'Partner Panel',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade300),

        // --- MENU LIST ---
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _petStoreMenuItems.length,
            itemBuilder: (ctx, i) {
              final item = _petStoreMenuItems[i];
              final targetPage = item['page'] as PartnerPage;

              // UPDATED: Use currentPage property for selection
              final selected = currentPage == targetPage;

              return Material(
                color: selected ? primary.withOpacity(0.9) : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();

                    // 🚀 REPLACED context.go(target) with pushReplacement
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (ctx) => PetStorePartnerShell(
                          serviceId: serviceId,
                          currentPage: targetPage,
                          child: _getPetStoreChildWidget(targetPage, serviceId),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: selected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ... (User info and Sign Out buttons remain the same,
        // using the unchanged provider logic)

        if (me != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : null,
                  child: currentUser?.photoURL == null
                      ? const Icon(Icons.person, size: 24, color: Colors.white)
                      : null,
                  backgroundColor: Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height:0),
                      Text(
                        me.role ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height:0),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (me != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150, // Width for the UID text (adjust based on your requirement)
                  child: Text(
                    'User ID: ${me.uid.length > 15 ? '${me.uid.substring(0, 15)}...' : me.uid}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis, // Ensure ellipsis if the text overflows
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.grey[600], size: 13),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: me.uid))
                        .then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User ID copied to clipboard!')),
                      );
                    });
                  },
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(24.0),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onSignOut,
          ),
        ),
      ],
    );
  }
}