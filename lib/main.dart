import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data.containsKey('serviceId')) {
      final serviceId = message.data['serviceId'];
      navigatorKey.currentContext?.go('/partner/$serviceId/overnight-requests');
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}
