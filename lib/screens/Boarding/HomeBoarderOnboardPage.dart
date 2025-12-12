    // lib/screens/ShopDetailsPage.dart
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
    import 'package:google_fonts/google_fonts.dart';
    import 'package:google_maps_flutter/google_maps_flutter.dart';
    import 'package:image_picker/image_picker.dart';
    import 'package:intl/intl.dart';
    import 'package:multi_select_flutter/chip_display/multi_select_chip_display.dart';
    import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
    import 'package:multi_select_flutter/util/multi_select_item.dart';
    import 'package:http/http.dart' as http;
import 'package:myfellowpet_sp/screens/Boarding/partner_shell.dart';
import 'package:myfellowpet_sp/screens/Boarding/roles/role_service.dart';
    import 'package:provider/provider.dart';
  import 'package:url_launcher/url_launcher.dart';
    import 'dart:typed_data';

    import '../../Colors/AppColor.dart';
  import '../../providers/boarding_details_loader.dart';
import '../../services/places_service.dart';
    import '../../tools/webcam_selfie_widget.dart';
    class PetType {
      final String id;
      final bool display;

      PetType({required this.id, required this.display});
    }

    // --- END VISUAL REFRESH ---

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

    class Homeboarderonboardpage extends StatefulWidget {
      final String uid;
      final String phone;
      final String email;
      final String runType;
      final String serviceId;

      const Homeboarderonboardpage({
        Key? key,
        required this.uid,
        required this.phone,
        required this.runType,
        required this.serviceId, required this.email,
      }) : super(key: key);

      @override
      _HomeboarderonboardpageState createState() => _HomeboarderonboardpageState();
    }

    class _HomeboarderonboardpageState extends State<Homeboarderonboardpage> {
      final _phoneDebouncer = Debouncer(milliseconds: 500);
      String? _phoneErrorText;
      String? _dashboardWhatsappErrorText;
      bool _isCheckingPhone = false;
      bool _isCheckingWhatsappPhone = false;
      int _highestStepReached = 0;
      String _checkboxLabelText = ""; // <-- ADD THIS LINE
      bool _isWhatsappSameAsPhone = false;
      // 🔽🔽🔽 ADD THESE NEW LINES 🔽🔽🔽
      final _shopNameDebouncer = Debouncer(milliseconds: 500);
      final _whatsappDebouncer = Debouncer(milliseconds: 500); // 👈 ADD THIS LINE
      String? _shopNameErrorText;
      bool _isCheckingShopName = false;

      // 🔽🔽🔽 ADD THESE NEW STATE VARIABLES 🔽🔽🔽
      String? _defaultPolicyUrl;
      bool _isLoadingDefaultPolicy = true;
      bool _useDefaultPolicy = false;

      // 🔽🔽🔽 ADD THESE NEW STATE VARIABLES 🔽🔽🔽
      final TextEditingController _emailOtpCtrl = TextEditingController();
      bool _isSendingEmailOtp = false;
      bool _isVerifyingEmailOtp = false;
      bool _emailOtpSent = false;
      bool _emailVerified = false;
      Timer? _resendTimer;
      int _resendCooldown = 60;


      // 🔽🔽🔽 ADD THESE NEW PHONE VERIFICATION VARIABLES 🔽🔽🔽
      final TextEditingController _phoneOtpCtrl = TextEditingController();
      bool _isSendingPhoneOtp = false;
      bool _isVerifyingPhoneOtp = false;
      bool _phoneOtpSent = false;
      bool _phoneVerified = false;
      Timer? _phoneResendTimer;
      int _phoneResendCooldown = 60;


      // 🔽🔽🔽 NEW WHATSAPP VERIFICATION VARIABLES 🔽🔽🔽
      final TextEditingController _whatsappOtpCtrl = TextEditingController();
      bool _isSendingWhatsappOtp = false;
      bool _isVerifyingWhatsappOtp = false;
      bool _whatsappOtpSent = false;
      bool _whatsappVerified = false;
      Timer? _whatsappResendTimer;
      int _whatsappResendCooldown = 60;


      String? _generatedDocIdForSubmission;

      final Map<String, Map<String, List<String>>> _selectedPetDetails = {};



      final _emailDebouncer = Debouncer(milliseconds: 500);
      static const List<String> percentages = [
        'lt_4h',   // Least advance notice
        'gt_4h',
        'gt_12h',
        'gt_24h',
        'gt_48h'   // Most advance notice

      ];

      String? _emailErrorText;
      bool _isCheckingEmail = false;
      bool _hasAgreedToTestament = false;
      // This single map will hold ALL state for the dynamic meal fields.
  // It can store single controllers, lists of controllers, and image data.
      Map<String, Map<String, Map<String, dynamic>>> _mealFieldState = {};

  // This map will hold the data for the uploaded meal images specifically.
      Map<String, Map<String, FileUploadData?>> _mealImages = {};

      // V V V ADD THESE TWO LINES V V V
      String _testamentText = "Loading declaration...";
      bool _isTestamentLoading = true;

      late final String apiKey;
      late final PlacesService _places;
      LatLng? _selectedLatLng;

      FileUploadData? _idFrontFile;
      FileUploadData? _utilityBillFile;
      FileUploadData? _idWithSelfieFile;
      FileUploadData? _policyPdfFile; // <-- ADD THIS LINE


      int _currentStep = 0;
      final _formKey = GlobalKey<FormState>();
      bool _isSubmitting = false;
      // --- NEW State Variables for Dynamic Pet Rates ---

  // This will hold the entire configuration fetched from Firestore.
      Map<String, dynamic> _petSizeConfigs = {};
      bool _isLoadingConfigs = true;

  // Note: The _RefundCtrls map remains unchanged as it's not related to pet sizes.
      final Map<String, TextEditingController> _RefundCtrls = {
        for (var s in percentages) s: TextEditingController()
      };

  // Controllers are now nested: First key is pet type (e.g., "dog"), second is size.
      Map<String, Map<String, TextEditingController>> _dailyPriceCtrls = {};
      Map<String, Map<String, TextEditingController>> _WalkingPriceCtrls = {};
      Map<String, Map<String, TextEditingController>> _MealPriceCtrls = {};
      Map<String, Map<String, TextEditingController>> _OfferdailyPriceCtrls = {};
      Map<String, Map<String, TextEditingController>> _OfferWalkingPriceCtrls = {};
      Map<String, Map<String, TextEditingController>> _OfferMealPriceCtrls = {};
      final TextStyle headerStyle =
      GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textColor);

      String? _errorText;

      final TextEditingController _ownerNameCtrl = TextEditingController();
      final TextEditingController _emailCtrl = TextEditingController();
      final TextEditingController _phoneCtrl = TextEditingController();
      final TextEditingController _shopNameCtrl = TextEditingController();
      final TextEditingController _ifscCtrl = TextEditingController();
      final TextEditingController _accountCtrl = TextEditingController();
      final TextEditingController _panCtrl = TextEditingController();
      final TextEditingController _gstinCtrl = TextEditingController();

      final TextEditingController _phoneController = TextEditingController();
      final TextEditingController _whatsappController = TextEditingController();
      final TextEditingController _descriptionController = TextEditingController();
      final TextEditingController _locationController = TextEditingController();
      final TextEditingController _coordController = TextEditingController();
      final TextEditingController _walkingController = TextEditingController();
      final TextEditingController _maxPetsController = TextEditingController();
      final TextEditingController _maxPetsPerHourController =
      TextEditingController();

      final TextEditingController _areaNameController = TextEditingController();
      final TextEditingController _districtController = TextEditingController();
      final TextEditingController _stateController = TextEditingController();

      final TextEditingController _streetController = TextEditingController();
      final TextEditingController _postalCodeController = TextEditingController();

      TimeOfDay? _openTime;
      String? _contractUrl;
      TimeOfDay? _closeTime;
      List<String> _imagePaths = [];

      List<PetType> _petTypes = [];
      List<String> _selectedPets = [];
      List<Map<String, String>> _employees = [];
      List<String> _selectedPetTypes = [];
  // The corrected version

      int _featureLimit = 10; // A safe default limit <-- ADD THIS LINE

      List<TextEditingController> _featureControllers = [
        TextEditingController(),
        TextEditingController(),
      ];
      final _featuresFormKey = GlobalKey<FormState>();

      GoogleMapController? _mapController;
      Marker? _selectedMarker;

      final ImagePicker _picker = ImagePicker();
      Uint8List? _imageBytes;
      String? _uploadedLogoUrl;
      String? _currentlyExpandedPetKey;

      final List<String> _stepTitles = [
        "Basic Details", "Service Information", "Dashboard Setup", "Review & Confirm"
      ];

      final List<String> _stepSubtitles = [
        "Owner's name, email & phone", "Your brand name & logo", "Services, location & rates",  "Final review and submission"
      ];

      final Map<String, List<Map<String, String>>> _breedsByPetType = {};

  // 🔽🔽🔽 REPLACE THIS ENTIRE METHOD 🔽🔽🔽
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

          // Map each document to a {'id': ..., 'name': ...} map
          final breeds = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? doc.id, // Use the 'name' field, fallback to ID
            };
          }).toList();

          _breedsByPetType[petKey] = breeds;
          return breeds;
        } catch (e) {
          print("Error fetching breeds for $petKey: $e");
          return [];
        }
      }

      void _resetEmailVerification() {
        _resendTimer?.cancel();
        setState(() {
          _emailOtpSent = false;
          _emailVerified = false;
          _emailOtpCtrl.clear();
          // This is important for the first step validator to re-run
          _emailCtrl.text = '';
        });
      }

      // ... after the _verifyEmailOtp() function ...

// 🔽🔽🔽 ADD THESE TWO NEW PHONE OTP METHODS 🔽🔽🔽

      Future<void> _sendPhoneOtp() async {
        if (_phoneCtrl.text.trim().length != 10) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter a valid 10-digit phone number.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isSendingPhoneOtp = true);
        try {
          // Note: We use the same 'sendSms' cloud function
          final callable = FirebaseFunctions.instance.httpsCallable('sendTestSms');

          // Use the same generated doc ID as the email verification
          _generatedDocIdForSubmission ??= FirebaseFirestore.instance.collection('users-sp-boarding').doc().id;

          final result = await callable.call({
            'phoneNumber': '+91${_phoneCtrl.text.trim()}',
            'docId': _generatedDocIdForSubmission,
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));

          setState(() {
            _phoneOtpSent = true;
            _startPhoneResendTimer();
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isSendingPhoneOtp = false);
        }
      }

      Future<void> _verifyPhoneOtp() async {
        if (_phoneOtpCtrl.text.trim().length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter the 6-digit code.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isVerifyingPhoneOtp = true);

        try {
          // Use the new 'verifySmsCode' cloud function
          final callable = FirebaseFunctions.instance.httpsCallable('verifyTestSmsCode');

          final result = await callable.call({
            'code': _phoneOtpCtrl.text.trim(),
            'docId': _generatedDocIdForSubmission,
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));
          setState(() {
            _phoneVerified = true;
            _phoneResendTimer?.cancel();
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isVerifyingPhoneOtp = false);
        }
      }

// Helper for the phone resend timer
      void _startPhoneResendTimer() {
        _phoneResendTimer?.cancel();
        setState(() => _phoneResendCooldown = 60);
        _phoneResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_phoneResendCooldown > 0) {
            setState(() => _phoneResendCooldown--);
          } else {
            timer.cancel();
          }
        });
      }

      // 🔽🔽🔽 ADD THESE NEW WHATSAPP OTP METHODS 🔽🔽🔽
      Future<void> _sendWhatsappOtp() async {
        if (_whatsappController.text.trim().length != 10) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter a valid 10-digit WhatsApp number.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isSendingWhatsappOtp = true);
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('sendTestSms');
          _generatedDocIdForSubmission ??= FirebaseFirestore.instance.collection('users-sp-boarding').doc().id;

          final result = await callable.call({
            'phoneNumber': '+91${_whatsappController.text.trim()}',
            'docId': _generatedDocIdForSubmission,
            'verificationType': 'whatsapp', // Specify the type
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));

          setState(() {
            _whatsappOtpSent = true;
            _startWhatsappResendTimer();
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isSendingWhatsappOtp = false);
        }
      }

      Future<void> _verifyWhatsappOtp() async {
        if (_whatsappOtpCtrl.text.trim().length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter the 6-digit code.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isVerifyingWhatsappOtp = true);

        try {
          // We use the same 'verifySmsCode' function, as it's generic
          final callable = FirebaseFunctions.instance.httpsCallable('verifyTestSmsCode');

          final result = await callable.call({
            'code': _whatsappOtpCtrl.text.trim(),
            'docId': _generatedDocIdForSubmission,
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));
          setState(() {
            _whatsappVerified = true;
            _whatsappResendTimer?.cancel();
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isVerifyingWhatsappOtp = false);
        }
      }

      void _startWhatsappResendTimer() {
        _whatsappResendTimer?.cancel();
        setState(() => _whatsappResendCooldown = 60);
        _whatsappResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_whatsappResendCooldown > 0) {
            setState(() => _whatsappResendCooldown--);
          } else {
            timer.cancel();
          }
        });
      }

      // 🔽🔽🔽 ADD THIS ENTIRE NEW WIDGET FOR WHATSAPP VERIFICATION 🔽🔽🔽
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

