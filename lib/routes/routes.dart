import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/boarding_details_loader.dart';
import '../screens/Boarding/DaycareComingSoon.dart';
import '../screens/Boarding/ServiceProviderCalendarPage.dart';
import '../screens/Boarding/Service_Analytics_Page.dart';
import '../screens/Boarding/chat_support/chat_support.dart';
import '../screens/Boarding/edit_service_info/edit_service_page.dart';
import '../screens/Boarding/employees/employee_tasks.dart';
import '../screens/Boarding/payment/PaymentDashboardPage.dart';
import '../screens/Boarding/roles/role_service.dart';
import '../screens/Boarding/service_requests_page.dart';
import '../screens/HomePage/mainhomescreen.dart';
import '../screens/Boarding/OtherBranchesPage.dart';
import '../screens/Boarding/employees/employees_management.dart';
import '../screens/Boarding/boarding_type.dart';
import '../screens/Partner/email_signin.dart';
import '../screens/Boarding/faq_sp.dart';
import '../screens/Boarding/logout_page.dart';
import '../screens/Boarding/boarding_service_page_detail.dart';
import '../screens/Boarding/partner_shell.dart';
import '../screens/Partner/partnerSpFaqs.dart';
import '../screens/Partner/profile_selection_screen.dart';
import '../screens/PetTraining/PetTrainingLoader.dart';
import '../screens/PetTraining/partner_shell.dart';
import '../screens/PetTraining/test.dart';
import '../screens/Pet_Store/PetStorePartnerShell.dart';
import '../screens/Pet_Store/pet_store_details_loader.dart';
import '../screens/Pet_Store/store stuff/inventory.dart';
import '../user_app/screens/Boarding/boarding_servicedetailspage.dart';
import '../widgets/reusable_splash_screen.dart'; // Import the new splash screen


void saveCurrentRoute(String route) {
  html.window.localStorage['lastRoute'] = route;
}
class RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint("🟩 ROUTE PUSHED → ${route.settings.name ?? route.settings}");
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint("🟥 ROUTE POPPED → ${route.settings.name ?? route.settings}");
    super.didPop(route, previousRoute);
  }
}

