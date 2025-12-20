// lib/edit_service_page.dart

import 'dart:async';
import 'dart:io' as io show File;
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:multi_select_flutter/chip_display/multi_select_chip_display.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../Colors/AppColor.dart';
import '../../../providers/boarding_details_loader.dart';
import '../../../services/places_service.dart';
import '../boarding_service_page_detail.dart';
import '../edit_history_page.dart';
import '../partner_shell.dart';
import '../roles/role_service.dart';

// --- NEW DATA MODEL FOR PRICING CONTROLLERS ---
// Replace with this
class PetPricingControllers {
  final Map<String, TextEditingController> ratesDaily;
  final Map<String, TextEditingController> walkingRates;
  final Map<String, TextEditingController> mealRates;
  final Map<String, TextEditingController> offerRatesDaily;
  final Map<String, TextEditingController> offerWalkingRates;
  final Map<String, TextEditingController> offerMealRates;
  final Map<String, dynamic> feedingDetailsCtrls; // ADDED THIS

  PetPricingControllers({
    required this.ratesDaily,
    required this.walkingRates,
    required this.mealRates,
    required this.offerRatesDaily,
    required this.offerWalkingRates,
    required this.offerMealRates,
    required this.feedingDetailsCtrls, // ADDED THIS
  });

  void dispose() {
    final allControllers = [
      ...ratesDaily.values, ...walkingRates.values, ...mealRates.values,
      ...offerRatesDaily.values, ...offerWalkingRates.values, ...offerMealRates.values
    ];
    for (var controller in allControllers) {
      controller.dispose();
    }
    // Also dispose feeding controllers
    for (var meal in feedingDetailsCtrls.values) {
      for (var ctrl in (meal as Map<String, dynamic>).values) {
        if (ctrl is TextEditingController) {
          ctrl.dispose();
        }
      }
    }
  }
}

/// A single field change request (Unchanged)
class FieldChange {
  final String label;
  final String oldValue;
  final String newValue;

  FieldChange({ required this.label, required this.oldValue, required this.newValue });
}

/// Pet type model (Unchanged)
class PetType {
  final String id;
  final bool display;

  PetType({required this.id, required this.display});
}


class EditServicePage extends StatefulWidget {
  final String serviceId;
  final List<String> pets;
  final String maxPetsAllowedPerHour;
  // --- REMOVED old rate maps ---
  final String description, walkingFee;
  final String openTime, closeTime, maxPetsAllowed;
  final String street, shopName, areaName, district, state, postalCode, shopLocation;
  final String bank_ifsc;
  final String bank_account_num;
  final String full_address;
  final List<String> features;
  final List<String> image_urls;
  final Map<String, String> refundPolicy;
  final String partnerPolicyUrl; // <-- ADD THIS LINE


  const EditServicePage({
    Key? key,
    required this.serviceId,
    required this.description,
    required this.walkingFee,
    required this.openTime,
    required this.closeTime,
    required this.maxPetsAllowed,
    required this.pets,
    required this.street,
    required this.areaName,
    required this.district,
    required this.state,
    required this.postalCode,
    required this.shopLocation,
    required this.bank_ifsc,
    required this.bank_account_num,
    required this.image_urls,
    required this.maxPetsAllowedPerHour,
    required this.full_address,
    required this.refundPolicy,
    required this.features,
    required this.shopName, required this.partnerPolicyUrl,
    // --- REMOVED old rate maps from constructor ---
  }) : super(key: key);

  @override
  _EditServicePageState createState() => _EditServicePageState();
}

class _EditServicePageState extends State<EditServicePage> {

  PlatformFile? _pickedPolicyFile; // <-- ADD THIS LINE


  static const List<String> refundPolicyKeys = ['lt_4h', 'gt_4h', 'gt_12h', 'gt_24h', 'gt_48h'];

  late final String apiKey;
  late final PlacesService _places;
  bool _dialogOpen = false;


  Map<String, Map<String, List<String>>> _selectedPetDetails = {};
  Map<String, Map<String, List<String>>> _initialSelectedPetDetails = {};
  final Map<String, List<Map<String, String>>> _breedsByPetType = {};
  Map<String, dynamic> _globalPetConfigs = {};

  // 🔽🔽🔽 PASTE THESE NEW VARIABLES HERE 🔽🔽🔽

  StreamSubscription<DocumentSnapshot>? _editStatusSubscription;
  bool _isLoadingStatus = true; // <-- ADD THIS LINE


  bool _isEditRequestPending = false;

  // 🔼🔼🔼 END OF NEW VARIABLES 🔼🔼🔼



  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;
  LatLng? _selectedLatLng;

  // --- NEW State variables for pricing ---
  bool _isLoadingPricing = true;
  Map<String, PetPricingControllers> _petPricingCtrls = {};
  Map<String, dynamic> _initialPetPricingData = {};
  Map<String, dynamic> _petSizeConfigs = {}; // To store sizes for each pet

  late Map<String, TextEditingController> _RefundCtrls;

  late TextEditingController _walkFeeCtrl;
  late TextEditingController _descCtrl, _openCtrl, _closeCtrl, _maxPetsCtrl, _streetCtrl, _areaCtrl,
      _shopNameCtrl, _districtCtrl, _stateCtrl, _postalCtrl, _coordCtrl, _locationCtrl,
      _bankAccountCtrl, _bankIfscCtrl;

  late List<dynamic> _images;
  List<PetType> _petTypes = [];
  List<String> _selectedPetTypes = [];
  int _featureLimit = 10;
  late List<TextEditingController> _featureControllers;
  final _featuresFormKey = GlobalKey<FormState>();
  GoogleMapController? _mapController;
  Marker? _selectedMarker;

  @override
  void initState() {
    super.initState();
    _listenToEditStatus(); // <-- ADD THIS LINE

    _fetchFeatureLimit();
    _fetchGlobalPetConfigs(); // <-- ADD THIS LINE
    _fetchPetPricingData(); // <-- NEW data fetching call

    apiKey = const String.fromEnvironment('PLACES_API_KEY');
    _places = PlacesService(apiKey);

    // Initialize non-pricing controllers
    _descCtrl = TextEditingController(text: widget.description);
    _RefundCtrls = { for (var key in refundPolicyKeys) key: TextEditingController(text: widget.refundPolicy[key] ?? '') };
    _walkFeeCtrl = TextEditingController(text: widget.walkingFee);
    _openCtrl = TextEditingController(text: widget.openTime);
    _closeCtrl = TextEditingController(text: widget.closeTime);
    _maxPetsCtrl = TextEditingController(text: widget.maxPetsAllowed);
    _shopNameCtrl = TextEditingController(text: widget.shopName);
    _streetCtrl = TextEditingController(text: widget.street);
    _areaCtrl = TextEditingController(text: widget.areaName);
    _districtCtrl = TextEditingController(text: widget.district);
    _stateCtrl = TextEditingController(text: widget.state);
    _postalCtrl = TextEditingController(text: widget.postalCode);
    _locationCtrl = TextEditingController(text: widget.full_address);
    _coordCtrl = TextEditingController(text: widget.shopLocation);
    _bankAccountCtrl = TextEditingController(text: widget.bank_account_num);
    _bankIfscCtrl = TextEditingController(text: widget.bank_ifsc);
    _images = List.of(widget.image_urls);
    _loadPetTypes();
    _selectedPetTypes = List.of(widget.pets);
    _featureControllers = widget.features.map((f) => TextEditingController(text: f)).toList();
    while (_featureControllers.length < 2) {
      _featureControllers.add(TextEditingController());
    }
  }

