import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddThreeAnnouncementsButton extends StatelessWidget {
  const AddThreeAnnouncementsButton({super.key});

  Future<void> addAnnouncements() async {
    final docRef = FirebaseFirestore.instance
        .collection('settings')
        .doc('announcements');

    final now = Timestamp.now();

    final newAnnouncements = [
      {
        "id": "ann_003",
        "heading": "New Feature 🎉",
        "message": "Check out our new pet training module!",
        "type": "update",
        "visibleTo": ["all"],
        "active": true,
        "startDate": now,
        "endDate": Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7))),
      },
      {
        "id": "ann_004",
        "heading": "Maintenance Alert ⚙️",
        "message": "Servers will be down from 2AM–4AM tomorrow.",
        "type": "alert",
        "visibleTo": ["all"],
        "active": true,
        "startDate": now,
        "endDate": Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 1))),
      },
      {
        "id": "ann_005",
        "heading": "Promo Offer 🐶",
        "message": "Get 20% off on pet grooming this week!",
        "type": "promo",
        "visibleTo": ["all"],
        "active": true,
        "startDate": now,
        "endDate": Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7))),
      },
    ];

    await docRef.update({
      "items": FieldValue.arrayUnion(newAnnouncements),
      "updatedAt": now,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await addAnnouncements();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('3 Announcements added!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: const Text('Add 3 Announcements'),
    );
  }
}
