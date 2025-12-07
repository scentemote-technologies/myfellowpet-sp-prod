// lib/models/General_user.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class GeneralAppUser {
  final String uid;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl; // Added: Stores the user's profile picture URL
  final String? serviceId; // Added: Essential for GoRouter navigation
  final bool isEmployee; // Added: To differentiate user types

  GeneralAppUser({
    required this.uid,
    this.name,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.serviceId,
    required this.isEmployee,
  });
}

class GeneralUserNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GeneralAppUser? _me;
  GeneralAppUser? get me => _me;

  bool isLoading = true;

  GeneralUserNotifier() {
    _auth.authStateChanges().listen((fbUser) async {
      isLoading = true;
      if (fbUser == null) {
        _me = null;
      } else {
        await _bootstrapUser(fbUser);
      }
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> setUser(User fbUser) async {
    isLoading = true;
    notifyListeners();

    await _bootstrapUser(fbUser);

    isLoading = false;
    notifyListeners();
  }

  Future<void> _bootstrapUser(User fbUser) async {
    try {
      // 🧩 STEP 0: Check if user is a customer
      final customerDoc = await _db.collection('web-users').doc(fbUser.uid).get();
      if (customerDoc.exists) {

        final data = customerDoc.data() ?? {};

        _me = GeneralAppUser(
          uid: fbUser.uid,
          isEmployee: false,
          name: data['displayName'] ?? "Guest",
          email: data['email'] ?? "",           // Safe now
          phoneNumber: data['number'] ?? fbUser.phoneNumber,
          photoUrl: fbUser.photoURL,
          serviceId: null,
        );

        return; // ✅ Skip SP logic
      }

      // 🧩 STEP 1: Check for existing service provider document
      final shopQuery = await _db
          .collection('users-sp-boarding')
          .where('shop_user_id', isEqualTo: fbUser.uid)
          .limit(1)
          .get();

      if (shopQuery.docs.isNotEmpty) {
        final shopDoc = shopQuery.docs.first;
        final data = shopDoc.data();
        _me = GeneralAppUser(
          uid: fbUser.uid,
          isEmployee: false,
          name: data['owner_name'] as String? ?? fbUser.displayName,
          email: data['notification_email'] as String? ?? fbUser.email,
          phoneNumber: data['owner_phone'] as String? ?? fbUser.phoneNumber,
          serviceId: data['service_id'] as String? ?? shopDoc.id,
          photoUrl: fbUser.photoURL,
        );
        return;
      }

      // 🧩 STEP 2: Employee via custom claims
      final idTokenResult = await fbUser.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      final String? claimedServiceId = claims?['serviceId'];
      final String? claimedRole = claims?['role'];

      if (claimedServiceId != null &&
          claimedServiceId.isNotEmpty &&
          claimedRole != 'Owner') {
        final empDoc = await _db
            .collection('users-sp-boarding')
            .doc(claimedServiceId)
            .collection('employees')
            .doc(fbUser.uid)
            .get();

        if (empDoc.exists && empDoc.data()?['active'] == true) {
          final data = empDoc.data()!;
          _me = GeneralAppUser(
            uid: fbUser.uid,
            isEmployee: true,
            name: data['name'] as String? ?? fbUser.displayName,
            email: data['email'] as String? ?? fbUser.email,
            phoneNumber: data['phone'] as String? ?? fbUser.phoneNumber,
            serviceId: claimedServiceId,
            photoUrl: fbUser.photoURL,
          );
          return;
        }
      }

      // 🧩 STEP 3: Brand new user
      _me = GeneralAppUser(
        uid: fbUser.uid,
        isEmployee: false,
        name: fbUser.displayName,
        email: fbUser.email,
        phoneNumber: fbUser.phoneNumber,
        serviceId: null,
        photoUrl: fbUser.photoURL,
      );
    } catch (e) {
      print('🔥 CRITICAL ERROR during bootstrap: $e');
      _me = null;
    }
  }
}
