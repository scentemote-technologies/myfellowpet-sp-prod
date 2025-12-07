import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class GreetingHeader extends StatelessWidget {
  /// Color for the greeting text (e.g. “MyFellowPet”)
  final Color greetingColor;

  /// Color for the “Hello {name}” text

  const GreetingHeader({
    Key? key,
    this.greetingColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // If not logged in, just show “Hello Guest” immediately:
      final nowStr = DateFormat('EEEE, MMM d • hh:mm a').format(DateTime.now());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/companylogo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'MyFellowPet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: greetingColor,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Hello Guest 👋',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: greetingColor,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black12, blurRadius: 2)],
            ),
          ),
        ],
      );
    }

    // If the user is signed in, listen to their document in "users/{uid}"
    final docRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        print('🔄 Stream triggered');

        String displayName = 'Guest';

        if (snapshot.hasData) {
          print('✅ Snapshot has data');
          if (snapshot.data!.exists) {
            print('📄 Document exists');
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            print('🧾 Raw data: $data');

            if (data != null && data['name'] is String && (data['name'] as String).isNotEmpty) {
              displayName = data['name'] as String;
              print('🙋 Name found: $displayName');
            } else {
              print('⚠️ Name field missing or empty');
            }
          } else {
            print('❌ Document does not exist');
          }
        } else if (snapshot.hasError) {
          print('❗ Error in snapshot: ${snapshot.error}');
        } else {
          print('⏳ Waiting for data...');
        }

        final nowStr = DateFormat('EEEE, MMM d • hh:mm a').format(DateTime.now());

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Logo
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/companylogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Padding(padding: EdgeInsets.fromLTRB(0, 5, 0, 0),child: // Right: Column with Name and Greeting
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App name
                Text(
                  'MyFellowPet',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: greetingColor,
                    fontWeight: FontWeight.w600,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),

                const SizedBox(height: 4),

                // Greeting
                Row(
                  children: [
                    Text(
                      'Hello $displayName',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: greetingColor,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(color: Colors.black12, blurRadius: 2)],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋'),
                  ],
                ),
              ],
            ),)
          ],
        );

      },
    );

  }
}
