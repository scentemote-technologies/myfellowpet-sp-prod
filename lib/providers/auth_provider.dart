import 'package:flutter/material.dart';
import '../models/user.dart'; // Ensure this import is correct

class AppAuthProvider with ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;

  void logIn(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void logOut() {
    _currentUser = null;
    notifyListeners();
  }
}
