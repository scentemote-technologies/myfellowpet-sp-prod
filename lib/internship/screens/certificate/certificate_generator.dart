import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart'; // Import Dio
import 'package:path_provider/path_provider.dart'; // Import Path Provider
import 'dart:io';

import '../../fullscreenchecker.dart'; // Import for file system access

class CertificatePage extends StatelessWidget {
  final String name;
  final String courseName;

  CertificatePage({required this.name, required this.courseName});

  @override
  Widget build(BuildContext context) {
    return FullscreenCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Course Completion Certificate',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white, // White text color
            ),
          ),
          backgroundColor: Colors.black, // Black background color
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white), // White back arrow icon
            onPressed: () {
              Navigator.pop(context); // Go back to the previous screen
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thank You Message
                Text(
                  'Thank You for Completing the Course!',
                  style: TextStyle(
                    fontSize: 32,  // Increased font size
                    fontWeight: FontWeight.bold,
                    color: Colors.black,  // Changed to black
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),

                // Certificate Download Button
                ElevatedButton(
                  onPressed: () async {
                    final logoBytes = await _getLogoBytes('Company_seal.png');
                    final directorImageBytes = await _getLogoBytes('Gowtham_Signature.png');
                    final dateImageBytes = await _getLogoBytes('Company_seal.png');
                    final topLeftImageBytes = await _getLogoBytes('logotrans.png');
                    final topRightImageBytes = await _getLogoBytes('MSME.png');
                    generateAndDownloadPDF(logoBytes, directorImageBytes, dateImageBytes, topLeftImageBytes, topRightImageBytes);
                  },
                  child: Text(
                    'Download Certificate',
                    style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    overlayColor: Colors.grey,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _getDisplayName(String userId, String courseName) async {
    print('Fetching user display name...');

    try {
      // Get the user's internship document based on the userId and internship name
      final userInternshipDocRef = FirebaseFirestore.instance
          .collection('web-users')
          .doc(userId)
          .collection('user courses')
          .doc(courseName);  // Access the internship document directly by its name

      final userInternshipDoc = await userInternshipDocRef.get();

      if (userInternshipDoc.exists) {
        print('Internship found for the user.');
        // Assuming that the document contains fields 'firstName', 'middleName', 'lastName'
        final firstName = userInternshipDoc.data()?['firstName'] ?? '';
        final middleName = userInternshipDoc.data()?['middleName'] ?? '';
        final lastName = userInternshipDoc.data()?['lastName'] ?? '';

        // Return the full name by concatenating the first, middle, and last names
        final fullName = '$firstName $middleName $lastName'.trim();
        return fullName.isEmpty ? 'User' : fullName;
      } else {
        print('Internship document not found.');
        return 'User';  // Return a default name if internship is not found
      }
    } catch (e) {
      print('Error fetching user display name: $e');
      return 'User';  // Return a default name in case of error
    }
  }

  Future<void> generateAndDownloadPDF(
      Uint8List logoBytes,
      Uint8List directorImageBytes,
      Uint8List dateImageBytes,
      Uint8List topLeftImageBytes,
      Uint8List topRightImageBytes,
      ) async {
    final pdf = pw.Document();

    // Get current user UID
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user_id';
    final userName = await _getDisplayName(userId, courseName);

    // Store certificate details in Firestore under the 'certifications' collection
    final certificationsRef = FirebaseFirestore.instance.collection('certifications').doc(userId).collection('user-certificates');

    // Add a new certificate document with the Firestore document ID as the certificate ID
    final certificateDocRef = await certificationsRef.add({
      'pdfUrl': '',  // Leave blank for now, to be filled after upload
      'name': userName,
      'courseName': courseName,
      'certificateNo': '', // We will update this after generating the certificate
      'date': DateTime.now().toIso8601String(),
    });

    final certificateId = certificateDocRef.id; // Get Firestore document ID

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 750,
              height: 550,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFF202B62),  // Set border color to blue
                  width: 4,
                ),
              ),
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: pw.Container(
                      width: 10, // Set width of the vertical bar (about 1 cm)
                      color: PdfColor.fromInt(0xFF202B62),
                    ),
                  ),
                  // Top-left Image (adjusted position to accommodate the left bar)
                  pw.Positioned(
                    top: 18,
                    left: 23,  // Adjusted to the right to avoid overlap with the vertical bar
                    child: pw.Container(
                      width: 115,
                      height: 115,
                      child: pw.Image(
                        pw.MemoryImage(topLeftImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  // Top-right Image
                  pw.Positioned(
                    top: 18,
                    right: 23,
                    child: pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(
                        pw.MemoryImage(topRightImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  // Header and Title
                  pw.Positioned(
                    top: 70,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      'CERTIFICATE OF COMPLETION',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Positioned(
                    top: 120,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      'THIS CERTIFICATE IS PROUDLY PRESENTED TO',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                  // Recipient Name
                  pw.Positioned(
                    top: 160,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      userName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  // Divider Line Below the Name
                  pw.Positioned(
                    top: 200,
                    left: 50,
                    right: 50,
                    child: pw.Divider(color: PdfColors.black, thickness: 1),
                  ),
                  // Certificate Text
                  pw.Positioned(
                    top: 220,
                    left: 50,
                    right: 50,
                    child: pw.RichText(
                      textAlign: pw.TextAlign.center,
                      text: pw.TextSpan(
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.black,
                        ),
                        children: [
                          pw.TextSpan(
                            text: 'For demonstrating a thorough understanding of the key concepts, theories, and principles covered in the course, ',
                          ),
                          pw.TextSpan(
                            text: '$courseName. ',  // This will be the bold course name
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.TextSpan(
                            text: 'By completing this program, ',
                          ),
                          pw.TextSpan(
                            text: '$userName',  // This will be the bold user name
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.TextSpan(
                            text: ' has met the requirements necessary to achieve a foundational knowledge in the subject. This certificate acknowledges their commitment to continuous learning, skill development, and the pursuit of excellence.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Left - Enlarged Company Seal
                  pw.Positioned(
                    bottom: 30,
                    left: 20,
                    child: pw.Container(
                      width: 200,
                      height: 150,
                      child: pw.Image(
                        pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  // Bottom Right - Director Section
                  pw.Positioned(
                    bottom: 50,
                    right: 60,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 100,  // Increase the width
                          height: 60, // Increase the height
                          child: pw.Image(pw.MemoryImage(directorImageBytes), fit: pw.BoxFit.contain),  // Use BoxFit.contain to avoid clipping
                        ),
                        pw.SizedBox(height: 5),
                        pw.Divider(color: PdfColors.black, thickness: 1),
                        pw.Text(
                          'Gowtham Sailesh Deepak',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Director',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Horizontal Black Bar at the Bottom
                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 10, // Set height of the black bar
                      color: PdfColor.fromInt(0xFF202B62),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Padding(
                          padding: pw.EdgeInsets.only(right: 20),
                          child: pw.Text(
                            'Certificate No: $certificateId', // Use the Firestore document ID
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  pw.Positioned(
                    right: 0,
                    top: 0,
                    left: 0,
                    child: pw.Container(
                      height: 10, // Set width of the vertical bar (about 1 cm)
                      color: PdfColor.fromInt(0xFF202B62),
                    ),
                  ),
                  pw.Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: pw.Container(
                      width: 10, // Set width of the vertical bar (about 1 cm)
                      color: PdfColor.fromInt(0xFF202B62),
                    ),
                  ),
                  // Your layout code here...
                ],
              ),
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    // Upload the certificate to Firebase Storage
    final storageRef = FirebaseStorage.instance.ref();
    final pdfRef = storageRef.child('certificates/${userName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final uploadTask = pdfRef.putData(pdfBytes);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Update the certificate document with the PDF URL and certificate number
    await certificateDocRef.update({
      'pdfUrl': downloadUrl,
      'certificateNo': certificateId, // Add the Firestore document ID as the certificate number
    });

    print('Certificate successfully uploaded and stored!');

    // Now we will use Dio to download the PDF to the local device
    await downloadPDF(downloadUrl);

    // Open the PDF in a new tab using window.open
    _openPDFInNewTab(downloadUrl);
  }

  // Function to download the PDF using Dio and save it locally
  Future<void> downloadPDF(String downloadUrl) async {
    try {
      Dio dio = Dio();

      // Get the directory to save the PDF
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String savePath = "${appDocDir.path}/certificate.pdf";

      // Download the PDF and save it to the device
      await dio.download(downloadUrl, savePath);

      print("PDF downloaded successfully and saved at $savePath");
    } catch (e) {
      print("Error downloading PDF: $e");
    }
  }

  // Function to open the PDF in a new tab
  Future<void> _openPDFInNewTab(String downloadUrl) async {
    html.window.open(downloadUrl, '_blank');
  }

  Future<Uint8List> _getLogoBytes(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
}