GoRouter createRouter(
    UserNotifier userNotifier,
    GlobalKey<NavigatorState> navigatorKey, {
      required String initialLocation,
    }) {

  Future<bool> checkPaymentEnabled() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('payment')
          .get();

      return doc.data()?['boarder_web_dashboard_payment_enabled'] == true;
    } catch (e) {
      print('⚠️ Failed to check payment enabled: $e');
      return false;
    }
  }

  // 1️⃣ If embedded → lightweight router
  if (kIsWeb && Uri.base.queryParameters['embedded'] == 'true') {
    return GoRouter(
      navigatorKey: navigatorKey,
      // This ensures the app starts by looking for the route below
      initialLocation: "/partner-entry",
      routes: [
        // ✅ 1. THE ROUTE YOU WANT (The destination)
        GoRoute(
          path: "/partner-with-us",
          builder: (ctx, state) => SignInPage(),
        ),

        // ✅ 2. THE SIDE DOOR (Redirects to the one above)
        GoRoute(
          path: "/partner-entry",
          redirect: (context, state) => "/partner-with-us",
        ),
      ],
    );
  }


  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: userNotifier,
    initialLocation: initialLocation,
    observers: [
      RouteLogger(),
    ],

    debugLogDiagnostics: true,


    redirect: (context, state) {
      final authState = userNotifier.authState;
      final location = state.uri.toString();

      if (!location.startsWith('/splash')) {
        html.window.localStorage['lastRoute'] = location;
      }

      final isLoggedIn = authState == AuthState.authenticated ||
          authState == AuthState.onboardingNeeded ||
          authState == AuthState.profileSelectionNeeded;

      // Public URLs (must be accessible unauthenticated)
      final isPublic =
          location == '/' ||
              location == '/partner-with-us' ||
              location == '/partner-with-us/faqs' ||
              location.startsWith('/india/boarding/');

      // 1️⃣ If NOT logged in, block PRIVATE pages
      if (!isLoggedIn && !isPublic) {
        return '/partner-with-us';
      }

      // 2️⃣ If logged in and open sign-in page → redirect to correct dashboard
      if (isLoggedIn && location == '/partner-with-us') {
        String? target;
        if (authState == AuthState.onboardingNeeded) target = '/business-type';
        if (authState == AuthState.profileSelectionNeeded) target = '/profile-selection';
        if (authState == AuthState.authenticated) {
          final sid = userNotifier.me?.serviceId;
          if (sid != null) target = '/partner/$sid/profile';
        }
        if (target != null && target != location) return target;
      }

      return null;
    },


    routes: [
      // --- Public Routes ---
      GoRoute(
        path: '/',
        builder: (ctx, state) => const MainHomeScreen(),
      ),
      GoRoute(
        // Corrected path to match the 6 segments generated by the card:
        // /:country/:serviceType/:stateSlug/:districtSlug/:areaSlug/:finalSlug
        path: '/:country/:serviceType/:stateSlug/:districtSlug/:areaSlug/:finalSlug',
        builder: (ctx, state) {
          // 1. Extract the unique service ID from the query parameters (e.g., ?id=x6gSixmf...)
          final serviceId = state.uri.queryParameters['id'];

          // 2. We skip using the 'extra' data here to ensure deep links (direct URL hits) work.
          //    The page will fetch its own data using the 'serviceId'.

          // 3. Extract path parameters for reference (optional, but good for error logging/tracking)
          // final country = state.pathParameters['country']!;
          // final serviceType = state.pathParameters['serviceType']!;
          // final finalSlug = state.pathParameters['finalSlug']!;

          // Crucial: Load the public detail page.
          if (serviceId != null) {
            return BoardingServiceDetailPage(
              documentId: serviceId,
              // These fields are required by the constructor but the page will fetch the
              // real data internally since 'serviceId' is provided.
              mode: '1',
              pets: const [],
              shopName: 'Loading...',
              shopImage: '',
              areaName: '',
              distanceKm: 0.0,
              rates: const {},
              otherBranches: const [],
              isOfferActive: false,
              isCertified: false,
              preCalculatedStandardPrices: const {},
              preCalculatedOfferPrices: const {},
            );
          }

          // Fallback if the required ID query parameter is missing
          return const Center(child: Text('Service ID missing for public route.'));
        },
      ),
      GoRoute(
        path: '/partner/:serviceId/profile',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: BoardingDetailsLoader(serviceId: sid),
          );
        },
      ),
      GoRoute(
        path: '/partner-with-us',
        builder: (ctx, state) => SignInPage(),
      ),
      GoRoute(
        path: '/profile-selection',
        builder: (ctx, state) => const ProfileSelectionScreen(),
      ),
      GoRoute(
        path: '/partner-with-us/faqs',
        builder: (ctx, state) => const PartnerFaqPage(),
      ),
      GoRoute(
        path: '/business-type',
        builder: (ctx, state) => RunTypeSelectionPage(
          uid: FirebaseAuth.instance.currentUser!.uid,
          phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',
          email: FirebaseAuth.instance.currentUser!.email ?? '',
          serviceId: null,
        ),
      ),
      GoRoute(
        path: '/partner/:serviceId/edit',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: _BoardingEditPageLoader(serviceId: sid),
          );
        },
      ),
      GoRoute(
        path: '/partner/:serviceId/branches',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: OtherBranchesPage(
              serviceId: sid,
              ownerId: FirebaseAuth.instance.currentUser!.uid,
            ),
          );
        },
      ),
      GoRoute(
        path: '/business-type/:serviceId',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return RunTypeSelectionPage(
            uid: FirebaseAuth.instance.currentUser!.uid,
            phone: FirebaseAuth.instance.currentUser!.phoneNumber ?? '',
            email: FirebaseAuth.instance.currentUser!.email ?? '',
            serviceId: sid,
          );
        },
      ),
      GoRoute(
        path: '/partner/:serviceId',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: BoardingDetailsLoader(serviceId: sid),
          );
        },
        // All nested routes of /partner/:serviceId are also automatically protected
        routes: [

          GoRoute(
            path: 'overnight-requests',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: ServiceRequestsPage(serviceId: sid),
              );
            },
          ),
          GoRoute(
            path: 'payments',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return FutureBuilder<bool>(
                future: checkPaymentEnabled(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final isEnabled = snapshot.data ?? false;

                  return PartnerShell(
                    serviceId: sid,
                    currentLocation: state.fullPath,
                    child: isEnabled
                        ? PaymentDashboardPage(serviceId: sid)
                        : DaycareComingSoonPage(),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: 'schedule',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: ServiceProviderCalendarPage(serviceId: sid),
              );
            },
          ),
          GoRoute(
            path: 'performance-monitor',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: ServiceAnalyticsPage(serviceId: sid),
              );
            },
          ),
          GoRoute(
            path: 'faq',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: SpFaqPage(
                  serviceId: sid,
                  onContactSupport: () => ctx.go('/partner/$sid/support'),
                ),
              );
            },
          ),
          GoRoute(
            path: 'support',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: _ChatPageLoader(
                  serviceId: sid,
                  ticketId: null, // No ticket on this route
                ),
              );
            },
          ),
          GoRoute(
            path: 'support/ticket/:ticketId',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              final tid = state.pathParameters['ticketId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: _ChatPageLoader(
                  serviceId: sid,
                  ticketId: tid, // Pass the ticketId
                ),
              );
            },
          ),
          GoRoute(
            path: 'employees',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: EmployeePage(serviceId: sid),
              );
            },
            routes: [
              GoRoute(
                path: 'add-emp',
                builder: (ctx, state) {
                  final sid = state.pathParameters['serviceId']!;
                  final extra = state.extra as Map<String, dynamic>;
                  final int employeeCount = extra['employeeCount'];
                  final int employeeLimit = extra['employeeLimit'];
                  final VoidCallback onAdded = extra['onAdded'];

                  return PartnerShell(
                    serviceId: sid,
                    currentLocation: state.fullPath,
                    child: AddEmployeePage(
                      serviceId: sid,
                      employeeCount: employeeCount,
                      employeeLimit: employeeLimit,
                      onAdded: onAdded,
                    ),
                  );
                },
              ),
              GoRoute(
                path: ':employeeId/tasks',
                builder: (ctx, state) {
                  final sid = state.pathParameters['serviceId']!;
                  final eid = state.pathParameters['employeeId']!;
                  return PartnerShell(
                    serviceId: sid,
                    currentLocation: state.fullPath,
                    child: TasksScreen(serviceId: sid, employeeId: eid),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'settings',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: SettingsPage(
                  serviceId: sid,
                  onFAQ: () => ctx.go('/partner/$sid/faq'),
                  onContactSupport: () => ctx.go('/partner/$sid/support'),
                ),
              );
            },
          ),
          GoRoute(
            path: 'home',
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: const MainHomeScreen(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/partner/pet-training/:serviceId',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PetTrainingPartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: Pettrainingloader(serviceId: sid),
          );
        },
        routes: [
          GoRoute(
            path: 'profile', // relative to parent
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PetTrainingPartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: Pettrainingloader(serviceId: sid),
              );
            },
          ),
          GoRoute(
            path: 'training-requests', // relative to parent
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PetTrainingPartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: TestPage(),
              );
            },
          ),

        ],
      ),
      GoRoute(
        path: '/partner/pet-store/:serviceId',
        builder: (ctx, state) {
          final sid = state.pathParameters['serviceId']!;
          return PetStorePartnerShell(
            serviceId: sid,
            currentLocation: state.fullPath,
            child: PetStoreDetailsLoader(serviceId: sid),
          );
        },
        routes: [
          GoRoute(
            path: 'profile', // relative to parent
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PetStorePartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: PetStoreDetailsLoader(serviceId: sid),
              );
            },
          ),
          GoRoute(
            path: 'inventory', // relative to parent
            builder: (ctx, state) {
              final sid = state.pathParameters['serviceId']!;
              return PetStorePartnerShell(
                serviceId: sid,
                currentLocation: state.fullPath,
                child: InventoryPage(serviceId: sid),
              );
            },
          ),
        ],
      ),
    ],


  );

}

