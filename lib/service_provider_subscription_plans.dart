import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myfellowpet_sp/subcheckoutpage.dart';

class SubscriptionPlansPage extends StatelessWidget {
  final String serviceId;

  const SubscriptionPlansPage({
    super.key,
    required this.serviceId,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Choose Your Plan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_provider_subscription_plans')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No plans available."));
          }

          final plans = snapshot.data!.docs;

          return LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;

              if (constraints.maxWidth >= 1200) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth >= 800) {
                crossAxisCount = 2;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    Text(
                      "Subscription Plans",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),
                    Text(
                      "Choose a plan that best suits your service requirements.",
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 40),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: plans.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (context, index) {
                        final planDoc = plans[index];
                        final plan = planDoc.data() as Map<String, dynamic>;

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 360, // 👈 perfect desktop card width
                            ),
                            child: _PlanCard(
                              serviceId: serviceId,
                              plan: plan,
                              planId: planDoc.id,
                            ),
                          ),
                        );
                      },

                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String planId;
  final String serviceId;

  const _PlanCard({required this.plan, required this.planId, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Plan Name (Heading)
          Text(
            plan['planName'] ?? 'Plan',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          /// Key - Value rows
          _InfoRow(
            label: "Duration",
            value: "${plan['durationMonths']} Month(s)",
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: "Price",
            value: "₹${plan['price']}",
            valueColor: Colors.teal,
          ),

          const SizedBox(height: 14),
          const Divider(height: 20),

          /// Features
          /// Features
          if (plan['features'] != null)
            _FeaturesPreview(
              features: List<String>.from(plan['features']),
            ),


          const Spacer(),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users-sp-boarding')
                .doc(serviceId)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasActivePlan = false;
              DateTime? expiryDate;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;

                if (data['status'] == 'active' && data['endDate'] != null) {
                  hasActivePlan = true;
                  expiryDate = (data['endDate'] as Timestamp).toDate();
                }
              }

              final String buttonText = hasActivePlan
                  ? "Active till ${_formatDate(expiryDate!)}"
                  : "Select Plan";

              final Widget button = SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    hasActivePlan ? Colors.grey : Colors.teal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: hasActivePlan
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionCheckoutPage(
                          serviceId: serviceId,
                          plan: plan,
                          planId: planId,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    buttonText,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );

              // ✅ Tooltip only when disabled
              return hasActivePlan
                  ? Tooltip(
                message: "You already have an active subscription",
                child: button,
              )
                  : button;
            },
          ),

        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-"
      "${date.month.toString().padLeft(2, '0')}-"
      "${date.year}";
}


class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "$label :",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}


class _FeaturesPreview extends StatelessWidget {
  final List<String> features;

  const _FeaturesPreview({required this.features});

  @override
  Widget build(BuildContext context) {
    final visible = features.take(2).toList();
    final remaining = features.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map(
              (f) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    f,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (remaining > 0)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Colors.teal,
            ),
            onPressed: () => _showFeatures(context),
            child: Text(
              "View all features ($remaining)",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _showFeatures(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      _showBottomSheet(context);
    } else {
      _showAnimatedDialog(context);
    }
  }

  // ---------------- MOBILE: BOTTOM SHEET ----------------
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FeaturesContent(
        features: features,
        isBottomSheet: true,
      ),
    );
  }

  // ---------------- DESKTOP: ANIMATED DIALOG ----------------
  void _showAnimatedDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Features",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) {
        return Center(
          child: _FeaturesContent(
            features: features,
            isBottomSheet: false,
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
class _FeaturesContent extends StatelessWidget {
  final List<String> features;
  final bool isBottomSheet;

  const _FeaturesContent({
    required this.features,
    required this.isBottomSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isBottomSheet ? double.infinity : 420,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Plan Features",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// Scrollable list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: features.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        features[index],
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