// 🔽🔽🔽 REPLACE THIS ENTIRE WIDGET 🔽🔽🔽
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
              label: 'Whatsapp Number*',
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


      // ... after the _buildEmailVerificationSection() widget ...

// 🔽🔽🔽 ADD THIS ENTIRE NEW WIDGET FOR PHONE VERIFICATION 🔽🔽🔽
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

// 🔽🔽🔽 REPLACE THIS ENTIRE WIDGET 🔽🔽🔽
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

      // 🔽🔽🔽 ADD THESE TWO NEW METHODS 🔽🔽🔽
      Future<void> _sendEmailOtp() async {
        // Basic validation
        if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter a valid email address.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isSendingEmailOtp = true);
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('sendEmailVerificationCode');

          // For a new user, docId won't exist yet, so we generate one client-side.
          // This is safe because Firestore document IDs are unique.
          final docId = FirebaseFirestore.instance.collection('users-sp-boarding').doc().id;
          // We need a way to reference this docId in the verify step and submit step.
          // A state variable is perfect for this.
          _generatedDocIdForSubmission = docId; // You'll need to declare this state variable.


          final result = await callable.call({
            'email': _emailCtrl.text.trim(),
            'docId': _generatedDocIdForSubmission, // Pass the ID to the function
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));

          setState(() {
            _emailOtpSent = true;
            _startResendTimer();
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isSendingEmailOtp = false);
        }
      }


      Future<void> _verifyEmailOtp() async {
        if (_emailOtpCtrl.text.trim().length != 6) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter the 6-digit code.'),
            backgroundColor: errorColor,
          ));
          return;
        }

        setState(() => _isVerifyingEmailOtp = true);

        try {
          final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('verifyEmailCode');

          final result = await callable.call({
            'code': _emailOtpCtrl.text.trim(),
            'docId': _generatedDocIdForSubmission, // Use the same ID
          });

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data['message']),
            backgroundColor: successColor,
          ));
          setState(() {
            _emailVerified = true;
            _resendTimer?.cancel(); // Stop the timer on success
          });
        } on FirebaseFunctionsException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'An unknown error occurred.'),
            backgroundColor: errorColor,
          ));
        } finally {
          setState(() => _isVerifyingEmailOtp = false);
        }
      }
      // Helper for the resend timer
      void _startResendTimer() {
        _resendTimer?.cancel(); // Cancel any existing timer
        setState(() => _resendCooldown = 60);
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_resendCooldown > 0) {
            setState(() => _resendCooldown--);
          } else {
            timer.cancel();
          }
        });
      }

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // 🔽🔽🔽 PASTE THIS ENTIRE NEW METHOD 🔽🔽🔽
      Future<void> _fetchDefaultPolicyUrl() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('default_content')
              .get();

          if (doc.exists && doc.data() != null) {
            setState(() {
              _defaultPolicyUrl = doc.data()!['home_boarder_terms_n_conditions'] as String?;
              _isLoadingDefaultPolicy = false;
            });
          } else {
            // Handle case where the document or field doesn't exist
            setState(() => _isLoadingDefaultPolicy = false);
          }
        } catch (e) {
          print('Error fetching default policy URL: $e');
          setState(() => _isLoadingDefaultPolicy = false);
        }
      }


      Future<void> _loadPetTypes() async {
        final snapshot =
        await FirebaseFirestore.instance.collection('pet_types').get();
        if (mounted) {
          setState(() {
            _petTypes = snapshot.docs
                .map((d) => PetType(
              id: d.id, // Assumes document ID is the pet name e.g., "Dog"
              display: (d.data()['display'] as bool? ?? false),
            ))
                .toList();
          });
        }
      }

      Future<void> _validateShopName(String name) async {
        // Don't run the check if the field is empty
        if (name.trim().isEmpty) {
          // Clear any previous errors when the user clears the field
          if (mounted) setState(() => _shopNameErrorText = null);
          return;
        }

        // Show a loading indicator to the user
        setState(() {
          _isCheckingShopName = true;
          _shopNameErrorText = null;
        });

        // For a case-insensitive search, we query a normalized, all-lowercase field.
        // This is the most efficient way to perform this check in Firestore.
        final normalizedName = name.trim().toLowerCase();

        // Build the efficient query
        final query = await FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .where('type', isEqualTo: 'Home Run') // 👈 FIRST condition: Only check "Home Run" types
            .where('shop_name_lowercase', isEqualTo: normalizedName) // 👈 SECOND condition: Case-insensitive check
            .limit(1) // 👈 crucial for efficiency: stops after finding one match
            .get();

        if (!mounted) return;

        // Update the UI with the result
        setState(() {
          _shopNameErrorText = query.docs.isNotEmpty
              ? 'This brand name is already in use.'
              : null;
          _isCheckingShopName = false;
        });
      }


      // In _HomeboarderonboardpageState

      // 🔽🔽🔽 ADD THIS ENTIRE NEW HELPER WIDGET 🔽🔽🔽
      // In _HomeboarderonboardpageState

      // In _HomeboarderonboardpageState

  // 🔽🔽🔽 REPLACE THIS ENTIRE METHOD 🔽🔽🔽
      Widget _buildMultiSelectDropdown({
        required String title,
        required List<MultiSelectItem<String>> items,
        required List<String> initialValue,
        required void Function(List<String>) onConfirm,

        // Add the new optional styling parameters
        TextStyle? titleTextStyle,
        TextStyle? itemTextStyle,
        TextStyle? selectedItemTextStyle,
        TextStyle? chipDisplayTextStyle,

      }) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: headerStyle),
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
                'Select $title',
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

      // 🔼🔼🔼 END OF NEW HELPER WIDGET 🔼🔼🔼

      Future<void> _fetchPetConfigs() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('boarding_options')
              .get();

          if (doc.exists && doc.data()!.containsKey('pet_size_configs')) {
            final configs = Map<String, dynamic>.from(doc.data()!['pet_size_configs']);

            // Initialize controllers for each pet type found in the config
            for (var petType in configs.keys) {
              final List<String> sizes = List<String>.from(configs[petType]['sizes']);
              _dailyPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
              _WalkingPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
              _MealPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
              _OfferdailyPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
              _OfferWalkingPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
              _OfferMealPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            }

            setState(() {
              _petSizeConfigs = configs;
              _isLoadingConfigs = false;
            });
          } else {
            // Fallback if the document doesn't exist
            setState(() { _isLoadingConfigs = false; });
          }
        } catch (e) {
          print("Error fetching pet configs: $e");
          setState(() { _isLoadingConfigs = false; });
        }
      }

      Widget _buildFeaturesSection() {
        // Check if the user can add more features
        bool canAddMore = _featureControllers.length < _featureLimit;

        return Form(
          key: _featuresFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      "Please list at least two key features of your service.",
                      style: GoogleFonts.poppins(fontSize: 13, color: subtleTextColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // This Row now contains the counter and the conditional button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Counter Text
                      Text(
                        '${_featureControllers.length} / $_featureLimit',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: canAddMore ? subtleTextColor : errorColor,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            : null, // This disables the button
                      ),
                    ],
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
                      style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                      validator: (v) {
                        if (index < 2 && (v == null || v.trim().isEmpty)) {
                          return 'This feature is required';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Feature #${index + 1}',
                        labelStyle: GoogleFonts.poppins(color: subtleTextColor),
                        prefixIcon: const Icon(Icons.star_border_rounded, color: subtleTextColor, size: 20),
                        suffixIcon: _featureControllers.length > 2
                            ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: errorColor),
                          onPressed: () {
                            setState(() {
                              _featureControllers[index].dispose();
                              _featureControllers.removeAt(index);
                            });
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // V V V ADD THIS NEW HELPER WIDGET V V V
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // 🔽🔽🔽 REPLACE your entire _buildPetReviewCard method with this 🔽🔽🔽
      Widget _buildPetReviewCard({required String petName, required bool isDesktop}) {
        final petKey = petName.toLowerCase();
        final config = _petSizeConfigs[petKey];
        if (config == null) return const SizedBox.shrink();

        // --- ✅ START OF THE FIX ---
        // 1. Get the user's selected display sizes (e.g., ["Medium (11-25 kg)"])
        final selectedDisplaySizes = _selectedPetDetails[petKey]?['sizes'] ?? [];

        // 2. Parse them into simple keys (e.g., ["Medium"])
        final List<String> selectedSizeKeys = selectedDisplaySizes.map((displayText) {
          return displayText.split(' ')[0];
        }).toList();
        // --- ✅ END OF THE FIX ---

        Widget buildRateRows(
            Map<String, Map<String, TextEditingController>> daily,
            Map<String, Map<String, TextEditingController>> walking,
            Map<String, Map<String, TextEditingController>> meal,
            ) {
          // If no sizes were selected for this pet, show a message instead of empty lists.
          if (selectedSizeKeys.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("No rates provided for the selected sizes.")),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("Daily Boarding", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              // 👈 USE THE SELECTED SIZES
              ...selectedSizeKeys.map((s) => _buildSummaryRow(icon: Icons.sunny, label: s, value: "₹ ${daily[petKey]![s]!.text.trim()}")),
              const Divider(height: 24),
              Text("Walking", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              // 👈 USE THE SELECTED SIZES
              ...selectedSizeKeys.map((s) => _buildSummaryRow(icon: Icons.directions_walk, label: s, value: "₹ ${walking[petKey]![s]!.text.trim()}")),
              const Divider(height: 24),
              Text("Meals", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              // 👈 USE THE SELECTED SIZES
              ...selectedSizeKeys.map((s) => _buildSummaryRow(icon: Icons.restaurant, label: s, value: "₹ ${meal[petKey]![s]!.text.trim()}")),
            ],
          );
        }

        Widget buildFeedingDetails() {
          final schedule = List<Map<String, dynamic>>.from(config['feeding_schedule'] ?? []);
          if (schedule.isEmpty) return const Center(child: Text("No feeding details provided."));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: schedule.map((mealObject) {
              final mealTitle = mealObject['section_title'] as String;
              final fields = List<Map<String, dynamic>>.from(mealObject['fields'] ?? []);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mealTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    ...fields.where((f) => f['field_type'] != 'image').map((fieldData) {
                      final label = fieldData['label'];
                      final fieldName = fieldData['field_name'];
                      dynamic value = _mealFieldState[petKey]![mealTitle]![fieldName];
                      String displayValue;
                      if (value is TextEditingController) {
                        displayValue = value.text.trim();
                      } else if (value is List<TextEditingController>) {
                        displayValue = value.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('; ');
                      } else {
                        displayValue = 'N/A';
                      }
                      return _buildSummaryRow(icon: Icons.edit_note, label: label, value: displayValue);
                    }),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11)),
                ),
                child: Text(
                  "Details for ${config['name']}",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: !isDesktop,
                      labelColor: primaryColor,
                      unselectedLabelColor: subtleTextColor,
                      indicatorColor: primaryColor,
                      tabs: const [
                        Tab(text: "Standard Rates"),
                        Tab(text: "Offer Rates"),
                        Tab(text: "Feeding Info"),
                      ],
                    ),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          buildRateRows(_dailyPriceCtrls, _WalkingPriceCtrls, _MealPriceCtrls),
                          buildRateRows(_OfferdailyPriceCtrls, _OfferWalkingPriceCtrls, _OfferMealPriceCtrls),
                          buildFeedingDetails(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // V V V REPLACE your old _buildReviewAndConfirmStep method with this one V V V
      Widget _buildReviewAndConfirmStep({required bool isDesktop}) {
        String formatList(List<String> items) => items.isEmpty ? "None selected" : items.join(', ');
        String formatTime(TimeOfDay? time) => time == null ? "Not set" : time.format(context);

        Widget buildResponsiveSection(List<Widget> children1, List<Widget> children2) {
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

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: isDesktop ? 24 : 12),
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FORM HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Application for Partnership", style: GoogleFonts.lora(fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.bold, color: textColor))),
                    Image.asset('assets/mfplogo.jpg', height: isDesktop ? 50 : 40),
                  ],
                ),
                Text("Please review all details carefully before final submission.", style: GoogleFonts.poppins(fontSize: 15, color: subtleTextColor)),
                const Divider(height: 40, thickness: 1.5),

                // --- APPLICANT & BRAND ---
                Text("Applicant & Brand Information", style: headerStyle),
                const SizedBox(height: 16),
                buildResponsiveSection(
                  [
                    _buildSummaryRow(icon: Icons.person_outline, label: "Owner Name", value: _ownerNameCtrl.text),
                    _buildSummaryRow(icon: Icons.email_outlined, label: "Contact Email", value: _emailCtrl.text),
                    _buildSummaryRow(icon: Icons.phone_outlined, label: "Contact Phone", value: _phoneCtrl.text),
                  ],
                  [
                    _buildTextFormField(
                      controller: _shopNameCtrl,
                      label: "Brand Name*",
                      icon: Icons.store_outlined,
                      // These new properties enable real-time validation
                      onChanged: (value) => _shopNameDebouncer.run(() => _validateShopName(value)),
                      errorText: _shopNameErrorText,
                      suffixIcon: _isCheckingShopName
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : null,
                      // The validator now checks for emptiness AND the async error state
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
                        return _shopNameErrorText;
                      },
                    ),                  _buildSummaryRow(icon: Icons.credit_card_outlined, label: "PAN", value: _panCtrl.text),
                    _buildSummaryRow(icon: Icons.chat_bubble_outline, label: "WhatsApp", value: _whatsappController.text),
                  ],
                ),
                const Divider(height: 40),

                // --- SERVICE & LOCATION ---
                Text("Service Operations & Location", style: headerStyle),
                const SizedBox(height: 16),
                _buildSummaryRow(icon: Icons.description_outlined, label: "Service Description", value: _descriptionController.text),
                _buildSummaryRow(icon: Icons.location_on_outlined, label: "Full Address", value: _locationController.text),
                _buildSummaryRow(icon: Icons.schedule_outlined, label: "Operating Hours", value: "${formatTime(_openTime)} - ${formatTime(_closeTime)}"),
                _buildSummaryRow(icon: Icons.pets_outlined, label: "Pets Serviced", value: formatList(_selectedPets)),
                const Divider(height: 40),

                // --- 🔹 REBUILT FINANCIALS & POLICIES SECTION 🔹 ---
                Text("Financials & Pet Details", style: headerStyle),
                const SizedBox(height: 16),

                // 1. Global Refund Policy
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Global Refund Policy", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      ...percentages.map((key) => _buildSummaryRow(icon: Icons.percent_outlined, label: _formatRefundPolicyLabel(key), value: "${_RefundCtrls[key]!.text}%")),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Pet-Specific Cards
                ..._selectedPets.map((petName) => _buildPetReviewCard(petName: petName, isDesktop: isDesktop)).toList(),

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
                    _buildDocumentStatusRow(label: "Utility Bill", isUploaded: _utilityBillFile != null),
                    _buildDocumentStatusRow(label: "Service Images", isUploaded: _imagePaths.isNotEmpty),
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
                  buildResponsiveSection(
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
      // lib/screens/HomeBoarderOnboardPage.dart -> in _HomeboarderonboardpageState

    // V V V ADD ALL THREE OF THESE HELPER METHODS INSIDE YOUR STATE CLASS V V V

    // Helper widget for the summary rows
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



    // Helper for the document checklist
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
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

    // V V V ADD THIS HELPER for displaying pricing details V V V




      // --- OMITTING NON-UI LOGIC (SAME AS BEFORE) ---
      @override
      void initState() {
        super.initState();
        _loadPetTypesAndConfigs(); // <-- Use a new combined function


        _fetchFeatureLimit(); // <-- ADD THIS LINE
        _fetchTestamentText();
        _fetchDefaultPolicyUrl(); // 👈 ADD THIS LINE


        apiKey = const String.fromEnvironment('PLACES_API_KEY', defaultValue: '');
        _places = PlacesService(apiKey);
      }

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // 🔽🔽🔽 PASTE THIS ENTIRE NEW WIDGET 🔽🔽🔽
      Widget _buildPolicySelector() {
        // Determine what text to display based on the user's selection
        String displayStatusText;
        String? viewableUrl;
        bool canView = false;

        if (_useDefaultPolicy) {
          displayStatusText = "Default MFP Policy Template selected.";
          viewableUrl = _defaultPolicyUrl;
          canView = viewableUrl != null && viewableUrl.isNotEmpty;
        } else if (_policyPdfFile != null) {
          displayStatusText = "Selected for upload: ${_policyPdfFile!.name}";
          canView = false; // Can't view local files from a URL
        } else {
          displayStatusText = "No custom policy uploaded.";
          canView = false;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Business Policies*", style: headerStyle),
            const SizedBox(height: 12),

            // --- Toggle Buttons for choice ---
            LayoutBuilder(
                builder: (context, constraints) {
                  return ToggleButtons(
                    isSelected: [!_useDefaultPolicy, _useDefaultPolicy],
                    onPressed: (index) {
                      setState(() {
                        _useDefaultPolicy = index == 1;
                        // If switching to the template, clear any picked file to avoid confusion
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
                      minWidth: (constraints.maxWidth - 4) / 2, // Divide space equally
                    ),
                    children: const [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file), SizedBox(width: 8), Text("Upload My Own")]),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.article), SizedBox(width: 8), Text("Use Template")]),
                    ],
                  );
                }
            ),
            const SizedBox(height: 16),

            // --- Conditional UI based on selection ---
            if (_useDefaultPolicy)
            // --- UI for "Use Template" ---
              _isLoadingDefaultPolicy
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
            // --- UI for "Upload My Own" ---
              _buildFileUploadField(
                title: "", // Title is now handled above
                description: "Upload a single PDF containing your business policies and terms for customers.",
                fileData: _policyPdfFile,
                onUploadTap: () => _pickPdfFile((file) => setState(() => _policyPdfFile = file)),
              ),
          ],
        );
      }

      // Combine the two fetch functions into one
      Future<void> _loadPetTypesAndConfigs() async {
        try {
          // Fetch both collections at the same time for efficiency
          final results = await Future.wait([
            FirebaseFirestore.instance.collection('pet_types').get(),
            FirebaseFirestore.instance
                .collection('settings')
                .doc('boarding_options')
                .collection('pet_information')
                .get(),
          ]);

          final petTypesSnapshot = results[0] as QuerySnapshot;
          final configsSnapshot = results[1] as QuerySnapshot;

          if (!mounted) return;

          // 1. Process Pet Types (this remains the same)
          _petTypes = petTypesSnapshot.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return PetType(
              id: d.id,
              display: data['display'] as bool? ?? false,
            );
          }).toList();

          // 2. Process Configurations from the subcollection
          final Map<String, dynamic> fetchedConfigs = {};
          for (final doc in configsSnapshot.docs) {
            fetchedConfigs[doc.id] = doc.data();
          }
          _petSizeConfigs = fetchedConfigs;

          // 3. Initialize all controllers based on the fetched configs
          for (var petType in _petSizeConfigs.keys) {
            final config = _petSizeConfigs[petType] as Map<String, dynamic>;

            // A. Initialize Rate Controllers
            final List<String> sizes = List<String>.from(config['sizes'] ?? []);
            _dailyPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            _WalkingPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            _MealPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            _OfferdailyPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            _OfferWalkingPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };
            _OfferMealPriceCtrls[petType] = { for (var size in sizes) size: TextEditingController() };

            // B. Initialize Detailed Feeding Schedule State
            if (config['feeding_schedule'] != null) {
              final List<dynamic> schedule = config['feeding_schedule'];
              _mealFieldState[petType] = {};
              _mealImages[petType] = {};

              for (var mealObject in schedule) {
                // --- SAFETY CHECKS ADDED HERE ---
                final sectionTitle = mealObject['section_title'] as String? ?? 'Unnamed Meal';
                final List<dynamic> fields = mealObject['fields'] ?? [];

                _mealFieldState[petType]![sectionTitle] = {};
                _mealImages[petType]![sectionTitle] = null;

                for (var fieldData in fields) {
                  final fieldName = fieldData['field_name'] as String? ?? '';
                  final fieldType = fieldData['field_type'] as String? ?? '';

                  if (fieldName.isEmpty) continue; // Skip if field_name is missing

                  switch (fieldType) {
                    case 'text':
                      _mealFieldState[petType]![sectionTitle]![fieldName] = TextEditingController();
                      break;
                    case 'points':
                      _mealFieldState[petType]![sectionTitle]![fieldName] = [TextEditingController()];
                      break;
                    case 'image':
                    // The image state is handled by _mealImages, no controller needed.
                      break;
                  }
                }
              }
            }
          }

          setState(() { _isLoadingConfigs = false; });

        } catch (e, stackTrace) {
          print("Error loading all configs: $e");
          print(stackTrace); // Print stack trace for better debugging
          if (mounted) setState(() => _isLoadingConfigs = false);
        }
      }

      Future<void> _fetchFeatureLimit() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('limits')
              .get();

          if (doc.exists && doc.data() != null) {
            final limitString = doc.data()!['home_boarding_feature_limit'] as String?;
            // Safely parse the string to an integer
            final limit = int.tryParse(limitString ?? '');
            if (limit != null) {
              if (mounted) {
                setState(() {
                  _featureLimit = limit;
                });
              }
            }
          }
        } catch (e) {
          // If there's an error, it will just use the default limit.
          print('Error fetching feature limit: $e');
        }
      }

      // V V V ADD THIS ENTIRE FUNCTION V V V
      Future<void> _fetchTestamentText() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('settings')
              .doc('testaments')
              .get();

          if (doc.exists && doc.data() != null) {
            setState(() {
              _testamentText = doc.data()!['home_boarding'] as String? ?? 'Declaration not available.';
              _checkboxLabelText = doc.data()!['home_boarding_checkbox_label'] as String? ?? 'I confirm the details are accurate and agree to the terms.';
              _isTestamentLoading = false;
            });
          } else {
            setState(() {
              _testamentText = 'Declaration not found.';
              _isTestamentLoading = false;
            });
          }
        } catch (e) {
          setState(() {
            _testamentText = 'Error loading declaration.';
            _isTestamentLoading = false;
          });
        }
      }

      // In _HomeboarderonboardpageState
// lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

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
      @override
      void dispose() {
        _emailOtpCtrl.dispose(); // 👈 Don't forget to dispose it
        _phoneOtpCtrl.dispose(); // 👈 ADD THIS LINE
        _phoneResendTimer?.cancel(); // 👈 ADD THIS LINE
        _whatsappOtpCtrl.dispose(); // 👈 ADD THIS LINE
        _phoneResendTimer?.cancel(); // 👈 ADD THIS LINE
        _whatsappResendTimer?.cancel(); // 👈 ADD THIS LINE
        _ownerNameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
        _shopNameCtrl.dispose(); _ifscCtrl.dispose();
        _accountCtrl.dispose(); _panCtrl.dispose(); _gstinCtrl.dispose();
        // Correctly disposes all dynamically created TextEditingControllers
        final allControllerMaps = [
          _dailyPriceCtrls, _WalkingPriceCtrls, _MealPriceCtrls,
          _OfferdailyPriceCtrls, _OfferWalkingPriceCtrls, _OfferMealPriceCtrls
        ];

        for (var controllerMap in allControllerMaps) {
          for (var innerMap in controllerMap.values) {
            for (var controller in innerMap.values) {
              controller.dispose();
            }
          }
        }

  // Dispose feature controllers
        for (final controller in _featureControllers) {
          controller.dispose();
        }
        for (var petMap in _mealFieldState.values) {
          for (var mealMap in petMap.values) {
            for (var item in mealMap.values) {
              if (item is TextEditingController) {
                item.dispose();
              } else if (item is List<TextEditingController>) {
                for (var controller in item) {
                  controller.dispose();
                }
              }
            }
          }
        }
        super.dispose();
      }
      Future<void> _validatePhone(String phone) async {
        if (phone.trim().length != 10) return;
        setState(() { _isCheckingPhone = true; _phoneErrorText = null; });
      /*  final query = await FirebaseFirestore.instance.collection('users-sp-boarding')
            .where('owner_phone', whereIn: [phone.trim(), '+91${phone.trim()}']).limit(1).get();*/
        if (!mounted) return;
        setState(() {
         // _phoneErrorText = query.docs.isNotEmpty ? 'This phone number is already registered.' : null;
          _isCheckingPhone = false;
        });
      }
      // lib/screens/HomeBoarderOnboardPage.dart -> in _HomeboarderonboardpageState

