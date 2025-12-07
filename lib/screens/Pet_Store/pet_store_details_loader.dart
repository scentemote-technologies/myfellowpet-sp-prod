import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myfellowpet_sp/screens/Pet_Store/pet_store_dashboard.dart';

import '../../tools/fcm_token_manager.dart';

class PetStoreDetailsLoader extends StatefulWidget {
  final String serviceId;
  const PetStoreDetailsLoader({Key? key, required this.serviceId})
      : super(key: key);

  @override
  _PetStoreDetailsLoaderState createState() => _PetStoreDetailsLoaderState();
}

class _PetStoreDetailsLoaderState extends State<PetStoreDetailsLoader> {
  late Future<PetStoreDetailsPage> _futurePage;

  @override
  void initState() {
    super.initState();
    // Start loading both the page data and the FCM token
    _futurePage = _loadAllData(widget.serviceId);
  }

  Future<PetStoreDetailsPage> _loadAllData(String id) async {
    // Step 1: Get the page data
    final petStorePage = await _loadPage(id);

    // Step 2: Fetch the FCM token (essential for notifications)
    await registerFcmToken(id);

    // Step 3: Return the fully loaded page
    return petStorePage;
  }

  Future<PetStoreDetailsPage> _loadPage(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-store') // <-- CORRECT COLLECTION
        .where('service_id', isEqualTo: id)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No service found');
    }

    final d = snap.docs.first.data();

    // --- Pet Store Specific Data Retrieval ---
    // Policies
    final rawReturnPolicy = (d['return_policy'] as Map<String, dynamic>? ?? {});
    final rawStoreHours = (d['store_hours'] as Map<String, dynamic>? ?? {});

    // Logistics (Safely parsing ints)
    final deliveryRadius = (d['delivery_radius_km'] as int?)?.toString() ?? '0';
    final fulfillmentTime = (d['fulfillment_time_min'] as int?)?.toString() ?? '0';
    final minOrderValue = (d['delivery_min_order_value'] as int?)?.toString() ?? '0';
    final flatDeliveryFee = (d['delivery_flat_fee'] as int?)?.toString() ?? '0';
    final returnWindowValue = (d['return_window_value'] as int?)?.toString() ?? '0';

    // Map your Firestore fields into the PetStoreDetailsPage constructor:
    return PetStoreDetailsPage(
      serviceId: id,
      // Owner/Basic Info
      ownerName:              d['owner_name'] as String? ?? '',
      notificationEmail:      d['notification_email'] as String? ?? '',
      phoneNumber:            d['owner_phone'] as String? ?? '',
      whatsappNumber:         d['dashboard_whatsapp'] as String? ?? '',

      // Store Identity
      shopName:               d['shop_name'] as String? ?? '',
      shopLogo:               d['shop_logo'] as String? ?? '',
      description:            d['description'] as String? ?? '',
      specialtyNiche:         d['specialty_niche'] as String? ?? '',

      // Verification/Admin
      adminApproved:          d['adminApproved'] as bool? ?? false,

      // Categories/Payments
      productCategories:      List<String>.from(d['product_categories'] ?? []),
      petTypesCatered:        List<String>.from(d['pet_types_catered'] ?? []),
      acceptedPaymentModes:   List<String>.from(d['accepted_payment_modes'] ?? []),

      // Location
      fullAddress:            d['full_address'] as String? ?? '',
      street:                 d['street'] as String? ?? '',
      areaName:               d['area_name'] as String? ?? '',
      state:                  d['state'] as String? ?? '',
      district:               d['district'] as String? ?? '',
      postalCode:             d['postal_code'] as String? ?? '',
      shopLocation: d['location_geopoint'] is GeoPoint
          ? '${(d['location_geopoint'] as GeoPoint).latitude}, ${(d['location_geopoint'] as GeoPoint).longitude}'
          : '',

      // Store Hours
      storeHours:             rawStoreHours.map((k, v) => MapEntry(k, Map<String, String>.from(v))), // Map<String, Map<String, String>>

      // Logistics
      deliveryRadiusKm:       deliveryRadius,
      fulfillmentTimeMin:     fulfillmentTime,
      minOrderValue:          minOrderValue,
      flatDeliveryFee:        flatDeliveryFee,

      // Policies & Returns
      supportEmail:           d['support_email'] as String? ?? '',
      returnPolicyText:       d['return_policy_text'] as String? ?? '',
      returnWindowValue:      returnWindowValue,
      returnWindowUnit:       d['return_window_unit'] as String? ?? 'Days',
      idUrl:                  d['id_url'] as String? ?? '',
      utilityBillUrl:         d['utility_bill_url'] as String? ?? '',
      idWithSelfieUrl:        d['id_with_selfie_url'] as String? ?? '',
      partnerPolicyUrl:       d['partner_policy_url'] as String? ?? '',

      // Documents
      imageUrls:              List<String>.from(d['store_images'] ?? []),

    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PetStoreDetailsPage>(
      future: _futurePage,
      builder: (ctx, snap) {
        // If the future is still running, show a loader
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If there's an error, show an error message
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        }
        // If the future is complete and has data, show the page
        return snap.data!;
      },
    );
  }
}
