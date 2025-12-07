import 'dart:convert';
import 'package:myfellowpet_sp/screens/Boarding/roles/role_service.dart';
import 'package:universal_html/html.dart' as html;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../Colors/AppColor.dart';
import '../../helper.dart';
import '../../user_app/screens/Boarding/boarding_servicedetailspage.dart';

// V V V PASTE THIS ENTIRE NEW CLASS AT THE BOTTOM OF YOUR FILE V V V

// Find the PetPricing class

class PetPricing {
  final String petName;
  final Map<String, String> ratesDaily;
  final Map<String, String> walkingRatesDaily;
  final Map<String, String> mealRatesDaily;
  final Map<String, String> offerRatesDaily;
  final Map<String, String> offerWalkingRatesDaily;
  final Map<String, String> offerMealRatesDaily;
  final Map<String, dynamic> feedingDetails;
  final List<String> acceptedSizes;   // <-- ADD THIS LINE
  final List<String> acceptedBreeds;  // <-- ADD THIS LINE


  PetPricing( {
    required this.petName,
    required this.ratesDaily,
    required this.walkingRatesDaily,
    required this.mealRatesDaily,
    required this.offerRatesDaily,
    required this.offerWalkingRatesDaily,
    required this.offerMealRatesDaily,
    required this.feedingDetails,
    required this.acceptedSizes,     // <-- ADD THIS LINE
    required this.acceptedBreeds,    // <-- ADD THIS LINE
  });
}
class BoardingDetailsPage extends StatelessWidget {
  final String serviceId;
  final String serviceName;
  final String partnerPolicyUrl; // <-- ADD THIS LINE
  final bool isAdminContractUpdateApproved; // <-- ADD THIS LINE


  final String description;

  final String walkingFee;
  final String openTime;
  final String closeTime;
  final String maxPetsAllowed;
  final String maxPetsAllowedPerHour;
  final List<String> pets;
  final String shopName;
  final String shopLogo;
  final bool adminApproved;
  final List<String> imageUrls;
  final String street;
  final String areaName;
  final String district;
  final String state;
  final String postalCode;
  final String shopLocation;
  final String notification_email;
  final String phoneNumber;
  final String whatsappNumber;
  final String fullAddress;
  final String bankIfsc;
  final Map<String, String> refundPolicy;
  final String partnerContractUrl; // <-- ADD THIS LINE

  final List<String> features; // <-- ADD THIS LINE


  final String bankAccountNum;
  final String ownerName;

  const   BoardingDetailsPage({
    Key? key,
    required this.serviceId,
    required this.serviceName,
    required this.description,

    required this.walkingFee,
    required this.openTime,
    required this.closeTime,
    required this.maxPetsAllowed,
    required this.maxPetsAllowedPerHour,
    required this.pets,
    required this.shopName,
    required this.shopLogo,
    required this.adminApproved,
    required this.imageUrls,
    required this.street,
    required this.areaName,
    required this.district,
    required this.state,
    required this.postalCode,
    required this.shopLocation,
    required this.phoneNumber,
    required this.whatsappNumber,
    required this.fullAddress,
    required this.bankIfsc,
    required this.bankAccountNum,
    required this.ownerName, required this.refundPolicy, required this.notification_email, required this.features, required this.partnerPolicyUrl, required this.isAdminContractUpdateApproved, required this.partnerContractUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return
      BoardingDetailsDashboard(
        serviceId: serviceId,
        serviceName: serviceName,
        features: features,
        description: description,
        walkingFee: walkingFee,
        openTime: openTime,
        closeTime: closeTime,
        partnerContractUrl: partnerContractUrl, // <-- PASS IT DOWN
        maxPetsAllowed: maxPetsAllowed,
        maxPetsAllowedPerHour: maxPetsAllowedPerHour,
        pets: pets,
        shopName: shopName,
        shopLogo: shopLogo,
        adminApproved: adminApproved,
        imageUrls: imageUrls,
        street: street,
        areaName: areaName,
        district: district,
        state: state,
        postalCode: postalCode,
        shopLocation: shopLocation,
        ownerEmail: notification_email,
        phoneNumber: phoneNumber,
        whatsappNumber: whatsappNumber,
        full_address: fullAddress,
        bank_ifsc: bankIfsc,
        bank_account_num: bankAccountNum,
        owner_name: ownerName,
        refundPolicy: refundPolicy,
        isAdminContractUpdateApproved: isAdminContractUpdateApproved, // <-- PASS IT DOWN

        partnerPolicyUrl: partnerPolicyUrl, // <-- PASS IT DOWN
      );
  }
}


const Color primary = Color(0xFF1E8586);
const Color accentColor = Color(0xFFF67B0D);

class BoardingDetailsDashboard extends StatefulWidget {
  final String bank_ifsc;
  final String bank_account_num;
  final String owner_name;
  final String shopName;
  final String partnerContractUrl; // <-- ADD THIS LINE

  final Map<String, String> refundPolicy;
  final String shopLogo;
  final List<String> features; // <-- ADD THIS LINE
  final bool adminApproved;
  final List<String> imageUrls;
  final String partnerPolicyUrl; // <-- ADD THIS LINE
  final bool isAdminContractUpdateApproved; // <-- ADD THIS LINE



  final String serviceName,
      serviceId,
      description,
      walkingFee;
  final List<String> pets;
  final String openTime,
      closeTime,
      maxPetsAllowed,
      maxPetsAllowedPerHour;
  final String street,
      areaName,
      district,
      state,
      postalCode,
      shopLocation;
  final String full_address;
  final String ownerEmail,
      phoneNumber,
      whatsappNumber;

  const BoardingDetailsDashboard({
    Key? key,
    required this.shopName,
    required this.adminApproved,
    required this.imageUrls,
    required this.serviceName,
    required this.serviceId,
    required this.description,
    required this.walkingFee,
    required this.openTime,
    required this.closeTime,
    required this.maxPetsAllowed,
    required this.pets,
    required this.street,
    required this.areaName,
    required this.district,
    required this.state,
    required this.postalCode,
    required this.shopLocation,
    required this.ownerEmail,
    required this.phoneNumber,
    required this.whatsappNumber,
    required this.bank_ifsc,
    required this.bank_account_num,
    required this.owner_name,
    required this.maxPetsAllowedPerHour,
    required this.shopLogo,
    required this.full_address,
    required this.refundPolicy,
    required this.features, required this.partnerPolicyUrl, required this.isAdminContractUpdateApproved, required this.partnerContractUrl,
  }) : super(key: key);

