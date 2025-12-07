import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String? _cachedFcmToken; // Keep this as a top-level or static variable somewhere

Future<void> registerFcmToken(String serviceId) async {

  // Step 0: Check user login
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }

  if (serviceId.isEmpty) {
    return;
  }

  // Step 1: Fetch employee details (document ID and role)
  final employeeSnapshot = await FirebaseFirestore.instance
      .collection('users-sp-boarding')
      .doc(serviceId)
      .collection('employees')
      .where('email', isEqualTo: user.email)
      .limit(1)
      .get();

  if (employeeSnapshot.docs.isEmpty) {
    return; // Abort if no matching employee is found
  }

  // Get the document ID and role
  final String employeeId = employeeSnapshot.docs.first.id;
  final employeeData = employeeSnapshot.docs.first.data();
  final String? role = employeeData['role'] as String?;

  if (role == null) {
    return;
  }


  // Step 2: Request notification permission
  NotificationSettings settings;
  try {
    settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e, st) {
    return;
  }

  if (settings.authorizationStatus != AuthorizationStatus.authorized) {
    return;
  }

  // Step 3: Get FCM token
  String? fcmToken;
  try {
// 1. Define a constant to hold the key from the build environment.
    const fcmVapidKey = String.fromEnvironment('VAPID_KEY');

// 2. Use that constant when you get the token.
    fcmToken = await FirebaseMessaging.instance.getToken(
      vapidKey: fcmVapidKey,
    );
  } catch (e, st) {
    return;
  }

  if (fcmToken == null) {
    return;
  }

  // Step 4: Skip update if token hasn’t changed
  if (_cachedFcmToken == fcmToken) {
    return;
  }
  _cachedFcmToken = fcmToken;

  // Step 5: Save token to Firestore
  // Step 5: Save token to Firestore
  final tokenCollectionRef = FirebaseFirestore.instance
      .collection('users-sp-boarding')
      .doc(serviceId)
      .collection('notification_settings');

  try {
    // Find a document for this employee and service ID
    final existingDocs = await tokenCollectionRef
        .where('employeeId', isEqualTo: employeeId)
        .where('serviceId', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (existingDocs.docs.isNotEmpty) {
      // If a document exists, update it with the new token
      await existingDocs.docs.first.reference.update({
        'fcm_token': fcmToken,
        'device_type': 'web',
        'last_updated': FieldValue.serverTimestamp(),
        'role': role,
      });
    } else {
      // If no document exists, create a new one
      await tokenCollectionRef.add({
        'fcm_token': fcmToken,
        'device_type': 'web',
        'last_updated': FieldValue.serverTimestamp(),
        'employeeId': employeeId,
        'role': role,
        'serviceId': serviceId,
      });
    }
  } catch (e, st) {
    print(st);
  }
}