  // PASTE THIS METHOD inside _EditServicePageState
  Future<void> _pickPolicyPdf() async {
    // This will open the file picker and let the user select a PDF
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // This is crucial for web to get the file bytes
    );

    if (result != null) {
      setState(() {
        // Store the picked file in our state variable
        _pickedPolicyFile = result.files.first;
      });
    } else {
      // User canceled the picker
    }
  }

  // PASTE THIS NEW WIDGET inside _EditServicePageState
  Widget _buildPolicyUploader() {
    String currentPolicyDisplay;
    // Check if a policy URL already exists from the initial data
    bool hasExistingPolicy = widget.partnerPolicyUrl.isNotEmpty;

    if (_pickedPolicyFile != null) {
      // If a new file has been picked, show its name
      currentPolicyDisplay = 'Staged for upload: ${_pickedPolicyFile!.name}';
    } else if (hasExistingPolicy) {
      // If an old policy exists, try to show its filename
      try {
        currentPolicyDisplay = Uri.decodeComponent(path.basename(Uri.parse(widget.partnerPolicyUrl).path));
      } catch (e) {
        currentPolicyDisplay = 'A policy is available. Click to view.';
      }
    } else {
      // If no policy exists
      currentPolicyDisplay = 'No policy PDF has been uploaded.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // This displays the status of the current policy file
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Current Policy Document',
            labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: Icon(Icons.picture_as_pdf_outlined, color: Colors.grey.shade600),
          ),
          child: InkWell(
            // Only allow clicking to view if an old policy exists and a new one isn't staged
            onTap: hasExistingPolicy && _pickedPolicyFile == null
                ? () async {
              final url = Uri.parse(widget.partnerPolicyUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
                : null,
            child: Text(
              currentPolicyDisplay,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                decoration: hasExistingPolicy && _pickedPolicyFile == null ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // This button triggers the file picker
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickPolicyPdf,
            icon: const Icon(Icons.upload_file), // <-- REMOVE the explicit color
            label: const Text('Upload New Policy PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor, // This will now correctly color BOTH the icon and text
              side: const BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),

          ),
        )
      ],
    );
  }

  // 🔽🔽🔽 ADD THIS ENTIRE NEW METHOD 🔽🔽🔽
  Future<void> _fetchGlobalPetConfigs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('boarding_options')
          .collection('pet_information')
          .get();
      if (!mounted) return;

      final Map<String, dynamic> configs = {};
      for (final doc in snapshot.docs) {
        configs[doc.id] = doc.data();
      }
      setState(() {
        _globalPetConfigs = configs;
      });
    } catch (e) {
      print("Error fetching global pet configs: $e");
    }
  }



  @override
  void dispose() {
    _editStatusSubscription?.cancel(); // <-- ADD THIS LINE

    // Dispose non-pricing controllers
    _descCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _coordCtrl.dispose();
    _maxPetsCtrl.dispose();
    _shopNameCtrl.dispose();
    // ... dispose all other simple controllers ...

    // Dispose new pricing controllers
    _petPricingCtrls.values.forEach((controllers) => controllers.dispose());
    for (var c in _RefundCtrls.values) c.dispose();
    _walkFeeCtrl.dispose();
    for (final controller in _featureControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // In lib/edit_service_page.dart -> _EditServicePageState

// 🔽🔽🔽 REPLACE your existing _listenToEditStatus method with this 🔽🔽🔽
  void _listenToEditStatus() {
    _editStatusSubscription = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      bool isPending = false;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data.containsKey('last_edit')) {
          final lastEdit = data['last_edit'] as Map<String, dynamic>;
          isPending = (lastEdit['marked_as_done'] as bool? ?? true) == false;
        }
      }

      // Update the UI state
      setState(() {
        _isEditRequestPending = isPending;
        _isLoadingStatus = false; // <-- THIS LINE IS THE KEY CHANGE
      });
    }, onError: (error) {
      // Also handle errors by stopping the loading state
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
      print("Error listening to edit status: $error");
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLatLng = position;
      _selectedMarker = Marker(
        markerId: const MarkerId('chosen'),
        position: position,
      );
      _coordCtrl.text = '${position.latitude}, ${position.longitude}';
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(position),
    );
    _reverseGeocode(position.latitude, position.longitude);
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final jsResult = await js_util.promiseToFuture(
        js_util.callMethod(
            html.window, 'reverseGeocodeJs', [lat.toString(), lng.toString()]),
      );
      final street = js_util.getProperty(jsResult, 'street') as String;
      final postalCode = js_util.getProperty(jsResult, 'postalCode') as String;
      final area = js_util.getProperty(jsResult, 'area') as String;
      final district = js_util.getProperty(jsResult, 'district') as String;
      final state = js_util.getProperty(jsResult, 'state') as String;
      setState(() {
        _streetCtrl.text = street;
        _postalCtrl.text = postalCode;
        _areaCtrl.text = area;
        _districtCtrl.text = district;
        _stateCtrl.text = state;
      });
    } catch (e) {
      print('Reverse-geocode error: $e');
    }
  }