  @override
  State<BoardingDetailsDashboard> createState() =>
      _BoardingDetailsDashboardState();
}

// V V V REPLACE THE ENTIRE '_BoardingDetailsDashboardState' CLASS V V V

class _BoardingDetailsDashboardState extends State<BoardingDetailsDashboard> {
  bool _isOfferActive = false;
  bool _isLoadingOfferStatus = true;
  // --- NEW: Future to hold our pricing data ---
  late Future<List<PetPricing>> _petPricingFuture;
  late Stream<DocumentSnapshot> _announcementsStream; // <-- ADD THIS LINE
  final Set<String> _dismissedAnnouncements = {};
  late Stream<DocumentSnapshot> _contractStream; // <-- ADD THIS





  @override
  void initState() {
    super.initState();
    _fetchOfferStatus();
    // --- NEW: Initialize the future in initState ---
    _petPricingFuture = _fetchPetPricing(widget.serviceId);

    // V V V INITIALIZE THE STREAM HERE V V V
    _announcementsStream = FirebaseFirestore.instance
        .collection('settings')
        .doc('announcements')
        .snapshots();


    // V V V ADD THIS LINE TO INITIALIZE THE CONTRACT STREAM V V V
    _contractStream = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .snapshots();
  }

  // This is the download method you provided
  Future<void> _downloadContract() async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('company_documents').doc('partner_contract').get();
      final pdfUrl = docSnap.data()?['home_boarder_contract_pdf'] as String?;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract PDF not available')));
        return;
      }
      html.AnchorElement(href: pdfUrl)..setAttribute('download', 'PartnerContract.pdf')..target = '_blank'..click()..remove();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download contract: $e')));
    }
  }

  // This helper gets a clean filename from a Firebase Storage URL
  String _getFileNameFromUrl(String url) {
    if (url.isEmpty) {
      return "No file uploaded.";
    }
    try {
      final decodedUrl = Uri.decodeComponent(url);
      return decodedUrl.substring(decodedUrl.lastIndexOf('/') + 1, decodedUrl.indexOf('?'));
    } catch (e) {
      return "Uploaded Contract";
    }
  }

  // --- NEW: Function to fetch pricing from the subcollection ---
  // In _BoardingDetailsDashboardState

// 🔽🔽🔽 REPLACE your _fetchPetPricing method with this 🔽🔽🔽
  Future<List<PetPricing>> _fetchPetPricing(String serviceId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('pet_information')
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return PetPricing(
        petName: doc.id,
        ratesDaily: Map<String, String>.from(data['rates_daily'] ?? {}),
        walkingRatesDaily: Map<String, String>.from(data['walking_rates'] ?? {}),
        mealRatesDaily: Map<String, String>.from(data['meal_rates'] ?? {}),
        offerRatesDaily: Map<String, String>.from(data['offer_daily_rates'] ?? {}),
        offerWalkingRatesDaily: Map<String, String>.from(data['offer_walking_rates'] ?? {}),
        offerMealRatesDaily: Map<String, String>.from(data['offer_meal_rates'] ?? {}),
        feedingDetails: Map<String, dynamic>.from(data['feeding_details'] ?? {}),
        // --- This is the new part that loads the varieties data ---
        acceptedSizes: List<String>.from(data['accepted_sizes'] ?? []),
        acceptedBreeds: List<String>.from(data['accepted_breeds'] ?? []),
      );
    }).toList();
  }

  // In _BoardingDetailsDashboardState

// V V V ADD THESE TWO METHODS V V V

// 1. This is the main widget that fetches and filters the announcements in real-time.
  // In _BoardingDetailsDashboardState

// REPLACE this entire method
  Widget _buildLiveAnnouncements() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];
        final now = DateTime.now();

        final validAnnouncements = items
            .map((item) => Announcement.fromMap(item as Map<String, dynamic>))
            .where((ann) {
          final isVisible = ann.visibleTo.contains('all') || ann.visibleTo.contains('partners');
          final isDateActive = (now.isAfter(ann.startDate) || now.isAtSameMomentAs(ann.startDate)) &&
              (now.isBefore(ann.endDate) || now.isAtSameMomentAs(ann.endDate));
          return ann.active && isVisible && isDateActive;
        }).toList();
        // V V V THIS IS THE NEW FILTERING LOGIC V V V
        final announcementsToShow = validAnnouncements
            .where((ann) => !_dismissedAnnouncements.contains(ann.heading))
            .toList();
        // ^ ^ ^ END OF NEW LOGIC ^ ^ ^

        if (announcementsToShow.isEmpty) { // <-- UPDATE THIS LINE
          return const SizedBox.shrink();
        }

        // The main container is now a Column with padding to hold the separate boxes.
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: announcementsToShow
                .map((ann) => _buildAnnouncementItem(
              ann,
              // This is the function that will be called when 'X' is pressed
              onDismiss: () {
                setState(() {
                  _dismissedAnnouncements.add(ann.heading);
                });
              },
            ))
                .toList(),
          ),
        );
      },
    );
  }
// 2. This helper widget styles a single announcement item.
  // In _BoardingDetailsDashboardState

// REPLACE this entire method
  // In _BoardingDetailsDashboardState