// V V V REPLACE this entire method V V V
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

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
        final query = await FirebaseFirestore.instance.collection('users-sp-boarding')
            .where('dashboard_whatsapp', whereIn: [cleanPhone, '+91$cleanPhone']).limit(1).get();

        if (!mounted) return;
        setState(() {
          // If a Firestore duplicate is found, set that error.
          _isCheckingWhatsappPhone = false;
        });
      }

      Future<void> _validateEmail(String email) async {
        if (email.trim().isEmpty || !email.contains('@')) return;
        setState(() { _isCheckingEmail = true; _emailErrorText = null; });
        final query = await FirebaseFirestore.instance.collection('users-sp-boarding')
            .where('notification_email', isEqualTo: email.trim()).limit(1).get();
        if (!mounted) return;
        setState(() {
          _isCheckingEmail = false;
        });
      }
      Future<void> _downloadContract() async {
        try {
          final docSnap = await FirebaseFirestore.instance.collection('company_documents').doc('boarders_partner_contract').get();
          final pdfUrl = docSnap.data()?['contract_pdf'] as String?;
          if (pdfUrl == null || pdfUrl.isEmpty) {
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract PDF not available')));
            return;
          }
          html.AnchorElement(href: pdfUrl)..setAttribute('download', 'PartnerContract.pdf')..target = '_blank'..click()..remove();
        } catch (e) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download contract: $e')));
        }
      }
      Future<void> _pickFile(void Function(FileUploadData) onFilePicked) async {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'pdf']);
        if (result != null && result.files.single.bytes != null) {
          final file = result.files.single;
          final fileType = ['jpg', 'png'].contains(file.extension?.toLowerCase()) ? 'image' : 'pdf';
          setState(() => onFilePicked(FileUploadData(bytes: file.bytes!, name: file.name, type: fileType)));
        }
      }

      Future<void> _pickPdfFile(void Function(FileUploadData) onFilePicked) async {
        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (result != null && result.files.single.bytes != null) {
          final file = result.files.single;
          // The type will always be 'pdf' for this picker
          setState(() => onFilePicked(FileUploadData(bytes: file.bytes!, name: file.name, type: 'pdf')));
        }
      }
      // lib/screens/ShopDetailsPage.dart

      Future<void> _pickContract() async {
        try {
          // 1. Show the file picker
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
          );

          // Check if a file was selected
          if (result == null || result.files.single.bytes == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('No file selected.'),
              ));
            }
            return;
          }

          final file = result.files.single;

          // 2. Start the upload and show a loading indicator
          setState(() {
            _isSubmitting = true; // Use a loading state to prevent early submission
          });

          final bytes = file.bytes!;
          final ref = FirebaseStorage.instance
              .ref()
              .child('Boarders_Partner_Contract')
              .child('${DateTime.now().millisecondsSinceEpoch}.pdf');

          // 3. Upload the file and get the download URL
          final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
          final snapshot = await uploadTask;
          final url = await snapshot.ref.getDownloadURL();

          // 4. Update the URL and remove the loading state
          setState(() {
            _contractUrl = url;
            _isSubmitting = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Contract uploaded successfully!'),
              backgroundColor: successColor,
            ));
          }

        } catch (e) {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _errorText = 'Failed to upload contract: $e';
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to upload contract: $e'),
              backgroundColor: errorColor,
            ));
          }
        }
      }
      Future<void> _pickLogo() async {
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          setState(() => _imageBytes = bytes);
        }
      }
      Future<String?> _checkForDuplicates() async {
        final collection = FirebaseFirestore.instance.collection('users-sp-boarding');
        final panQuery = await collection.where('pan', isEqualTo: _panCtrl.text.trim()).limit(1).get();
        if (panQuery.docs.isNotEmpty) return 'This PAN number is already registered.';
        return null;
      }
      Future<String?> _uploadFile(FileUploadData? fileData, String storagePath) async {
        if (fileData == null) return null;
        final metadata = SettableMetadata(contentType: fileData.type == 'pdf' ? 'application/pdf' : 'image/jpeg');
        final ref = FirebaseStorage.instance.ref().child(storagePath).child(fileData.name);
        return await (await ref.putData(fileData.bytes, metadata)).ref.getDownloadURL();
      }
      Future<String?> _uploadImage(Uint8List? bytes, String storagePath) async {
        if (bytes == null) return null;
        final ref = FirebaseStorage.instance.ref().child(storagePath).child('${DateTime.now().millisecondsSinceEpoch}.png');
        return await (await ref.putData(bytes, SettableMetadata(contentType: 'image/png'))).ref.getDownloadURL();
      }
      String _formatRefundPolicyLabel(String key) {
        try {
          final parts = key.split('_');
          if (parts.length != 2) return key;

          // Check if it's greater than (gt) or less than (lt)
          String conditionText = parts[0] == 'gt'
              ? 'If cancelled more than'
              : 'If cancelled less than';

          // Extract hours (remove 'h')
          final hours = parts[1].replaceAll('h', '');

          return '$conditionText $hours hours before booking time';
        } catch (e) {
          return key;
        }
      }

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // V V V REPLACE your entire _submitAllDetails method with this new version V V V
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // V V V REPLACE your entire _submitAllDetails method with this one V V V
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // V V V ADD THIS NEW HELPER FUNCTION V V V
      String _getSafeRate(
          Map<String, Map<String, TextEditingController>> controllerMap,
          String petKey,
          String sizeKey,
          ) {
        // Safely check if the map for the pet exists
        final sizeMap = controllerMap[petKey];
        if (sizeMap == null) {
          print("⚠️ WARNING: Controller map for pet '$petKey' was not initialized. Check Firestore config.");
          return "0"; // Return a safe default
        }
        // Safely check if the controller for the specific size exists
        final controller = sizeMap[sizeKey];
        if (controller == null) {
          print("⚠️ WARNING: Controller for size '$sizeKey' of pet '$petKey' was not initialized. Check Firestore config.");
          return "0"; // Return a safe default
        }
        return controller.text.trim();
      }
      Future<void> _submitAllDetails() async {
        if (!_formKey.currentState!.validate()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
          return;
        }
        final validationErrors = <String>[
          if (_idFrontFile == null) 'Government ID', if (_idWithSelfieFile == null) 'ID with Selfie',
          if (_utilityBillFile == null) 'Utility Bill', if (_imageBytes == null) 'Brand Logo',
          if (_openTime == null || _closeTime == null) 'Open/Close Times', if (_imagePaths.isEmpty) 'At least one service image',
          if (_policyPdfFile == null && !_useDefaultPolicy) 'Business Policies PDF',
          if (_selectedPets.isEmpty) 'At least one pet type',
        ];
        if (validationErrors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please complete: ${validationErrors.join(', ')}'), backgroundColor: errorColor));
          return;
        }


// NEW: Upload meal images and get their URLs
        final Map<String, Map<String, String>> mealImageUrls = {};
        for (var petKey in _mealImages.keys) {
          mealImageUrls[petKey] = {};
          for (var sectionTitle in _mealImages[petKey]!.keys) {
            final fileData = _mealImages[petKey]![sectionTitle];
            if (fileData != null) {
              final url = await _uploadFile(fileData, 'meal_images/$petKey/$sectionTitle');
              mealImageUrls[petKey]![sectionTitle] = url ?? '';
            }
          }
        }

        // V V V THIS IS THE MISSING LINE THAT FIXES THE ERROR V V V
        final validFeatures = _featureControllers
            .map((controller) => controller.text.trim())
            .where((feature) => feature.isNotEmpty)
            .toList();

        if (validFeatures.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A minimum of two features are required.'), backgroundColor: errorColor));
          return;
        }


        setState(() => _isSubmitting = true);
        try {
          final duplicateError = await _checkForDuplicates();
          if (duplicateError != null) {
            setState(() { _errorText = duplicateError; _isSubmitting = false; });
            return;
          }
          // --- DYNAMIC POLICY URL LOGIC ---
          String? finalPolicyUrl;
          if (_useDefaultPolicy) {
            // If the user chose the template, use the fetched default URL.
            finalPolicyUrl = _defaultPolicyUrl;
          } else {
            // Otherwise, upload their custom file.
            finalPolicyUrl = await _uploadFile(_policyPdfFile, 'partner_policies');
          }
          final idFrontUrl = await _uploadFile(_idFrontFile, 'id_proofs');
          final utilityBillUrl = await _uploadFile(_utilityBillFile, 'utility_bills');
          final idWithSelfieUrl = await _uploadFile(_idWithSelfieFile, 'selfies');
          final policyPdfUrl = await _uploadFile(_policyPdfFile, 'partner_policies'); // <-- UPLOAD THE PDF

          _uploadedLogoUrl = await _uploadImage(_imageBytes, 'company_logos');
          List<String> imageUrls = [];
          for (var dataUrl in _imagePaths) {
            final bytes = base64Decode(dataUrl.split(',').last);
            final ref = FirebaseStorage.instance.ref().child('service_images').child('${DateTime.now().millisecondsSinceEpoch}.png');
            imageUrls.add(await (await ref.putData(bytes)).ref.getDownloadURL());
          }
          final collectionRef = FirebaseFirestore.instance.collection('users-sp-boarding');
          final docRef = collectionRef.doc();

          // Example: _coordController.text = "12.9716,77.5946"
          final coordText = _coordController.text.trim();
          final parts = coordText.split(',');

          GeoPoint geoPoint = GeoPoint(
            double.parse(parts[0]), // latitude
            double.parse(parts[1]), // longitude
          );
          // ✨ NEW: Initialize maps for the pre-calculated standard and offer prices.
          final Map<String, Map<String, int>> preCalculatedStandardPrices = {};
          final Map<String, Map<String, int>> preCalculatedOfferPrices = {};

          // This loop now populates our new maps.
          for (var petName in _selectedPets) {
            final petKey = petName.toLowerCase();
            if (!_petSizeConfigs.containsKey(petKey)) continue;

            // 💡 TWEAK 1: Define the selected sizes list
            final selectedDisplaySizes = _selectedPetDetails[petKey]?['sizes'] ?? [];
            final List<String> selectedSizeKeys = selectedDisplaySizes.map((displayText) {
              return displayText.split(' ')[0];
            }).toList();

            // If no sizes selected, skip the rate calculation part for this pet (since validation should have caught this)
            if (selectedSizeKeys.isEmpty) continue;

            final List<String> sizesToProcess = selectedSizeKeys;

            // Calculate total prices for standard rates
            final Map<String, String> totalPricesMap = {};
            // 💡 TWEAK 2: Loop over selectedSizeKeys
            for (var size in sizesToProcess) {
              final dailyRate = int.tryParse(
                  _getSafeRate(_dailyPriceCtrls, petKey, size)) ?? 0;
              final walkingRate = int.tryParse(
                  _getSafeRate(_WalkingPriceCtrls, petKey, size)) ?? 0;
              final mealRate = int.tryParse(
                  _getSafeRate(_MealPriceCtrls, petKey, size)) ?? 0;
              totalPricesMap[size] =
                  (dailyRate + walkingRate + mealRate).toString();
            }

            // Calculate total prices for offer rates
            final Map<String, String> totalOfferPricesMap = {};
            // 💡 TWEAK 3: Loop over selectedSizeKeys
            for (var size in sizesToProcess) {
              final offerDailyRate = int.tryParse(
                  _getSafeRate(_OfferdailyPriceCtrls, petKey, size)) ?? 0;
              final offerWalkingRate = int.tryParse(
                  _getSafeRate(_OfferWalkingPriceCtrls, petKey, size)) ?? 0;
              final offerMealRate = int.tryParse(
                  _getSafeRate(_OfferMealPriceCtrls, petKey, size)) ?? 0;
              totalOfferPricesMap[size] =
                  (offerDailyRate + offerWalkingRate + offerMealRate).toString();
            }

            // ✨ NEW: Populate the maps with the calculated totals for each size.
            // We convert the string values to integers here for clean data.
            preCalculatedStandardPrices[petKey] =
                totalPricesMap.map((key, value) =>
                    MapEntry(key, int.tryParse(value) ?? 0));
            preCalculatedOfferPrices[petKey] =
                totalOfferPricesMap.map((key, value) =>
                    MapEntry(key, int.tryParse(value) ?? 0));
          }
          // ✅ TWEAK HERE: Use owner_phone for dashboard_whatsapp if the checkbox is checked.
          final String finalDashboardWhatsapp = _isWhatsappSameAsPhone
              ? _phoneCtrl.text.trim()
              : _whatsappController.text.trim();

          final mainPayload = {
            'shop_name_lowercase': _shopNameCtrl.text.trim().toLowerCase(), // For efficient querying
            'pre_calculated_standard_prices': preCalculatedStandardPrices,
            'pre_calculated_offer_prices': preCalculatedOfferPrices,
            'testament_declaration': {'agreed': true, 'uid': widget.uid, 'timestamp': FieldValue.serverTimestamp(), 'user_agent': html.window.navigator.userAgent, 'declaration_text': _testamentText,},
            'type': widget.runType,
            'adminApproved': false,
            'admin_verification_status': false,
            'display': false,
            'isOfferActive': false,
            'mfp_certified': true,
            'owner_name': _ownerNameCtrl.text.trim(),
            'notification_email': _emailCtrl.text.trim(),
            'login_email': widget.email,
            'owner_phone': _phoneCtrl.text.trim(),
            'id_url': idFrontUrl ?? '', 'utility_bill_url': utilityBillUrl ?? '', 'id_with_selfie_url': idWithSelfieUrl ?? '',
            'shop_name': _shopNameCtrl.text.trim(), 'shop_logo': _uploadedLogoUrl ?? '',
            'bank_ifsc': _ifscCtrl.text.trim(), 'bank_account_num': _accountCtrl.text.trim(), 'pan': _panCtrl.text.trim(), 'gstin': _gstinCtrl.text.trim(),
            'dashboard_phone': _phoneController.text.trim(), 'dashboard_whatsapp': finalDashboardWhatsapp,
            'description': _descriptionController.text.trim(), 'features': validFeatures, 'full_address': _locationController.text.trim(),
            "refund_policy": { for (var p in percentages) p: _RefundCtrls[p]!.text.trim() },
            'max_pets_allowed': _maxPetsController.text.trim(), 'max_pets_allowed_per_hour': _maxPetsPerHourController.text.trim(),
            'open_time': _openTime?.format(context) ?? '', 'close_time': _closeTime?.format(context) ?? '',
            'location_geopoint': geoPoint,
            'shop_location': geoPoint,
            'street': _streetController.text.trim(),
            'postal_code': _postalCodeController.text.trim(), 'area_name': _areaNameController.text.trim(), 'district': _districtController.text.trim(), 'state': _stateController.text.trim(),
            'employees': _employees,
            'image_urls': imageUrls,
            'pets': _selectedPets,
            'pet_types': _selectedPetTypes,
            // ✅ USE THE FINAL URL HERE
            'partner_policy_url': finalPolicyUrl ?? '',
            'service_id': docRef.id,
            'shop_user_id': widget.uid,
            'admin_contract_pdf_update_approve': true,
            'created_at': FieldValue.serverTimestamp(),
          };
          await docRef.set(mainPayload);

          // --- SUBCOLLECTION PAYLOAD CALCULATION ---
          // This helper function filters the rate controller map to only include selected sizes
          Map<String, String> filterAndFormatRates(Map<String, Map<String, TextEditingController>> sourceMap, List<String> sizesToProcess, String petKey) {
            final Map<String, String> filteredRates = {};
            for (var size in sizesToProcess) {
              final controller = sourceMap[petKey]?[size];
              if (controller != null) {
                filteredRates[size] = controller.text.trim();
              }
            }
            return filteredRates;
          }

          for (var petName in _selectedPets) {
            final petKey = petName.toLowerCase();
            if (!_petSizeConfigs.containsKey(petKey)) continue;

            // 💡 TWEAK 4: Re-calculate the selected sizes to use in the subcollection payload
            final selectedDisplaySizes = _selectedPetDetails[petKey]?['sizes'] ?? [];
            final List<String> sizesToProcess = selectedDisplaySizes.map((displayText) {
              return displayText.split(' ')[0];
            }).toList();

            // If no sizes selected, skip this pet's subcollection entirely
            if (sizesToProcess.isEmpty) continue;

            final petConfig = _petSizeConfigs[petKey];

            // 🔽 START OF NEW CODE (Old calculation logic is now obsolete/replaced by filterAndFormatRates) 🔽
            // 1. Calculate the standard total prices map (No longer needed here, using pre-calculated maps)
            // 2. Calculate the offer total prices map (No longer needed here, using pre-calculated maps)
            // 🔼 END OF NEW CODE 🔼

            final petDataPayload = {
              // 💡 TWEAK 5: Use the filtered/formatted maps here:
              "rates_daily": filterAndFormatRates(_dailyPriceCtrls, sizesToProcess, petKey),
              "walking_rates": filterAndFormatRates(_WalkingPriceCtrls, sizesToProcess, petKey),
              "meal_rates": filterAndFormatRates(_MealPriceCtrls, sizesToProcess, petKey),
              "offer_daily_rates": filterAndFormatRates(_OfferdailyPriceCtrls, sizesToProcess, petKey),
              "offer_meal_rates": filterAndFormatRates(_OfferMealPriceCtrls, sizesToProcess, petKey),
              "offer_walking_rates": filterAndFormatRates(_OfferWalkingPriceCtrls, sizesToProcess, petKey),

              // This pulls the already-filtered data from the maps populated earlier in the main loop
              "total_prices": preCalculatedStandardPrices[petKey]!,
              "total_offer_prices": preCalculatedOfferPrices[petKey]!,

              "feeding_details": {
                for (var mealObject in List<Map<String, dynamic>>.from(petConfig['feeding_schedule'] ?? []))
                  mealObject['section_title']: {
                    for (var fieldData in List<Map<String, dynamic>>.from(mealObject['fields'] ?? []))
                      fieldData['field_name']: _getFieldValueForSubmission(petKey, mealObject['section_title'], fieldData, mealImageUrls),
                  }
              },
              'name': petConfig['name'] ?? petName,
              'sizes': sizesToProcess, // 💡 TWEAK 6: Use only the selected sizes here for the subcollection doc
              'accepted_sizes': _selectedPetDetails[petKey]?['sizes'] ?? [],
              'accepted_breeds': _selectedPetDetails[petKey]?['breeds'] ?? [],
            };
            await docRef.collection('pet_information').doc(petKey).set(petDataPayload);
          }

          // --- Step 4: Finalization and Navigation ---
          await updateBranchLinks(docRef.id, widget.serviceId);
          if (mounted) {
            await Provider.of<UserNotifier>(context, listen: false).refreshUserProfile();
            final userNotifier = Provider.of<UserNotifier>(context, listen: false);

            if (userNotifier.authState == AuthState.authenticated && userNotifier.me != null) {
              final serviceId = userNotifier.me!.serviceId;

              // 🚀 REPLACING context.go('/partner/$serviceId/profile')
              // We use pushAndRemoveUntil here to clear the navigation history
              // (e.g., login screens) below the main dashboard.
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => PartnerShell(
                    serviceId: serviceId, // serviceId is guaranteed non-null here
                    currentPage: PartnerPage.profile, // Directing to the main profile page
                    child: BoardingDetailsLoader(serviceId: serviceId), // The widget that loads the profile content
                  ),
                ),
                    (Route<dynamic> route) => false, // Clears the history
              );
            }
          }
        } catch (e, st) {
          print('SUBMISSION FAILED: $e');
          print(st);
          if(mounted) setState(() => _errorText = 'Submission error: $e');
        } finally {
          if (mounted) setState(() => _isSubmitting = false);
        }
      }
      // --- END NON-UI LOGIC ---

      // --- VISUAL REFRESH: REBUILT WIDGETS ---
      Widget _buildFileUploadField({
        required String title,
        required String description,
        required VoidCallback onUploadTap,
        required FileUploadData? fileData,
        bool isSelfie = false,
      }) {
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

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

// 🔽🔽🔽 CORRECTED FUNCTION SIGNATURE (Removed argument, using State context) 🔽🔽🔽
      Widget _buildFancyStepIndicator() {
        // Assuming primaryColor and successColor are defined in the file scope
        const Color primaryColor = Color(0xFF2CB4B6);
        const Color successColor = Colors.greenAccent;

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
                padding: const EdgeInsets.only(bottom: 20),
                child:
                // --- White Circle Wrapper ---
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white, // The white background
                    shape: BoxShape.circle,
                    // Optional: Add a subtle shadow
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: IconButton(
                    // Change the icon color to black to contrast with the white circle
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    // We use some padding here for spacing within the circle.
                    padding: const EdgeInsets.all(8),
                    // Remove constraints since the Container is defining the size/shape
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child:
                    // ----------------------
                    Text(
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
                  // NOTE: _stepTitles is a state variable and is now correctly accessible
                  itemCount: _stepTitles.length,
                  itemBuilder: (context, i) {
                    // 🚀 FIX: _currentStep and _highestStepReached are State variables,
                    // no need for local declaration, solving the original error.
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
                                      _stepSubtitles[i], // NOTE: This also relies on being a State variable
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
// ---------------------------------------------------------------------------------

// You must also fix the call site (where this widget is used):
// Find this line (previously line 4170)
// _buildFancyStepIndicator(context),
// And change it to:
// _buildFancyStepIndicator(),


      Widget _buildCurrentStepContent({required bool isDesktop}) {
        switch (_currentStep) {
        // Pass 'isDesktop' down to the relevant step method
          case 0: return _buildBasicDetailsStep(isDesktop: isDesktop);
          case 1: return _buildServiceInfoStep(isDesktop: isDesktop);
          case 2: return _buildDashboardSetupStep(isDesktop: isDesktop);
          case 3: return _buildReviewAndConfirmStep(isDesktop: isDesktop);
          default: return const SizedBox.shrink();
        }
      }

      Widget _buildBasicDetailsStep({required bool isDesktop}) {

        final bool showSeparateWhatsapp = !_isWhatsappSameAsPhone;

        final bool isPhoneVerificationInProgress = _phoneOtpSent && !_phoneVerified;
        final bool isWhatsappVerificationInProgress = _whatsappOtpSent && !_whatsappVerified;

        // A field is "active" if the user has typed in it, but an OTP has not yet been sent.
        final bool isPhoneFieldActive = _phoneCtrl.text.trim().isNotEmpty && !_phoneOtpSent;
        final bool isWhatsappFieldActive = _whatsappController.text.trim().isNotEmpty && !_whatsappOtpSent;



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

                // --- PHONE & WHATSAPP ROW/COLUMN ---
                // We will manage the logic here to simplify the inner row/column block.
                Column(
                  children: [
                    // 1. Owner's Phone (Always visible)
                    showSeparateWhatsapp && (isWhatsappFieldActive || isWhatsappVerificationInProgress)
                        ? _buildDisabledVerificationPlaceholder("Complete WhatsApp verification first.")
                        : _buildPhoneVerificationSection(),

                    const SizedBox(height: 16),

                    // 2. Checkbox: Is WhatsApp Same as Phone?
                    CheckboxListTile(
                      title: Text(
                        "WhatsApp Number is same as Owner's Phone Number",
                        style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                      ),
                      value: _isWhatsappSameAsPhone,
                      onChanged: (bool? value) {
                        setState(() {
                          _isWhatsappSameAsPhone = value ?? false;
                          // If they check the box, we can assume the WhatsApp is 'verified' by phone's verification
                          if (_isWhatsappSameAsPhone) {
                            // Reset the separate WhatsApp flow
                            _whatsappResendTimer?.cancel();
                            _whatsappOtpSent = false;
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

                    // 3. WhatsApp Number (Conditional visibility)
                    if (showSeparateWhatsapp)
                      isDesktop
                          ? (isPhoneFieldActive || isPhoneVerificationInProgress)
                          ? _buildDisabledVerificationPlaceholder("Complete Owner's Phone verification first.")
                          : _buildWhatsappVerificationSection()
                          : (isPhoneFieldActive || isPhoneVerificationInProgress)
                          ? _buildDisabledVerificationPlaceholder("Complete Owner's Phone verification first.")
                          : _buildWhatsappVerificationSection(),
                  ],
                ),
                // --- END PHONE & WHATSAPP ROW/COLUMN ---

                const SizedBox(height: 16),
                _buildTextFormField(controller: _panCtrl, label: "PAN*", icon: Icons.credit_card_outlined, validator: (v) => v == null || v.trim().isEmpty ? "Required" : null),
              ],
            ),
            // ... (rest of the widget remains unchanged)
            _buildSectionContainer(
              title: "Verification Documents",
              children: [
                isDesktop
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFileUploadField(title: "Government ID*", description: "Aadhar, Passport, etc. (Image or PDF)", fileData: _idFrontFile, onUploadTap: () => _pickFile((file) => setState(() => _idFrontFile = file)))),
                    const SizedBox(width: 24),
                    Expanded(child: _buildFileUploadField(title: "ID with Selfie*", description: "A clear photo of you holding your ID", fileData: _idWithSelfieFile, isSelfie: true, onUploadTap: () async {
                      final bytes = await showDialog<Uint8List>(context: context, builder: (_) => const WebcamSelfieWidget());
                      if (bytes != null) {
                        // ✅ FIX: Use a unique timestamp for the file name
                        final uniqueFileName = 'selfie-${DateTime.now().millisecondsSinceEpoch}.jpg';
                        setState(() => _idWithSelfieFile = FileUploadData(bytes: bytes, name: uniqueFileName, type: 'image'));
                      }
                    })),
                  ],
                )
                    : Column(
                  children: [
                    _buildFileUploadField(title: "Government ID*", description: "Aadhar, Passport, etc. (Image or PDF)", fileData: _idFrontFile, onUploadTap: () => _pickFile((file) => setState(() => _idFrontFile = file))),
                    const SizedBox(height: 24),
                    _buildFileUploadField(title: "ID with Selfie*", description: "A clear photo of you holding your ID", fileData: _idWithSelfieFile, isSelfie: true, onUploadTap: () async {
                      final bytes = await showDialog<Uint8List>(context: context, builder: (_) => const WebcamSelfieWidget());
                      if (bytes != null) {
                        // ✅ FIX: Use a unique timestamp for the file name
                        final uniqueFileName = 'selfie-${DateTime.now().millisecondsSinceEpoch}.jpg';
                        setState(() => _idWithSelfieFile = FileUploadData(bytes: bytes, name: uniqueFileName, type: 'image'));
                      }
                    }),
                  ],
                ),
                const SizedBox(height: 24),
                isDesktop
                    ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFileUploadField(title: "Utility Bill*", description: "Latest electricity, gas, or water bill", fileData: _utilityBillFile, onUploadTap: () => _pickFile((file) => setState(() => _utilityBillFile = file)))),
                    const SizedBox(width: 24),
                    const Expanded(child: SizedBox()),
                  ],
                )
                    : _buildFileUploadField(title: "Utility Bill*", description: "Latest electricity, gas, or water bill", fileData: _utilityBillFile, onUploadTap: () => _pickFile((file) => setState(() => _utilityBillFile = file))),
              ],
            )
          ],
        );
      }

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

