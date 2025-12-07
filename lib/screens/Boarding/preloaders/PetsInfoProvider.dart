import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../../main.dart';


class PetProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _pets = [];
  bool _loading = false;

  /// A Future that completes only after pets are loaded AND precached.

  final Completer<void> _ready = Completer<void>();
  Future<void> get fullyLoaded => _ready.future;

  List<Map<String, dynamic>> get pets => _pets;
  bool get isLoading => _loading;

  PetProvider() {
    // Kick off loading & precaching immediately.
    _loadPets();
  }

  void setPets(List<Map<String, dynamic>> newPets) {
    _pets = newPets;
    notifyListeners();
  }

  Future<void> _loadPets() async {
    _loading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _ready.complete();
      return;
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('users-pets')
        .get();

    _pets = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'pet_id': data['pet_id'] ?? doc.id,
        'name': data['name'] ?? '',
        'pet_image': data['pet_image'] as String?,
      };
    }).toList();

    // Pre-cache each pet image
    await Future.wait(_pets.map((pet) async {
      final url = pet['pet_image'];
      if (url != null) {
        await precacheImage(NetworkImage(url), navigatorKey.currentContext!);
      }
    }));

    _loading = false;
    notifyListeners();
    _ready.complete();          // signal “all done”
  }
}

