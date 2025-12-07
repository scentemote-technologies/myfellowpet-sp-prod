import 'dart:io' show Platform;
// add these at the top alongside your other imports
import 'dart:io' show Platform;
import 'package:myfellowpet_sp/user_app/screens/AppBars/AllPetsPage.dart';
import 'package:myfellowpet_sp/user_app/screens/Authentication/FirstTimeUserLoginDeyts.dart';
import 'package:myfellowpet_sp/user_app/screens/Authentication/PhoneSignInPage.dart';
import 'package:myfellowpet_sp/user_app/screens/Boarding/boarding_homepage.dart';
import 'package:myfellowpet_sp/user_app/screens/BottomBars/homebottomnavigationbar.dart';
import 'package:myfellowpet_sp/user_app/screens/HomeScreen/HomeScreen.dart';
import 'package:myfellowpet_sp/user_app/screens/Orders/BoardingOrders.dart';
import 'package:myfellowpet_sp/user_app/screens/reviews/review_gate.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_client.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_enterprise.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../screens/Boarding/preloaders/BoardingCardsForBoardingHomePage.dart';
import '../screens/Boarding/preloaders/BoardingCardsProvider.dart';
import '../screens/Boarding/preloaders/PetsInfoProvider.dart';
import '../screens/Boarding/preloaders/TileImageProvider.dart';
import '../screens/Boarding/preloaders/distance_provider.dart';
import '../screens/Boarding/preloaders/favorites_provider.dart';
import '../screens/Boarding/preloaders/header_media_provider.dart';
import '../screens/Boarding/preloaders/hidden_services_provider.dart';
import 'firebase_options.dart';
import 'loader/app_initializer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// Holds greeting text and media URL for your header.
class HeaderData {
  final String greeting;
  final String mediaUrl;
  HeaderData({required this.greeting, required this.mediaUrl});
}

Future<VideoPlayerController?> preloadVideoController(String url) async {
  if (url.isEmpty) return null;
  final controller = VideoPlayerController.network(url);
  try {
    await controller.initialize().timeout(const Duration(seconds: 5));
    controller.setLooping(true);
    controller.play();
    return controller;
  } catch (e) {
    return null;
  }
}

Future<AndroidMapRenderer?> initializeMapRenderer() async {
  try {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      return await mapsImplementation.initializeWithRenderer(
        AndroidMapRenderer.latest,
      );
    }
  } catch (e) {
  }
  return null;
}

Future<void> initializeLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(android: android),
  );
}

Future<void> setupForegroundNotificationListener() async {
  FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
    final notif = msg.notification;
    final android = msg.notification?.android;
    if (notif != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'booking_channel',
            'Booking Notifications',
            channelDescription:
            'This channel is used for booking confirmation notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });
}

/// Fetches greeting and media URL from Firestore.
Future<HeaderData> preloadHeaderData() async {
  final firestore = FirebaseFirestore.instance;
  final doc = await firestore
      .collection('company_documents')
      .doc('homescreen_images')
      .get();
  final mediaUrl = doc.data()?['boarding'] as String? ?? '';
  String greeting = 'Hello Guest 👋';
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final name = userDoc.data()?['name'] as String?;
    if (name != null) greeting = 'Hello \$name 👋';
  }
  return HeaderData(greeting: greeting, mediaUrl: mediaUrl);
}

/// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 Bg Message: ${message.notification?.title}');
}

