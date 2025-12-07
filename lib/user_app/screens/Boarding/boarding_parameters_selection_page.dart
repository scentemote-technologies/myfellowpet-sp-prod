import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myfellowpet_sp/user_app/screens/Boarding/summary_page_boarding.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import '../../../screens/Boarding/preloaders/petpreloaders.dart';
import '../../app_colors.dart';
import '../Pets/AddPetPage.dart';
import 'boarding_servicedetailspage.dart';
import 'new_location.dart';

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
// Brand Colors
const Color primaryColor = Color(0xFF2CB4B6);
const Color accentColor = Color(0xFFF67B0D);

// Reusable Components
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
  /// The current active stage (1-based index).
  final int currentStage;

  /// The total number of stages in the process.
  final int totalStages;

  /// A list of labels for each stage. The length must match [totalStages].
  final List<String> labels;

  /// Callback function triggered when a step is tapped.
  final void Function(int)? onStepTap;

  /// Padding around the entire widget.
  final EdgeInsetsGeometry padding;

  const StageProgressBar({
    Key? key,
    required this.currentStage,
    required this.totalStages,
    required this.labels,
    this.onStepTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
  })  : assert(labels.length == totalStages,
  'The number of labels must match the total number of stages.'),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    // A list to hold each step widget
    final List<Widget> stepWidgets = [];

    // Loop through the stages to build the widgets
    for (int i = 0; i < totalStages; i++) {
      final stepNumber = i + 1;

      // Add the step widget itself
      stepWidgets.add(
        // Flexible allows the step's content to size naturally
        Flexible(
          child: _buildStep(context, stepNumber),
        ),
      );

      // Add a connector if it's not the last step
      if (i < totalStages - 1) {
        stepWidgets.add(
          // Expanded forces the connector to fill the remaining space
          Expanded(child: _buildConnector(stepNumber)),
        );
      }
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align tops of elements
        children: stepWidgets,
      ),
    );
  }

  /// Builds a single step, including the circle and its label below.
  Widget _buildStep(BuildContext context, int stepNumber) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircle(stepNumber),
        const SizedBox(height: 12),
        _buildLabel(stepNumber),
      ],
    );
  }

  /// Builds the animated connecting line between steps.
  Widget _buildConnector(int stepNumber) {
    final bool isCompleted = stepNumber < currentStage;
    final Color activeColor = AppColors.primary; // Use your brand color for completed lines
    final Color inactiveColor = Colors.grey.shade300;

    return Container(
      // This margin vertically centers the connector with the circles
      margin: const EdgeInsets.only(top: 18.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        height: 2.0, // Thinner line for a cleaner look
        color: isCompleted ? activeColor : inactiveColor,
      ),
    );
  }

  /// Builds the central circle for a step with the new minimalist design.
  Widget _buildCircle(int stepNumber) {
    final isCompleted = stepNumber < currentStage;
    final isCurrent = stepNumber == currentStage;

    final double circleSize = 36.0;
    final Color activeColor = AppColors.primary;
    final Color completedColor = AppColors.primary; // Use brand color for consistency
    final Color inactiveColor = Colors.grey.shade400;

    Widget child;
    BoxDecoration decoration;

    if (isCompleted) {
      decoration = BoxDecoration(
        color: completedColor,
        shape: BoxShape.circle,
      );
      child = const Icon(Icons.check, color: Colors.white, size: 20);
    } else if (isCurrent) {
      decoration = BoxDecoration(
        color: activeColor,
        shape: BoxShape.circle,
      );
      child = Text(
        '$stepNumber',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    } else { // Future step
      decoration = BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: inactiveColor, width: 2.0),
      );
      child = Text(
        '$stepNumber',
        style: GoogleFonts.poppins(
          color: inactiveColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return GestureDetector(
      onTap: onStepTap != null && !isCurrent ? () => onStepTap!(stepNumber) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: circleSize,
        height: circleSize,
        decoration: decoration,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Builds the text label under a step with clearer active/inactive states.
  Widget _buildLabel(int stepNumber) {
    final isCompleted = stepNumber < currentStage;
    final isCurrent = stepNumber == currentStage;
    final bool isActive = isCompleted || isCurrent;

    final labelStyle = GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      color: isActive ? Colors.black87 : Colors.grey.shade600,
    );

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: labelStyle,
      textAlign: TextAlign.center,
      child: Text(
        labels[stepNumber - 1],
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
// 2) Example usage in your page's build:
// replace existing StageProgressBar(...) with this:

class BoardingParametersSelectionPage extends StatefulWidget {

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
  final Map<String, int> rates;
  final String serviceId;
  final Map<String, int> mealRates;
  final Map<String, int> refundPolicy;
  final String fullAddress;
  final Map<String, int> walkingRates; // ADD THIS LINE
  final Map<String, dynamic> feedingDetails; // <-- ADD THIS
  final String? initialSelectedPet;




  BoardingParametersSelectionPage({
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
    required this.open_time,
    required this.mode,
    required this.rates, // THIS IS THE RATES YOU NEED
    required this.mealRates,
    required this.refundPolicy,
    required this.fullAddress,
    required this.walkingRates,
    required this.feedingDetails, this.initialSelectedPet, // ADD THIS LINE


  });

  @override
  _BoardingParametersSelectionPageState createState() =>
      _BoardingParametersSelectionPageState();
}

class _BoardingParametersSelectionPageState extends State<BoardingParametersSelectionPage> {
  // ---------------- State Variables ----------------
  // New variable to track the current step (0: Pet selection, 1: Calendar, 2: Additional Services)
  // inside class _BoardingParametersSelectionPageState {
  int currentStep = 0; // you alrea
  late Future<List<PetPricing>> _petPricingFuture;
  bool _isLoading = false;


  bool _isSaving = false;
  Map<String, int> _mealRates = {};
  Map<String, int> _refundPolicy = {};
  String _fullAddress = '';
  Map<String, int> _walkingRates = {}; // ADD THIS LINE

  late final Stream<List<Map<String, dynamic>>> _petListStream;

// dy have this
  bool get hasAdditionalServices =>
      widget.walkingFee != '0' || _foodInfo != null;
  late TextEditingController _searchController;
  String _searchTerm = '';
  String? _selectedPet;
  List<String> _acceptedSizes = [];
  List<String> _acceptedBreeds = [];
  List<String> _petDocIds = []; // store pet document IDs

  // replace your static totalSteps with this getter:
  // The corrected totalSteps getter
  int get totalSteps {
    final hasWalkingServices = widget.walkingRates.values.any((rate) => rate > 0);
    final hasMealServices = widget.mealRates.values.any((rate) => rate > 0);
    return (hasWalkingServices || hasMealServices) ? 3 : 2;
  }

  Map<String,String>  _petSizesMap    = {};                 // petId → size
  List<Map<String,dynamic>> _petSizesList = [];
  late final Map<String,int> _lcRates; // ordered [{ size, price }, …]
  late final Map<String, int> _lcMealRates;
  late final Map<String, int> _lcWalkingRates;


  // Existing state variables
  DateTime? _startDate;
  List<Map<String, dynamic>> _filteredPets = [];

  int totalDays = 0;
  DateTime? _endDate;
  bool _pickupRequired = false;
  bool _dropoffRequired = false;
  bool _transportOptionSelected = false;
  bool _isFoodDescriptionExpanded = false;

  late double _pricePerDay;
  double _transportCost = 0.0;
  double _totalCost = 0.0;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;
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
    'Select Pets',
    'Choose Dates',
    'Add-ons',
  ];
  Map<String, Map<String, dynamic>> _locations = {};

  //bool _dailyWalkingRequired = false;
  //String _foodOption = 'self'; // 'provider' or 'self'
  Map<String, Map<DateTime, bool>> _petWalkingOptions = {};
  Map<String, Map<DateTime, String>> _petFoodOptions = {};
  Map<String, dynamic>?
  _foodInfo; // Contains { "Description": "...", "cost_per_day": "..." }
  late Future<List<Map<String, dynamic>>> _petListFuture;
  List<Map<String,dynamic>> _allPets = [];

  Future<void> _loadPetSizes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1️⃣ fetch each pet doc
    final snaps = await Future.wait(
      _selectedPetIds.map((petId) =>
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('users-pets')
              .doc(petId)
              .get()
      ),
    );

    // 2️⃣ build petId → size map
    final map = <String, String>{};
    for (var s in snaps) {
      if (s.exists) {
        map[s.id] = (s.data()?['size'] as String? ?? 'small').toLowerCase();
      }
    }

    // parse your uniform walk & meal fees once
    final walkFee = double.tryParse(widget.walkingFee) ?? 0.0;
    final mealFee = (_foodInfo != null)
        ? double.tryParse(_foodInfo!['cost_per_day']?.toString() ?? '0') ?? 0.0
        : 0.0;

    // 3️⃣ build the ordered [ { size, price, walkFee, mealFee } ] list
    final list = _selectedPetIds.map((petId) {
      final size  = map[petId] ?? 'small';
      final price = _lcRates[size] ?? 0;
      return {
        'id':      petId,         // ← add this
        'size':    size,
        'price':   price,
        'walkFee': walkFee,
        'mealFee': mealFee,
      };
    }).toList();

    setState(() {
      _petSizesMap  = map;
      _petSizesList = list;
    });
  }
  // REPLACE your entire _getDatesInRange() method with this one

  List<DateTime> _getDatesInRange() {
    // If no start date is selected, return empty.
    if (_rangeStart == null) {
      return [];
    }

    // --- FIX IS HERE ---
    // If there's a start date but no end date, it's a single-day selection.
    if (_rangeEnd == null) {
      return [_rangeStart!];
    }
    // --- END OF FIX ---

    // If both start and end dates exist, calculate the range as before.
    final dates = <DateTime>[];
    final dayCount = _rangeEnd!.difference(_rangeStart!).inDays + 1;
    for (int i = 0; i < dayCount; i++) {
      dates.add(_rangeStart!.add(Duration(days: i)));
    }
    return dates;
  }

  @override
  void initState() {
    super.initState();
    _petPricingFuture = _fetchPetPricing(widget.serviceId);
    // Chain the fetch calls to ensure data is loaded sequentially
    _fetchPetDocIds().then((_) {
      if (_selectedPet != null) {
        _fetchPetDetails(_selectedPet!);
      }
    });

    _lcRates = widget.rates.map((k, v) => MapEntry(k.toLowerCase(), v));
    // FIX: Create lowercase versions of the other rate maps.
    _lcMealRates = widget.mealRates.map((k, v) => MapEntry(k.toLowerCase(), v));
    _lcWalkingRates = widget.walkingRates.map((k, v) => MapEntry(k.toLowerCase(), v));
    _mealRates = widget.mealRates;
    _refundPolicy = widget.refundPolicy;
    _fullAddress = widget.fullAddress;
    _walkingRates = widget.walkingRates; // ADD THIS LINE
    _fetchLocations();
    _searchController = TextEditingController();
    PetService.instance.watchMyPetsAsMap(context).listen((pets){
      setState(() => _allPets = pets);
    });
    _calculateTransportCost();
  }


  Future<void> _fetchPetDocIds() async {
    final serviceDocRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId);
    final petCollectionSnap = await serviceDocRef.collection('pet_information').get();

    final docIds = petCollectionSnap.docs.map((doc) => doc.id).toList();
    // Determine the selected pet but don't call setState yet
    _petDocIds = docIds;
    _selectedPet = widget.initialSelectedPet ?? (docIds.isNotEmpty ? docIds.first : null);
  }


  // ADD THIS NEW METHOD TO FETCH DATA FOR THE VARIETIES TABLE
  Future<void> _fetchPetDetails(String petId) async {
    if (petId.isEmpty) return;
    try {
      final petSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAllPets() {
    // First, clear what the user sees in the text field.
    _searchController.clear();

    // Then, update the state variable that controls the filter and
    // tell Flutter to rebuild the widget with the change.
    setState(() {
      _searchTerm = '';
    });

    // If you also want to re-fetch the list from your database on refresh,
    // you would trigger your data fetching logic here.
  }

  // In your _BoardingParametersSelectionPageState class...

// Helper method for the calendar card's decoration for a cleaner build method
  BoxDecoration _getCalendarCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24.0), // Softer, more modern corners
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2CB4B6).withOpacity(0.08),
          blurRadius: 40,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }



// Helper method for legend items (you can place this in your State class)
  Widget _buildLegendItem(Color color, String text, {BoxBorder? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }


// The main updated widget build method
  Widget _buildCalendarSection() {
    final stageNumber = currentStep + 1;
    const Color primaryBrandColor = Color(0xFF2CB4B6);
    final Color lightPrimaryColor = primaryBrandColor.withOpacity(0.15);
    final Color accentColor = Colors.orange.shade700; // Define an accent for weekends

    // --- LOGIC (UNCHANGED) ---
    // This block remains exactly as you provided it.
    final combinedUnavailable = [
      ..._bookingCountMap.entries
          .where((e) => e.value + _selectedPetIds.length > widget.max_pets_allowed)
          .map((e) => e.key),
      ..._unavailableDates.where((d) =>
      !_bookingCountMap.keys.any((u) => isSameDay(u, d)))
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rangeStart != null && _rangeEnd != null) {
        final dayCount = _rangeEnd!.difference(_rangeStart!).inDays + 1;
        final daysInRange = List.generate(
            dayCount, (i) => _rangeStart!.add(Duration(days: i))
        );
        final bool isRangeInvalid = daysInRange.any((day) =>
            combinedUnavailable.any((unavailable) => isSameDay(day, unavailable))
        );
        if (isRangeInvalid) {
          setState(() {
            _rangeStart = null;
            _rangeEnd = null;
            _calculateTotalCost();
          });
        }
      }
    });
    // --- END OF LOGIC ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1) Progress bar (Unchanged)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: StageProgressBar(
            currentStage: stageNumber,
            totalStages: totalSteps,
            onStepTap: _handleStepTap,
            labels: _stepTitles.take(totalSteps).toList(),
          ),
        ),



        // 3) Calendar + legend container with improved styling
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.all(8), // Reduced padding for calendar to fit
          decoration: _getCalendarCardDecoration(),
          child: Column(
            children: [
              // REPLACE your entire TableCalendar widget with this one

              TableCalendar(
                // Core properties (Unchanged)
                availableGestures: AvailableGestures.horizontalSwipe,
                focusedDay: _selectedDay,
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                startingDayOfWeek: StartingDayOfWeek.monday,

                // --- FIX IS HERE: Add the enabledDayPredicate ---
                enabledDayPredicate: (day) {
                  // A day is enabled if it's NOT in the list of unavailable dates.
                  final isUnavailable = combinedUnavailable.any((d) => isSameDay(d, day));
                  return !isUnavailable;
                },
                // --- END OF FIX ---

                // Range Selection Properties (Unchanged)
                rangeSelectionMode: _rangeSelectionMode,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,

                // onRangeSelected Callback (Simplified)
                onRangeSelected: (start, end, focusedDay) {
                  setState(() {
                    _selectedDay = focusedDay;
                    _rangeStart = start;
                    _rangeEnd = end;
                    _calculateTotalCost();
                  });
                },

                // --- STYLING (Unchanged) ---
                calendarStyle: CalendarStyle(
                  rangeStartDecoration: BoxDecoration(
                    color: primaryBrandColor,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: BoxDecoration(
                    color: primaryBrandColor,
                    shape: BoxShape.circle,
                  ),
                  rangeHighlightColor: lightPrimaryColor,
                  todayDecoration: BoxDecoration(
                    color: lightPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: primaryBrandColor,
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
                  weekendTextStyle: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
                  outsideTextStyle: TextStyle(color: Colors.grey.shade400),
                  disabledTextStyle: TextStyle( // This style will now be applied automatically
                    color: Colors.grey.shade400,
                    decoration: TextDecoration.lineThrough,
                  ),
                  withinRangeTextStyle: const TextStyle(color: Colors.black),
                  withinRangeDecoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: Colors.grey, size: 28),
                  rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 28),
                  headerPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                  weekendStyle: GoogleFonts.poppins(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),

                // CalendarBuilders (Simplified)
                calendarBuilders: CalendarBuilders(
                  disabledBuilder: (context, date, focusedDate) {
                    return Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    );
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final bookedCount = _bookingCountMap[day] ?? 0;
                    if (bookedCount > 0) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  },
                ),
              ),
              const Divider(height: 32, indent: 16, endIndent: 16),

              // 4) Legend Row (Now more descriptive)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildLegendItem(primaryBrandColor, 'Selected'),
                    _buildLegendItem(Colors.grey.shade300, 'Unavailable'),
                    _buildLegendItem(
                      lightPrimaryColor,
                      'Today',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fetchUnavailableDates() async {
    try {
      // 1. Get all existing daily summaries for this service provider.
      final summarySnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('daily_summary')
          .get();

      final Map<DateTime, int> dateCountMap = {};
      final List<DateTime> unavailableDates = [];
      final int petsInCurrentSelection = _selectedPetIds.length;
      final int maxPetsAllowed = widget.max_pets_allowed;

      // 2. Process each day's summary document.
      for (final doc in summarySnap.docs) {
        final date = DateFormat('yyyy-MM-dd').parse(doc.id);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final data = doc.data();

        // Check if the day is a holiday. This works even if the field is missing.
        final bool isHoliday = data['isHoliday'] as bool? ?? false;

        // NEW, CLEARER LOGIC:
        // We now handle the 'bookedPets' field safely inside the capacity check.
        if (isHoliday) {
          // --- NEW: Print statement for holidays ---
          print('🗓️ Holiday Found (Date Blocked): ${DateFormat('yyyy-MM-dd').format(normalizedDate)}');

          // CRITERIA 1: If it's a holiday, it is always unavailable. We don't care about pet counts.
          unavailableDates.add(normalizedDate);
          dateCountMap[normalizedDate] = 0; // It's a holiday, so booked count for capacity is irrelevant.
        } else {
          // CRITERIA 2: If it's NOT a holiday, then we check capacity.

          // This safely gets the booked pet count. If the 'bookedPets' field is missing, it defaults to 0.
          final int currentBookedCount = data['bookedPets'] as int? ?? 0;
          dateCountMap[normalizedDate] = currentBookedCount;

          if (currentBookedCount + petsInCurrentSelection > maxPetsAllowed) {
            // The date is unavailable because adding the selected pets would exceed the limit.
            unavailableDates.add(normalizedDate);
          }
        }
      }

      // 3. Update the state to refresh the calendar UI.
      if (mounted) {
        setState(() {
          _bookingCountMap = dateCountMap;
          _unavailableDates = unavailableDates.toSet().toList();
        });
      }
    } catch (e) {
      print("Error fetching optimized unavailable dates: $e");
      // Handle error state if necessary.
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

  // In _calculateTotalCost()
  // In _calculateTotalCost()
  void _calculateTotalCost() {
    double totalBoardingCost = 0.0;
    double totalWalkingCost = 0.0;
    double totalMealsCost = 0.0;
    double transportCost = _transportCost;

    for (final pet in _petSizesList) {
      final petId = pet['id'] as String;
      final petRate = (pet['price'] as int).toDouble();
      final petSize = pet['size'] as String;

      // Boarding cost for this pet
      totalBoardingCost += petRate * _getDatesInRange().length;

      // Per-day service costs
      for (final date in _getDatesInRange()) {
        // FIX: Use the lowercase map `_lcWalkingRates` for lookup
        if (_petWalkingOptions[petId]?[date] == true) {
          final walkingRate = _lcWalkingRates[petSize]?.toDouble() ?? 0.0;
          totalWalkingCost += walkingRate;
        }

        // FIX: Use the lowercase map `_lcMealRates` for lookup
        if (_petFoodOptions[petId]?[date] == 'provider') {
          final mealRate = _lcMealRates[petSize]?.toDouble() ?? 0.0;
          totalMealsCost += mealRate;
        }
      }
    }

    double total = totalBoardingCost + totalWalkingCost + totalMealsCost + transportCost;

    setState(() {
      _totalCost = total;
    });
  }
  /// Updated _onNextPressed to either progress the current step or navigate to the Summary page.
  // Change your signature to async:
  Future<_FeesData> _fetchFees() async {
    final snap = await FirebaseFirestore.instance
        .collection('company_documents').doc('fees').get();
    final data        = snap.data() ?? {};
    final platformFee = double.tryParse(data['user_app_platform_fee'] ?? '0') ?? 0;
    final gstPct      = double.tryParse(data['gst_percentage']        ?? '0') ?? 0;
    return _FeesData(platformFee, platformFee * gstPct / 100);
  }


  Future<void> _onNextPressed() async {
    // Prevent double-taps while saving or loading
    if (_isSaving || _isLoading) return;

    // --- Start of Step Transition Logic ---
    if (currentStep < totalSteps - 1) {
      print('ℹ️ Current step is not the final step.');

      // Step 0 -> Step 1
      if (currentStep == 0) {
        if (_selectedPetIds.isEmpty) {
          print('⛔️ Step 0 failed: No pets selected.');
          _showWarningDialog(message: 'Please select at least one pet to proceed.');
          return;
        }
        print('✅ Step 0 complete. Fetching data for next steps...');

        // Use a loading state to prevent UI freeze during network calls
        setState(() {
          _isLoading = true;
        });

        // Parallelize the network requests to speed up loading
        try {
          await Future.wait([
            _fetchUnavailableDates(),
            _loadPetSizes(),
          ]);
          print('✅ Dates and pet sizes loaded.');
        } catch (e) {
          // Handle any errors from the concurrent fetches
          print('⛔️ Error fetching data: $e');
          setState(() {
            _isLoading = false;
          });
          _showWarningDialog(message: 'Failed to load calendar data. Please try again.');
          return;
        }
      }

      // Step 1 -> Step 2
      // In BoardingParametersSelectionPage.dart -> _onNextPressed()

      // ... (inside the `if (currentStep < totalSteps - 1)` block)

      // Step 1 -> Step 2
      if (currentStep == 1) {
        if (_rangeStart == null) {
          print('⛔️ Step 1 failed: No dates selected.');
          _showWarningDialog(message: 'Please select at least one date to proceed.');
          return;
        }

        // --- FIX IS HERE ---
        // Explicitly load pet sizes to ensure data is ready for the add-ons page.
        setState(() {
          _isLoading = true;
        });
        await _loadPetSizes();
        // The isLoading flag will be set to false in the final setState below.
        // --- END OF FIX ---

        print('✅ Step 1 complete. Proceeding to next step.');
      }

      // Increment the step and update the UI
      setState(() {
        currentStep++;
        _isLoading = false; // Reset loading flag
      });
      print('➡️ Successfully moved to step: $currentStep');
      return;
    }
    // --- End of Step Transition Logic ---

    print('🎉 Final step (Step $currentStep). Attempting to proceed to SummaryPage.');
    final int numberOfPets = _selectedPetIds.length;
    for (final date in _getDatesInRange()) {
      final existing = _bookingCountMap[DateTime(date.year, date.month, date.day)] ?? 0;
      if (existing + numberOfPets > widget.max_pets_allowed) {
        print('⛔️ Capacity check failed for date ${DateFormat('MMM dd, yyyy').format(date)}.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('MMM dd, yyyy').format(date)} exceeds capacity '
                  '(Available: ${widget.max_pets_allowed - existing}, Trying: $numberOfPets)',
            ),
          ),
        );
        return;
      }
    }
    print('✅ Capacity check passed.');

    setState(() => _isSaving = true);

    try {
      // --- Data Preparation ---
      final _FeesData f = await _fetchFees();
      double boardingCost = 0.0;
      double walkingCost = 0.0;
      double mealsCost = 0.0;

      for (final pet in _petSizesList) {
        final petId = pet['id'] as String;
        final petSize = pet['size'] as String;
        final petRate = (_lcRates[petSize] ?? 0).toDouble();
        boardingCost += petRate * _getDatesInRange().length;
        for (final date in _getDatesInRange()) {
          if (_petWalkingOptions[petId]?[date] == true) {
            final walkingRate = (_lcWalkingRates[petSize] ?? 0).toDouble();
            walkingCost += walkingRate;
          }
          if (_petFoodOptions[petId]?[date] == 'provider') {
            final mealRate = (_lcMealRates[petSize] ?? 0).toDouble();
            mealsCost += mealRate;
          }
        }
      }

      double transportCost = _transportCost;
      final double grandTotal = boardingCost + walkingCost + mealsCost + transportCost + f.platform + f.gst;
      setState(() => _totalCost = grandTotal);

      final Map<String, Map<String, dynamic>> perPetServices = {};
      for (final petId in _selectedPetIds) {
        final petIndex = _selectedPetIds.indexOf(petId);
        final petName = _selectedPetNames[petIndex];
        final petImage = _selectedPetImages[petIndex];
        final petSizeRaw = _petSizesMap[petId] ?? 'small';
        final petSize = petSizeRaw.isNotEmpty ? petSizeRaw[0].toUpperCase() + petSizeRaw.substring(1) : 'Small';

        final Map<String, Map<String, dynamic>> dailyDetailsMap = {};
        for (final date in _getDatesInRange()) {
          final dateString = DateFormat('yyyy-MM-dd').format(date);
          dailyDetailsMap[dateString] = {
            'meals': _petFoodOptions[petId]?[date] == 'provider',
            'walk': _petWalkingOptions[petId]?[date] ?? false,
          };
        }
        perPetServices[petId] = {
          'name': petName,
          'size': petSize,
          'image': petImage,
          'dailyDetails': dailyDetailsMap,
        };
      }

      // --- Firestore Write Logic using a Batch ---

      final user = FirebaseAuth.instance.currentUser!;
      final uSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final uData = uSnap.data() ?? {};

      final bookingRef = FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('service_request_boarding')
          .doc();

      final batch = FirebaseFirestore.instance.batch();

      final mainBookingData = {
        'order_status': 'requested',
        'admin_account_number': '2323230014933488',
        'user_id': user.uid,
        'start_reminder_stage': 0,
        'bookingId': bookingRef.id,
        'mode': "Online",
        'pet_name': _selectedPetNames,
        'original_total_amount': grandTotal,
        'pet_images': _selectedPetImages,
        'pet_id': _selectedPetIds,
        'pet_sizes': _petSizesList,
        'user_reviewed': "false",
        'sp_reviewed': "false",
        'service_id': widget.serviceId,
        'numberOfPets': numberOfPets,
        'user_name': uData['name'] ?? '',
        'phone_number': uData['phone_number'] ?? '',
        'email': uData['email'] ?? '',
        'user_location': uData['user_location'],
        'timestamp': FieldValue.serverTimestamp(),
        'cost_breakdown': {
          'boarding_cost': boardingCost.toString(),
          'daily_walking_cost': walkingCost.toString(),
          'meals_cost': mealsCost.toString(),
          'platform_fee_plus_gst': (f.platform + f.gst).toString(),
          'total_amount': grandTotal.toString(),
        },
        'shopName': widget.shopName,
        'shop_image': widget.shopImage,
        'selectedDates': _getDatesInRange(),
        'openTime': widget.open_time,
        'closeTime': widget.close_time,
        'user_confirmation': false,
        'user_t&c_acceptance': false,
        'admin_called': false,
        'refund_policy': widget.refundPolicy,
        'referral_code_used': false,
      };

      batch.set(bookingRef, mainBookingData);

      for (final petEntry in perPetServices.entries) {
        final petId = petEntry.key;
        final petData = petEntry.value;
        final petServiceRef = bookingRef.collection('pet_services').doc(petId);
        batch.set(petServiceRef, petData);
      }

      // This is the only part that was incorrect.
      // The 'numberOfPets' variable was already defined above.
      for (final date in _getDatesInRange()) {
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final summaryRef = FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .doc(widget.serviceId)
            .collection('daily_summary')
            .doc(dateString);

        batch.set(
          summaryRef,
          {
            'bookedPets': FieldValue.increment(numberOfPets),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      print('✅ Batch write successful for booking ${bookingRef.id} and updating daily summaries.');

      // --- Navigation ---
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryPage(
            mode: widget.mode,
            rates: widget.rates,
            bookingId: bookingRef.id,
            openTime: widget.open_time,
            closeTime: widget.close_time,
            foodCost: mealsCost,
            shopImage: widget.shopImage,
            shopName: widget.shopName,
            sp_id: widget.sp_id,
            startDate: _rangeStart,
            endDate: _rangeEnd,
            transportCost: _transportCost,
            dailyWalkingRequired: walkingCost > 0,
            walkingFee: widget.walkingFee,
            totalCost: _totalCost,
            pickupDistance: _pickupDistance,
            dropoffDistance: _dropoffDistance,
            petIds: _selectedPetIds,
            petNames: _selectedPetNames,
            petImages: _selectedPetImages,
            numberOfPets: numberOfPets,
            pickupRequired: _pickupRequired,
            dropoffRequired: _dropoffRequired,
            transportVehicle: _selectedTransportVehicle ?? 'Not Selected',
            availableDaysCount: _getDatesInRange().length,
            selectedDates: _getDatesInRange(),
            serviceId: widget.serviceId,
            sp_location: widget.sp_location,
            areaName: widget.fullAddress,
            foodOption: mealsCost > 0 ? 'provider' : 'self',
            foodInfo: null,
            mealRates: widget.mealRates,
            refundPolicy: widget.refundPolicy,
            fullAddress: widget.fullAddress,
            walkingRates: widget.walkingRates,
            perDayServices: perPetServices,
            walkingCost: walkingCost,
            petSizesList: _petSizesList,
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${e.toString()}')),
      );
      print('⛔️ Booking failed with error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        return _buildCalendarSection();
      case 2:
        return _buildAdditionalServicesSection();
      default:
        return _buildPetSelector();
    }
  }

  // -------------------- Main Build --------------------
  @override
  Widget build(BuildContext context) {
    if (_allPets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildMainScaffold();
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

  // -------------------- UI Widgets (Pet Selector, etc.) --------------------

// [REPLACE] your current pet selector code with this complete set of lucid UI methods.

  /// Builds the main pet selection UI, focusing on clarity and professional design.
  Widget _buildPetSelector() {
    // Filtering logic remains efficient and unchanged.
    final displayList = _searchTerm.isEmpty
        ? _allPets
        : _allPets.where((p) {
      return (p['name'] as String)
          .toLowerCase()
          .contains(_searchTerm.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: StageProgressBar(
            currentStage: currentStep + 1,
            totalStages: totalSteps,
            onStepTap: _handleStepTap,
            labels: _stepTitles.take(totalSteps).toList(), // <-- ADD THIS LINE

          ),
        ),

        // 1. A clean, familiar search bar.
        _buildSearchBarAndRefresh(),
        const SizedBox(height: AppDimensions.spacingLg),

        // 2. The grid, which now clearly handles an empty state.
        displayList.isEmpty
            ? _buildEmptyState()
            : _buildPetGrid(displayList),
        const SizedBox(height: AppDimensions.spacingLg),

        // 3. The "Add Pet" button, styled just like your original.
        _buildAddPetButton(),
        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }

  /// A straightforward and professional search bar, matching your original style.
  Widget _buildSearchBarAndRefresh() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your pets…',
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                // Using OutlineInputBorder for all states for a consistent, professional look.
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              onChanged: (term) {
                setState(() => _searchTerm = term);
              },
            ),
          ),
          const SizedBox(width: 8),
          // This refresh button is styled exactly like your original implementation.
          Container(
            height: 48, // Match the typical height of a TextField
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.primary, width: 1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _refreshAllPets,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
    );
  }

  /// A responsive grid of pets.
  Widget _buildPetGrid(List<Map<String, dynamic>> displayList) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 4);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppDimensions.spacingMd,
              mainAxisSpacing: AppDimensions.spacingMd,
              childAspectRatio: 1, // Classic square aspect ratio
            ),
            itemBuilder: (context, i) {
              final pet = displayList[i];
              final isSel = _selectedPetIds.contains(pet['pet_id']);
              return _buildPetCard(pet, isSel);
            },
          );
        },
      ),
    );
  }

  /// A pet card focused on clarity. Selection is made obvious with a border,
  /// background color change, and a clear checkmark icon.
  Widget _buildPetCard(Map<String, dynamic> pet, bool isSelected) {
    return GestureDetector(
      onTap: () => _handlePetSelection(pet),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.08),
        // The shape property handles both the border radius and the animated border.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1, // Thicker border when selected
          ),
        ),
        // Using an AnimatedContainer to smoothly transition the background color.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd - 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusMd - 2),
                  ),
                  child: pet['pet_image'] != null
                      ? Image.network(
                    pet['pet_image'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImagePlaceholder(),
                  )
                      : _buildImagePlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pet['name'],
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          // Making the text bold when selected makes the state even clearer.
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : Colors.black87,
                        ),
                      ),
                    ),
                    // This is the cool, subtle animation.
                    // The checkmark smoothly fades and scales into view.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: isSelected
                          ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        key: ValueKey('selected_icon'), // Key for AnimatedSwitcher
                      )
                          : const SizedBox.shrink(
                        key: ValueKey('empty_icon'),
                      ),
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

  /// The "Add Pet" button, using your exact original implementation for consistency.
  Widget _buildAddPetButton() {
    return Center(
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Add Pet',
                  // Using AppTextStyles from your provided code.
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A helpful message when no search results are found. This greatly improves clarity.
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingLg * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'No Pets Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for another name, or add a new pet!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }


// Keep your existing _buildImagePlaceholder method as it is.


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
      _rangeStart = null;
      _rangeEnd = null;
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

  // Add this new method inside _BoardingParametersSelectionPageState
  void _handleStepTap(int step) async {
    final targetIndex = step - 1;

    if (targetIndex == currentStep) return; // No action if tapping the current step

    // Validation for moving FORWARD
    if (targetIndex > currentStep) {
      if (currentStep == 0 && _selectedPetIds.isEmpty) {
        _showWarningDialog(message: 'Please select at least one pet to proceed.');
        return;
      }
      if (currentStep == 1 && _getDatesInRange().isEmpty) {
        _showWarningDialog(message: 'Please select your dates to proceed.');
        return;
      }
    }

    // --- THE FIX ---
    // If we are navigating TO the calendar view (step 2, index 1), we must
    // recalculate availability based on the current number of selected pets.
    if (targetIndex == 1) {
      await _fetchUnavailableDates();
      await _loadPetSizes();
    }

    setState(() => currentStep = targetIndex);
  }


// Helper to draw unavailable-day cells
  Widget _buildUnavailableDay(String label) {
    return Container(
      width: 40, // adjust size as needed
      height: 40,
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

  // The corrected version of your _buildAdditionalServicesSection
  // In your _BoardingParametersSelectionPageState class...

// 1. ADD THIS NEW HELPER WIDGET for the tappable service icons.
  Widget _buildServiceToggle(
      {required IconData icon,
        required String label,
        required double cost,
        required bool isSelected,
        required VoidCallback onTap}) {
    final Color activeColor = AppColors.primary;
    final Color inactiveColor = Colors.grey.shade400;
    final Color bgColor = isSelected ? activeColor.withOpacity(0.1) : Colors.grey.shade100;
    final Color borderColor = isSelected ? activeColor.withOpacity(0.5) : Colors.grey.shade300;
    final Color textColor = isSelected ? activeColor : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                if (cost > 0)
                  Text(
                    '₹${cost.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

// 2. REPLACE your old _buildAdditionalServicesSection with this one.
  // You can place these helper methods inside your State class

  /// Builds a professional, animated, and tappable box for selecting a service.
  Widget _buildServiceOptionBox({
    required IconData icon,
    required String label,
    required double cost,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const Color primaryBrandColor = Color(0xFF2CB4B6);
    final Color textColor = isSelected ? Colors.white : Colors.grey.shade800;
    final Color iconColor = isSelected ? Colors.white : primaryBrandColor;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(8.0), // reduced from 12
          decoration: BoxDecoration(
            color: isSelected ? primaryBrandColor : Colors.white,
            border: Border.all(
              color: isSelected ? primaryBrandColor : Colors.grey.shade300,
              width: 1.2, // slightly thinner border
            ),
            borderRadius: BorderRadius.circular(12.0), // reduced from 16
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: primaryBrandColor.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 18, color: iconColor), // smaller icon
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8), // reduced spacing
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12, // smaller text
                  color: textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '+₹${cost.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



// The main updated widget build method
  Widget _buildAdditionalServicesSection() {
    // --- This top section remains the same as the previous good version ---
    final sortedDates = _getDatesInRange().toList()..sort();
    final hasWalking = widget.walkingRates.isNotEmpty;
    final hasMeals = _mealRates.isNotEmpty;

    if (!hasWalking && !hasMeals) {
      // Using the same clean "No Services" widget from before
      return _buildNoServicesAvailable();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: StageProgressBar(
            currentStage: currentStep + 1,
            totalStages: totalSteps,
            onStepTap: _handleStepTap,
            labels: _stepTitles.take(totalSteps).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Customise Add-ons',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // List of Pet Cards
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedPetIds.length,
          itemBuilder: (context, petIndex) {
            final petId = _selectedPetIds[petIndex];
            final petName = _selectedPetNames[petIndex];
            final petImage = _selectedPetImages[petIndex];
            final petSize = _petSizesMap[petId] ?? 'small';

            final walkingCost = widget.walkingRates[petSize[0].toUpperCase() + petSize.substring(1)]?.toDouble() ?? 0.0;
            final mealCost = widget.mealRates[petSize[0].toUpperCase() + petSize.substring(1)]?.toDouble() ?? 0.0;

            // Using the same professional pet card from before
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Pet Header (same as before)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: petImage.isNotEmpty ? NetworkImage(petImage) : null,
                        backgroundColor: const Color(0xFF2CB4B6).withOpacity(0.1),
                        child: petImage.isEmpty ? Icon(Icons.pets, color: const Color(0xFF2CB4B6)) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Services for $petName',
                          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            for (final date in sortedDates) {
                              if (hasMeals) _petFoodOptions.putIfAbsent(petId, () => {})[date] = 'self';
                              if (hasWalking) _petWalkingOptions.putIfAbsent(petId, () => {})[date] = false;
                            }
                            _calculateTotalCost();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // slightly larger
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 1.2),
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                          ),
                          child: Text(
                            'Clear',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 14, // slightly larger text
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                  const Divider(height: 24),

                  // --- List of Dates with the NEW Two-Box Layout ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedDates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, dateIndex) {
                      final date = sortedDates[dateIndex];
                      final formattedDate = DateFormat('EEE, MMM d').format(date);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                            child: Text(
                              formattedDate,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ),
                          Row(
                            children: [
                              if (hasMeals)
                                _buildServiceOptionBox(
                                  icon: Icons.restaurant_menu_rounded,
                                  label: 'Meal',
                                  cost: mealCost,
                                  isSelected: _petFoodOptions[petId]?[date] == 'provider',
                                  onTap: () {
                                    setState(() {
                                      _petFoodOptions.putIfAbsent(petId, () => {});
                                      bool isProvider = _petFoodOptions[petId]![date] == 'provider';
                                      _petFoodOptions[petId]![date] = isProvider ? 'self' : 'provider';
                                      _calculateTotalCost();
                                    });
                                  },
                                ),
                              if (hasMeals && hasWalking) const SizedBox(width: 10),
                              if (hasWalking)
                                _buildServiceOptionBox(
                                  icon: Icons.directions_walk_rounded,
                                  label: 'Walk',
                                  cost: walkingCost,
                                  isSelected: _petWalkingOptions[petId]?[date] ?? false,
                                  onTap: () {
                                    setState(() {
                                      _petWalkingOptions.putIfAbsent(petId, () => {});
                                      _petWalkingOptions[petId]![date] = !(_petWalkingOptions[petId]![date] ?? false);
                                      _calculateTotalCost();
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Feeding Info Button (same as before)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: FutureBuilder<List<PetPricing>>(
            future: _petPricingFuture,
            builder: (context, petPricingSnapshot) {
              if (petPricingSnapshot.connectionState != ConnectionState.done || !petPricingSnapshot.hasData || petPricingSnapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final allPetData = petPricingSnapshot.data!;
              final allFeedingDetails = {for (var pet in allPetData) pet.petName: pet.feedingDetails};
              return FeedingInfoButton(allFeedingDetails: allFeedingDetails, initialSelectedPet: _selectedPet);
            },
          ),
        ),
      ],
    );
  }

  /// A styled widget to display when no extra services are available.
  Widget _buildNoServicesAvailable() {
    return Container(
      margin: const EdgeInsets.all(24.0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_class_outlined, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Additional Services',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'This provider only offers the standard boarding service.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
          ),
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

class _FeesData{
  final double platform,gst;
  _FeesData(this.platform,this.gst);
}