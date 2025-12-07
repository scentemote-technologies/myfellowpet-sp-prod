import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wrap your app (or part of it) with ReviewGate to automatically
/// prompt users to rate their completed overnight boarding orders.
class ReviewGate extends StatefulWidget {
  final Widget child;
  const ReviewGate({Key? key, required this.child}) : super(key: key);

  @override
  _ReviewGateState createState() => _ReviewGateState();
}

class _ReviewGateState extends State<ReviewGate> {
  late StreamSubscription<QuerySnapshot> _sub;
  final _pendingQueue = <DocumentSnapshot>[];
  final _handled = <String>{};
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .doc('overnight_boarding')
        .collection('completed_orders')
        .where('user_reviewed', isEqualTo: 'false')
        .snapshots()
        .listen((snap) {
      for (var doc in snap.docs) {
        if (!_handled.contains(doc.id)) {
          _pendingQueue.add(doc);
          _handled.add(doc.id);
        }
      }
      _processNext();
    });
  }

  Future<void> _processNext() async {
    if (_dialogShowing || _pendingQueue.isEmpty) return;
    _dialogShowing = true;

    final doc = _pendingQueue.removeAt(0);
    await _showReviewDialog(doc);

    _dialogShowing = false;
    await _processNext();
  }

  static const Color primary = Color(0xFF2CB4B6);

  Future<void> _showReviewDialog(DocumentSnapshot orderDoc) async {
    int rating = 0;
    String remarks = '';

    // ShowDialog now returns a bool: true if submitted, false otherwise.
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 48),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Rate Order ${orderDoc.id}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // Star row
                      StatefulBuilder(
                        builder: (ctx2, setState2) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final filled = i < rating;
                              return IconButton(
                                iconSize: 42,
                                icon: Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  color: filled ? Colors.amber : Colors.black26,
                                ),
                                onPressed: () => setState2(() {
                                  rating = i + 1;
                                }),
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Remarks
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              onChanged: (v) => remarks = v,
                              maxLines: null,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.black87),
                              decoration: InputDecoration.collapsed(
                                hintText: 'Any remarks?',
                                hintStyle: GoogleFonts.poppins(
                                    color: Colors.black38),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Submit button
                      Padding(
                        padding:
                        const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              // Tell the caller this was a submission
                              Navigator.of(ctx).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.white,
                              textStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              side: BorderSide(color: primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text('Submit Review'),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () {
                        // Tell the caller this was an ignore
                        Navigator.of(ctx).pop(false);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ) ?? false;   // default to false if dialog dismissed otherwise

    // Convert boolean to your string flags
    final status = submitted ? 'true' : 'ignored';

    // And now save
    await _saveReview(orderDoc, rating, remarks, reviewed: status);
  }


  Future<void> _saveReview(
      DocumentSnapshot orderDoc,
      int rating,
      String remarks, {
        required String reviewed,
      }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final now = FieldValue.serverTimestamp();
    final orderId = orderDoc.id;
    final data = orderDoc.data()! as Map<String, dynamic>;
    final serviceId = data['service_id'] as String;

    final feedback = {
      'rating': rating,
      'remarks': remarks,
      'user_uid': user.uid,
      'timestamp': now,
      'order_id': orderId,
    };

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1️⃣ SP’s completed_orders entry (merge so it never fails)
    final spRef = db
        .collection('users-sp-boarding')
        .doc(serviceId)
        .collection('completed_orders')
        .doc(orderId);
    batch.set(spRef, {
      'user_feedback': feedback,
      'user_reviewed': reviewed,
    }, SetOptions(merge: true));

    // 2️⃣ Public reviews
    final pubRef = db
        .collection('public_review')
        .doc('service_providers')
        .collection('sps')
        .doc(serviceId)
        .collection('reviews')
        .doc();
    batch.set(pubRef, feedback);

    // 3️⃣ **Always** update the user's own order doc with whatever flag we got
    final userOrderRef = db
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .doc('overnight_boarding')
        .collection('completed_orders')
        .doc(orderId);
    batch.set(userOrderRef, {
      'user_reviewed': reviewed,  // now 'true' or 'ignored'
    }, SetOptions(merge: true));

    // Commit and log
    try {
      await batch.commit();
      debugPrint('✅ Marked order $orderId as reviewed="$reviewed"');
    } catch (e, st) {
      debugPrint('❌ Failed to mark order $orderId: $e\n$st');
    }
  }


  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