// V V V PASTE THIS ENTIRE NEW WIDGET AT THE BOTTOM OF YOUR FILE V V V

class _ChatPageLoader extends StatefulWidget {
  final String serviceId;
  final String? ticketId;

  const _ChatPageLoader({
    Key? key,
    required this.serviceId,
    this.ticketId,
  }) : super(key: key);

  @override
  State<_ChatPageLoader> createState() => _ChatPageLoaderState();
}

class _ChatPageLoaderState extends State<_ChatPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
  }

  @override
  void didUpdateWidget(covariant _ChatPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId || oldWidget.ticketId != widget.ticketId) {
      setState(() {
        _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
      });
    }
  }

  Future<Widget> _loadChatPage(String serviceId, String? ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage(); // Protected by router, but good fallback
    }

    // Fetch the service provider's document
    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return const Center(child: Text("Error: Service provider profile not found."));
    }

    final d = snap.docs.first.data();

    // Extract the required fields (using the same fields as your _PartnerLoader)
    final shopName = d['shop_name'] as String? ?? '';
    final shopEmail = d['notification_email'] as String? ?? '';
    final shopPhone = d['dashboard_phone'] as String? ?? '';

    // Return the fully-formed SPChatPage
    return SPChatPage(
      initialOrderId: ticketId,
      serviceId: serviceId,
      shop_name: shopName,
      shop_email: shopEmail,
      shop_phone_number: shopPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        if (snap.hasError) {
          return Center(child: Text("Error loading chat: ${snap.error}"));
        }
        return snap.data!;
      },
    );
  }
}

