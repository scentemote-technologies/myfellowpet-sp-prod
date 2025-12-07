// lib/screens/service_provider_calendar_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'HolidayDeclarationPage.dart';

const Color kPrimary = Color(0xFF2CB4B6);

class ServiceProviderCalendarPage extends StatefulWidget {
  final String serviceId;
  const ServiceProviderCalendarPage({required this.serviceId});

  @override
  _ServiceProviderCalendarPageState createState() =>
      _ServiceProviderCalendarPageState();
}

class _ServiceProviderCalendarPageState
    extends State<ServiceProviderCalendarPage> {
  Map<DateTime, int> _bookingCountMap = {};
  int maxPetsAllowed = 0;
  bool _isLoading = true;
  Set<DateTime> _unavailDates = {};
  StreamSubscription<QuerySnapshot>? _bookingSub;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final svcRef = FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId);

    // Load maxPetsAllowed
    final doc = await svcRef.get();
    if (doc.exists) {
      maxPetsAllowed = int.tryParse(
        (doc.data()?['max_pets_allowed'] ?? '0').toString(),
      ) ??
          0;
    }

    // Listen for bookings
    _bookingSub = svcRef
        .collection('service_request_boarding')
        .snapshots()
        .listen((snap) {
      final counts = <DateTime, int>{};
      for (var d in snap.docs) {
        final data = d.data();
        final mode = (data['mode'] as String?) ?? '';
        if (!['Pending','Confirmed','Offline','Online'].contains(mode)) continue;
        final dates = (data['selectedDates'] as List<dynamic>?)
            ?.cast<Timestamp>() ??
            [];
        final numP = data['numberOfPets'] as int? ?? 1;
        for (var ts in dates) {
          final dt = ts.toDate();
          final day = DateTime(dt.year, dt.month, dt.day);
          counts[day] = (counts[day] ?? 0) + numP;
        }
      }
      setState(() => _bookingCountMap = counts);
    });
    // load unavailable dates
    _unavailDates.clear();
    final uaSnap = await svcRef.collection('unavailabilities').get();
    for (var doc in uaSnap.docs) {
      final dates = (doc.data()['dates'] as List<dynamic>?)
          ?.cast<Timestamp>() ?? [];
      for (var ts in dates) {
        final d = ts.toDate();
        _unavailDates.add(DateTime(d.year, d.month, d.day));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kPrimary),
        ),
      );
    }

    return Scaffold(
      body:
          HolidayDeclarationPage(serviceId: widget.serviceId),
    );
  }
}

