import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/chip_display/multi_select_chip_display.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';

// Assuming these are defined globally or imported from your theme files
// Placeholder imports for classes assumed to exist in the user's original project
import '../../Colors/AppColor.dart';
import '../../Colors/AppColor.dart' as RunTypeSelectionPage;
import '../../services/places_service.dart';
import '../../tools/webcam_selfie_widget.dart';
import 'package:provider/provider.dart';

// --- UTILITY CLASSES (Reused) ---

class Debouncer {
  final int milliseconds;
  Timer? _timer;
  Debouncer({required this.milliseconds});
  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class FileUploadData {
  final Uint8List bytes;
  final String name;
  final String type; // 'image' or 'pdf'
  FileUploadData({required this.bytes, required this.name, required this.type});
}

// --- MAIN CLASS (Renamed) ---

class PetStoreOnboardingPage extends StatefulWidget {
  final String uid;
  final String phone;
  final String email;
  final String runType; // e.g., 'Pet Store'
  final String serviceId;

  const PetStoreOnboardingPage({
    Key? key,
    required this.uid,
    required this.phone,
    required this.runType,
    required this.serviceId,
    required this.email,
  }) : super(key: key);

  @override
  _PetStoreOnboardingPageState createState() => _PetStoreOnboardingPageState();
}

class _PetStoreOnboardingPageState extends State<PetStoreOnboardingPage> {
  // --- STATE VARIABLES ---

  // Validation & Debounce
  final _phoneDebouncer = Debouncer(milliseconds: 500);
  String _returnWindowUnit = 'Days';
  final _shopNameDebouncer = Debouncer(milliseconds: 500);
  final _whatsappDebouncer = Debouncer(milliseconds: 500);
  final _emailDebouncer = Debouncer(milliseconds: 500);

  String? _emailErrorText;
  bool _isCheckingEmail = false;
  bool _hasAgreedToTestament = false;


  String? _phoneErrorText;
  String? _dashboardWhatsappErrorText;
  String? _shopNameErrorText;
  bool _isCheckingShopName = false;
  int _highestStepReached = 0;
  bool _isWhatsappSameAsPhone = false;
  String? _generatedDocIdForSubmission;

  // OTP State (Used for verification rigor)
  final TextEditingController _emailOtpCtrl = TextEditingController();
  final TextEditingController _phoneOtpCtrl = TextEditingController();
  final TextEditingController _whatsappOtpCtrl = TextEditingController();
  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _whatsappVerified = false;
  Timer? _resendTimer;
  Timer? _phoneResendTimer;
  Timer? _whatsappResendTimer;
  int _resendCooldown = 60;
  int _phoneResendCooldown = 60;
  int _whatsappResendCooldown = 60;

  // Documents/Policy
  FileUploadData? _idFrontFile;
  FileUploadData? _utilityBillFile;
  FileUploadData? _idWithSelfieFile;
  FileUploadData? _policyPdfFile;
  String? _defaultPolicyUrl;
  bool _useDefaultPolicy = false;
  String _testamentText = "Loading declaration...";
  bool _isTestamentLoading = true;
  String _checkboxLabelText = "I confirm the details are accurate and agree to the terms.";
  bool _isCheckingPhone = false;
  bool _isCheckingWhatsappPhone = false;

  // Location
  late final String apiKey;
  late final PlacesService _places;
  LatLng? _selectedLatLng;
  Marker? _selectedMarker;
  GoogleMapController? _mapController;

  // Images
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  List<String> _imagePaths = []; // Storefront images base64 data

  // Store Specialties/Categories
  List<String> _selectedPetTypes = [];
  List<String> _selectedCategories = [];
  List<String> _selectedPaymentModes = [];
  List<String> _serviceCategories = [];
  List<String> _modesOfPayment = [];
  List<String> _petTypes = [];
  List<String> daysOfWeek = [];
  Map<String, TimeOfDay?> _dailyOpenTimes = {};
  Map<String, TimeOfDay?> _dailyCloseTimes = {};


  // --- CONTROLLERS ---
  final TextEditingController _ownerNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _ifscCtrl = TextEditingController();
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _panCtrl = TextEditingController();
  final TextEditingController _gstinCtrl = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _coordController = TextEditingController();
  final TextEditingController _areaNameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  // Retail-Specific Controllers
  final TextEditingController _fulfillmentTimeCtrl = TextEditingController();
  final TextEditingController _deliveryRadiusCtrl = TextEditingController();
  final TextEditingController _minOrderValueCtrl = TextEditingController();
  final TextEditingController _flatDeliveryFeeCtrl = TextEditingController();
  final TextEditingController _supportEmailCtrl = TextEditingController();
  final TextEditingController _returnDaysCtrl = TextEditingController();
  final TextEditingController _returnPolicyCtrl = TextEditingController();
  final TextEditingController _specialtyCtrl = TextEditingController();


  bool _isSendingEmailOtp = false;
  bool _isVerifyingEmailOtp = false;
  bool _emailOtpSent = false;
  bool _isSendingPhoneOtp = false;
  bool _isVerifyingPhoneOtp = false;
  bool _phoneOtpSent = false;
  bool _isSendingWhatsappOtp = false;
  bool _isVerifyingWhatsappOtp = false;
  bool _whatsappOtpSent = false;
  final TextEditingController _returnWindowCtrl = TextEditingController();


  // Internal State
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  final TextStyle headerStyle = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor);
  String? _errorText;

  // Step Titles (Modified for Retail)
  final List<String> _stepTitles = ["Basic Details", "Brand Info", "Store Info, Logistics & Policy", "Review & Confirm"];
  final List<String> _stepSubtitles = ["Owner's name, email & phone", "Brand name and logo", "Products, specialty, Location, hours & delivery setup", "Final review and submission"];

  // --- INITIALIZATION ---

  @override
  void initState() {
    super.initState();
    _fetchDefaultPolicyUrl();
    _fetchTestamentText();
    _fetchDropdownSettings(); // 🔥 new

    // Initialize Daily Time Maps
    for (var day in daysOfWeek) {
      _dailyOpenTimes[day] = null;
      _dailyCloseTimes[day] = null;
    }
    apiKey = const String.fromEnvironment('PLACES_API_KEY', defaultValue: '');
    _places = PlacesService(apiKey);
  }