class _PartnerLoader extends StatefulWidget {
  final String serviceId;
  const _PartnerLoader({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<_PartnerLoader> createState() => _PartnerLoaderState();
}

class _PartnerLoaderState extends State<_PartnerLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadPartnerPage(widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant _PartnerLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      setState(() {
        _loadFuture = _loadPartnerPage(widget.serviceId);
      });
    }
  }

  Future<Widget> _loadPartnerPage(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage();
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return RunTypeSelectionPage(
        uid: user.uid,
        phone: user.phoneNumber ?? '',
        email: user.email ?? '',
        serviceId: serviceId,
      );
    }

    final d = snap.docs.first.data();
    final refundPolicyRaw = (d['refund_policy'] as Map<String, dynamic>? ?? {});

    return BoardingDetailsPage(
      partnerContractUrl:    d['partner_contract_url']    as String? ?? '',
      isAdminContractUpdateApproved: (d['admin_contract_pdf_update_approve'] as bool?) ?? false,

      serviceId:             serviceId,
      serviceName:           d['service_name']            as String? ?? '',
      description:           d['description']             as String? ?? '',
      refundPolicy:          refundPolicyRaw.map((k, v) => MapEntry(k, v.toString())),
      walkingFee:            d['walking_fee']             as String? ?? '',
      openTime:              d['open_time']               as String? ?? '',
      closeTime:             d['close_time']              as String? ?? '',
      maxPetsAllowed:        d['max_pets_allowed']        as String? ?? '',
      maxPetsAllowedPerHour: d['max_pets_allowed_per_hour'] as String? ?? '',
      pets:                  (d['pets'] as List?)?.cast<String>() ?? [],
      shopName:              d['shop_name']               as String? ?? '',
      shopLogo:              d['shop_logo']               as String? ?? '',
      street:                d['street']                  as String? ?? '',
      areaName:              d['area_name']               as String? ?? '',
      state:                 d['state']                   as String? ?? '',
      district:              d['district']                as String? ?? '',
      postalCode:            d['postal_code']             as String? ?? '',
      shopLocation: d['shop_location'] is GeoPoint
          ? '${(d['shop_location'] as GeoPoint).latitude}, ${(d['shop_location'] as GeoPoint).longitude}'
          : '',
      notification_email:    d['notification_email']      as String? ?? '',
      phoneNumber:           d['owner_phone']             as String? ?? '',
      whatsappNumber:        d['dashboard_whatsapp']      as String? ?? '',
      adminApproved:         (d['adminApproved'] as bool?)?? false,
      fullAddress:           d['full_address']            as String? ?? '',
      bankIfsc:              d['bank_ifsc']               as String? ?? '',
      bankAccountNum:        d['bank_account_num']        as String? ?? '',
      ownerName:             d['owner_name']              as String? ?? '',
      imageUrls:             (d['image_urls'] as List?)?.cast<String>() ?? [],
      features:              (d['features'] as List?)?.cast<String>() ?? [],
      partnerPolicyUrl:      d['partner_policy_url']      as String? ?? '', // <-- ADDED THIS LINE
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        return snap.data!;
      },
    );
  }
}


