import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';
import 'package:myfellowpet_sp/screens/Boarding/service_requests_page.dart';
import 'package:myfellowpet_sp/utils/web_audio_manager.dart';
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


void main() {
  initWebAudio(); // Initialize the audio element immediately
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}
