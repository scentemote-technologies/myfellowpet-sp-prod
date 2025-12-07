
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// -----------------------------------------------------------------------------
// App Imports (Please adjust paths if necessary)
// -----------------------------------------------------------------------------
import '../../../screens/Boarding/preloaders/TileImageProvider.dart';
import '../../../screens/Boarding/preloaders/petpreloaders.dart';
import '../../app_colors.dart';
import '../../main.dart'; // For HomeWithTabsState
import '../AppBars/Accounts.dart';
import '../AppBars/AllPetsPage.dart';
import '../AppBars/greeting_service.dart';
import '../Authentication/PhoneSignInPage.dart';
import '../Boarding/OpenCloseBetween.dart';
import '../Boarding/boarding_confirmation_page.dart';
import '../Boarding/boarding_homepage.dart';
import '../Pets/AddPetPage.dart';
import '../Search Bars/search_bar.dart';
import 'AllActiveOrdersPage.dart';

// -----------------------------------------------------------------------------
// Data Model for Services
// -----------------------------------------------------------------------------
class Service {
  final String title;
  final String imagePath;
  final Widget destination;
  final bool isComingSoon;

  const Service({
    required this.title,
    required this.imagePath,
    required this.destination,
    this.isComingSoon = false,
  });
}

// -----------------------------------------------------------------------------
// Home Screen Widget
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Service> _services = [];

  bool _isBannerCollapsed = false;
  bool _bannerHasBeenShown = false;
  Timer? _bannerCollapseTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;


  // Helper to navigate to the Boarding tab in the parent widget
  void _goToBoardingTab() {
    final parent = context.findAncestorStateOfType<HomeWithTabsState>();
    parent?.goToTab(1); // Assumes Boarding is on the second tab (index 1)
  }


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final tileImages = Provider.of<TileImageProvider>(context, listen: false).tileImages;

    // ✅ MODIFICATION: Updated destinations for "coming soon" services
    _services = [
      Service(
        title: 'Boarding',
        imagePath: tileImages['boarding'] ?? '',
        destination: BoardingHomepage(), // This remains an active service
      ),
      Service(
        title: 'Veterinary Care',
        imagePath: tileImages['vet'] ?? '',
        destination: const ComingSoonServicePage(serviceName: 'Veterinary Care'),
        isComingSoon: true,
      ),
      Service(
        title: 'Grooming',
        imagePath: tileImages['grooming'] ?? '',
        destination: const ComingSoonServicePage(serviceName: 'Grooming'),
        isComingSoon: true,
      ),
      Service(
        title: 'Pet Marketplace',
        imagePath: tileImages['shop'] ?? '',
        destination: const ComingSoonServicePage(serviceName: 'Pet Marketplace'),
        isComingSoon: true,
      ),
      Service(
        title: 'Farewell Services',
        imagePath: tileImages['farewell'] ?? '',
        destination: const ComingSoonServicePage(serviceName: 'Farewell Services'),
        isComingSoon: true,
      ),
      Service(
        title: 'Store',
        imagePath: tileImages['store'] ?? '',
        destination: const ComingSoonServicePage(serviceName: 'Store'),
        isComingSoon: true,
      ),
    ];
  }

  @override
  void dispose() {
    _bannerCollapseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(),
              _buildPetAvatarRow(),
              _buildServicesGrid(),
              _buildImageCarousel(),
              _buildFooter(),
              const SliverToBoxAdapter(
                child: SizedBox(height: 180),
              ),
            ],
          ),
          _buildActiveOrderBanner(),
        ],
      ),
    );
  }

  /// Builds the top header with greeting and account icon.
  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: GreetingHeader(
                    greetingColor: AppColors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountsPage())),
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.account_circle, color: AppColors.black, size: 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ✅ MODIFIED: Replace PetSearchBar with a custom-styled InkWell
            InkWell(
              onTap: () {
                // Navigate directly to BoardingHomepage
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BoardingHomepage(initialSearchFocus: true)),
                );
              },
              child: Container(
                width: double.infinity,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: AppColors.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search for Daycare...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  SliverPadding _buildServicesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9, // ✅ TWEAK: Changed from 1.1 to 1.0
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final service = _services[index];
            return _buildServiceTile(service);
          },
          childCount: _services.length,
        ),
      ),
    );
  }
  Widget _buildServiceTile(Service service) {
    return GestureDetector(
      onTap: () {
        if (service.isComingSoon) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => service.destination),
          );
        } else {
          if (service.title == 'Boarding') {
            _goToBoardingTab();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => service.destination),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image takes up the remaining space
              Expanded(
                child: Image.network(
                  service.imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                    );
                  },
                ),
              ),

              // Service Title + Status Icon inline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        service.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      service.isComingSoon
                          ? Icons.watch_later_outlined
                          : Icons.check_circle_rounded,
                      size: 16,
                      color: service.isComingSoon
                          ? Colors.grey.shade600
                          : Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLabel(bool isComingSoon) {
    final String text = isComingSoon ? 'Coming Soon' : 'Active';
    final IconData icon =
    isComingSoon ? Icons.watch_later_outlined : Icons.check_circle_rounded;

    // Gradients
    final Gradient gradient = isComingSoon
        ? LinearGradient(
      colors: [
        Colors.grey.shade700,
        Colors.grey.shade600,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )
        : LinearGradient(
      colors: [
        AppColors.primaryDark,         // your main brand color
        AppColors.primaryDark, // softer shade
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 0.0, top: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// The auto-playing carousel of promotional images.
  SliverToBoxAdapter _buildImageCarousel() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('company_documents').doc('homescreen_images').snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final urls = List<String>.from(snap.data?.data()?['flex'] ?? []);
            if (urls.isEmpty) return const SizedBox.shrink();

            return CarouselSlider.builder(
              itemCount: urls.length,
              itemBuilder: (context, index, realIndex) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: 200,
                autoPlay: true,
                enlargeCenterPage: true,
                viewportFraction: 0.94,
                aspectRatio: 16 / 9,
                autoPlayInterval: const Duration(seconds: 4),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds the signature at the bottom of the screen.
  SliverToBoxAdapter _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'with love,',
              style: GoogleFonts.pacifico(fontSize: 24, color: Colors.grey.shade600),
            ),
            Text(
              'MyFellowPet',
              style: GoogleFonts.pacifico(fontSize: 32, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper function somewhere in your file, outside the class.
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // In the _HomeScreenState class

  Widget _buildActiveOrderBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('service_request_boarding')
          .where('user_id', isEqualTo: uid)
          .where('status', isEqualTo: 'Confirmed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final today = DateTime.now();
        final ongoingDocs = snapshot.data!.docs.where((doc) {
          final dynamic rawDates = doc['selectedDates'];
          if (rawDates is List) {
            final dates = rawDates.whereType<Timestamp>().map((ts) => ts.toDate());
            return dates.any((d) => isSameDay(d, today));
          }
          return false;
        }).toList();

        if (ongoingDocs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _bannerHasBeenShown = false;
                _isBannerCollapsed = true;
              });
            }
          });
          return const SizedBox.shrink();
        }

        if (!_bannerHasBeenShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _bannerCollapseTimer?.cancel();
            _bannerCollapseTimer = Timer(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() {
                  _isBannerCollapsed = true;
                });
              }
            });
            if (mounted) {
              setState(() {
                _bannerHasBeenShown = true;
              });
            }
          });
        }

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.fastOutSlowIn,
          bottom: _isBannerCollapsed ? 16 : 0,
          left: _isBannerCollapsed ? null : 0,
          right: _isBannerCollapsed ? 16 : 0,
          child: GestureDetector(
            onTap: () {
              // This detector now ONLY handles EXPANDING the banner.
              // It does nothing when the banner is already expanded.
              if (_isBannerCollapsed) {
                _bannerCollapseTimer?.cancel();
                setState(() => _isBannerCollapsed = false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: _isBannerCollapsed ? 64 : null,
              height: _isBannerCollapsed ? 64 : null,
              decoration: BoxDecoration(
                color: Colors.transparent, // Always transparent now
                borderRadius: BorderRadius.circular(_isBannerCollapsed ? 32 : 0),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: _isBannerCollapsed
                    ? _buildCollapsedBanner(ongoingDocs.length)
                // Pass the entire list of docs to the expanded banner
                    : _buildExpandedBanner(ongoingDocs),
              ),
            ),
          ),
        );
      },
    );
  }

  // In _HomeScreenState class

  // In the _HomeScreenState class

  // In the _HomeScreenState class

  // REPLACE your entire _buildExpanded-Banner method with this one

  Widget _buildExpandedBanner(List<QueryDocumentSnapshot> ongoingDocs) {
    // Get the data from the list
    final firstDoc = ongoingDocs.first;
    final totalOngoingOrders = ongoingDocs.length;
    final data = firstDoc.data() as Map<String, dynamic>;

    // This part remains the same, just extracting basic info
    final petImages = (data['pet_images'] as List<dynamic>? ?? []);
    final petNamesList = (data['pet_name'] as List<dynamic>? ?? []);
    final shopName = data['shopName'] ?? 'Provider';
    final shopImageUrl = data['shop_image'] as String? ?? '';
    final openTime = data['openTime'] ?? 'N/A';
    final closeTime = data['closeTime'] ?? 'N/A';
    final rawDates = data['selectedDates'];
    final isStartPinUsed = data['isStartPinUsed'] as bool? ?? false;
    String statusText = 'Ongoing Stay';
    IconData statusIcon = Icons.night_shelter_outlined;
    String? pickupMessage;
    int currentDay = 0;
    int totalDays = 0;
    final today = DateTime.now();

    final dates = (rawDates is List)
        ? rawDates.whereType<Timestamp>().map((ts) => ts.toDate()).toList()
        : <DateTime>[];

    if (dates.isNotEmpty) {
      totalDays = dates.length;
      dates.sort();
      final todayIndex = dates.indexWhere((d) => isSameDay(d, today));
      if (todayIndex != -1) currentDay = todayIndex + 1;
      final bool isFirstDay = isSameDay(dates.first, today);
      final bool isLastDay = isSameDay(dates.last, today);
      if (isFirstDay && !isStartPinUsed) {
        statusText = 'Drop-off: $openTime - $closeTime';
        statusIcon = Icons.login_rounded;
      } else if (isLastDay) {
        statusText = 'Ongoing Stay';
        statusIcon = Icons.night_shelter_outlined;
        pickupMessage = 'Pick-up tomorrow at $closeTime';
      }
    }

    // --- ⬇️ MODIFICATION: Capitalize Pet Name ---
    String petDisplayName;
    if (petNamesList.isEmpty) {
      petDisplayName = 'Your Pet';
    } else {
      String firstName = petNamesList.first.toString();
      // Ensure the string is not empty before capitalizing
      String capitalizedFirstName = firstName.isNotEmpty
          ? "${firstName[0].toUpperCase()}${firstName.substring(1)}"
          : "";

      if (petNamesList.length > 1) {
        petDisplayName = '$capitalizedFirstName (+${petNamesList.length - 1} more)';
      } else {
        petDisplayName = capitalizedFirstName;
      }
    }
    // --- ⬆️ MODIFICATION END ---

    return Container(
      key: const ValueKey('expanded_banner'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () async {
              if (ongoingDocs.length > 1) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AllActiveOrdersPage(docs: ongoingDocs)));
              } else {
                // This data fetching logic remains the same
                final data = firstDoc.data() as Map<String, dynamic>? ?? {};
                final costBreakdown = data['cost_breakdown'] as Map<String, dynamic>? ?? {};
                final foodCost = double.tryParse(costBreakdown['meals_cost']?.toString() ?? '0') ?? 0.0;
                final walkingCost = double.tryParse(costBreakdown['daily_walking_cost']?.toString() ?? '0') ?? 0.0;
                final transportCost = double.tryParse(costBreakdown['transport_cost']?.toString() ?? '0') ?? 0.0;
                final petIds = List<String>.from(data['pet_id'] ?? []);
                final fullAddress = data['fullAddress'] ?? 'Address not found';
                final spLocation = data['sp_location'] as GeoPoint? ?? const GeoPoint(0, 0);
                final Map<String, int> rates = {};
                final Map<String, int> mealRates = {};
                final Map<String, int> walkingRates = {};
                final petSizesList = data['pet_sizes'] as List<dynamic>? ?? [];

                for (final petInfo in petSizesList) {
                  final petData = petInfo as Map<String, dynamic>;
                  final petId = petData['id'] as String?;
                  final price = (petData['price'] as num?)?.toInt() ?? 0;
                  final mealFee = (petData['mealFee'] as num?)?.toInt() ?? 0;
                  final walkFee = (petData['walkFee'] as num?)?.toInt() ?? 0;
                  if (petId != null) {
                    rates[petId] = price;
                    mealRates[petId] = mealFee;
                    walkingRates[petId] = walkFee;
                  }
                }

                final Map<String, Map<String, dynamic>> perDayServices = {};
                final petServicesSnapshot =
                await firstDoc.reference.collection('pet_services').get();

                for (var petDoc in petServicesSnapshot.docs) {
                  perDayServices[petDoc.id] = petDoc.data();
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfirmationPage(
                      perDayServices: perDayServices,
                      petIds: petIds,
                      foodCost: foodCost,
                      walkingCost: walkingCost,
                      transportCost: transportCost,
                      rates: rates,
                      mealRates: mealRates,
                      walkingRates: walkingRates,
                      fullAddress: fullAddress,
                      sp_location: spLocation,
                      shopName: shopName,
                      fromSummary: false,
                      shopImage: shopImageUrl,
                      selectedDates: dates,
                      totalCost:
                      (data['original_total_amount'] as num?)?.toDouble() ?? 0.0,
                      petNames: List<String>.from(data['pet_name'] ?? []),
                      openTime: data['openTime'] ?? '',
                      closeTime: data['closeTime'] ?? '',
                      bookingId: firstDoc.id,
                      buildOpenHoursWidget: buildOpenHoursWidget(
                          data['openTime'] ?? '', data['closeTime'] ?? '', dates),
                      sortedDates: List<DateTime>.from(dates)..sort(),
                      petImages: List<String>.from(data['pet_images'] ?? []),
                      serviceId: data['service_id'] ?? '',
                    ),
                  ),
                );
              }
            },
            // The rest of the widget's layout remains the same
            child: Padding(
              padding: const EdgeInsets.only(right: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Your Active Stay",
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      if (totalOngoingOrders > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accentColor)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('+${totalOngoingOrders - 1} more',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 10, color: AppColors.accentColor)
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(shopName,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            CircleAvatar(
                                radius: 16,
                                backgroundImage: shopImageUrl.isNotEmpty
                                    ? NetworkImage(shopImageUrl)
                                    : null,
                                child: shopImageUrl.isEmpty
                                    ? const Icon(Icons.storefront, size: 16)
                                    : null),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      if (petImages.isNotEmpty)
                        _buildOverlappingPetAvatars(petImages)
                      else
                        _buildNoPetIndicator(),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(petDisplayName, // This now uses the capitalized name
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon,
                                  color: AppColors.primaryColor, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Text(statusText,
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryColor))),
                            ],
                          ),
                        ),
                      ),
                      if (totalDays > 0) ...[
                        const SizedBox(width: 12),
                        Text('Day $currentDay of $totalDays',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700))
                      ],
                    ],
                  ),
                  if (totalDays > 1) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                            value: currentDay / totalDays,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor),
                            minHeight: 6)),
                  ],
                  if (pickupMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.grey.shade700, size: 16),
                          const SizedBox(width: 8),
                          Text(pickupMessage,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppColors.black, size: 22),
              onPressed: () {
                setState(() {
                  _isBannerCollapsed = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingPetAvatars(List<dynamic> petImages) {
    const double avatarRadius = 20;
    const double overlap = 15;
    final itemsToShow = petImages.length > 2 ? 2 : petImages.length;
    if (petImages.isEmpty) {
      return const CircleAvatar(radius: avatarRadius, child: Icon(Icons.pets));
    }

    return SizedBox(
      width: (itemsToShow * (avatarRadius * 2 - overlap)) + (petImages.length > itemsToShow ? avatarRadius * 2 : overlap),
      height: avatarRadius * 2,
      child: Stack(
        children: [
          ...List.generate(itemsToShow, (index) {
            return Positioned(
              left: index * (avatarRadius * 2 - overlap),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: avatarRadius - 1.5,
                  backgroundImage: CachedNetworkImageProvider(petImages[index]),
                ),
              ),
            );
          }),
          if (petImages.length > itemsToShow)
            Positioned(
              left: itemsToShow * (avatarRadius * 2 - overlap),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.primaryColor,
                child: Text(
                  '+${petImages.length - itemsToShow}',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // In the _HomeScreenState class

  // In the _HomeScreenState class

  Widget _buildCollapsedBanner(int orderCount) {
    return ScaleTransition(
      key: const ValueKey('collapsed_banner'),
      scale: _pulseAnimation,
      child: Container(
        width: 60,  // ✅ Reduced from 68
        height: 60, // ✅ Reduced from 68
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor, // Lighter shade at the top
              AppColors.primaryDark,  // Darker shade at the bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            orderCount.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24, // ✅ Reduced from 26 for better balance
              shadows: const [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAddPetButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add your first pet!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddPetPage())),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: const Icon(Icons.add, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetList(List<Pet> pets) {
    const int maxShown = 5;
    final displayList = pets.take(maxShown).toList();
    final extraCount = pets.length > maxShown ? pets.length - maxShown : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border( // Add the border here
            bottom: BorderSide(
              color: AppColors.primary.withOpacity(0.5),
              width: 3.0,
            ),
            right: BorderSide(
              color: AppColors.primary.withOpacity(0.5),
              width: 3.0,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'Your\nPets',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                  height: 1.2,
                ),
              ),
            ),
            const VerticalDivider(color: Colors.black26, thickness: 1, indent: 10, endIndent: 10),
            const SizedBox(width: 6),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length + (extraCount > 0 ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == displayList.length) {
                    return _buildExtraPetsIndicator(extraCount);
                  }
                  final pet = displayList[index];
                  return _buildPetAvatar(pet);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildPetAvatarRow() {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<Pet>>(
        stream: PetService.instance.watchMyPets(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          final pets = snapshot.data!;
          return pets.isEmpty ? _buildAddPetButton() : _buildPetList(pets);
        },
      ),
    );
  }

  Widget _buildPetAvatar(Pet pet) {
    return Tooltip(
      message: pet.name,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllPetsPage())),
        child: Padding(
          padding: const EdgeInsets.only(right: 10.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46, // Slightly larger for the border
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryColor, // The background color for the border
                  ),
                  child: Center(
                    child: CircleAvatar(
                      radius: 21, // Slightly smaller to show the border
                      backgroundColor: Colors.white,
                      backgroundImage: CachedNetworkImageProvider(
                        pet.imageUrl.isNotEmpty ? pet.imageUrl : 'https://via.placeholder.com/150',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: A stylized indicator for when there are no pet images
  // NEW: A stylized indicator for when there are no pet images
  Widget _buildNoPetIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primaryColor,
            child: const Icon(
              Icons.pets,
              size: 24,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Your Pet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildExtraPetsIndicator(int count) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AllPetsPage())),
      child: Padding(
        padding: const EdgeInsets.only(right: 10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade400, width: 1.8),
              ),
              child: Center(
                child: Text(
                  '+$count',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'More',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _auth = FirebaseAuth.instance;
  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PhoneAuthPage()),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// NEW: Coming Soon Page Widget
// -----------------------------------------------------------------------------

class ComingSoonServicePage extends StatefulWidget {
  final String serviceName;

  const ComingSoonServicePage({Key? key, required this.serviceName}) : super(key: key);

  @override
  _ComingSoonServicePageState createState() => _ComingSoonServicePageState();
}

class _ComingSoonServicePageState extends State<ComingSoonServicePage>
    with SingleTickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.serviceName),
        backgroundColor: Colors.white,
        elevation: 0, // A flatter, more modern look
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Stack(
        children: [
          // Subtle background decorative shapes
          Positioned(
            top: -100,
            left: -100,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: AppColors.primaryColor.withOpacity(0.05),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -150,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: AppColors.accentColor.withOpacity(0.05),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rocket_launch_outlined,
                    size: 100,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(height: 32),

                  // Main Title
                  Text(
                    "Launching Soon!",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Subtitle
                  Text(
                    "Our amazing '${widget.serviceName}' service is getting ready. We're working hard to bring it to you and your furry friends!",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Call-to-Action Button
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.textPrimary,
                          content: Text(
                            "You're on the list! We'll notify you first.",
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                    label: Text("Notify Me", style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: AppColors.primaryColor.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// -----------------------------------------------------------------------------
// Blinking Button Widget (Unchanged)
// -----------------------------------------------------------------------------
class BlinkingButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const BlinkingButton({required this.label, required this.onTap, Key? key}) : super(key: key);

  @override
  State<BlinkingButton> createState() => _BlinkingButtonState();
}

class _BlinkingButtonState extends State<BlinkingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.4).animate(_controller),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accentColor),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.poppins(
              color: AppColors.accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}