// 🔽🔽🔽 PASTE THIS ENTIRE NEW WIDGET 🔽🔽🔽
      Widget _buildDisabledVerificationPlaceholder(String message) {
        return Container(
          // An explicit height to prevent layout shifts
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

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // 🔽🔽🔽 REPLACE your entire _buildServiceInfoStep method with this 🔽🔽🔽
      Widget _buildServiceInfoStep({required bool isDesktop}) {
        return _buildSectionContainer(
          title: "Brand & Company Information",
          children: [
            if (isDesktop)
            // DESKTOP LAYOUT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ THIS IS THE CORRECTED WIDGET FOR DESKTOP
                        _buildTextFormField(
                          controller: _shopNameCtrl,
                          label: "Brand Name*",
                          icon: Icons.store_outlined,
                          onChanged: (value) => _shopNameDebouncer.run(() => _validateShopName(value)),
                          errorText: _shopNameErrorText,
                          suffixIcon: _isCheckingShopName ? const CircularProgressIndicator(strokeWidth: 2) : null,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Required";
                            return _shopNameErrorText;
                          },
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "This name will be visible to all pet parents.", // Corrected subtitle
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Brand Logo*", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Container(
                            height: 142,
                            width: double.infinity,
                            decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                            child: _imageBytes != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(_imageBytes!, fit: BoxFit.contain))
                                : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              )
            else
            // MOBILE LAYOUT
              Column(
                children: [
                  // ✅ THIS IS THE CORRECTED WIDGET FOR MOBILE
                  _buildTextFormField(
                    controller: _shopNameCtrl,
                    label: "Brand Name*",
                    icon: Icons.store_outlined,
                    onChanged: (value) => _shopNameDebouncer.run(() => _validateShopName(value)),
                    errorText: _shopNameErrorText,
                    suffixIcon: _isCheckingShopName ? const CircularProgressIndicator(strokeWidth: 2) : null,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Required";
                      return _shopNameErrorText;
                    },
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "This name will be visible to all pet parents.", // Corrected subtitle
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Brand Logo*", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          height: 142,
                          width: double.infinity,
                          decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
                          child: _imageBytes != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(_imageBytes!, fit: BoxFit.contain))
                              : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
          ],
        );
      }

      // ADD THIS NEW HELPER WIDGET
      // ADD THIS NEW WIDGET FOR THE REFUND POLICY FIELDS
      Widget _buildResponsivePolicyField({
        required bool isDesktop,
        required TextEditingController controller,
        required String key,
      }) {
        final label = _formatRefundPolicyLabel(key);

        // The text input part of the widget
        final textField = TextFormField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          validator: (val) {
            if (val == null || val.isEmpty) return 'Enter %';
            final n = int.tryParse(val);
            if (n == null || n < 0 || n > 100) return '0-100';
            return null;
          },
          decoration: InputDecoration(
            hintText: "%",
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
          ),
        );

        // The label part of the widget
        final labelWidget = Text(
          label,
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500),
        );

        if (isDesktop) {
          // DESKTOP: Icon, Label, and TextField in a Row
          return Row(
            children: [
              const Icon(Icons.percent_outlined, color: subtleTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: labelWidget),
              const SizedBox(width: 12),
              SizedBox(width: 80, child: textField),
            ],
          );
        } else {
          // MOBILE: Label on top, TextField below
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: 8),
              SizedBox(width: 100, child: textField),
            ],
          );
        }
      }

      // In _HomeboarderonboardpageState
      // 🔽🔽🔽 ALSO REPLACE THIS METHOD 🔽🔽🔽
      Widget _buildResponsiveRateFields({
        required bool isDesktop,
        required Map<String, TextEditingController> controllers,
        required String labelSuffix,
        required IconData icon,
        required List<String> petSizes,
        required Map<String, dynamic> sizeLabels,
      }) {
        List<Widget> fields = petSizes.map((s) {
          // This now receives the modified map with the correct "Giant" label
          final weightRange = sizeLabels[s] as String? ?? '';
          final labelText = weightRange.isNotEmpty ? '$weightRange kg' : '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFormField(
                controller: controllers[s]!,
                label: '$s pets ($labelSuffix)',
                icon: icon,
                keyboardType: TextInputType.number,
              ),
              if (labelText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                  child: Text(
                    labelText,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          );
        }).toList();

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields
                .map((field) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: field,
              ),
            ))
                .toList(),
          );
        } else {
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: fields.map((field) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width / 2) - 40,
                child: field,
              );
            }).toList(),
          );
        }
      }

      // REPLACE your entire _buildDashboardSetupStep method with this one

      Widget _buildDashboardSetupStep({required bool isDesktop}) {
        if (_isLoadingConfigs) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildSectionContainer(
              title: "Service Location & Details",
              children: [
                _buildTextFormField(controller: _descriptionController, label: 'Service Description*', icon: Icons.description_outlined, maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildAddressSearchField(),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 350,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 4),
                      onTap: _onMapTap,
                      markers: _selectedMarker != null ? {_selectedMarker!} : {},
                      onMapCreated: (c) => _mapController = c,
                    ),
                  ),
                ),
                // ... all your responsive address fields are still here ...
                const SizedBox(height: 16),
                isDesktop ? Row(
                    children: [
                      Expanded(child: _buildTextFormField(controller: _coordController, label: 'Coordinates (lat, lng)', icon: Icons.location_on_outlined, readOnly: true, validator: (v) => v == null || v.isEmpty ? 'Required' : null)), const SizedBox(width: 16),
                      Expanded(child: _buildTextFormField(controller: _streetController, label: 'Street', icon: Icons.signpost_outlined, readOnly: true))
                    ]
                ) : Column(
                  children: [
                    _buildTextFormField(controller: _coordController, label: 'Coordinates (lat, lng)', icon: Icons.location_on_outlined, readOnly: true, validator: (v) => v == null || v.isEmpty ? 'Required' : null), const SizedBox(height: 16),
                    _buildTextFormField(controller: _streetController, label: 'Street', icon: Icons.signpost_outlined, readOnly: true)
                  ],
                ),
                const SizedBox(height: 16),
                isDesktop ? Row(
                  children: [
                    Expanded(child: _buildTextFormField(controller: _areaNameController, label: 'Area', icon: Icons.location_city_outlined, readOnly: true)), const SizedBox(width: 16),
                    Expanded(child: _buildTextFormField(controller: _districtController, label: 'District', icon: Icons.map_outlined, readOnly: true))
                  ],
                ) : Column(
                  children: [
                    _buildTextFormField(controller: _areaNameController, label: 'Area', icon: Icons.location_city_outlined, readOnly: true), const SizedBox(height: 16),
                    _buildTextFormField(controller: _districtController, label: 'District', icon: Icons.map_outlined, readOnly: true)
                  ],
                ),
                const SizedBox(height: 16),
                isDesktop ? Row(
                  children: [
                    Expanded(child: _buildTextFormField(controller: _stateController, label: 'State', icon: Icons.flag_outlined, readOnly: true)), const SizedBox(width: 16),
                    Expanded(child: _buildTextFormField(controller: _postalCodeController, label: 'Postal Code', icon: Icons.local_post_office_outlined, readOnly: true))
                  ],
                ) : Column(
                  children: [
                    _buildTextFormField(controller: _stateController, label: 'State', icon: Icons.flag_outlined, readOnly: true), const SizedBox(height: 16),
                    _buildTextFormField(controller: _postalCodeController, label: 'Postal Code', icon: Icons.local_post_office_outlined, readOnly: true)
                  ],
                ),
                const SizedBox(height: 24),
                isDesktop
                    ? Row(
                  children: [
                    Expanded(child: _buildTextFormField(controller: _maxPetsController, label: 'Max pets/day*', icon: Icons.pets_outlined, keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? "Required" : null)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextFormField(controller: _maxPetsPerHourController, label: 'Max pets/hour*', icon: Icons.hourglass_bottom_outlined, keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? "Required" : null))
                  ],
                )
                    : Column(
                  children: [
                    _buildTextFormField(controller: _maxPetsController, label: 'Max pets/day*', icon: Icons.pets_outlined, keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? "Required" : null),
                    const SizedBox(height: 16),
                    _buildTextFormField(controller: _maxPetsPerHourController, label: 'Max pets/hour*', icon: Icons.hourglass_bottom_outlined, keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? "Required" : null)
                  ],
                ),
                const SizedBox(height: 24),
                isDesktop
                    ? Row(
                  children: [
                    Expanded(child: _buildTimePicker('Open Time', _openTime, (t) => setState(() => _openTime = t))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTimePicker('Close Time', _closeTime, (t) => setState(() => _closeTime = t)))
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTimePicker('Open Time', _openTime, (t) => setState(() => _openTime = t)),
                    const SizedBox(height: 16),
                    _buildTimePicker('Close Time', _closeTime, (t) => setState(() => _closeTime = t)),
                  ],
                ),
                const SizedBox(height: 24),

                // The pet selector is now here, driving the UI below.
                _buildPetSelection(),

                const SizedBox(height: 24),

                _buildImagePicker(),
              ],
            ),

            // This section for Features remains unchanged.
            _buildSectionContainer(
                title: "Features & Amenities",
                children: [
                  _buildFeaturesSection(),
                ]
            ),

            // The "Policies & Capacity" section now contains the pet selector.
            _buildSectionContainer(
                title: "Policies & Capacity",
                children: [
                  Text("Refund Policy (% refund)", style: headerStyle),
                  const SizedBox(height: 12),
                  ...percentages.map((key) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildResponsivePolicyField(
                      isDesktop: isDesktop,
                      controller: _RefundCtrls[key]!,
                      key: key,
                    ),
                  )),

                  const SizedBox(height: 24),

                  _buildPolicySelector(),

  // ...
                  // ^ ^ ^ END OF NEW SECTION ^ ^ ^

                ]
            ),

            // 3. This new widget call will dynamically build the rate sections
            //    based on the pets selected above.
            _buildDynamicPetSections(isDesktop: isDesktop),
          ],
        );
      }

      Widget _buildTextFormField({
        required TextEditingController controller, required String label, required IconData icon, int maxLines = 1,
        TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator,
        bool readOnly = false, Widget? suffixIcon, String? prefixText, String? errorText, void Function(String)? onChanged,
      }) {
        return TextFormField(
          controller: controller, style: GoogleFonts.poppins(fontSize: 14, color: textColor),
          keyboardType: keyboardType, maxLines: maxLines, validator: validator, inputFormatters: inputFormatters, onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label, labelStyle: GoogleFonts.poppins(color: subtleTextColor),
            prefixText: prefixText, prefixStyle: GoogleFonts.poppins(fontSize: 14, color: textColor),
            prefixIcon: Icon(icon, color: subtleTextColor, size: 20), errorText: errorText,
            suffixIcon: suffixIcon != null ? Padding(padding: const EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: suffixIcon)) : null,
            filled: true, fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryColor, width: 2)),
          ),
        );
      }

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
            decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8), color: Colors.grey.shade50),
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

      void _onMapTap(LatLng position) {
        setState(() { _selectedMarker = Marker(markerId: const MarkerId('chosen'), position: position); _coordController.text = '${position.latitude}, ${position.longitude}'; });
        _reverseGeocode(position.latitude, position.longitude);
      }
      Future<void> _reverseGeocode(double lat, double lng) async {
        try {
          final jsResult = await js_util.promiseToFuture(js_util.callMethod(html.window, 'reverseGeocodeJs', [lat.toString(), lng.toString()]));
          setState(() {
            _streetController.text = js_util.getProperty(jsResult, 'street');
            _postalCodeController.text = js_util.getProperty(jsResult, 'postalCode');
            _areaNameController.text = js_util.getProperty(jsResult, 'area');
            _districtController.text = js_util.getProperty(jsResult, 'district');
            _stateController.text = js_util.getProperty(jsResult, 'state');
          });
        } catch (e) { print('Reverse‐geocode JS error: $e'); }
      }
      Future<void> _getCurrentLocationAndPin() async {
        try {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          final latLng = LatLng(pos.latitude, pos.longitude);
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
          _onMapTap(latLng);
        } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not get location: $e"))); }
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
              setState(() { _selectedMarker = Marker(markerId: const MarkerId('selected-place'), position: coord); _coordController.text = '${coord.latitude}, ${coord.longitude}'; });
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
            if (_imagePaths.length + files.length > 5) {
              if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can select up to 5 images only')));
              return;
            }
            for (final file in files) {
              final reader = html.FileReader();
              reader.onLoadEnd.listen((_) {
                if (reader.result != null) setState(() => _imagePaths.add(reader.result as String));
              });
              reader.readAsDataUrl(file);
            }
          });
        } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick images: $e'))); }
      }

      // In _HomeboarderonboardpageState

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // 🔽🔽🔽 REPLACE your entire _buildDynamicPetSections method with this 🔽🔽🔽
      Widget _buildDynamicPetSections({required bool isDesktop}) {
        if (_selectedPets.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: _selectedPets.map((petName) {
            final petKey = petName.toLowerCase();
            final config = _petSizeConfigs[petKey];
            if (config == null) return const SizedBox.shrink();

            final String petDetailsTitle = config['name'];
            final List<String> allPossibleSizes = List<String>.from(config['sizes']);
            final Map<String, dynamic> sizeLabels = Map<String, dynamic>.from(config['size_labels'] ?? {});

            final selectedDisplaySizes = _selectedPetDetails[petKey]?['sizes'] ?? [];

            final List<String> selectedSizeKeys = selectedDisplaySizes.map((displayText) {
              return displayText.split(' ')[0];
            }).toList();

            String giantLabelText = '40+';
            final largeLabel = sizeLabels['Large'] as String?;
            if (largeLabel != null && largeLabel.contains('-')) {
              final maxValueStr = largeLabel.split('-').last.trim();
              final maxValue = int.tryParse(maxValueStr);
              if (maxValue != null) {
                giantLabelText = '${maxValue + 1}+';
              }
            }

            final displayLabels = Map<String, dynamic>.from(sizeLabels);
            displayLabels['Giant'] = giantLabelText;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor, width: 1.5),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.pets, color: Colors.black87),
                  ),
                  title: Text(petDetailsTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)),
                  subtitle: Text("Tap to expand details", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                  children: [
                    _buildSectionContainer(
                      title: "Accepted Varieties for $petDetailsTitle",
                      children: [
                        _buildMultiSelectDropdown(
                          title: 'Accepted Sizes',
                          items: allPossibleSizes.map((size) {
                            final weightLabel = displayLabels[size] as String? ?? '';
                            final displayText = weightLabel.isNotEmpty ? '$size ($weightLabel kg)' : size;
                            return MultiSelectItem<String>(displayText, displayText);
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
                            final List<Map<String, String>> availableBreeds = snapshot.data ?? [];
                            return _buildMultiSelectDropdown(
                              title: 'Accepted Breeds',
                              items: availableBreeds.map((breed) => MultiSelectItem<String>(breed['name']!, breed['name']!)).toList(),
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
                    if (selectedSizeKeys.isNotEmpty) ...[
                      _buildSectionContainer(
                        title: "Service Rates for $petDetailsTitle",
                        children: [
                          Text("Daily Rates", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _dailyPriceCtrls[petKey]!,
                            labelSuffix: '₹/day',
                            icon: Icons.currency_rupee,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                          const SizedBox(height: 16),
                          Text("Walking Fee", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _WalkingPriceCtrls[petKey]!,
                            labelSuffix: '₹/hr',
                            icon: Icons.directions_walk,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                          const SizedBox(height: 16),
                          Text("Meals Fee", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _MealPriceCtrls[petKey]!,
                            labelSuffix: '₹/meal',
                            icon: Icons.restaurant,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                        child: Center(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy_all_outlined, size: 18),
                            label: const Text("Copy Standard Rates to Offers"),
                            onPressed: () => _copyRatesToOffers(petKey, selectedSizeKeys),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: const BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      _buildSectionContainer(
                        title: "Offer Rates for $petDetailsTitle (Optional)",
                        children: [
                          Text("Offer Daily Rates", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _OfferdailyPriceCtrls[petKey]!,
                            labelSuffix: '₹/day',
                            icon: Icons.local_offer_outlined,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                          const SizedBox(height: 16),
                          Text("Offer Walking Fee", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _OfferWalkingPriceCtrls[petKey]!,
                            labelSuffix: '₹/hr',
                            icon: Icons.local_offer_outlined,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                          const SizedBox(height: 16),
                          Text("Offer Meals Fee", style: headerStyle),
                          const SizedBox(height: 8),
                          _buildResponsiveRateFields(
                            isDesktop: isDesktop,
                            controllers: _OfferMealPriceCtrls[petKey]!,
                            labelSuffix: '₹/meal',
                            icon: Icons.local_offer_outlined,
                            petSizes: selectedSizeKeys,
                            sizeLabels: displayLabels,
                          ),
                        ],
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            "Please select 'Accepted Sizes' above to set the rates.",
                            style: GoogleFonts.poppins(color: subtleTextColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ...List<Map<String, dynamic>>.from(config['feeding_schedule'] ?? []).map((mealObject) {
                      final mealTitle = mealObject['section_title'] as String;
                      final List<dynamic> fields = mealObject['fields'];
                      return _buildSectionContainer(
                        title: mealTitle,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 600;
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...fields.where((f) => f['field_type'] == 'text').map((fieldData) {
                                            final fieldName = fieldData['field_name'];
                                            final label = fieldData['label'];
                                            final isRequired = fieldData['required'] as bool? ?? false;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 6.0),
                                              child: _buildTextFormField(
                                                label: label,
                                                icon: Icons.edit_note,
                                                controller: _mealFieldState[petKey]![mealTitle]![fieldName],
                                                validator: isRequired ? (v) => (v == null || v.isEmpty) ? "$label is required" : null : null,
                                              ),
                                            );
                                          }),
                                          ...fields.where((f) => f['field_type'] == 'points').map((fieldData) {
                                            final fieldName = fieldData['field_name'];
                                            final label = fieldData['label'];
                                            final isRequired = fieldData['required'] as bool? ?? false;
                                            final controllers = _mealFieldState[petKey]![mealTitle]![fieldName] as List<TextEditingController>;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 6.0),
                                              child: _buildPointsSection(label: label, controllers: controllers, isRequired: isRequired),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 1, child: _buildMealImagePicker(petKey, mealTitle)),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...fields.where((f) => f['field_type'] == 'text').map((fieldData) {
                                      final fieldName = fieldData['field_name'];
                                      final label = fieldData['label'];
                                      final isRequired = fieldData['required'] as bool? ?? false;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10.0),
                                        child: _buildTextFormField(
                                          label: label,
                                          icon: Icons.edit_note,
                                          controller: _mealFieldState[petKey]![mealTitle]![fieldName],
                                          validator: isRequired ? (v) => (v == null || v.isEmpty) ? "$label is required" : null : null,
                                        ),
                                      );
                                    }),
                                    ...fields.where((f) => f['field_type'] == 'points').map((fieldData) {
                                      final fieldName = fieldData['field_name'];
                                      final label = fieldData['label'];
                                      final isRequired = fieldData['required'] as bool? ?? false;
                                      final controllers = _mealFieldState[petKey]![mealTitle]![fieldName] as List<TextEditingController>;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10.0),
                                        child: _buildPointsSection(label: label, controllers: controllers, isRequired: isRequired),
                                      );
                                    }),
                                    const SizedBox(height: 10),
                                    _buildMealImagePicker(petKey, mealTitle),
                                  ],
                                );
                              }
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      }

      // 🔹 Dynamic Points Section (label + add button on same row)
      Widget _buildPointsSection({
        required String label,
        required List<TextEditingController> controllers,
        required bool isRequired,
      }) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Row with Label + Add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.black87, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.black87),
                    label: const Text(
                      "Add",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    onPressed: () => setState(() => controllers.add(TextEditingController())),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 🔹 List of dynamic point fields
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildTextFormField(
                      label: '#${index + 1}',
                      icon: Icons.check_circle_outline,
                      controller: controllers[index],
                      validator: isRequired && index == 0
                          ? (v) => (v == null || v.isEmpty)
                          ? 'At least one Meal Part / Ingredient is required'
                          : null
                          : null,
                      suffixIcon: controllers.length > 1
                          ? Padding(
                        padding: const EdgeInsets.only(right: 8.0), // adjust tap hitbox
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              controllers[index].dispose();
                              controllers.removeAt(index);
                            });
                          },
                          child: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                            size: 24, // ensure clickable size
                          ),
                        ),
                      )
                          : null,

                    ),
                  );
                },
              ),
            ],
          ),
        );
      }


  // 🔹 Meal Image Picker (modern card style)
      Widget _buildMealImagePicker(String petKey, String sectionTitle) {
        final fileData = _mealImages[petKey]![sectionTitle];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Meal Image (optional)",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              // Image preview container
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: fileData != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(fileData.bytes, fit: BoxFit.contain),
                )
                    : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        "No image selected",
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Upload button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_upload, size: 22,color: Colors.black87),
                  label: const Text(
                    "Upload Image",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87
                    ),
                  ),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null && result.files.single.bytes != null) {
                      final file = result.files.single;
                      setState(() => _mealImages[petKey]![sectionTitle] = FileUploadData(
                        bytes: file.bytes!,
                        name: file.name,
                        type: 'image',
                      ));
                    }
                  },
                ),
              ),

            ],
          ),
        );
      }


  // ADD this helper function to get the correct value for submission
      dynamic _getFieldValueForSubmission(String petKey, String sectionTitle, Map<String, dynamic> fieldData, Map<String, Map<String, String>> imageUrls) {
        final fieldName = fieldData['field_name'];
        final fieldType = fieldData['field_type'];

        switch (fieldType) {
          case 'text':
            return (_mealFieldState[petKey]![sectionTitle]![fieldName] as TextEditingController).text.trim();
          case 'points':
            return (_mealFieldState[petKey]![sectionTitle]![fieldName] as List<TextEditingController>)
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();
          case 'image':
            return imageUrls[petKey]?[sectionTitle] ?? '';
          default:
            return '';
        }
      }


      Widget _buildPetSelection() {
        // ADD THIS 'return' KEYWORD
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pets You Service*", style: headerStyle),
            const SizedBox(height: 8),

            // This is the main button the user taps
            InkWell(
              onTap: () {
                // This is where we show our custom bottom sheet
                _showPetSelectionBottomSheet(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Chip Display using a responsive Wrap widget
                    if (_selectedPets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedPets.map((pet) {
                            return Chip(
                              label: Text(pet, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor)),
                              backgroundColor: primaryColor.withOpacity(0.15),
                              deleteIcon: const Icon(Icons.close, size: 18, color: primaryColor),
                              onDeleted: () {
                                setState(() {
                                  _selectedPets.remove(pet);
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      )
                    else
                    // Show a placeholder when nothing is selected
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.pets_outlined, color: subtleTextColor),
                            const SizedBox(width: 12),
                            Text("Choose pets you can service...", style: GoogleFonts.poppins(color: subtleTextColor)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Simple validator text below the field
            if (_formKey.currentState?.validate() == false && _selectedPets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: Text(
                  "Please select at least one pet type",
                  style: GoogleFonts.poppins(color: errorColor, fontSize: 12),
                ),
              ),
          ],
        );
      }
      // ADD THIS NEW METHOD TO YOUR STATE CLASS
      void _showPetSelectionBottomSheet(BuildContext context) {
        showModalBottomSheet(
          context: context,
          // This gives us the sharp corners
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12.0),
              topRight: Radius.circular(12.0),
            ),
          ),
          // This makes the bottom sheet take up a reasonable amount of height
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          builder: (ctx) {
            // We use a StatefulWidget here so the user can see their selections live inside the sheet
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setSheetState) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        "Select Pets",
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 16),
                      // The scrollable list of pets
                      // Inside the StatefulBuilder of _showPetSelectionBottomSheet
                      Expanded(
                        child: ListView.builder(
                          itemCount: _petTypes.length,
                          itemBuilder: (context, index) {
                            final petType = _petTypes[index];
                            final isSelected = _selectedPets.contains(petType.id);
                            final isSelectable = petType.display; // Check the display flag

                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Text(
                                    petType.id,
                                    style: GoogleFonts.poppins(
                                      color: isSelectable ? textColor : Colors.grey, // Grey out text if not selectable
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Show "Coming Soon" chip if not selectable
                                  if (!isSelectable)
                                    Chip(
                                      label: Text(
                                        "Coming Soon",
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
                                      ),
                                      backgroundColor: Colors.blueGrey,
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    )
                                ],
                              ),
                              value: isSelected,
                              // Disable the checkbox if the pet is not selectable
                              onChanged: isSelectable
                                  ? (bool? value) {
                                setSheetState(() {
                                  if (value == true) {
                                    _selectedPets.add(petType.id);
                                  } else {
                                    _selectedPets.remove(petType.id);
                                  }
                                });
                                setState(() {}); // Update the main page UI
                              }
                                  : null, // Setting onChanged to null disables the checkbox
                              activeColor: primaryColor,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close the bottom sheet
                          },
                          child: const Text("CONFIRM"),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
      Widget _buildMobileLayout() {
        return Form(
          key: _formKey,
          child: Column(
            children: [
              // The new, compact stepper for mobile
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
              // Footer for mobile
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
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The dark, fancy sidebar stepper
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
                    // Footer for desktop
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

      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

  // PASTE THIS NEW METHOD into your state class
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

      void _copyRatesToOffers(String petKey, List<String> selectedSizeKeys) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied standard rates to offer rates for $petKey.'),
            backgroundColor: successColor,
          ),
        );

        setState(() {
          for (var sizeKey in selectedSizeKeys) {
            // CORRECT: Daily -> Offer Daily
            _OfferdailyPriceCtrls[petKey]![sizeKey]!.text =
                _dailyPriceCtrls[petKey]![sizeKey]!.text;

            // CORRECT: Walking -> Offer Walking
            _OfferWalkingPriceCtrls[petKey]![sizeKey]!.text =
                _WalkingPriceCtrls[petKey]![sizeKey]!.text;

            // CORRECT: Meal -> Offer Meal
            _OfferMealPriceCtrls[petKey]![sizeKey]!.text =
                _MealPriceCtrls[petKey]![sizeKey]!.text;
          }
        });
      }

      // --- END VISUAL REFRESH ---

      @override
      Widget build(BuildContext context) {
        // We use the primaryColor and textColor variables defined in your code
        const Color primaryColor = Color(0xFF2CB4B6);
        const Color textColor = Colors.black87;

        return Scaffold(
          backgroundColor: Colors.white,

          // 🚀 FIXED: Wrapped the LayoutBuilder logic inside PreferredSize.
          appBar: PreferredSize(
            // Set the standard height of an AppBar
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // We check the width here. I've set the breakpoint to 760px.
                final bool isDesktop = constraints.maxWidth > 760;

                // Only return an AppBar if we are NOT on desktop
                if (!isDesktop) {
                  return AppBar(
                    // Back Arrow with Pop functionality
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: textColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    // Title for the onboarding flow
                    title: Text(
                      'Partner Onboarding',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor),
                    ),
                    backgroundColor: Colors.white,
                    foregroundColor: textColor,
                    elevation: 1,
                  );
                }
                // Return an empty/zero-sized widget when on desktop
                return const SizedBox.shrink();
              },
            ),
          ),

          // The main body remains the same
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth > 760;

              if (isDesktop) {
                // If the screen is WIDE, return the desktop layout
                return _buildDesktopLayout();
              } else {
                // If the screen is NARROW, return the new mobile layout
                return _buildMobileLayout();
              }
            },
          ),
        );
      }

      // lib/screens/HomeBoarderOnboardPage.dart -> in _HomeboarderonboardpageState

    // V V V PASTE THIS ENTIRE FUNCTION INTO YOUR STATE CLASS V V V
      // REPLACE your entire _validateCurrentStep method with this one

      bool _validateCurrentStep() {
        // 1. This handles all TextFormField validators (Description, Rates, Policies, etc.)
        if (!_formKey.currentState!.validate()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please correct the errors shown on the screen.'),
              backgroundColor: errorColor));
          return false;
        }

        // 2. This handles everything else that isn't a standard text field
        final List<String> validationErrors = [];
        switch (_currentStep) {
          case 0: // Basic Details
            if (!_emailVerified) validationErrors.add('Verified Email');
            if (_idFrontFile == null) validationErrors.add('Government ID');
            if (_idWithSelfieFile == null) validationErrors.add('ID with Selfie');
            if (_utilityBillFile == null) validationErrors.add('Utility Bill');
            if (!_phoneVerified) validationErrors.add('Verified Phone Number');

            // ✅ TWEAK HERE: Conditional WhatsApp Verification Check
            if (!_isWhatsappSameAsPhone && !_whatsappVerified) {
              validationErrors.add('Verified WhatsApp Number');
            }

            break;
          case 1: // Service Information
            if (_imageBytes == null) validationErrors.add('Brand Logo');
// ✅ THE FIX: Also check for the brand name async error here.
            if (_shopNameErrorText != null) validationErrors.add('the brand name is already taken');
            break;
          case 2: // Dashboard Setup
          // --- Initial Checks ---
            if (_coordController.text.isEmpty) validationErrors.add('Service Location on Map');
            if (_openTime == null || _closeTime == null) validationErrors.add('Open/Close Times');
            if (_selectedPets.isEmpty) validationErrors.add('At least one pet type serviced');
            if (_imagePaths.isEmpty) validationErrors.add('At least one service image');

            // --- Consolidated Loop for All Pet-Specific Validations ---
            for (var petName in _selectedPets) {
              final petKey = petName.toLowerCase();
              final details = _selectedPetDetails[petKey];
              final config = _petSizeConfigs[petKey];

              // Safety check in case config is missing
              if (config == null) continue;

              // 1. Validate Selections (Sizes & Breeds)
              if (details == null || (details['sizes']?.isEmpty ?? true)) {
                validationErrors.add('Accepted Sizes for $petName');
              }
              if (details == null || (details['breeds']?.isEmpty ?? true)) {
                validationErrors.add('Accepted Breeds for $petName');
              }

              // 2. Validate Prices for Selected Sizes
              final selectedDisplaySizes = details?['sizes'] ?? [];
              final List<String> selectedSizeKeys = selectedDisplaySizes.map((displayText) {
                // Extracts the simple key (e.g., "Medium")
                return displayText.split(' ')[0];
              }).toList();

              // 💡 FIX APPLIED HERE: The loop now only runs for the user-selected sizes.
              for (var size in selectedSizeKeys) {
                if (_dailyPriceCtrls[petKey]?[size]?.text.trim().isEmpty ?? true) {
                  validationErrors.add('Daily Rate for $size $petName');
                }
                if (_WalkingPriceCtrls[petKey]?[size]?.text.trim().isEmpty ?? true) {
                  validationErrors.add('Walking Rate for $size $petName');
                }
                if (_MealPriceCtrls[petKey]?[size]?.text.trim().isEmpty ?? true) {
                  validationErrors.add('Meal Rate for $size $petName');
                }
              }

              // 3. Validate Required Meal Fields (This section is already correct as it doesn't depend on size keys)
              final schedule = List<Map<String, dynamic>>.from(config['feeding_schedule'] ?? []);
              for (var mealObject in schedule) {
                final mealTitle = mealObject['section_title'] as String;
                final fields = List<Map<String, dynamic>>.from(mealObject['fields'] ?? []);

                for (var fieldData in fields) {
                  if (fieldData['required'] as bool? ?? false) { // Only check required fields
                    final fieldName = fieldData['field_name'];
                    final fieldType = fieldData['field_type'];
                    final label = fieldData['label'];

                    switch (fieldType) {
                      case 'text':
                        final controller = _mealFieldState[petKey]?[mealTitle]?[fieldName] as TextEditingController?;
                        if (controller?.text.trim().isEmpty ?? true) {
                          validationErrors.add('"$label" in $mealTitle for $petName');
                        }
                        break;
                      case 'points':
                        final controllers = _mealFieldState[petKey]?[mealTitle]?[fieldName] as List<TextEditingController>?;
                        if (controllers == null || controllers.isEmpty || controllers.first.text.trim().isEmpty) {
                          validationErrors.add('At least one "$label" in $mealTitle for $petName');
                        }
                        break;
                    }
                  }
                }
              }
            }

            // --- Final Feature Check ---
            if (!_featuresFormKey.currentState!.validate()) {
              validationErrors.add('At least two valid features');
            }
            break;

        // Step 3 is the review page, no validation needed here.
        }

        if (validationErrors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please complete the following: ${validationErrors.join(', ')}'),
            backgroundColor: errorColor,
          ));
          return false;
        }

        // If all checks pass for the current step
        return true;
      }

      // --- VISUAL REFRESH: Gradient Button ---
      // lib/screens/ShopDetailsPage.dart -> in _HomeboarderonboardpageState

    // V V V REPLACE your old _buildNextButton method with this one V V V
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

      // --- RESPONSIVE: New Mobile Stepper Widget ---
      // lib/screens/HomeBoarderOnboardPage.dart -> in _HomeboarderonboardpageState

// V V V REPLACE your old _buildMobileStepper method with this one V V V
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

      // --- VISUAL REFRESH: Section Container with Accent Border ---
      // --- VISUAL REFRESH: Section Container with Accent Border ---
      Widget _buildSectionContainer({ required String title, required List<Widget> children }) {
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
                  // ADD THIS LINE TO FIX THE ALIGNMENT
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children
                ),
              ),
            ],
          ),
        );
      }
    }