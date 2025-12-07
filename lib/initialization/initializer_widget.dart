import 'dart:js' as js;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';

import '../main.dart';
import '../routes/routes.dart';
import '../providers/boarding_details_loader.dart';
import '../models/General_user.dart';
import '../screens/Boarding/preloaders/BoardingCardsForBoardingHomePage.dart';
import '../screens/Boarding/preloaders/BoardingCardsProvider.dart';
import '../screens/Boarding/preloaders/PetsInfoProvider.dart';
import '../screens/Boarding/preloaders/distance_provider.dart';
import '../screens/Boarding/preloaders/favorites_provider.dart';
import '../screens/Boarding/preloaders/header_media_provider.dart';
import '../screens/Boarding/preloaders/hidden_services_provider.dart';
import '../screens/Boarding/roles/role_service.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<void> _initializationFuture;

  static GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    setPathUrlStrategy();

    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
      ),
    );

    if (kIsWeb) {
      registerRecaptchaView();
      const recaptchaV3SiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider(recaptchaV3SiteKey),
      );
    }

    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

    if (kIsWeb) {
      html.window.onPopState.listen((event) {
        print("🌐 BROWSER POP → ${html.window.location.pathname}");
      });

      html.window.onHashChange.listen((event) {
        print("🔗 HASH CHANGE → ${html.window.location.pathname}");
      });

      html.window.onBeforeUnload.listen((event) {
        print("⚠️ BEFORE UNLOAD → browser may refresh");
      });
    }

    _setupFirebaseMessaging();
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification?.title != null) {
        html.Notification(
          message.notification!.title!,
          body: message.notification?.body,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data.containsKey('serviceId')) {
        final serviceId = message.data['serviceId'];
        navigatorKey.currentContext?.go('/partner/$serviceId/overnight-requests');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFFF0F8F8),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            ),
          );
        }

        if (kIsWeb) {
          js.context.callMethod('hideLoadingSplash');
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserNotifier()),
            ChangeNotifierProvider(create: (_) => DistanceProvider(FirebaseFirestore.instance)),
            ChangeNotifierProvider(create: (_) => ShopDetailsProvider()),
            ChangeNotifierProvider(create: (_) => HiddenServicesProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => PetProvider()),
            ChangeNotifierProvider(create: (ctx) => HeaderMediaProvider(ctx)),
            ChangeNotifierProvider(create: (ctx) => BoardingCardsProvider(ctx)),
            ChangeNotifierProvider(create: (_) => GeneralUserNotifier()),
          ],
          child: Consumer<UserNotifier>(
            builder: (context, userNotifier, child) {

              // 1️⃣ Wait for auth
              if (userNotifier.authState == AuthState.loading ||
                  userNotifier.authState == AuthState.initializing) {
                return const MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // 2️⃣ Router must be created ONLY ONCE
              if (_router == null) {

                // 🔥 Allow browser one frame to apply the correct URL before reading it
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_router != null) return; // prevent double create

                  final initialUrl = kIsWeb
                      ? "${html.window.location.pathname}${html.window.location.search}"
                      : "/partner-with-us";

                  print("🚀 Creating router with initialLocation = $initialUrl");

                  setState(() {
                    _router = createRouter(
                      userNotifier,
                      navigatorKey,
                      initialLocation: initialUrl,
                    );
                  });
                });

                // While router is being constructed, show temporary blank screen
                return const MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                    backgroundColor: Color(0xFFF0F8F8),
                  ),
                );
              }

              // 3️⃣ Router READY → return the actual app
              return MyApp(router: _router!);
            },
          ),

        );
      },
    );
  }
}


class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'MyFellowPet',
    );
  }
}

