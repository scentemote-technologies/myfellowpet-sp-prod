import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Authentication/PhoneSignInPage.dart';
import '../Boarding/grid_view.dart';
import '../appbars/Accounts.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Import the carousel slider

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _getUserName() async {
    User? user = _auth.currentUser;

    if (user != null) {
      String uid = user.uid;

      var snapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return 'Hello ${snapshot.docs.first['name']} 👋';
      } else {
        return 'Hello Guest 👋';
      }
    } else {
      return 'Hello Guest 👋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserName(),
      builder: (context, snapshot) {
        // Ensure proper handling of snapshot states
        String greetingText = 'Hello Guest 👋';
        if (snapshot.connectionState == ConnectionState.waiting) {
          greetingText = 'Loading...'; // Show a loading message until the data is fetched
        } else if (snapshot.hasData) {
          greetingText = snapshot.data ?? 'Hello Guest 👋';
        } else if (snapshot.hasError) {
          greetingText = 'Error: ${snapshot.error}';
        }

        return PreferredSize(
          preferredSize: Size.fromHeight(150), // Adjusted height to accommodate carousel and other UI elements
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),  // Curved bottom left corner
              bottomRight: Radius.circular(30), // Curved bottom right corner
            ),
            child: AppBar(
              elevation: 10,
              automaticallyImplyLeading: false,
              flexibleSpace: SizedBox(
                height: MediaQuery.of(context).size.height * 0.42, // Adjusted height for proper spacing
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF431555), Color(0xFF63287A), Color(
                          0xFF9C4598)], // Gradient colors
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: MediaQuery.of(context).padding.top + -15),
                        // Top Row: Texts and Icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greetingText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'HOME - #146, Anton Fortuna, NRI-Layout Phase-2',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications_active, color: Colors.white),
                                  iconSize: 40,
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut(); // Step 1: Sign out

                                    // Step 2: Clear all routes and navigate to PhoneAuthPage
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => PhoneAuthPage()),
                                          (route) => false, // Remove all previous routes
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.account_circle_outlined, color: Colors.white),
                                  iconSize: 40,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => AccountsPage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Add Search Bar here
                        TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Search for services...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, // Ensures the image stretches across the screen
                          child: Image.asset(
                            'assets/images/home page/flex.png',
                            fit: BoxFit.contain, // Stretches and crops the image to cover the width
                            height: 80,
                            width: double.infinity, // Adjust the width as needed
                          ),
                        ),
                        // CarouselSlider (image slider)

                        // Horizontal scrolling items
                        SizedBox(
                          height: 100,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSquareContainer('assets/images/store/toy.png', 'Toys'),
                                SizedBox(width: 10),
                                _buildSquareContainer('assets/images/store/softtoys.png', 'Soft Toys'),
                                SizedBox(width: 10),
                                _buildSquareContainer('assets/images/store/dress.png', 'Dress'),
                                SizedBox(width: 10),
                                _buildSquareContainer('assets/images/store/collor.png','Collar'),
                                SizedBox(width: 10),
                                _buildSquareContainer('assets/images/store/catfood.png','Cat Food'),
                                SizedBox(width: 10),
                                _buildSquareContainer('assets/images/store/toy.png', 'Toy'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.transparent, // Set to transparent so gradient is visible
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquareContainer(String imagePath, String labelText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          labelText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(321); // Adjusted height to accommodate the carousel and other elements
}
