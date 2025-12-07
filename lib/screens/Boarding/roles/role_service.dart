
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;

// === [START] UPDATED USER NOTIFIER LOGIC (Replaces role_service.dart content) ===

enum AuthState { initializing, loading, unauthenticated, onboardingNeeded, profileSelectionNeeded, authenticated }

class AppUser {
  final String uid;
  final bool isEmployee;
  final String role;
  final String serviceType; // <-- CRITICAL: To distinguish Boarding vs. Pet Store
  final String name;
  final String serviceId;
  final String shopName;
  final String areaName;

  AppUser({
    required this.uid,
    required this.name,
    required this.isEmployee,
    required this.role,
    required this.serviceType, // <-- FIXED: Added serviceType here
    required this.serviceId,
    required this.shopName,
    required this.areaName,
  });
}

class UserNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _me;
  AppUser? get me => _me;

  AuthState _authState = AuthState.initializing;
  AuthState get authState => _authState;

  List<AppUser> _ownerProfiles = [];
  List<AppUser> get ownerProfiles => _ownerProfiles;

  List<AppUser> _employeeProfiles = [];
  List<AppUser> get employeeProfiles => _employeeProfiles;

  UserNotifier() {
    print("DEBUG_AUTH: UserNotifier created. Initial state is $_authState");
    _auth.authStateChanges().listen((fbUser) async {
      _authState = AuthState.loading;
      notifyListeners();

      if (fbUser == null) {
        html.window.localStorage.remove('lastSelectedServiceId');
        _authState = AuthState.unauthenticated;
      } else {
        await _fetchAllProfiles(fbUser);
      }

      notifyListeners();
    });
  }

  void setSelectedUser(AppUser selectedProfile) {
    final allProfiles = [..._ownerProfiles, ..._employeeProfiles];
    if (allProfiles.any((p) => p.serviceId == selectedProfile.serviceId)) {
      html.window.localStorage['lastSelectedServiceId'] = selectedProfile.serviceId;
      _me = selectedProfile;
      _authState = AuthState.authenticated;
      notifyListeners();
    }
  }

  Future<void> refreshUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      _authState = AuthState.loading;
      notifyListeners();
      await _fetchAllProfiles(user);
      notifyListeners();
    }
  }

  Future<void> _fetchAllProfiles(User user) async {
    try {
      _ownerProfiles.clear();
      _employeeProfiles.clear();

      const serviceCollections = ['users-sp-boarding', 'users-sp-store'];

      // --- 1. Fetch EMPLOYEE profiles (Check both collections for potential employee roles) ---
      final empDirDoc = await _db.collection('employeeDirectory').doc(user.uid).get();
      if (empDirDoc.exists) {
        final dirData = empDirDoc.data()!;
        final String serviceId = dirData['serviceId'] as String? ?? '';

        for (final collectionName in serviceCollections) {
          if (serviceId.isNotEmpty) {
            final empDetailDoc = await _db
                .collection(collectionName)
                .doc(serviceId)
                .collection('employees')
                .doc(user.uid)
                .get();

            if (empDetailDoc.exists && empDetailDoc.data()?['active'] == true) {
              final detailData = empDetailDoc.data()!;
              final serviceDoc = await _db.collection(collectionName).doc(serviceId).get();
              final serviceData = serviceDoc.data() ?? {};

              final serviceType = serviceData['type'] as String? ?? (collectionName.contains('store') ? 'Pet Store' : 'Boarding');

              _employeeProfiles.add(AppUser(
                uid: user.uid,
                isEmployee: true,
                role: detailData['role'] as String? ?? 'Staff',
                serviceType: serviceType, // <-- Passed the fetched type
                name: detailData['name'] as String? ?? 'Employee',
                serviceId: serviceId,
                shopName: serviceData['shop_name'] as String? ?? 'Service Name - NA',
                areaName: serviceData['area_name'] as String? ?? 'Area Name - NA',
              ));
              // Stop after finding one active employee profile
              break;
            }
          }
        }
      }

      // --- 2. Fetch OWNER profiles from ALL collections ---
      for (final collectionName in serviceCollections) {
        final shopQuery = await _db
            .collection(collectionName)
            .where('shop_user_id', isEqualTo: user.uid)
            .get();

        for (final shopDoc in shopQuery.docs) {
          final data = shopDoc.data();
          final serviceType = data['type'] as String? ?? (collectionName.contains('store') ? 'Pet Store' : 'Boarding');

          _ownerProfiles.add(AppUser(
            uid: user.uid,
            isEmployee: false,
            role: 'Owner',
            serviceType: serviceType, // <-- Passed the fetched type
            serviceId: data['service_id'] as String? ?? shopDoc.id,
            name: data['owner_name'] as String? ?? 'Owner',
            shopName: data['shop_name'] as String? ?? 'Service Name - NA',
            areaName: data['area_name'] as String? ?? 'Area Name - NA',
          ));
        }
      }

      // --- 3. Determine Final State ---
      final lastSelectedServiceId = html.window.localStorage['lastSelectedServiceId'];
      final allProfiles = [..._ownerProfiles, ..._employeeProfiles];

      if (lastSelectedServiceId != null) {
        try {
          _me = allProfiles.firstWhere((p) => p.serviceId == lastSelectedServiceId);
          _authState = AuthState.authenticated;
          return;
        } catch (e) {
          html.window.localStorage.remove('lastSelectedServiceId');
        }
      }

      final totalProfiles = allProfiles.length;

      if (totalProfiles == 0) {
        _authState = AuthState.onboardingNeeded;
      } else if (totalProfiles == 1) {
        _me = allProfiles.first;
        _authState = AuthState.authenticated;
        // Automatically save the single service ID for fast login next time
        if (_me != null) {
          html.window.localStorage['lastSelectedServiceId'] = _me!.serviceId;
        }
      } else {
        _authState = AuthState.profileSelectionNeeded;
      }

    } catch (e) {
      print('🔥 Error fetching profiles: $e');
      _authState = AuthState.unauthenticated;
    }
  }

  Future<void> init() async {
    _authState = AuthState.initializing;
    notifyListeners();

    final fbUser = await _auth.authStateChanges().first;
    if (fbUser == null) {
      html.window.localStorage.remove('lastSelectedServiceId');
      _authState = AuthState.unauthenticated;
    } else {
      await _fetchAllProfiles(fbUser);
    }

    notifyListeners();
  }
}