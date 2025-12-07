import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import '../../../screens/Boarding/preloaders/petpreloaders.dart';
import '../Pets/AddPetPage.dart';
import 'HourlySummaryPage.dart';
import 'new_location.dart';

// Reusable Components
class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
class CustomCard extends StatelessWidget {
  final Widget child;
  final Color color;

  const CustomCard({required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [AppShadows.cardShadow],
      ),
      child: child,
    );
  }
}

class ServiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final ValueChanged<bool> onChanged;

  const ServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingLg,
        vertical: AppDimensions.spacingMd,
      ),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.bodyLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: Switch.adaptive(
        value: isActive,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

class FoodOptionTile extends StatelessWidget {
  final String title;
  final Widget subtitle; // Change to Widget
  final double? cost;
  final bool isSelected;
  final VoidCallback onTap;

  const FoodOptionTile({
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Icon(
                Icons.check,
                size: 16,
                color: isSelected ? Colors.white : Colors.transparent,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge),
                  subtitle, // Now we pass the widget directly
                ],
              ),
            ),
            if (cost != null)
              Text(
                '₹${cost!.toStringAsFixed(2)}/day',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Style Constants
class AppDimensions {
  static const double radiusLg = 20;
  static const double radiusMd = 15;
  static const double spacingLg = 16;
  static const double spacingMd = 12;
}

class AppColors {
  static const Color primary = Color(0xFF000000);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color border = Color(0xFFDEE2E6);
}

class AppTextStyles {
  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: 0.5,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
}

class AppShadows {
  static BoxShadow get cardShadow => BoxShadow(
    color: Colors.blue.shade100.withOpacity(0.2),
    blurRadius: 20,
    offset: const Offset(0, 10),
  );
}

class StageProgressBar extends StatelessWidget {
  final int currentStage;
  final int totalStages; // now 4
  final EdgeInsetsGeometry padding;
  final void Function(int)? onStepTap;

  const StageProgressBar({
    Key? key,
    required this.currentStage,
    required this.totalStages,  // pass 4 here
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.onStepTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double circleSize = 36.0;
    const double connectorHeight = 4.0;
    const Color completedColor = Color(0xFF4CAF50);
    final Color pendingColor = Colors.green.shade200;
    const Color futureBorder = Colors.grey;

    // **1) Update to 4 labels**:
    const List<String> labels = [
      'Pets',
      'Date',
      'Time-Slots',
      'Extras',
    ];

    final double connectorTopMargin = (circleSize / 2) - (connectorHeight / 2);

    // **2) Generate 4 circles + 3 connectors**: 4*2−1 = 7 widgets
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalStages * 2 - 1, (index) {
          if (index.isOdd) {
            final connectorIndex = index ~/ 2;
            Color lineColor;
            if (connectorIndex < currentStage - 1) {
              lineColor = completedColor;
            } else if (connectorIndex == currentStage - 1) {
              lineColor = pendingColor;
            } else {
              lineColor = Colors.transparent;
            }
            return Expanded(
              child: Container(
                height: connectorHeight,
                margin: EdgeInsets.only(top: connectorTopMargin),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepNumber = (index ~/ 2) + 1;
          final isCompleted = stepNumber < currentStage;
          final isCurrent   = stepNumber == currentStage;

          Color bg;
          Widget child;
          Color border;
          if (isCompleted) {
            bg = completedColor;
            child = const Icon(Icons.check, color: Colors.white, size: 20);
            border = completedColor;
          } else if (isCurrent) {
            bg = Colors.white;
            child = Text(
              '$stepNumber',
              style: const TextStyle(
                color: completedColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            );
            border = completedColor;
          } else {
            bg = Colors.white;
            child = Text(
              '$stepNumber',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            );
            border = futureBorder;
          }

          return GestureDetector(
            onTap: onStepTap != null ? () => onStepTap!(stepNumber) : null,
            child: SizedBox(
              width: circleSize + 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: child,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[stepNumber - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                      isCompleted || isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: isCompleted || isCurrent
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}


// 2) Example usage in your page's build:
// replace existing StageProgressBar(...) with this:

class HourlyBoardingParametersSelectionPage extends StatefulWidget {
  final double price;
  final String walkingFee;
  final int max_pets_allowed;
  final String current_count_of_pet;
  final GeoPoint sp_location;
  final String companyName;
  final String sp_id;
  final String close_time;
  final String shopName;
  final String shopImage;
  final String open_time;
  final String mode;
  final String serviceId;
  final Map<String,int> rates;

  HourlyBoardingParametersSelectionPage({
    required this.price,
    required this.sp_location,
    required this.companyName,
    required this.sp_id,
    required this.shopName,
    required this.shopImage,
    required this.max_pets_allowed,
    required this.current_count_of_pet,
    required this.walkingFee,
    required this.close_time,
    required this.serviceId,
    required this.open_time, required this.mode, required this.rates,
  });

  @override
  _HourlyBoardingParametersSelectionPageState createState() =>
      _HourlyBoardingParametersSelectionPageState();
}

class _HourlyBoardingParametersSelectionPageState
    extends State<HourlyBoardingParametersSelectionPage> {
  // ---------------- State Variables ----------------
  // New variable to track the current step (0: Pet selection, 1: Calendar, 2: Additional Services)
  // inside class _BoardingParametersSelectionPageState {
  int currentStep = 0; // you already have this
  bool get hasAdditionalServices =>
      widget.walkingFee != '0' || _foodInfo != null;
  late TextEditingController _searchController;
  String _searchTerm = '';

  // replace your static totalSteps with this getter:
  int get totalSteps => hasAdditionalServices ? 4 : 3;

  // how many consecutive slots the user wants
  int? _suggestSlotCount;

// computed set of dates matching that suggestion
  Set<DateTime> _suggestedDays = {};

// helper to know if we’re actively filtering
  bool get _isSuggestActive => _suggestSlotCount != null;
  // Existing state variables
  DateTime? _startDate;
  List<Map<String, dynamic>> _filteredPets = [];

  int totalDays = 0;
  DateTime? _endDate;
  bool _pickupRequired = false;
  bool _dropoffRequired = false;
  bool _transportOptionSelected = false;
  bool _isFoodDescriptionExpanded = false;

  bool _dailyWalkingRequired = false;
  late double _pricePerHour;
  double _transportCost = 0.0;
  double _totalCost = 0.0;
  DateTime? _selectedDate;

  List<DateTime> _selectedDates = [];
  final double _costPerKm = 60.0;
  double _pickupDistance = 0.0;
  double? foodCost = 0.0;
  double? foodcostPerDay = 0.0;
  double _dropoffDistance = 0.0;
  Map<DateTime, int> _bookingCountMap = {};
  Set<DateTime> _maskedDates = {};
  List<String> _selectedPetIds = [];
  List<String> _selectedPetNames = [];
  List<Map<String, dynamic>> _pets = [];
  List<String> _selectedPetImages = [];
  List<DateTime> _unavailableDates = [];
  DateTime _selectedDay = DateTime.now();
  String? _selectedTransportVehicle;
  final List<String> _stepTitles = [
    'Select Your Pets',
    'Choose Booking Dates',
    'Time-Slots',
    'Additional Services',
  ];

  Map<String, Map<String, dynamic>> _locations = {};

  // Food option info remains as before.
  String _foodOption = 'self';
  List<String> _selectedTimeSlots = [];
  int _maxPerHour = 0;// 'provider' or 'self'
  Map<String, dynamic>?
  _foodInfo; // Contains { "Description": "...", "cost_per_day": "..." }
  late Future<List<Map<String, dynamic>>> _petListFuture;
  late final Stream<List<Map<String, dynamic>>> _petListStream;

  @override
  void initState() {
    super.initState();
    _pricePerHour = widget.price;
    _fetchLocations();
    _fetchUnavailableDates();
    _searchController = TextEditingController();
    // INITIALIZE the stream once here:
    _petListStream = PetService.instance.watchMyPetsAsMap(context);
    _calculateTransportCost();
    FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.sp_id)
        .get()
        .then((docSnap) {
      final raw = docSnap.data()?['max_pets_allowed_per_hour']?.toString() ?? '0';
      setState(() => _maxPerHour = int.tryParse(raw) ?? 0);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAllPets() {
    _searchController.clear();
    setState(() {
      _searchTerm = '';
      // Re‐assign the stream reference to force re‐subscription:
      _petListStream = PetService.instance.watchMyPetsAsMap(context);
    });
  }

  void _computeSuggestedDays(Map<DateTime,int> dayCount, int slotsPerDay) {
    final totalHours = slotsPerDay ~/ widget.max_pets_allowed;
    final freeSlotsPerDay = <DateTime,int>{};
    dayCount.forEach((day, petHours) {
      // petHours = pets × bookedSlots
      // so bookedSlots = petHours / petsPerSlotCapacity
      // here we assume MaxPetsPerHour==1 for simplicity; adjust if >1
      final bookedSlots = petHours ~/ widget.max_pets_allowed;
      freeSlotsPerDay[day] = totalHours - bookedSlots;
    });

    _suggestedDays = freeSlotsPerDay.entries
        .where((e) => e.value >= (_suggestSlotCount ?? 0))
        .map((e) => e.key)
        .toSet();
  }


  // ---------------- Data Methods (Unchanged) ----------------

  Future<void> _fetchUnavailableDates() async {
    try {
      // 1️⃣ Find your service document
      final serviceQuery = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .where('service_id', isEqualTo: widget.sp_id)
          .get();
      if (serviceQuery.docs.isEmpty) return;
      final serviceDoc = serviceQuery.docs.first;

      // 2️⃣ Load maxPetsAllowed
      final rawValue = serviceDoc['max_pets_allowed'];
      final int maxPets = int.tryParse(rawValue?.toString() ?? '') ?? 0;

      // 3️⃣ Aggregate booking counts
      Map<DateTime, int> dateCountMap = {};
      final bookingsQuery = await serviceDoc.reference
          .collection('service_request_boarding')
          .get();
      for (var booking in bookingsQuery.docs) {
        final data = booking.data();
        final status = data['status'] as String? ?? '';
        if (!(status == 'Pending' || status == 'Confirmed')) continue;

        final bookedDates = (data['selectedDates'] as List<dynamic>? ?? [])
            .cast<Timestamp>();
        final petsInBooking = data['numberOfPets'] as int? ?? 1;

        for (var ts in bookedDates) {
          final d = ts.toDate();
          final norm = DateTime(d.year, d.month, d.day);
          dateCountMap[norm] = (dateCountMap[norm] ?? 0) + petsInBooking;
        }
      }

      // 4️⃣ Compute fully‐booked days
      List<DateTime> unavailableDates = [];
      dateCountMap.forEach((date, count) {
        if (count >= maxPets) unavailableDates.add(date);
      });

      // 5️⃣ Also block days that would overflow if you add more pets
      final int totalPetsToAdd = _selectedPetIds.length;
      dateCountMap.forEach((date, currentCount) {
        if (currentCount + totalPetsToAdd > maxPets &&
            !unavailableDates.any((u) => isSameDay(u, date))) {
          unavailableDates.add(date);
        }
      });

      // ────────────────────────────────────────────────────
      // 6️⃣ NEW: Include your manually‐declared holidays/unavailability
      final holidaySnap = await serviceDoc.reference
          .collection('unavailabilities')
          .get();
      for (var doc in holidaySnap.docs) {
        final tsList = (doc.data()['dates'] as List<dynamic>?)
            ?.cast<Timestamp>() ??
            [];
        for (var ts in tsList) {
          final d = ts.toDate();
          final norm = DateTime(d.year, d.month, d.day);
          if (!unavailableDates.any((u) => isSameDay(u, norm))) {
            unavailableDates.add(norm);
          }
        }
      }
      // ────────────────────────────────────────────────────

      // 7️⃣ Update state
      setState(() {
        _unavailableDates = unavailableDates;
      });
    } catch (e) {
      print("Error fetching unavailable dates: $e");
    }
  }


  Future<void> _fetchLocations() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final User? currentUser = auth.currentUser;
      if (currentUser == null) {
        print("No current user for locations.");
        return;
      }
      final phoneNumber = currentUser.phoneNumber;
      if (phoneNumber == null) {
        print("No phone number available.");
        return;
      }
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_number', isEqualTo: phoneNumber)
          .get();
      if (userQuery.docs.isEmpty) {
        print("No user document found for phone number: $phoneNumber");
        return;
      }
      final userDoc = userQuery.docs.first;
      final locationsMap = userDoc['locations'] as Map<String, dynamic>?;
      if (locationsMap != null) {
        setState(() {
          _locations = locationsMap.map((key, value) {
            return MapEntry(key, value as Map<String, dynamic>);
          });
        });
        _calculateTransportCost();
      } else {
        print("No locations map found in user document.");
      }
    } catch (e) {
      print("Error fetching locations: $e");
    }
  }

  Future<double> _getDistanceFromGoogle(double originLat, double originLng,
      double destLat, double destLng) async {
    const apiKey = 'AIzaSyCbr1VKuRpq-1TYYhlbUEuWl5xZpUg3dBo';
    final url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$originLat,$originLng&destinations=$destLat,$destLng&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final elements = jsonResponse['rows']?[0]?['elements'];
      if (elements != null && elements[0]['status'] == 'OK') {
        double distanceMeters =
        (elements[0]['distance']['value'] as num).toDouble();
        return distanceMeters;
      }
    }
    print("Error in Google API response: ${response.body}");
    return 0.0;
  }

  Map<String, dynamic>? get _currentLocation {
    try {
      final currLoc = _locations.values
          .firstWhere((loc) => loc['current_location'] == true);
      return currLoc;
    } catch (e) {
      return null;
    }
  }

  Future<void> _calculateTransportCost() async {
    if (_locations.isNotEmpty) {
      final currentLoc = _currentLocation;
      if (currentLoc != null) {
        final userLocation = currentLoc['user_location'] as GeoPoint?;
        if (userLocation != null) {
          double distanceInMeters = await _getDistanceFromGoogle(
            userLocation.latitude,
            userLocation.longitude,
            widget.sp_location.latitude,
            widget.sp_location.longitude,
          );
          double distanceInKm = distanceInMeters / 1000.0;
          setState(() {
            _pickupDistance = _pickupRequired ? distanceInKm : 0.0;
            _dropoffDistance = _dropoffRequired ? distanceInKm : 0.0;
            _transportCost = (_pickupDistance + _dropoffDistance) * _costPerKm;
            _calculateTotalCost();
          });
          return;
        }
      }
    }
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;
    if (currentUser == null) return;
    final phoneNumber = currentUser.phoneNumber;
    if (phoneNumber == null) return;
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone_number', isEqualTo: phoneNumber)
        .get();
    if (userQuery.docs.isEmpty) return;
    final userDoc = userQuery.docs.first;
    final userLocation = userDoc['user_location'] as GeoPoint?;
    if (userLocation != null) {
      double distanceInMeters = await _getDistanceFromGoogle(
        userLocation.latitude,
        userLocation.longitude,
        widget.sp_location.latitude,
        widget.sp_location.longitude,
      );
      double distanceInKm = distanceInMeters / 1000.0;
      setState(() {
        _pickupDistance = _pickupRequired ? distanceInKm : 0.0;
        _dropoffDistance = _dropoffRequired ? distanceInKm : 0.0;
        _transportCost = (_pickupDistance + _dropoffDistance) * _costPerKm;
        _calculateTotalCost();
      });
    }
  }

  void _calculateTotalCost() {
    int selectedSlotsCount = _selectedTimeSlots.length;
    int numberOfPets = _selectedPetIds.length;
    double baseBoardingCost = selectedSlotsCount * _pricePerHour * numberOfPets;


    double walkingFeeAmount = _dailyWalkingRequired
        ? (double.tryParse(widget.walkingFee) ?? 0.0)
        : 0.0;
    double transportCost = _transportCost;

    if (_foodOption == 'provider' && _foodInfo != null) {
      foodcostPerDay =
          double.tryParse(_foodInfo!['cost_per_day'].toString()) ?? 0.0;
      foodCost = foodcostPerDay! * selectedSlotsCount * numberOfPets;
    } else {
      foodCost = 0.0;
    }

    double totalCost =
        baseBoardingCost + walkingFeeAmount + transportCost + foodCost!;

    setState(() {
      _totalCost = totalCost;
    });
  }

  /// Updated _onNextPressed to either progress the current step or navigate to the Summary page.
  void _onNextPressed() {
    // use the getter which now returns 4 if extras exist
    final int totalSteps = this.totalSteps;

    // if we’re not on the last step yet, validate & advance
    if (currentStep < totalSteps - 1) {
      if (currentStep == 0 && _selectedPetIds.isEmpty) {
        _showWarningDialog(message: 'Please select at least one pet to proceed.');
        return;
      }
      if (currentStep == 1 && _selectedDate == null) {
        _showWarningDialog(message: 'Please choose a date to proceed.');
        return;
      }
      if (currentStep == 2 && _selectedTimeSlots.isEmpty) {
        _showWarningDialog(message: 'Please pick at least one time slot to proceed.');
        return;
      }

      setState(() => currentStep++);
      return;
    }

    // Final step → capacity check then go to summary
    final int numberOfPets = _selectedPetIds.length;
    for (final date in _selectedDates) {
      final existing = _getExistingCountForDate(date);
      if (existing + numberOfPets > widget.max_pets_allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MMM dd, yyyy').format(date)} exceeds capacity '
                  '(Available: ${widget.max_pets_allowed - existing}, '
                  'Trying: $numberOfPets)',
            ),
          ),
        );
        return;
      }
    }

    // Navigate to summary
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HourlySummaryPage(
          selectedDate: _selectedDate!,
          openTime: widget.open_time,
          closeTime: widget.close_time,
          foodCost: foodCost,
          shopImage: widget.shopImage,
          shopName: widget.shopName,
          sp_id: widget.sp_id,
          pricePerHour: _pricePerHour,               // maybe rename to pricePerHour
          dailyWalkingRequired: _dailyWalkingRequired,
          walkingFee: widget.walkingFee,
          totalCost: _totalCost,
          petIds: _selectedPetIds,
          petNames: _selectedPetNames,
          petImages: _selectedPetImages,
          numberOfPets: numberOfPets,
          selectedTimeSlots: _selectedTimeSlots,    // ← pass your slots list
          serviceId: widget.serviceId,
          sp_location: widget.sp_location,
          areaName: 'K R Puram',
          foodOption: _foodOption,
          foodInfo: _foodInfo,
        ),
      ),
    );

  }

  int _getExistingCountForDate(DateTime date) {
    int count = 0;
    for (DateTime unavailableDate in _unavailableDates) {
      if (isSameDay(unavailableDate, date)) {
        count += int.parse(widget.current_count_of_pet);
      }
    }
    return count;
  }

  void _showWarningDialog({required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 48, color: Color(0xFF00C2CB)),
              SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF00C2CB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('OK', style: TextStyle(color: Color(0xFF00C2CB))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderFoodDialog({required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fastfood, size: 48, color: Color(0xFF00C2CB)),
              SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.justify,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF00C2CB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('OK', style: TextStyle(color: Color(0xFF00C2CB))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildPetSelector();
      case 1:
        return _buildDateSection();
      case 2:
        return _buildTimeSlotSection();
      case 3:
        return _buildAdditionalServicesSection();
      default:
        return _buildPetSelector();
    }
  }


  // -------------------- Main Build --------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: PetService.instance.watchMyPetsAsMap(context),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          // still loading pets → show spinner
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final pets = snap.data ?? [];
        if (pets.isEmpty) {
          // no pets → show message
          return const Scaffold(
            body: Center(child: Text('No pets added.')),
          );
        }
        // cache them if you like
        _filteredPets = pets;
        return _buildMainScaffold();
      },
    );
  }

  /// STEP 1: pick exactly one date (masks days where every slot is full)
  Widget _buildDateSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.sp_id)
          .collection('hourly_service_request_boarding')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return Center(child: CircularProgressIndicator());

        // 1️⃣ compute pet-hours per day
        // new: per-slot counts
        // ─── 1️⃣ build per-slot booking counts ───
        final Map<DateTime, Map<String,int>> dailySlotCounts = {};
        for (var doc in snap.data!.docs) {
          final data  = doc.data()! as Map<String,dynamic>;
          final ts    = data['selectedDate'] as Timestamp;
          final day   = DateTime(ts.toDate().year, ts.toDate().month, ts.toDate().day);
          final pets  = data['numberOfPets'] as int? ?? 1;
          final slots = List<String>.from(data['selectedTimeSlots'] as List<dynamic>? ?? []);

          dailySlotCounts.putIfAbsent(day, () => {});
          for (var slot in slots) {
            dailySlotCounts[day]![slot] = (dailySlotCounts[day]![slot] ?? 0) + pets;
          }
        }
        // ─── recompute dayCount for “fullyBooked” only ───
        final Map<DateTime,int> dayCount = {
          for (var entry in dailySlotCounts.entries)
            entry.key: entry.value.values.fold<int>(0, (sum, booked) => sum + booked),
        };




        // ─── 2️⃣ build a list of every possible one-hour slot label ───
        final openDt  = DateFormat('h:mm a').parse(widget.open_time);
        final closeDt = DateFormat('h:mm a').parse(widget.close_time);
        final int hours = closeDt.difference(openDt).inHours;

        final List<String> allSlots = [];
        for (var i = 0; i < hours; i++) {
          final start = openDt.add(Duration(hours: i));
          final end   = openDt.add(Duration(hours: i + 1));
          allSlots.add('${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}');
        }


        final hoursPerDay= closeDt.difference(openDt).inHours;
        final slotsPerDay= hoursPerDay * widget.max_pets_allowed;

        // 3️⃣ fully booked days
        final fullyBooked = dayCount.entries
            .where((e) => e.value >= slotsPerDay)
            .map((e) => e.key)
            .toSet();

        // ← HERE: generate your full list of days →
        final firstDay = DateTime.now();
        final lastDay  = DateTime.now().add(Duration(days: 365));
        final allDays = List<DateTime>.generate(
          lastDay.difference(firstDay).inDays + 1,
              (i) => DateTime(
            firstDay.year,
            firstDay.month,
            firstDay.day + i,
          ),
        );

        // 4️⃣ if suggestion is active, compute _suggestedDays
        if (_isSuggestActive) {
          _suggestedDays = allDays
              .where((day) {
            // skip any day that’s fully booked
            if (fullyBooked.contains(day)) return false;
            // check for runLength free slots
            return _hasContiguousFreeRun(
              day,
              _suggestSlotCount!,
              widget.max_pets_allowed,
              allSlots,
              dailySlotCounts,
            );
          })
              .toSet();
        } else {
          _suggestedDays.clear();
        }


        return Column(
          children: [
            StageProgressBar(
              currentStage: currentStep + 1,
              totalStages: totalSteps,
              onStepTap: (step) {
                // (optional) same tap‐guard logic you have elsewhere
                if (step - 1 > 0 && _selectedPetIds.isEmpty) {
                  _showWarningDialog(message: 'Select at least one pet first');
                  return;
                }
                setState(() => currentStep = step - 1);
              },
            ),

            const SizedBox(height: 12),
            // ▪︎ Add horizontal padding around calendar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(Duration(days: 365)),
                lastDay:  DateTime.now().add(Duration(days: 365)),
                focusedDay: _selectedDate ?? DateTime.now(),
                enabledDayPredicate: (day) {
                  final norm = DateTime(day.year, day.month, day.day);
                  final isPast = day.isBefore(DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ));
                  final isFull = fullyBooked.contains(norm);
                  return !isPast && !isFull;
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (ctx, date, _) {
                    final norm = DateTime(date.year, date.month, date.day);
                    // ① fully booked → grey circle
                    if (fullyBooked.contains(norm)) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${date.day}'),
                      );
                    }
                    // ② suggested → green circle
                    if (_isSuggestActive && _suggestedDays.contains(norm)) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('${date.day}'),
                      );
                    }
                    return null;
                  },
                ),
                calendarStyle: CalendarStyle(
                  disabledTextStyle: TextStyle(color: Colors.grey.withOpacity(0.4)),
                  todayDecoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.teal, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                selectedDayPredicate: (d) => isSameDay(d, _selectedDate),
                onDaySelected: (day, _) {
                  final norm = DateTime(day.year, day.month, day.day);
                  if (fullyBooked.contains(norm)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No slots left on ${DateFormat.yMMMd().format(day)}'))
                    );
                    return;
                  }
                  setState(() {
                    _selectedDate = day;
                    _selectedTimeSlots.clear();
                  });
                },
              ),
            ),

            const SizedBox(height: 8),

            // ▪︎ Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _LegendDot(color: Colors.grey.shade300),
                  const SizedBox(width: 4),
                  const Text('Grey = slots full'),
                  const Spacer(),
                  _LegendDot(color: Colors.green.shade200),
                  const SizedBox(width: 4),
                  const Text('Green = suggestion'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ▪︎ Suggest button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                child: Text(_isSuggestActive ? 'Clear Suggestion' : 'Suggest'),
                onPressed: () async {
                  if (_isSuggestActive) {
                    setState(() => _suggestSlotCount = null);
                  } else {
                    final count = await showDialog<int>(
                      context: context,
                      builder: (ctx) {
                        int input = 1;
                        return AlertDialog(
                          title: const Text('How many slots in a row?'),
                          content: TextField(
                            keyboardType: TextInputType.number,
                            onChanged: (v) => input = int.tryParse(v) ?? 1,
                            decoration: const InputDecoration(hintText: 'e.g. 3'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, input), child: const Text('OK')),
                          ],
                        );
                      },
                    );
                    if (count != null && count > 0) {
                      setState(() => _suggestSlotCount = count);
                    }
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _hasContiguousFreeRun(
      DateTime day,
      int runLength,
      int capacity,
      List<String> allSlots,
      Map<DateTime, Map<String,int>> dailySlotCounts,
      ) {
    final counts = dailySlotCounts[day] ?? {};
    // mark free flags
    final freeFlags = allSlots
        .map((s) => (counts[s] ?? 0) + _selectedPetIds.length <= capacity)
        .toList();

    int consec = 0;
    for (var ok in freeFlags) {
      if (ok) {
        if (++consec >= runLength) return true;
      } else {
        consec = 0;
      }
    }
    return false;
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _stepTitles[currentStep],
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingActionBar(),
    );
  }

  // -------------------- UI Widgets (Pet Selector, Calendar, etc.) --------------------

  Widget _buildPetSelector() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _petListStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPets = snapshot.data!;
        final displayList = _searchTerm.isNotEmpty
            ? allPets
            .where((p) => p['name']!
            .toLowerCase()
            .contains(_searchTerm.toLowerCase()))
            .toList()
            : allPets;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StageProgressBar(
                currentStage: currentStep + 1,
                totalStages: totalSteps,
                onStepTap: (step) {
                  final targetIndex = step - 1;

                  if (targetIndex > 0 && _selectedPetIds.isEmpty) {
                    _showWarningDialog(
                      message:
                      'Please select at least one pet before moving on.',
                    );
                    return;
                  }

                  if (targetIndex > 1 && _selectedTimeSlots.isEmpty) {
                    _showWarningDialog(
                      message:
                      'Please pick at least one slot before moving on.',
                    );
                    return;
                  }

                  setState(() => currentStep = targetIndex);
                },
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // Search bar
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search your pets…',
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF008585)),
                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                            borderSide: BorderSide(
                              color: Color(0xFF008585),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                            borderSide: BorderSide(
                              color: Color(0xFF008585),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                            borderSide: BorderSide(
                              color: Color(0xFF008585),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (term) {
                          setState(() {
                            _searchTerm = term;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                        Border.all(color: Color(0xFF008585), width: 1.0),
                        borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: IconButton(
                        icon:
                        const Icon(Icons.refresh, color: Color(0xFF000000)),
                        onPressed: _refreshAllPets,
                        tooltip: 'Refresh',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // Pet Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                  (constraints.maxWidth ~/ 150).clamp(2, 4);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayList.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppDimensions.spacingMd,
                      mainAxisSpacing: AppDimensions.spacingMd,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, i) {
                      final pet = displayList[i];
                      final isSel = _selectedPetIds.contains(pet['pet_id']);
                      return GestureDetector(
                        onTap: () => _handlePetSelection(pet),
                        child: CustomCard(
                          color: isSel ? AppColors.primaryLight : Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(
                                          AppDimensions.radiusMd)),
                                  child: pet['pet_image'] != null
                                      ? Image.network(pet['pet_image'],
                                      fit: BoxFit.cover)
                                      : _buildImagePlaceholder(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(
                                    AppDimensions.spacingMd),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pet['name'],
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: isSel
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSel)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: AppDimensions.spacingLg),

              // Add Pet Button
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddPetPage()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Add Pet',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 1) Add this helper in your State class:
  void _showMaxPetsDialog() {
    final max = widget.max_pets_allowed;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 48, color: Color(0xFF00C2CB)),
              SizedBox(height: 16),
              Text(
                'Too Many Pets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This shop can take in only $max pet${max > 1 ? 's' : ''} per day.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF00C2CB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF00C2CB)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// 2) Replace your _handlePetSelection with this:
  void _handlePetSelection(Map<String, dynamic> pet) {
    final max = widget.max_pets_allowed;
    final already = _selectedPetIds.contains(pet['pet_id']);

    if (!already && _selectedPetIds.length >= max) {
      _showMaxPetsDialog();
      return;
    }

    setState(() {
      if (already) {
        _selectedPetIds.remove(pet['pet_id']);
        _selectedPetNames.remove(pet['name']);
        _selectedPetImages.remove(pet['pet_image']);
      } else {
        _selectedPetIds.add(pet['pet_id']);
        _selectedPetNames.add(pet['name']);
        _selectedPetImages.add(pet['pet_image']);
      }
      _selectedDates.clear();
      _calculateTotalCost();
    });
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.pets_rounded, size: 32, color: Colors.grey.shade400),
      ),
    );
  }

  /// STEP 2: select one-hour slots instead of dates
  Widget _buildTimeSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) unchanged
        StageProgressBar(
          currentStage: currentStep + 1,
          totalStages: totalSteps,
          onStepTap: (step) {
            if (step > 1 && _selectedPetIds.isEmpty) {
              _showWarningDialog(message: 'Please select at least one pet before moving on.');
              return;
            }
            setState(() => currentStep = step - 1);
          },
        ),
        const SizedBox(height: 16),

        // 2) stream of hourly bookings
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users-sp-boarding')
              .doc(widget.sp_id)
              .collection('hourly_service_request_boarding')
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData)
              return Center(child: CircularProgressIndicator());

            // a) count bookings per slot for our chosen date
            final chosenDate = _selectedDate!;

            final Map<String,int> slotCount = {};
            for (var d in snap.data!.docs) {
              final data = d.data()! as Map<String,dynamic>;
              final ts = (data['selectedDate'] as Timestamp).toDate();
              if (!isSameDay(ts, chosenDate)) continue;

              final slots = List<String>.from(data['selectedTimeSlots'] ?? []);
              final pets  = data['numberOfPets'] as int? ?? 1;
              for (var s in slots) {
                slotCount[s] = (slotCount[s] ?? 0) + pets;
              }
            }

            // b) block any slot at or over capacity
            final blocked = <String>{};
            slotCount.forEach((slot, cnt) {
              if (cnt >= _maxPerHour ||
                  cnt + _selectedPetIds.length > _maxPerHour) {
                blocked.add(slot);
              }
            });

            // c) generate one-hour slots exactly from open_time → close_time
            // ─── sanitize & parse open_time / close_time ───
            String normalize(String s) =>
                s.replaceAll(RegExp(r'\s+'), ' ')  // collapse all whitespace
                    .replaceAll('\u00A0', ' ')        // any non-breaking spaces
                    .trim();

            final openClean  = normalize(widget.open_time);
            final closeClean = normalize(widget.close_time);

// use exact pattern "h:mm a"
            final openDt  = DateFormat('h:mm a').parse(widget.open_time);
            final closeDt = DateFormat('h:mm a').parse(widget.close_time);
            final hours   = closeDt.difference(openDt).inHours;




// build DateTimes at year 0
            DateTime slotStart   = DateTime(0,0,0, openDt.hour,  openDt.minute);
            final slotEndBound   = DateTime(0,0,0, closeDt.hour, closeDt.minute);
            final endLimit       = slotEndBound.subtract(Duration(hours: 1));

// generate your one-hour slots
            final List<String> allSlots = [];
            while (!slotStart.isAfter(endLimit)) {
              final next = slotStart.add(Duration(hours: 1));
              final startLabel = DateFormat('h:mm a').format(slotStart);
              final endLabel   = DateFormat('h:mm a').format(next);
              allSlots.add('$startLabel – $endLabel');
              slotStart = next;
            }

            // d) render grid of slot buttons
            return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.5,
              ),
              itemCount: allSlots.length,
              itemBuilder: (_, i) {
                final s     = allSlots[i];
                final isBlk = blocked.contains(s);
                final isSel = _selectedTimeSlots.contains(s);

                return GestureDetector(
                  onTap: isBlk
                      ? null
                      : () => setState(() {
                    if (isSel) _selectedTimeSlots.remove(s);
                    else _selectedTimeSlots.add(s);
                    _calculateTotalCost();
                  }),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isBlk
                          ? Colors.grey.shade200
                          : isSel
                          ? AppColors.primaryLight
                          : Colors.white,
                      border: Border.all(
                        color: isBlk
                            ? Colors.grey
                            : isSel
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        color: isBlk ? Colors.grey : Colors.black87,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }





// Helper to draw unavailable-day cells
  Widget _buildUnavailableDay(String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(dynamic color, String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color is Color ? color : null,
            gradient: color is Gradient ? color : null,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: text == 'Booked' ? Colors.transparent : Colors.white,
          ),
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<int> _fetchLatestBookingCountForDate(DateTime date) async {
    try {
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.sp_id)
          .collection('service_request_boarding')
          .get();

      int totalCountForDate = 0;
      for (var booking in bookingsQuery.docs) {
        List<dynamic> bookedDates = booking['selectedDates'];
        int petsInBooking = booking['numberOfPets'] ?? 1;
        if (bookedDates
            .any((d) => isSameDay((d as Timestamp).toDate(), date))) {
          totalCountForDate += petsInBooking;
        }
      }
      return totalCountForDate;
    } catch (e) {
      print("Error fetching latest count for date: $e");
      return 0;
    }
  }

  Widget _buildAdditionalServicesSection() {
    final stageNumber = currentStep + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageProgressBar(
          currentStage: currentStep + 1,
          totalStages: totalSteps,
          onStepTap: (step) {
            final targetIndex = step - 1;

            // 1) Cannot go to step 2 or 3 if no pet is selected
            if (targetIndex > 0 && _selectedPetIds.isEmpty) {
              _showWarningDialog(
                message: 'Please select at least one pet before moving on.',
              );
              return;
            }

            // 2) Cannot go to step 3 if no date is selected
            if (targetIndex > 1 && _selectedTimeSlots.isEmpty) {
              _showWarningDialog(
                message: 'Please pick at least one slot before moving on.',
              );
              return;
            }

            // Passed both checks – let's go!
            setState(() => currentStep = targetIndex);
          },
        ),
        _buildServicesCard(), // or inline your services UI here
      ],
    );
  }

  void _handleDailyWalkingChange(bool value) {
    setState(() {
      _dailyWalkingRequired = value;
      _calculateTotalCost();
    });
  }

  void _handleFoodOptionChange(String option) {
    setState(() {
      _foodOption = option;
      _calculateTotalCost();
    });
  }

  Widget _buildSectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
      child: Text(
        text,
        style: AppTextStyles.headingMedium,
      ),
    );
  }

  Widget _buildServicesCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ───── Walking Section ─────
          if (widget.walkingFee != '0') ...[
            ServiceTile(
              icon: Icons.directions_walk_rounded,
              title: 'Daily Walking',
              subtitle:
              'Regular exercise for your pet\n₹ ${widget.walkingFee} / day',
              isActive: _dailyWalkingRequired,
              onChanged: _handleDailyWalkingChange,
            ),
          ],
          SizedBox(height: 20),

          // ───── Food Options Section ─────
          if (_foodInfo != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.primary, width: 3),
                  ),
                ),
                child: Text('Food Options', style: AppTextStyles.subheading),
              ),
            ),

            // ── Provider Food ──
            InkWell(
              onTap: () => _handleFoodOptionChange('provider'),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                decoration: BoxDecoration(
                  color:
                  _foodOption == 'provider' ? AppColors.primaryLight : null,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    // Circle check
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _foodOption == 'provider'
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _foodOption == 'provider'
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: _foodOption == 'provider'
                            ? Colors.white
                            : Colors.transparent,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),

                    // Label
                    Expanded(
                      child: Text(
                        'Boarding Center Menu',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Info & Price
                    IconButton(
                      icon: Icon(Icons.info_outline, color: AppColors.primary),
                      onPressed: () => _showProviderFoodDialog(
                          message: _foodInfo!['Description'] ?? ''),
                    ),
                    Text(
                      '₹${_foodInfo!['cost_per_day']}/day',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bring Your Own ──
            FoodOptionTile(
              title: 'Bring Your Own',
              subtitle: Text(
                'Supply your pet\'s regular food',
                style: AppTextStyles.bodySmall,
              ),
              cost: null,
              isSelected: _foodOption == 'self',
              onTap: () => _handleFoodOptionChange('self'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            // Adjust as per your shadow style
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          // Text and icon color
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: Color(0xFF2BCECE), // Border color like before
              width: 3.0,
            ),
          ),
          elevation: 0,
        ),
        onPressed: _onNextPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentStep < 2 ? 'Next' : 'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
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
