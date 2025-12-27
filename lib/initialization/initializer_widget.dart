import 'dart:js' as js;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_strategy/url_strategy.dart';
import '../main.dart';
import '../models/General_user.dart';
import '../screens/Boarding/preloaders/BoardingCardsForBoardingHomePage.dart';
import '../screens/Boarding/preloaders/BoardingCardsProvider.dart';
import '../screens/Boarding/preloaders/PetsInfoProvider.dart';
import '../screens/Boarding/preloaders/distance_provider.dart';
import '../screens/Boarding/preloaders/favorites_provider.dart';
import '../screens/Boarding/preloaders/header_media_provider.dart';
import '../screens/Boarding/preloaders/hidden_services_provider.dart';
import '../screens/Boarding/roles/role_service.dart';
import '../screens/Boarding/service_requests_page.dart';
import '../screens/Boarding/partner_shell.dart';
import '../screens/Partner/email_signin.dart';
import '../screens/Boarding/boarding_type.dart';
import '../screens/Partner/profile_selection_screen.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<void> _initializationFuture;

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
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
      ),
    );

    if (kIsWeb) {
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
      final context = navigatorKey.currentContext;

      if (message.data.containsKey('serviceId') && context != null) {
        final serviceId = message.data['serviceId']!;

        // 🚀 REPLACED context.go() with standard Navigator

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (ctx) => PartnerShell(
                  serviceId: serviceId,

                  currentPage: PartnerPage.overnightRequests,

                  child: ServiceRequestsPage(serviceId: serviceId),
                ),
          ),

          (Route<dynamic> route) => false,
        );
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

            home: Scaffold(backgroundColor: Color(0xFFF0F8F8)),
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

            ChangeNotifierProvider(
              create: (_) => DistanceProvider(FirebaseFirestore.instance),
            ),

            ChangeNotifierProvider(create: (_) => ShopDetailsProvider()),

            ChangeNotifierProvider(create: (_) => HiddenServicesProvider()),

            ChangeNotifierProvider(create: (_) => FavoritesProvider()),

            ChangeNotifierProvider(create: (_) => PetProvider()),

            ChangeNotifierProvider(create: (ctx) => HeaderMediaProvider(ctx)),

            ChangeNotifierProvider(create: (ctx) => BoardingCardsProvider(ctx)),

            ChangeNotifierProvider(create: (_) => GeneralUserNotifier()),
          ],

          child: const MyAppRoot(), // Go directly to MyAppRoot
        );
      },
    );
  }
}

// --- RENAMED & RE-PURPOSED MYAPP CLASS ---

class MyAppRoot extends StatelessWidget {
  const MyAppRoot({super.key});

  // Helper method to determine the initial widget after auth is resolved

  Widget _getInitialWidget(UserNotifier userNotifier) {
    final authState = userNotifier.authState;

    final isLoggedIn =
        authState == AuthState.authenticated ||
        authState == AuthState.onboardingNeeded ||
        authState == AuthState.profileSelectionNeeded;

    // Logic based on the old router redirects:

    // 1. If not logged in, go to Sign In

    if (!isLoggedIn) {
      return SignInPage();
    }

    // 2. If logged in, check auth state for specific pages

    if (authState == AuthState.onboardingNeeded) {
      // '/business-type' route

      return RunTypeSelectionPage(
        fromOtherbranches: false,

        uid: FirebaseAuth.instance.currentUser!.uid,

        phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',

        email: FirebaseAuth.instance.currentUser!.email ?? '',

        serviceId: null,
      );
    }

    if (authState == AuthState.profileSelectionNeeded ||
        authState == AuthState.authenticated) {
      // '/profile-selection' route (used as the default target when logged in)

      return const ProfileSelectionScreen();
    }

    // Fallback: Should not be reached, but default to Sign In

    return SignInPage();
  }
  Future<void> registerFcmToken(String serviceId) async {
    if (!kIsWeb) return;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken(
      vapidKey: const String.fromEnvironment('FIREBASE_VAPID_KEY'),
    );

    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }


  @override
  Widget build(BuildContext context) {
    final userNotifier = context.watch<UserNotifier>();

    if (kIsWeb &&
        userNotifier.authState == AuthState.authenticated &&
        userNotifier.serviceId != null) {

      registerFcmToken(userNotifier.serviceId!);
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: _getInitialWidget(userNotifier),
    );
  }

}

// -------------------------------------------------
