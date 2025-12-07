// lib/screens/Boarding/boarding_homepage.dart

import 'dart:math';

import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../screens/Boarding/preloaders/BoardingCardsForBoardingHomePage.dart';
import '../../../screens/Boarding/preloaders/distance_provider.dart';
import '../../../screens/Boarding/preloaders/favorites_provider.dart';
import '../../../screens/Boarding/preloaders/hidden_services_provider.dart';
import '../../app_colors.dart';
import '../../main.dart';
import '../AppBars/Accounts.dart';
import '../AppBars/greeting_service.dart';
import '../Search Bars/live_searchbar.dart';
import '../Search Bars/search_bar.dart';
import 'HeaderMedia.dart';
import 'boarding_servicedetailspage.dart';
import 'hidden_boarding_services_page.dart';

void _showHideConfirmationDialog(
    BuildContext context,
    String serviceId,
    bool isHidden,
    HiddenServicesProvider provider,
    ) {
  showDialog(
    context: context,
    barrierDismissible: true, // Allow dismissing by tapping outside
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icon
              Icon(
                isHidden ? Icons.refresh_rounded : Icons.block_rounded,
                size: 48,
                color: isHidden ? AppColors.primaryColor : Colors.red.shade700,
              ),
              const SizedBox(height: 20),

              // 2. Title
              Text(
                isHidden ? 'Make Service Visible?' : 'Hide This Service?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // 3. Subtitle
              Text(
                isHidden
                    ? 'This service will reappear in your search results.'
                    : 'You won\'t see this service in your feed anymore. You can un-hide it later from your account settings.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Dismiss the dialog first
                        Navigator.of(dialogContext).pop();

                        // Then, perform the action
                        provider.toggle(serviceId);

                        // And finally, show the SnackBar feedback
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.grey.shade800,
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                              isHidden ? 'Service is now visible.' : 'Service has been hidden.',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            action: SnackBarAction(
                              label: 'Undo',
                              textColor: AppColors.accentColor,
                              onPressed: () => provider.toggle(serviceId),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isHidden ? AppColors.primaryColor : Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        isHidden ? 'Yes, Show' : 'Yes, Hide',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Gradient _runTypeGradient(String type) {
  switch (type) {
    case 'Home Run':
      return LinearGradient(
        colors: [
          const Color(0xFF556B2F),
          const Color(0xFFBADE7D),
        ],
      );
    case 'Business Run':
      return LinearGradient(
        colors: [
          const Color(0xFF4682B4),
          const Color(0xFF7EB6E5),
        ],
      );
    case 'NGO Run':
      return LinearGradient(
        colors: [
          const Color(0xFFFF5252),
          const Color(0xFFFF8A80),
        ],
      );
    case 'Govt Run':
      return LinearGradient(
        colors: [
          const Color(0xFFB0BEC5),
          const Color(0xFF90A4AE),
        ],
      );
    case 'Vet Run':
      return LinearGradient(
        colors: [
          const Color(0xFFCE93D8).withOpacity(0.85),
          const Color(0xFFBA68C8).withOpacity(0.85),
        ],
      );
    default:
      return LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]);
  }
}


String _runTypeLabel(String type) {
  switch (type) {
    case 'Home Run':      return 'Home Run';
    case 'Business Run':  return 'Business';
    case 'NGO Run':       return 'NGO';
    case 'Govt Run':      return 'Govt Run';
    case 'Vet Run':       return 'Vet Run';
    default:               return type;
  }
}


Widget _buildInfoRow(String text, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, size: 17, color: color), // was 16
      const SizedBox(width: 4),
      Expanded( // ⬅️ makes sure the text uses remaining space
        child: Text(
          text,
          maxLines: 1, // single line only
          overflow: TextOverflow.ellipsis, // show "..." if too long
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    ],
  );
}

Widget _buildPetChip(String pet) {
  // Capitalize first letter
  String displayText = pet.isNotEmpty
      ? pet[0].toUpperCase() + pet.substring(1).toLowerCase()
      : '';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: // In your _buildPetChip widget's decoration
    BoxDecoration(
      color: AppColors.primaryColor.withOpacity(0.1), // Light teal background
      border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(8),
    ),

    child: Text(
        displayText,
        style: const // And for the chip's text style
        TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600, // Slightly bolder
          color: AppColors.primaryColor, // Teal text
        )
    ),
  );
}

Future<Map<String, dynamic>> fetchRatingStats(String serviceId) async {
  final coll = FirebaseFirestore.instance
      .collection('public_review')
      .doc('service_providers')
      .collection('sps')
      .doc(serviceId)
      .collection('reviews');

  final snap = await coll.get();
  // Extract only ratings > 0
  final ratings = snap.docs
      .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
      .where((r) => r > 0)
      .toList();

  final count = ratings.length;
  final avg = count > 0
      ? ratings.reduce((a, b) => a + b) / count
      : 0.0;

  return {
    'avg': avg.clamp(0.0, 5.0),
    'count': count,
  };
}

enum FilterTab { price, species }

class PetType {
  final String id;
  final bool display;

  PetType({required this.id, required this.display});
}

class _PriceRangePainter extends CustomPainter {
  final String? selectedRange;
  final List<String> options;

  _PriceRangePainter({required this.selectedRange, required this.options});

  @override
  void paint(Canvas canvas, Size size) {
    final faintPaint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final activePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final y = size.height / 2;
    final fullPath = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    canvas.drawPath(fullPath, faintPaint);

    if (selectedRange != null && options.contains(selectedRange)) {
      final index = options.indexOf(selectedRange!);
      final segmentWidth = size.width / options.length;
      final startX = index * segmentWidth;
      final endX = (index + 1) * segmentWidth;
      final activePath = Path()
        ..moveTo(startX, y)
        ..lineTo(endX, y);
      canvas.drawPath(activePath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BoardingHomepage extends StatefulWidget {
  final bool initialSearchFocus;
  final Map<String, dynamic>? initialBoardingFilter;

  const BoardingHomepage({
    Key? key,
    this.initialSearchFocus = false,
    this.initialBoardingFilter, // 💡 CORRECTED: Use initialBoardingFilter here.// 💡 ADD THIS LINE to the constructor list
  }) : super(key: key);

  @override
  _BoardingHomepageState createState() => _BoardingHomepageState();
}

class _BoardingHomepageState extends State<BoardingHomepage> with TickerProviderStateMixin {
  bool _locationPermissionDenied = false;
  bool _showOffersOnly = false; // New state variable
  List<String> pets = [];
  final FocusNode _searchFocusNode = FocusNode();

  late TabController _tabController; // ADD THIS LINE

  // ① NEW: store each service’s max_pets_allowed (from the parent doc)
  final Map<String, int> _serviceMaxAllowed = {};

  bool _showCertifiedOnly = false;
  Set<String> _selectedRunTypes = {};

  late String _greeting;
  late String _mediaUrl;

  // No longer needed
  // final TextEditingController _searchController = TextEditingController();

  String _searchQuery = ''; // The state variable for the search query

  // This is the new method to handle search query changes from the PetSearchBar
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  late Timer _timer;
  late Future<void> _videoInit;
  FilterTab _filterTab = FilterTab.price;

  // ─── New: Price‐range state ──────────────────────────────────
  double _minPrice = 0;
  double _maxPrice = 1000;
  RangeValues _selectedPriceRange = const RangeValues(0, 1000);
  late ScrollController _filterScrollController;

  int _filterPetCount = 0;
  List<DateTime> _filterDates = [];

  bool _priceFilterLoaded = false;

  final List<String> _placeholders = [
    "Multispeciality Hospitals",
    "Vaccines",
    "Best Vets",
    "Pet Clinics",
  ];
  double km = 0.0;

  int _currentIndex = 1;

  void _onTap(int newIndex) {
    if (newIndex == _currentIndex) return;
    setState(() => _currentIndex = newIndex);
  }

  bool _showFavoritesOnly = false;

  String address = '';
  Position? _currentPosition;
  List<PetType> _petTypes = [];
  final ScrollController _drawerScrollController = ScrollController();

  Set<String> _selectedPetTypes = {};
  String _selectedDistanceOption = ''; // New distance filter selection
  bool isLiked = false;
  Set<String> likedServiceIds = {};
  Set<String> _hiddenServiceIds = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double distanceKm = 0.0;

  final List<String> _priceOptions = ['<1000', '3000>=1000', '>3000'];

  List<String> get _petOptions =>
      _petTypes.map((pt) => _capitalize(pt.id)).toList();

  final List<String> _distanceOptions = [
    '<5 km',
    '<10 km',
    '<15 km',
    '>15 km'
  ]; // New filter options

  int _placeholderIndex = 0;

  final ValueNotifier<int> _placeholderNotifier = ValueNotifier<int>(0);

  String _speciesSearchQuery = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _loadPriceFilter() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('fees')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;

        // The image you attached shows:
        //   boarding_price_filter: { min: "300", max: "10000" }
        final bpFilter = data['boarding_price_filter'] as Map<String, dynamic>?;

        if (bpFilter != null) {
          // parse min / max as ints
          final minStr = bpFilter['min']?.toString() ?? '0';
          final maxStr = bpFilter['max']?.toString() ?? '0';

          final parsedMin = int.tryParse(minStr) ?? 0;
          final parsedMax = int.tryParse(maxStr) ?? 0;

          if (parsedMax > parsedMin) {
            setState(() {
              _minPrice = parsedMin.toDouble();
              _maxPrice = parsedMax.toDouble();
              _selectedPriceRange = RangeValues(
                _minPrice,
                _maxPrice,
              );
              _priceFilterLoaded = true;
            });
          } else {
            setState(() {
              _minPrice = 0;
              _maxPrice = 0;
              _selectedPriceRange = const RangeValues(0, 0);
              _priceFilterLoaded = false;
            });
          }
        }
      }
    } catch (e) {
      // In case of error, we can leave _priceFilterLoaded as false.
      setState(() {
        _priceFilterLoaded = false;
      });
      debugPrint('Error loading price filter: $e');
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = ''; // Reset the search query as well
      _showFavoritesOnly = false;
      _selectedPetTypes.clear();
      _selectedDistanceOption = '';
      _selectedPriceRange = RangeValues(_minPrice, _maxPrice);

      _filterPetCount = 0;
      _filterDates.clear();

      _showCertifiedOnly = false;
      _selectedRunTypes.clear();

      // New: Reset the offer price filter state
      _showOffersOnly = false;
    });
  }

