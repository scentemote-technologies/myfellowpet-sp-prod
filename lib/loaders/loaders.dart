
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../Widgets/reusable_splash_screen.dart';
import '../screens/Boarding/boarding_service_page_detail.dart';
import '../screens/Boarding/boarding_type.dart';
import '../screens/Boarding/chat_support/chat_support.dart';
import '../screens/Boarding/edit_service_info/edit_service_page.dart';
import '../screens/Partner/email_signin.dart';

class _ChatPageLoader extends StatefulWidget {
  final String serviceId;
  final String? ticketId;

  const _ChatPageLoader({
    Key? key,
    required this.serviceId,
    this.ticketId,
  }) : super(key: key);

  @override
  State<_ChatPageLoader> createState() => _ChatPageLoaderState();
}

class _ChatPageLoaderState extends State<_ChatPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
  }

  @override
  void didUpdateWidget(covariant _ChatPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId || oldWidget.ticketId != widget.ticketId) {
      setState(() {
        _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
      });
    }
  }

  Future<Widget> _loadChatPage(String serviceId, String? ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage(); // Protected by router, but good fallback
    }

    // Fetch the service provider's document
    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return const Center(child: Text("Error: Service provider profile not found."));
    }

    final d = snap.docs.first.data();

    // Extract the required fields (using the same fields as your _PartnerLoader)
    final shopName = d['shop_name'] as String? ?? '';
    final shopEmail = d['notification_email'] as String? ?? '';
    final shopPhone = d['dashboard_phone'] as String? ?? '';

    // Return the fully-formed SPChatPage
    return SPChatPage(
      initialOrderId: ticketId,
      serviceId: serviceId,
      shop_name: shopName,
      shop_email: shopEmail,
      shop_phone_number: shopPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        if (snap.hasError) {
          return Center(child: Text("Error loading chat: ${snap.error}"));
        }
        return snap.data!;
      },
    );
  }
}

class _PartnerLoader extends StatefulWidget {
  final String serviceId;
  const _PartnerLoader({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<_PartnerLoader> createState() => _PartnerLoaderState();
}

class _PartnerLoaderState extends State<_PartnerLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadPartnerPage(widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant _PartnerLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      setState(() {
        _loadFuture = _loadPartnerPage(widget.serviceId);
      });
    }
  }

  Future<Widget> _loadPartnerPage(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage();
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return RunTypeSelectionPage(
        uid: user.uid,
        phone: user.phoneNumber ?? '',
        email: user.email ?? '',
        serviceId: serviceId,
      );
    }

    final d = snap.docs.first.data();
    final refundPolicyRaw = (d['refund_policy'] as Map<String, dynamic>? ?? {});

    return BoardingDetailsPage(
      partnerContractUrl:    d['partner_contract_url']    as String? ?? '',
      isAdminContractUpdateApproved: (d['admin_contract_pdf_update_approve'] as bool?) ?? false,

      serviceId:             serviceId,
      serviceName:           d['service_name']            as String? ?? '',
      description:           d['description']             as String? ?? '',
      refundPolicy:          refundPolicyRaw.map((k, v) => MapEntry(k, v.toString())),
      walkingFee:            d['walking_fee']             as String? ?? '',
      openTime:              d['open_time']               as String? ?? '',
      closeTime:             d['close_time']              as String? ?? '',
      maxPetsAllowed:        d['max_pets_allowed']        as String? ?? '',
      maxPetsAllowedPerHour: d['max_pets_allowed_per_hour'] as String? ?? '',
      pets:                  (d['pets'] as List?)?.cast<String>() ?? [],
      shopName:              d['shop_name']               as String? ?? '',
      shopLogo:              d['shop_logo']               as String? ?? '',
      street:                d['street']                  as String? ?? '',
      areaName:              d['area_name']               as String? ?? '',
      state:                 d['state']                   as String? ?? '',
      district:              d['district']                as String? ?? '',
      postalCode:            d['postal_code']             as String? ?? '',
      shopLocation: d['shop_location'] is GeoPoint
          ? '${(d['shop_location'] as GeoPoint).latitude}, ${(d['shop_location'] as GeoPoint).longitude}'
          : '',
      notification_email:    d['notification_email']      as String? ?? '',
      phoneNumber:           d['owner_phone']             as String? ?? '',
      whatsappNumber:        d['dashboard_whatsapp']      as String? ?? '',
      adminApproved:         (d['adminApproved'] as bool?)?? false,
      fullAddress:           d['full_address']            as String? ?? '',
      bankIfsc:              d['bank_ifsc']               as String? ?? '',
      bankAccountNum:        d['bank_account_num']        as String? ?? '',
      ownerName:             d['owner_name']              as String? ?? '',
      imageUrls:             (d['image_urls'] as List?)?.cast<String>() ?? [],
      features:              (d['features'] as List?)?.cast<String>() ?? [],
      partnerPolicyUrl:      d['partner_policy_url']      as String? ?? '', // <-- ADDED THIS LINE
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        return snap.data!;
      },
    );
  }
}


class _BoardingEditPageLoader extends StatefulWidget {
  final String serviceId;
  const _BoardingEditPageLoader({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<_BoardingEditPageLoader> createState() => __BoardingEditPageLoaderState();
}

class __BoardingEditPageLoaderState extends State<_BoardingEditPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadBoardingEditPage(widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant _BoardingEditPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      setState(() {
        _loadFuture = _loadBoardingEditPage(widget.serviceId);
      });
    }
  }

  Future<Widget> _loadBoardingEditPage(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage();
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    final d = snap.docs.first.data();
    final refundPolicy = d['refund_policy'] as Map<String, dynamic>? ?? {};

    return EditServicePage(
      full_address: d['full_address'] as String? ?? '',
      bank_account_num: d['bank_account_num'] as String? ?? '',
      bank_ifsc: d['bank_ifsc'] as String? ?? '',
      serviceId: serviceId,
      description: d['description'] as String? ?? '',
      refundPolicy: refundPolicy.map((k, v) => MapEntry(k, v.toString())),
      walkingFee: d['walking_fee'] as String? ?? '',
      openTime: d['open_time'] as String? ?? '',
      closeTime: d['close_time'] as String? ?? '',
      maxPetsAllowed: d['max_pets_allowed'] as String? ?? '',
      features: (d['features'] as List?)?.cast<String>() ?? [],
      pets: (d['pets'] as List?)?.cast<String>() ?? [],
      street: d['street'] as String? ?? '',
      areaName: d['area_name'] as String? ?? '',
      state: d['state'] as String? ?? '',
      district: d['district'] as String? ?? '',
      postalCode: d['postal_code'] as String? ?? '',
      shopName: d['shop_name'] as String? ?? '',
      shopLocation: d['shop_location'] is GeoPoint
          ? '${(d['shop_location'] as GeoPoint).latitude}, ${(d['shop_location'] as GeoPoint).longitude}'
          : '',
      image_urls: (d['image_urls'] as List?)?.cast<String>() ?? [],
      maxPetsAllowedPerHour: d['max_pets_allowed_per_hour'] as String? ?? '',
      partnerPolicyUrl: d['partner_policy_url'] as String? ?? '', // <-- ADD THIS LINE

    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        return snap.data!;
      },
    );
  }
}