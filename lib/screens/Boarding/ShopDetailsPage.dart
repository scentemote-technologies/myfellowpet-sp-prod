// lib/screens/ShopDetailsPage.dart
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/chip_display/multi_select_chip_display.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';

import '../../providers/boarding_details_loader.dart';
import '../Partner/partner_appbar.dart';
import '../../services/places_service.dart';

const Color primary = Color(0xFF2CB4B6);

class ShopDetailsPage extends StatefulWidget {
  final String uid;
  final String phone;
  final String runType;      // ← new field
  final String serviceId;      // ← new field


  const ShopDetailsPage({
    Key? key,
    required this.uid,
    required this.phone, required this.runType, required this.serviceId,
  }) : super(key: key);

  @override
  _ShopDetailsPageState createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  late final String apiKey;
  late final PlacesService _places;

  LatLng? _selectedLatLng;


  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  static const List<String> sizes = ['Small','Medium','Large','Giant'];
  static const List<String> percentages = ['gt_12h','gt_24h','gt_48h','gt_4h','lt_4h'];

  final Map<String,TextEditingController> _dailyPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final Map<String,TextEditingController> _OfferdailyPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final Map<String,TextEditingController> _RefundCtrls = {
    for (var s in percentages) s: TextEditingController()
  };
  final Map<String,TextEditingController> _OfferWalkingPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final Map<String,TextEditingController> _OfferMealPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final Map<String,TextEditingController> _WalkingPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final Map<String,TextEditingController> _MealPriceCtrls = {
    for (var s in sizes) s: TextEditingController()
  };
  final TextStyle headerStyle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.bold
  );

  String? _errorText;

  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _cinCtrl = TextEditingController();
  final TextEditingController _ifscCtrl = TextEditingController();
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _panCtrl = TextEditingController();
  final TextEditingController _gstinCtrl = TextEditingController();



  // Controllers for form fields:
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _coordController = TextEditingController();
  final TextEditingController _walkingController = TextEditingController();
  final TextEditingController _maxPetsController = TextEditingController();
  final TextEditingController _maxPetsPerHourController = TextEditingController();

  // Controllers for Area, District, State (existing):
  final TextEditingController _areaNameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  // NEW Controllers for Street and Postal Code:
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _employeePhoneController =
  TextEditingController();

  TimeOfDay? _openTime;
  String? _contractUrl;
  TimeOfDay? _closeTime;
  List<Map<String, String>> _employees = [];
  List<String> _imagePaths = [];

  // Pet / Pet-Type selections:
  final List<String> _petOptions = [
    'Bunnies',
    'Cat',
    'Dog',
    'Fish',
    'Bird',
    'Hamster',
    'Guinea Pig',
    'Cows',
    'Buffaloes',
    'Turtles',
  ];
  final List<String> _petTypes = ['Large pets', 'Small pets'];
  List<String> _selectedPets = [];
  List<String> _selectedPetTypes = [];

  // Price suggestions:
  List<double> priceRecommendations = [500.0, 700.0, 1000.0, 1500.0, 2000.0];
  List<double> walkingFeeRecommendations = [25.0, 30.0, 35.0, 40.0, 50.0];

  GoogleMapController? _mapController;
  Marker? _selectedMarker;


  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final List<String> _menuItems = ['Home', 'Products', 'About', 'Contact'];
  bool _noGstCheckbox = false;


  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _uploadedLogoUrl;

  int _selectedIndex = 0;
  int? _hoveredIndex;

  final List<String> _stepTitles = [
    "Basic Details",
    "Shop Information",
    "Bank Details",
    "PAN & GSTIN",
    "Dashboard Setup",
    "Partner Contract"
  ];

  Future<void> _downloadContract() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('boarders_partner_contract')
          .get();
      final pdfUrl = docSnap.data()?['contract_pdf'] as String?;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contract PDF not available')),
        );
        return;
      }
      final anchor = html.AnchorElement(href: pdfUrl)
        ..setAttribute('download', 'PartnerContract.pdf')
        ..target = '_blank';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download contract: $e')),
      );
    }
  }
  Future<void> updateBranchLinks(String newServiceId, String? parentServiceId) async {
    final firestore = FirebaseFirestore.instance;
    final boardingRef = firestore.collection('users-sp-boarding');

    print('🔧 Starting branch link update...');
    print('📌 Parent Service ID: $parentServiceId');
    print('📌 New Service ID: $newServiceId');

    // 0️⃣ Always create an empty array (merge) on the new doc
    final newDocRef = boardingRef.doc(newServiceId);
    await newDocRef.set({
      'other_branches': <String>[],
    }, SetOptions(merge: true));
    print('✅ Initialized other_branches to [] on new service');

    // 1️⃣ If parentServiceId is null or empty, bail out cleanly
    if (parentServiceId == null || parentServiceId.isEmpty) {
      print('⚠️ No parentServiceId provided; skipping linking steps.');
      return;
    }

    try {
      // 2️⃣ Fetch the parent doc
      final parentDocRef = boardingRef.doc(parentServiceId);
      final parentDoc = await parentDocRef.get();

      if (!parentDoc.exists) {
        print("⚠️ Parent doc not found; skipping parent & sibling updates.");
        return;
      }

      print('✅ Parent document found.');

      final otherBranchIds = List<String>.from(
        parentDoc.data()?['other_branches'] ?? [],
      );
      print('📎 Existing branches: $otherBranchIds');

      // 3️⃣ Link parent → new
      await newDocRef.update({
        'other_branches': FieldValue.arrayUnion([parentServiceId])
      });
      print('✅ Linked parentServiceId to new service');

      // 4️⃣ Link new → parent
      await parentDocRef.update({
        'other_branches': FieldValue.arrayUnion([newServiceId])
      });
      print('✅ Linked newServiceId to parent');

      // 5️⃣ Link new → each sibling
      for (final siblingId in otherBranchIds) {
        await boardingRef.doc(siblingId).update({
          'other_branches': FieldValue.arrayUnion([newServiceId])
        });
        print('✅ Linked newServiceId to sibling $siblingId');
      }

      print('🎉 Branch linking complete');
    } catch (e, st) {
      print('❌ updateBranchLinks failed but continuing: $e');
      print(st);
      // swallow errors so caller can still proceed
    }
  }



  // Call this to pick & upload the signed PDF
  Future<void> _pickContract() async {
    final input = html.FileUploadInputElement()..accept = 'application/pdf';
    input.click();
    input.onChange.listen((_) async {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final buffer = reader.result as ByteBuffer;
      final bytes = Uint8List.view(buffer);
      final ref = FirebaseStorage.instance
          .ref()
          .child('Boarders_Partner_Contract')
          .child('${DateTime.now().millisecondsSinceEpoch}.pdf');
      final snap = await ref.putData(
          bytes, SettableMetadata(contentType: 'application/pdf'));
      final url = await snap.ref.getDownloadURL();
      setState(() => _contractUrl = url);
    });
  }

  final List<String> _stepSubtitles = [
    "Name, Email & Phone Number",
    "Shop name, CIN & logo",
    "IFSC & Account number",
    "Shop name, CIN & logo",
    "Service Details",
    "Upload Signed Agreement"
  ];

  @override
  void initState() {
    super.initState(); // Always call this first

    // Now it's safe to initialize them
    apiKey = const String.fromEnvironment('PLACES_API_KEY');
    _places = PlacesService(apiKey);
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _shopNameCtrl.dispose();
    _cinCtrl.dispose();
    _ifscCtrl.dispose();
    _accountCtrl.dispose();
    _panCtrl.dispose();
    _gstinCtrl.dispose();
    for (var c in _dailyPriceCtrls.values) {
      c.dispose();
    }
    for (var c in _OfferdailyPriceCtrls.values) {
      c.dispose();
    }
    for (var c in _RefundCtrls.values) {
      c.dispose();
    }
    for (var c in _OfferMealPriceCtrls.values) {
      c.dispose();
    }
    for (var c in _OfferWalkingPriceCtrls.values) {
      c.dispose();
    }
    for (var c in _WalkingPriceCtrls.values) {
      c.dispose();
    }
    for (var c in _MealPriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadLogo() async {
    if (_imageBytes == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('company_logos')
        .child('${DateTime.now().millisecondsSinceEpoch}.png');
    final task =
    ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/png'));
    final snap = await task.whenComplete(() {});
    return await snap.ref.getDownloadURL();
  }
  Future<void> _createPayoutContact(String serviceId) async {
    final rawPhone = _phoneCtrl.text.trim();
    final contact  = rawPhone.startsWith('+91')
        ? rawPhone.substring(3)
        : rawPhone;

    final fnUrl = Uri.parse(
        'https://us-central1-petproject-test-g.cloudfunctions.net/createContactAndFundAccount'
    );

    final body = jsonEncode({
      'reference_id':   serviceId,
      'name':           _shopNameCtrl.text.trim(),
      'email':          _emailCtrl.text.trim(),
      'contact':        contact,
      'account_number': _accountCtrl.text.trim(),
      'ifsc':           _ifscCtrl.text.trim(),
      'type':        'vendor',         // optional
      'account_type':   'bank_account',
    });

    final resp = await http.post(
      fnUrl,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to create payout contact/fund-account: '
          '${resp.statusCode} ${resp.body}');
    }
  }

  String _formatRefundPolicyLabel(String key) {
    try {
      final parts = key.split('_');
      if (parts.length != 2) return key;

      String conditionText;
      switch (parts[0]) {
        case 'gt':
          conditionText = 'Cancellation Greater than (>)'; // Both word and symbol
          break;
        case 'lt':
          conditionText = 'Cancellation Less than (<)'; // Both word and symbol
          break;
        default:
          return key;
      }

      final hours = parts[1].replaceAll('h', '');
      return '$conditionText $hours hours prior';
    } catch (e) {
      return key;
    }
  }

  Future<void> _submitAllDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // 1️⃣ Upload shop logo (step 1)
      if (_imageBytes != null) {
        _uploadedLogoUrl = await _uploadLogo();
      }

      // 2️⃣ Upload service images (Dashboard Setup)
      List<String> imageUrls = [];
      for (var dataUrl in _imagePaths) {
        final base64Str = dataUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        final ref = FirebaseStorage.instance
            .ref()
            .child('service_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.png');
        final snap =
        await ref.putData(Uint8List.fromList(bytes)).whenComplete(() {});
        imageUrls.add(await snap.ref.getDownloadURL());
      }

      // 3️⃣ Parse geo‐point
      GeoPoint? geo;
      if (_coordController.text.isNotEmpty) {
        final parts =
        _coordController.text.split(',').map((s) => s.trim()).toList();
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) geo = GeoPoint(lat, lng);
      }

      // 4️⃣ Write to `users-sp-boarding`
      final collectionRef =
      FirebaseFirestore.instance.collection('users-sp-boarding');
      final docRef = collectionRef.doc(); // new doc ID

      final payload = {
        'type': widget.runType,
        'adminApproved': false,
        'isOfferActive': false,
        'mfp_certified': false,
        // ── STEP 0: owner
        'owner_name': _ownerNameCtrl.text.trim(),
        'notification_email': _emailCtrl.text.trim(),
        'owner_phone': _phoneCtrl.text.trim(),
        // ── STEP 1: shop
        'shop_name': _shopNameCtrl.text.trim(),
        'cin': _cinCtrl.text.trim(),
        'shop_logo': _uploadedLogoUrl ?? '',
        // ── STEP 2: bank
        'bank_ifsc': _ifscCtrl.text.trim(),
        'bank_account_num': _accountCtrl.text.trim(),
        // ── STEP 3: pan/gst
        'pan': _panCtrl.text.trim(),
        'gstin': _noGstCheckbox ? '' : _gstinCtrl.text.trim(),
        // ── STEP 4: Dashboard Setup
        'dashboard_phone': _phoneController.text.trim(),
        'dashboard_whatsapp': _whatsappController.text.trim(),
        'description': _descriptionController.text.trim(),
        'full_address': _locationController.text.trim(),
        "rates_daily": {
          for (var size in sizes) size: _dailyPriceCtrls[size]!.text.trim(),
        },
        "offer_daily_rates": {
          for (var size in sizes) size: _OfferdailyPriceCtrls[size]!.text.trim(),
        },
        "refund_policy": {
          for (var size in percentages) size: _RefundCtrls[size]!.text.trim(),
        },
        "offer_meal_rates": {
          for (var size in sizes) size: _OfferMealPriceCtrls[size]!.text.trim(),
        },
        "offer_walking_rates": {
          for (var size in sizes) size: _OfferWalkingPriceCtrls[size]!.text.trim(),
        },
        "walking_rates": {
          for (var size in sizes) size: _WalkingPriceCtrls[size]!.text.trim(),
        },
        "meal_rates": {
          for (var size in sizes) size: _MealPriceCtrls[size]!.text.trim(),
        },
        'walking_fee': _walkingController.text.trim(),
        'max_pets_allowed': _maxPetsController.text.trim(),
        'max_pets_allowed_per_hour':_maxPetsPerHourController.text.trim(),
        'open_time': _openTime?.format(context) ?? '',
        'close_time': _closeTime?.format(context) ?? '',
        // Location & address
        'location_geopoint': _coordController.text.trim(),
        'shop_location': _coordController.text.trim(),
        'street': _streetController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'area_name': _areaNameController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        // Employees & images & pets
        'employees': _employees,
        'image_urls': imageUrls,
        'pets': _selectedPets,
        'pet_types': _selectedPetTypes,
        // ── Partner contract
        'partner_contract_url': _contractUrl ?? '',
        // ── Metadata
        'service_id': docRef.id,
        'shop_user_id': widget.uid,
        'created_at': FieldValue.serverTimestamp(),
      };

      //  after you've successfully written the payload...
      // 4️⃣ Write to `users-sp-boarding`
      await docRef.set(payload);

      // 5️⃣ Create payout contact
      //  await _createPayoutContact(docRef.id);

      // 6️⃣ Link this branch with all the others
      // 6️⃣ Link this branch with all the others
      await updateBranchLinks(
        docRef.id,           // newly created branch
        widget.serviceId,    // main (parent) service ID passed into this page
      );

// 7️⃣ Create an employee record (Owner/Admin)
      // … after updateBranchLinks …

// 7️⃣ Create an employee record (Owner/Admin)
      final employeeAddress = [
        _streetController.text.trim(),
        _areaNameController.text.trim(),
        _districtController.text.trim(),
        _stateController.text.trim(),
        _postalCodeController.text.trim(),
        _coordController.text.trim(), // lat,lng
      ].where((s) => s.isNotEmpty).join(', ');

// Debug before we even call Firestore:
      debugPrint('🛠️ About to create employee for service ${docRef.id}');
      try {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(widget.uid)        // ← use the user’s uid as the document ID
            .set({
          'serviceId': docRef.id,
          'name': 'Admin',
          'phone': '+91 ${_phoneCtrl.text.trim()}',
          'email': _emailCtrl.text.trim(),
          'password': '',
          'address': employeeAddress,
          'jobTitle': 'Owner',
          'role': 'Owner',
          'photoUrl': '',
          'idProofUrl': '',
        });
        debugPrint('✅ Created employee doc with ID ${widget.uid}');
      } on FirebaseException catch (fe) {
        // Catches Firestore-specific errors
        debugPrint('🚨 Firestore error creating employee: [${fe.code}] ${fe.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save employee: ${fe.message}')),
        );
      } catch (e, st) {
        // Catches anything else
        debugPrint('❌ Unknown error creating employee: $e');
        debugPrint('$st');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save employee: $e')),
        );
      }
      debugPrint('🔚 Employee creation block complete');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All details submitted successfully!')),
      );

      final serviceId = docRef.id;