// REPLACE this entire method
  Widget _buildAnnouncementItem(Announcement announcement, {required VoidCallback onDismiss}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12, right: 8), // Adjust right padding for the button
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        border: Border.all(color: primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getAnnouncementIcon(announcement.heading.split(' ').first.toLowerCase()), color: primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              textAlign: TextAlign.start,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: primary,
                ),
                children: [
                  TextSpan(
                    text: '${announcement.heading}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: announcement.message,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          // V V V THIS IS THE NEW DISMISS BUTTON V V V
          InkWell(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                Icons.close,
                size: 18,
                color: primary.withOpacity(0.7),
              ),
            ),
          ),
          // ^ ^ ^ END OF NEW BUTTON ^ ^ ^
        ],
      ),
    );
  }

  // lib/screens/boarding_details_dashboard.dart -> inside _BoardingDetailsDashboardState

  Widget _buildPolicySection() {
    // If the URL is empty or null, don't build this section at all.
    if (widget.partnerPolicyUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildInfoSection(
      'Business Policies',
      [


        ListTile(
          leading: const Icon(Icons.policy_outlined, color: primaryColor, size: 28),
          title: Text(
            'View Terms & Conditions',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          subtitle: Text(
            'Service Provider\'s policy document',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
          ),
          trailing: const Icon(Icons.launch, color: Colors.grey),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          onTap: () {
            // This is the action that opens the URL in a new tab
            html.window.open(widget.partnerPolicyUrl, '_blank');
          },
        ),
      ],
    );
  }

  // In _BoardingDetailsDashboardState

// 🔽🔽🔽 ADD THIS ENTIRE NEW WIDGET 🔽🔽🔽
  Widget _buildVarietiesInfo(List<String> sizes, List<String> breeds) {
    // A helper to create the styled chips
    Widget buildChip(String label, Color color) {
      return Chip(
        label: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: color)),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Accepted Sizes Section
        if (sizes.isNotEmpty) ...[
          Text(
            'Accepted Sizes',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: sizes.map((size) => buildChip(size, primaryColor)).toList(),
          ),
        ],

        // Divider if both sections are present
        if (sizes.isNotEmpty && breeds.isNotEmpty)
          const Divider(height: 32),

        // Accepted Breeds Section
        if (breeds.isNotEmpty) ...[
          Text(
            'Accepted Breeds',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: breeds.map((breed) => buildChip(breed, accentColor)).toList(),
          ),
        ] else ...[
          // If breeds are empty, explicitly state that all are accepted
          Center(child: Text("All breeds are accepted for the selected sizes.", style: GoogleFonts.poppins(color: Colors.grey, fontStyle: FontStyle.italic)))
        ],

        // Case where no varieties are specified at all
        if (sizes.isEmpty)
          Center(child: Text("No specific varieties listed.", style: GoogleFonts.poppins(color: Colors.grey, fontStyle: FontStyle.italic))),
      ],
    );
  }




  // In _BoardingDetailsDashboardState

// V V V PASTE THESE TWO NEW METHODS INTO YOUR STATE CLASS V V V

// This method contains the logic for picking and uploading the new contract.
  Future<void> _handleContractUpload() async {
    // 1. Pick the PDF file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading contract... Please wait.')),
    );

    try {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      // 2. Create a reference in Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('Boarders_Partner_Contract')
          .child('${widget.serviceId}_$fileName'); // Naming it with service ID for easy tracking

      // 3. Upload the file
      final uploadTask = await ref.putData(fileBytes, SettableMetadata(contentType: 'application/pdf'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 4. Update the Firestore document with the new URL
      await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .update({'partner_contract_url': downloadUrl});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New contract uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // You might want to refresh the page or update state here if needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// This widget builds the UI for the contract link and conditional upload button.
  // In _BoardingDetailsDashboardState

  // In _BoardingDetailsDashboardState

// ❌ DELETE your old _buildContractSection method and
// ✅ REPLACE it with this one.
  // In _BoardingDetailsDashboardState

// REPLACE this entire method
  Widget _buildContractSection({
    required BuildContext context, // Pass context for the dialog
    required String contractUrl,
    required bool isUpdateApproved,
  }) {
    final bool hasContract = contractUrl.isNotEmpty;
    final String pdfName = hasContract
        ? _getFileNameFromUrl(contractUrl)
        : 'No contract uploaded';

    return _buildInfoSection(
      'Partner Contract',
      [
        ListTile(
          leading: Icon(
            hasContract ? Icons.description_outlined : Icons.upload_file_outlined,
            color: accentColor,
            size: 28,
          ),
          title: Text(
            'Signed Contract',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          subtitle: Text(
            pdfName,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: hasContract ? Colors.black54 : Colors.grey.shade600),
            overflow: TextOverflow.ellipsis, // Prevents long filenames from wrapping
          ),
          // Use LayoutBuilder to decide which widget to show based on available width
          trailing: isUpdateApproved
              ? LayoutBuilder(
            builder: (context, constraints) {
              // A breakpoint for when to switch to the menu.
              // Adjust this value if needed.
              if (constraints.maxWidth < 150) {
                // NARROW SCREEN LAYOUT (e.g., phone)
                return _buildMobileActions(context);
              } else {
                // WIDE SCREEN LAYOUT (e.g., tablet/desktop)
                return _buildDesktopActions(context);
              }
            },
          )
              : (hasContract ? const Icon(Icons.launch, color: Colors.grey) : null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          onTap: hasContract && !isUpdateApproved // Only allow tap if not in edit mode
              ? () => html.window.open(contractUrl, '_blank')
              : null,
        ),
      ],
    );
  }

// 2. ADD this new helper method for the WIDE screen layout
  Widget _buildDesktopActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Download Contract Template',
          child: IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            color: Colors.blueGrey,
            onPressed: _downloadContract,
          ),
        ),
        Tooltip(
          message: 'View Instructions',
          child: IconButton(
            icon: const Icon(Icons.info_outline),
            color: Colors.blueAccent,
            onPressed: () => _showContractInstructionsDialog(context),
          ),
        ),
        Tooltip(
          message: 'Upload New Signed Contract',
          child: IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            color: primaryColor,
            onPressed: _handleContractUpload,
          ),
        ),
      ],
    );
  }

// 3. ADD this new helper method for the NARROW screen layout
  Widget _buildMobileActions(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        // Handle the action based on the value passed from PopupMenuItem
        switch (value) {
          case 'download':
            _downloadContract();
            break;
          case 'instructions':
            _showContractInstructionsDialog(context);
            break;
          case 'upload':
            _handleContractUpload();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'download',
          child: ListTile(
            leading: Icon(Icons.download_for_offline_outlined, color: Colors.blueGrey),
            title: Text('Download Template'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'instructions',
          child: ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blueAccent),
            title: Text('View Instructions'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'upload',
          child: ListTile(
            leading: Icon(Icons.cloud_upload_outlined, color: primaryColor),
            title: Text('Upload Signed PDF'),
          ),
        ),
      ],
    );
  }


  // In _BoardingDetailsDashboardState