void main() async {
  Provider.debugCheckInvalidValueType = null;
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase init
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── FCM: request permissions & register background handler
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ── Android map renderer (unchanged)
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    await initializeMapRenderer();
  }

  // ── Local notifications & foreground listener
  await initializeLocalNotifications();
  await setupForegroundNotificationListener();
  final tileImageProvider = TileImageProvider();
  await tileImageProvider.loadTileImages(); // <<--- ADD THIS LINE


  // ── Preload header data
  final headerData = await preloadHeaderData();

  // ── Recaptcha init
  try {
    await RecaptchaEnterprise.initClient(
      Platform.isAndroid
          ? '6Lf1308rAAAAAAkKlrGdzbxH3KiUBCjIoT70u750'
          : '6Lf1308rAAAAAAkKlrGdzbxH3KiUBCjIoT70u750',
      timeout: 10000,
    );
  } catch (_, st) {
    debugPrintStack(stackTrace: st);
  }

  // ── Run the app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DistanceProvider(FirebaseFirestore.instance)),
        ChangeNotifierProvider(create: (_) => ShopDetailsProvider()..loadFirstTen()),
        ChangeNotifierProvider(create: (_) => HiddenServicesProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider<TileImageProvider>.value(value: tileImageProvider),

        ChangeNotifierProvider(create: (_) => PetProvider()),
        //ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider<HeaderData>.value(value: headerData),
        ChangeNotifierProvider(create: (ctx) => HeaderMediaProvider(ctx)),
        ChangeNotifierProvider(create: (ctx) => BoardingCardsProvider(ctx)),
      ],
      child: const AuthGate(),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  Future<Widget> handlePostLoginRouting(User user) async {
    print('🧠 AuthGate: Logged in as ${user.phoneNumber}');

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone_number', isEqualTo: user.phoneNumber)
        .get();

    if (snapshot.docs.isNotEmpty) {
      print('✅ Firestore user document found. Going to HomeWithTabs.');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ReviewGate(               // ← wrap here
          child: HomeWithTabs(),        // your existing home
        ),
      );
    } else {
      print('🆕 No user document. Going to UserDetailsPage.');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: UserDetailsPage(
          phoneNumber: user.phoneNumber ?? '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.active) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = snap.data;
        if (user == null) {
          print('🔓 Not logged in. Going to PhoneAuthPage.');
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: PhoneAuthPage(),
          );
        }

        // 🔁 Use FutureBuilder to wait for Firestore check
        return FutureBuilder<Widget>(
          future: handlePostLoginRouting(user),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            return snapshot.data!;
          },
        );
      },
    );
  }
}


/// MyApp now launches HomeWithTabs directly.
/*class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        title: 'Flutter App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue),
        navigatorKey: navigatorKey,
        home: const HomeWithTabs(),
      ),
    );
  }
}*/

/// Hosts all your pages in an IndexedStack for instant, smooth swaps.
class HomeWithTabs extends StatefulWidget {
  // 💡 MODIFIED: Add initialTabIndex and initialBoardingFilter
  final int initialTabIndex;
  final Map<String, dynamic>? initialBoardingFilter;

  const HomeWithTabs({
    Key? key,
    this.initialTabIndex = 0, // Default to 0 (HomeScreen)
    this.initialBoardingFilter,
  }) : super(key: key);

  @override
  HomeWithTabsState createState() => HomeWithTabsState();
}

class HomeWithTabsState extends State<HomeWithTabs> {
  // 💡 MODIFIED: Initialize _currentIndex from widget.initialTabIndex
  late int _currentIndex;

  // 💡 NEW: Hold the filter data state, which will be consumed and cleared
  Map<String, dynamic>? _boardingFilterData;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;

    // 💡 NEW: Store the incoming filter data and immediately clear it from the widget
    // This ensures the filter is only applied once upon navigation.
    _boardingFilterData = widget.initialBoardingFilter;
  }

  void goToTab(int idx) => setState(() => _currentIndex = idx);

  // 💡 MODIFIED: Dynamically create the pages list to inject filter data into BoardingHomepage
  List<Widget> get _pages {
    // 1. Get the current filter data and then immediately set it to null
    //    so subsequent builds/navigations won't re-apply it.
    final filterToApply = _boardingFilterData;
    _boardingFilterData = null;

    return [
      HomeScreen(),
      // 2. Inject the filter data and initialSearchFocus into BoardingHomepage
      // ✅ CORRECTION APPLIED: Changed 'initialFilterData' to 'initialBoardingFilter'
      BoardingHomepage(
        initialSearchFocus: filterToApply != null, // Trigger autofocus/dialog
        initialBoardingFilter: filterToApply, // <-- This resolves the error
      ),
      AllPetsPage(),
      BoardingOrders(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
    ];
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false; // prevent default back
    }
    return true; // exit app
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          // 💡 MODIFIED: Use the getter to build pages with the latest filter data
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBarWidget(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() {
            // 💡 IMPORTANT: If the user manually switches tabs, clear any pending filter.
            if (i != 1) {
              _boardingFilterData = null;
            }
            _currentIndex = i;
          }),
        ),
      ),
    );
  }
}