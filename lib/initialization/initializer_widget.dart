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

import '../main.dart'; // Contains navigatorKey
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
import '../screens/Boarding/service_requests_page.dart';
import '../screens/Boarding/partner_shell.dart';
import '../screens/Partner/email_signin.dart'; // REQUIRED: SignInPage
import '../screens/Boarding/boarding_type.dart'; // REQUIRED: RunTypeSelectionPage
import '../screens/Partner/profile_selection_screen.dart'; // REQUIRED: ProfileSelectionScreen
import '../utils/web_audio_manager.dart'; // Assuming this holds playCriticalAlertSound()


// 🚀 FIX 1: DEFINE CONSTANT AT TOP LEVEL (Used for the VAPID key)
const String F_VAPID_KEY = String.fromEnvironment('VAPID_KEY');
// ----------------------------------------------------------------------


// --- NEW ENUM FOR PERMISSION GATE ---
enum PermissionStatus { initial, granted, denied, failed }

// --- NEW WIDGET FOR FORCING CONSENT ---
class NotificationPermissionGate extends StatefulWidget {
  final Widget child;
  const NotificationPermissionGate({super.key, required this.child});

  @override
  State<NotificationPermissionGate> createState() => _NotificationPermissionGateState();
}

class _NotificationPermissionGateState extends State<NotificationPermissionGate> {
  PermissionStatus _status = PermissionStatus.initial;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  // This function is your combined FCM/Permission setup logic
  Future<void> _checkAndRequestPermission() async {
    // Check mounted status immediately and for non-web environments
    if (!mounted || !kIsWeb) {
      if(mounted) {
        setState(() => _status = PermissionStatus.granted);
      }
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final userNotifier = context.read<UserNotifier>();

      // 🛑 CRITICAL FIX 2: Check UserNotifier state BEFORE accessing serviceId
      // If the app is still loading the profile data, exit quietly.
      if (userNotifier.authState == AuthState.initializing || userNotifier.authState == AuthState.loading) {
        // The parent FutureBuilder/Consumer handles the loading screen
        return;
      }

      // 1. REQUEST PERMISSIONS (This shows the browser prompt)
      await messaging.requestPermission(
        alert: true, announcement: false, badge: true, carPlay: false,
        criticalAlert: true, provisional: false, sound: true,
      );

      // 2. CHECK STATUS AND GET TOKEN
      final settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // Get token using the safe constant
        final token = await messaging.getToken(
          vapidKey: F_VAPID_KEY,
        );

        if (token != null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {

            // 🚀 Retrieve the service ID using the working getter
            final String? serviceId = userNotifier.activeServiceId;

            // Check mounted again before saving, as the above logic is asynchronous
            if (!mounted) return;

            if (serviceId != null && serviceId.isNotEmpty) {
              // 3. CORRECT SAVE LOCATION: users-sp-boarding/{serviceId}
              await FirebaseFirestore.instance.collection('users-sp-boarding').doc(serviceId).set(
                {'fcmTokenWeb': token, 'tokenUpdated': FieldValue.serverTimestamp()},
                SetOptions(merge: true),
              );
              // Successful save and permission granted
              _setupFirebaseMessagingListeners();
              setState(() => _status = PermissionStatus.granted);

            } else {
              // Token received but no service ID means profile is incomplete/not selected. Block access.
              print("FCM Token saved, but serviceId is missing. Blocking access.");
              setState(() => _status = PermissionStatus.denied);
              return;
            }
          }
        } else {
          // Token not received for unknown reason, block access
          if (mounted) setState(() => _status = PermissionStatus.denied);
        }

      } else {
        // Permission denied by the user
        if (mounted) {
          setState(() => _status = PermissionStatus.denied);
        }
      }
    } catch (e) {
      print("FCM Setup Failed: $e");
      if (mounted) {
        setState(() => _status = PermissionStatus.failed);
      }
    }
  }

  // Duplicating the core listener setup so it can be called AFTER permission check
  void _setupFirebaseMessagingListeners() {
    // a) onMessage listener (handles when the app is open/focused)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && message.notification?.title != null) {
        final notification = message.notification!;
        html.Notification(
          notification.title!,
          body: notification.body,
        );
        // CRITICAL: Trigger the LOUD audio alert when the app is focused
        playCriticalAlertSound();
      }
    });

    // b) onMessageOpenedApp listener (handles when user clicks the notification)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final context = navigatorKey.currentContext;

      if (message.data.containsKey('serviceId') && context != null) {
        final serviceId = message.data['serviceId']!;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (ctx) => PartnerShell(
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
    switch (_status) {
      case PermissionStatus.initial:
      // When status is initial, show loading spinner while waiting for permission/data status
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case PermissionStatus.granted:
      // Proceed to the main application content
        return widget.child;

      case PermissionStatus.denied:
      case PermissionStatus.failed:
      // Block user with a required consent screen
        return Scaffold(
          body: Center(
            child: NotificationRequiredPage(onRetry: _checkAndRequestPermission),
          ),
        );
    }
  }
}

// --- The Blocking Screen Widget ---
class NotificationRequiredPage extends StatelessWidget {
  final VoidCallback onRetry;
  const NotificationRequiredPage({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_rounded, size: 80, color: Color(0xFFC62828)), // Use a distinct red
          const SizedBox(height: 24),
          Text(
            "Notifications Required",
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "As a Service Partner, you must enable browser notifications to receive critical booking requests and cancellation alerts. Without them, you may miss revenue opportunities.",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Enable Notifications / Retry"),
            onPressed: () {
              // Prompt user guidance
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please look for the browser prompt at the top of the screen or check site settings.')),
              );
              onRetry();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: const Color(0xFF2CB4B6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}


// ----------------------------------------------------------------------
// --- ORIGINAL CODE STRUCTURE MODIFIED BELOW ---
// ----------------------------------------------------------------------

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
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
      ),
    );

    if (kIsWeb) {
      // registerRecaptchaView();

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

    // REMOVED old, partial _setupFirebaseMessaging call from here.
  }

  // NOTE: This old function must be removed or renamed if it was defined here,
  // as the new consolidated one is inside the Gate widget.
  void _setupFirebaseMessaging() {
    // This function must be removed if it exists in your original file.
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
    final isLoggedIn = authState == AuthState.authenticated ||
        authState == AuthState.onboardingNeeded ||
        authState == AuthState.profileSelectionNeeded;

    // 1. If not logged in, go to Sign In
    if (!isLoggedIn) {
      return SignInPage();
    }

    // --- WRAP ALL LOGGED-IN STATES IN THE PERMISSION GATE ---

    Widget nextPage;

    if (authState == AuthState.onboardingNeeded) {
      // '/business-type' route
      nextPage = RunTypeSelectionPage(
        uid: FirebaseAuth.instance.currentUser!.uid,
        phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',
        email: FirebaseAuth.instance.currentUser!.email ?? '',
        serviceId: null,
      );
    } else {
      // profileSelectionNeeded OR authenticated (default landing page)
      nextPage = const ProfileSelectionScreen();
    }

    // 🚀 CRITICAL: This is the gate that blocks the user until permission is granted
    return NotificationPermissionGate(child: nextPage);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the UserNotifier to trigger a rebuild when the auth state changes
    final userNotifier = context.watch<UserNotifier>();

    return MaterialApp(
      navigatorKey: navigatorKey, // Keep the global key for navigation
      debugShowCheckedModeBanner: false,
      title: 'MyFellowPet',
      // Define the home widget based on the current AuthState
      home: _getInitialWidget(userNotifier),
    );
  }
}