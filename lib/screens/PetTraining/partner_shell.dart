import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../Boarding/roles/role_service.dart';

const Color primary = Color(0xFF2CB4B6);
const double sidebarWidth = 300.0;
const double kDesktopBreakpoint = 1000.0;

class PetTrainingPartnerShell extends StatelessWidget {
  final String serviceId;
  final String? currentLocation;
  final Widget child;
  final Widget? phonePreview;

  const PetTrainingPartnerShell({
    Key? key,
    required this.serviceId,
    required this.currentLocation,
    required this.child,
    this.phonePreview,
  }) : super(key: key);

  static const _menuItems = [
    {'label': 'Overview', 'icon': Icons.dashboard, 'path': 'profile'},
    {'label': 'Training Requests', 'icon': Icons.directions_walk, 'path': 'Training-requests'},
  ];

  String _getCurrentTitle(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final base = '/partner/pet-training/$serviceId';
    for (final item in _menuItems) {
      final target = '$base/${item['path']}';
      if (location.startsWith(target)) return item['label'] as String;
    }
    return 'Partner Panel';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kDesktopBreakpoint;

        // REPLACE IT WITH THIS
        if (isWide) {
          // DESKTOP / WIDE LAYOUT

          // Calculate the available width for the main content area
          double mainContentWidth = constraints.maxWidth - sidebarWidth - 1; // 1 for the divider
          if (phonePreview != null) {
            mainContentWidth -= 400; // Subtract phone preview width if it exists
          }

          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: sidebarWidth,
                  color: Colors.white,
                  child: _SidebarContent(
                    serviceId: serviceId,
                    onSignOut: () => _confirmAndSignOut(context),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Use a SizedBox with the calculated width instead of the problematic Expanded
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
              title: Text(
                _getCurrentTitle(context),
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
    context.go('/');
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
  final VoidCallback onSignOut;

  const _SidebarContent({
    Key? key,
    required this.serviceId,
    required this.onSignOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final base = '/partner/pet-training/$serviceId';
    final location = GoRouterState.of(context).uri.toString();
    final me = context.watch<UserNotifier>().me;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: PetTrainingPartnerShell._menuItems.length,
            itemBuilder: (ctx, i) {
              final item = PetTrainingPartnerShell._menuItems[i];
              final target = '$base/${item['path']}';
              final selected = location.startsWith(target);
              return Material(
                color: selected ? primary.withOpacity(0.9) : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();
                    context.go(target);
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
                        '${me.name}',
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
                    'User ID: ${(me.uid.length) > 15 ? '${(me.uid).substring(0, 15)}...' : (me.uid ?? '')}', // Added prefix "User ID: "
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
                    // Copy the UID to the clipboard
                    Clipboard.setData(ClipboardData(text: me.uid ?? ''))
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