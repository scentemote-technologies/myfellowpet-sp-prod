import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ContactUsPage(),
    );
  }
}

class ContactUsPage extends StatefulWidget {
  @override
  _ContactUsPageState createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  // Controllers to capture user input
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String mission = "";
  String vision = "";
  String values = "";
  String email = '';
  String emailBody = '';
  String emailSubject = '';
  String emailUrl = '';
  String whatsappMessage = '';
  String whatsappUrl = '';
  String instagramProfileUrl = '';
  String linkedinProfileUrl = '';

  @override
  void initState() {
    super.initState();


    // Fetch data from Firestore
    _fetchCompanyData();
  }

  // Function to handle form submission

  Future<void> _fetchCompanyData() async {
    try {
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('company_documents')
          .doc('About Us')
          .get();

      if (docSnapshot.exists) {
        setState(() {
          mission = docSnapshot['mission'] ?? 'No mission available';
          vision = docSnapshot['vision'] ?? 'No vision available';
          values = docSnapshot['values'] ?? 'No values available';
          email = docSnapshot['email'] ?? 'No email available';
          emailBody = docSnapshot['email_body'] ?? 'No email body available';
          emailSubject = docSnapshot['email_subject'] ?? 'No email subject available';
          emailUrl = docSnapshot['email_url'] ?? 'No email URL available';
          whatsappMessage = docSnapshot['whatsapp_message'] ?? 'No message available';
          whatsappUrl = docSnapshot['whatsapp_url'] ?? 'No WhatsApp URL available';
          instagramProfileUrl = docSnapshot['instagram_profile_url'] ?? 'No Instagram URL available';
          linkedinProfileUrl = docSnapshot['linkedin_profile_url'] ?? 'No LinkedIn URL available';
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  // Function to launch URLs
  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Function to open Gmail compose screen with pre-filled recipient
  Future<void> _launchGmail() async {
    String email = this.email;
    String subject = this.emailSubject;
    String body = this.emailBody;

    String url = '${this.emailUrl}?view=cm&fs=1&to=$email&su=$subject&body=$body';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch Gmail compose screen';
    }
  }

  // Function to open WhatsApp chat
  Future<void> _launchWhatsApp() async {
    String phoneNumber = this.whatsappUrl; // You may need to extract the phone number from this URL
    String message = this.whatsappMessage;
    String url = 'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch WhatsApp';
    }
  }
  void sendMessage() async {
    String name = nameController.text;
    String email = emailController.text;
    String message = messageController.text;

    if (name.isNotEmpty && email.isNotEmpty && message.isNotEmpty) {
      try {
        // Send data to Firestore collection "ContactUsInformation"
        await FirebaseFirestore.instance.collection("contactUsInformation").add({
          'name': name,
          'email': email,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(), // Automatically adds timestamp
        });

        // Clear the text fields after submission
        nameController.clear();
        emailController.clear();
        messageController.clear();

        // Optionally, show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message sent successfully!')),
        );
      } catch (e) {
        // Handle any errors that occur while sending data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } else {
      // If any field is empty, show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields!')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contact Us',
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

      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Text(
              "We'd Love to Hear From You!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "If you have any questions, feedback, or need assistance, feel free to reach out to us. We are here to help!",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 30),

            // Contact Form Section
            ContactForm(
              nameController: nameController,
              emailController: emailController,
              messageController: messageController,
              onSend: sendMessage,
            ),

            SizedBox(height: 30),



            // Social Media Icons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Social media buttons
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.instagram),
                    onPressed: () => _launchURL(instagramProfileUrl),
                  ),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.linkedin),
                    onPressed: () => _launchURL(linkedinProfileUrl),
                  ),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.whatsapp),
                    onPressed: _launchWhatsApp,
                  ),
                  IconButton(
                    icon: const Icon(FontAwesomeIcons.envelope),
                    onPressed: _launchGmail,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController messageController;
  final VoidCallback onSend;

  ContactForm({
    required this.nameController,
    required this.emailController,
    required this.messageController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueAccent, width: 2.0),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.2),
            spreadRadius: 5,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Contact Us",
            style: TextStyle(
              fontSize: 22, // Reduced font size for the title
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16), // Reduced space between title and input fields
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: "Your Name",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16), // Reduced space between fields
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: "Your Email",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16), // Reduced space between fields
          TextField(
            controller: messageController,
            decoration: InputDecoration(
              labelText: "Your Message",
              border: OutlineInputBorder(),
            ),
            maxLines: 4, // Reduced maxLines to make the message box smaller
          ),
          SizedBox(height: 16), // Reduced space between fields
          ElevatedButton(
            onPressed: onSend,
            child: Text("Send", style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