  Future<String> _getUserName() async {
    User? user = _auth.currentUser;
    if (user != null) {
      String uid = user.uid;
      final snapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .get();
      if (snapshot.docs.isNotEmpty) {
        address = snapshot.docs.first['address'];
        return 'Hello ${snapshot.docs.first['name']}';
      }
    }
    return 'Hello Guest';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final header = Provider.of<HeaderData>(context);
    _greeting = header.greeting;
    _mediaUrl = header.mediaUrl;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAllBookingCounts();
    });

    final initialFilter = (widget.initialBoardingFilter as Map<String, dynamic>?);
    if (initialFilter != null && initialFilter.isNotEmpty) {
      final petCount = initialFilter['petCount'] as int? ?? 0;
      final dates = initialFilter['dates'] as List<DateTime>? ?? [];

      if (petCount > 0 && dates.isNotEmpty) {
        // 💡 ACTION: Setting the state variables applies the filter immediately
        // because the main build method depends on these state variables.
        setState(() {
          _filterPetCount = petCount;
          _filterDates = dates;
        });

        // ❌ REMOVED: The following block that opened the dialog is removed:
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   _showAvailabilityFilterDialog();
        // });
      }
    }

  _tabController = TabController(length: 2, vsync: this);

    _tabController = TabController(length: 2, vsync: this);

    _filterScrollController = ScrollController();

    _loadPriceFilter();
    _fetchCurrentLocation();
    _fetchPetTypes();

    if (widget.initialSearchFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }

    // The listener on _searchController is no longer needed here
    // as the new PetSearchBar widget will manage it and pass the value
    // via the _handleSearch callback.

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
      _placeholderNotifier.value = _placeholderIndex;
    });
  }



  Future<void> _fetchPetTypes() async {
    final snap = await _firestore.collection('pet_types').get();
    setState(() {
      _petTypes = snap.docs.map((d) {
        final data = d.data();
        return PetType(
          id: d.id,
          display: (data['display'] ?? false) as bool,
        );
      }).toList();
    });
  }

  // helper to uppercase first letter
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // In _BoardingHomepageState class

  // In _BoardingHomepageState class



  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if(mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if(mounted) {
        setState(() {
          _currentPosition = position;
          _locationPermissionDenied = false;
        });

        // ✅ TWEAK HERE: Call the new method in your provider
        // This will update the distances on all cards and refresh the UI.
        context.read<BoardingCardsProvider>().recalculateCardDistances(position);
      }

    } catch (e) {
      if(mounted) setState(() => _locationPermissionDenied = true);
    }
  }

  Future<void> toggleLike(String serviceId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      print('No user is logged in');
      return;
    }
    setState(() {
      if (likedServiceIds.contains(serviceId)) {
        likedServiceIds.remove(serviceId);
      } else {
        likedServiceIds.add(serviceId);
      }
    });

    final userPreferencesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('user_preferences')
        .doc('boarding');
    final userPreferencesDoc = await userPreferencesRef.get();
    List<dynamic> likedServices = userPreferencesDoc.exists
        ? List.from(userPreferencesDoc.get('liked') ?? [])
        : [];
    if (likedServices.contains(serviceId)) {
      likedServices.remove(serviceId);
    } else {
      likedServices.add(serviceId);
    }
    if (userPreferencesDoc.exists) {
      await userPreferencesRef.update({'liked': likedServices});
    } else {
      await userPreferencesRef.set({
        'liked': [serviceId]
      });
    }
  }

  Future<void> checkIfLiked(String serviceId) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    final userPreferencesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('user_preferences')
        .doc('boarding');
    final userPreferencesDoc = await userPreferencesRef.get();
    if (userPreferencesDoc.exists) {
      List<dynamic> likedServices =
      List.from(userPreferencesDoc.get('liked') ?? []);
      setState(() {
        isLiked = likedServices.contains(serviceId);
        print('Service $serviceId liked status: $isLiked');
      });
    } else {
      print('User preferences document does not exist. Creating a new one...');
      await userPreferencesRef.set({
        'liked': [serviceId]
      });
      setState(() {
        isLiked = true;
      });
    }
  }

  void _showWarningDialog({required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Color(0xFF00C2CB)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C2CB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('OK',
                    style: TextStyle(color: Color(0xFF00C2CB))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _hideService(String serviceId) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    final userPreferencesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('user_preferences')
        .doc('boarding');
    final userPreferencesDoc = await userPreferencesRef.get();
    List<dynamic> hiddenServices = [];
    if (userPreferencesDoc.exists && userPreferencesDoc.data() != null) {
      final data = userPreferencesDoc.data() as Map<String, dynamic>;
      if (data.containsKey('hidden')) {
        hiddenServices = List.from(data['hidden']);
      }
    }
    if (!hiddenServices.contains(serviceId)) {
      hiddenServices.add(serviceId);
      await userPreferencesRef
          .set({'hidden': hiddenServices}, SetOptions(merge: true));
    }
    setState(() {
      _hiddenServiceIds.add(serviceId);
    });
    // Show the popup message immediately once service is hidden.
    _showWarningDialog(
      message:
      'This service has been hidden.\nTo un-hide, go to Accounts → Hidden Services.',
    );
  }

  // New method: Distance Filter Dialog.
  Future<void> _showDistanceFilterDialog() async {
    double tempMaxKm = _selectedDistanceOption.isNotEmpty
        ? double.parse(_selectedDistanceOption.replaceAll(' km', ''))
        : 10.0;

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: // ← wrap the entire content in StatefulBuilder
          StatefulBuilder(
            builder: (context, setStateDialog) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFF5F3FF)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Radius Filter',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Slider + value
                    Text(
                      '${tempMaxKm.toStringAsFixed(0)} km',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Slider(
                      min: 1,
                      max: 100,
                      divisions: 99,
                      value: tempMaxKm,
                      label: '${tempMaxKm.toStringAsFixed(0)} km',
                      onChanged: (v) => setStateDialog(() => tempMaxKm = v),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        // ─── Default (clears filter) ───────────────────────
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFF4F46E5)),
                            ),
                            onPressed: () {
                              // Clear the distance filter and close
                              setState(() => _selectedDistanceOption = '');
                              Navigator.pop(context);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Default',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // ─── Apply Button ────────────────────────────
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              // match the flat look of Default
                              alignment: Alignment.center,
                            ),
                            onPressed: () {
                              setState(() => _selectedDistanceOption =
                              '${tempMaxKm.toStringAsFixed(0)} km');
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Apply',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                // white on blue so it’s readable
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getPriceEmoji(String priceRange) {
    final value = priceRange.toLowerCase();
    if (value.contains('under')) return '💰';
    if (value.contains('-')) return '💸';
    if (value.contains('over')) return '🤑';
    return '₹';
  }

  bool _matchesPriceRange(int price) {
    return price >= _selectedPriceRange.start.toInt() &&
        price <= _selectedPriceRange.end.toInt();
  }

  Widget _buildFilterChip({
    required VoidCallback onTap,
    required Widget icon,
    required String label,
    bool isActive = false,
    bool isAccent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        elevation: isActive ? 3 : 0, // Soft elevation only when active
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isAccent
                  ? AppColors.onPrimary.withOpacity(0.1)
                  : Colors.white, // Lighter neutral background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : Colors.grey.shade300,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 16,
                    color: isActive ? AppColors.primary : Colors.grey.shade600,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    _drawerScrollController.dispose(); // ← dispose the drawer’s controller here
    _placeholderNotifier.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.45;
    final paddingTop = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background video or image
          HeaderMedia(),
          // Semi-transparent overlay
          Container(color: Colors.transparent),
          // Foreground content
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 20,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting only, no avatar here
                const GreetingHeader(
                  greetingColor: Colors.white,
                ),

                const SizedBox(height: 10),

                // Pet search bar
                // ✅ Corrected: Pass the _searchFocusNode to LiveSearchBar
                LiveSearchBar(
                  onSearch: _handleSearch,
                  focusNode: _searchFocusNode,
                ),
                const SizedBox(height: 7),
              ],
            ),
          ),

          // Account icon with its own top position
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, // independent top padding
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AccountsPage()),
              ),
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<String> _getBoardingImage() async {
    final doc = await _firestore
        .collection('company_documents')
        .doc('homescreen_images')
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      return data['boarding'] ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final availabilityActive = _filterPetCount > 0 && _filterDates.isNotEmpty;

    final filteredPetTypes = _petTypes.where((pt) {
      final name = _capitalize(pt.id).toLowerCase();
      return name.contains(_speciesSearchQuery.toLowerCase());
    }).toList();

    return DefaultTabController(
      length: 2, // We have two tabs: Overnight and Day Care
      child:  Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,

        // ─── Filter Drawer ─────────────────────────────────
        endDrawer: Drawer(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(left: Radius.circular(0)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── HEADER ───────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                            ),
                            child: Icon(Icons.close_rounded,
                                size: 22, color: Colors.grey.shade700),
                          ),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── SCROLLABLE CONTENT ───────────────────────────
                Expanded(
                  child: Scrollbar(
                    controller: _filterScrollController,
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(2),
                    child: ListView(
                      controller: _filterScrollController,
                      primary: false,
                      padding: const EdgeInsets.only(top: 8),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // ⭐️ REMOVED Favorites Only ListTile
                              ListTile(
                                leading: Icon(Icons.verified_user_outlined, color: _showCertifiedOnly ? const Color(0xFF25ADAD) : Colors.grey.shade700),
                                title: Text(
                                  'MFP Certified Only',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: _showCertifiedOnly ? const Color(0xFF25ADAD) : Colors.grey.shade800,
                                  ),
                                ),
                                trailing: Switch(
                                  value: _showCertifiedOnly,
                                  onChanged: (val) => setState(() => _showCertifiedOnly = val),
                                  activeColor: const Color(0xFF25ADAD),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ─ Hidden Services Section ─
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 0),
                            title: Text(
                              'Hidden Services',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right,
                                color: Colors.grey.shade800),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => HiddenServicesPage()),
                              );
                            },
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                            title: Text(
                              'Run Type',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _selectedRunTypes.isNotEmpty ? const Color(0xFF25ADAD) : Colors.grey.shade800,
                              ),
                            ),
                            trailing: _selectedRunTypes.isNotEmpty
                                ? CircleAvatar(
                              backgroundColor: const Color(0xFF25ADAD),
                              radius: 12,
                              child: Text(
                                _selectedRunTypes.length.toString(),
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            )
                                : null,
                            childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                            children: [
                              ...['Home Run', 'Business Run', 'NGO Run', 'Govt Run', 'Vet Run'].map((type) {
                                return CheckboxListTile(
                                  activeColor: const Color(0xFF25ADAD),
                                  title: Text(type, style: GoogleFonts.poppins()),
                                  value: _selectedRunTypes.contains(type),
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedRunTypes.add(type);
                                      } else {
                                        _selectedRunTypes.remove(type);
                                      }
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                        ),

                        // ─ Price Section (with dynamic RangeSlider) ─
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            tilePadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                            // Show a badge/icon on the right if price range has been modified
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Price',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: (_selectedPriceRange.start.toInt() !=
                                        _minPrice.toInt() ||
                                        _selectedPriceRange.end.toInt() !=
                                            _maxPrice.toInt())
                                        ? const Color(
                                        0xFF25ADAD) // highlight if active
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                if (_selectedPriceRange.start.toInt() !=
                                    _minPrice.toInt() ||
                                    _selectedPriceRange.end.toInt() !=
                                        _maxPrice.toInt())
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25ADAD),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_selectedPriceRange.start.toInt()} - ${_selectedPriceRange.end.toInt()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            childrenPadding:
                            const EdgeInsets.fromLTRB(24, 8, 24, 16),
                            iconColor: const Color(0xFF25ADAD),
                            children: [
                              // Show loader while Firestore fetch is in progress:
                              if (!_priceFilterLoaded)
                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFF25ADAD),
                                    ),
                                  ),
                                )
                              else ...[
                                // Show RangeSlider once min/max are loaded
                                Text(
                                  'Select price range:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Display current numeric labels above slider
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${_minPrice.toInt()}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                    ),
                                    Text(
                                      '₹${_maxPrice.toInt()}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                RangeSlider(
                                  values: _selectedPriceRange,
                                  min: _minPrice.toDouble(),
                                  max: _maxPrice.toDouble(),
                                  divisions:
                                  ((_maxPrice - _minPrice) ~/ 100).toInt(),
                                  // Each tick represents ₹100
                                  labels: RangeLabels(
                                    '₹${_selectedPriceRange.start.toInt()}',
                                    '₹${_selectedPriceRange.end.toInt()}',
                                  ),
                                  activeColor: const Color(0xFF25ADAD),
                                  inactiveColor: Colors.grey.shade300,
                                  onChanged: (newRange) {
                                    setState(() {
                                      _selectedPriceRange = RangeValues(
                                        newRange.start.clamp(_minPrice.toDouble(),
                                            _maxPrice.toDouble()),
                                        newRange.end.clamp(_minPrice.toDouble(),
                                            _maxPrice.toDouble()),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    // “Clear” button resets to full-range
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: const Color(0xFF25ADAD)
                                                .withOpacity(0.5)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 16),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedPriceRange = RangeValues(
                                            _minPrice.toDouble(),
                                            _maxPrice.toDouble(),
                                          );
                                        });
                                      },
                                      child: Text(
                                        'Clear',
                                        style: GoogleFonts.poppins(
                                            color: const Color(0xFF25ADAD)),
                                      ),
                                    ),
                                    // “Apply” closes drawer and keeps the selected range
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25ADAD),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 16),
                                      ),
                                      onPressed: () {
                                        // _selectedPriceRange already holds the chosen min/max.
                                        Navigator.pop(
                                            context); // close the drawer
                                      },
                                      child: Text(
                                        'Apply',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ─ Species Section ─
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            tilePadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                            // Show a badge/icon on the right if any species are selected
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Species',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedPetTypes.isNotEmpty
                                        ? const Color(
                                        0xFF25ADAD) // highlight if active
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                if (_selectedPetTypes.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25ADAD),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_selectedPetTypes.length}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.only(
                                left: 24, right: 24, bottom: 8),
                            iconColor: const Color(0xFF25ADAD),
                            children: [
                              // ─── Search Field ───────────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => _speciesSearchQuery = v),
                                  decoration: InputDecoration(
                                    hintText: 'Search species',
                                    prefixIcon: Icon(Icons.search,
                                        color: const Color(0xFF25ADAD)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ),

                              // ─── Filtered List ───────────────────────────────
                              ...filteredPetTypes.map((pt) {
                                final name = _capitalize(pt.id);
                                final available = pt.display;
                                final sel = _selectedPetTypes.contains(name);

                                if (!available) {
                                  return Padding(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 15,
                                                color: Colors.grey.shade500),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            'Coming Soon',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.black, // Teal text
                                            ),
                                          ),
                                          backgroundColor: Colors.white, // White background
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: AppColors.primaryColor, // Teal border
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: Colors.grey.shade800),
                                  ),
                                  value: sel,
                                  activeColor: const Color(0xFF25ADAD),
                                  checkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                  side: BorderSide(
                                      color: const Color(0xFF25ADAD)
                                          .withOpacity(0.5)),
                                  onChanged: (_) {
                                    setState(() {
                                      if (sel)
                                        _selectedPetTypes.remove(name);
                                      else
                                        _selectedPetTypes.add(name);
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                        // ─ New: At Offer Price Section ─
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            title: Text(
                              'At Offer Price',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _showOffersOnly ? const Color(0xFF25ADAD) : Colors.grey.shade800,
                              ),
                            ),
                            trailing: Icon(
                              _showOffersOnly ? Icons.check_box : Icons.check_box_outline_blank,
                              color: _showOffersOnly ? const Color(0xFF25ADAD) : Colors.grey.shade600,
                            ),
                            onTap: () {
                              setState(() {
                                _showOffersOnly = !_showOffersOnly;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── FOOTER BUTTONS ───────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // ─── Clear All ─────────────────────────────────────────
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                                color: Colors.grey.shade400, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              // Reset search query as well
                              _searchQuery = '';
                              // Reset price slider to full range:
                              _selectedPriceRange = RangeValues(
                                _minPrice.toDouble(),
                                _maxPrice.toDouble(),
                              );
                              // Clear pet-type selections:
                              _selectedPetTypes.clear();
                              // If there’s a distance filter, reset it too:
                              // _selectedDistanceOption = '';

                              // New: Uncheck the 'At Offer Price' filter
                              _showOffersOnly = false;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Clear All',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ─── Apply ────────────────────────────────────────────────
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF25ADAD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () {
                            // Simply close drawer to “apply” current selections
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Apply',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Main Content ───────────────────────────────────
        body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [

              // 1) Your existing header
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              // 3) New Control Row (Filters, Reset, and Availability)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
                  child: Row(
                    children: [
                      // Filter Button
                      Builder(
                          builder: (context) {
                            return OutlinedButton(
                              onPressed: () => Scaffold.of(context).openEndDrawer(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(42, 42), // Make it square
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Icon(Icons.filter_list_rounded, size: 20, color: Colors.grey.shade700),
                            );
                          }
                      ),
                      const SizedBox(width: 2),

                      // ⭐️ NEW Favorite Button
                      OutlinedButton(
                        onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(42, 42),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: _showFavoritesOnly ? Colors.red.shade200 : Colors.grey.shade300),
                          backgroundColor: _showFavoritesOnly ? Colors.red.withOpacity(0.05) : Colors.transparent,
                        ),
                        child: Icon(
                          _showFavoritesOnly ? Icons.favorite : Icons.favorite_border_rounded,
                          size: 20,
                          color: _showFavoritesOnly ? Colors.redAccent : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 2),

                      // RIGHT SIDE: Check Availability button
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isFilterActive = _filterPetCount > 0 && _filterDates.isNotEmpty;
                            return GestureDetector(
                              onTap: () => _showAvailabilityFilterDialog(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: double.infinity,
                                height: 42, // Set a fixed compact height
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isFilterActive ? Colors.white : const Color(0xFF25ADAD),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isFilterActive ? Border.all(color: const Color(0xFF25ADAD), width: 1.5) : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isFilterActive ? _buildActiveState() : _buildInactiveState(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 2),
                      OutlinedButton(
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(42, 42), // Make it square
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Icon(Icons.restart_alt_rounded, size: 20, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              // 3) NEW: The sticky TabBar
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.poppins(),
                    labelColor: const Color(0xFF25ADAD),
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: const Color(0xFF25ADAD),
                    indicatorWeight: 3.0,
                    tabs: const [
                      Tab(text: 'Overnight'),
                      Tab(text: 'Day Care'),
                    ],
                  ),
                ),
                pinned: true, // This makes the tab bar stick to the top when you scroll
              ),
            ],

            // 4) Single ListView content
            body: TabBarView(
              controller: _tabController,
              children: [
                Builder(builder: (context) {
                  final cardsProv = context.watch<BoardingCardsProvider>();
                  print('Is BoardingCardsProvider ready? ${cardsProv.ready}');
                  if (!cardsProv.ready) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final favProv = context.watch<FavoritesProvider>();
                  final hideProv = context.watch<HiddenServicesProvider>();

                  if (!cardsProv.ready) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  print('Total services fetched: ${cardsProv.cards.length}');

                  // Replace the entire filter block inside your TabBarView's Builder

                  final filtered = cardsProv.cards.where((service) {
                    final id = service['service_id']?.toString() ?? '';
                    print('--- Checking service: ${service['shopName']} (ID: $id) ---');


                    // New Search Query Filter
                    final shopName = service['shopName']?.toString().toLowerCase() ?? '';
                    final areaName = service['areaName']?.toString().toLowerCase() ?? '';
                    final searchQuery = _searchQuery.toLowerCase();

                    if (searchQuery.isNotEmpty && !shopName.contains(searchQuery) && !areaName.contains(searchQuery)) {
                      return false;
                    }

                    // 1. Hidden Service Filter
                    if (hideProv.hidden.contains(id)) {
                      return false;
                    }

                    // 2. Offer Filter
                    final isOfferActive = service['isOfferActive'] as bool? ?? false;
                    if (_showOffersOnly && !isOfferActive) {
                      return false;
                    }

                    // 3. Favorites Filter
                    if (_showFavoritesOnly && !favProv.liked.contains(id)) {
                      return false;
                    }

                    // 4. SPECIES FILTER (Case-insensitive) - ✅ CORRECTED HERE
                    if (_selectedPetTypes.isNotEmpty) {
                      // It was looking for 'accepted_pets', but the correct field is 'pets'.
                      final acceptedPetsLower = (service['pets'] as List<dynamic>? ?? [])
                          .map((p) => p.toString().toLowerCase())
                          .toList();
                      if (!_selectedPetTypes.any((selectedPet) => acceptedPetsLower.contains(selectedPet.toLowerCase()))) {
                        return false;
                      }
                    }

                    // 5. PRICE FILTER
                    final bool priceFilterIsActive = _selectedPriceRange.start > _minPrice || _selectedPriceRange.end < _maxPrice;

                    if (priceFilterIsActive) {
                      final serviceMinPrice = (service['min_price'] as num?)?.toDouble() ?? 0.0;
                      final serviceMaxPrice = (service['max_price'] as num?)?.toDouble() ?? 0.0;

                      if (serviceMaxPrice == 0.0) {
                        return false;
                      }

                      final userMinPrice = _selectedPriceRange.start;
                      final userMaxPrice = _selectedPriceRange.end;
                      final bool priceMatches = (userMaxPrice >= serviceMinPrice) && (userMinPrice <= serviceMaxPrice);

                      if (!priceMatches) {
                        return false;
                      }
                    }

                    // 6. Distance Filter
                    if (_selectedDistanceOption.isNotEmpty) {
                      final maxKm = double.tryParse(_selectedDistanceOption.replaceAll(RegExp(r'[^0-9]'), '')) ?? double.infinity;
                      final dKm = service['distance'] ?? double.infinity;
                      if (dKm > maxKm) {
                        return false;
                      }
                    }

                    // 7. Availability Filter
                    // lib/screens/Boarding/boarding_homepage.dart -> inside the .where() clause

// 7. Availability Filter
                    // Replace your entire Availability Filter block with this one:

// 7. Availability Filter
                    // Make sure your Availability Filter block looks exactly like this

// 7. Availability Filter
                    if (_filterDates.isNotEmpty && _filterPetCount > 0) {
                      final id = service['service_id']?.toString() ?? '';
                      final bookingCounts = _allBookingCounts[id] ?? {};
                      final maxAllowed = _serviceMaxAllowed[id] ?? 0;

                      for (final date in _filterDates) {
                        final dayOnly = DateTime(date.year, date.month, date.day);
                        final usedSlots = bookingCounts[dayOnly] ?? 0;

                        // ====================== CRITICAL DEBUG PRINT #2 ======================
                        // 👇 Replace "MyFellowPet" with the real name of your test shop
                        if (service['shopName'] == 'Lakshmi') {
                          print('''

      ------ 🔍 FINAL CHECK for MyFellowPet 🔍 ------
      - Checking Date: $dayOnly
      - Max Capacity (maxAllowed): $maxAllowed
      - Loaded Slots (usedSlots): $usedSlots  <-- Check if this is 999 for the holiday
      - Pets to Book (_filterPetCount): $_filterPetCount
      - THE CHECK: ($usedSlots + $_filterPetCount) > $maxAllowed
      - RESULT: ${usedSlots + _filterPetCount > maxAllowed}
      -----------------------------------------------

      ''');
                        }
                        // ====================================================================

                        if (usedSlots + _filterPetCount > maxAllowed) {
                          return false;
                        }
                      }
                    }

                    // 8. Certified & Run Type Filters
                    final certified = service['mfp_certified'] as bool? ?? false;
                    if (_showCertifiedOnly && !certified) {
                      return false;
                    }
                    final runType = service['type'] as String? ?? '';
                    if (_selectedRunTypes.isNotEmpty && !_selectedRunTypes.contains(runType)) {
                      return false;
                    }

                    // If all checks pass, show the card
                    return true;

                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(8),
                    children:
                    filtered.map((data) => BoardingServiceCard(
                        key: ValueKey(data['id']),
                        service: data,
                        mode: 1
                    )).toList(),
                  );
                }),
                ComingSoonPage()
              ],)
        ),
      ),);
  }

  // Add this new method anywhere inside the _BoardingHomepageState class

  void _showInfoDialog(BuildContext context, {required String title, required String content}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.event_available, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        Text(
          'Check Availability',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveState() {
    String getDatesSummary() {
      if (_filterDates.isEmpty) return '';
      if (_filterDates.length == 1) return DateFormat('dd MMM').format(_filterDates.first);
      return '${_filterDates.length} days';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.pets, size: 16, color: const Color(0xFF00695C)),
              const SizedBox(width: 4),
              Text(
                '$_filterPetCount Pet${_filterPetCount > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF00695C)),
              ),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8),
              Icon(Icons.date_range, size: 16, color: const Color(0xFF00695C)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  getDatesSummary(),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF00695C)),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
        // Clear button
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.close , size: 20, color: Colors.redAccent),
          onPressed: () {
            setState(() {
              _filterPetCount = 0;
              _filterDates.clear();
            });
          },
        ),
      ],
    );
  }

  // Replace the old method with this one

  Widget _buildFilterDetailChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF25ADAD).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // This tells the Row to shrink-wrap its children
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00695C)),
          const SizedBox(width: 8),
          Flexible( // Using Flexible instead of Expanded allows it to take up space but not force an infinite width
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF00695C),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              softWrap: false, // Prevents wrapping to keep it chip-like
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<DateTime, int>> _allBookingCounts = {};


  // lib/screens/Boarding/boarding_homepage.dart

  Future<void> _preloadAllBookingCounts() async {
    // Wait for the provider to be ready before trying to access cards
    final provider = context.read<BoardingCardsProvider>();
    if (!provider.ready) {
      // If not ready, wait a moment and try again.
      await Future.delayed(const Duration(milliseconds: 100));
      _preloadAllBookingCounts();
      return;
    }

    final services = provider.cards;
    if (services.isEmpty) return;

    print("🕵️‍♂️ Preloading availability data for ${services.length} services...");

    // Loop through each service card to fetch its specific availability data
    for (final service in services) {
      final sid = service['service_id'] as String;
      final dateCount = <DateTime, int>{};

      // 1. Fetch the main document to get max_pets_allowed
      final parentSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(sid)
          .get();

      if (parentSnap.exists && parentSnap.data() != null) {
        final rawMax = parentSnap.data()!['max_pets_allowed'];
        _serviceMaxAllowed[sid] = int.tryParse(rawMax?.toString() ?? '0') ?? 0;
      } else {
        _serviceMaxAllowed[sid] = 0;
      }

      // 2. Fetch the daily_summary to get booked counts and holidays
      final summarySnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(sid)
          .collection('daily_summary')
          .get();

      for (final doc in summarySnap.docs) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(doc.id);
          final dayOnly = DateTime(date.year, date.month, date.day);
          final docData = doc.data();

          final bool isHoliday = docData['isHoliday'] as bool? ?? false;

          if (isHoliday) {
            // If it's a holiday, use our 999 signal
            dateCount[dayOnly] = 999;
          } else {
            // Otherwise, use the actual booked count
            dateCount[dayOnly] = docData['bookedPets'] as int? ?? 0;
          }
        } catch (e) {
          // Ignore malformed doc IDs
        }
      }
      _allBookingCounts[sid] = dateCount;
    }

    // Once all data is fetched, trigger a UI update.
    setState(() {
      print("✅ Preloading complete. Data is ready for filtering.");
    });
  }

  // [REPLACE] your existing _showAvailabilityFilterDialog method with this one.

  Future<void> _showAvailabilityFilterDialog() async {
    final petCountCtl = TextEditingController(
      text: _filterPetCount > 0 ? '$_filterPetCount' : '',
    );
    List<DateTime> tempDates = List.from(_filterDates);

    // NEW: Create a FocusNode to control the keyboard
    final petCountFocusNode = FocusNode();

    await showDialog(
      context: context,
      // Ensure the dialog itself doesn't dismiss when tapping outside the textfield
      barrierDismissible: false,
      builder: (ctx) {
        // Use a StatefulBuilder to manage the internal state of the calendar
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Availability Filter',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF25ADAD),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                              // MODIFIED: Close button now unfocuses before popping
                              onPressed: () {
                                petCountFocusNode.unfocus();
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // "Number of Pets" Field
                        Text(
                          'Number of pets',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // --- MODIFIED TEXTFIELD ---
                        TextField(
                          controller: petCountCtl,
                          focusNode: petCountFocusNode, // MODIFIED: Assign the FocusNode
                          keyboardType: TextInputType.number,
                          // MODIFIED: Change keyboard action to "Done"
                          textInputAction: TextInputAction.done,
                          // MODIFIED: Hide keyboard when "Done" is pressed
                          onEditingComplete: () => petCountFocusNode.unfocus(),
                          decoration: InputDecoration(
                            hintText: 'Enter the number',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(color: Color(0xFF25ADAD)),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            // NEW: The "tick button" (checkmark icon)
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.check, color: Color(0xFF25ADAD)),
                              onPressed: () {
                                // This is the key part: it dismisses the keyboard
                                petCountFocusNode.unfocus();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // "Select Dates" Label
                        Text(
                          'Select dates',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Calendar
                        TableCalendar(
                          firstDay: DateTime.now(),
                          lastDay: DateTime.now().add(const Duration(days: 365)),
                          focusedDay: DateTime.now(),
                          selectedDayPredicate: (day) => tempDates.any((d) => isSameDay(d, day)),
                          onDaySelected: (sel, focus) {
                            // This now uses the StatefulBuilder's setState equivalent
                            setDialogState(() {
                              if (tempDates.any((d) => isSameDay(d, sel))) {
                                tempDates.removeWhere((d) => isSameDay(d, sel));
                              } else {
                                tempDates.add(sel);
                              }
                            });
                          },
                          calendarStyle: CalendarStyle(
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFF25ADAD),
                              shape: BoxShape.rectangle,
                            ),
                            todayDecoration: BoxDecoration(
                              border: Border.all(color: Color(0xFF25ADAD)),
                              shape: BoxShape.rectangle,
                            ),
                            todayTextStyle: const TextStyle(color: Colors.black),
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Clear / Apply Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFF25ADAD).withOpacity(0.5)),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _filterPetCount = 0;
                                    _filterDates.clear();
                                  });
                                  setDialogState(() {
                                    petCountCtl.text = '';
                                    tempDates.clear();
                                  });
                                },
                                child: Text('Clear', style: GoogleFonts.poppins(color: const Color(0xFF25ADAD))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25ADAD),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  final enteredCount = int.tryParse(petCountCtl.text) ?? 0;
                                  if (enteredCount <= 0) {
                                    _showWarningDialog(message: 'Please enter a valid pet count.');
                                    return;
                                  }
                                  if (tempDates.isEmpty) {
                                    _showWarningDialog(message: 'Please select at least one date.');
                                    return;
                                  }
                                  setState(() {
                                    _filterPetCount = enteredCount;
                                    _filterDates = List.from(tempDates);
                                  });
                                  Navigator.pop(dialogContext);
                                },
                                child: Text('Apply', style: GoogleFonts.poppins(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // NEW: Important cleanup to prevent memory leaks
    petCountFocusNode.dispose();
  }
}

// boarding_homepage.dart (add this to the bottom of the file)

// A separate class to hold the data needed by the isolate
class IsolateData {
  final List<Map<String, dynamic>> services;
  IsolateData(this.services);
}

// The top-level function to run in the isolate. It MUST be static or top-level.
// lib/screens/Boarding/boarding_homepage.dart

// The top-level function to run in the isolate.
// lib/screens/Boarding/boarding_homepage.dart

// Replace your _computeBookingCounts function with this one

Future<Map<String, Map<DateTime, int>>> _computeBookingCounts(IsolateData data) async {
  final allBookingCounts = <String, Map<DateTime, int>>{};

  for (final service in data.services) {
    final sid = service['service_id'] as String;
    final dateCount = <DateTime, int>{};

    final summarySnap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(sid)
        .collection('daily_summary')
        .get();

    // === START DEBUG PRINT #1 ===
    print("--- [ISOLATE TRACE for ${service['shopName']}] Found ${summarySnap.docs.length} summary docs.");
    // === END DEBUG PRINT #1 ===

    for (final doc in summarySnap.docs) {
      try {
        final date = DateFormat('yyyy-MM-dd').parse(doc.id);
        final dayOnly = DateTime(date.year, date.month, date.day);
        final docData = doc.data();

        final bool isHoliday = docData['isHoliday'] as bool? ?? false;

        if (isHoliday) {
          // === START DEBUG PRINT #1 ===
          print("--- [ISOLATE TRACE for ${service['shopName']}] 👉 HOLIDAY FOUND for ${doc.id}. Setting slots to 999.");
          // === END DEBUG PRINT #1 ===
          dateCount[dayOnly] = 999;
        } else {
          final bookedPets = docData['bookedPets'] as int? ?? 0;
          dateCount[dayOnly] = bookedPets;
        }

      } catch (e) {
        print('Could not parse date from summary document ID: ${doc.id}');
      }
    }

    allBookingCounts[sid] = dateCount;
  }
  return allBookingCounts;
}


class _ComingSoonMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'Daycare Services Coming Soon!',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We\'re working hard to bring you the best Daycare providers in your area.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}


class RunTypeFilterDialog extends StatefulWidget {
  final Set<String> selected;
  const RunTypeFilterDialog({ Key? key, required this.selected }) : super(key: key);

  @override
  _RunTypeFilterDialogState createState() => _RunTypeFilterDialogState();
}

class _RunTypeFilterDialogState extends State<RunTypeFilterDialog> {
  late Set<String> _tempSelected;
  static const _allTypes = [
    'Home Run',
    'Business Run',
    'NGO Run',
    'Govt Run',
    'Vet Run',
  ];


  @override
  void initState() {
    super.initState();
    _tempSelected = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        'Filter by Run Type',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: _allTypes.map((type) {
            final isSelected = _tempSelected.contains(type);
            return CheckboxListTile(
              activeColor: AppColors.primaryColor,
              checkColor: Colors.white,
              value: isSelected,
              title: Text(
                type,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primaryColor : Colors.black87,
                ),
              ),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) _tempSelected.add(type);
                  else                 _tempSelected.remove(type);
                });
              },
            );
          }).toList(),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => Navigator.pop(context, widget.selected),
          child: Text(
            'CANCEL',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context, _tempSelected),
          child: Text(
            'APPLY',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

}