// 🚀 REPLACING context.go('/partner/${docRef.id}')
// Navigate and clear the stack, ensuring the user lands on the main dashboard.
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PartnerShell(
              serviceId: serviceId,
              currentPage: PartnerPage.profile, // Directing to the main profile page (Overview)
              // The page corresponding to the root /partner/:serviceId route is the loader
              child: BoardingDetailsLoader(serviceId: serviceId),
            ),
          ),
              (Route<dynamic> route) => false, // Clears the history
        );
      }

    } catch (e) {
      setState(() => _errorText = 'Submission error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget _buildFancyStepIndicator() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_stepTitles.length, (i) {
            final isCompleted = i < _currentStep;
            final isActive = i == _currentStep;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _currentStep = i),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isActive ? 20 : 12,
                        height: isActive ? 20 : 12,
                        decoration: BoxDecoration(
                          color: (isCompleted || isActive)
                              ? primary
                              : Colors.grey.shade300,
                          shape: BoxShape.circle,
                          border: isActive
                              ? Border.all(color: primary, width: 2)
                              : null,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stepTitles[i],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                              color: (isCompleted || isActive)
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _stepSubtitles[i],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < _stepTitles.length - 1)
                  Container(
                    margin: EdgeInsets.only(
                        left: isActive ? 9 : 5, top: 8, bottom: 8),
                    width: 2,
                    height: 40,
                    color: isCompleted ? primary : Colors.grey.shade300,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              SizedBox(height: 8),
            ],
            _buildSectionContainer(
              title: "Basic Details",
              children: [
                TextFormField(
                  controller: _ownerNameCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Owner’s Name*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                // add this:
                SizedBox(height: 4),
                Text(
                  "Name of the authorised owner of the business",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _emailCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Owner's Email*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Required";
                    if (!v.contains("@")) return "Invalid";
                    return null;
                  },
                ),
                SizedBox(height: 4),
                Text(
                  "Email address where we’ll send notifications and updates",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _phoneCtrl,
                            style: GoogleFonts.poppins(),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              prefix:
                              Text('+91 ', style: GoogleFonts.poppins()),
                              hintText: "Phone*",
                              hintStyle: GoogleFonts.poppins(),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return "Required";
                              if (v.trim().length != 10)
                                return "Enter exactly 10 digits";
                              return null;
                            },
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Business contact (10-digit local number)",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextFormField(
                            controller: _whatsappController,
                            label: 'Whatsapp Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.number,
                            maxLines: 1,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (val.length != 10)
                                return 'Must be exactly 10 digits';
                              return null;
                            },
                          ),
                          SizedBox(height: 4),
                          Text(
                            "WhatsApp updates (10-digit local number)",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ],
        );

      case 1:
        return Column(
          children: [
            _buildSectionContainer(
              title: "Shop Information",
              children: [
                // Shop Name field
                TextFormField(
                  controller: _shopNameCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Shop Name*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                SizedBox(height: 4),
                Text(
                  "Legal name of your business as registered",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12),

                // CIN field
                TextFormField(
                  controller: _cinCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "CIN*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                SizedBox(height: 4),
                Text(
                  "Corporate Identification Number from company records",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12),

                // Shop Logo upload
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                      Image.memory(_imageBytes!, fit: BoxFit.cover),
                    )
                        : Icon(Icons.upload_file, size: 40, color: Colors.grey),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Tap to upload your shop’s logo (PNG or JPEG)",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 12),
              ],
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            _buildSectionContainer(
              title: "Bank Details",
              subtitle: "Where we’ll transfer your earnings",
              children: [
                // IFSC field
                TextFormField(
                  controller: _ifscCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Bank IFSC*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                SizedBox(height: 4),
                Text(
                  "Enter your Bank IFSC code",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 12),

                // Account Number field
                TextFormField(
                  controller: _accountCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "Account Number*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                SizedBox(height: 4),
                Text(
                  "Your bank account number",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 12),

                // …any other children…
              ],
            ),
          ],
        );

      case 3:
        return Column(
          children: [
            _buildSectionContainer(
              title: "PAN & GSTIN",
              children: [
                // PAN field
                TextFormField(
                  controller: _panCtrl,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "PAN*",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? "Required" : null,
                ),
                SizedBox(height: 4),
                Text(
                  "10-character alphanumeric PAN as per Income Tax Dept.",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 12),

                // GSTIN field
                TextFormField(
                  controller: _gstinCtrl,
                  enabled: !_noGstCheckbox,
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: "GSTIN",
                    hintStyle: GoogleFonts.poppins(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_noGstCheckbox) return null;
                    if (v == null || v.trim().isEmpty) return "Required";
                    return null;
                  },
                ),
                SizedBox(height: 4),
                Text(
                  "15-digit GSTIN if registered (leave blank if none)",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),

                // No-GST checkbox
                CheckboxListTile(
                  title: Text("I don’t have a GSTIN",
                      style: GoogleFonts.poppins()),
                  value: _noGstCheckbox,
                  onChanged: (b) => setState(() {
                    _noGstCheckbox = b ?? false;
                    if (_noGstCheckbox) _gstinCtrl.clear();
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ],
        );

      case 4: // Dashboard Setup
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextFormField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 4,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            SizedBox(height: 4),
            Text(
              "Brief overview of your boarding service",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),

            // Location picker
            _buildAddressSearchField(),

            SizedBox(height: 16),
            // Map preview
            Container(
              height: 500,
              width: 800,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(20.5937, 78.9629),
                  zoom: 5,
                ),
                onTap: _onMapTap,
                markers: _selectedMarker != null ? {_selectedMarker!} : {},
                onMapCreated: (c) => _mapController = c,
              ),
            ),
            SizedBox(height: 12),
            // Coordinates & Street (same row)
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _coordController,
                    label: 'Coordinates (lat, lng)',
                    icon: Icons.location_on,
                    readOnly: true,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.my_location, color: primary),
                      onPressed: _getCurrentLocationAndPin,
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _streetController,
                    label: 'Street',
                    icon: Icons.streetview,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Area & District (same row)
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _areaNameController,
                    label: 'Area',
                    icon: Icons.location_city,
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _districtController,
                    label: 'District',
                    icon: Icons.map,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // State & Postal Code (same row)
            Row(
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.flag,
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    icon: Icons.local_post_office,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Rates',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _dailyPriceCtrls[size]!,
                    label: '$size (₹/day)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
                SizedBox(height: 16),
                Text('Walking Fee', style: headerStyle),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _WalkingPriceCtrls[size]!,
                    label: '$size (₹/hr)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
                SizedBox(height: 16),
                Text('Meals Fee', style: headerStyle),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _MealPriceCtrls[size]!,
                    label: '$size (₹/hr)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer Daily Rates',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _OfferdailyPriceCtrls[size]!,
                    label: '$size (₹/day)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
                SizedBox(height: 16),
                Text('Offer Walking Fee', style: headerStyle),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _OfferWalkingPriceCtrls[size]!,
                    label: '$size (₹/hr)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
                SizedBox(height: 16),
                Text('Offer Meals Fee', style: headerStyle),
                ...sizes.map((size) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildTextFormField(
                    controller: _OfferMealPriceCtrls[size]!,
                    label: '$size (₹/hr)',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter $size rate';
                      if (double.tryParse(val) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                )),
              ],
            ),
            Text(
              'Refund Policy',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ...percentages.map((key) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildTextFormField(
                controller: _RefundCtrls[key]!,
                // This is the change to show a clean label
                label: '${_formatRefundPolicyLabel(key)} (% refund)',
                icon: Icons.percent,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter percentage';
                  final numValue = double.tryParse(val);
                  if (numValue == null) return 'Must be a number';
                  if (numValue < 0 || numValue > 100) return 'Must be 0-100';
                  return null;
                },
              ),
            )),
            SizedBox(height: 4),
            Text(
              "Additional fee for daily walks (if offered)",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 12),

            // Max Pets Allowed
            _buildTextFormField(
              controller: _maxPetsController,
              label: 'Maximum pets allowed/Day',
              icon: Icons.pets,
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a number';
                }
                if (int.tryParse(val) == null) {
                  return 'Enter a valid integer';
                }
                return null;
              },
            ),
            Text(
              "Max number of pets you can board in a day",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            _buildTextFormField(
              controller: _maxPetsPerHourController,
              label: 'Maximum pets allowed/Hour',
              icon: Icons.pets,
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter a number';
                }
                if (int.tryParse(val) == null) {
                  return 'Enter a valid integer';
                }
                return null;
              },
            ),
            SizedBox(height: 4),
            Text(
              "Max number of pets you can board in 1 Hour",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),

            // Open / Close times
            // Open / Close times in a row
            Row(
              children: [
                Expanded(
                  child: _buildTimePicker(
                    'Open Time',
                    _openTime,
                        (picked) => setState(() => _openTime = picked),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTimePicker(
                    'Close Time',
                    _closeTime,
                        (picked) => setState(() => _closeTime = picked),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Employees & Images
            _buildImagePicker(),
            SizedBox(height: 16),

            _buildPetSelection(),
          ],
        );

      case 5: // Partner Contract
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.picture_as_pdf, color: Colors.red),
              label: Text(
                'Download Contract',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red),
                ),
              ),
              onPressed: _downloadContract,
            ),
            SizedBox(height: 8),
            Text(
              'Instructions: Take printout, fill details & sign, then upload scanned copy below.',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(
                Icons.upload_file,
                color: Colors.white,
              ),
              label: Text(
                'Upload Signed Contract',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _pickContract,
            ),
            if (_contractUrl != null) ...[
              SizedBox(height: 8),
              Text(
                'Uploaded URL:',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                _contractUrl!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ],
        );

      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon, color: primary),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  /*Widget _buildPriceRecommendations() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommended Prices:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: priceRecommendations.map((price) {
              return ChoiceChip(
                label: Text('₹${price.toStringAsFixed(0)}'),
                selected: _priceController.text == price.toString(),
                onSelected: (_) {
                  setState(() {
                    _priceController.text = price.toString();
                  });
                },
                selectedColor: Colors.blueAccent,
                backgroundColor: Colors.grey[200],
              );
            }).toList(),
          ),
        ],
      );
    }*/

  Widget _buildTimePicker(
      String label,
      TimeOfDay? selectedTime,
      ValueChanged<TimeOfDay?> onTimeSelected,
      ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        selectedTime != null ? selectedTime.format(context) : 'Select $label',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Icon(Icons.access_time, color: primary),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
          builder: (ctx, child) {
            return Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primary.withOpacity(0.15), // header background
                  onPrimary: Colors.white, // header text & icons
                  onSurface: Colors.black, // dialog text (numbers & labels)
                ),
                timePickerTheme: TimePickerThemeData(
                  dialHandColor: primary, // the hand
                  dialBackgroundColor: Colors.white, // keep white background
                  dialTextColor: Colors.black, // ensure numbers stay black
                  hourMinuteTextColor: primary, // selected numbers
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: primary),
                ),
                textTheme: TextTheme(
                  titleMedium: GoogleFonts.poppins(), // dialog labels
                  headlineMedium: GoogleFonts.poppins(), // big numbers
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onTimeSelected(picked);
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images:',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        _imagePaths.isEmpty
            ? Text(
          'No images selected.',
          style: GoogleFonts.poppins(
              fontSize: 14, color: Colors.grey.shade600),
        )
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _imagePaths.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(path,
                      width: 100, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _imagePaths.removeAt(index);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          icon: Icon(Icons.add_a_photo, color: Colors.white),
          label: Text(
            'Add Images',
            style:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _pickImages,
        ),
      ],
    );
  }

  /// 1. When user taps the map, place a marker and reverse-geocode:
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedMarker = Marker(
        markerId: MarkerId('chosen'),
        position: position,
      );
      _coordController.text = '${position.latitude}, ${position.longitude}';
    });
    _reverseGeocode(position.latitude, position.longitude);
  }

  /// 2. Call the JS wrapper (reverseGeocodeJs) defined in index.html:
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      // Call the JS function reverseGeocodeJs(lat, lng) as a Promise
      final jsResult = await js_util.promiseToFuture(
        js_util.callMethod(
          html.window,
          'reverseGeocodeJs',
          [lat.toString(), lng.toString()],
        ),
      );

      // Extract all five properties from the JS result:
      final street = js_util.getProperty(jsResult, 'street') as String;
      final postalCode = js_util.getProperty(jsResult, 'postalCode') as String;
      final area = js_util.getProperty(jsResult, 'area') as String;
      final district = js_util.getProperty(jsResult, 'district') as String;
      final state = js_util.getProperty(jsResult, 'state') as String;

      setState(() {
        _streetController.text = street;
        _postalCodeController.text = postalCode;
        _areaNameController.text = area;
        _districtController.text = district;
        _stateController.text = state;
      });
    } catch (e) {
      print('Reverse‐geocode JS error: $e');
    }
  }

  /// 3. “Use Current Location” button to center map & fill lat/lng:
  Future<void> _getCurrentLocationAndPin() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final latLng = LatLng(pos.latitude, pos.longitude);

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(latLng),
    );
    _onMapTap(latLng);
  }

  Widget _buildAddressSearchField() {
    return TypeAheadFormField<AutocompletePrediction>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _locationController,
        decoration: InputDecoration(
          labelText: 'Search address',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
      ),
      suggestionsCallback: (pattern) =>
      pattern.isEmpty ? [] : _places.autocomplete(pattern),
      itemBuilder: (ctx, pred) =>
          ListTile(title: Text(pred.description)),
      onSuggestionSelected: (pred) async {
        // 1️⃣ Show the human-readable address in the search field
        _coordController.text = pred.description;

        // 2️⃣ Fetch the latitude/longitude for the selected place
        LatLng coord;
        try {
          coord = await _places.getPlaceLocation(pred.placeId);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching location: $e')),
          );
          return;
        }

        // 3️⃣ Update marker and animate the camera
        setState(() {
          _selectedLatLng = coord;
          _selectedMarker = Marker(
            markerId: MarkerId('selected-place'),
            position: coord,
          );
          // Put the raw lat,lng into the separate coordinates field
          _coordController.text = '${coord.latitude}, ${coord.longitude}';
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(coord, 15),
        );

        // 4️⃣ Autofill street, area, district, state, and postal code
        try {
          final jsResult = await js_util.promiseToFuture(
            js_util.callMethod(
              html.window,
              'reverseGeocodeJs',
              [coord.latitude.toString(), coord.longitude.toString()],
            ),
          );
          setState(() {
            _streetController.text   = js_util.getProperty(jsResult, 'street') as String;
            _areaNameController.text     = js_util.getProperty(jsResult, 'area') as String;
            _districtController.text = js_util.getProperty(jsResult, 'district') as String;
            _stateController.text    = js_util.getProperty(jsResult, 'state') as String;
            _postalCodeController.text   = js_util.getProperty(jsResult, 'postalCode') as String;
          });
        } catch (e) {
          print('Reverse-geocode failed: $e');
        }

        // 5️⃣ Reset the Places session token
        _places.resetSession();
      },


      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _pickImages() async {
    try {
      final fileInput = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = true;
      fileInput.click();
      fileInput.onChange.listen((_) {
        final files = fileInput.files;
        if (files == null) return;

        if (_imagePaths.length + files.length > 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can select up to 5 images only')),
          );
          return;
        }

        for (final file in files) {
          final reader = html.FileReader();
          reader.onLoadEnd.listen((_) {
            final dataUrl = reader.result as String?;
            if (dataUrl != null) {
              setState(() {
                _imagePaths.add(dataUrl);
              });
            }
          });
          reader.readAsDataUrl(file);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  Widget _buildPetSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Pets",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        MultiSelectDialogField<String>(
          items: _petOptions
              .map((pet) => MultiSelectItem<String>(pet, pet))
              .toList(),
          dialogWidth: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          buttonIcon: Icon(Icons.pets, color: primary),
          buttonText: Text(
            "Choose Pets",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: primary,
            ),
          ),
          title: Text(
            "Pets",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          selectedColor: primary,
          confirmText: Text(
            "OK",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          cancelText: Text(
            "CANCEL",
            style:
            GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          ),
          chipDisplay: MultiSelectChipDisplay(
            chipColor: primary.withOpacity(0.2),
            textStyle: GoogleFonts.poppins(fontSize: 14, color: primary),
            onTap: (value) {
              setState(() {
                _selectedPets.remove(value);
              });
            },
          ),
          onConfirm: (values) {
            setState(() {
              _selectedPets = List<String>.from(values);
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sidebar with step indicator
                    Container(
                      width: 280,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back,
                                    size: 16, color: primary),
                                SizedBox(width: 4),
                                Text(
                                  "Back",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: primary),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          // Constrain the indicator to remaining space so it scrolls instead of overflowing
                          Expanded(
                            child: _buildFancyStepIndicator(),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 24),

                    // ── Main form pane
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _stepTitles[_currentStep],
                                style: GoogleFonts.poppins(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _stepSubtitles[_currentStep],
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.grey.shade600),
                              ),
                              SizedBox(height: 24),

                              // dynamic step content
                              Flexible(
                                child: SingleChildScrollView(
                                  child: _buildCurrentStepContent(),
                                ),
                              ),

                              SizedBox(height: 24),

                              // navigation buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_currentStep > 0)
                                    Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 14, horizontal: 24),
                                          textStyle: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(8)),
                                        ),
                                        onPressed: _isSubmitting
                                            ? null
                                            : () =>
                                            setState(() => _currentStep--),
                                        child: Text("Back"),
                                      ),
                                    ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 24),
                                      textStyle: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () async {
                                      if (!_formKey.currentState!
                                          .validate()) return;
                                      if (_currentStep ==
                                          _stepTitles.length - 1) {
                                        await _submitAllDetails();
                                      } else {
                                        setState(() => _currentStep++);
                                      }
                                    },
                                    child: _isSubmitting
                                        ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                        : Text(_currentStep ==
                                        _stepTitles.length - 1
                                        ? "Complete Profile"
                                        : "Next"),
                                  ),
                                ],
                              ),
                            ],
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
    );
  }

  Widget _buildSectionContainer({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