// Replace the entire _fetchPetPricingData function
  // REPLACE your entire _fetchPetPricingData function with this

  // REPLACE your _fetchPetPricingData function with this
  Future<void> _fetchPetPricingData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('pet_information')
          .get();

      if (!mounted) return;

      final Map<String, PetPricingControllers> pricingControllers = {};
      final Map<String, dynamic> initialData = {};
      final Map<String, dynamic> sizeConfigs = {};

      for (final doc in snapshot.docs) {
        final petKey = doc.id;
        final data = doc.data();

        // 1. Get ALL possible sizes from the global configuration fetched earlier
        // If global config is missing for some reason, fall back to the saved sizes
        final globalConfig = _globalPetConfigs[petKey];
        final List<String> allPossibleSizes = globalConfig != null
            ? List<String>.from(globalConfig['sizes'] ?? [])
            : List<String>.from(data['sizes'] ?? []);

        // Store all possible sizes so the UI builds fields for every one of them
        sizeConfigs[petKey] = allPossibleSizes;

        // --- 🔽 ADDITION: Fetches the currently saved varieties ---
        final details = {
          'sizes': List<String>.from(data['accepted_sizes'] ?? []),
          'breeds': List<String>.from(data['accepted_breeds'] ?? []),
        };
        _initialSelectedPetDetails[petKey] = Map.from(details);
        _selectedPetDetails[petKey] = details;
        // --- 🔼 END OF ADDITION ---

        Map<String, String> getMap(String key) => Map<String, String>.from(data[key] ?? {});

        final feedingDetailsData = Map<String, dynamic>.from(data['feeding_details'] ?? {});
        final Map<String, dynamic> feedingDetailsCtrls = {};

        feedingDetailsData.forEach((mealTitle, mealFields) {
          final fieldsMap = mealFields as Map<String, dynamic>;
          feedingDetailsCtrls[mealTitle] = fieldsMap.map((fieldName, value) {
            if (value is List) {
              return MapEntry(
                fieldName,
                value.map((item) => TextEditingController(text: item.toString())).toList(),
              );
            }
            if (fieldName.contains('image')) {
              return MapEntry(fieldName, value as String? ?? '');
            }
            return MapEntry(fieldName, TextEditingController(text: value.toString()));
          });
        });

        initialData[petKey] = {
          'rates_daily': getMap('rates_daily'),
          'walking_rates': getMap('walking_rates'),
          'meal_rates': getMap('meal_rates'),
          'offer_daily_rates': getMap('offer_daily_rates'),
          'offer_walking_rates': getMap('offer_walking_rates'),
          'offer_meal_rates': getMap('offer_meal_rates'),
          'feeding_details': feedingDetailsData,
        };

        // 2. Updated: Create controllers for EVERY possible size.
        // If the rate is missing in Firestore, it defaults to an empty string (showing the field in UI).
        Map<String, TextEditingController> createRateControllers(Map<String, String> rates) {
          return {
            for (var size in allPossibleSizes)
              size: TextEditingController(text: rates[size] ?? '')
          };
        }

        pricingControllers[petKey] = PetPricingControllers(
          ratesDaily: createRateControllers(getMap('rates_daily')),
          walkingRates: createRateControllers(getMap('walking_rates')),
          mealRates: createRateControllers(getMap('meal_rates')),
          offerRatesDaily: createRateControllers(getMap('offer_daily_rates')),
          offerWalkingRates: createRateControllers(getMap('offer_walking_rates')),
          offerMealRates: createRateControllers(getMap('offer_meal_rates')),
          feedingDetailsCtrls: feedingDetailsCtrls,
        );
      }

      setState(() {
        _petPricingCtrls = pricingControllers;
        _initialPetPricingData = initialData;
        _petSizeConfigs = sizeConfigs;
        _isLoadingPricing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load pricing details: $e')));
        setState(() { _isLoadingPricing = false; });
      }
    }
  }

  // 🔽🔽🔽 PASTE THESE THREE NEW METHODS 🔽🔽🔽

// Fetches the list of breeds for a pet like "dog"
  Future<List<Map<String, String>>> _fetchBreedsForPet(String petKey) async {
    if (_breedsByPetType.containsKey(petKey)) {
      return _breedsByPetType[petKey]!;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pet_types')
          .doc(petKey)
          .collection('breeds')
          .get();
      final breeds = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, 'name': data['name'] as String? ?? doc.id};
      }).toList();
      _breedsByPetType[petKey] = breeds;
      return breeds;
    } catch (e) {
      print("Error fetching breeds for $petKey: $e");
      return [];
    }
  }

// Builds the actual multi-select dropdown UI
  Widget _buildMultiSelectDropdown({
    required String title,
    required List<MultiSelectItem<String>> items,
    required List<String> initialValue,
    required void Function(List<String>) onConfirm,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        MultiSelectDialogField<String>(
          selectedColor: primaryColor,
          buttonIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          buttonText: Text("Select...", style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14)),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          items: items,
          initialValue: initialValue,
          onConfirm: onConfirm,
          title: Text('Select $title', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          searchable: true,
          chipDisplay: MultiSelectChipDisplay(
            chipColor: primaryColor.withOpacity(0.15),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor),
          ),
        ),
      ],
    );
  }

