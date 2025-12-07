import 'dart:html' as html; // Import for web-specific file handling
import 'dart:typed_data'; // To handle binary data
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetailerConfirmationPage extends StatefulWidget {
  final String shopId;
  final String sid;

  RetailerConfirmationPage({
    Key? key,
    required this.shopId,
    required this.sid,
  }) : super(key: key);
  @override
  _RetailerConfirmationPageState createState() =>
      _RetailerConfirmationPageState();
}

class _RetailerConfirmationPageState extends State<RetailerConfirmationPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController retailerNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController gstNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();

  String brandType = "Manufacturer";
  List<String> brandNames = [];
  String selectedCategory = "Pet Food";
  final List<String> sellerCategories = [
    "Pet Food",
    "Accessories",
    "Grooming Services",
    "Veterinary Services",
    "Training Services",
    "Pet Boarding",
    "Adoption Services",
    "Pet Toys"
  ];

  // Store files as ByteData
  Uint8List? panCard;
  Uint8List? gstCertificate;
  Uint8List? cancelledCheque;
  Uint8List? authorizedSignature;
  Uint8List? trademarkCertificate;
  Uint8List? authorizationLetter;

  // File picking for web
  Future<void> pickDocumentWeb(void Function(Uint8List) setFile) async {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '*/*'; // Accept all file types
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files!.isEmpty) return;
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        setFile(Uint8List.fromList(reader.result as List<int>));
      });
    });
  }

  // File picking for mobile
  Future<void> pickDocumentMobile(ImageSource source, void Function(Uint8List) setFile) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setFile(await pickedFile.readAsBytes());
    }
  }

  // Conditionally pick file based on platform
  Future<void> pickDocument(void Function(Uint8List) setFile) async {
    if (kIsWeb) {
      await pickDocumentWeb(setFile); // Web
    } else {
      await pickDocumentMobile(ImageSource.gallery, setFile); // Mobile
    }
  }

  // Upload files to Firebase
  Future<String?> uploadFileToStorage(Uint8List fileBytes, String fileName) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('retailers/$fileName');
      await storageRef.putData(fileBytes);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Error uploading $fileName: $e");
      return null;
    }
  }

  Future<void> submitRetailerDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No user logged in!')));
      return;
    }
    final retailerId = user.uid;

    try {
      // Upload files and get URLs
      final panCardUrl = panCard != null ? await uploadFileToStorage(panCard!, 'pan_card') : null;
      final gstCertificateUrl = gstCertificate != null ? await uploadFileToStorage(gstCertificate!, 'gst_certificate') : null;
      final cancelledChequeUrl = cancelledCheque != null ? await uploadFileToStorage(cancelledCheque!, 'cancelled_cheque') : null;
      final authorizedSignatureUrl = authorizedSignature != null ? await uploadFileToStorage(authorizedSignature!, 'authorized_signature') : null;
      final trademarkCertificateUrl = trademarkCertificate != null ? await uploadFileToStorage(trademarkCertificate!, 'trademark_certificate') : null;
      final authorizationLetterUrl = authorizationLetter != null ? await uploadFileToStorage(authorizationLetter!, 'authorization_letter') : null;

      // Add retailer details to Firestore
      await _firestore.collection('users-sp-store').doc(retailerId).set({
        'retailer_name': retailerNameController.text,
        'business_name': businessNameController.text,
        'gst_number': gstNumberController.text,
        'email': emailController.text,
        'contact_number': contactController.text,
        'brand_type': brandType,
        'shopId':widget.shopId,
        'sid':widget.sid,
        'service_name':'Store',
        'brand_names': brandNames,
        'verified': false,
        'seller_category': selectedCategory,
        'documents': {
          'pan_card': panCardUrl,
          'gst_certificate': gstCertificateUrl,
          'cancelled_cheque': cancelledChequeUrl,
          'authorized_signature': authorizedSignatureUrl,
          'trademark_certificate': trademarkCertificateUrl,
          'authorization_letter': authorizationLetterUrl,
        },
        'created_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retailer details submitted successfully!')));
    } catch (e) {
      print("Error submitting retailer details: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting details')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Retailer Confirmation Page'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Retailer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: retailerNameController,
                decoration: InputDecoration(labelText: 'Retailer Name'),
                validator: (value) => value!.isEmpty ? 'Enter Retailer Name' : null,
              ),
              TextFormField(
                controller: businessNameController,
                decoration: InputDecoration(labelText: 'Business Name'),
                validator: (value) => value!.isEmpty ? 'Enter Business Name' : null,
              ),
              TextFormField(
                controller: gstNumberController,
                decoration: InputDecoration(labelText: 'GST Number'),
                validator: (value) => value!.isEmpty ? 'Enter GST Number' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Enter Email' : null,
              ),
              TextFormField(
                controller: contactController,
                decoration: InputDecoration(labelText: 'Contact Number'),
                validator: (value) => value!.isEmpty ? 'Enter Contact Number' : null,
              ),
              SizedBox(height: 20),
              Text('Upload Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              buildUploadField('Upload PAN Card', panCard, (file) => setState(() => panCard = file)),
              buildUploadField('Upload GST Certificate', gstCertificate, (file) => setState(() => gstCertificate = file)),
              buildUploadField('Upload Cancelled Cheque', cancelledCheque, (file) => setState(() => cancelledCheque = file)),
              buildUploadField('Upload Authorized Signature', authorizedSignature, (file) => setState(() => authorizedSignature = file)),
              buildUploadField('Upload Trademark Certificate', trademarkCertificate, (file) => setState(() => trademarkCertificate = file)),
              buildUploadField('Upload Authorization Letter', authorizationLetter, (file) => setState(() => authorizationLetter = file)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitRetailerDetails,
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildUploadField(String label, Uint8List? file, void Function(Uint8List) setFile) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () => pickDocument(setFile),
          child: Text(label),
        ),
        SizedBox(width: 10),
        if (file != null) Text('File Selected'),
      ],
    );
  }
}