class _BoardingEditPageLoader extends StatefulWidget {
  final String serviceId;
  const _BoardingEditPageLoader({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<_BoardingEditPageLoader> createState() => __BoardingEditPageLoaderState();
}

class __BoardingEditPageLoaderState extends State<_BoardingEditPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadBoardingEditPage(widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant _BoardingEditPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      setState(() {
        _loadFuture = _loadBoardingEditPage(widget.serviceId);
      });
    }
  }

  Future<Widget> _loadBoardingEditPage(String serviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage();
    }

    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    final d = snap.docs.first.data();
    final refundPolicy = d['refund_policy'] as Map<String, dynamic>? ?? {};

    return EditServicePage(
      full_address: d['full_address'] as String? ?? '',
      bank_account_num: d['bank_account_num'] as String? ?? '',
      bank_ifsc: d['bank_ifsc'] as String? ?? '',
      serviceId: serviceId,
      description: d['description'] as String? ?? '',
      refundPolicy: refundPolicy.map((k, v) => MapEntry(k, v.toString())),
      walkingFee: d['walking_fee'] as String? ?? '',
      openTime: d['open_time'] as String? ?? '',
      closeTime: d['close_time'] as String? ?? '',
      maxPetsAllowed: d['max_pets_allowed'] as String? ?? '',
      features: (d['features'] as List?)?.cast<String>() ?? [],
      pets: (d['pets'] as List?)?.cast<String>() ?? [],
      street: d['street'] as String? ?? '',
      areaName: d['area_name'] as String? ?? '',
      state: d['state'] as String? ?? '',
      district: d['district'] as String? ?? '',
      postalCode: d['postal_code'] as String? ?? '',
      shopName: d['shop_name'] as String? ?? '',
      shopLocation: d['shop_location'] is GeoPoint
          ? '${(d['shop_location'] as GeoPoint).latitude}, ${(d['shop_location'] as GeoPoint).longitude}'
          : '',
      image_urls: (d['image_urls'] as List?)?.cast<String>() ?? [],
      maxPetsAllowedPerHour: d['max_pets_allowed_per_hour'] as String? ?? '',
      partnerPolicyUrl: d['partner_policy_url'] as String? ?? '', // <-- ADD THIS LINE

    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        return snap.data!;
      },
    );
  }
}