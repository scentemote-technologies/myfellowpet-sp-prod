// lib/screens/OtherBranchesPage.dart
import "dart:html" as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';
import 'package:shimmer/shimmer.dart';

import '../../Colors/AppColor.dart';
import '../../providers/boarding_details_loader.dart';
import 'boarding_type.dart'; // You will need to add this package

// --- Brand Colors ---

const Color backgroundColor = Color(0xFFF7FAFC);
const Color cardColor = Colors.white;
const Color textColor = Color(0xFF2D3748);
const Color subtleTextColor = Color(0xFF718096);

class OtherBranchesPage extends StatefulWidget {
  final String ownerId;
  final String serviceId;

  const OtherBranchesPage({super.key, required this.ownerId, required this.serviceId});

  @override
  State<OtherBranchesPage> createState() => _OtherBranchesPageState();
}

class _OtherBranchesPageState extends State<OtherBranchesPage> {
  List<Map<String, dynamic>> branches = [];
  bool isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    fetchOtherBranches();
  }

  Future<void> fetchOtherBranches() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();
        final List<dynamic> branchIds = data?['other_branches'] ?? [];
        final List<Map<String, dynamic>> fetchedBranches = [];

        // ✅ Add current branch first
        fetchedBranches.add({
          'id': widget.serviceId,
          'shop_name': data?['shop_name'] ?? 'Unnamed Shop',
          'area_name': data?['area_name'] ?? 'N/A',
          'adminApproved': data?['adminApproved'] ?? false,
          'shop_logo': data?['shop_logo'] ?? '',
          'isCurrent': true, // 👈 marker
        });

        for (final branchId in branchIds) {
          final branchDoc = await FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(branchId)
              .get();

          if (branchDoc.exists) {
            final branchData = branchDoc.data();
            fetchedBranches.add({
              'id': branchId,
              'shop_name': branchData?['shop_name'] ?? 'Unnamed Shop',
              'area_name': branchData?['area_name'] ?? 'N/A',
              'adminApproved': branchData?['adminApproved'] ?? false,
              'shop_logo': branchData?['shop_logo'] ?? '',
            });
          }
        }
        setState(() => branches = fetchedBranches);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load branches. Please try again.');
      }
      print('Error fetching other branches: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 🚀 Replacing context.go('/business-type/${widget.serviceId}')
          // Navigate and replace the current screen, as this starts a new flow.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RunTypeSelectionPage(
                
                uid: FirebaseAuth.instance.currentUser!.uid,
                phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',
                email: FirebaseAuth.instance.currentUser!.email ?? '',
                serviceId: widget.serviceId, fromOtherbranches: true, // Pass the existing serviceId
              ),
            ),
          );
        },
        label: Text('Add New Branch', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 8.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 150.0,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Our Branches',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, Color(0xFF1A7F81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const _ShimmerLoadingState();
    }
    if (_errorMessage != null) {
      return SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.error_outline,
          message: _errorMessage!,
          color: Colors.red.shade400,
        ),
      );
    }
    if (branches.isEmpty) {
      return const SliverFillRemaining(
        child: _EmptyState(
          icon: Icons.store_mall_directory_outlined,
          message: 'No other branches found.\nAdd your first one to get started!',
        ),
      );
    }

    // Using GridView for a responsive layout
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400.0, // Max width for each card
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 2.5, // Adjust for card proportions
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            return _BranchCard(
              branch: branches[index],
              onTap: () {
                // 1. Get the target service ID
                final targetServiceId = branches[index]['id'];

                // 2. 🚀 Replace redundant context.go() and manual URL manipulation
                // with a single Navigator.pushReplacement.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (ctx) => PartnerShell(
                      serviceId: targetServiceId,
                      // We are navigating to the main profile/overview page of the new branch
                      currentPage: PartnerPage.profile,
                      child: BoardingDetailsLoader(serviceId: targetServiceId),
                    ),
                  ),
                );
              },
            );
          },
          childCount: branches.length,
        ),
      ),
    );
  }
}

class _BranchCard extends StatefulWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onTap;

  const _BranchCard({required this.branch, required this.onTap});

  @override
  State<_BranchCard> createState() => _BranchCardState();
}

class _BranchCardState extends State<_BranchCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final approved = widget.branch['adminApproved'] == true;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _isHovering ? primaryColor.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: _isHovering ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isHovering ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            // ✅ Disable tap if it's the current branch
            onTap: widget.branch['isCurrent'] == true ? null : widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.branch['shop_logo'] != ''
                            ? Image.network(
                          widget.branch['shop_logo'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
                        )
                            : _buildLogoPlaceholder(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.branch['shop_name'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Area: ${widget.branch['area_name']}',
                              style: GoogleFonts.poppins(
                                color: subtleTextColor,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (approved ? Colors.green : Colors.orange)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                approved ? 'Approved' : 'Pending',
                                style: GoogleFonts.poppins(
                                  color: approved
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Current Branch Badge
                if (widget.branch['isCurrent'] == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor, // 0xFFF67B0D
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Current',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      child: Icon(Icons.storefront_outlined, size: 40, color: Colors.grey.shade400),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const _EmptyState({required this.icon, required this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: color ?? Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 18, color: subtleTextColor),
          ),
        ],
      ),
    );
  }
}

class _ShimmerLoadingState extends StatelessWidget {
  const _ShimmerLoadingState();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400.0,
          mainAxisSpacing: 16.0,
          crossAxisSpacing: 16.0,
          childAspectRatio: 2.5,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
          childCount: 6,
        ),
      ),
    );
  }
}