import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../fullscreenchecker.dart';
import '../dashboard.dart';

class InternshipCertificatePage extends StatelessWidget {
  final String internship_name;
  final String userId;

  InternshipCertificatePage({
    required this.internship_name,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FullscreenCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Internship Completion Certificate',
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
                  'Thank You for Completing the Internship!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),

                // Certificate Download Button
                ElevatedButton(
                  onPressed: () async {
                    print('Button Pressed: Starting PDF Generation...');
                    try {
                      // Fetch all the images asynchronously
                      final logoBytes = await _getLogoBytes('Company_seal.png');
                      final directorImageBytes = await _getLogoBytes('GowSign.png');
                      final dateImageBytes = await _getLogoBytes('Company_seal.png');
                      final topLeftImageBytes = await _getLogoBytes('logotrans.png');
                      final topRightImageBytes = await _getLogoBytes('MSME.png');
                      print('Images loaded successfully.');

                      // Generate and download the PDF
                      await generateAndDownloadPDF(
                        logoBytes,
                        directorImageBytes,
                        dateImageBytes,
                        topLeftImageBytes,
                        topRightImageBytes,
                      );
                    } catch (e) {
                      print('Error during PDF generation: $e');
                    }
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

  Future<void> generateAndDownloadPDF(
      Uint8List logoBytes,
      Uint8List directorImageBytes,
      Uint8List dateImageBytes,
      Uint8List topLeftImageBytes,
      Uint8List topRightImageBytes,
      ) async {
    final pdf = pw.Document();

    print('Fetching user data...');
    // Get current user UID and other data
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'default_user_id';
    print('User ID: $userId');

    final userName = await _getDisplayName(userId, internship_name);
    print('User Name: $userName');

    final startDate = await _getInternshipStartDate(userId, internship_name);
    print('Internship Start Date: $startDate');

    final endDate = await _getInternshipEndDate(internship_name, startDate);
    print('Internship End Date: $endDate');
    final startDateFormatted = DateFormat('dd-MM-yyyy').format(DateTime.parse(startDate));
    final endDateFormatted = DateFormat('dd-MM-yyyy').format(DateTime.parse(endDate));

    // Store certificate details in Firestore
    final certificationsRef = FirebaseFirestore.instance.collection('certifications').doc(userId).collection('user-internship-certificates');
    final certificateDocRef = await certificationsRef.add({
      'pdfUrl': '',
      'name': userName,
      'InternshipName': internship_name,
      'certificateNo': '',
      'startDate': startDateFormatted,
      'endDate': endDateFormatted,
      'date': DateTime.now().toIso8601String(),
    });

    final certificateId = certificateDocRef.id;
    print('Certificate document created with ID: $certificateId');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          print('Building the PDF page...');
          return pw.Center(
            child: pw.Container(
              width: 750,
              height: 550,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFF202B62),
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
                      width: 10,
                      color: PdfColor.fromInt(0xFF202B62),
                    ),
                  ),
                  pw.Positioned(
                    top: 18,
                    left: 23,
                    child: pw.Container(
                      width: 115,
                      height: 115,
                      child: pw.Image(pw.MemoryImage(topLeftImageBytes), fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.Positioned(
                    top: 18,
                    right: 23,
                    child: pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(pw.MemoryImage(topRightImageBytes), fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.Positioned(
                    top: 54,
                    left: 0,
                    right: 0,
                    child: pw.Text(
                      'CERTIFICATE OF\nINTERNSHIP COMPLETION',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  pw.Positioned(
                    top: 132,
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
                  pw.Positioned(
                    top: 177,
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
                  pw.Positioned(
                    top: 207,
                    left: 100,
                    right: 100,
                    child: pw.Divider(color: PdfColors.black, thickness: 1),
                  ),
                  pw.Positioned(
                    top: 235,
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
                            text: 'who has successfully completed the ',
                          ),
                          pw.TextSpan(
                            text: '$internship_name internship', // Bold internship name
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text: ' at Scentemote Technologies Private Limited, from ',
                          ),
                          pw.TextSpan(
                            text: '$startDateFormatted to $endDateFormatted.', // Bold dates
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text: ' During this period, they have gained valuable experience and demonstrated dedication, a strong work ethic, and the ability to apply their knowledge effectively in real-world situations.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.Positioned(
                    bottom: 30,
                    left: 20,
                    child: pw.Container(
                      width: 150,
                      height: 150,
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                  ),
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

                  pw.Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: pw.Container(
                      height: 10,
                      color: PdfColor.fromInt(0xFF202B62),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Padding(
                          padding: pw.EdgeInsets.only(right: 20),
                          child: pw.Text(
                            'Certificate No: $certificateId',
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
                ],
              ),
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    print('PDF generated successfully. Size: ${pdfBytes.length} bytes.');

    final pdfBlob = html.Blob([pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(pdfBlob);

    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = 'certificate_${userName.replaceAll(' ', '_')}.pdf';

    anchor.click();
    html.Url.revokeObjectUrl(url);

    // Upload the certificate to Firebase Storage
    print('Uploading the PDF to Firebase Storage...');
    final storageRef = FirebaseStorage.instance.ref();
    final pdfRef = storageRef.child('certificates/${userName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final uploadTask = pdfRef.putData(pdfBytes);
    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Update the certificate document with the PDF URL and certificate number
    await certificateDocRef.update({
      'pdfUrl': downloadUrl,
      'certificateNo': certificateId,
    });

    print('Certificate successfully uploaded and stored!');
  }

  Future<String> _getInternshipStartDate(String userId, String internshipName) async {
    print('Fetching internship start date...');
    final userInternshipRef = FirebaseFirestore.instance
        .collection('web-users')
        .doc(userId)
        .collection('user-internship')
        .doc(internshipName);

    final userInternshipDoc = await userInternshipRef.get();
    final timestamp = userInternshipDoc['timestamp'] as Timestamp;
    final startDate = timestamp.toDate();
    final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);

    print('Start Date: $formattedStartDate');
    return formattedStartDate;
  }

  Future<String> _getInternshipEndDate(String internshipName, String startDate) async {
    print('Fetching internship end date...');
    final internshipRef = FirebaseFirestore.instance.collection('internships').doc(internshipName);

    final internshipDoc = await internshipRef.get();
    final durationDays = int.parse(internshipDoc['duration_days']);

    final startDateTime = DateTime.parse(startDate);
    final endDateTime = startDateTime.add(Duration(days: durationDays));

    final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDateTime);

    print('End Date: $formattedEndDate');
    return formattedEndDate;
  }

  Future<String> _getDisplayName(String userId, String internshipName) async {
    print('Fetching user display name...');

    try {
      // Get the user's internship document based on the userId and internship name
      final userInternshipDocRef = FirebaseFirestore.instance
          .collection('web-users')
          .doc(userId)
          .collection('user-internship')
          .doc(internshipName);  // Access the internship document directly by its name

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


  Future<Uint8List> _getLogoBytes(String path) async {
    print('Loading image: $path');
    try {
      final ByteData data = await rootBundle.load(path);
      final byteArray = data.buffer.asUint8List();
      print('Image loaded successfully.');
      return byteArray;
    } catch (e) {
      print('Error loading image $path: $e');
      return Uint8List(0); // Return empty data if there's an error
    }
  }
}
