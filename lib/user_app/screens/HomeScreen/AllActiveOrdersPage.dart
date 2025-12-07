import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../Boarding/OpenCloseBetween.dart';
import '../Boarding/boarding_confirmation_page.dart';

class AllActiveOrdersPage extends StatelessWidget {
  final List<DocumentSnapshot> docs;

  const AllActiveOrdersPage({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Active Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: docs.isEmpty
          ? Center(
        child: Text(
          'No active orders found.',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const Divider(
          color: Colors.grey,
          thickness: 0.6,
          height: 32,
        ),
        itemBuilder: (context, index) => _buildOrderTile(context, docs[index]),
      ),
    );
  }

  // REPLACE your entire _buildOrderTile method with this one

  Widget _buildOrderTile(BuildContext context, DocumentSnapshot doc) {
    // --- This part is mostly unchanged ---
    final shopName = doc['shopName'] ?? '';
    final shopImageUrl = doc['shop_image'] ?? '';
    final openTime = doc['openTime'] ?? '';
    final closeTime = doc['closeTime'] ?? '';
    final totalCostValue = doc.get('cost_breakdown.total_amount');
    final totalCost = totalCostValue is num
        ? totalCostValue.toDouble()
        : (totalCostValue is String ? double.tryParse(totalCostValue) ?? 0.0 : 0.0);
    final petNames = List<String>.from(doc['pet_name'] ?? []);
    final petImages = List<String>.from(doc['pet_images'] ?? []);
    final serviceId = doc['service_id'] ?? '';
    final bookingId = doc.id;

    // --- ⬇️ MODIFICATION: Display Date Range ---
    final dates = (doc['selectedDates'] as List?)?.map((d) => (d as Timestamp).toDate()).toList() ?? [];
    final sortedDates = List<DateTime>.from(dates)..sort();

    String displayDateStr;
    String dateLabel = 'Date:';

    if (sortedDates.isEmpty) {
      displayDateStr = 'No dates selected';
    } else if (sortedDates.length == 1) {
      // If only one date, show it fully
      displayDateStr = DateFormat('dd MMM, yyyy').format(sortedDates.first);
    } else {
      // If multiple dates, show a range
      dateLabel = 'Dates:';
      final firstDate = DateFormat('dd MMM').format(sortedDates.first);
      final lastDate = DateFormat('dd MMM, yyyy').format(sortedDates.last);
      displayDateStr = '$firstDate - $lastDate';
    }
    // --- ⬆️ MODIFICATION END ---

    return InkWell(
      onTap: () async {
        // The onTap logic remains the same as before
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};

          final costBreakdown = data['cost_breakdown'] as Map<String, dynamic>? ?? {};
          final foodCost = double.tryParse(costBreakdown['meals_cost']?.toString() ?? '0') ?? 0.0;
          final walkingCost = double.tryParse(costBreakdown['daily_walking_cost']?.toString() ?? '0') ?? 0.0;
          final transportCost = double.tryParse(costBreakdown['transport_cost']?.toString() ?? '0') ?? 0.0;

          final petIds = List<String>.from(data['pet_id'] ?? []);
          final fullAddress = data['fullAddress'] ?? 'Address not found';
          final spLocation = data['sp_location'] as GeoPoint? ?? const GeoPoint(0, 0);

          final Map<String, int> rates = {};
          final Map<String, int> mealRates = {};
          final Map<String, int> walkingRates = {};
          final petSizesList = data['pet_sizes'] as List<dynamic>? ?? [];

          for (final petInfo in petSizesList) {
            final petData = petInfo as Map<String, dynamic>;
            final petId = petData['id'] as String?;
            final price = (petData['price'] as num?)?.toInt() ?? 0;
            final mealFee = (petData['mealFee'] as num?)?.toInt() ?? 0;
            final walkFee = (petData['walkFee'] as num?)?.toInt() ?? 0;

            if (petId != null) {
              rates[petId] = price;
              mealRates[petId] = mealFee;
              walkingRates[petId] = walkFee;
            }
          }

          final Map<String, Map<String, dynamic>> perDayServices = {};
          final petServicesSnapshot = await doc.reference.collection('pet_services').get();

          for (var petDoc in petServicesSnapshot.docs) {
            final petDocData = petDoc.data() as Map<String, dynamic>? ?? {};
            perDayServices[petDoc.id] = {
              'name': petDocData['name'] ?? 'No Name',
              'size': petDocData['size'] ?? 'Unknown Size',
              'image': petDocData['image'] ?? '',
              'dailyDetails': petDocData['dailyDetails'] ?? {},
            };
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConfirmationPage(
                perDayServices: perDayServices,
                petIds: petIds,
                foodCost: foodCost,
                walkingCost: walkingCost,
                transportCost: transportCost,
                rates: rates,
                mealRates: mealRates,
                walkingRates: walkingRates,
                fullAddress: fullAddress,
                sp_location: spLocation,
                shopName: shopName,
                fromSummary: false,
                shopImage: shopImageUrl,
                selectedDates: dates,
                totalCost: totalCost,
                petNames: petNames,
                openTime: openTime,
                closeTime: closeTime,
                bookingId: bookingId,
                buildOpenHoursWidget: buildOpenHoursWidget(openTime, closeTime, dates),
                sortedDates: sortedDates,
                petImages: petImages,
                serviceId: serviceId,
              ),
            ),
          );
        } catch (e, s) {
          print('❌❌❌ AN ERROR OCCURRED ❌❌❌');
          print('Error navigating to confirmation page: $e');
          print('Stack trace: $s');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not load order details. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: shopImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: shopImageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.red, size: 48),
              )
                  : Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // --- ⬇️ MODIFICATION: Use the new date string ---
                  Text(
                    '$dateLabel $displayDateStr',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                  ),
                  // --- ⬆️ MODIFICATION END ---
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Details',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      color: Colors.black54,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