// The content for our new "Varieties" tab
  Widget _buildVarietiesEditor(String petKey) {
    final globalConfig = _globalPetConfigs[petKey];
    if (globalConfig == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Loading configuration...")));
    }

    final List<String> availableSizes = List<String>.from(globalConfig['sizes'] ?? []);
    final Map<String, dynamic> sizeLabels = Map<String, dynamic>.from(globalConfig['size_labels'] ?? {});

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          _buildMultiSelectDropdown(
            title: 'Accepted Sizes',
            items: availableSizes.map((size) {
              final label = sizeLabels[size] as String? ?? '';
              final displayText = label.isNotEmpty ? '$size ($label kg)' : size;
              return MultiSelectItem<String>(displayText, displayText); // <-- CORRECTED LINE
            }).toList(),
            initialValue: _selectedPetDetails[petKey]?['sizes'] ?? [],
            onConfirm: (results) {
              setState(() {
                _selectedPetDetails[petKey] ??= {};
                _selectedPetDetails[petKey]!['sizes'] = results;
              });
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, String>>>(
            future: _fetchBreedsForPet(petKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No breeds found for this pet.");
              }
              return _buildMultiSelectDropdown(
                title: 'Accepted Breeds',
                items: snapshot.data!.map((breed) => MultiSelectItem<String>(breed['id']!, breed['name']!)).toList(),
                initialValue: _selectedPetDetails[petKey]?['breeds'] ?? [],
                onConfirm: (results) {
                  setState(() {
                    _selectedPetDetails[petKey] ??= {};
                    _selectedPetDetails[petKey]!['breeds'] = results;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // PASTE THESE TWO NEW METHODS inside _EditServicePageState

// This method handles picking a new image
  Future<void> _onPickFeedImage(String petKey, String mealTitle, String fieldName) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() {
      // Update the state with the new XFile object, which will trigger a UI rebuild
      _petPricingCtrls[petKey]!.feedingDetailsCtrls[mealTitle][fieldName] = pickedFile;
    });
  }

// This method builds the UI for the image editor
  Widget _buildImageEditor(String label, dynamic imageValue, VoidCallback onUpdate) {
    Widget imagePreview;
    if (imageValue is XFile) {
      // New local image selected by user
      imagePreview = Image.network(imageValue.path, fit: BoxFit.contain, height: 150, width: double.infinity);
    } else if (imageValue is String && imageValue.isNotEmpty) {
      // Existing image URL from Firestore
      imagePreview = CachedNetworkImage(
        imageUrl: imageValue,
        fit: BoxFit.cover,
        height: 150,
        width: double.infinity,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else {
      // No image
      imagePreview = Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: const Center(child: Icon(Icons.photo_library_outlined, color: Colors.grey, size: 40)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imagePreview,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onUpdate,
            icon: const Icon(Icons.upload_file, color: Colors.black87,),
            label: const Text("Update Image"),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  // PASTE THIS NEW METHOD
  // DELETE the old _buildFeedingInfoEditor and PASTE these two new methods

// This is the new main editor for the "Feeding Info" tab
  // REPLACE your _buildFeedingInfoEditor with this
  Widget _buildFeedingInfoEditor(String petKey, Map<String, dynamic> feedingDetailsCtrls) {
    if (feedingDetailsCtrls.isEmpty) {
      return const Center(child: Text("No feeding info structure found."));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: feedingDetailsCtrls.entries.map((mealEntry) {
        final mealTitle = mealEntry.key;
        final mealData = mealEntry.value as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mealTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              ...mealData.entries.map((fieldEntry) {
                final fieldName = fieldEntry.key;
                final label = fieldName.replaceAll('_', ' ').capitalize();
                final value = fieldEntry.value;

                if (fieldName.contains('image')) {
                  return _buildImageEditor(label, value, () {
                    _onPickFeedImage(petKey, mealTitle, fieldName);
                  });
                } else if (value is TextEditingController) {
// REPLACE WITH THIS
// Check if the label contains 'portion' (case-insensitive) to make it optional
                  final bool isOptional = label.toLowerCase().contains('portion');
                  return _buildField(label, value, icon: Icons.edit_note, isRequired: !isOptional);                } else if (value is List<TextEditingController>) {
                  return _buildPointsEditor(label, value);
                } else {
                  return const SizedBox.shrink();
                }
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

// This is a new helper for editing lists of items (like ingredients)
  Widget _buildPointsEditor(String label, List<TextEditingController> controllers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: primaryColor),
                onPressed: () => setState(() => controllers.add(TextEditingController())),
              )
            ],
          ),
          const SizedBox(height: 8),
          ...controllers.asMap().entries.map((entry) {
            int idx = entry.key;
            TextEditingController ctrl = entry.value;
            return _buildField(
              '#${idx + 1}',
              ctrl,
              suffix: IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => setState(() => controllers.removeAt(idx)),
              ),
            );
          }),
        ],
      ),
    );
  }


  Future<void> _fetchFeatureLimit() async {
    // (This function remains unchanged)
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('limits').get();
      if (doc.exists && doc.data() != null) {
        final limit = int.tryParse(doc.data()!['home_boarding_feature_limit'] as String? ?? '');
        if (limit != null && mounted) setState(() => _featureLimit = limit);
      }
    } catch (e) { print('Error fetching feature limit: $e'); }
  }

  Future<void> _loadPetTypes() async {
    // (This function remains unchanged)
    final snap = await FirebaseFirestore.instance.collection('pet_types').where('display', isEqualTo: true).get();
    if (mounted) setState(() => _petTypes = snap.docs.map((d) => PetType(id: d.id, display: true)).toList());
  }

  // --- UPDATED: Submission Logic ---
  // REPLACE your entire _onSubmit function with this final version

  // REPLACE your entire _onSubmit method with this one
  Future<void> _onSubmit() async {
    if (_isUploading) return;
    if (!_formKey.currentState!.validate() || !_featuresFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the errors before submitting.')));
      return;
    }

    final newFeatures = _featureControllers.map((c) => c.text.trim()).where((f) => f.isNotEmpty).toList();
    if (newFeatures.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A minimum of two features are required.')));
      return;
    }

    setState(() => _isUploading = true);

    final List<Map<String, dynamic>> changes = [];

    try {
      // --- 1. HANDLE FILE UPLOADS (POLICY AND IMAGES) ---

      // 🔽 START OF NEW POLICY UPLOAD LOGIC 🔽
      String finalPolicyUrl = widget.partnerPolicyUrl; // Default to the existing URL

      if (_pickedPolicyFile != null) {
        // A new policy PDF was selected, so we need to process it.

        // First, delete the old file from storage if a URL for it exists.
        if (widget.partnerPolicyUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(widget.partnerPolicyUrl).delete();
            print('Successfully deleted old policy file.');
          } catch (e) {
            // This error is okay, it might mean the file was already deleted or the URL was invalid.
            print('Could not delete old policy file (it may not exist): $e');
          }
        }

        // Next, upload the new file. We use a consistent path.
        final policyRef = FirebaseStorage.instance.ref()
            .child('service_policies/${widget.serviceId}/terms_and_conditions.pdf');

        // Use putData with bytes for web compatibility.
        final uploadTask = policyRef.putData(_pickedPolicyFile!.bytes!);
        final snapshot = await uploadTask;

        // Get the new download URL and store it.
        finalPolicyUrl = await snapshot.ref.getDownloadURL();
      }
      // 🔼 END OF NEW POLICY UPLOAD LOGIC 🔼

      final List<String> finalImageUrls = [];
      for (final item in _images) {
        if (item is String) {
          finalImageUrls.add(item);
        } else if (item is XFile) {
          final storageRef = FirebaseStorage.instance.ref().child('service_images/${widget.serviceId}/${DateTime.now().millisecondsSinceEpoch}');
          final bytes = await item.readAsBytes();
          final snapUpload = await storageRef.putData(bytes);
          finalImageUrls.add(await snapUpload.ref.getDownloadURL());
        }
      }

      // (The rest of the data preparation logic remains the same)
      final Map<String, Map<String, int>> newPreCalcStandardPrices = {};
      final Map<String, Map<String, int>> newPreCalcOfferPrices = {};

      final Map<String, dynamic> finalPetData = {};
      for (final petKey in _petPricingCtrls.keys) {
        final controllers = _petPricingCtrls[petKey]!;
        final sizes = List<String>.from(_petSizeConfigs[petKey] ?? []);
        final newFeedingDetails = <String, dynamic>{};

        final Map<String, String> totalPricesMap = {};
        for (var size in sizes) {
          final dailyRate = int.tryParse(controllers.ratesDaily[size]?.text.trim() ?? '') ?? 0;
          final walkingRate = int.tryParse(controllers.walkingRates[size]?.text.trim() ?? '') ?? 0;
          final mealRate = int.tryParse(controllers.mealRates[size]?.text.trim() ?? '') ?? 0;
          final total = dailyRate + walkingRate + mealRate;
          totalPricesMap[size] = total.toString();
        }

        final Map<String, String> totalOfferPricesMap = {};
        for (var size in sizes) {
          final offerDailyRate = int.tryParse(controllers.offerRatesDaily[size]?.text.trim() ?? '') ?? 0;
          final offerWalkingRate = int.tryParse(controllers.offerWalkingRates[size]?.text.trim() ?? '') ?? 0;
          final offerMealRate = int.tryParse(controllers.offerMealRates[size]?.text.trim() ?? '') ?? 0;
          final totalOffer = offerDailyRate + offerWalkingRate + offerMealRate;
          totalOfferPricesMap[size] = totalOffer.toString();
        }

        newPreCalcStandardPrices[petKey] = totalPricesMap.map((key, value) => MapEntry(key, int.tryParse(value) ?? 0));
        newPreCalcOfferPrices[petKey] = totalOfferPricesMap.map((key, value) => MapEntry(key, int.tryParse(value) ?? 0));

        for (var mealEntry in controllers.feedingDetailsCtrls.entries) {
          final mealTitle = mealEntry.key;
          final fields = mealEntry.value as Map<String, dynamic>;
          final newFields = <String, dynamic>{};

          for (var fieldEntry in fields.entries) {
            final fieldName = fieldEntry.key;
            final value = fieldEntry.value;
            dynamic finalValue;
            if (value is XFile) {
              final ref = FirebaseStorage.instance.ref().child('feeding_images/${widget.serviceId}/$petKey/${mealTitle}_${fieldName}');
              final url = await (await ref.putData(await value.readAsBytes())).ref.getDownloadURL();
              finalValue = url;
            } else if (value is TextEditingController) {
              finalValue = value.text.trim();
            } else if (value is List<TextEditingController>) {
              finalValue = value.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
            } else {
              finalValue = value;
            }
            newFields[fieldName] = finalValue;
          }
          newFeedingDetails[mealTitle] = newFields;
        }

        Map<String, String> controllersToMap(Map<String, TextEditingController> ctrls) {
          return { for (var size in sizes) size: ctrls[size]!.text.trim() }..removeWhere((k, v) => v.isEmpty);
        }

        finalPetData[petKey] = {
          'rates_daily': controllersToMap(controllers.ratesDaily),
          'walking_rates': controllersToMap(controllers.walkingRates),
          'meal_rates': controllersToMap(controllers.mealRates),
          'offer_daily_rates': controllersToMap(controllers.offerRatesDaily),
          'offer_walking_rates': controllersToMap(controllers.offerWalkingRates),
          'offer_meal_rates': controllersToMap(controllers.offerMealRates),
          'total_prices': totalPricesMap,
          'total_offer_prices': totalOfferPricesMap,
          'accepted_sizes': _selectedPetDetails[petKey]?['sizes'] ?? [],
          'accepted_breeds': _selectedPetDetails[petKey]?['breeds'] ?? [],
          'feeding_details': newFeedingDetails,
        };
      }
      changes.add({
        'label': 'Pre-Calculated Prices Update',
        'newValueMap': {
          'pre_calculated_standard_prices': newPreCalcStandardPrices,
          'pre_calculated_offer_prices': newPreCalcOfferPrices,
        }
      });

      // --- 2. DETECT ALL CHANGES ---
      void addSimpleChange(String label, String oldValue, String newValue) {
        if (oldValue != newValue) {
          changes.add({'label': label, 'oldValue': oldValue, 'newValue': newValue});
        }
      }

      addSimpleChange('Service Name', widget.shopName, _shopNameCtrl.text.trim());
      addSimpleChange('Description', widget.description, _descCtrl.text.trim());
      addSimpleChange('Open Time', widget.openTime, _openCtrl.text.trim());
      addSimpleChange('Close Time', widget.closeTime, _closeCtrl.text.trim());
      addSimpleChange('Max Pets Allowed', widget.maxPetsAllowed, _maxPetsCtrl.text.trim());
      addSimpleChange('Full Address', widget.full_address, _locationCtrl.text.trim());

      // 🔽 THIS IS THE KEY CHANGE FOR CHANGE DETECTION 🔽
      // We now compare the original URL with the final URL (which might be new or the same)
      addSimpleChange('Business Policy URL', widget.partnerPolicyUrl, finalPolicyUrl);

      for (final petKey in finalPetData.keys) {
        final initialFullData = Map<String, dynamic>.from(_initialPetPricingData[petKey] ?? {});
        initialFullData['accepted_sizes'] = _initialSelectedPetDetails[petKey]?['sizes'] ?? [];
        initialFullData['accepted_breeds'] = _initialSelectedPetDetails[petKey]?['breeds'] ?? [];
        if (!const DeepCollectionEquality().equals(finalPetData[petKey], initialFullData)) {
          changes.add({
            'label': 'Pet Information Update',
            'pet': petKey,
            'oldValueMap': initialFullData,
            'newValueMap': finalPetData[petKey]
          });
        }
      }

      final newRefund = { for (var key in _RefundCtrls.keys) key: _RefundCtrls[key]!.text.trim() }..removeWhere((k, v) => v.isEmpty);
      if (!mapEquals(newRefund, widget.refundPolicy)) {
        changes.add({'label': 'Refund Policy', 'oldValueMap': widget.refundPolicy, 'newValueMap': newRefund});
      }
      if (!const ListEquality().equals(_selectedPetTypes, widget.pets)) {
        changes.add({'label': 'Pets Serviced', 'oldValueList': widget.pets, 'newValueList': _selectedPetTypes});
      }
      if (!const ListEquality().equals(finalImageUrls, widget.image_urls)) {
        changes.add({'label': 'Gallery Images', 'oldValueList': widget.image_urls, 'newValueList': finalImageUrls});
      }
      if (!const ListEquality().equals(newFeatures, widget.features)) {
        changes.add({'label': 'Features', 'oldValueList': widget.features, 'newValueList': newFeatures});
      }
      if (_selectedLatLng != null) {
        changes.add({'label': 'GeoPoint', 'oldValue': widget.shopLocation, 'newValueGeo': GeoPoint(_selectedLatLng!.latitude, _selectedLatLng!.longitude)});
      }

      if (changes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes were made to submit.')));
        setState(() => _isUploading = false);
        return;
      }

      // --- 3. SUBMIT REQUEST TO FIRESTORE ---
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';
      final parentDocRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId);
      final reqRef = FirebaseFirestore.instance.collection('users-sp-boarding').doc(widget.serviceId).collection('profile_edit_requests').doc();
      await reqRef.set({'requester': userEmail, 'timestamp': FieldValue.serverTimestamp(), 'handled': false, 'changes': changes});
      await parentDocRef.update({
        'last_edit': {
          'ts': FieldValue.serverTimestamp(),
          'marked_as_done': false,
          'request_id': reqRef.id,
        }
      });

      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request submitted successfully.')));

      if (mounted) {
        await Provider.of<UserNotifier>(context, listen: false).refreshUserProfile();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => PartnerShell(
              serviceId: widget.serviceId,
              // We are navigating to the main profile/overview page of the new branch
              currentPage: PartnerPage.profile,
              child: BoardingDetailsLoader(serviceId: widget.serviceId),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- UI Widgets ---

  // (All helper widgets like _buildSectionCard, _buildField, _buildTimeField, _buildLocationSection, _buildImagePicker, etc. remain unchanged)
  // ... Paste your existing helper widgets here ...
  Widget _buildSectionCard({ required String title, String? subtitle, required List<Widget> children, IconData? icon, }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5)) ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, color: primaryColor, size: 28),
              if (icon != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    if (subtitle != null) Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          ...children,
        ],
      ),
    );
  }

  // --- NEW: Helper to get a nice icon for each pet ---
  IconData _getPetIcon(String petName) {
    switch (petName.toLowerCase()) {
      case 'dog':
        return Icons.pets; // Standard dog icon
      case 'cat':
      // You might need a custom icon pack for a specific cat icon, using a paw as a fallback
        return Icons.pets; // Using pets icon as a placeholder
      default:
        return Icons.star_outline; // Generic icon for other pets
    }
  }
  // REPLACE the _buildPetPricingCard widget with this
  Widget _buildPetPricingCard(PetPricing pricing) {
    final displayName = pricing.petName[0].toUpperCase() + pricing.petName.substring(1);
    final bool hasOffers = pricing.offerRatesDaily.isNotEmpty ||
        pricing.offerWalkingRatesDaily.isNotEmpty ||
        pricing.offerMealRatesDaily.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: primaryColor.withOpacity(0.05),
        collapsedBackgroundColor: Colors.white,
        iconColor: primaryColor,
        collapsedIconColor: primaryColor,
        leading: Icon(_getPetIcon(pricing.petName), color: primaryColor, size: 28),
        title: Text(
          displayName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        children: [
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryColor,
                  tabs: [
                    Tab(text: "Standard"),
                    Tab(text: "Offers"),
                    Tab(text: "Feeding Info"),
                  ],
                ),
                Container(
                  height: 350, // Increased height to fit more fields
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: TabBarView(
                    children: [
                      // Standard Rates
                      SingleChildScrollView(
                        child: Column(children: [
                          _buildPriceGroup('Boarding', pricing.ratesDaily),
                          _buildPriceGroup('Walking', pricing.walkingRatesDaily),
                          _buildPriceGroup('Meals', pricing.mealRatesDaily),
                        ]),
                      ),
                      // Offer Rates
                      SingleChildScrollView(
                        child: Column(children: [
                          if(hasOffers) ...[
                            _buildPriceGroup('Boarding', pricing.offerRatesDaily),
                            _buildPriceGroup('Walking', pricing.offerWalkingRatesDaily),
                            _buildPriceGroup('Meals', pricing.offerMealRatesDaily),
                          ] else
                            const Center(child: Text("No offers set for this pet."))
                        ]),
                      ),
                      // Feeding Info
                      SingleChildScrollView(
                        child: _buildFeedingInfoEditor(pricing.petName, pricing.feedingDetails), // NEW
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  // NOTE: This existing function is now reused inside our new Pet Pricing Card!
  Widget _buildPriceGroup(String title, Map<String, String> rates) {
    // If a pet has no rates for a specific group (e.g., no meal rates), don't show anything.
    if (rates.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ...rates.entries.map((e) => Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: GoogleFonts.poppins(fontSize: 15)),
                Text('₹${e.value}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }
  // --- NEW: UI for Pet-Specific Pricing ---
  // 🔽🔽🔽 REPLACE the existing _buildPetPricingEditor widget with this 🔽🔽🔽
  Widget _buildPetPricingEditor() {
    if (_isLoadingPricing) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_selectedPetTypes.isEmpty) {
      return Text(
        "Select a pet type from the 'General Information' section to set its pricing.",
        style: GoogleFonts.poppins(color: Colors.grey.shade600),
      );
    }

    return Column(
      children: _selectedPetTypes.map((petName) {
        final petKey = petName.toLowerCase();
        final controllers = _petPricingCtrls[petKey];
        final sizes = List<String>.from(_petSizeConfigs[petKey] ?? []);

        if (controllers == null || sizes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Loading pricing for $petName...", style: GoogleFonts.poppins()),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)
          ),
          child: DefaultTabController(
            length: 4, // Changed to 4 tabs
            child: ExpansionTile(
              title: Text(petName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
              childrenPadding: const EdgeInsets.all(16),
              backgroundColor: primaryColor.withOpacity(0.04),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              children: [
                const TabBar(
                  isScrollable: true,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: primaryColor,
                  tabs: [
                    Tab(text: "Varieties"), // <-- NEW TAB
                    Tab(text: "Standard"),
                    Tab(text: "Offers"),
                    Tab(text: "Feeding Info"),
                  ],
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      _buildVarietiesEditor(petKey), // <-- NEW TAB VIEW
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            _buildRateFields('Daily Boarding Rates (₹)', controllers.ratesDaily, sizes),
                            const Divider(height: 24),
                            _buildRateFields('Walking Rates (₹)', controllers.walkingRates, sizes),
                            const Divider(height: 24),
                            _buildRateFields('Meal Rates (₹)', controllers.mealRates, sizes),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            _buildRateFields('Offer: Daily Boarding (₹)', controllers.offerRatesDaily, sizes),
                            const Divider(height: 24),
                            _buildRateFields('Offer: Walking (₹)', controllers.offerWalkingRates, sizes),
                            const Divider(height: 24),
                            _buildRateFields('Offer: Meals (₹)', controllers.offerMealRates, sizes),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildFeedingInfoEditor(petKey, controllers.feedingDetailsCtrls),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- MODIFIED: _buildRateFields to accept sizes ---
  Widget _buildRateFields(String title, Map<String, TextEditingController> controllers, List<String> sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: sizes.map((sz) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 150),
// Inside _buildRateFields
              child: _buildField(
                '$sz Rate',
                controllers[sz]!,
                icon: Icons.currency_rupee,
                // Add a hint so if the text is empty, the user sees '0'
                hintText: '0',
              ),            );
          }).toList(),
        ),
      ],
    );
  }

  // (Paste all your other UI helper methods here: _buildField, _buildTimeField, _buildLocationSection, etc.)
  // They do not need to be changed.

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      // If we are loading, show a simple Scaffold with a centered spinner.
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        title: Text(
          'Edit Service Details',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        EditHistoryPage(serviceId: widget.serviceId),
                  ),
                );
              },
              icon: const Icon(Icons.history, color: primaryColor),
              label: Text('Edit History', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: primaryColor.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SERVICE ID BANNER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3))
                ),
                child: Text(
                  'Service ID: ${widget.serviceId}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // --- GENERAL INFO (Unchanged) ---
              _buildSectionCard(
                title: 'General Information',
                icon: Icons.info_outline,
                children: [
                  _buildField('Service Name', _shopNameCtrl),
                  _buildField('Description', _descCtrl, maxLines: 4),
                  Wrap(
                    spacing: 16, runSpacing: 16,
                    children: [
                      _buildTimeField('Open Time', _openCtrl),
                      _buildTimeField('Close Time', _closeCtrl),
                      _buildField('Max Pets Allowed', _maxPetsCtrl),
                      _buildPetTypeSelector(), // This now drives the pricing section
                    ],
                  )
                ],
              ),
              _buildSectionCard(title: 'Features & Amenities', icon: Icons.checklist_rtl_outlined, children: [_buildFeaturesSection()]),
              _buildSectionCard(title: 'Service Photos', subtitle: 'Add up to 6 high-quality images.', icon: Icons.photo_library_outlined, children: [_buildImagePicker()]),
              _buildSectionCard(title: 'Location Details', subtitle: 'Search or tap on the map to set your location.', icon: Icons.location_on_outlined, children: [_buildLocationSection()]),

              // --- REPLACED Pricing & Offers with new dynamic section ---
              _buildSectionCard(
                title: 'Pet-Specific Pricing',
                subtitle: 'Set your standard and offer prices for each pet type.',
                icon: Icons.payments_outlined,
                children: [_buildPetPricingEditor()], // <-- NEW DYNAMIC WIDGET
              ),
              _buildSectionCard(
                  title: 'Refund Policy',
                  icon: Icons.policy_outlined,
                  children: [_buildRefundPolicyFields()]
              ),

              // V V V ADD THIS ENTIRE NEW SECTION V V V

// REPLACE IT WITH THIS:
              _buildSectionCard(
                title: 'Business Policies',
                icon: Icons.description_outlined,
                subtitle: "Upload your business's terms & conditions as a PDF document.",
                children: [
                  _buildPolicyUploader(), // <-- USE THE NEW WIDGET
                ],
              ),


            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildFloatingActionBar(),
    );
  }
  Widget _buildPetTypeSelector() {
    return FormField<List<String>>(
      initialValue: _selectedPetTypes,
      validator: (v) =>
      (v == null || v.isEmpty) ? 'Select at least one pet' : null,
      builder: (field) => InkWell(
        onTap: () async {
          List<String> tempSelected = List.from(_selectedPetTypes);
          final picked = await _showMyDialog<List<String>>(
            context,
            StatefulBuilder(
              builder: (ctx2, setState2) => AlertDialog(
                // --- STYLE UPDATES START HERE ---

                // 1. Gives the dialog a modern, sharp, but slightly rounded shape.
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),

                // 2. Refined padding for a cleaner look.
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                contentPadding: EdgeInsets.zero,
                actionsPadding: const EdgeInsets.all(16),

                // 3. Enhanced title styling.
                title: Text('Select Pets Catered To',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 20)),

                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 4. A thin divider for better visual separation.
                    const Divider(height: 1, thickness: 1),
                    // 5. Constrains the height to prevent overly tall dialogs.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _petTypes.map((pt) {
                            final isChecked = tempSelected.contains(pt.id);
                            return CheckboxListTile(
                              title: Text(pt.id, style: GoogleFonts.poppins()),
                              value: isChecked,
                              activeColor: primaryColor,
                              controlAffinity: ListTileControlAffinity.leading, // Moves checkbox to the left
                              onChanged: (b) => setState2(() {
                                if (b == true) {
                                  tempSelected.add(pt.id);
                                } else {
                                  tempSelected.remove(pt.id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                  ],
                ),
                actions: [
                  // 6. Refined button styling for clear primary/secondary actions.
                  TextButton(
                    onPressed: () => Navigator.pop(ctx2, null),
                    child: Text('CANCEL',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx2, tempSelected),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0, // Flatter, more modern look
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    child: Text('CONFIRM',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
                // --- STYLE UPDATES END HERE ---
              ),
            ),
          );
          if (picked != null) {
            setState(() => _selectedPetTypes = picked);
            field.didChange(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Pets Catered To',
            labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
            errorText: field.errorText,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
          ),
          child: Text(
            _selectedPetTypes.isEmpty
                ? 'Tap to select'
                : _selectedPetTypes.join(', '),
            style: GoogleFonts.poppins(
              color: _selectedPetTypes.isEmpty ? Colors.grey.shade700 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // In lib/edit_service_page.dart -> _EditServicePageState

// 🔽🔽🔽 REPLACE your existing _buildFloatingActionBar with this 🔽🔽🔽
  Widget _buildFloatingActionBar() {
    // The button is disabled if uploading OR if an edit request is already pending.
    final bool isButtonDisabled = _isUploading || _isEditRequestPending;

    // Determine the button text based on the current state.
    String buttonText = 'Submit Edit Request';
    if (_isUploading) {
      buttonText = 'Uploading...';
    } else if (_isEditRequestPending) {
      buttonText = 'Request Pending Approval';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          border: Border(top: BorderSide(color: Colors.grey.shade200))
      ),
      // Wrap in a Column to add the pending request message
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Show a message ONLY when a request is pending
          if (_isEditRequestPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'An edit request is already pending. The form is locked until it is approved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // The button itself
          ElevatedButton.icon(
            onPressed: isButtonDisabled ? null : _onSubmit,
            icon: _isUploading
                ? Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 8),
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(
                _isEditRequestPending ? Icons.hourglass_top_rounded : Icons.send,
                color: Colors.white, size: 20),
            label: Text(
              buttonText,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFeaturesSection() {
    bool canAddMore = _featureControllers.length < _featureLimit;

    return Form(
      key: _featuresFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header with Action Button and Counter ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "Please list at least two key features of your service.",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 16),
              // Counter Text
              Text(
                '${_featureControllers.length} / $_featureLimit',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: canAddMore ? Colors.grey.shade700 : errorColor,
                ),
              ),
              // Conditional Add Button
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: canAddMore ? primaryColor : Colors.grey.shade400,
                  size: 28,
                ),
                tooltip: canAddMore ? 'Add Another Feature' : 'Limit reached',
                onPressed: canAddMore
                    ? () {
                  setState(() {
                    _featureControllers.add(TextEditingController());
                  });
                }
                    : null, // Disables the button when limit is reached
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Dynamic List of Text Fields (no changes here) ---
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _featureControllers.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextFormField(
                  controller: _featureControllers[index],
                  style: GoogleFonts.poppins(color: Colors.black87),
                  validator: (v) {
                    if (index < 2 && (v == null || v.trim().isEmpty)) {
                      return 'This feature is required';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Feature #${index + 1}',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 2)),
                    prefixIcon: const Icon(Icons.star_border_rounded, color: Colors.grey),
                    suffixIcon: _featureControllers.length > 2
                        ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _featureControllers[index].dispose();
                          _featureControllers.removeAt(index);
                        });
                      },
                    )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _images.length + 1, // Use the new list
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (ctx, i) {
        if (i == _images.length) {
          if (_images.length >= 6) return const SizedBox.shrink();
          return _isUploading
              ? Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)))
              : InkWell(
            onTap: _onPickImage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: primaryColor, size: 28),
                    const SizedBox(height: 8),
                    Text('Add Photo', style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          );
          // ... your "Add Photo" button UI remains the same ...
        }

        final item = _images[i];
        Widget imageWidget;

        // Check the type to decide how to display the image
        if (item is String) {
          // It's an existing image from Firebase Storage
          imageWidget = Image.network(item, fit: BoxFit.cover);
        } else if (item is XFile) {
          // It's a new local image, show a preview
          imageWidget = Image.network(item.path, fit: BoxFit.cover); // For web
          // For mobile, you would use: Image.file(io.File(item.path), fit: BoxFit.cover);
        } else {
          imageWidget = const Icon(Icons.error); // Fallback
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(fit: StackFit.expand, children: [
            imageWidget,
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(i)), // Update the new list
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
                  child: Icon(Icons.cancel, color: Colors.red.shade400, size: 22),
                ),                // ... your remove icon UI ...
              ),
            ),
          ]),
        );
      },
    );
  }
// REPLACE WITH THIS
  Widget _buildField(String label, TextEditingController ctrl,
      {IconData? icon,
        bool readOnly = false,
        Widget? suffix,
        int? maxLines = 1,
        bool isRequired = true,
        String? hintText}) { // Added hintText parameter
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        readOnly: readOnly, // Ensure readOnly is actually applied
        style: GoogleFonts.poppins(color: Colors.black87),
        decoration: InputDecoration(
            labelText: label,
            hintText: hintText, // Use the hintText here
            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
            labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
            suffixIcon: suffix),
        // Set isRequired to false when calling this for Pricing so users can see '0'
        validator: isRequired ? (v) => (v == null || v.trim().isEmpty ? 'Required' : null) : null,
      ),
    );
  }
  Widget _buildTimeField(String label, TextEditingController ctrl) {
    return _buildField(
      label,
      ctrl,
      readOnly: true,
      suffix: GestureDetector(
        onTap: () async {
          TimeOfDay initial = TimeOfDay.now();
          final parts = ctrl.text.split(RegExp(r'[: ]'));
          if (parts.length >= 2) {
            initial = TimeOfDay(
                hour: int.tryParse(parts[0])!, minute: int.tryParse(parts[1])!);
          }
          // In _buildTimeField's onTap function

          final picked = await showTimePicker(
            context: context,
            initialTime: initial,
            // ▼▼▼ ADD THIS BUILDER ▼▼▼
            builder: (context, child) {
              return Theme(
                // Provide a custom theme just for the picker
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    // This will be the main selection color (e.g., the clock hand and numbers)
                    primary: Color(0xFFF67B0D), // Your accent color
                    // This is the color of the text on top of the primary color (e.g., '9' in '9:30')
                    onPrimary: Colors.white,
                    // This is the color of the dialog surface
                    surface: Colors.white,
                    // This is the color of text on the surface
                    onSurface: Colors.black87,
                  ),
                  // Style for the 'OK' and 'Cancel' buttons
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFF67B0D), // Your accent color
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
// ▲▲▲ END OF ADDITION ▲▲▲

          if (picked != null) ctrl.text = picked.format(context);
          if (picked != null) ctrl.text = picked.format(context);
        },
        // ▼▼▼ THIS IS THE ONLY CHANGE ▼▼▼
        child: Icon(Icons.access_time_filled_rounded, color: primaryColor),
      ),
    );
  }

  Widget _buildLocationSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        final mapHeight = isWide ? 450.0 : 300.0;

        Widget mapWidget = SizedBox(
          height: mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(20.5937, 78.9629), zoom: 5),
              onTap: _onMapTap,
              markers: _selectedMarker != null ? {_selectedMarker!} : {},
              onMapCreated: (c) => _mapController = c,
            ),
          ),
        );

        Widget addressFields = Column(
          children: [
            TypeAheadFormField<AutocompletePrediction>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _locationCtrl,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: 'Search for your full address',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                ),
              ),
              suggestionsCallback: (pattern) =>
              pattern.isEmpty ? [] : _places.autocomplete(pattern),
              itemBuilder: (ctx, pred) => ListTile(
                title: Text(pred.description, style: GoogleFonts.poppins()),
              ),
              onSuggestionSelected: (pred) async {
                _locationCtrl.text = pred.description;
                try {
                  final coord = await _places.getPlaceLocation(pred.placeId);
                  setState(() {
                    _selectedLatLng = coord;
                    _selectedMarker = Marker(markerId: const MarkerId('selected-place'), position: coord);
                    _coordCtrl.text = '${coord.latitude}, ${coord.longitude}';
                  });
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(coord, 15));
                  _reverseGeocode(coord.latitude, coord.longitude);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching location: $e')));
                }
                _places.resetSession();
              },
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildField('Coordinates', _coordCtrl, icon: Icons.gps_fixed, readOnly: false),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildField('Street', _streetCtrl, icon: Icons.signpost_outlined, readOnly: false),
                _buildField('Area', _areaCtrl, icon: Icons.location_city_outlined, readOnly: false),
                _buildField('District', _districtCtrl, icon: Icons.map_outlined, readOnly: false),
                _buildField('State', _stateCtrl, icon: Icons.flag_outlined, readOnly: false),
                _buildField('Postal Code', _postalCtrl, icon: Icons.local_post_office_outlined, readOnly: false),
              ],
            )
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: mapWidget),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: addressFields),
            ],
          );
        } else {
          return Column(
            children: [
              mapWidget,
              const SizedBox(height: 24),
              addressFields,
            ],
          );
        }
      },
    );
  }
  Future<void> _onPickImage() async {
    if (_images.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only have up to 6 images.')),
      );
      return;
    }

    final pickedList = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (pickedList.isEmpty) return;

    final remainingSlots = 6 - _images.length;
    final limitedList = pickedList.take(remainingSlots).toList();

    // Simply add the selected files to the list for local preview
    setState(() {
      _images.addAll(limitedList);
    });
  }
  // --- ASYNC LOGIC (Unchanged) ---
  Future<T?> _showMyDialog<T>(BuildContext c, Widget dialog) async {
    setState(() => _dialogOpen = true);
    final result = await showDialog<T>(context: c, builder: (_) => dialog);
    setState(() => _dialogOpen = false);
    return result;
  }

  Widget _buildRefundPolicyFields() {
    String formatPolicyKey(String key) {
      try {
        final parts = key.split('_');
        if (parts.length != 2) return key;
        String condition;
        switch (parts[0]) {
          case 'gt': condition = 'Greater than'; break;
          case 'lt': condition = 'Less than'; break;
          default: return key;
        }
        final hours = parts[1].replaceAll('h', '');
        return '$condition $hours hours';
      } catch (e) {
        return key;
      }
    }

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Refund Policy (%)',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      // ▼▼▼ ADD THIS SUBTITLE ▼▼▼
      subtitle: Text(
        'Set the refund if a user cancels within a timeframe before check-in.',
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
      ),
      // ▲▲▲ END OF ADDITION ▲▲▲
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _RefundCtrls.keys.map((key) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 250),
                child: _buildField(
                  formatPolicyKey(key),
                  _RefundCtrls[key]!,
                  icon: Icons.percent_outlined,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

