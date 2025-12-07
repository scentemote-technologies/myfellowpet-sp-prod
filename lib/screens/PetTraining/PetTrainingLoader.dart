import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myfellowpet_sp/screens/PetTraining/pet_training_service_detail_page.dart';

import '../../tools/fcm_token_manager.dart';

class Pettrainingloader extends StatefulWidget {
  final String serviceId;
  const Pettrainingloader({Key? key, required this.serviceId})
      : super(key: key);

  @override
  _PettrainingloaderState createState() => _PettrainingloaderState();
}

class _PettrainingloaderState extends State<Pettrainingloader> {
  late Future<PetTrainingServiceDetailsPage> _futurePage;

  @override
  void initState() {
    super.initState();
    // Start loading both the page data and the FCM token
    _futurePage = _loadAllData(widget.serviceId);
  }

  Future<PetTrainingServiceDetailsPage> _loadAllData(String id) async {
    // Step 1: Get the page data (await will pause execution here)
    final petWalkingPage = await _loadPage(id);

    // Step 2: Fetch the FCM token (await will pause execution here)
    // This is the key step that gives the Service Worker time
    await registerFcmToken(id);

    // Step 3: Return the fully loaded page
    return petWalkingPage;
  }
  Future<PetTrainingServiceDetailsPage> _loadPage(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: id)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No service found');
    }

    final d = snap.docs.first.data();
    final rawDaily = (d['rates_daily'] as Map<String, dynamic>? ?? {});
    final walkingRaw = (d['walking_rates'] as Map<String, dynamic>? ?? {});
    final mealRaw = (d['meal_rates'] as Map<String, dynamic>? ?? {});
    final offerRawDaily = (d['offer_daily_rates'] as Map<String, dynamic>? ?? {});
    final offerWalkingRaw = (d['offer_walking_rates'] as Map<String, dynamic>? ?? {});
    final offerMealRaw = (d['offer_meal_rates'] as Map<String, dynamic>? ?? {});
    final refundPolicyRaw = (d['refund_policy'] as Map<String, dynamic>? ?? {});

    // Map your Firestore fields into the constructor:
    return PetTrainingServiceDetailsPage(
      serviceId: id,
      serviceName: d['service_name'] ?? '',
      partnerContractUrl:    d['partner_contract_url']    as String? ?? '',
      isAdminContractUpdateApproved: (d['admin_contract_pdf_update_approve'] as bool?) ?? false,

      partnerPolicyUrl:      d['partner_policy_url']      as String? ?? '', // <-- ADDED THIS LINE

      description: d['description'] ?? '',
      features: (d['features'] as List?)?.cast<String>() ?? [],

      refundPolicy: refundPolicyRaw.map((k, v) => MapEntry(k, v.toString())),

      walkingFee: d['walking_fee'] ?? '',
      openTime: d['open_time'] ?? '',
      closeTime: d['close_time'] ?? '',
      maxPetsAllowed: d['max_pets_allowed'] ?? '',
      maxPetsAllowedPerHour: d['max_pets_allowed_per_hour'] ?? '',
      pets: List<String>.from(d['pets'] ?? []),
      shopName: d['shop_name'] ?? '',
      street: d['street'] ?? '',
      areaName: d['area_name'] ?? '',
      state: d['state'] ?? '',
      district: d['district'] ?? '',
      postalCode: d['postal_code'] ?? '',
      shopLocation: d['shop_location'] is GeoPoint
          ? '${(d['shop_location'] as GeoPoint).latitude}, ${(d['shop_location'] as GeoPoint).longitude}'
          : '',
      notification_email: d['notification_email'] ?? '',
      phoneNumber: d['owner_phone'] ?? '',
      whatsappNumber: d['dashboard_whatsapp'] ?? '',
      adminApproved: d['adminApproved'] ?? false,
      fullAddress:            d['full_address'] as String? ?? '',
      bankIfsc:               d['bank_ifsc'] as String? ?? '',
      bankAccountNum:        d['bank_account_num'] as String? ?? '',
      ownerName:              d['owner_name'] as String? ?? '',
      shopLogo: d['shop_logo'] ?? '',
      imageUrls: List<String>.from(d['image_urls'] ?? []),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PetTrainingServiceDetailsPage>(
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