class PulsingCard extends StatefulWidget {
  final bool isPulsing;
  final Widget child;

  const PulsingCard({
    Key? key,
    required this.isPulsing,
    required this.child,
  }) : super(key: key);

  @override
  _PulsingCardState createState() => _PulsingCardState();
}

class _PulsingCardState extends State<PulsingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.animateTo(0.0); // Reset to the beginning (scale 1.0)
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class BoardingServiceCard extends StatefulWidget {
  final Map<String, dynamic> service;
  final int mode;

  const BoardingServiceCard({
    Key? key,
    required this.service,
    this.mode = 1,
  }) : super(key: key);

  @override
  State<BoardingServiceCard> createState() => _BoardingServiceCardState();
}

class _BoardingServiceCardState extends State<BoardingServiceCard> {
  String? _selectedPet;
  List<Map<String, String>> _branchOptions = [];
  bool _isLoadingBranches = true;
  bool _isSwitchingBranch = false;

  @override
  void initState() {
    super.initState();
    _initializeCardState(widget.service);
  }

  @override
  void didUpdateWidget(covariant BoardingServiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service['id'] != oldWidget.service['id']) {
      _initializeCardState(widget.service);
    }
  }

  void _initializeCardState(Map<String, dynamic> serviceData) {
    setState(() {
      _isLoadingBranches = true;
      _initializePetSelection(serviceData);
    });
    _fetchBranchDetails(serviceData);
  }

  void _initializePetSelection(Map<String, dynamic> serviceData) {
    final standardPrices =
    Map<String, dynamic>.from(serviceData['pre_calculated_standard_prices'] ?? {});
    if (standardPrices.isEmpty) {
      _selectedPet = null;
      return;
    }
    final userMajorityPet = context.read<BoardingCardsProvider>().majorityPetType;
    _selectedPet = (userMajorityPet != null &&
        standardPrices.containsKey(userMajorityPet))
        ? userMajorityPet
        : standardPrices.keys.first;
  }

  Future<void> _fetchBranchDetails(Map<String, dynamic> serviceData) async {
    final otherBranchIds =
    List<String>.from(serviceData['other_branches'] ?? []);
    final currentBranchId = serviceData['id'].toString();
    final currentBranchName = serviceData['areaName'].toString();
    _branchOptions = [{'id': currentBranchId, 'areaName': currentBranchName}];

    if (otherBranchIds.isNotEmpty) {
      final futures = otherBranchIds
          .map((id) => FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(id)
          .get())
          .toList();
      final results = await Future.wait(futures);
      for (var doc in results) {
        if (doc.exists) {
          _branchOptions.add(
              {'id': doc.id, 'areaName': doc.data()?['area_name'] ?? 'Unknown'});
        }
      }
    }
    if (mounted) setState(() => _isLoadingBranches = false);
  }

  Future<void> _switchBranch(String? newBranchId) async {
    if (newBranchId == null || newBranchId == widget.service['id']) return;
    setState(() => _isSwitchingBranch = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(newBranchId)
          .get();
      if (doc.exists && mounted) {
        // ... (all the logic to build fullNewData is correct) ...
        final newData = doc.data()!;
        final distances = context.read<DistanceProvider>().distances;
        final standardPrices = Map<String, dynamic>.from(newData['pre_calculated_standard_prices'] ?? {});
        final offerPrices = Map<String, dynamic>.from(newData['pre_calculated_offer_prices'] ?? {});
        final List<num> allPrices = [];
        standardPrices.values.forEach((petPrices) {
          allPrices.addAll((petPrices as Map).values.map((price) => _safeParseDouble(price)));
        });
        offerPrices.values.forEach((petPrices) {
          allPrices.addAll((petPrices as Map).values.map((price) => _safeParseDouble(price)));
        });
        final minPrice = allPrices.isNotEmpty ? allPrices.reduce(min).toDouble() : 0.0;
        final maxPrice = allPrices.isNotEmpty ? allPrices.reduce(max).toDouble() : 0.0;

        final fullNewData = {
          ...newData,
          'id': doc.id,
          'service_id': newData['service_id'] ?? doc.id,
          'shopName': newData['shop_name'] ?? '',
          'shop_image': newData['shop_logo'] ?? '',
          'areaName': newData['area_name'] ?? '',
          'distance': distances[newBranchId] ?? double.infinity,
          'min_price': minPrice,
          'max_price': maxPrice,
          'other_branches': [
            widget.service['id'],
            ...List<String>.from(widget.service['other_branches'] ?? []).where((id) => id != newBranchId),
          ],
        };

        // ✅ FIX: The `preservePosition` flag is no longer needed here.
        context.read<BoardingCardsProvider>().replaceService(
          widget.service['id'],
          fullNewData,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSwitchingBranch = false);
      print("Error switching branch: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final documentId = service['id']?.toString() ?? '';
    final serviceId = service['service_id']?.toString() ?? '';
    final shopName = service['shopName']?.toString() ?? 'Unknown Shop';
    final shopImage = service['shop_image']?.toString() ?? '';
    final standardPricesMap = Map<String, dynamic>.from(service['pre_calculated_standard_prices'] ?? {});
    final offerPricesMap = Map<String, dynamic>.from(service['pre_calculated_offer_prices'] ?? {});

    final runType = service['type'] as String? ?? '';
    final isOfferActive = service['isOfferActive'] as bool? ?? false;
    final petList = List<String>.from(service['pets'] ?? []);
    final dKm = service['distance'] as double? ?? 0.0;
    final isCertified = service['mfp_certified'] as bool? ?? false;
    final otherBranches = List<String>.from(service['other_branches'] ?? []);


    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: isOfferActive
                ? const BorderSide(color: Colors.black87, width: 1.0)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BoardingServiceDetailPage(
                    mode: widget.mode.toString(),
                    pets: petList,
                    documentId: documentId,
                    shopName: shopName,
                    shopImage: shopImage,
                    areaName: service['areaName']?.toString() ?? '',
                    distanceKm: dKm,
                    rates: const {},
                    otherBranches: List<String>.from(service['other_branches'] ?? []),
                    isOfferActive: isOfferActive,
                    isCertified: isCertified,
                    initialSelectedPet: _selectedPet,
                    preCalculatedStandardPrices: standardPricesMap,
                    preCalculatedOfferPrices: offerPricesMap,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: isOfferActive ? const EdgeInsets.all(8.0) : EdgeInsets.zero,
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 110,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.network(
                                  shopImage,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image_not_supported,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // bottom gradient (runType)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: _runTypeGradient(runType),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _runTypeLabel(runType),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // favorite button (stays on image)
                          Positioned(
                            top: 2,
                            right: 0,
                            child: Consumer<FavoritesProvider>(
                              builder: (_, favProv, __) {
                                final isLiked = favProv.liked.contains(serviceId);
                                return Container(
                                  height: 28,
                                  width: 28,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => favProv.toggle(serviceId),
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (c, a) =>
                                          ScaleTransition(scale: a, child: c),
                                      child: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        key: ValueKey(isLiked),
                                        size: 16,
                                        color: isLiked
                                            ? const Color(0xFFFF5B20)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      // ===== RIGHT SIDE DETAILS =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87, // optional for consistency
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),

                              FutureBuilder<Map<String, dynamic>>(
                                future: fetchRatingStats(serviceId),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) {
                                    return const SizedBox(height: 20);
                                  }
                                  final avg = snap.data!['avg'] as double;
                                  final count = snap.data!['count'] as int;
                                  return Row(
                                    children: [
                                      for (int i = 0; i < 5; i++)
                                        Icon(
                                          i < avg ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        avg.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($count)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  );

                                },
                              ),
                              PriceAndPetSelector(
                                standardPrices: standardPricesMap,
                                offerPrices: offerPricesMap,
                                isOfferActive: isOfferActive,
                                initialSelectedPet: _selectedPet,
                                onPetSelected: (pet) {
                                  setState(() {
                                    _selectedPet = pet;
                                  });
                                },
                              ),
                              BranchSelector(
                                currentServiceId: serviceId,
                                currentAreaName: service['areaName']?.toString() ?? '',
                                otherBranches: List<String>.from(service['other_branches'] ?? []),
                                onBranchSelected: _switchBranch,
                              ),                                  SizedBox(height: 2),
                              // if (!_isLoadingBranches) _buildBranchSelector(),
                              SizedBox(height: 2),
                              SizedBox(
                                height: 25,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: petList
                                      .map((pet) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _buildPetChip(pet),
                                  ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                dKm.isInfinite ? 'Location services disabled. Enable to view' : '${dKm.toStringAsFixed(1)} km away',
                                style: const TextStyle(fontSize: 9),
                              ),                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isOfferActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accentColor, const Color(0xFFD96D0B)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'SPECIAL OFFER',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // In _BoardingServiceCardState build method

        // ✅ TWEAK HERE: Replace the entire "hide/unhide menu" Positioned widget with this one.
        Positioned(
          right: isOfferActive ? 10.0 : 8.0,
          bottom: isOfferActive ? 45.0 : 8.0,
          child: Consumer<HiddenServicesProvider>(
            builder: (_, hideProv, __) {
              final isHidden = hideProv.hidden.contains(serviceId);
              final accentColor = Colors.red.shade700;

              return Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(
                    Icons.more_vert, // 3-dot vertical menu icon
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    _showHideConfirmationDialog(context, serviceId, isHidden, hideProv);
                  },
                ),
              );
            },
          ),
        ),

        isCertified
            ? const VerifiedBadge(isCertified: true)
            : const ProfileVerified(),

      ],
    );
  }
// Place this method inside your State class (e.g., _BoardingHomepageState)

// In _BoardingServiceCardState class
}

double _safeParseDouble(dynamic value) {
  return double.tryParse(value?.toString() ?? '0') ?? 0.0;
}

class VerifiedBadge extends StatelessWidget {
  final bool isCertified;
  const VerifiedBadge({Key? key, required this.isCertified}) : super(key: key);

  Future<void> _showDialog(BuildContext context, String field) async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('testaments')
        .get();

    final message = doc.data()?[field] ?? 'No info available';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        title: Text(
          isCertified ? "MFP Certified" : "Verified Profile",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: () => _showDialog(
          context,
          isCertified ? 'mfp_certified_user_app' : 'profile_verified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isCertified ? AppColors.accentColor : AppColors.primaryColor,
            borderRadius: BorderRadius.circular(20), // pill-like modern shape
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                isCertified ? "MFP Certified" : "Verified",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileVerified extends StatelessWidget {
  const ProfileVerified({Key? key}) : super(key: key);

  Future<void> _showDialog(BuildContext context, String field) async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('testaments')
        .get();

    final message = doc.data()?[field] ?? 'No info available';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white,
        title: Text(
          "Profile Verified",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryColor,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        onTap: () => _showDialog(
          context,
          'profile_verified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(20), // pill-like modern shape
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                "Profile Verified",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // Or your desired background color for the tab bar
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class ComingSoonPage extends StatefulWidget {
  const ComingSoonPage({super.key});

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Subtle gradient background for a modern feel
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFF25ADAD).withOpacity(0.08),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title with Poppins font
                  Text(
                    "Daycare Centers Coming Soon",
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Extra description
                  Text(
                    "We're busy setting up a network of safe and fun daycare centers for your beloved pets. Stay tuned!",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // A "Notify Me" button instead of a progress indicator
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.grey.shade800,
                          content: Text(
                            "Great! We'll notify you as soon as it's available.",
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active_outlined, size: 20,color: Colors.white,),
                    label: Text(
                      "Notify Me",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF25ADAD),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _parsePrice(dynamic value) {
  return double.tryParse(value?.toString() ?? '0') ?? 0;
}

class PriceAndPetSelector extends StatefulWidget {
  final Map<String, dynamic> standardPrices;
  final Map<String, dynamic> offerPrices;
  final bool isOfferActive;
  final String? initialSelectedPet;
  final Function(String) onPetSelected; // Callback to update the parent

  const PriceAndPetSelector({
    Key? key,
    required this.standardPrices,
    required this.offerPrices,
    required this.isOfferActive,
    this.initialSelectedPet,
    required this.onPetSelected,
  }) : super(key: key);

  @override
  _PriceAndPetSelectorState createState() => _PriceAndPetSelectorState();
}

class _PriceAndPetSelectorState extends State<PriceAndPetSelector> {
  String? _selectedPet;

  @override
  void initState() {
    super.initState();
    _selectedPet = widget.initialSelectedPet;
  }

  @override
  void didUpdateWidget(covariant PriceAndPetSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initial pet from the parent changes, update the state
    if (widget.initialSelectedPet != oldWidget.initialSelectedPet) {
      setState(() {
        _selectedPet = widget.initialSelectedPet;
      });
    }
  }

  Widget _buildPetSelector() {
    final standardPrices = Map<String, dynamic>.from(
        widget.standardPrices ?? {});
    final availablePets = standardPrices.keys.toList();
    if (availablePets.isEmpty) return const SizedBox.shrink();

    String capitalize(String s) =>
        s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    return PopupMenuButton<String>(
      color: Colors.white, // white background for dropdown
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onSelected: (pet) => setState(() => _selectedPet = pet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical:0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedPet != null ? capitalize(_selectedPet!) : 'Pet',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
          ],
        ),
      ),
      itemBuilder: (context) => availablePets
          .map((pet) => PopupMenuItem<String>(
        value: pet,
        child: Text(
          capitalize(pet),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ))
          .toList(),
    );

  }

  Widget _buildPriceDisplay(bool isOfferActive) {
    if (_selectedPet == null) {
      return const Text('Pricing not available',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final standardPrices = Map<String, dynamic>.from(
        widget.standardPrices ?? {});
    final offerPrices = Map<String, dynamic>.from(
        widget.offerPrices ?? {});

    final ratesSource = (isOfferActive && offerPrices.containsKey(_selectedPet))
        ? Map<String, num>.from(offerPrices[_selectedPet])
        : Map<String, num>.from(standardPrices[_selectedPet] ?? {});

    if (ratesSource.isEmpty) {
      return const Text('No price set',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey));
    }

    final minPrice = ratesSource.values.reduce(min);
    int? minOldPrice;

    if (isOfferActive && standardPrices.containsKey(_selectedPet)) {
      final oldPricesForPet = Map<String, num>.from(standardPrices[_selectedPet]);
      if (oldPricesForPet.isNotEmpty) {
        minOldPrice = oldPricesForPet.values.reduce(min).toInt();
      }
    }

    return PopupMenuButton<String>(
      color: Colors.white, // white background for dropdown
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      itemBuilder: (_) => ratesSource.entries
          .map((entry) => PopupMenuItem<String>(
        enabled: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              '₹${entry.value}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: isOfferActive && minOldPrice != null
                    ? Row(
                  children: [
                    Text(
                      '₹$minOldPrice',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFFF9A9A),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹$minPrice',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                )
                    : Text(
                  'Starts from ₹$minPrice',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
          ],
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPriceDisplay(widget.isOfferActive)),
        const SizedBox(width: 8),
        _buildPetSelector(),
      ],
    );
  }
}

class BranchSelector extends StatefulWidget {
  final String currentServiceId;
  final String currentAreaName;
  final List<String> otherBranches;
  final Function(String?) onBranchSelected;

  const BranchSelector({
    Key? key,
    required this.currentServiceId,
    required this.currentAreaName,
    required this.otherBranches,
    required this.onBranchSelected,
  }) : super(key: key);

  @override
  _BranchSelectorState createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<BranchSelector> {
  List<Map<String, String>> _branchOptions = [];
  bool _isLoadingBranches = true;

  @override
  void initState() {
    super.initState();
    _fetchBranchDetails();
  }

  @override
  void didUpdateWidget(covariant BranchSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentServiceId != oldWidget.currentServiceId) {
      _fetchBranchDetails();
    }
  }

  Future<void> _fetchBranchDetails() async {
    setState(() {
      _isLoadingBranches = true;
      _branchOptions = [];
    });

    List<Map<String, String>> branches = [{
      'id': widget.currentServiceId,
      'areaName': widget.currentAreaName
    }];

    if (widget.otherBranches.isNotEmpty) {
      final futures = widget.otherBranches
          .map((id) => FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(id)
          .get())
          .toList();
      final results = await Future.wait(futures);
      for (var doc in results) {
        if (doc.exists) {
          branches.add({
            'id': doc.id,
            'areaName': doc.data()?['area_name'] ?? 'Unknown'
          });
        }
      }
    }
    if (mounted) {
      setState(() {
        _branchOptions = branches;
        _isLoadingBranches = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBranches) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_branchOptions.length <= 1) {
      return _buildInfoRow(
          widget.currentAreaName, Icons.location_on, Colors.black54);
    }

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: widget.onBranchSelected,
      itemBuilder: (_) => _branchOptions
          .map((branch) => PopupMenuItem<String>(
        value: branch['id'],
        child: Text(
          branch['areaName']!,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 17, color: Colors.black54),
            const SizedBox(width: 4),
            Text(
              widget.currentAreaName,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                color: Color(0xFFF67B0D), size: 20),
          ],
        ),
      ),
    );
  }
}