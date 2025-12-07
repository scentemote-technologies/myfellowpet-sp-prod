import 'dart:convert';
import 'dart:html' as html;
// ... rest of your imports
  import 'package:cached_network_image/cached_network_image.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/services.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:provider/provider.dart';
  import '../../../screens/Boarding/preloaders/distance_provider.dart';
  import '../../../screens/Boarding/preloaders/favorites_provider.dart';
  import '../../../screens/Boarding/preloaders/hidden_services_provider.dart';
  import '../../app_colors.dart';
  import 'boarding_homepage.dart';
  import 'boarding_parameters_selection_page.dart';


  Future<List<PetPricing>> _fetchPetPricing(String serviceId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('pet_information')
        .get();
    if (snapshot.docs.isEmpty) {
      return [];
    }
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return PetPricing(
        petName: doc.id,
        ratesDaily: Map<String, String>.from(data['rates_daily'] ?? {}),
        walkingRatesDaily: Map<String, String>.from(data['walking_rates'] ?? {}),
        mealRatesDaily: Map<String, String>.from(data['meal_rates'] ?? {}),
        offerRatesDaily: Map<String, String>.from(data['offer_daily_rates'] ?? {}),
        offerWalkingRatesDaily: Map<String, String>.from(data['offer_walking_rates'] ?? {}),
        offerMealRatesDaily: Map<String, String>.from(data['offer_meal_rates'] ?? {}),
        feedingDetails: Map<String, dynamic>.from(data['feeding_details'] ?? {}),
        // --- This is the new part that loads the varieties data ---
        acceptedSizes: List<String>.from(data['accepted_sizes'] ?? []),
        acceptedBreeds: List<String>.from(data['accepted_breeds'] ?? []),
      );
    }).toList();
  }


  class BoardingServiceDetailPage extends StatefulWidget {
    final String documentId;
    final String shopName;
    final String mode;
    final double distanceKm;
    final List<String> pets;
    final List<String> otherBranches;

    final Map<String, int> rates;
    final String shopImage;
    final String areaName;
    final bool isOfferActive;
    final bool isCertified;
    final String? initialSelectedPet;
    final Map<String, dynamic> preCalculatedStandardPrices;
    final Map<String, dynamic> preCalculatedOfferPrices;


    const BoardingServiceDetailPage({
      Key? key,
      required this.documentId,
      required this.shopName,
      required this.shopImage,
      required this.areaName,
      required this.distanceKm,
      required this.pets,
      required this.mode,
      required this.rates,
      required this.isOfferActive, this.initialSelectedPet, required this.preCalculatedStandardPrices, required this.preCalculatedOfferPrices, required this.otherBranches, required this.isCertified, // ADD THIS

    }) : super(key: key);

    @override
    State<BoardingServiceDetailPage> createState() =>
        _BoardingServiceDetailPageState();
  }

  class _BoardingServiceDetailPageState extends State<BoardingServiceDetailPage>
      with SingleTickerProviderStateMixin {
    GeoPoint _location = const GeoPoint(0.0, 0.0);
    // State for the Future that will hold our pricing data
    late Future<List<PetPricing>> _petPricingFuture;
    String _companyName = '';
    String _description = '';
    String _serviceId = '';

    String _spId = '';
    bool _adminApproved = false;
    String _shopName = '';
    String _street = '';
    String _areaName = '';
    String _state = '';
    String _district = '';
    String _postalCode = '';
    String _walkingFee = '0';
    String _currentCountOfPet = '';
    String _maxPetsAllowed = '';
    String _maxPetsAllowedPerHour = '';
    String _closeTime = '';
    String _openTime = '';
    bool isLiked = false;
    List<String> _acceptedSizes = [];
    List<String> _acceptedBreeds = [];
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    Set<String> likedServiceIds = {};
    Set<String> _hiddenServiceIds = {};
    final DesignConstants _design = DesignConstants();
    String _fullAddress = '';
    Map<String, int> _refundPolicy = {};
    List<String> _features = [];
    // Pet & rates
    Map<String, String> _ratesDaily = {};
    Map<String, String> _walkingRates = {};
    Map<String, String> _mealRates = {};
    Map<String, String> _offerDailyRates = {};
    Map<String, String> _offerWalkingRates = {};
    Map<String, String> _offerMealRates = {};
    List<String> _petDocIds = []; // store pet document IDs
    String? _selectedPet;

    // ADD THIS ENTIRE METHOD TO YOUR _BoardingServiceDetailPageState CLASS



    // ADD THIS NEW METHOD TO FETCH DATA FOR THE VARIETIES TABLE
    Future<void> _fetchPetDetails(String petId) async {
      if (petId.isEmpty) return;
      try {
        final petSnap = await FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .doc(widget.documentId)
            .collection('pet_information')
            .doc(petId)
            .get();

        if (petSnap.exists) {
          final data = petSnap.data() as Map<String, dynamic>;
          setState(() {
            _acceptedSizes = List<String>.from(data['accepted_sizes'] ?? []);
            _acceptedBreeds = List<String>.from(data['accepted_breeds'] ?? []);
          });
        }
      } catch (e) {
        print("Error fetching pet details for $petId: $e");
        setState(() {
          _acceptedSizes = [];
          _acceptedBreeds = [];
        });
      }
    }

    // Inside _BoardingServiceDetailPageState

// 💥 CHANGE TO ASYNC 💥
    Future<void> _addSchemaMarkup(Map<String, dynamic> serviceData, String serviceId) async {
      if (html.window.document is! html.HtmlDocument) {
        return;
      }

      // --- AWAIT THE RATING DATA ---
      Map<String, dynamic> ratingStats = {'avg': 0.0, 'count': 0};
      try {
        ratingStats = await fetchRatingStats(serviceId);
      } catch (e) {
        // Keep default 0/0 if fetching fails
        print('Error fetching rating stats for schema: $e');
      }

      final double avgRating = ratingStats['avg'] as double;
      final int reviewCount = ratingStats['count'] as int;

      // --- 1. Calculate Minimum Price (same as before) ---
      final Map<String, dynamic> standardPrices = serviceData['pre_calculated_standard_prices'] ?? {};
      int minPrice = 0;
      try {
        if (standardPrices.isNotEmpty) {
          final allPetTotals = standardPrices.values
              .expand((pet) => (pet as Map).values.cast<int>())
              .where((price) => price > 0);
          if (allPetTotals.isNotEmpty) {
            minPrice = allPetTotals.reduce((a, b) => a < b ? a : b);
          }
        }
      } catch (_) {
        minPrice = 0;
      }

      // --- 2. Build the JSON-LD Object ---
      final GeoPoint? location = serviceData['shop_location'] as GeoPoint?;

      final schemaData = {
        "@context": "https://schema.org",
        "@type": "LocalBusiness",
        "name": serviceData['shop_name'] ?? 'MyFellowPet Service',
        "image": serviceData['shop_logo'] ?? '',
        "description": serviceData['description'] ?? 'Trusted pet care service.',
        "url": html.window.location.href,
        "address": {
          "@type": "PostalAddress",
          "streetAddress": serviceData['street'] ?? serviceData['full_address'],
          "addressLocality": serviceData['area_name'] ?? '',
          "addressRegion": serviceData['state'] ?? '',
          "postalCode": serviceData['postal_code'] ?? '',
          "addressCountry": "IN"
        },
        "openingHours": "Mo-Su ${serviceData['open_time'] ?? '00:00'}-${serviceData['close_time'] ?? '23:59'}",
        "priceRange": minPrice > 0 ? "₹$minPrice+" : "₹",
        "telephone": "+91" + (serviceData['owner_phone'] ?? ''),

        "geo": (location != null) ? {
          "@type": "GeoCoordinates",
          "latitude": location.latitude,
          "longitude": location.longitude
        } : null,

        // 💥 USE REAL RATING DATA HERE 💥
        // Only include this block if you have at least one review.
        if (reviewCount > 0)
          "aggregateRating": {
            "@type": "AggregateRating",
            "ratingValue": avgRating.toStringAsFixed(1),
            "reviewCount": reviewCount.toString()
          },
      };

      // --- 3. Inject the script tag ---
      html.document.querySelectorAll('script[type="application/ld+json"]').forEach((e) => e.remove());

      final script = html.ScriptElement()
        ..type = 'application/ld+json'
        ..text = json.encode(schemaData);

      html.document.head!.append(script);
      print('✅ Schema Markup Injected with ${reviewCount} reviews.');
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
        await userPreferencesRef.set({'liked': [serviceId]});
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
        await userPreferencesRef.set({'liked': [serviceId]});
        setState(() {
          isLiked = true;
        });
      }
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
        await userPreferencesRef.set({'hidden': hiddenServices},
            SetOptions(merge: true));
      }
      setState(() {
        _hiddenServiceIds.add(serviceId);
      });
    }



    @override
    void initState() {
      super.initState();
      _petPricingFuture = _fetchPetPricing(widget.documentId);
      // Chain the fetch calls to ensure data is loaded sequentially
      _fetchPetDocIds().then((_) {
        if (_selectedPet != null) {
          _fetchPetDetails(_selectedPet!);
        }
      });

    }

    // In _BoardingServiceDetailPageState

    Future<void> _switchBranch(String newBranchId) async {
      // Prevent navigating to the same page
      if (newBranchId == widget.documentId) return;

      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Fetch the full document for the new branch
        final doc = await FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .doc(newBranchId)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>;
          final distances = Provider.of<DistanceProvider>(context, listen: false).distances;
          final newDistance = distances[newBranchId] ?? 0.0;

          // Close the loading dialog before navigating
          Navigator.pop(context);

          // Replace the current page with a new one for the selected branch
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BoardingServiceDetailPage(
                documentId: newBranchId,
                shopName: data['shop_name'] ?? 'N/A',
                shopImage: data['shop_logo'] ?? '', // Ensure correct field name
                areaName: data['area_name'] ?? 'N/A',
                distanceKm: newDistance,
                pets: List<String>.from(data['pets'] ?? []),
                mode: widget.mode,
                rates: {}, // Rates are derived from pre-calculated prices now
                isOfferActive: data['isOfferActive'] ?? false,
                isCertified: data['mfp_certified'] ?? false,
                otherBranches: List<String>.from(data['other_branches'] ?? []),
                preCalculatedStandardPrices: Map<String, dynamic>.from(data['pre_calculated_standard_prices'] ?? {}),
                preCalculatedOfferPrices: Map<String, dynamic>.from(data['pre_calculated_offer_prices'] ?? {}),
                initialSelectedPet: _selectedPet,
              ),
            ),
          );
        } else {
          if (mounted) Navigator.pop(context); // Close loading dialog on failure
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Could not load branch details."))
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        print("Error switching branch: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("An error occurred."))
        );
      }
    }

    // In _BoardingServiceDetailPageState

    Future<void> _fetchPetDocIds() async {
      final serviceDocRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.documentId);
      final petCollectionSnap = await serviceDocRef.collection('pet_information').get();

      final docIds = petCollectionSnap.docs.map((doc) => doc.id).toList();
      // Determine the selected pet but don't call setState yet
      _petDocIds = docIds;
      _selectedPet = widget.initialSelectedPet ?? (docIds.isNotEmpty ? docIds.first : null);
    }

    @override
    void dispose() {
      super.dispose();
    }

    // You must import 'dart:html' as html;

    void updateSeoMeta({
      required String shopName,
      required String areaName,
      required String description,
      required String serviceType,
    }) {
      // --- 💥 SAFETY CHECK ADDED HERE 💥 ---
      // Ensure this code only runs when compiled for the web platform.
      if (html.window.document is! html.HtmlDocument) {
        return;
      }
      // ------------------------------------

      // --- 1. Update the Page Title ---
      final titleElement = html.document.querySelector('title');
      if (titleElement != null) {
        titleElement.text =
        '$shopName – Best $serviceType in $areaName | MyFellowPet';
      }

      // --- 2. Update the Meta Description ---
      html.Element? metaDesc = html.document.querySelector('meta[name="description"]');
      if (metaDesc == null) {
        metaDesc = html.MetaElement()..name = 'description';
        html.document.head!.append(metaDesc);
      }

      final finalDescription = description.isNotEmpty
          ? description
          : 'Find trusted, MFP-Certified $serviceType in $areaName. Book safe and reliable pet care with $shopName today.';

      (metaDesc as html.MetaElement).content = finalDescription;
    }

    @override
    Widget build(BuildContext context) {

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .doc(widget.documentId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: _design.backgroundColor,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              backgroundColor: _design.backgroundColor,
              body: Center(
                child: Text(
                  'Service not found.',
                  style: GoogleFonts.poppins(
                    color: _design.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          final serviceData = snapshot.data!.data() as Map<String, dynamic>;
          _shopName = serviceData['shop_name'] ?? 'No Shop Name';
          _street = serviceData['street'] ?? 'No Street';
          _areaName = serviceData['area_name'] ?? 'No Area';
          _state = serviceData['state'] ?? 'No State';
          _district = serviceData['district'] ?? 'No District';
          _postalCode = serviceData['postal_code'] ?? 'No Postal Code';
          _companyName = serviceData['company_name'] ?? 'No Company Name';
          _adminApproved = serviceData['adminApproved'] as bool? ?? false;
          _serviceId = serviceData['service_id'] ?? 'No Service ID';
          _maxPetsAllowed = serviceData['max_pets_allowed']?.toString() ?? '0';
          _maxPetsAllowedPerHour =
              serviceData['max_pets_allowed_per_hour']?.toString() ?? '0';
          _currentCountOfPet =
              serviceData['current_count_of_pet']?.toString() ?? '0';
          _description = serviceData['description'] ?? 'No Description';

          _location = serviceData['shop_location'] as GeoPoint;
          _openTime = serviceData['open_time'] ?? '09:00';
          _closeTime = serviceData['close_time'] ?? '18:00';
          _walkingFee = (serviceData['walkingFee'] ?? '0').toString();
          _spId = serviceData['service_id'] ?? 'No ID';
          final petList = List<String>.from(serviceData['pets'] ?? []);
          final imageUrls = List<String>.from(serviceData['image_urls'] ?? []);
          _fullAddress = serviceData['full_address'] ?? 'No address provided';
          // --- 💥 UPDATED ASYNC CALLS HERE 💥 ---
          // Use Future.microtask to perform async operations safely in build
          Future.microtask(() async {
            // 1. Meta Tags (can be done sync, but inside async block is fine)
            updateSeoMeta(
              shopName: _shopName,
              areaName: _areaName,
              description: _description,
              serviceType: 'Boarding',
            );

            // 2. Schema Markup (AWAITS rating stats)
            await _addSchemaMarkup(serviceData, _serviceId);
          });


          final selectedPet =
              widget.initialSelectedPet ?? (petList.isNotEmpty ? petList.first : null);

          if (selectedPet == null) {
            return Scaffold(
              backgroundColor: _design.backgroundColor,
              body: const Center(child: Text("No pets available")),
            );
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users-sp-boarding')
                .doc(widget.documentId)
                .collection('pet_information')
                .doc(selectedPet)
                .get(),
            builder: (context, petSnapshot) {
              if (petSnapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: _design.backgroundColor,
                  body: const Center(child: CircularProgressIndicator()),
                );
              }

              if (!petSnapshot.hasData || !petSnapshot.data!.exists) {
                return Scaffold(
                  backgroundColor: _design.backgroundColor,
                  body: const Center(child: Text("Pet data not found.")),
                );
              }
              final petData =
                  petSnapshot.data!.data() as Map<String, dynamic>? ?? {};
              final selectedPetId = petSnapshot.data!.id;

              final _ratesDaily =
              (petData['rates_daily'] as Map<String, dynamic>? ?? {}).map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final _walkingRates =
              (petData['walking_rates'] as Map<String, dynamic>? ?? {}).map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final _mealRates =
              (petData['meal_rates'] as Map<String, dynamic>? ?? {}).map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final _offerDailyRates =
              (petData['offer_daily_rates'] as Map<String, dynamic>? ?? {}).map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final _offerWalkingRates =
              (petData['offer_walking_rates'] as Map<String, dynamic>? ?? {})
                  .map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final _offerMealRates =
              (petData['offer_meal_rates'] as Map<String, dynamic>? ?? {}).map(
                    (k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
              );
              final acceptedSizes = (petData['accepted_sizes'] is List)
                  ? (petData['accepted_sizes'] as List).map((e) => e.toString()).toList()
                  : (petData['accepted_sizes'] is Map)
                  ? (petData['accepted_sizes'] as Map).keys.map((e) => e.toString()).toList()
                  : <String>[];

              final acceptedBreeds = (petData['accepted_breeds'] is List)
                  ? (petData['accepted_breeds'] as List).map((e) => e.toString()).toList()
                  : (petData['accepted_breeds'] is Map)
                  ? (petData['accepted_breeds'] as Map).keys.map((e) => e.toString()).toList()
                  : <String>[];


              _refundPolicy = Map<String, int>.fromEntries(
                (serviceData['refund_policy'] as Map<String, dynamic>? ?? {})
                    .entries
                    .map(
                      (e) => MapEntry(
                    e.key,
                    e.value is int
                        ? e.value
                        : int.tryParse(e.value.toString()) ?? 0,
                  ),
                ),
              );

              _features = List<String>.from(serviceData['features'] ?? []);
              final fullAddress = '''
  $_shopName,
  $_street,
  $_areaName,
  $_district, $_state - $_postalCode
  ''';

              // 🔽🔽🔽 MODIFICATION STARTS HERE 🔽🔽🔽
              // ----------------------------------------------------
              // 🔽🔽🔽 RESPONSIVE SPLIT MODIFICATION STARTS HERE 🔽🔽🔽

              // Function to define the components that go into the RIGHT column (Pricing/Varieties)
              Widget buildRightColumnContent(bool isWideScreen) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pets We Service Title and Chips (Placed here for context/grouping on mobile)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 20),
                      child: Text(
                        "Pets We Service",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3436),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 20),
                      child: PetChipsRow(
                        pets: widget.pets,
                        initialSelectedPet: widget.pets.isNotEmpty ? widget.pets[0] : "",
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Accepted Sizes & Breeds Table
                    PetVarietiesTable(
                      petDocIds: _petDocIds,
                      selectedPet: _selectedPet,
                      acceptedSizes: _acceptedSizes,
                      acceptedBreeds: _acceptedBreeds,
                      onPetSelected: (newPetId) {
                        if (newPetId != null) {
                          setState(() {
                            _selectedPet = newPetId;
                            _fetchPetDetails(newPetId);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pricing Table
                    PetPricingTable(
                      isOfferActive: widget.isOfferActive,
                      petDocIds: _petDocIds,
                      ratesDaily: {selectedPet: _ratesDaily},
                      walkingRates: {selectedPet: _walkingRates },
                      mealRates: {selectedPet: _mealRates},
                      offerRatesDaily: {selectedPet: _offerDailyRates},
                      offerWalkingRates: {selectedPet: _offerWalkingRates},
                      offerMealRates: {selectedPet: _offerMealRates},
                      initialSelectedPet: selectedPet,
                    ),
                    const SizedBox(height: 16),

                    // Feeding Info Button
                    FutureBuilder<List<PetPricing>>(
                      future: _petPricingFuture,
                      builder: (context, petPricingSnapshot) {
                        if (petPricingSnapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2.0));
                        }
                        if (!petPricingSnapshot.hasData || petPricingSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final allPetData = petPricingSnapshot.data!;
                        final allFeedingDetails = {
                          for (var pet in allPetData) pet.petName: pet.feedingDetails
                        };

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 16), // Adjusted horizontal padding
                          child: FeedingInfoButton(
                            allFeedingDetails: allFeedingDetails,
                            initialSelectedPet: _selectedPet,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 8),
                  ],
                );
              }

              // Function to define the components that go into the LEFT column (Overview/Details/Gallery)
              Widget buildLeftColumnContent(bool isWideScreen) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoGridRow(
                      distanceKm: widget.distanceKm,
                      openTime: _openTime,
                      closeTime: _closeTime,
                      maxPetsAllowed: _maxPetsAllowed,
                      design: _design,
                      isWideScreen: isWideScreen, // Pass the flag
                    ),
                    // 1. Service Overview Card (Header content for Desktop Left Column)
                    if (isWideScreen)
                      Padding(
                        // Match the left padding of the Row container to align with content below
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column( // <--- ADD A COLUMN HERE
                          crossAxisAlignment: CrossAxisAlignment.start, // <--- Set alignment to start
                          children: [


                            // Add explicit spacing or a flexible row here if needed outside the card itself
                          ],
                        ), // <
                      ),

                    // 2. Details/Gallery/Features/Refund Policy (Mobile padding is inside this function)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          _DetailSection(
                            title: "Description",
                            content: _description,
                            design: _design,
                          ),
                          const SizedBox(height: 13),
                          Text(
                            "Gallery",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (imageUrls.isNotEmpty)
                            FutureBuilder<void>(
                              future: Future.wait(
                                imageUrls.map((url) => precacheImage(NetworkImage(url), context)),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState != ConnectionState.done) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                return _GalleryGridSection(
                                  imageUrls: imageUrls,
                                  design: _design,
                                );
                              },
                            ),
                          const SizedBox(height: 14),
                          if (_features.isNotEmpty)
                            _DetailSection(
                              title: "Features",
                              content: '',
                              design: _design,
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: _features.map((feature) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(feature, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 14),
                          if (_refundPolicy.isNotEmpty)
                            RefundPolicyChips(
                              refundRates: _refundPolicy,
                              design: _design,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }



              // Build the main responsive body
              return Scaffold(
                backgroundColor: _design.backgroundColor,
                body: Stack( // 1. Use a Stack to layer widgets
                  children: [
                    // 2. Your main content (LayoutBuilder/SingleChildScrollView) goes first
                    LayoutBuilder(
                      builder: (context, constraints) {

                        const double kDesktopBreakpoint = 800.0;
                        final isWideScreen = constraints.maxWidth > kDesktopBreakpoint;



                        return SingleChildScrollView(
                          // 🚨 Tweak: Remove redundant Center, rely on Container for maxWidth.
                          child: Container(
                            constraints: BoxConstraints(maxWidth: isWideScreen ? 1600 : double.infinity),
                            width: constraints.maxWidth, // Force container to take full width of LayoutBuilder (important!)
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ColorStrip(),

                                _ServiceOverviewCard(
                                  serviceId: _serviceId,
                                  distanceKm: widget.distanceKm,
                                  shopName: widget.shopName,
                                  areaName: widget.areaName,
                                  shopImage: widget.shopImage,
                                  openTime: _openTime,
                                  maxPetsAllowed: _maxPetsAllowed,
                                  closeTime: _closeTime,
                                  onBranchSelected: _switchBranch,
                                  design: _design,
                                  rates: widget.rates,
                                  pets: petList,
                                  isOfferActive: widget.isOfferActive,
                                  isCertified: widget.isCertified,
                                  originalRates: _ratesDaily,
                                  otherBranches: widget.otherBranches,
                                  // ... widget properties ...
                                ),

                                // Responsive Content
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 20 : 12),
                                  child: isWideScreen
                                      ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // LEFT Column (Overview, Details, Gallery, narrower)
                                      Expanded(
                                        flex: 5,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 30.0), // Space between columns
                                          child: buildLeftColumnContent(isWideScreen),
                                        ),
                                      ),

                                      // RIGHT Column (Selection & Pricing, wider)
                                      Expanded(
                                        flex: 5,
                                        child: buildRightColumnContent(isWideScreen),
                                      ),

                                    ],
                                  )
                                      : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Mobile: All content stacked vertically
                                      buildRightColumnContent(isWideScreen),
                                      buildLeftColumnContent(isWideScreen),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // 3. The Positioned widget (for top-right overlay) goes last
                    Positioned(
                      top: 40,
                      right: 15,
                      child: Row(
                        children: [
                          Consumer<FavoritesProvider>(
                            builder: (ctx, favProv, _) {
                              final isLiked = favProv.liked.contains(_serviceId);
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(scale: anim, child: child),
                                    child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, key: ValueKey(isLiked), color: isLiked ? Colors.red : Colors.grey),
                                  ),
                                  onPressed: () => favProv.toggle(_serviceId),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Consumer<HiddenServicesProvider>(
                            builder: (context, hideProv, _) {
                              final isHidden = hideProv.hidden.contains(_serviceId);
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _showHideConfirmationDialog(context, _serviceId, isHidden, hideProv),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  // ... (rest of your FloatingActionButton code) ...
                  backgroundColor: _design.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: _design.primaryColor.withOpacity(0.9),
                      width: 4.0,
                    ),
                  ),
                  onPressed: () {
                    // 3. TRANSFER: Paste the original booking logic here
                    final Map<String, int> dailyRatesToPass = widget.isOfferActive
                        ? _offerDailyRates.map((key, value) =>
                        MapEntry(key, int.tryParse(value.toString()) ?? 0))
                        : _ratesDaily;
                    final Map<String, int> mealRatesToPass = widget.isOfferActive
                        ? _offerMealRates.map((key, value) =>
                        MapEntry(key, int.tryParse(value.toString()) ?? 0))
                        : _mealRates;

                    final feedingDetailsToPass = Map<String, dynamic>.from(petData['feeding_details'] ?? {});

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BoardingParametersSelectionPage(
                          max_pets_allowed: int.parse(_maxPetsAllowed),
                          mode: widget.mode,
                          open_time: _openTime,
                          close_time: _closeTime,
                          current_count_of_pet: _currentCountOfPet,
                          initialSelectedPet: _selectedPet,
                          shopName: widget.shopName,
                          shopImage: widget.shopImage,
                          sp_location: _location,
                          companyName: _companyName,
                          sp_id: _spId,
                          walkingFee: _walkingFee,
                          serviceId: _serviceId,
                          rates: dailyRatesToPass,
                          mealRates: mealRatesToPass,
                          refundPolicy: _refundPolicy,
                          fullAddress: _fullAddress,
                          walkingRates: _walkingRates,
                          feedingDetails: feedingDetailsToPass,
                        ),
                      ),
                    );
                  },
                  label: Row(
                    children: [
                      Text(
                        'Continue Booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white, // Changed to white for visibility on primaryColor background
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                // 3. ADD: FloatingActionButtonLocation property
                floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              );
              // 🔼🔼🔼 MODIFICATION ENDS HERE 🔼🔼🔼
            },
          );
        },
      );
    }
  // REPLACE your old _showFeedingInfoDialog method with this corrected one
  // REPLACE your current _showFeedingInfoDialog method with this FINAL version

  }

  class RefundPolicyChips extends StatefulWidget {
    final Map<String, int> refundRates;
    final DesignConstants design;

    const RefundPolicyChips({
      Key? key,
      required this.refundRates,
      required this.design,
    }) : super(key: key);

    @override
    State<RefundPolicyChips> createState() => _RefundPolicyChipsState();
  }

  class _RefundPolicyChipsState extends State<RefundPolicyChips>
      with SingleTickerProviderStateMixin {
    bool _expanded = false;
    late final AnimationController _blinkController;

    @override
    void initState() {
      super.initState();
      _blinkController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..repeat(reverse: true);
    }

    @override
    void dispose() {
      _blinkController.dispose();
      super.dispose();
    }

    String _getRefundLabel(String key) {
      switch (key) {
        case 'gt_48h':
          return 'If cancelled more than 2 days before';
        case 'gt_24h':
          return 'If cancelled 1–2 days before';
        case 'gt_12h':
          return 'If cancelled 12–24 hours before';
        case 'gt_4h':
          return 'If cancelled 4–12 hours before';
        case 'lt_4h':
          return 'If cancelled less than 4 hours before';
        default:
          return key; // fallback in case a new key comes
      }
    }

    @override
    Widget build(BuildContext context) {
      final entries = widget.refundRates.entries.toList();
      final displayedEntries = _expanded ? entries : entries.take(2).toList();
      final orderMap = {
        'lt_4h': 0,
        'gt_4h': 1,
        'gt_12h': 2,
        'gt_24h': 3,
        'gt_48h': 4,
      };

      final sortedEntries = displayedEntries.toList()
        ..sort((a, b) => orderMap[a.key]!.compareTo(orderMap[b.key]!));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Refund Policy",
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: sortedEntries.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final refund = entry.value;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Text(
                      '$idx',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: widget.design.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_getRefundLabel(refund.key)}: ${refund.value}%',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 5),

          if (entries.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                    if (!_expanded) _blinkController.repeat(reverse: true);
                    else _blinkController.stop();
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? "Tap to see less" : "Tap to see more",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.design.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    FadeTransition(
                      opacity:
                      _expanded ? const AlwaysStoppedAnimation(1.0) : _blinkController,
                      child: RotationTransition(
                        turns: AlwaysStoppedAnimation(_expanded ? 0.5 : 0),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

        ],
      );
    }
  }

  // New widget: AnimatedLocationButton
  // This widget uses the provided AnimationController to animate a button that initially
  // moves from an off-screen start position to the center of the screen displaying the full message,
  // then after a short hold, animates back to the bottom right showing just the km value.
  class AnimatedLocationButton extends StatefulWidget {
    final double distanceKm;
    final AnimationController controller;

    const AnimatedLocationButton({
      Key? key,
      required this.distanceKm,
      required this.controller,
    }) : super(key: key);

    @override
    _AnimatedLocationButtonState createState() => _AnimatedLocationButtonState();
  }

  class _AnimatedLocationButtonState extends State<AnimatedLocationButton> {
    bool _expanded = false;

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _expanded = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          setState(() {
            _expanded = false;
          });
        });
      });
    }

    @override
    Widget build(BuildContext context) {
      const double collapsedSize = 50;
      const double expandedWidth = 250;
      const double buttonHeight = 50;

      return Positioned(
        right: 16,
        bottom: 120,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Location Info"),
                content: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    children: [
                      const TextSpan(text: "Your location is "),
                      TextSpan(
                        text: "${widget.distanceKm.toStringAsFixed(1)} km",
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: " far from this place"),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.fastOutSlowIn,
            width: _expanded ? expandedWidth : collapsedSize,
            height: buttonHeight,
            padding: EdgeInsets.symmetric(horizontal: _expanded ? 16 : 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFFF9D443),
                width: 4.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: _expanded
                ? RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                children: [
                  const TextSpan(text: "Your location is "),
                  TextSpan(
                    text: "${widget.distanceKm.toStringAsFixed(1)} km",
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: " far from this place"),
                ],
              ),
            )
                : Icon(
              Icons.location_on,
              size: 24,
              color: const Color(0xFFBE8F00).withOpacity(0.7),
            ),
          ),
        ),
      );
    }
  }

  // ***********************
  // Design & Enhanced UI Widgets
  // ***********************

  class DesignConstants {
    final contentPadding =
    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0);
    final primaryColor = const Color(0xFF2BCECE);
    final accentColor = const Color(0xFFF9D443);
    final backgroundColor = const Color(0xFFFFFFFF);
    final textDark = const Color(0xFF2D3436);
    final textLight = const Color(0xFF636E72);
    final shadowColor = Colors.black12;

    final titleStyle = const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: Color(0xFF2D3436),
    );

    final subtitleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF636E72),
      height: 1.5,
    );

    final priceStyle = const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6C5CE7),
    );
  }
  class _ServiceOverviewCard extends StatefulWidget {
    final String shopName;
    final String areaName;
    final String shopImage;
    final String openTime;
    final String serviceId;
    final String closeTime;
    final double distanceKm;
    final bool isCertified;

    final DesignConstants design;
    final String maxPetsAllowed;
    final List<String> pets;
    final Map<String, int> rates;
    final List<String> otherBranches;
    final bool isOfferActive; // ADD THIS LINE
    final Map<String, int> originalRates; // ADD THIS LINE
    final Function(String) onBranchSelected; // ADD THIS LINE




    const _ServiceOverviewCard({
      Key? key,
      required this.shopName,
      required this.shopImage,
      required this.openTime,
      required this.closeTime,
      required this.design,
      required this.distanceKm,
      required this.maxPetsAllowed,
      required this.pets,
      required this.rates,
      required this.serviceId,
      required this.isOfferActive,
      required this.originalRates, required this.areaName, required this.isCertified, required this.otherBranches, required this.onBranchSelected, // ADD THIS LINE
// ADD THIS LINE

    }) : super(key: key);

    @override
    __ServiceOverviewCardState createState() => __ServiceOverviewCardState();
  }

  class __ServiceOverviewCardState extends State<_ServiceOverviewCard> {
    String _selectedSize = '';
    bool _isOfferActive = false;



    int _minPrice() {
      final prices = widget.rates.values.where((p) => p > 0).toList();
      return prices.isEmpty ? 0 : prices.reduce((a, b) => a < b ? a : b);
    }

    Future<Map<String, dynamic>> fetchRatingStats(String serviceId) async {
      final coll = FirebaseFirestore.instance
          .collection('public_review')
          .doc('service_providers')
          .collection('sps')
          .doc(serviceId)
          .collection('reviews');

      final snap = await coll.get();
      final ratings = snap.docs
          .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
          .where((r) => r > 0)
          .toList();

      final count = ratings.length;
      final avg = count > 0 ? ratings.reduce((a, b) => a + b) / count : 0.0;

      return {
        'avg': avg.clamp(0.0, 5.0),
        'count': count,
      };
    }

    @override
    Widget build(BuildContext context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800.0;


          final imageSize = isWideScreen ? 120.0 : 80.0;

          final titleFontSize = isWideScreen ? 28.0 : 22.0;

          final subTextSize = isWideScreen ? 20.0 : 12.0;

          final ratingTextSize = isWideScreen ? 12.0 : 10.0;

          final ratingIconSize = isWideScreen ? 16.0 : 12.0;
          final basePadding = isWideScreen ? 40.0 : 10.0;


          String shortId = widget.serviceId.length > 8
              ? widget.serviceId.substring(0, 8) + "…"
              : widget.serviceId;

          // Safety check for the image URL
          final bool isImageValid = widget.shopImage.isNotEmpty && widget.shopImage.startsWith('http');

          return Container(
            // Use increased padding
            padding: EdgeInsets.fromLTRB(basePadding, 30, basePadding,0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: isImageValid
                            ? DecorationImage(
                          image: NetworkImage(widget.shopImage),
                          fit: BoxFit.cover,
                        )
                            : null,
                        color: isImageValid ? null : Colors.grey.shade200,
                      ),
                      // Increased fallback icon size
                      child: isImageValid ? null : Icon(Icons.store, color: Colors.grey.shade400, size: isWideScreen ? 80 : 32),
                    ),
                    SizedBox(width: isWideScreen ? 36 : 16), // Increased spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Shop Name, Verification, and Rating ---
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: isWideScreen ? 18 : 10, // Increased spacing
                            runSpacing: isWideScreen ? 10 : 8,
                            children: [
                              Text(
                                widget.shopName,
                                style: GoogleFonts.poppins(
                                  // 🚨 FIX: Explicitly set the fontSize to the scaled variable
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2D3436),
                                ),
                              ),
                              if(widget.isCertified)
                                const VerifiedBadge(isCertified: true)
                              else
                                const ProfileVerified(),
                              FutureBuilder<Map<String, dynamic>>(
                                future: fetchRatingStats(widget.serviceId),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) return const SizedBox.shrink();
                                  final stats = snap.data!;
                                  final avg = (stats['avg'] as double).clamp(0.0, 5.0);
                                  final count = stats['count'] as int;
                                  if (count == 0) return const SizedBox.shrink();

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Increased padding
                                    decoration: BoxDecoration(
                                      color: AppColors.accentColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, size: ratingIconSize, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${avg.toStringAsFixed(1)} ($count)",
                                          style: GoogleFonts.poppins(
                                            fontSize: ratingTextSize, // Uses larger size
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          // --- Service ID ---
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Service ID: ",
                                  style: GoogleFonts.poppins(
                                    fontSize: subTextSize, // Uses larger size
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  shortId,
                                  style: GoogleFonts.poppins(
                                    fontSize: subTextSize, // Uses larger size
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: widget.serviceId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Service ID copied")),
                                    );
                                  },
                                  child: Icon(Icons.copy, size: subTextSize + 4, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isWideScreen ? 10 : 3),
                          // --- Branch Selector ---
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                                child: BranchSelector(
                                  currentServiceId: widget.serviceId,
                                  currentAreaName: widget.areaName,
                                  otherBranches: widget.otherBranches,
                                  onBranchSelected: (newBranchId) {
                                    if (newBranchId != null) {
                                      widget.onBranchSelected(newBranchId);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWideScreen ? 5 : 8),
                // Increased vertical space

                // --- Info Grid Row (Now takes up full width) ---
              ],
            ),
          );
        },
      );
    }
  }

  class _InfoGridRow extends StatelessWidget {
    final double distanceKm;
    final String openTime;
    final String closeTime;
    final DesignConstants design;
    final String maxPetsAllowed;
    final bool isWideScreen; // New flag

    const _InfoGridRow({
      Key? key,
      required this.openTime,
      required this.closeTime,
      required this.design,
      required this.maxPetsAllowed,
      required this.distanceKm,
      required this.isWideScreen,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      // 1. Define all four information pills (same as before)
      final pills = [
        _InfoPill(
          icon: Icons.access_time_rounded,
          label: 'Open Time',
          value: openTime,
          design: design,
          isWideScreen: isWideScreen,
        ),
        _InfoPill(
          icon: Icons.access_time_rounded,
          label: 'Close Time',
          value: closeTime,
          design: design,
          isWideScreen: isWideScreen,
        ),
        _InfoPill(
          icon: Icons.filter_list,
          label: 'Daily pet limit',
          value: (maxPetsAllowed == "0") ? "No limit" : maxPetsAllowed,
          design: design,
          isWideScreen: isWideScreen,
        ),
        _InfoPill(
          icon: Icons.location_on_outlined,
          label: 'Distance',
          value: '${distanceKm.toStringAsFixed(1)} km',
          design: design,
          isWideScreen: isWideScreen,
        ),
      ];

      // Use consistent spacing for both mobile and desktop (adjust as needed)
      final double spacing = isWideScreen ? 16.0 : 12.0;

      // 🚨 FINAL FIX: Use Wrap to handle flowing and wrapping naturally.
      // Wrap will render all four pills in a single row if space allows,
      // and wrap them to the next line if the column gets too narrow.
      return Wrap(
        alignment: WrapAlignment.start,
        spacing: spacing,      // Horizontal spacing between pills
        runSpacing: spacing,   // Vertical spacing between lines
        children: pills,       // Let Wrap manage the layout of the four pills
      );
    }
  }
  class _InfoPill extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;
    final DesignConstants design;
    final bool isWideScreen; // New flag

    const _InfoPill({
      Key? key,
      required this.icon,
      required this.label,
      required this.value,
      required this.design,
      required this.isWideScreen,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      // 🚨 TWEAKED SIZING: Minimal increase for desktop (close to mobile size)
      final iconSize = isWideScreen ? 20.0 : 18.0; // Slightly larger icon
      final labelSize = isWideScreen ? 12.0 : 10.0; // Slightly larger label text
      final valueSize = isWideScreen ? 14.0 : 12.0; // Slightly larger value text

      // Minimized internal padding
      final horizontalPadding = isWideScreen ? 12.0 : 8.0;
      final verticalPadding = isWideScreen ? 6.0 : 2.0;
      final borderRadius = isWideScreen ? 8.0 : 6.0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: design.primaryColor),
            SizedBox(width: isWideScreen ? 8 : 8), // Minimal spacing
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: labelSize,
                    color: design.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: valueSize,
                    color: design.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
  class _DetailSection extends StatelessWidget {
    final String title;
    final String content;
    final DesignConstants design;
    final Widget? child;

    const _DetailSection({
      Key? key,
      required this.title,
      required this.content,
      required this.design,
      this.child,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 5),
          if (child != null)
            child!
          else
            ExpandableText(
              text: content,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
              expandText: "Show more",
              collapseText: "Show less",
              maxLines: 2,
              linkStyle: GoogleFonts.poppins( // ✅ custom style
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),

        ],
      );
    }
  }

  // In BoardingServiceDetailPage.dart
  class _RatesSection extends StatelessWidget {
    final String title;
    final Map<String, int> rates;
    final Map<String, int> originalRates;
    final DesignConstants design;
    final bool isOfferActive;

    const _RatesSection({
      Key? key,
      required this.title,
      required this.rates,
      required this.design,
      required this.originalRates,
      this.isOfferActive = false,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isOfferActive ? "$title" : title, // Use a more descriptive title
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3436),
                  ),
                ),
                if (isOfferActive)
                  Container(
                    margin: const EdgeInsets.only(left: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Offer',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            const Divider(color: Colors.grey),
            const SizedBox(height: 5),
            Column(
              children: rates.entries.map((offerEntry) {
                final originalPrice = originalRates[offerEntry.key];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        offerEntry.key,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: design.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          if (isOfferActive && originalPrice != null && originalPrice != offerEntry.value)
                            Text(
                              '₹$originalPrice',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (isOfferActive && originalPrice != null && originalPrice != offerEntry.value)
                            const SizedBox(width: 8),
                          Text(
                            '₹${offerEntry.value}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: design.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
  }

  class ExpandableText extends StatefulWidget {
    final String text;
    final TextStyle style;
    final int maxLines;
    final String expandText;
    final String collapseText;
    final TextStyle? linkStyle; // ✅ new property


    const ExpandableText({
      Key? key,
      required this.text,
      required this.style,
      this.maxLines = 3,
      this.expandText = 'Show more',
      this.collapseText = 'Show less', this.linkStyle,
    }) : super(key: key);

    @override
    _ExpandableTextState createState() => _ExpandableTextState();
  }

  class _ExpandableTextState extends State<ExpandableText> {
    bool _expanded = false;
    bool _needsToggle = false;

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final span = TextSpan(text: widget.text, style: widget.style);
        final tp = TextPainter(
          maxLines: widget.maxLines,
          text: span,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: MediaQuery.of(context).size.width - 48);
        if (tp.didExceedMaxLines != _needsToggle) {
          setState(() {
            _needsToggle = tp.didExceedMaxLines;
          });
        }
      });
    }

    @override
    Widget build(BuildContext context) {
      return LayoutBuilder(builder: (context, constraints) {
        final textWidget = Text(
          widget.text,
          style: widget.style,
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          textAlign: TextAlign.justify,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textWidget,
            if (_needsToggle)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Text(
                  _expanded ? widget.collapseText : widget.expandText,
                  style: widget.linkStyle ??
                      GoogleFonts.poppins( // fallback if no style given
                        color: const Color(0xFF209696),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
          ],
        );
      });
    }
  }
  class _GalleryGridSection extends StatelessWidget {
    final List<String> imageUrls;
    final DesignConstants design;

    const _GalleryGridSection({
      Key? key,
      required this.imageUrls,
      required this.design,
    }) : super(key: key);

    void _openImageViewer(BuildContext context, int initialIndex) {
      showDialog(
        context: context,
        builder: (_) => _ImageViewerDialog(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          design: design,
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      // We use LayoutBuilder to determine the width available to this specific widget,
      // which is helpful since it lives inside a constrained column on desktop.
      return LayoutBuilder(
        builder: (context, constraints) {
          // Tweak Point 1: Determine if we are in a desktop-like constrained context.
          // If the container holding the gallery is wider than 400px, we assume it's a wide screen
          // and can support more, smaller columns.
          final bool isDesktopContext = constraints.maxWidth > 400.0;

          // Tweak Point 2: Increase crossAxisCount to make each image smaller.
          // 5 columns on desktop, 3 columns on mobile (default).
          final int crossAxisCount = isDesktopContext ? 5 : 3;

          // Tweak Point 3: Scale down the font size for the "+X" overlay on desktop.
          final double overlayFontSize = isDesktopContext ? 14.0 : 16.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              GridView.builder(
                padding: EdgeInsets.zero,
                primary: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: imageUrls.length > 3 ? 3 : imageUrls.length, // show max 3 previews
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount, // <<< SCALED UP FOR DESKTOP
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  // First two images always normal
                  if (index < 2) {
                    return GestureDetector(
                      onTap: () => _openImageViewer(context, index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }

                  // Third image
                  if (imageUrls.length > 3 && index == 2) {
                    final remaining = imageUrls.length - 3;
                    return GestureDetector(
                      onTap: () => _openImageViewer(context, index),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Text(
                            "+$remaining",
                            style: GoogleFonts.poppins(
                              fontSize: overlayFontSize, // <<< SCALED DOWN FOR DESKTOP
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // If exactly 3 images → show third one normally
                  return GestureDetector(
                    onTap: () => _openImageViewer(context, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }
  class _ImageViewerDialog extends StatefulWidget {
    final List<String> imageUrls;
    final int initialIndex;
    final DesignConstants design;

    const _ImageViewerDialog({
      Key? key,
      required this.imageUrls,
      required this.initialIndex,
      required this.design,
    }) : super(key: key);

    @override
    __ImageViewerDialogState createState() => __ImageViewerDialogState();
  }

  class __ImageViewerDialogState extends State<_ImageViewerDialog> {
    late PageController _pageController;
    late int _currentIndex;

    @override
    void initState() {
      super.initState();
      _currentIndex = widget.initialIndex;
      _pageController = PageController(initialPage: _currentIndex);
    }

    void _previousImage() {
      if (_currentIndex > 0) {
        _currentIndex--;
        _pageController.animateToPage(_currentIndex,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }

    void _nextImage() {
      if (_currentIndex < widget.imageUrls.length - 1) {
        _currentIndex++;
        _pageController.animateToPage(_currentIndex,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }

    @override
    Widget build(BuildContext context) {
      return Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            Positioned(
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 30),
                onPressed: _previousImage,
              ),
            ),
            Positioned(
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 30),
                onPressed: _nextImage,
              ),
            ),
            Positioned(
              top: 30,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }
  }

  class _SectionSpacer extends StatelessWidget {
    const _SectionSpacer({Key? key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          const SizedBox(height: 1),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 1),
        ],
      );
    }
  }

  class _ActionFooter extends StatelessWidget {
    final DesignConstants design;
    final VoidCallback onPressed;

    const _ActionFooter({
      Key? key,
      required this.design,
      required this.onPressed,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: design.shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: design.primaryColor.withOpacity(0.9),
                width: 4.0,
              ),
            ),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue Booking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Colors.black,
              ),
            ],
          ),
        ),
      );
    }
  }

  extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return "";
      return "${this[0].toUpperCase()}${substring(1)}";
    }
  }


  class PetPricing {
    final String petName;
    final Map<String, String> ratesDaily;
    final Map<String, String> walkingRatesDaily;
    final Map<String, String> mealRatesDaily;
    final Map<String, String> offerRatesDaily;
    final Map<String, String> offerWalkingRatesDaily;
    final Map<String, String> offerMealRatesDaily;
    final Map<String, dynamic> feedingDetails;
    final List<String> acceptedSizes;   // <-- ADD THIS LINE
    final List<String> acceptedBreeds;  // <-- ADD THIS LINE


    PetPricing( {
      required this.petName,
      required this.ratesDaily,
      required this.walkingRatesDaily,
      required this.mealRatesDaily,
      required this.offerRatesDaily,
      required this.offerWalkingRatesDaily,
      required this.offerMealRatesDaily,
      required this.feedingDetails,
      required this.acceptedSizes,     // <-- ADD THIS LINE
      required this.acceptedBreeds,    // <-- ADD THIS LINE
    });
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
            "MFP Certified",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.accentColor,
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
                  color: AppColors.accentColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Corrected code for VerifiedBadge class
    @override
    Widget build(BuildContext context) {
      // Return the GestureDetector directly, without Positioned
      return GestureDetector(
        onTap: () => _showDialog(
          context,
          'mfp_certified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:AppColors.accentColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
              // You also have a text widget here, but it's missing from your snippet
              // Text("MFP Certified", ...),
            ],
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

    // Corrected code for ProfileVerified class
    @override
    Widget build(BuildContext context) {
      // Return the GestureDetector directly, without Positioned
      return GestureDetector(
        onTap: () => _showDialog(
          context,
          'profile_verified_user_app',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      );
    }
  }

  class PetPricingTable extends StatefulWidget {
    final bool isOfferActive;
    final List<String> petDocIds; // now list of pet document IDs
    final Map<String, Map<String, int>> ratesDaily;
    final Map<String, Map<String, int>> walkingRates;
    final Map<String, Map<String, int>> mealRates;
    final Map<String, Map<String, int>> offerRatesDaily;
    final Map<String, Map<String, int>> offerWalkingRates;
    final Map<String, Map<String, int>> offerMealRates;
    final String? initialSelectedPet;

    const PetPricingTable({
      Key? key,
      required this.isOfferActive,
      required this.petDocIds,
      required this.ratesDaily,
      required this.walkingRates,
      required this.mealRates,
      required this.offerRatesDaily,
      required this.offerWalkingRates,
      required this.offerMealRates,
      this.initialSelectedPet,
    }) : super(key: key);

    @override
    State<PetPricingTable> createState() => _PetPricingTableState();
  }

  class _PetPricingTableState extends State<PetPricingTable> {
    late String _selectedPet;

    @override
    void initState() {
      super.initState();
      _selectedPet = widget.initialSelectedPet ?? widget.petDocIds.first;
    }

    int _getTotal(int boarding, int walking, int meal) => boarding + walking + meal;

    // Modified to accept and use scaled font sizes
    Widget _buildPriceCell(int standardPrice, int? offerPrice, double baseFontSize) {
      if (widget.isOfferActive && offerPrice != null && offerPrice != standardPrice) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹$standardPrice',
              style: GoogleFonts.poppins(
                fontSize: baseFontSize - 1, // Scaled down for strikethrough price
                color: Colors.grey.shade600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            SizedBox(width: baseFontSize * 0.4), // Scaled spacing
            Text(
              '₹$offerPrice',
              style: GoogleFonts.poppins(
                fontSize: baseFontSize + 1, // Slightly bigger for offer price
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        );
      }
      return Text(
        '₹$standardPrice',
        style: GoogleFonts.poppins(
          fontSize: baseFontSize,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 800.0;

          // --- Scaled Metrics based on screen width ---
          final double baseFontSize = isWideScreen ? 18.0 : 14.0;
          final double headerFontSize = isWideScreen ? 20.0 : 16.0;
          final double cellFontSize = isWideScreen ? 16.0 : 13.0;
          final double columnSpacing = isWideScreen ? 32.0 : 16.0;
          final double headingRowHeight = isWideScreen ? 45.0 : 36.0;
          final double dataRowHeight = isWideScreen ? 55.0 : 42.0;


          final sizes = {...widget.ratesDaily[_selectedPet]!.keys, ...widget.walkingRates[_selectedPet]!.keys, ...widget.mealRates[_selectedPet]!.keys}.toList();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: isWideScreen ? BoxConstraints(minWidth: constraints.maxWidth - 40) : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Row ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Increased vertical padding

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Price Details",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: headerFontSize, // Scaled up
                          ),
                        ),
                        SizedBox(width: isWideScreen ? 50 : 25), // Scaled spacing
                        if (widget.isOfferActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Scaled padding
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.accentColor, const Color(0xFFD96D0B)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_offer, color: Colors.white, size: headerFontSize * 0.8), // Scaled icon
                                const SizedBox(width: 6),
                                Text(
                                  "SPECIAL OFFER",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: cellFontSize * 0.8, // Scaled font
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- DataTable ---
                  DataTable(
                    columnSpacing: columnSpacing, // Scaled
                    headingRowHeight: headingRowHeight, // Scaled
                    dataRowMinHeight: dataRowHeight * 0.9,
                    dataRowMaxHeight: dataRowHeight, // Scaled
                    horizontalMargin: isWideScreen ? 18.0 : 12.0, // Increased margin
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1),
                      verticalInside: BorderSide(color: Colors.grey.shade300, width: 1),
                      top: BorderSide(color: Colors.grey.shade400, width: 1),
                      bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                      left: BorderSide(color: Colors.grey.shade400, width: 1),
                      right: BorderSide(color: Colors.grey.shade400, width: 1),
                    ),
                    columns: [
                      DataColumn(
                        label: Container(
                          padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 12 : 8, vertical: isWideScreen ? 6 : 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPet,
                              items: widget.petDocIds
                                  .map((petId) => DropdownMenuItem(
                                value: petId,
                                child: Text(
                                  petId,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: cellFontSize, // Scaled
                                  ),
                                ),
                              ))
                                  .toList(),
                              onChanged: (newPet) {
                                if (newPet != null) {
                                  setState(() {
                                    _selectedPet = newPet;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      ...sizes.map(
                            (size) => DataColumn(
                          label: Text(
                            size,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: cellFontSize, // Scaled
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: [
                      // Boarding row
                      DataRow(
                        cells: [
                          DataCell(
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isWideScreen ? 6 : 4, horizontal: isWideScreen ? 10 : 6),
                              child: Text(
                                "Boarding",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: cellFontSize), // Scaled
                              ),
                            ),
                          ),
                          ...sizes.map((size) {
                            final standard = widget.ratesDaily[_selectedPet]![size] ?? 0;
                            final offer = widget.offerRatesDaily[_selectedPet]?[size] ?? standard;
                            return DataCell(_buildPriceCell(standard, widget.isOfferActive ? offer : null, cellFontSize)); // Passed scaled size
                          }),
                        ],
                      ),

                      // Walking row
                      DataRow(
                        cells: [
                          DataCell(
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isWideScreen ? 6 : 4, horizontal: isWideScreen ? 10 : 6),
                              child: Text(
                                "Walking",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: cellFontSize), // Scaled
                              ),
                            ),
                          ),
                          ...sizes.map((size) {
                            final standard = widget.walkingRates[_selectedPet]![size] ?? 0;
                            final offer = widget.offerWalkingRates[_selectedPet]?[size] ?? standard;
                            return DataCell(_buildPriceCell(standard, widget.isOfferActive ? offer : null, cellFontSize)); // Passed scaled size
                          }),
                        ],
                      ),

                      // Meal row
                      DataRow(
                        cells: [
                          DataCell(
                            Container(
                              color: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isWideScreen ? 6 : 4, horizontal: isWideScreen ? 10 : 6),
                              child: Text(
                                "Meal",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: cellFontSize), // Scaled
                              ),
                            ),
                          ),
                          ...sizes.map((size) {
                            final standard = widget.mealRates[_selectedPet]![size] ?? 0;
                            final offer = widget.offerMealRates[_selectedPet]?[size] ?? standard;
                            return DataCell(_buildPriceCell(standard, widget.isOfferActive ? offer : null, cellFontSize)); // Passed scaled size
                          }),
                        ],
                      ),

                      // Total row
                      DataRow(
                        color: MaterialStateProperty.resolveWith<Color?>(
                              (Set<MaterialState> states) => Colors.yellow.shade100,
                        ),
                        cells: [
                          DataCell(
                            Container(
                              color: Colors.yellow.shade200,
                              padding: EdgeInsets.symmetric(vertical: isWideScreen ? 6 : 4, horizontal: isWideScreen ? 10 : 6),
                              child: Text(
                                "Total",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: baseFontSize), // Scaled
                              ),
                            ),
                          ),
                          ...sizes.map((size) {
                            final boarding = widget.ratesDaily[_selectedPet]![size] ?? 0;
                            final walking = widget.walkingRates[_selectedPet]![size] ?? 0;
                            final meal = widget.mealRates[_selectedPet]![size] ?? 0;
                            final oldTotal = boarding + walking + meal;

                            int? newTotal;
                            if (widget.isOfferActive) {
                              final offerBoarding = widget.offerRatesDaily[_selectedPet]?[size] ?? boarding;
                              final offerWalking = widget.offerWalkingRates[_selectedPet]?[size] ?? walking;
                              final offerMeal = widget.offerMealRates[_selectedPet]?[size] ?? meal;
                              newTotal = offerBoarding + offerWalking + offerMeal;
                            }

                            if (widget.isOfferActive && newTotal != null && newTotal != oldTotal) {
                              return DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹$oldTotal',
                                      style: GoogleFonts.poppins(
                                        fontSize: cellFontSize * 0.85, // Scaled
                                        color: Colors.grey.shade600,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '₹$newTotal',
                                      style: GoogleFonts.poppins(
                                        fontSize: baseFontSize, // Scaled
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return DataCell(
                              Text(
                                '₹$oldTotal',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: baseFontSize), // Scaled
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    }
  }
  class PetChipsRow extends StatefulWidget {
    final List<String> pets;
    final String initialSelectedPet;

    const PetChipsRow({
      Key? key,
      required this.pets,
      required this.initialSelectedPet,
    }) : super(key: key);

    @override
    State<PetChipsRow> createState() => _PetChipsRowState();
  }

  class _PetChipsRowState extends State<PetChipsRow> {
    late String _selectedPet;

    @override
    void initState() {
      super.initState();
      _selectedPet = widget.initialSelectedPet;
    }

    @override
    Widget build(BuildContext context) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: widget.pets.map((pet) {
            final isSelected = pet == _selectedPet;

            // Capitalize first letter only
            final displayName =
            pet.isNotEmpty ? pet[0].toUpperCase() + pet.substring(1) : pet;

            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPet = pet;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pets,
                        size: 16,
                        color:  AppColors.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
  }

  class PetVarietiesTable extends StatefulWidget {
    final List<String> petDocIds;
    final String? selectedPet;
    final List<String> acceptedSizes;
    final List<String> acceptedBreeds;
    final Function(String?) onPetSelected;

    const PetVarietiesTable({
      Key? key,
      required this.petDocIds,
      required this.selectedPet,
      required this.acceptedSizes,
      required this.acceptedBreeds,
      required this.onPetSelected,
    }) : super(key: key);

    @override
    State<PetVarietiesTable> createState() => _PetVarietiesTableState();
  }

  class _PetVarietiesTableState extends State<PetVarietiesTable>
      with TickerProviderStateMixin {
    late AnimationController _controller;
    late Animation<double> _arrowAnimation;
    late AnimationController _blinkController;
    bool _expanded = false;
    String? _currentSelectedPet;



    @override
    void initState() {
      super.initState();
      _currentSelectedPet = widget.selectedPet; // <-- default pet


      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      _arrowAnimation = Tween<double>(begin: 0, end: 0.5).animate(_controller);

      _blinkController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..repeat(reverse: true);
    }

    @override
    void dispose() {
      _controller.dispose();
      _blinkController.dispose();
      super.dispose();
    }

    int? extractMinWeight(String size) {
      final regExp = RegExp(r'\((\d+)');
      final match = regExp.firstMatch(size);
      if (match != null && match.groupCount >= 1) {
        return int.tryParse(match.group(1)!);
      }
      return null;
    }

    @override
    Widget build(BuildContext context) {
      final sortedAcceptedSizes = List<String>.from(widget.acceptedSizes);
      sortedAcceptedSizes.sort((a, b) {
        final minA = extractMinWeight(a);
        final minB = extractMinWeight(b);
        if (minA != null && minB != null) {
          return minA.compareTo(minB);
        }
        return a.compareTo(b);
      });

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0,vertical: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [

                    ExpandableChipList(
                      title: 'Accepted Sizes',
                      items: sortedAcceptedSizes,
                      color: AppColors.primaryColor,
                    ),
                    ExpandableChipList(
                      title: 'Accepted Breeds',
                      items: widget.acceptedBreeds,
                      color: AppColors.accentColor,

            ),
          ],
        ),
      );
    }
  }

  // Simple Chip List Helper
  class _ChipList extends StatefulWidget {
    final String title;
    final List<String> items;
    final Color color;
    final bool showSearchBar;

    const _ChipList({
      Key? key,
      required this.title,
      required this.items,
      required this.color,
      this.showSearchBar = false,
    }) : super(key: key);

    @override
    State<_ChipList> createState() => _ChipListState();
  }

  class _ChipListState extends State<_ChipList> {
    bool _isExpanded = false;
    String _searchQuery = '';

    @override
    Widget build(BuildContext context) {
      // Filter items based on search
      final filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      // Wrap of chips
      final wrapWidget = Wrap(
        spacing: 8,
        runSpacing: 6,
        children: filteredItems
            .map(
              (item) => Chip(
            label: Text(item.capitalize()),
            backgroundColor: widget.color.withOpacity(0.15),
            labelStyle: GoogleFonts.poppins(
              color: widget.color,
              fontSize: 13,
            ),
          ),
        )
            .toList(),
      );

      final isOverflowing = filteredItems.length > 6; // Adjust visible limit

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + optional search bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
              if (widget.showSearchBar)
                SizedBox(
                  width: 150,
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search',
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Overflow / fade effect
          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No matching items found.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              ),
            )
          else if (isOverflowing && !_isExpanded)
            SizedBox(
              height: 40,
              child: Stack(
                children: [
                  ClipRect(child: wrapWidget),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.white],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            wrapWidget,

          // Show more / less toggle
          if (isOverflowing)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Text(
                  _isExpanded ? "Show less" : "Show more...",
                  style: GoogleFonts.poppins(
                    color: widget.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }


  class ExpandableChipList extends StatefulWidget {
    final String title;
    final List<String> items;
    final Color color;
    final bool showSearchBar;

    const ExpandableChipList({
      Key? key,
      required this.title,
      required this.items,
      required this.color,
      this.showSearchBar = false,
    }) : super(key: key);

    @override
    State<ExpandableChipList> createState() => _ExpandableChipListState();
  }

  class _ExpandableChipListState extends State<ExpandableChipList> {
    String _searchQuery = '';

    @override
    Widget build(BuildContext context) {
      // Filter items based on search
      final filteredItems = widget.items
          .where((item) => item.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      final wrapWidget = Wrap(
        spacing: 8,
        runSpacing: 6,
        children: filteredItems
            .map((item) => Chip(
          backgroundColor: Colors.white, // chip fill color
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black87, width: 1), // <-- border color here
            borderRadius: BorderRadius.circular(8),
          ),
          label: Text(
            item.capitalize(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ))
            .toList(),
      );



      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + optional search bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
              if (widget.showSearchBar)
                SizedBox(
                  width: 150,
                  height: 38,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search',
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Overflow logic with fade mask
          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No matching items found.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              ),
            ),
          wrapWidget,



        ],
      );
    }
  }




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

  class _SimpleMealCard extends StatelessWidget {
    final String mealTitle;
    final Map<String, dynamic> mealData;
    final Function(BuildContext, String, Map<String, dynamic>) onDetailsPressed;

    const _SimpleMealCard({
      Key? key,
      required this.mealTitle,
      required this.mealData,
      required this.onDetailsPressed,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      final imageUrl = mealData['image'] as String?;
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: InkWell(
          onTap: () => onDetailsPressed(context, mealTitle, mealData),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade100,
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.restaurant_outlined, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                // Text and Button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mealTitle.capitalize(),
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tap to see details",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }
  }
  // REPLACE your old FeedingInfoButton and its helpers with this entire class
  class FeedingInfoButton extends StatelessWidget {
    final Map<String, Map<String, dynamic>> allFeedingDetails;
    final String? initialSelectedPet;

    const FeedingInfoButton({
      Key? key,
      required this.allFeedingDetails,
      required this.initialSelectedPet,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
      // We use a Row with MainAxisAlignment.start to prevent the Padding from
      // forcing the button to full width, and rely on the button's internal sizing.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // Ensure it starts from the left
          mainAxisSize: MainAxisSize.min, // Make the row only as wide as the button
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Use explicit horizontal padding
                // 🚨 FIX: Remove minimumSize(double.infinity), allowing it to shrink-wrap its content
                // minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                _showFeedingInfoDialog(context, allFeedingDetails, initialSelectedPet);
              },
              icon: const Icon(Icons.restaurant_menu_outlined, color: Colors.white),
              label: Text(
                "View Feeding Information",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    void _showFeedingInfoDialog(
        BuildContext context, Map<String, Map<String, dynamic>> allFeedingDetails, String? initialSelectedPet) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          // Use StatefulBuilder to manage the state of the dropdown inside the dialog
          return StatefulBuilder(
            builder: (context, setState) {
              // Determine the initially selected pet for the dialog's state
              String selectedPet = initialSelectedPet ?? allFeedingDetails.keys.first;
              if (!allFeedingDetails.containsKey(selectedPet)) {
                selectedPet = allFeedingDetails.keys.first;
              }

              final currentFeedingDetails = allFeedingDetails[selectedPet] ?? {};

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                title: Row(
                  children: [
                    Icon(Icons.restaurant_menu_outlined, color: AppColors.primaryColor),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "Feeding Information",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Column(
                    children: [
                      // Only show the dropdown if there is more than one pet type
                      if (allFeedingDetails.length > 1)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedPet,
                              isExpanded: true,
                              items: allFeedingDetails.keys.map((petName) {
                                return DropdownMenuItem<String>(
                                  value: petName,
                                  child: Text(petName.capitalize(),
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  // Use the setState from StatefulBuilder to update the dialog's UI
                                  setState(() {
                                    selectedPet = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      // The list of meals for the selected pet
                      Expanded(
                        child: _buildFeedingInfo(currentFeedingDetails),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Close",
                      style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                titlePadding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                insetPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 24.0),
              );
            },
          );
        },
      );
    }

    Widget _buildFeedingInfo(Map<String, dynamic> feedingDetails) {
      if (feedingDetails.isEmpty) {
        return const Center(
          child: Text("No feeding information provided for this pet."),
        );
      }

      const desiredOrder = [
        'Morning Meal (Breakfast)', 'Afternoon Meal (Lunch)', 'Evening Meal (Dinner)', 'Treats', 'Water Availability'
      ];

      final mealEntries = feedingDetails.entries.toList()
        ..sort((a, b) {
          final aIndex = desiredOrder.indexWhere((name) => name.toLowerCase() == a.key.toLowerCase());
          final bIndex = desiredOrder.indexWhere((name) => name.toLowerCase() == b.key.toLowerCase());
          return (aIndex == -1 ? desiredOrder.length : aIndex)
              .compareTo(bIndex == -1 ? desiredOrder.length : bIndex);
        });

      return ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: mealEntries.length,
        itemBuilder: (context, index) {
          final entry = mealEntries[index];
          return _SimpleMealCard(
            mealTitle: entry.key,
            mealData: entry.value as Map<String, dynamic>,
            onDetailsPressed: _showMealDetailsDialog,
          );
        },
      );
    }

    void _showMealDetailsDialog(BuildContext context, String mealTitle, Map<String, dynamic> mealData) {
      // This helper method remains the same as in the previous version
      final details = <Widget>[];

      IconData getIconForDetail(String fieldName) {
        switch (fieldName) {
          case 'food_title': return Icons.label_outline;
          case 'food_type': return Icons.category_outlined;
          case 'brand': return Icons.storefront_outlined;
          case 'ingredients': return Icons.list_alt_outlined;
          case 'quantity_grams': return Icons.scale_outlined;
          case 'feeding_time': return Icons.access_time_outlined;
          default: return Icons.info_outline;
        }
      }

      String getLabel(String fieldName) {
        if (fieldName == 'food_title') return 'Meal Name';
        return fieldName.replaceAll('_', ' ').capitalize();
      }

      for (var entry in mealData.entries) {
        if (entry.key == 'image') continue;
        final value = entry.value;
        final isValueMissing = value == null || (value is String && value.isEmpty) || (value is List && value.isEmpty);
        details.add(Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(getIconForDetail(entry.key), color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
                  children: [
                    TextSpan(text: "${getLabel(entry.key)}: ", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    TextSpan(
                      text: isValueMissing ? "N/A" : (value is List ? value.join(', ') : value.toString()),
                      style: GoogleFonts.poppins(
                          color: isValueMissing ? Colors.grey.shade500 : Colors.grey.shade800,
                          fontStyle: isValueMissing ? FontStyle.italic : FontStyle.normal),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ));
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(mealTitle.capitalize(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mealData['image'] != null && (mealData['image'] as String).isNotEmpty)
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(mealData['image'], width: double.infinity, height: 180, fit: BoxFit.cover)),
              if (mealData['image'] != null && (mealData['image'] as String).isNotEmpty) const SizedBox(height: 12),
              ...details.isNotEmpty ? details : [Text("No details to show.", style: GoogleFonts.poppins(color: Colors.grey.shade600))]
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Close", style: GoogleFonts.poppins(color: Colors.black87))),
          ],
        ),
      );
    }
  }

  class _DesktopFeedingInfoView extends StatefulWidget {
    final Map<String, Map<String, dynamic>> allFeedingDetails;
    final String initialSelectedPet;

    const _DesktopFeedingInfoView({
      required this.allFeedingDetails,
      required this.initialSelectedPet,
    });

    @override
    State<_DesktopFeedingInfoView> createState() => _DesktopFeedingInfoViewState();
  }

  class _DesktopFeedingInfoViewState extends State<_DesktopFeedingInfoView> {
    late String _selectedPet;

    @override
    void initState() {
      super.initState();
      _selectedPet = widget.initialSelectedPet;
      if (!widget.allFeedingDetails.containsKey(_selectedPet)) {
        _selectedPet = widget.allFeedingDetails.keys.first;
      }
    }

    // Helper method copied/adapted from FeedingInfoButton's internal logic
    Widget _buildFeedingInfo(Map<String, dynamic> feedingDetails) {
      if (feedingDetails.isEmpty) {
        return const Center(
          child: Text("No feeding information provided.", style: TextStyle(color: Colors.grey)),
        );
      }

      const desiredOrder = ['Morning Meal (Breakfast)', 'Afternoon Meal (Lunch)', 'Evening Meal (Dinner)', 'Treats', 'Water Availability'];

      final mealEntries = feedingDetails.entries.toList()
        ..sort((a, b) {
          final aIndex = desiredOrder.indexWhere((name) => name.toLowerCase() == a.key.toLowerCase());
          final bIndex = desiredOrder.indexWhere((name) => name.toLowerCase() == b.key.toLowerCase());
          return (aIndex == -1 ? desiredOrder.length : aIndex)
              .compareTo(bIndex == -1 ? desiredOrder.length : bIndex);
        });

      return ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: mealEntries.length,
        itemBuilder: (context, index) {
          final entry = mealEntries[index];
          // Note: You may want to simplify _SimpleMealCard functionality here,
          // or just display title/brief details since a dialog won't open on click.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
              ),
              child: Text(
                entry.key.capitalize(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          );
        },
      );
    }

    @override
    Widget build(BuildContext context) {
      final currentFeedingDetails = widget.allFeedingDetails[_selectedPet] ?? {};

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Feeding Details",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryColor),
            ),
            const SizedBox(height: 10),

            // Pet Dropdown
            if (widget.allFeedingDetails.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPet,
                    isExpanded: true,
                    items: widget.allFeedingDetails.keys.map((petName) {
                      return DropdownMenuItem<String>(
                        value: petName,
                        child: Text(petName.capitalize(), style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPet = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),

            // Meal List
            Expanded(
              child: _buildFeedingInfo(currentFeedingDetails),
            ),
          ],
        ),
      );
    }
  }

  class ColorStrip extends StatelessWidget {
    const ColorStrip({super.key});

    @override
    Widget build(BuildContext context) {
      final isWideScreen = MediaQuery.of(context).size.width > 600; // you can adjust breakpoint

      return isWideScreen
          ? Container(
        width: double.infinity,
        height: 12, // small height
        color: const Color(0xFFF67B0D), // your orange color
      )
          : const SizedBox.shrink(); // show nothing if not wide
    }
  }