// V V V ADD THIS NEW WIDGET V V V
  Widget _buildLiveContractSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _contractStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return _buildInfoSection('Partner Contract', [Text('Error: ${snapshot.error}')]);
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildInfoSection('Partner Contract', [const Text('Contract information not found.')]);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final url = data['partner_contract_url'] as String? ?? '';
        final isApproved = (data['admin_contract_pdf_update_approve'] as bool?) ?? false;

        return _buildContractSection(context: context ,
          contractUrl: url,
          isUpdateApproved: isApproved,
        );
      },
    );
  }


  // ADD THESE TWO NEW METHODS
  Widget _buildFeedingInfo(Map<String, dynamic> feedingDetails) {
    if (feedingDetails.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No feeding information provided.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        ),
      );
    }

    String getLabel(String fieldName) {
      if (fieldName == 'food_title') return 'Meal Name';
      return StringExtension(fieldName.replaceAll('_', ' ')).capitalize();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: feedingDetails.entries.map((mealEntry) {
        final mealTitle = mealEntry.key;
        final mealData = mealEntry.value as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mealTitle,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const Divider(height: 12),
              ...mealData.entries.map((detailEntry) {
                final fieldName = detailEntry.key;
                final value = detailEntry.value;

                if (value == null || (value is String && value.isEmpty) || (value is List && value.isEmpty)) {
                  return const SizedBox.shrink();
                }

                if (fieldName == 'image' && value is String && value.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: value,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  );
                }

                final label = getLabel(fieldName);
                final displayValue = (value is List) ? value.join(' • ') : value.toString();

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$label: ",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, color: Colors.black87)),
                      Expanded(
                          child: Text(displayValue,
                              style: GoogleFonts.poppins(color: Colors.black54))),
                    ],
                  ),
                );
              })
            ],
          ),
        );
      }).toList(),
    );
  }



  // COPY THIS ENTIRE WIDGET
  Widget _buildAllPetPricingSection() {
    return FutureBuilder<List<PetPricing>>(
      future: _petPricingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading pricing: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildInfoSection('Pet Pricing', [
            Center(
              child: Text(
                'No specific pricing information found.',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
              ),
            )
          ]);
        }
        final petPricings = snapshot.data!;
        return _buildInfoSection(
          'Pet-Specific Pricing',
          petPricings.map((pricing) => _buildPetPricingCard(pricing)).toList(),
        );
      },
    );
  }

  // --- NEW: Helper to get a nice icon for each pet ---
  IconData _getPetIcon(String petName) {
    switch (petName.toLowerCase()) {
      case 'dog':
        return Icons.pets; // Standard dog icon
      case 'cat':
      // You might need a custom icon pack for a specific cat icon, using a paw as a fallback
        return Icons.pets; // Using pets icon as a placeholder
      default:
        return Icons.star_outline; // Generic icon for other pets
    }
  }



// --- REFINED: A more professional and branded card for a single pet's pricing ---
  // REPLACE your _buildPetPricingCard with this
  // In _BoardingDetailsDashboardState

