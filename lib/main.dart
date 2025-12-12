import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';
import 'package:myfellowpet_sp/screens/Boarding/service_requests_page.dart';
import 'initialization/initializer_widget.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void registerRecaptchaView() {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'recaptcha',
        (int viewId) {
      final elem = html.DivElement()..id = 'recaptcha';
      elem.style.width = '0';
      elem.style.height = '0';
      return elem;
    },
  );
}

void setupFirebaseMessagingListeners() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null && message.notification?.title != null) {
      final notification = message.notification!;
      html.Notification(
        notification.title!,
        body: notification.body,
      );
    }
  });

  // Ensure your global navigatorKey is available and the necessary imports are present
// (PartnerShell, PartnerPage, ServiceRequestsPage, etc.)

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final context = navigatorKey.currentContext; // Get the context once

    if (message.data.containsKey('serviceId') && context != null) {
      final serviceId = message.data['serviceId']!;

      // 🚀 REPLACING context.go() with Navigator.pushAndRemoveUntil
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => PartnerShell(
            serviceId: serviceId,
            // Use the specific enum for the Overnight Requests page
            currentPage: PartnerPage.overnightRequests,
            // Assuming ServiceRequestsPage is the correct widget
            child: ServiceRequestsPage(serviceId: serviceId),
          ),
        ),
            (Route<dynamic> route) => false, // Clear all previous routes
      );
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}
