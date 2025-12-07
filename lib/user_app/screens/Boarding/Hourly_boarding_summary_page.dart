import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HourlyBoardingSummaryPage extends StatelessWidget {
  // ─── Core booking info ─────────────────────────────────────────────
  final DateTime selectedDate;
  final String shopId;
  final String shopName;
  final String areaName;
  final List<String> petIds;
  final List<String> petNames;
  final List<List<DateTime>> selectedTimeSlots;

  // ─── Pricing & options ────────────────────────────────────────────
  final double hourlyRate;
  final bool dailyWalkingRequired;
  final double walkingFee;
  final String foodOption;        // 'provider' or 'self'
  final double? foodCostPerMeal;  // only if provider
  final int feedingTimes;         // meals per day

  HourlyBoardingSummaryPage({
    Key? key,
    required this.selectedDate,
    required this.shopId,
    required this.shopName,
    required this.areaName,
    required this.petIds,
    required this.petNames,
    required this.selectedTimeSlots,
    required this.hourlyRate,
    required this.dailyWalkingRequired,
    required this.walkingFee,
    required this.foodOption,
    this.foodCostPerMeal,
    required this.feedingTimes,
  }) : super(key: key);

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange,
              ),
            ),
            const Divider(color: Colors.deepOrangeAccent),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.deepOrange),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _timeSlotRange() {
    if (selectedTimeSlots.isEmpty) return const SizedBox();
    final fmt = DateFormat('h:mm a');
    final start = fmt.format(selectedTimeSlots.first.first);
    final end   = fmt.format(selectedTimeSlots.last.last);
    return _detailRow(
      'Time',
      '$start – $end',
      icon: Icons.access_time_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, MMM d, y');
    final dateStr = df.format(selectedDate);

    // ─── Compute line‐item costs ───────────────────────────────────────
    final hours        = selectedTimeSlots.length;
    final petsCount    = petIds.length;
    final boardingCost = hourlyRate * hours * petsCount;
    final walkingCost  = dailyWalkingRequired ? walkingFee * petsCount : 0.0;
    final foodCost     = (foodOption == 'provider' && foodCostPerMeal != null)
        ? foodCostPerMeal! * feedingTimes * petsCount
        : 0.0;
    final totalCost    = boardingCost + walkingCost + foodCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Summary'),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── 1) Appointment Details ─────────────────────────────────
            _buildCard('Appointment Details', [
              _detailRow('Date', dateStr, icon: Icons.calendar_today),
              _timeSlotRange(),
              _detailRow('Pets', petNames.join(', '), icon: Icons.pets),
              _detailRow('Shop', shopName, icon: Icons.store),
              _detailRow(
                'Duration',
                '$hours hour${hours>1?'s':''} × $petsCount pet${petsCount>1?'s':''}',
                icon: Icons.timer,
              ),
            ]),

            // ─── 2) Invoice Breakdown ───────────────────────────────────
            _buildCard('Invoice', [
              _detailRow(
                'Boarding',
                '₹${hourlyRate.toStringAsFixed(0)} × $hours h × $petsCount pet${petsCount>1?'s':''} = ₹${boardingCost.toStringAsFixed(0)}',
                icon: Icons.home_repair_service_rounded,
              ),
              if (dailyWalkingRequired)
                _detailRow(
                  'Walking',
                  '₹${walkingFee.toStringAsFixed(0)} × $petsCount pet${petsCount>1?'s':''} = ₹${walkingCost.toStringAsFixed(0)}',
                  icon: Icons.directions_walk,
                ),
              if (foodOption == 'provider' && foodCostPerMeal != null)
                _detailRow(
                  'Food',
                  '₹${foodCostPerMeal!.toStringAsFixed(0)} × $feedingTimes meal${feedingTimes>1?'s':''} × $petsCount pet${petsCount>1?'s':''} = ₹${foodCost.toStringAsFixed(0)}',
                  icon: Icons.fastfood,
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      '₹${totalCost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ─── 3) Confirm & Book ──────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => _bookService(context, totalCost),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm & Book Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookService(BuildContext context, double totalCost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Text('You\'re about to pay ₹${totalCost.toStringAsFixed(0)}. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue.')),
      );
      return;
    }

    try {
      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (userDoc.docs.isEmpty) throw 'User profile not found.';

      final data  = userDoc.docs.first.data();
      final phone = data['phone_number'] ?? '';

      final bookingRef = FirebaseFirestore.instance
          .collection('service_request_grooming')
          .doc();

      await bookingRef.set({
        'user_id': uid,
        'petIds': petIds,
        'petNames': petNames,
        'shopId': shopId,
        'shopName': shopName,
        'areaName': areaName,
        'phone_number': phone,
        'selectedDate': selectedDate,
        'selectedTimeSlots': selectedTimeSlots
            .map((s) =>
        '${DateFormat.jm().format(s[0])} - ${DateFormat.jm().format(s[1])}')
            .toList(),
        'hourlyRate': hourlyRate,
        'dailyWalkingRequired': dailyWalkingRequired,
        'walkingFee': walkingFee,
        'foodOption': foodOption,
        'foodCostPerMeal': foodCostPerMeal,
        'feedingTimes': feedingTimes,
        'totalCost': totalCost,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booked successfully!')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