// 🔽🔽🔽 REPLACE your _buildPetPricingCard widget with this 🔽🔽🔽
  Widget _buildPetPricingCard(PetPricing pricing) {
    final displayName = pricing.petName[0].toUpperCase() + pricing.petName.substring(1);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: primaryColor.withOpacity(0.05),
        collapsedBackgroundColor: Colors.white,
        iconColor: primaryColor,
        collapsedIconColor: primaryColor,
        leading: Icon(_getPetIcon(pricing.petName), color: primaryColor, size: 28),
        title: Text(
          displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        children: [
          DefaultTabController(
            length: 4, // Changed to 4 tabs
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true, // Makes tabs scrollable on small screens
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryColor,
                  tabs: [
                    Tab(text: "Varieties"), // <-- NEW TAB
                    Tab(text: "Standard"),
                    Tab(text: "Offers"),
                    Tab(text: "Feeding Info"),
                  ],
                ),
                SizedBox(
                  height: 250,
                  child: TabBarView(
                    children: [
                      // --- This is the new view for our tab ---
                      _buildVarietiesInfo(pricing.acceptedSizes, pricing.acceptedBreeds),

                      // --- Existing views ---
                      ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildPriceGroup('Boarding', pricing.ratesDaily),
                            _buildPriceGroup('Walking', pricing.walkingRatesDaily),
                            _buildPriceGroup('Meals', pricing.mealRatesDaily),
                          ]
                      ),
                      ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildPriceGroup('Boarding', pricing.offerRatesDaily),
                            _buildPriceGroup('Walking', pricing.offerWalkingRatesDaily),
                            _buildPriceGroup('Meals', pricing.offerMealRatesDaily),
                          ]
                      ),
                      _buildFeedingInfo(pricing.feedingDetails),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ... (All your other existing functions like _showImageDialog, _fetchOfferStatus, etc. remain here)
  // ... (PASTE ALL YOUR OTHER FUNCTIONS FROM THE PREVIOUS CODE HERE)
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16), // Responsive padding
          child: GestureDetector(
            // Let the user tap the background to close
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer( // Allows pinch-to-zoom and panning
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain, // Ensures the whole image is visible
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  // V V V PASTE THIS ENTIRE NEW WIDGET METHOD V V V
  Widget _buildFeaturesSection() {
    // If there are no features, don't show the section at all.
    if (widget.features.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildInfoSection(
      'Features & Amenities', // The section title
      widget.features.map((feature) {
        // Create a row for each feature to act as a bullet point item
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(
                  Icons.check_circle,
                  color: primaryColor, // Using your orange accent color for the bullet
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _fetchOfferStatus() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _isOfferActive = doc.data()!['isOfferActive'] ?? false;
        });
      }
    } catch (e) {
      print("Error fetching offer status: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingOfferStatus = false);
      }
    }
  }

  // --- UPDATED: Helper function to show the status info dialog ---
  void _showStatusInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isApproved = widget.adminApproved;
        final Color statusColor = isApproved ? primaryColor : accentColor;
        final IconData statusIcon = isApproved ? Icons.verified_user_outlined : Icons.hourglass_top_outlined;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  isApproved ? 'Profile Verified' : 'Pending Review',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ),
          content: Text(
            isApproved
                ? 'Your profile has been verified by our team. It is now live and visible to pet parents on the app.'
                : 'Your profile is currently under review by our team. It will not be visible to pet parents until it is approved. This usually takes 24-48 hours.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- UPDATED: Helper widget for the status indicator icon ---
  Widget _buildStatusIndicator(BuildContext context) {
    final bool isApproved = widget.adminApproved;
    return Tooltip(
      message: isApproved ? 'Verified' : 'Pending Review',
      child: InkWell(
        onTap: () => _showStatusInfoDialog(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            isApproved ? Icons.verified_user : Icons.hourglass_top,
            color: isApproved ? Colors.green : accentColor,
            size: 28,
          ),
        ),
      ),
    );
  }

  Future<void> _updateOfferStatus(bool newValue) async {
    setState(() => _isOfferActive = newValue);
    try {
      await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .update({'isOfferActive': newValue});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              newValue ? 'Offers have been activated.' : 'Offers have been deactivated.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update offer status: $e',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) {
        setState(() => _isOfferActive = !newValue);
      }
    }
  }

  // 🔽🔽🔽 REPLACE the old signature with this
  Widget _buildBankDetailsSectionUI({
    required String accountHolderName,
    required String bankAccountNum,
    required String bankIfsc,
    required bool isPending, // <-- NEW PARAMETER
  }) {
    // 🔽🔽🔽 REPLACE this line:
    // final hasBankDetails = widget.bank_account_num.isNotEmpty && widget.bank_ifsc.isNotEmpty;
    // With this line:
    final hasBankDetails = bankAccountNum.isNotEmpty && bankIfsc.isNotEmpty;

    // 🔽🔽🔽 ADD THIS ENTIRE 'if (isPending)' BLOCK
    // This shows the "Pending" message and hides the buttons
    if (isPending) {
      return _buildInfoSection(
        'Bank Details for Payouts',
        [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your bank details are under review. This may take 1-2 business days.',
                    style: GoogleFonts.poppins(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Show the *currently active* details (read-only)
          if (hasBankDetails) ...[
            _buildDetailRow('Active Account Holder', accountHolderName),
            _buildDetailRow('Active Account Number', bankAccountNum),
            _buildDetailRow('Active IFSC Code', bankIfsc),
          ],
        ],
      );
    }
    // 🔽🔽🔽 END OF NEW BLOCK

    // The rest of the method stays the same, just make sure
    // it uses the new parameters, NOT 'widget.'

    return _buildInfoSection(
      'Bank Details for Payouts',
      [
        if (hasBankDetails) ...[
          // 🔽🔽🔽 Use the new parameters
          _buildDetailRow('Account Holder Name', accountHolderName),
          _buildDetailRow('Account Number', bankAccountNum),
          _buildDetailRow('IFSC Code', bankIfsc),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              // This is now disabled by the 'isPending' check above
              _showEditBankDetailsDialog();
            },
            icon: const Icon(Icons.edit, size: 18, color: Colors.white),
            label: const Text('Edit Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ] else ...[
          // This part for 'Add Bank Details' remains unchanged
          const Text('No bank details added yet.'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              _showAddBankDetailsDialog();
            },
            icon: const Icon(Icons.account_balance, size: 18, color: Colors.white),
            label: const Text('Add Bank Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  void _showAddBankDetailsDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    final TextEditingController ifscController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Bank Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Account Holder Name'),
            ),
            TextField(
              controller: accountController,
              decoration: const InputDecoration(labelText: 'Account Number'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: ifscController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'IFSC Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // In _showAddBankDetailsDialog, find the "Save" ElevatedButton...
          // In _showAddBankDetailsDialog...
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final acc = accountController.text.trim();
              final ifsc = ifscController.text.trim().toUpperCase();

              if (name.isEmpty || acc.isEmpty || ifsc.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              // Close the dialog FIRST
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Submitting request for review...')),
              );

              try {
                // 1. Get references
                final mainDocRef = FirebaseFirestore.instance
                    .collection('users-sp-boarding')
                    .doc(widget.serviceId);

                // Get the subcollection ref AND its unique ID
                final requestSubcollectionRef = mainDocRef
                    .collection('bank_details_edit_request')
                    .doc(); // Creates a new doc ref with a unique ID

                // 2. Define the data for the new request document
                final requestData = {
                  'pending_name': name,
                  'pending_account_num': acc,
                  'pending_ifsc': ifsc,
                  'status': 'pending',
                  'requested_at': FieldValue.serverTimestamp(),
                  'provider_email': widget.ownerEmail,
                  'provider_phone': widget.phoneNumber,
                };

                // 3. V V V NEW V V V
                // Define the data for the 'last_bank_edit' map
                final lastEditData = {
                  'marked_as_done': false,
                  'request_id': requestSubcollectionRef.id, // This is the new doc ID
                  'ts': FieldValue.serverTimestamp(),
                };
                // ^ ^ ^ END OF NEW ^ ^ ^


                // 4. Use a WriteBatch to do all updates at once
                final batch = FirebaseFirestore.instance.batch();

                // 4a. Create the new request document in the subcollection
                batch.set(requestSubcollectionRef, requestData);

                // 4b. Update the main document
                batch.update(mainDocRef, {
                  'bank_details_pending_review': true,
                  'last_bank_edit': lastEditData // <-- HERE IS YOUR NEW MAP
                });

                // 5. Commit the batch
                await batch.commit();

                // 6. Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Request submitted for admin review.'),
                    backgroundColor: Colors.green,
                  ),
                );

              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to submit request: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2CB4B6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],

      ),
    );
  }


  void _showEditBankDetailsDialog() {
    _showAddBankDetailsDialog(); // You can customize later if you want different behavior
  }



  Future<Map<String, dynamic>> fetchRatingStats(String serviceId) async {
    final coll = FirebaseFirestore.instance
        .collection('public_review')
        .doc('service_providers')
        .collection('sps')
        .doc(serviceId)
        .collection('reviews');

    final snap = await coll.get();
    final ratings = snap.docs
        .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
        .where((r) => r > 0)
        .toList();

    final count = ratings.length;
    final avg = count > 0 ? ratings.reduce((a, b) => a + b) / count : 0.0;

    return {'avg': avg.clamp(0.0, 5.0), 'count': count};
  }

  // In _BoardingDetailsDashboardState

  IconData _getAnnouncementIcon(String type) {
    switch (type) {
      case 'update':
        return Icons.campaign_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'promo':
        return Icons.sell_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildLiveAnnouncements(), // <-- ADD THIS LINE HER
          _buildHeader(context),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 950;
                if (isWide) {
                  return _buildWideLayout();
                } else {
                  return _buildNarrowLayout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  // Add this method to your _BoardingDetailsDashboardState class
  // V V V PASTE THIS ENTIRE NEW WIDGET V V V
  // V V V PASTE THIS ENTIRE NEW WIDGET V V V
  Widget _buildLiveBankDetailsSection() {
    return StreamBuilder<DocumentSnapshot>(
      // We reuse the _contractStream you already have!
      stream: _contractStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Build the "Add" UI if no data
          return _buildBankDetailsSectionUI(
            accountHolderName: '',
            bankAccountNum: '',
            bankIfsc: '',
            isPending: false,
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        // Get the live data from the stream
        final name = data['owner_name'] as String? ?? '';
        final accNum = data['bank_account_num'] as String? ?? '';
        final ifsc = data['bank_ifsc'] as String? ?? '';
        final isPending = (data['bank_details_pending_review'] as bool?) ?? false;

        // Call the UI widget with the live data
        return _buildBankDetailsSectionUI(
          accountHolderName: name,
          bankAccountNum: accNum,
          bankIfsc: ifsc,
          isPending: isPending,
        );
      },
    );
  }
  void _showPhonePreviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _buildPhonePreview(), // Re-uses your existing phone preview widget
        );
      },
    );
  }
  Widget _buildOfferSwitch({required bool isWide}) {
    return Row(
      children: [
        // On mobile, show a descriptive icon instead of text
        if (!isWide) ...[
          const Icon(Icons.sell_outlined, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
        ],
        // On wide screens, show the full text label
        if (isWide)
          Text(
            'Activate Offers',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
        const SizedBox(width: 8),
        // The Switch itself
        Transform.scale(
          scale: 0.8, // Make the switch a bit smaller to fit better
          child: Switch(
            value: _isOfferActive,
            onChanged: _isLoadingOfferStatus ? null : _updateOfferStatus,
            activeColor: Colors.green,
            activeTrackColor: Colors.green.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final me = context.watch<UserNotifier>().me;

    return LayoutBuilder(builder: (context, constraints) {
      const double breakpoint = 950.0;
      final bool isWide = constraints.maxWidth > breakpoint;

      if (isWide) {
        // --- WIDE / DESKTOP LAYOUT (Shows rating stars directly) ---
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Logo
              GestureDetector(
                onTap: () => _showImageDialog(context, widget.shopLogo),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.shopLogo,
                    height: 50,
                    width: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              /// Shop Name (takes remaining space)
              Expanded(
                child: Tooltip(
                  message: "${widget.shopName}", // full text on hover
                  waitDuration: Duration(milliseconds: 300),  // optional: delay before showing
                  child: Text(
                    "${widget.shopName}",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),


              /// Rating Stars
              _buildRatingStars(),

              const SizedBox(width: 24),

              /// Offer switch (only for Owner/Manager)
              if (me?.role == 'Owner' || me?.role == 'Manager')
                _buildOfferSwitch(isWide: true),

              const SizedBox(width: 24),

              /// Edit button (not for Staff)
              if (me?.role != 'Staff')
                _styledButton(
                  'Edit',
                  Icons.edit_outlined,
                  primaryColor,
                      () => context.go('/partner/${widget.serviceId}/edit'),
                ),

              const SizedBox(width: 12),

              /// Branches button (only for Owner)
              if (me?.role == 'Owner')
                _styledButton(
                  'Branches',
                  Icons.store_outlined,
                  accentColor,
                      () => context.go('/partner/${widget.serviceId}/branches'),
                ),
              const SizedBox(width: 12),
              _buildStatusIndicator(context),
            ],
          ),
        );

      } else {
        // --- CLEANER MOBILE LAYOUT (Rating stars are now hidden) ---
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Left: Logo + Shop Name
              GestureDetector(
                onTap: () => _showImageDialog(context, widget.shopLogo),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.shopLogo,
                    height: 50,
                    width: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              /// Shop Name expands to take available space
              Expanded(
                child: Text(
                  widget.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 16),

              /// Right: Actions menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'preview':
                      _showPhonePreviewDialog(context);
                      break;
                    case 'edit':
                      context.go('/partner/${widget.serviceId}/edit');
                      break;
                    case 'branches':
                      context.go('/partner/${widget.serviceId}/branches');
                      break;
                    case 'reviews':
                      _showReviewsDialog(context);
                      break;
                    case 'status':
                      _showStatusInfoDialog(context);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  return <PopupMenuEntry<String>>[
                    if (me?.role == 'Owner' || me?.role == 'Manager')
                      PopupMenuItem<String>(
                        value: 'offers',
                        enabled: false,
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter setState) {
                            return SwitchListTile(
                              title: Text('Activate Offers', style: GoogleFonts.poppins()),
                              value: _isOfferActive,
                              onChanged: (bool value) {
                                _updateOfferStatus(value);
                                setState(() {});
                              },
                              secondary: const Icon(Icons.sell_outlined),
                            );
                          },
                        ),
                      ),
                    const PopupMenuDivider(),
                    // --- TWEAK: Added status item to the menu ---
                    PopupMenuItem<String>(
                      value: 'status',
                      child: ListTile(
                        leading: Icon(
                          widget.adminApproved ? Icons.verified_user_outlined : Icons.hourglass_top_outlined,
                          color: widget.adminApproved ? Colors.green : Colors.orange,
                        ),
                        title: Text('Verification Status', style: GoogleFonts.poppins()),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'preview',
                      child: ListTile(
                        leading: const Icon(Icons.phone_iphone_outlined),
                        title: Text('Preview on App', style: GoogleFonts.poppins()),
                      ),
                    ),
                    if (me?.role != 'Staff')
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text('Edit Details', style: GoogleFonts.poppins()),
                        ),
                      ),
                    if (me?.role == 'Owner')
                      PopupMenuItem<String>(
                        value: 'branches',
                        child: ListTile(
                          leading: const Icon(Icons.store_outlined),
                          title: Text('Manage Branches', style: GoogleFonts.poppins()),
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'reviews',
                      child: ListTile(
                        leading: const Icon(Icons.reviews_outlined),
                        title: Text('View Reviews', style: GoogleFonts.poppins()),
                      ),
                    ),
                  ];
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        );

      }
    });
  }

  // Add this updated method inside your _BoardingDetailsDashboardState class
  void _showReviewsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Overall Rating", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            // Re-use your existing function to get the average and count
            child: FutureBuilder<Map<String, dynamic>>(
              future: fetchRatingStats(widget.serviceId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || (snapshot.data!['count'] as int) == 0) {
                  return Center(child: Text("No reviews yet.", style: GoogleFonts.poppins()));
                }

                final avg = snapshot.data!['avg'] as double;
                final count = snapshot.data!['count'] as int;

                // New UI to show the summary instead of a list
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      avg.toStringAsFixed(1), // e.g., "4.7"
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Star rating for the average score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < avg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Based on $count review${count == 1 ? '' : 's'}",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- MODIFIED: This layout now calls the new pricing section ---
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            // Removed padding to allow sections to control their own
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Service ID: ${widget.serviceId}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: primaryColor),
                        tooltip: 'Copy Service ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.serviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Service ID copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _buildInfoSection('Service Details', [
                  _buildDetailRow('Description', widget.description),
                  _buildDetailRow('Pets Accepted', widget.pets.join(', ')),
                  _buildDetailRow('Open Time', widget.openTime),
                  _buildDetailRow('Close Time', widget.closeTime),
                  _buildDetailRow('Max Pets/Day', widget.maxPetsAllowed),
                ]),
                const SizedBox(height: 24),
                _buildFeaturesSection(),
                const SizedBox(height: 24),

                // --- REPLACED old pricing sections with the new one ---
                _buildAllPetPricingSection(),

                const SizedBox(height: 24),
                if (widget.refundPolicy.isNotEmpty)
                  _buildInfoSection('Refund Policy', [
                    _buildRefundPolicySection(widget.refundPolicy),
                  ]),
                const SizedBox(height: 24),
                _buildInfoSection('Location', [
                  _buildDetailRow('Full Address', widget.full_address, isAddress: true),
                ]),
                const SizedBox(height: 24),
                _buildInfoSection('Gallery', [_buildPhotoGrid()]),
                const SizedBox(height: 24), // <-- ADD THIS SPACER
                _buildPolicySection(),
                const SizedBox(height: 24),
                _buildLiveBankDetailsSection(), // <-- ADD THIS LINE
                const SizedBox(height: 24), // <-- ADD THIS SPACER
                _buildLiveContractSection(),   // <-- ADD THIS LINE
// <-- ADD THIS LINE

              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.grey),
        Expanded(
          flex: 2,
          child: Center(child: _buildPhonePreview()),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> createRazorpayBeneficiary({
    required String spId,           // Firestore doc ID
    required String name,
    required String email,
    required String contact,
    required String accountNumber,
    required String ifsc,
  }) async {
    final url = Uri.parse(
      'https://us-central1-petproject-test-g.cloudfunctions.net/createContactAndFundAccount',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reference_id': spId,
          'name': name,
          'email': email,
          'contact': contact,
          'account_number': accountNumber,
          'ifsc': ifsc,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Contact created: ${data['contact_id']}');
        print('✅ Fund account created: ${data['fund_account_id']}');
        return data;
      } else {
        print('❌ Failed to create beneficiary: ${response.body}');
        return null;
      }
    } catch (e) {
      print('🔥 Error creating beneficiary: $e');
      return null;
    }
  }



  // --- MODIFIED: This layout also calls the new pricing section ---
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoSection('Service Details', [
            _buildDetailRow('Description', widget.description),
            _buildDetailRow('Pets Accepted', widget.pets.join(', ')),
            _buildDetailRow('Open Time', widget.openTime),
            _buildDetailRow('Close Time', widget.closeTime),
            _buildDetailRow('Max Pets/Day', widget.maxPetsAllowed),
          ]),
          const SizedBox(height: 24),
          _buildFeaturesSection(),
          const SizedBox(height: 24),
          // --- REPLACED old pricing sections with the new one ---
          _buildAllPetPricingSection(),

          const SizedBox(height: 24),
          if (widget.refundPolicy.isNotEmpty)
            _buildInfoSection('Refund Policy', [
              _buildRefundPolicySection(widget.refundPolicy),
            ]),
          const SizedBox(height: 24),
          _buildInfoSection('Location', [
            _buildDetailRow('Full Address', widget.full_address, isAddress: true),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Gallery', [_buildPhotoGrid()]),
          const SizedBox(height: 24), // <-- ADD THIS SPACER
          _buildPolicySection(),
          const SizedBox(height: 24), // <-- ADD THIS SPACER
          _buildLiveContractSection(),     // <-- ADD THIS LINE
// <-- ADD THIS LINE

        ],
      ),
    );
  }



  Widget _buildPhonePreview() {
    // NOTE: This preview is now for demonstration purposes, as it can't
    // easily access the sub-collection data. It will show empty rates.
    return Container(
      width: 370,
      height: 750,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BoardingServiceDetailPage(
          documentId: widget.serviceId,
          shopName: widget.shopName,
          shopImage: widget.shopLogo,
          areaName: widget.areaName,
          distanceKm: 0.0,
          pets: widget.pets,
          mode: '1',
          // --- This will now be empty, which is expected for this preview ---
          rates: {}, isOfferActive: true, preCalculatedStandardPrices: {}, preCalculatedOfferPrices: {}, otherBranches: [], isCertified: true,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const Divider(height: 24),
          // Use a Column instead of spreading the list directly to avoid layout issues with single children.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAddress = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          if (label == 'Description')
            ExpandableText(
              text: value,
              trimLines: 3,
            )
          else
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.black87,
                height: isAddress ? 1.5 : 1.2,
              ),
            ),
        ],
      ),
    );
  }

  // NOTE: This existing function is now reused inside our new Pet Pricing Card!
  Widget _buildPriceGroup(String title, Map<String, String> rates) {
    // If a pet has no rates for a specific group (e.g., no meal rates), don't show anything.
    if (rates.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ...rates.entries.map((e) => Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: GoogleFonts.poppins(fontSize: 15)),
                Text('₹${e.value}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }


// ... (The rest of your functions: _buildPhotoGrid, _showImageCarouselDialog, etc., remain unchanged)
// ... (PASTE ALL YOUR OTHER FUNCTIONS FROM THE PREVIOUS CODE HERE)
  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.imageUrls.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        // ▼▼▼ THIS IS THE FIX ▼▼▼
        // Get the specific URL for this item in the grid.

        final imageUrl = widget.imageUrls[index];
        return GestureDetector(
          onTap: () {
            // The list of images is just the gallery
            final galleryImages = widget.imageUrls;
            // The starting index is the index of the tapped image
            _showImageCarouselDialog(context, imageUrls: galleryImages, initialIndex: index);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }
  // In _BoardingDetailsDashboardState

  // In _BoardingDetailsDashboardState

  void _showImageCarouselDialog(BuildContext context, {
    required List<String> imageUrls,
    required int initialIndex,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final PageController pageController = PageController(initialPage: initialIndex);

        // --- THIS IS THE TWEAK ---
        // We use a StatefulBuilder to manage the current index and update the UI.
        return StatefulBuilder(
          builder: (context, setState) {
            int currentIndex = pageController.hasClients ? pageController.page!.round() : initialIndex;

            // Add a listener to update the index when the user swipes
            pageController.addListener(() {
              if (pageController.page!.round() != currentIndex) {
                setState(() {
                  currentIndex = pageController.page!.round();
                });
              }
            });

            return Dialog(
              backgroundColor: Colors.black.withOpacity(0.8),
              insetPadding: const EdgeInsets.all(0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The swipeable image viewer (unchanged)
                  PageView.builder(
                    controller: pageController,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: imageUrls[index],
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                        ),
                      );
                    },
                  ),

                  // --- TWEAK: Conditionally show the Left Arrow ---
                  // Only show if it's NOT the first image
                  if (currentIndex > 0)
                    Positioned(
                      left: 16,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 30),
                        onPressed: () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),

                  // --- TWEAK: Conditionally show the Right Arrow ---
                  // Only show if it's NOT the last image
                  if (currentIndex < imageUrls.length - 1)
                    Positioned(
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 30),
                        onPressed: () {
                          pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),

                  // Close Button (unchanged)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatPolicyKey(String key) {
    try {
      final parts = key.split('_');
      if (parts.length != 2) return key;
      final condition = parts[0] == 'gt' ? 'Cancellation >' : 'Cancellation <';
      final hours = parts[1].replaceAll('h', '');
      return '$condition $hours hours prior';
    } catch (e) {
      return key;
    }
  }

  // In _BoardingDetailsDashboardState

// ❌ DELETE your old _buildRefundPolicySection method and
// ✅ REPLACE it with this responsive one.
  Widget _buildRefundPolicySection(Map<String, String> policy) {
    final sortedKeys = policy.keys.toList()
      ..sort((a, b) {
        final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numB.compareTo(numA); // Sort descending
      });

    // LayoutBuilder checks the available width and rebuilds accordingly.
    return LayoutBuilder(
      builder: (context, constraints) {
        // We can define a breakpoint. If the width is less than this, we stack the items.
        final bool isWide = constraints.maxWidth > 350;

        return Column(
          children: sortedKeys.map((key) {
            final value = policy[key];
            final labelWidget = Text(_formatPolicyKey(key), style: GoogleFonts.poppins(fontSize: 15));
            final valueWidget = Text('$value% Refund',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600, color: primary));

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: isWide
              // If the screen is WIDE, use the original Row layout.
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [labelWidget, valueWidget],
              )
              // If the screen is NARROW, use a Column.
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelWidget,
                  const SizedBox(height: 4),
                  valueWidget, // The value appears below the title
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // In _BoardingDetailsDashboardState

// V V V ADD THIS ENTIRE NEW METHOD V V V
  // In _BoardingDetailsDashboardState

// REPLACE your old method with this one
  void _showContractInstructionsDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  "Upload Instructions",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth < 600 ? 16 : 20, // smaller on mobile
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: screenWidth < 600
                ? screenWidth * 0.9
                : screenWidth * 0.6, // more compact on mobile
            height: screenHeight < 600
                ? screenHeight * 0.5
                : screenHeight * 0.7, // limit height for scroll
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('company_documents')
                  .doc('partner_contract')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }
                if (snapshot.hasError || !snapshot.data!.exists) {
                  return const Text(
                    "Could not load instructions. Please try again later.",
                    style: TextStyle(fontSize: 14),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final instructionsMap =
                    data['home_boarder_contract_instructions'] as Map<String, dynamic>? ?? {};

                if (instructionsMap.isEmpty) {
                  return const Text(
                    "No instructions found.",
                    style: TextStyle(fontSize: 14),
                  );
                }

                final sortedEntries = instructionsMap.entries.toList()
                  ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

                return SingleChildScrollView(
                  child: ListBody(
                    children: sortedEntries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${entry.key}.",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: primary,
                                fontSize: screenWidth < 600 ? 14 : 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth < 600 ? 13 : 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth < 600 ? 14 : 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _styledButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20, color: Colors.white,),
      label: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
      ),
    );
  }

  Widget _buildRatingStars() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchRatingStats(widget.serviceId),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox(width: 150);
        final avg = snap.data!['avg'] as double;
        final count = snap.data!['count'] as int;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row of stars
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 5; i++)
                  Icon(
                    i < avg ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Row with avg + reviews
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "($count reviews)",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
/// A widget that displays text and truncates it to a certain number of lines,
/// showing a "Show More" / "Show Less" button if the text overflows.
/// A widget that displays text and truncates it to a certain number of lines,
/// showing a "Show More" / "Show Less" button if the text overflows.
/// A widget that displays text and truncates it to a certain number of lines,
/// showing a "Show More" / "Show Less" button if the text overflows.
class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;

  const ExpandableText({
    Key? key,
    required this.text,
    this.trimLines = 3,
  }) : super(key: key);

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;
  bool _isTextOverflowing = false;

  @override
  void initState() {
    super.initState();
    // We check for overflow once when the widget is first built.
    // We use a post-frame callback to ensure the context has a size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final textSpan = TextSpan(
        text: widget.text,
        style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
      );

      final textPainter = TextPainter(
        text: textSpan,
        maxLines: widget.trimLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: context.size?.width ?? MediaQuery.of(context).size.width);

      if (textPainter.didExceedMaxLines) {
        if (mounted) {
          setState(() {
            _isTextOverflowing = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The text style is defined once to be reused.
    final textStyle = GoogleFonts.poppins(
      fontSize: 16,
      color: Colors.black87,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // This widget smoothly animates between the two text states.
        AnimatedCrossFade(
          // The collapsed text widget
          firstChild: Text(
            widget.text,
            style: textStyle,
            maxLines: widget.trimLines,
            overflow: TextOverflow.ellipsis,
          ),
          // The expanded text widget
          secondChild: Text(
            widget.text,
            style: textStyle,
          ),
          // The current state of the animation
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          // The duration of the fade animation
          duration: const Duration(milliseconds: 300),
        ),
        // Only show the button if the text is long enough to overflow
        if (_isTextOverflowing)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isExpanded ? 'Show Less' : 'Show More',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


class Announcement {
  final String heading;
  final String message;
  final bool active;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> visibleTo;

  Announcement({
    required this.heading,
    required this.message,
    required this.active,
    required this.startDate,
    required this.endDate,
    required this.visibleTo,
  });

  // Factory constructor to parse data from Firestore
  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      heading: map['heading'] as String? ?? 'Notice',
      message: map['message'] as String? ?? '',
      active: map['active'] as bool? ?? false,
      // Safely convert Timestamps to DateTime
      startDate: (map['startDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      endDate: (map['endDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      visibleTo: List<String>.from(map['visibleTo'] as List? ?? []),
    );
  }
}