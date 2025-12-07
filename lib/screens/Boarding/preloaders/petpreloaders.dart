import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// A simple model for your pet data.
class Pet {
  final String id;
  final String name;
  final String imageUrl;
  final String breed;
  final String age;

  Pet({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.breed,
    required this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'pet_id': id,
      'name': name,
      'pet_image': imageUrl,
      'pet_breed': breed,
      'pet_age': age,
    };
  }

  factory Pet.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Pet(
      id: data['pet_id'] as String? ?? doc.id,
      name: data['name'] as String? ?? 'Unnamed',
      imageUrl: data['pet_image'] as String? ?? '',
      breed: data['pet_breed'] as String? ?? 'NA',
      age: data['pet_age'] as String? ?? 'NA',
    );
  }
}

/// A singleton “repository” you can call from anywhere.
class PetService {
  PetService._();
  static final PetService instance = PetService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  /// Returns a stream of Pet objects, updating in real-time.
  Stream<List<Pet>> watchMyPets(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('users-pets')
        .snapshots()
        .map((snap) {
      final pets = snap.docs.map((d) => Pet.fromDoc(d)).toList();
      // Fire-and-forget image caching;
      for (var pet in pets) {
        if (pet.imageUrl.isNotEmpty) {
          precacheImage(NetworkImage(pet.imageUrl), context).catchError((_) {});
        }
      }
      return pets;
    });
  }

  /// Returns a stream of pet data as Map for UI builders.
  Stream<List<Map<String, dynamic>>> watchMyPetsAsMap(BuildContext context) {
    return watchMyPets(context).map(
          (list) => list.map((p) => p.toMap()).toList(),
    );
  }

  /// Legacy: one-time fetch (if needed).
  Future<List<Pet>> fetchMyPets(BuildContext context) async {
    final uid = _auth.currentUser!.uid;
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('users-pets')
        .get();

    final pets = snap.docs.map((doc) => Pet.fromDoc(doc)).toList();
    // Fire-and-forget caching as before
    for (var pet in pets) {
      if (pet.imageUrl.isNotEmpty) {
        precacheImage(NetworkImage(pet.imageUrl), context).catchError((_) {});
      }
    }
    return pets;
  }
}
