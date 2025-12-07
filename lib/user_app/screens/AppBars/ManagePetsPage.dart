/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Pets/AddPetPage.dart';
import 'EditPetPage.dart';
import 'PetRemoveReasonPage.dart';

class ManagePetsPage extends StatefulWidget {
  @override
  _ManagePetsPageState createState() => _ManagePetsPageState();
}

class _ManagePetsPageState extends State<ManagePetsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Color teal = Color(0xFF25ADAD);

  Stream<QuerySnapshot> _petStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('pets')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Pets', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: _petStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          final pets = snap.data!.docs;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Add new pet
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddPetPage()),
                    ),
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text('Add New Pet', style: GoogleFonts.poppins(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                if (pets.isEmpty)
                  Text('No pets added yet.', style: GoogleFonts.poppins(color: Colors.grey))
                else
                  ...pets.map((doc) {
                    final data = doc.data()! as Map<String, dynamic>;
                    final petId = doc.id;
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: (data['pet_image'] ?? '').isNotEmpty
                                  ? NetworkImage(data['pet_image'])
                                  : null,
                              backgroundColor: Colors.grey[200],
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                data['name'] ?? 'Unnamed',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            // Edit
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => EditPetPage(
                                    petId: petId,
                                    initialData: data,
                                  )),
                                );
                              },
                              child: Text('Edit', style: GoogleFonts.poppins(color: teal)),
                            ),
                            SizedBox(width: 8),
                            // Remove
                            TextButton(
                              onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => PetRemoveReasonPage(
                                  petId: petId,
                                  petName: data['name'] ?? '',
                                )),
                              ),
                              child: Text('Remove', style: GoogleFonts.poppins(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}*/