  Future<void> _fetchDropdownSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('dropdowns')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _serviceCategories =
          List<String>.from(data['serviceCategories'] ?? []);
          _modesOfPayment =
          List<String>.from(data['modesOfPayment'] ?? []);
          _petTypes = List<String>.from(data['petTypes'] ?? []);
          daysOfWeek = List<String>.from(data['daysOfWeek'] ?? []);
        });

        // Re-initialize daily hours map
        for (var day in daysOfWeek) {
          _dailyOpenTimes[day] = null;
          _dailyCloseTimes[day] = null;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching dropdown settings: $e');
    }
  }


  @override
  void dispose() {
    // Dispose all controllers and timers
    _emailOtpCtrl.dispose(); _phoneOtpCtrl.dispose(); _whatsappOtpCtrl.dispose();
    _resendTimer?.cancel(); _phoneResendTimer?.cancel(); _whatsappResendTimer?.cancel();
    _ownerNameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _shopNameCtrl.dispose(); _ifscCtrl.dispose(); _accountCtrl.dispose();
    _panCtrl.dispose(); _gstinCtrl.dispose(); _whatsappController.dispose();
    _descriptionController.dispose(); _locationController.dispose(); _coordController.dispose();
    _areaNameController.dispose(); _districtController.dispose(); _stateController.dispose();
    _streetController.dispose(); _postalCodeController.dispose();
    _fulfillmentTimeCtrl.dispose(); _deliveryRadiusCtrl.dispose(); _minOrderValueCtrl.dispose();
    _flatDeliveryFeeCtrl.dispose(); _supportEmailCtrl.dispose(); _returnDaysCtrl.dispose();
    _returnPolicyCtrl.dispose(); _specialtyCtrl.dispose();
    super.dispose();
  }

  // --- AUTH/VALIDATION METHODS (Reused/Modified) ---

  Future<void> _fetchDefaultPolicyUrl() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('default_content')
          .get();

      if (doc.exists && doc.data() != null) {
        if(mounted) {
          setState(() {
            _defaultPolicyUrl = doc.data()!['store_terms_n_conditions'] as String?;
            _isTestamentLoading = false;
          });
        }
      } else {
        if(mounted) setState(() => _isTestamentLoading = false);
      }
    } catch (e) {
      print('Error fetching default policy URL: $e');
      if(mounted) setState(() => _isTestamentLoading = false);
    }
  }

  Future<void> _fetchTestamentText() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('testaments')
          .get();

      if (doc.exists && doc.data() != null) {
        if(mounted) {
          setState(() {
            _testamentText = doc.data()!['pet_store'] as String? ?? 'Declaration not available.';
            _checkboxLabelText = doc.data()!['pet_store_checkbox_label'] as String? ?? 'I confirm the details are accurate and agree to the terms.';
            _isTestamentLoading = false;
          });
        }
      } else {
        if(mounted) {
          setState(() {
            _testamentText = 'Declaration not found.';
            _isTestamentLoading = false;
          });
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          _testamentText = 'Error loading declaration.';
          _isTestamentLoading = false;
        });
      }
    }
  }

  void _resetEmailVerification() {
    _resendTimer?.cancel();
    if(mounted) {
      setState(() {
        _emailOtpSent = false;
        _emailVerified = false;
        _emailOtpCtrl.clear();
        _emailErrorText = null;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    if(mounted) setState(() => _resendCooldown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted) {
        if (_resendCooldown > 0) {
          setState(() => _resendCooldown--);
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startPhoneResendTimer() {
    _phoneResendTimer?.cancel();
    if(mounted) setState(() => _phoneResendCooldown = 60);
    _phoneResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted) {
        if (_phoneResendCooldown > 0) {
          setState(() => _phoneResendCooldown--);
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startWhatsappResendTimer() {
    _whatsappResendTimer?.cancel();
    if(mounted) setState(() => _whatsappResendCooldown = 60);
    _whatsappResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted) {
        if (_whatsappResendCooldown > 0) {
          setState(() => _whatsappResendCooldown--);
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendEmailOtp() async {
    // Basic validation
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendPetStoreEmailVerificationCode');
      _generatedDocIdForSubmission ??= FirebaseFirestore.instance.collection('users-sp-store').doc().id;
      // 💡 ADD THIS PRINT STATEMENT
      print('OTP Send Request: Doc ID is $_generatedDocIdForSubmission, Email is ${_emailCtrl.text.trim()}');
      final result = await callable.call({
        'email': _emailCtrl.text.trim(),
        'docId': _generatedDocIdForSubmission,
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _emailOtpSent = true; // Use this to lock the field and show OTP input
          _startResendTimer();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    if (_emailOtpCtrl.text.trim().length != 6) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit code.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('verifyPetStoreEmailCode');
      final result = await callable.call({'code': _emailOtpCtrl.text.trim(), 'docId': _generatedDocIdForSubmission});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _emailVerified = true;
          _resendTimer?.cancel();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    if (_phoneCtrl.text.trim().length != 10) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit phone number.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendTestSms');
      _generatedDocIdForSubmission ??= FirebaseFirestore.instance.collection('users-sp-store').doc().id;
      final result = await callable.call({'phoneNumber': '+91${_phoneCtrl.text.trim()}', 'docId': _generatedDocIdForSubmission,});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _phoneOtpSent = true;
          _startPhoneResendTimer();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    if (_phoneOtpCtrl.text.trim().length != 6) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit code.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyTestSmsCode');
      final result = await callable.call({'code': _phoneOtpCtrl.text.trim(), 'docId': _generatedDocIdForSubmission,});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _phoneVerified = true;
          _phoneResendTimer?.cancel();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendWhatsappOtp() async {
    if (_whatsappController.text.trim().length != 10) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit Service Contact Number.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendTestSms');
      _generatedDocIdForSubmission ??= FirebaseFirestore.instance.collection('users-sp-store').doc().id;
      final result = await callable.call({'phoneNumber': '+91${_whatsappController.text.trim()}', 'docId': _generatedDocIdForSubmission, 'verificationType': 'whatsapp',});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _whatsappOtpSent = true;
          _startWhatsappResendTimer();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyWhatsappOtp() async {
    if (_whatsappOtpCtrl.text.trim().length != 6) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit code.'), backgroundColor: errorColor));
      return;
    }
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyTestSmsCode');
      final result = await callable.call({'code': _whatsappOtpCtrl.text.trim(), 'docId': _generatedDocIdForSubmission,});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: successColor));
      if(mounted) {
        setState(() {
          _whatsappVerified = true;
          _whatsappResendTimer?.cancel();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'An unknown error occurred.'), backgroundColor: errorColor));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  // ⭐️ MODIFIED: Check against the new 'users-sp-store' collection
  Future<void> _validateShopName(String name, String type) async {
    if (name.trim().isEmpty) { if (mounted) setState(() => _shopNameErrorText = null); return; }
    setState(() { _isCheckingShopName = true; _shopNameErrorText = null; });
    final normalizedName = name.trim().toLowerCase();
    final query = await FirebaseFirestore.instance
        .collection('users-sp-store') // ⭐️ UPDATED COLLECTION
        .where('shop_name_lowercase', isEqualTo: normalizedName)
        .limit(1)
        .get();
    if (!mounted) return;
    setState(() {
      _shopNameErrorText = query.docs.isNotEmpty ? 'This brand name is already in use.' : null;
      _isCheckingShopName = false;
    });
  }

  // ⭐️ MODIFIED: Check against the new 'users-sp-store' collection
  Future<String?> _checkForDuplicates() async {
    final collection = FirebaseFirestore.instance.collection('users-sp-store'); // ⭐️ UPDATED COLLECTION
    final phoneQuery = await collection.where('owner_phone', whereIn: [_phoneCtrl.text.trim(), '+91${_phoneCtrl.text.trim()}']).limit(1).get();
    if (phoneQuery.docs.isNotEmpty) return 'This phone number is already registered.';
    final emailQuery = await collection.where('login_email', isEqualTo: _emailCtrl.text.trim()).limit(1).get();
    if (emailQuery.docs.isNotEmpty) return 'This email address is already registered.';
    final panQuery = await collection.where('pan', isEqualTo: _panCtrl.text.trim()).limit(1).get();
    if (panQuery.docs.isNotEmpty) return 'This PAN number is already registered.';
    return null;
  }

  // --- DOCUMENT & IMAGE HANDLING (Reused) ---
  Future<void> _pickFile(void Function(FileUploadData) onFilePicked) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'pdf']);
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final fileType = ['jpg', 'png'].contains(file.extension?.toLowerCase()) ? 'image' : 'pdf';
      if(mounted) setState(() => onFilePicked(FileUploadData(bytes: file.bytes!, name: file.name, type: fileType)));
    }
  }
  Future<void> _pickPdfFile(void Function(FileUploadData) onFilePicked) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      if(mounted) setState(() => onFilePicked(FileUploadData(bytes: file.bytes!, name: file.name, type: 'pdf')));
    }
  }
  Future<String?> _uploadFile(FileUploadData? fileData, String storagePath) async {
    if (fileData == null) return null;
    final metadata = SettableMetadata(contentType: fileData.type == 'pdf' ? 'application/pdf' : 'image/jpeg');
    final ref = FirebaseStorage.instance.ref().child(storagePath).child(fileData.name);
    return await (await ref.putData(fileData.bytes, metadata)).ref.getDownloadURL();
  }
  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if(mounted) setState(() => _imageBytes = bytes);
    }
  }
  Future<String?> _uploadImage(Uint8List? bytes, String storagePath) async {
    if (bytes == null) return null;
    final ref = FirebaseStorage.instance.ref().child(storagePath).child('${DateTime.now().millisecondsSinceEpoch}.png');
    return await (await ref.putData(bytes, SettableMetadata(contentType: 'image/png'))).ref.getDownloadURL();
  }

  // --- LOCATION HANDLING (Reused) ---
  void _onMapTap(LatLng position) {
    if(mounted) setState(() { _selectedMarker = Marker(markerId: const MarkerId('chosen'), position: position); _coordController.text = '${position.latitude}, ${position.longitude}'; });
    _reverseGeocode(position.latitude, position.longitude);
  }
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final jsResult = await js_util.promiseToFuture(js_util.callMethod(html.window, 'reverseGeocodeJs', [lat.toString(), lng.toString()]));
      if(mounted) {
        setState(() {
          _streetController.text = js_util.getProperty(jsResult, 'street');
          _postalCodeController.text = js_util.getProperty(jsResult, 'postalCode');
          _areaNameController.text = js_util.getProperty(jsResult, 'area');
          _districtController.text = js_util.getProperty(jsResult, 'district');
          _stateController.text = js_util.getProperty(jsResult, 'state');
        });
      }
    } catch (e) { print('Reverse‐geocode JS error: $e'); }
  }
  Widget _buildAddressSearchField() {
    return TypeAheadFormField<AutocompletePrediction>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _locationController, style: GoogleFonts.poppins(fontSize: 14, color: textColor),
        decoration: InputDecoration(
          labelText: 'Search & Select Full Address*', labelStyle: GoogleFonts.poppins(color: subtleTextColor),
          prefixIcon: const Icon(Icons.search, color: subtleTextColor), filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
        ),
      ),
      suggestionsCallback: (pattern) => pattern.isEmpty ? Future.value([]) : _places.autocomplete(pattern),
      itemBuilder: (ctx, pred) => ListTile(title: Text(pred.description, style: GoogleFonts.poppins())),
      onSuggestionSelected: (pred) async {
        _locationController.text = pred.description;
        try {
          final coord = await _places.getPlaceLocation(pred.placeId);
          if(mounted) setState(() { _selectedMarker = Marker(markerId: const MarkerId('selected-place'), position: coord); _coordController.text = '${coord.latitude}, ${coord.longitude}'; });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(coord, 15));
          await _reverseGeocode(coord.latitude, coord.longitude);
        } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching location: $e'))); }
        _places.resetSession();
      },
      validator: (v) => v == null || v.isEmpty ? 'Please select an address' : null,
    );
  }
  Future<void> _pickImages() async {
    try {
      final fileInput = html.FileUploadInputElement()..accept = 'image/*'..multiple = true;
      fileInput.click();
      fileInput.onChange.listen((_) {
        final files = fileInput.files;
        if (files == null) return;
        // Limit to 5 images total
        if (_imagePaths.length + files.length > 5) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can select up to 5 images only')));
          return;
        }
        for (final file in files) {
          final reader = html.FileReader();
          reader.onLoadEnd.listen((_) {
            if (reader.result != null) {
              if(mounted) setState(() => _imagePaths.add(reader.result as String));
            }
          });
          reader.readAsDataUrl(file);
        }
      });
    } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick images: $e'))); }
  }

  // ⭐️ NEW Helper for Day-Specific Time Picker (To be inserted in _PetStoreOnboardingPageState)
  Widget _buildDailyTimePicker(String day, TimeOfDay? openTime, TimeOfDay? closeTime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(day, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
          ),
          Row(
            children: [
              Expanded(
                child: _buildTimePicker('Open', openTime, (t) {
                  setState(() => _dailyOpenTimes[day] = t);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePicker('Close', closeTime, (t) {
                  setState(() => _dailyCloseTimes[day] = t);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ⭐️ MODIFIED Time Picker (This is the one called inside the daily picker)
  Widget _buildTimePicker(String label, TimeOfDay? selectedTime, ValueChanged<TimeOfDay?> onTimeSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now(),
          builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: primaryColor), textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryColor))), child: child!),
        );
        if (picked != null) onTimeSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: subtleTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text(selectedTime?.format(context) ?? 'Not Set', style: GoogleFonts.poppins(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
              ],
            ),
            const Icon(Icons.access_time_outlined, color: subtleTextColor),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS (Reused/Modified) ---
  Widget _buildSectionContainer({ required String title, required List<Widget> children }) {
    // Assuming cardColor and borderColor are defined globally/in AppColor.
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: borderColor))
            ),
            child: Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
            ),
          ),
        ],
      ),
    );
  }

  // REPLACE your current _buildTextFormField with this updated version

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? prefixText,
    String? errorText,
    void Function(String)? onChanged,
    // NEW PARAMETER: small helper line
    String? tooltipMessage, CircularProgressIndicator? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(fontSize: 14, color: textColor),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          readOnly: readOnly,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(color: subtleTextColor),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(fontSize: 14, color: textColor),
            prefixIcon: Icon(icon, color: subtleTextColor, size: 20),
            errorText: errorText,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 2)),
          ),
        ),
        // Small line below for tooltip/helper message
        if (tooltipMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              tooltipMessage,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildFileUploadField({required String title, required String description, required VoidCallback onUploadTap, required FileUploadData? fileData, bool isSelfie = false,}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: fileData != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: fileData.type == 'image'
                ? Image.memory(fileData.bytes, fit: BoxFit.contain)
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.picture_as_pdf, color: errorColor, size: 40),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(fileData.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, style: GoogleFonts.poppins(fontSize: 12, color: textColor)),
                ),
              ],
            ),
          )
              : Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400)),
        ),
        const SizedBox(height: 4),
        Text(description, style: GoogleFonts.poppins(fontSize: 12, color: subtleTextColor)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(isSelfie ? Icons.camera_alt_outlined : Icons.upload_file_outlined, size: 20, color: Colors.black87,),
            label: Text(isSelfie ? 'Take Photo' : 'Upload File'),
            onPressed: onUploadTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              side: const BorderSide(color: borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPolicySelector() {
    String displayStatusText;
    String? viewableUrl;
    bool canView = false;

    if (_useDefaultPolicy) {
      displayStatusText = "Default MFP Policy Template selected.";
      viewableUrl = _defaultPolicyUrl;
      canView = viewableUrl != null && viewableUrl.isNotEmpty;
    } else if (_policyPdfFile != null) {
      displayStatusText = "Selected for upload: ${_policyPdfFile!.name}";
      canView = false;
    } else {
      displayStatusText = "No custom policy uploaded.";
      canView = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Your Business Policies*", style: headerStyle),
        const SizedBox(height: 12),
        LayoutBuilder(
            builder: (context, constraints) {
              return ToggleButtons(
                isSelected: [!_useDefaultPolicy, _useDefaultPolicy],
                onPressed: (index) {
                  setState(() {
                    _useDefaultPolicy = index == 1;
                    if (_useDefaultPolicy) {
                      _policyPdfFile = null;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: primaryColor,
                color: primaryColor,
                constraints: BoxConstraints(
                  minHeight: 40.0,
                  minWidth: (constraints.maxWidth - 4) / 2,
                ),
                children: const [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file), SizedBox(width: 8), Text("Upload My Own")]),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.article), SizedBox(width: 8), Text("Use Template")]),
                ],
              );
            }
        ),
        const SizedBox(height: 16),
        if (_useDefaultPolicy)
          _isTestamentLoading
              ? const Center(child: CircularProgressIndicator())
              : InkWell(
            onTap: !canView ? null : () => launchUrl(Uri.parse(viewableUrl!)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: canView ? successColor : subtleTextColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayStatusText,
                      style: GoogleFonts.poppins(color: canView ? textColor : subtleTextColor, decoration: canView ? TextDecoration.underline : null),
                    ),
                  ),
                  if (canView) Icon(Icons.open_in_new, color: subtleTextColor, size: 18),
                ],
              ),
            ),
          )
        else
          _buildFileUploadField(
            title: "",
            description: "Upload a single PDF containing your business policies and terms for customers.",
            fileData: _policyPdfFile,
            onUploadTap: () => _pickPdfFile((file) => setState(() => _policyPdfFile = file)),
          ),
      ],
    );
  }

  Widget _buildSummaryRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: subtleTextColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(color: subtleTextColor, fontSize: 13)),
                Text(
                  value.isNotEmpty ? value : "Not provided",
                  style: GoogleFonts.poppins(
                      color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatusRow({required String label, required bool isUploaded}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isUploaded ? Icons.check_circle : Icons.cancel,
            color: isUploaded ? successColor : errorColor,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            isUploaded ? "UPLOADED" : "MISSING",
            style: GoogleFonts.poppins(
              color: isUploaded ? successColor : errorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledVerificationPlaceholder(String message) {
    return Container(
      height: 158,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailVerificationSection() {
    final isCodeSent = _emailOtpSent;
    final isVerified = _emailVerified;

    // State 3: Final, verified state
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: successColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ FIX: Wrap the inner Row with Expanded
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: successColor),
                  const SizedBox(width: 12),
                  // ✅ FIX: Also wrap the Text with Expanded so it can truncate
                  Expanded(
                    child: Text(
                      _emailCtrl.text.trim(),
                      overflow: TextOverflow.ellipsis, // Adds "..." if text is too long
                      softWrap: false, // Prevents wrapping to a new line
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),
                ],
              ),
            ),
            // The "Change" button remains outside the Expanded widget
            TextButton(
              onPressed: _resetEmailVerification,
              child: Text(
                "Change",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    // State 1 (Initial) & State 2 (OTP Sent)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Input Field (Always visible unless verified)
        _buildTextFormField(
          controller: _emailCtrl,
          label: "Notification Email*",
          icon: Icons.email_outlined,
          readOnly: isCodeSent, // Lock the field after sending code
          onChanged: isCodeSent ? null : (v) => _emailDebouncer.run(() => _validateEmail(v)),
          errorText: isCodeSent ? null : _emailErrorText,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Required";
            if (!v.contains("@")) return "Invalid email";
            return _emailErrorText;
          },
        ),
        const SizedBox(height: 16),

        // Conditional OTP field
        if (isCodeSent)
          _buildTextFormField(
            controller: _emailOtpCtrl,
            label: "6-Digit Verification Code",
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6)
            ],
          ),

        if (isCodeSent) const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            // Cancel/Change Button (Only when code is sent)
            if (isCodeSent)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: OutlinedButton(
                  onPressed: _resetEmailVerification,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: errorColor,
                    side: const BorderSide(color: errorColor),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                  ),
                  child: const Text('Cancel'),
                ),
              ),

            // The main action button (Send or Verify)
            Expanded(
              child: ElevatedButton.icon(
                icon: isCodeSent
                    ? (_isVerifyingEmailOtp ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, color: Colors.white,))
                    : (_isSendingEmailOtp ? const SizedBox.shrink() : const Icon(Icons.send_outlined,color: Colors.white)),
                label: Text(isCodeSent ? 'Verify Code' : 'Send Code'),
                onPressed: (_isSendingEmailOtp || _isVerifyingEmailOtp)
                    ? null // Disable while loading
                    : (isCodeSent ? _verifyEmailOtp : _sendEmailOtp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),

        // Resend Cooldown
        if (isCodeSent)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _resendCooldown > 0 ? null : _sendEmailOtp,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend in $_resendCooldown seconds'
                        : 'Resend Code',
                    style: GoogleFonts.poppins(
                      color: _resendCooldown > 0 ? subtleTextColor : primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }
  Widget _buildPhoneVerificationSection() { // <--- The 'isDisabled' parameter is removed
    final isCodeSent = _phoneOtpSent;
    final isVerified = _phoneVerified;

    void resetPhoneVerification() {
      _phoneResendTimer?.cancel();
      setState(() {
        _phoneOtpSent = false;
        _phoneVerified = false;
        _phoneOtpCtrl.clear();
        _phoneCtrl.clear();
      });
    }

    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: successColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: successColor),
                const SizedBox(width: 12),
                Text(
                  '+91 ${_phoneCtrl.text.trim()}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor),
                ),
              ],
            ),
            TextButton(
              onPressed: resetPhoneVerification,
              child: Text("Change", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
            ),
          ],
        ),
      );
    }



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFormField(
          controller: _phoneCtrl,
          label: "Owner's Phone*",
          icon: Icons.phone_outlined,
          prefixText: "+91 ",
          readOnly: isCodeSent, // Logic is simple again
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: isCodeSent ? null : (v) {
            _phoneDebouncer.run(() => _validatePhone(v));
            // Re-validate the WhatsApp field if it's currently visible and not empty.
            if (!_isWhatsappSameAsPhone && _whatsappController.text.trim().isNotEmpty) {
              _whatsappDebouncer.run(() => _validateDashboardWhatsapp(_whatsappController.text));
            }
          },
          errorText: isCodeSent ? null : _phoneErrorText,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Required";
            if (v.length != 10) return "Must be 10 digits";
            return _phoneErrorText;
          },
        ),
        const SizedBox(height: 16),
        if (isCodeSent)
          _buildTextFormField(
            controller: _phoneOtpCtrl,
            label: "6-Digit Verification Code",
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          ),
        if (isCodeSent) const SizedBox(height: 16),
        Row(
          children: [
            if (isCodeSent)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: OutlinedButton(
                  onPressed: resetPhoneVerification,
                  style: OutlinedButton.styleFrom(foregroundColor: errorColor, side: const BorderSide(color: errorColor), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10)),
                  child: const Text('Cancel'),
                ),
              ),
            Expanded(
              child: ElevatedButton.icon(
                icon: isCodeSent ? (_isVerifyingPhoneOtp ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, color: Colors.white)) : (_isSendingPhoneOtp ? const SizedBox.shrink() : const Icon(Icons.send_to_mobile, color: Colors.white)),
                label: Text(isCodeSent ? 'Verify Code' : 'Send Code'),
                // Logic is simple again
                onPressed: (_isSendingPhoneOtp || _isVerifyingPhoneOtp) ? null : (isCodeSent ? _verifyPhoneOtp : _sendPhoneOtp),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
        if (isCodeSent)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Center(
              child: TextButton(
                // Logic is simple again
                onPressed: _phoneResendCooldown > 0 ? null : _sendPhoneOtp,
                child: Text(_phoneResendCooldown > 0 ? 'Resend in $_phoneResendCooldown seconds' : 'Resend Code', style: GoogleFonts.poppins(color: _phoneResendCooldown > 0 ? subtleTextColor : primaryColor, fontWeight: FontWeight.w600)),
              ),
            ),
          )
      ],
    );
  }

  Future<void> _validateDashboardWhatsapp(String phone) async {
    final cleanPhone = phone.trim();
    final ownerPhone = _phoneCtrl.text.trim();

    // 1. Check if the numbers are the same AND the checkbox is NOT checked
    if (cleanPhone.length == 10 && cleanPhone == ownerPhone && !_isWhatsappSameAsPhone) {
      if (mounted) {
        setState(() {
          // Set a clear error message that the UI can use.
          _dashboardWhatsappErrorText = 'If this number is the same as the Owner\'s Phone, please check the box above.';
          _isCheckingWhatsappPhone = false;
        });
      }
      return;
    }

    // If the cross-validation check passes (numbers are different or box is checked), clear the error.
    if (cleanPhone.length == 10 && (cleanPhone != ownerPhone || _isWhatsappSameAsPhone)) {
      if (mounted) setState(() => _dashboardWhatsappErrorText = null);
    }

    // Don't run check if format is incorrect, field is empty, or numbers are intentionally the same
    if (cleanPhone.length != 10 || cleanPhone.isEmpty || _isWhatsappSameAsPhone) {
      if (mounted) setState(() => _dashboardWhatsappErrorText = null);
      return;
    }

    // Clear the cross-validation error if the user changes the phone number
    if (cleanPhone != ownerPhone) {
      if (mounted) setState(() => _dashboardWhatsappErrorText = null);
    }

    setState(() { _isCheckingWhatsappPhone = true; _dashboardWhatsappErrorText = null; });

    // 2. Original Firestore duplicate check remains.
    final query = await FirebaseFirestore.instance.collection('users-sp-store')
        .where('dashboard_whatsapp', whereIn: [cleanPhone, '+91$cleanPhone']).limit(1).get();

    if (!mounted) return;
    setState(() {
      // If a Firestore duplicate is found, set that error.
      _dashboardWhatsappErrorText = query.docs.isNotEmpty ? 'This Service Contact Number is already registered.' : null;
      _isCheckingWhatsappPhone = false;
    });
  }

  Future<void> _validateEmail(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) return;
    setState(() { _isCheckingEmail = true; _emailErrorText = null; });
    final query = await FirebaseFirestore.instance.collection('users-sp-store')
        .where('notification_email', isEqualTo: email.trim()).limit(1).get();
    if (!mounted) return;
    setState(() {
      _emailErrorText = query.docs.isNotEmpty ? 'This email address is already registered.' : null;
      _isCheckingEmail = false;
    });
  }

  Future<void> _validatePhone(String phone) async {
    if (phone.trim().length != 10) return;
    setState(() { _isCheckingPhone = true; _phoneErrorText = null; });
    final query = await FirebaseFirestore.instance.collection('users-sp-store')
        .where('owner_phone', whereIn: [phone.trim(), '+91${phone.trim()}']).limit(1).get();
    if (!mounted) return;
    setState(() {
      _phoneErrorText = query.docs.isNotEmpty ? 'This phone number is already registered.' : null;
      _isCheckingPhone = false;
    });
  }

  Widget _buildWhatsappVerificationSection() { // <--- The 'isDisabled' parameter is removed
    final isCodeSent = _whatsappOtpSent;
    final isVerified = _whatsappVerified;
    final bool isButtonDisabledByError = _dashboardWhatsappErrorText != null || _isCheckingWhatsappPhone;

    void resetWhatsappVerification() {
      _whatsappResendTimer?.cancel();
      setState(() {
        _whatsappOtpSent = false;
        _whatsappVerified = false;
        _whatsappOtpCtrl.clear();
        _whatsappController.clear();
      });
    }

    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: successColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: successColor),
                const SizedBox(width: 12),
                Text(
                  '+91 ${_whatsappController.text.trim()}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor),
                ),
              ],
            ),
            TextButton(
              onPressed: resetWhatsappVerification,
              child: Text("Change", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextFormField(
          controller: _whatsappController,
          label: 'Service Contact Number*',
          prefixText: "+91 ",
          icon: Icons.chat_bubble_outline,
          readOnly: isCodeSent,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: isCodeSent ? null : (value) {
            // 💡 Re-validate immediately when the field changes to prevent hitting 'Send'
            _whatsappDebouncer.run(() => _validateDashboardWhatsapp(value));
          },
          errorText: isCodeSent ? null : _dashboardWhatsappErrorText,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Required";
            if (v.length != 10) return "Must be 10 digits";
            return _dashboardWhatsappErrorText;
          },
        ),
        const SizedBox(height: 16),
        if (isCodeSent)
          _buildTextFormField(
            controller: _whatsappOtpCtrl,
            label: "6-Digit Verification Code",
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          ),
        if (isCodeSent) const SizedBox(height: 16),
        Row(
          children: [
            if (isCodeSent)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: OutlinedButton(
                  onPressed: resetWhatsappVerification,
                  style: OutlinedButton.styleFrom(foregroundColor: errorColor, side: const BorderSide(color: errorColor), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10)),
                  child: const Text('Cancel'),
                ),
              ),
            Expanded(
              child: ElevatedButton.icon(
                icon: isCodeSent ? (_isVerifyingWhatsappOtp ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, color: Colors.white)) : (_isSendingWhatsappOtp ? const SizedBox.shrink() : const Icon(Icons.send_to_mobile, color: Colors.white)),
                label: Text(isCodeSent ? 'Verify Code' : 'Send Code'),
                // Logic is simple again
                onPressed: (_isSendingWhatsappOtp || _isVerifyingWhatsappOtp) || (isButtonDisabledByError && !isCodeSent)
                    ? null
                    : (isCodeSent ? _verifyWhatsappOtp : _sendWhatsappOtp),

                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),                  ),
            ),
          ],
        ),
        if (isCodeSent)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Center(
              child: TextButton(
                // Logic is simple again
                onPressed: _whatsappResendCooldown > 0 ? null : _sendWhatsappOtp,
                child: Text(_whatsappResendCooldown > 0 ? 'Resend in $_whatsappResendCooldown seconds' : 'Resend Code', style: GoogleFonts.poppins(color: _whatsappResendCooldown > 0 ? subtleTextColor : primaryColor, fontWeight: FontWeight.w600)),
              ),
            ),
          )
      ],
    );
  }
  Widget _buildFancyStepIndicator() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A202C), Color(0xFF2D3748)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: Text(
              'Partner Onboarding',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _stepTitles.length,
              itemBuilder: (context, i) {
                final isCompleted = i < _currentStep;
                final isActive = i == _currentStep;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: InkWell(
                    onTap: i <= _highestStepReached ? () {
                      // Allow navigation only to visited steps
                      if (i != _currentStep) {
                        setState(() {
                          _currentStep = i;
                          // ✅ THE FIX: When you navigate back, this becomes the new highest step.
                          // This prevents jumping forward again without re-validating.
                          _highestStepReached = i;
                        });
                      }
                    } : null,// Disables tap for future steps
                    // ^ ^ ^ TO HERE ^ ^ ^
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(colors: [primaryColor, Color(0xFF319795)])
                            : null,
                        color: isActive ? null : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompleted ? primaryColor : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCompleted ? Icons.check_circle : (isActive ? Icons.edit_note : Icons.circle_outlined),
                            color: isCompleted ? successColor : Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _stepTitles[i],
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _stepSubtitles[i],
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
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
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMobileStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20), // Adjusted padding slightly
      color: cardColor,
      child: Row(
        // No need for the extra Column here
        children: List.generate(_stepTitles.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;
          // This is the key logic from your desktop version.
          // A step is tappable if the user has already reached it.
          final bool isTappable = index <= _highestStepReached;

          return Expanded(
            // --- 래퍼 추가: InkWell ---
            // We wrap the step indicator in an InkWell to make it tappable.
            child: InkWell(
              // Use the isTappable flag to enable or disable the tap action.
              onTap: isTappable
                  ? () {
                if (index != _currentStep) {
                  setState(() {
                    _currentStep = index;
                    // ✅ THE SAME FIX: Apply the same logic here for mobile.
                    _highestStepReached = index;
                  });
                }
              }
                  : null,// Setting onTap to null disables the gesture.
              borderRadius: BorderRadius.circular(8), // Adds a nice ripple effect on tap.
              child: Padding(
                // Added padding to increase the tap area and for better spacing.
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Text(
                      'Step ${index + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? primaryColor
                            : (isCompleted ? successColor : subtleTextColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive
                            ? primaryColor
                            : (isCompleted ? successColor : borderColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
  Widget _buildNextButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [accentColor, Color(0xFFDD6B20)]),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          shadowColor: Colors.transparent,
        ),
        onPressed: _isSubmitting
            ? null
            : () async {
          // The final step is a special case for submission
          if (_currentStep == _stepTitles.length - 1) {
            await _submitAllDetails();
            return;
          }

          // Validate the current step before allowing the user to proceed
          if (_validateCurrentStep()) {
            setState(() {
              _currentStep++;
              // Update our progress tracker if we've reached a new step
              if (_currentStep > _highestStepReached) {
                _highestStepReached = _currentStep;
              }
            });
          }
        },
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentStep == _stepTitles.length - 1 ? "Complete Profile" : "Next Step"),
            const SizedBox(width: 8),
            Icon(_currentStep == _stepTitles.length - 1 ? Icons.check_circle_outline : Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white,),
          ],
        ),
      ),
    );
  }
  // Helper for Multi-Select (REUSED)
  Widget _buildMultiSelectDropdown({
    required List<MultiSelectItem<String>> items,
    required List<String> initialValue,
    required void Function(List<String>) onConfirm,
    TextStyle? titleTextStyle, TextStyle? itemTextStyle, TextStyle? selectedItemTextStyle, TextStyle? chipDisplayTextStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        MultiSelectDialogField<String>(
          selectedColor: primaryColor,

          buttonIcon: Icon(Icons.arrow_drop_down, color: subtleTextColor),
          buttonText: Text(
            "Select...",
            style: GoogleFonts.poppins(color: subtleTextColor, fontSize: 14),
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          items: items,
          initialValue: initialValue,
          onConfirm: onConfirm,
          confirmText: Text(
            'OK',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          cancelText: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.black,
            ),
          ),


          // Title inside the dialog
          title: Text(
            'Select',
            style: titleTextStyle ??
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          searchable: true,
          searchHint: 'Search...',

          // Chips shown below the dropdown
          chipDisplay: MultiSelectChipDisplay(
            chipColor: primaryColor.withOpacity(0.15),
            textStyle: chipDisplayTextStyle ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
          ),

          // These are only available in newer versions:
          // If your package version supports them, add these too
          // itemTextStyle: itemTextStyle,
          // selectedItemTextStyle: selectedItemTextStyle,
        ),
      ],
    );
  }

  // --- STEP 1: Basic Details (Largely Reused) ---
  Widget _buildBasicDetailsStep({required bool isDesktop}) {
    final bool showSeparateWhatsapp = !_isWhatsappSameAsPhone;
    final bool isPhoneVerificationInProgress = _phoneVerified && !_phoneVerified; // Always false, but keeping pattern
    final bool isWhatsappVerificationInProgress = _whatsappVerified && !_whatsappVerified; // Always false
    final bool isPhoneFieldActive = _phoneCtrl.text.trim().isNotEmpty && !_phoneVerified;
    final bool isWhatsappFieldActive = _whatsappController.text.trim().isNotEmpty && !_whatsappVerified;

    return Column(
      children: [
        if (_errorText != null) ...[
          Text(_errorText!, style: GoogleFonts.poppins(color: errorColor)),
          const SizedBox(height: 16),
        ],
        _buildSectionContainer(
          title: "Owner Information",
          children: [
            _buildTextFormField(controller: _ownerNameCtrl, label: "Owner’s Full Name*", icon: Icons.person_outline, validator: (v) => v == null || v.trim().isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            _buildEmailVerificationSection(),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildPhoneVerificationSection(),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: Text("Service Contact Number is same as Owner's Phone Number", style: GoogleFonts.poppins(fontSize: 14, color: textColor),),
                  value: _isWhatsappSameAsPhone,
                  onChanged: (bool? value) {
                    setState(() {
                      _isWhatsappSameAsPhone = value ?? false;
                      if (_isWhatsappSameAsPhone) {
                        _whatsappResendTimer?.cancel();
                        _whatsappVerified = false;
                        _whatsappOtpCtrl.clear();
                        _whatsappController.clear();
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                if (showSeparateWhatsapp)
                  (isPhoneFieldActive || isPhoneVerificationInProgress)
                      ? _buildDisabledVerificationPlaceholder("Complete Owner's Phone verification first.")
                      : _buildWhatsappVerificationSection(),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _panCtrl, label: "PAN*", icon: Icons.credit_card_outlined, validator: (v) => v == null || v.trim().isEmpty ? "Required" : null),
          ],
        ),
        _buildSectionContainer(
          title: "Verification Documents",
          children: [
            isDesktop
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFileUploadField(title: "Government ID*", description: "Aadhar, Passport, etc. (Image or PDF)", fileData: _idFrontFile, onUploadTap: () => _pickFile((file) => setState(() => _idFrontFile = file)))),
                const SizedBox(width: 24),
                Expanded(child: _buildFileUploadField(title: "ID with Selfie*", description: "A clear photo of you holding your ID", fileData: _idWithSelfieFile, isSelfie: true, onUploadTap: () async { final bytes = await showDialog<Uint8List>(context: context, builder: (_) => const WebcamSelfieWidget()); if (bytes != null) setState(() => _idWithSelfieFile = FileUploadData(bytes: bytes, name: 'selfie.jpg', type: 'image')); })),
              ],
            )
                : Column(
              children: [
                _buildFileUploadField(title: "Government ID*", description: "Aadhar, Passport, etc. (Image or PDF)", fileData: _idFrontFile, onUploadTap: () => _pickFile((file) => setState(() => _idFrontFile = file))),
                const SizedBox(height: 24),
                _buildFileUploadField(title: "ID with Selfie*", description: "A clear photo of you holding your ID", fileData: _idWithSelfieFile, isSelfie: true, onUploadTap: () async { final bytes = await showDialog<Uint8List>(context: context, builder: (_) => const WebcamSelfieWidget()); if (bytes != null) setState(() => _idWithSelfieFile = FileUploadData(bytes: bytes, name: 'selfie.jpg', type: 'image')); }),
              ],
            ),
            const SizedBox(height: 24),
            isDesktop
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFileUploadField(title: "Utility Bill*", description: "Latest electricity, gas, or water bill (Address Proof)", fileData: _utilityBillFile, onUploadTap: () => _pickFile((file) => setState(() => _utilityBillFile = file)))),
                const SizedBox(width: 24),
                const Expanded(child: SizedBox()),
              ],
            )
                : _buildFileUploadField(title: "Utility Bill*", description: "Latest electricity, gas, or water bill (Address Proof)", fileData: _utilityBillFile, onUploadTap: () => _pickFile((file) => setState(() => _utilityBillFile = file))),
          ],
        ),
      ],
    );
  }

  // --- TWEAKED STEP 2: Store & Brand Info (Retail Focus) ---
  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Product Categories You Stock*", style: headerStyle),
        const SizedBox(height: 12),
        _buildMultiSelectDropdown(
          items: _serviceCategories.map((c) => MultiSelectItem<String>(c, c)).toList(),
          initialValue: _selectedCategories,
          onConfirm: (results) => setState(() => _selectedCategories = results),
        ),
        const SizedBox(height: 16),
        Text("Pet Types You Cater To*", style: headerStyle),
        const SizedBox(height: 12),
        _buildMultiSelectDropdown(
          items: _petTypes.map((p) => MultiSelectItem<String>(p, p)).toList(),
          initialValue: _selectedPetTypes,
          onConfirm: (results) => setState(() => _selectedPetTypes = results),
        ),
      ],
    );
  }
  Widget _buildPaymentModesSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Modes of Payment Accepted", style: headerStyle),
        const SizedBox(height: 12),
        _buildMultiSelectDropdown(
          items: _modesOfPayment.map((c) => MultiSelectItem<String>(c, c)).toList(),
          initialValue: _selectedPaymentModes,
          onConfirm: (results) => setState(() => _selectedPaymentModes = results),
        ),
      ],
    );
  }

  Widget _buildServiceInfoStep({required bool isDesktop}) {
    return Column(
      children: [
        _buildSectionContainer(
          title: "Brand & Company Information",
          children: [
            _buildTextFormField(
              controller: _shopNameCtrl, label: "Brand Name*", icon: Icons.store_outlined,
              onChanged: (value) => _shopNameDebouncer.run(() => _validateShopName(value, 'Pet Store')),
              errorText: _shopNameErrorText,
              suffixIcon: _isCheckingShopName ? const CircularProgressIndicator(strokeWidth: 2) : null,
              validator: (v) { if (v == null || v.trim().isEmpty) return "Required"; return _shopNameErrorText; },
            ),
            const SizedBox(height: 24),
            _buildFileUploadField(title: "Brand Logo*", description: "The logo that will appear in the app.", fileData: _imageBytes != null ? FileUploadData(bytes: _imageBytes!, name: 'logo.png', type: 'image') : null, onUploadTap: _pickLogo),
          ],
        ),

      ],
    );
  }

  // --- TWEAKED STEP 3: Logistics & Policy ---
  Widget _buildDashboardSetupStep({required bool isDesktop}) {
    return Column(
      children: [
        _buildSectionContainer(
          title: "Service Scope & Specialty",
          children: [
            _buildCategorySelection(),
            const SizedBox(height: 24),
            _buildTextFormField(controller: _descriptionController, label: 'Store Description*', icon: Icons.description_outlined, maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _specialtyCtrl, label: 'Store Niche/Specialty (Optional)', icon: Icons.star_border, maxLines: 2),
            const SizedBox(height: 24),
            _buildPaymentModesSelection(),

            /*       _buildTextFormField(controller: _ifscCtrl, label: 'Bank IFSC*', icon: Icons.account_balance, validator: (v) => v == null || v.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _accountCtrl, label: 'Bank Account Number*', icon: Icons.account_balance_wallet, validator: (v) => v == null || v.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _gstinCtrl, label: 'GSTIN (Optional)', icon: Icons.business),*/
          ],
        ),
        _buildSectionContainer(
          title: "Store Location & Hours",
          children: [
            _buildAddressSearchField(),
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 350, child: GoogleMap(initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 4), onTap: _onMapTap, markers: _selectedMarker != null ? {_selectedMarker!} : {}, onMapCreated: (c) => _mapController = c))),
            const SizedBox(height: 16),
            // Address Fields
            _buildTextFormField(controller: _coordController, label: 'Coordinates (lat, lng)', icon: Icons.location_on_outlined, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _streetController, label: 'Street', icon: Icons.signpost_outlined, ),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _areaNameController, label: 'Area', icon: Icons.location_city_outlined, ),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _districtController, label: 'District', icon: Icons.map_outlined, ),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _stateController, label: 'State', icon: Icons.flag_outlined, ),
            const SizedBox(height: 16),
            _buildTextFormField(controller: _postalCodeController, label: 'Postal Code', icon: Icons.local_post_office_outlined, ),
            const SizedBox(height: 24),

            // ⭐️ NEW: Daily Store Hours Collection
            Text("Store Operating Hours (Daily)", style: headerStyle),
            const SizedBox(height: 16),
            ...daysOfWeek.map((day) => _buildDailyTimePicker(
              day,
              _dailyOpenTimes[day],
              _dailyCloseTimes[day],
            )),
          ],
        ),
        _buildSectionContainer(
          title: "Delivery & Order Logistics",
          children: [
// Local Delivery Radius
            _buildTextFormField(
              controller: _deliveryRadiusCtrl,
              label: 'Local Delivery Radius (in km)*',
              icon: Icons.map_outlined,
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
              tooltipMessage: "Maximum distance from your store for delivery. Orders beyond this radius won’t be accepted.",
            ),

            const SizedBox(height: 16),

// Order Fulfillment Time
            _buildTextFormField(
              controller: _fulfillmentTimeCtrl,
              label: 'Order Fulfillment Time (Minutes)*',
              icon: Icons.timer,
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
                tooltipMessage: "Your delivery time can vary based on the maximum radius you cover, so enter accordingly."
            ),

            const SizedBox(height: 24),

            Text("Delivery Fee Structure (Required)", style: headerStyle),
            const SizedBox(height: 12),

// Minimum Order Value
            _buildTextFormField(
              controller: _minOrderValueCtrl,
              label: 'Minimum Order Value for FREE Delivery (₹)*',
              icon: Icons.local_shipping,
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
              tooltipMessage: "Orders meeting or exceeding this value qualify for free delivery.",
            ),

            const SizedBox(height: 16),

// Delivery Fee per km
            _buildTextFormField(
              controller: _flatDeliveryFeeCtrl,
              label: 'Delivery Fee per km (₹)*',
              icon: Icons.delivery_dining,
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
              tooltipMessage: "Fee charged per kilometer to deliver an order. Helps pet parents estimate delivery costs.",
            ),

          ],
        ),
        _buildSectionContainer(
          title: "Policies & Assurance",
          children: [
            _buildPolicySelector(),
            const SizedBox(height: 24),
            Text("Returns & Exchanges", style: headerStyle),
            const SizedBox(height: 12),

// Return/Exchange Window
            ReturnWindowField(
              controller: _returnDaysCtrl, // Using _returnDaysCtrl as the number controller
              onUnitChanged: (newUnit) {
                setState(() {
                  _returnWindowUnit = newUnit; // Capture the unit change
                });
              },
            ),
            const SizedBox(height: 16),

// Detailed Return Policy Text
            _buildTextFormField(
              controller: _returnPolicyCtrl,
              label: 'Detailed Return Policy*',
              icon: Icons.rule,
              maxLines: 3,
              validator: (v) => v == null || v.isEmpty ? "Required" : null,
              tooltipMessage: "Provide clear instructions for returns and exchanges. Keep it concise and easy to understand for pet parents.",
            ),

            const SizedBox(height: 24),

// Customer Support Email
            _buildTextFormField(
              controller: _supportEmailCtrl,
              label: 'Dedicated Customer Support Email*',
              icon: Icons.support_agent,
              validator: (v) => v == null || !v.contains('@') ? "Valid Email Required" : null,
              tooltipMessage: "Provide an email address for customer support inquiries regarding orders and returns.",
            ),
          ],
        ),
        _buildSectionContainer(
          title: "Store Image Gallery",
          children: [_buildImagePicker()],
        ),
      ],
    );
  }
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Images (up to 5)', style: headerStyle),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
          child: _imagePaths.isEmpty
              ? const Center(child: Text('No images selected.', style: TextStyle(color: subtleTextColor)))
              : Wrap(
            spacing: 12, runSpacing: 12,
            children: _imagePaths.asMap().entries.map((entry) {
              return Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(entry.value, width: 100, height: 100, fit: BoxFit.contain)),
                  Positioned(top: 4, right: 4, child: InkWell(onTap: () => setState(() => _imagePaths.removeAt(entry.key)), child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
            label: const Text('Add Images'),
            onPressed: _pickImages,
            style: ElevatedButton.styleFrom(backgroundColor: textColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
          ),
        ),
      ],
    );
  }


  // ⭐️ NEW: Build Responsive Section Helper
  Widget buildResponsiveSection(List<Widget> children1, List<Widget> children2, {required bool isDesktop}) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children1)),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children2)),
        ],
      );
    } else {
      return Column(children: [...children1, const Divider(height: 32), ...children2]);
    }
  }


  // --- TWEAKED STEP 4: Review & Confirm (Full Implementation) ---
  Widget _buildReviewAndConfirmStep({required bool isDesktop}) {
    String formatList(List<String> items) => items.isEmpty ? "None selected" : items.join(', ');
    String formatTime(TimeOfDay? time) => time == null ? "Not set" : time.format(context);

    Widget buildHoursList() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: daysOfWeek.map((day) {
          final open = _dailyOpenTimes[day];
          final close = _dailyCloseTimes[day];
          final hours = (open != null && close != null) ? "${formatTime(open)} - ${formatTime(close)}" : "Not Set";
          return _buildSummaryRow(icon: Icons.schedule_outlined, label: day, value: hours);
        }).toList(),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: isDesktop ? 24 : 12),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- FORM HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Application for Pet Store Partnership", style: GoogleFonts.lora(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.bold, color: textColor))),
                Image.asset('assets/mfplogo.jpg', height: isDesktop ? 50 : 40),
              ],
            ),
            Text("Please review all details carefully before final submission.", style: GoogleFonts.poppins(fontSize: 15, color: subtleTextColor)),
            const Divider(height: 40, thickness: 1.5),

            // --- APPLICANT & BRAND ---
            Text("Applicant & Brand Information", style: headerStyle),
            const SizedBox(height: 16),
            buildResponsiveSection(isDesktop: isDesktop,
              [
                _buildSummaryRow(icon: Icons.person_outline, label: "Owner Name", value: _ownerNameCtrl.text),
                _buildSummaryRow(icon: Icons.email_outlined, label: "Contact Email (Notifications)", value: _emailCtrl.text),
                _buildSummaryRow(icon: Icons.phone_outlined, label: "Contact Phone", value: _phoneCtrl.text),
              ],
              [
                _buildSummaryRow(icon: Icons.store_outlined, label: "Brand Name", value: _shopNameCtrl.text),
                _buildSummaryRow(icon: Icons.credit_card_outlined, label: "PAN", value: _panCtrl.text),
                _buildSummaryRow(icon: Icons.chat_bubble_outline, label: "WhatsApp", value: _whatsappController.text),
              ],
            ),
            const Divider(height: 40),

            // --- STORE OPERATIONS & LOGISTICS ---
            Text("Store Operations & Logistics", style: headerStyle),
            const SizedBox(height: 16),
            _buildSummaryRow(icon: Icons.description_outlined, label: "Store Description", value: _descriptionController.text),
            _buildSummaryRow(icon: Icons.star_border, label: "Niche/Specialty", value: _specialtyCtrl.text.isNotEmpty ? _specialtyCtrl.text : "General Pet Store"),
            _buildSummaryRow(icon: Icons.location_on_outlined, label: "Full Address", value: _locationController.text),
            _buildSummaryRow(icon: Icons.category, label: "Categories Stocked", value: formatList(_selectedCategories)),
            _buildSummaryRow(icon: Icons.payment, label: "Modes Of Payment Accepted", value: formatList(_selectedPaymentModes)),
            _buildSummaryRow(icon: Icons.pets, label: "Pets Catered To", value: formatList(_selectedPetTypes)),
            const SizedBox(height: 16),
            Text("Store Hours", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            buildHoursList(), // Daily hours summary
            const Divider(height: 40),

            // --- DELIVERY & FEES ---
            Text("Delivery & Financials", style: headerStyle),
            const SizedBox(height: 16),
            _buildSummaryRow(icon: Icons.inventory, label: "Fulfillment Time", value: "${_fulfillmentTimeCtrl.text} minutes"),
            _buildSummaryRow(icon: Icons.local_shipping, label: "Delivery Radius", value: "${_deliveryRadiusCtrl.text} km"),
            _buildSummaryRow(icon: Icons.attach_money, label: "Minimum Free Order", value: "₹${_minOrderValueCtrl.text}"),
            _buildSummaryRow(icon: Icons.money, label: "Standard Flat Fee", value: "₹${_flatDeliveryFeeCtrl.text}"),
            const Divider(height: 40),

            // --- RETURN & SUPPORT ---
            Text("Returns & Support", style: headerStyle),
            const SizedBox(height: 16),
            _buildSummaryRow(icon: Icons.support_agent, label: "Support Email", value: _supportEmailCtrl.text),
            _buildSummaryRow(icon: Icons.date_range, label: "Return Window", value: "${_returnDaysCtrl.text} Days"),
            _buildSummaryRow(icon: Icons.rule, label: "Return Policy", value: _returnPolicyCtrl.text),
            const Divider(height: 40),

            // --- DOCUMENT CHECKLIST ---
            Text("Document Checklist", style: headerStyle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16, runSpacing: 16,
              children: [
                _buildDocumentStatusRow(label: "Brand Logo", isUploaded: _imageBytes != null),
                _buildDocumentStatusRow(label: "Government ID", isUploaded: _idFrontFile != null),
                _buildDocumentStatusRow(label: "ID with Selfie", isUploaded: _idWithSelfieFile != null),
                _buildDocumentStatusRow(label: "Utility Bill (Address Proof)", isUploaded: _utilityBillFile != null),
                _buildDocumentStatusRow(label: "Store Image Gallery", isUploaded: _imagePaths.isNotEmpty),
                _buildDocumentStatusRow(label: "Store Policy PDF", isUploaded: _policyPdfFile != null || _useDefaultPolicy),
              ],
            ),
            const Divider(height: 40),

            // --- FINAL AGREEMENT ---
            Text("Declaration & Agreement", style: headerStyle),
            const SizedBox(height: 16),
            if (_isTestamentLoading) const Center(child: CircularProgressIndicator())
            else ...[
              Container(
                height: 200, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(child: Text(_testamentText, style: GoogleFonts.poppins(fontSize: 12, color: subtleTextColor))),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(_checkboxLabelText, style: GoogleFonts.poppins(fontSize: 14, color: textColor)),
                value: _hasAgreedToTestament,
                onChanged: (bool? value) { setState(() { _hasAgreedToTestament = value ?? false; }); },
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: primaryColor, contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 30),
              buildResponsiveSection(isDesktop: isDesktop,
                [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Electronically Agreed By", style: GoogleFonts.poppins(color: subtleTextColor, fontSize: 12)),
                      Text(_ownerNameCtrl.text, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                ],
                [
                  Column(
                    crossAxisAlignment: isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text("Date of Agreement", style: GoogleFonts.poppins(color: subtleTextColor, fontSize: 12)),
                      Text(DateFormat('dd MMMM yyyy').format(DateTime.now()), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }


  // --- TWEAKED VALIDATION LOGIC ---
  bool _validateCurrentStep() {
    if (!_formKey.currentState!.validate()) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please correct the errors shown on the screen.'), backgroundColor: errorColor));
      return false;
    }

    final List<String> validationErrors = [];
    switch (_currentStep) {
      case 0: // Basic Details
      // Keeping this simplified for the demo, but production would require checking errorText as well
        if (!_emailVerified) validationErrors.add('Verified Email');
        if (!_phoneVerified) validationErrors.add('Verified Phone Number');
        if (!_isWhatsappSameAsPhone && !_whatsappVerified) validationErrors.add('Verified Service Contact Number');
        if (_idFrontFile == null) validationErrors.add('Government ID');
        if (_idWithSelfieFile == null) validationErrors.add('ID with Selfie');
        if (_utilityBillFile == null) validationErrors.add('Utility Bill');
        if (_phoneErrorText != null) validationErrors.add('the phone number is already taken');
        break;
      case 1: // Store & Brand Info
        if (_imageBytes == null) validationErrors.add('Brand Logo');
        if (_shopNameErrorText != null) validationErrors.add('the brand name is already taken');
        break;
      case 2: // Logistics & Policy
        if (_selectedCategories.isEmpty) validationErrors.add('Product Categories');
        if (_selectedPaymentModes.isEmpty) validationErrors.add('Payment Modes');
        if (_selectedPetTypes.isEmpty) validationErrors.add('Pet Types');

        if (_coordController.text.isEmpty) validationErrors.add('Store Location on Map');

        // ⭐️ NEW: Validate Daily Hours
        for (var day in daysOfWeek) {
          if (_dailyOpenTimes[day] == null || _dailyCloseTimes[day] == null) {
            validationErrors.add('Hours for $day');
          }
        }
        if (_deliveryRadiusCtrl.text.isEmpty || _fulfillmentTimeCtrl.text.isEmpty) validationErrors.add('Delivery Logistics');
        if (_returnDaysCtrl.text.isEmpty || _returnPolicyCtrl.text.isEmpty) validationErrors.add('Return Policy');
        if (_imagePaths.isEmpty) validationErrors.add('At least one store image');
        break;
    }

    if (validationErrors.isNotEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please complete: ${validationErrors.join(', ')}'), backgroundColor: errorColor));
      return false;
    }
    return true;
  }


  // --- TWEAKED SUBMISSION LOGIC ---
  Future<void> _submitAllDetails() async {
    // 1. Validation & Pre-checks
    if (!_formKey.currentState!.validate() || !_validateCurrentStep()) return;
    if(mounted) setState(() => _isSubmitting = true);
    try {
      final duplicateError = await _checkForDuplicates();
      if (duplicateError != null) {
        if(mounted) setState(() { _errorText = duplicateError; _isSubmitting = false; });
        return;
      }

      // 2. Upload Files
      String? finalPolicyUrl;
      if (_useDefaultPolicy) { finalPolicyUrl = _defaultPolicyUrl; } else { finalPolicyUrl = await _uploadFile(_policyPdfFile, 'store_policies'); }
      final idFrontUrl = await _uploadFile(_idFrontFile, 'id_proofs');
      final utilityBillUrl = await _uploadFile(_utilityBillFile, 'utility_bills');
      final idWithSelfieUrl = await _uploadFile(_idWithSelfieFile, 'selfies');
      final _uploadedLogoUrl = await _uploadImage(_imageBytes, 'company_logos');
      List<String> imageUrls = [];
      for (var dataUrl in _imagePaths) {
        final bytes = base64Decode(dataUrl.split(',').last);
        final ref = FirebaseStorage.instance.ref().child('store_images').child('${DateTime.now().millisecondsSinceEpoch}.png');
        imageUrls.add(await (await ref.putData(bytes)).ref.getDownloadURL());
      }

      // 3. Prepare Payloads
// In _submitAllDetails()

// ... (omitted previous code)

      // 3. Prepare Payloads
      final collectionRef = FirebaseFirestore.instance.collection('users-sp-store');

      // ✅ FIX: Use widget.serviceId if it's not empty, otherwise generate a new one.
      final String finalDocId = widget.serviceId.isNotEmpty
          ? widget.serviceId
          : collectionRef.doc().id;

      final docRef = collectionRef.doc(finalDocId);

      // ... (rest of your submission logic continues below)
      final coordText = _coordController.text.trim();
      final parts = coordText.split(',');
      GeoPoint geoPoint = GeoPoint(double.parse(parts[0]), double.parse(parts[1]));

      final String finalDashboardWhatsapp = _isWhatsappSameAsPhone ? _phoneCtrl.text.trim() : _whatsappController.text.trim();

      // ⭐️ NEW: Daily Store Hours Payload
      final Map<String, Map<String, String>> storeHoursPayload = {};
      for (var day in daysOfWeek) {
        storeHoursPayload[day] = {
          'open': _dailyOpenTimes[day]?.format(context) ?? '',
          'close': _dailyCloseTimes[day]?.format(context) ?? '',
        };
      }

      final retailPayload = {
        'return_window_value': int.tryParse(_returnDaysCtrl.text.trim()) ?? 0, // Value (Days/Hours)
        'return_window_unit': _returnWindowUnit, // ⭐️ NEW: Unit (Days or Hours)
        'return_policy_text': _returnPolicyCtrl.text.trim(),
        'shop_name_lowercase': _shopNameCtrl.text.trim().toLowerCase(),
        'type': widget.runType,
        'adminApproved': false, 'display': false, 'mfp_certified': true,
        'owner_name': _ownerNameCtrl.text.trim(), 'notification_email': _emailCtrl.text.trim(),
        'login_email': widget.email, 'owner_phone': _phoneCtrl.text.trim(),
        'id_url': idFrontUrl ?? '', 'utility_bill_url': utilityBillUrl ?? '', 'id_with_selfie_url': idWithSelfieUrl ?? '',
        'shop_logo': _uploadedLogoUrl ?? '',
        'bank_ifsc': _ifscCtrl.text.trim(), 'bank_account_num': _accountCtrl.text.trim(), 'pan': _panCtrl.text.trim(), 'gstin': _gstinCtrl.text.trim(),
        'shop_name': _shopNameCtrl.text.trim(),
        'description': _descriptionController.text.trim(), 'specialty_niche': _specialtyCtrl.text.trim(),
        'store_images': imageUrls,
        'pet_types_catered': _selectedPetTypes,
        'product_categories': _selectedCategories,
        'accepted_payment_modes': _selectedPaymentModes,
        'partner_policy_url': finalPolicyUrl ?? '',
        'full_address': _locationController.text.trim(),
        'location_geopoint': geoPoint,
        'street': _streetController.text.trim(), 'postal_code': _postalCodeController.text.trim(),
        'area_name': _areaNameController.text.trim(), 'district': _districtController.text.trim(), 'state': _stateController.text.trim(),
        'delivery_radius_km': int.tryParse(_deliveryRadiusCtrl.text.trim()) ?? 0,
        'fulfillment_time_min': int.tryParse(_fulfillmentTimeCtrl.text.trim()) ?? 0,
        'delivery_min_order_value': int.tryParse(_minOrderValueCtrl.text.trim()) ?? 0,
        'delivery_flat_fee': int.tryParse(_flatDeliveryFeeCtrl.text.trim()) ?? 0,
        'support_email': _supportEmailCtrl.text.trim(),
        'return_window_days': int.tryParse(_returnDaysCtrl.text.trim()) ?? 0,
        'return_policy_text': _returnPolicyCtrl.text.trim(),
        'store_hours': storeHoursPayload, // ⭐️ SAVED DAILY HOURS
        'dashboard_whatsapp': finalDashboardWhatsapp,
        'service_id': docRef.id, 'shop_user_id': widget.uid, 'created_at': FieldValue.serverTimestamp(),
      };

      await docRef.set(retailPayload);

      // 4. Finalization
      if (mounted) {
        // Navigation placeholder:
        // await Provider.of<UserNotifier>(context, listen: false).refreshUserProfile();
        // final userNotifier = Provider.of<UserNotifier>(context, listen: false);
        // if (userNotifier.authState == AuthState.authenticated && userNotifier.me != null) {
        //   context.go('/partner/${userNotifier.me!.serviceId}/profile');
        // }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pet Store Onboarding Complete!')));
      }
    } catch (e) {
      print('SUBMISSION FAILED: $e');
      if(mounted) setState(() => _errorText = 'Submission error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  // --- MAIN LAYOUT WIDGETS ---

  Widget _buildCurrentStepContent({required bool isDesktop}) {
    switch (_currentStep) {
      case 0: return _buildBasicDetailsStep(isDesktop: isDesktop);
      case 1: return _buildServiceInfoStep(isDesktop: isDesktop);
      case 2: return _buildDashboardSetupStep(isDesktop: isDesktop);
      case 3: return _buildReviewAndConfirmStep(isDesktop: isDesktop);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildMobileLayout() {
    // Assuming cardColor and borderColor are defined globally/in AppColor.
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFE2E8F0);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildMobileStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stepTitles[_currentStep], style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 4),
                  Text(_stepSubtitles[_currentStep], style: GoogleFonts.poppins(fontSize: 15, color: subtleTextColor)),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                    child: Container(key: ValueKey<int>(_currentStep), child: _buildCurrentStepContent(isDesktop: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
                      child: const Text("Back"),
                    ),
                  ),
                Expanded(child: _buildNextButton()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    // Assuming cardColor and borderColor are defined globally/in AppColor.
    const Color cardColor = Colors.white;
    const Color borderColor = Color(0xFFE2E8F0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFancyStepIndicator(),
        Expanded(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stepTitles[_currentStep], style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 8),
                        Text(_stepSubtitles[_currentStep], style: GoogleFonts.poppins(fontSize: 16, color: subtleTextColor)),
                        const SizedBox(height: 32),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                          child: Container(key: ValueKey<int>(_currentStep),child: _buildCurrentStepContent(isDesktop: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
                          child: Text("Back", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                        ),
                      const SizedBox(width: 16),
                      _buildNextButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF7FAFC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 760;
          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }
}

class ReturnWindowField extends StatefulWidget {
  final TextEditingController controller;
  // ⭐️ NEW CALLBACK
  final ValueChanged<String> onUnitChanged;

  const ReturnWindowField({
    Key? key,
    required this.controller,
    required this.onUnitChanged,
  }) : super(key: key);

  @override
  State<ReturnWindowField> createState() => _ReturnWindowFieldState();
}

class _ReturnWindowFieldState extends State<ReturnWindowField> {
  String _selectedUnit = 'Days'; // Default unit

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Return/Exchange Window*", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            // Number input
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                decoration: InputDecoration(
                  hintText: "Enter value",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Radio buttons for unit
            Column(
              children: [
                Row(
                  children: [
                    Radio<String>(
                      value: 'Days',
                      groupValue: _selectedUnit,
                      activeColor: RunTypeSelectionPage.primaryColor,
                      onChanged: (val) {
                        setState(() => _selectedUnit = val!);
                        widget.onUnitChanged(val!); // ⭐️ CALL THE CALLBACK
                      },
                    ),
                    Text(
                      "Days",
                      style: GoogleFonts.poppins(
                        color: RunTypeSelectionPage.primaryColor, // text color match
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: 'Hours',
                      groupValue: _selectedUnit,
                      activeColor: RunTypeSelectionPage.primaryColor,
                      onChanged: (val) {
                        setState(() => _selectedUnit = val!);
                        widget.onUnitChanged(val!); // ⭐️ CALL THE CALLBACK
                      },
                    ),
                    Text(
                      "Hours",
                      style: GoogleFonts.poppins(
                        color: RunTypeSelectionPage.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            )

          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Select whether your return/exchange window is in hours or days, then enter the value.",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
