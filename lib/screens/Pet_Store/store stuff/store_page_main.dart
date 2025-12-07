import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


import 'ProductSelectionPage.dart';
import 'inventory.dart';

class StorePageMain extends StatefulWidget {
  final String serviceId;

  const StorePageMain({Key? key, required this.serviceId}) : super(key: key);

  @override
  _StorePageMainState createState() => _StorePageMainState();
}

class _StorePageMainState extends State<StorePageMain> {
  String _selectedSection = '';
  bool _isAddProductsEnabled = true; // Flag to manage Inventory option

  // Function to fetch user verification status from Firestore
  Future<void> _checkUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users-sp-store') // Assuming your collection name is users-sp-store
            .doc(user.uid) // Get the current user's document by UID
            .get();

        if (userDoc.exists) {
          bool verified = userDoc['verified'] ?? false; // Check the 'verified' field
          setState(() {
            _isAddProductsEnabled = verified; // Update inventory availability
          });
        }
      } catch (e) {
        print('Error fetching user profile: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _checkUserProfile(); // Check the user's profile status when the page loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Store Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Row(
        children: [
          // Sidebar (Navigation Drawer)
          NavigationDrawer(
            onSelectSection: _onSectionSelect,
            isAddProductsEnabled: _isAddProductsEnabled, // Pass the state to NavigationDrawer
          ),
          // Main Content Area
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  // Handle section selection
  void _onSectionSelect(String section) {
    if (section == 'Add Products' && !_isAddProductsEnabled) {
      // If the user tries to access Inventory but it's not enabled, show a pop-up
      _showProfileUnderReviewDialog();
    } else {
      setState(() {
        _selectedSection = section;
      });
    }
  }

  // Build the content based on the selected section
  Widget _buildContent() {
    switch (_selectedSection) {
      case 'Add Products':
        return ProductSelectionPage(serviceId: widget.serviceId);
      case 'Inventory':
        return InventoryPage(serviceId: widget.serviceId); // Show Inventory page
      /*case 'Pending items':
        return UnverifiedProductsPage();*/
      default:
        return Center(child: Text('Select a section from the sidebar'));
    }
  }

  // Show a dialog if the user tries to access Inventory while under review
  void _showProfileUnderReviewDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Profile Under Review'),
          content: Text('Your profile is under review. Once accepted, this option will be unlocked.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final Function(String) onSelectSection;
  final bool isAddProductsEnabled; // Pass the state here to disable Inventory

  NavigationDrawer({required this.onSelectSection, required this.isAddProductsEnabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.blueGrey[900],
      child: Drawer(
        child: Column(
          children: [
            ListTile(
              title: Text('Inventory'),
              leading: Icon(Icons.store),
              onTap: () {
                if (isAddProductsEnabled) {
                  onSelectSection('Inventory'); // Proceed if enabled
                } else {
                  // Show the pop-up message when trying to click on a masked Inventory option
                  _showProfileUnderReviewDialog(context);
                }
              },
              tileColor: isAddProductsEnabled ? null : Color(0xFF949494), // Change color to indicate it's disabled
            ),
            ListTile(
              title: Text('Pending items'),
              leading: Icon(Icons.event),
              onTap: () {
                if (isAddProductsEnabled) {
                  onSelectSection('Pending items'); // Proceed if enabled
                } else {
                  // Show the pop-up message when trying to click on a masked Inventory option
                  _showProfileUnderReviewDialog(context);
                }
              },
            ),
            ListTile(
              title: Text('Add Products'),
              leading: Icon(Icons.event),
              onTap: () {
                if (isAddProductsEnabled) {
                  onSelectSection('Add Products'); // Proceed if enabled
                } else {
                  // Show the pop-up message when trying to click on a masked Inventory option
                  _showProfileUnderReviewDialog(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Function to show the dialog when the Inventory option is disabled
  void _showProfileUnderReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Profile Under Review'),
          content: Text('Your profile is under review. Once accepted, this option will be unlocked.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
