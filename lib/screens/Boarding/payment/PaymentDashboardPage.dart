import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Brand palette (matches your app vibe)
const Color kPrimary = Color(0xFF2CB4B6);
const Color kAccent  = Color(0xFFF67B0D);
const Color kGreen   = Color(0xFF1DB954);
const Color kRed     = Color(0xFFE53935);
const Color kIndigo  = Color(0xFF3D5AFE);
const Color kBg      = Color(0xFFF6F8FB);

class PaymentDashboardPage extends StatefulWidget {
  final String serviceId;
  const PaymentDashboardPage({super.key, required this.serviceId});

  @override
  State<PaymentDashboardPage> createState() => _PaymentDashboardPageState();
}

class _PaymentDashboardPageState extends State<PaymentDashboardPage> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end: DateTime.now(),
  );
  double ongoingEarnings = 0; // from active confirmed/ongoing bookings


  bool _loading = true;
  String? _error;

  // Aggregates
  double totalBookedInclGst = 0;      // sum(cost_breakdown.total_amount)
  double platformFeePlusGst = 0;      // sum(cost_breakdown.platform_fee_plus_gst)
  double spServiceFee = 0;            // sum(cost_breakdown.sp_service_fee)
  double payoutsDone = 0;             // completed_orders where payout_done==true, sum(sp_service_fee)
  double payoutsPending = 0;          // completed_orders where payout_done==false, sum(sp_service_fee)
  double refundsInclGst = 0;          // sum(sp_cancellation_history.net_refund_including_gst)

  // For tiny bar chart (daily net = sp_service_fee - refunds that day)
  // dateKey "yyyy-MM-dd" -> amount
  final Map<String, double> _dailyNet = {};

  // Tables
  final List<_RefundRow> _recentRefunds = [];
  final List<_PayoutRow> _recentPayouts = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _range = picked);
      _refresh();
    }
  }

  Future<void> _quickRange(int days) async {
    setState(() {
      _range = DateTimeRange(
        start: DateTime.now().subtract(Duration(days: days - 1)),
        end: DateTime.now(),
      );
    });
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;

      totalBookedInclGst = 0;
      platformFeePlusGst = 0;
      spServiceFee = 0;
      payoutsDone = 0;
      payoutsPending = 0;
      refundsInclGst = 0;
      _dailyNet.clear();
      _recentRefunds.clear();
      _recentPayouts.clear();
    });

    try {
      final fs = FirebaseFirestore.instance;
      final sid = widget.serviceId;

      final startTs = Timestamp.fromDate(
        DateTime(_range.start.year, _range.start.month, _range.start.day, 0, 0, 0),
      );
      final endTs = Timestamp.fromDate(
        DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59, 59),
      );

      // 1) Pull active bookings (in this window by booking timestamp)
      final activeSnap = await fs
          .collection('users-sp-boarding')
          .doc(sid)
          .collection('service_request_boarding')
          .where('timestamp', isGreaterThanOrEqualTo: startTs)
          .where('timestamp', isLessThanOrEqualTo: endTs)
          .get();

      // 2) Pull completed orders (use completedAt if present, else timestamp)
      final completedSnap = await fs
          .collection('users-sp-boarding')
          .doc(sid)
          .collection('completed_orders')
          .get();

      // Helper to add to daily bucket
      String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
      void _addDaily(DateTime d, double amt) {
        final k = _key(d);
        _dailyNet[k] = (_dailyNet[k] ?? 0) + amt;
      }

      // ──────────────────────────────────────────────────────────
      // Aggregate on ACTIVE + COMPLETED bookings
      // ──────────────────────────────────────────────────────────
      Future<void> processBookingDoc(DocumentSnapshot doc, {bool isCompleted = false}) async {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final cb = (data['cost_breakdown'] as Map<String, dynamic>?) ?? {};

        // Amounts (robust parsing)
        double _num(dynamic v) {
          if (v == null) return 0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0;
        }

        final booked = _num(cb['total_amount']);                 // incl GST
        final platform = _num(cb['platform_fee_plus_gst']);
        final spFee = _num(cb['sp_service_fee']);                // used for payout too

        totalBookedInclGst += booked;
        platformFeePlusGst += platform;
        spServiceFee += spFee;

        // tiny daily bar: use booking 'timestamp' (fallback now)
        final DateTime when = (data['timestamp'] is Timestamp)
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
        _addDaily(when, spFee);

        // If completed → compute payout buckets
        // If completed → compute payout buckets
        if (isCompleted) {
          final payout = (data['payout_done'] == true);

          if (payout) {
            payoutsDone += spFee;
          } else {
            payoutsPending += spFee;
          }

          // recent payouts table (only show items inside range if completedAt exists)
          DateTime? completedAt = (data['completedAt'] is Timestamp)
              ? (data['completedAt'] as Timestamp).toDate()
              : null;

          if (payout || data.containsKey('payout_id')) {
            DateTime? completedAt = (data['payout_time'] is Timestamp)
                ? (data['payout_time'] as Timestamp).toDate()
                : (data['completedAt'] is Timestamp)
                ? (data['completedAt'] as Timestamp).toDate()
                : DateTime.now();

            if (!completedAt.isBefore(_range.start) && !completedAt.isAfter(_range.end)) {
              _recentPayouts.add(
                _PayoutRow(
                  id: doc.id,
                  payoutId: data['payout_id'], // ✅ add this
                  amount: spFee,
                  when: completedAt,
                  status: (data['payout_status'] ?? (payout ? 'processed' : 'processing')).toString(),
                ),
              );
            }
          }

        } else {
          // ────────────────────────────────────────────────
          // Ongoing / Active service → future payout
          // ────────────────────────────────────────────────
          // Only count confirmed or ongoing statuses
          final status = (data['order_status'] ?? '').toString().toLowerCase();
          if (status == 'confirmed' || status == 'ongoing') {
            ongoingEarnings += spFee;
          }
        }


        //  ── Refunds: read subcollection sp_cancellation_history and sum net_refund_including_gst
        final hist = await doc.reference.collection('sp_cancellation_history').orderBy('created_at', descending: true).get();
        for (final h in hist.docs) {
          final hd = h.data() as Map<String, dynamic>;
          final created = (hd['created_at'] is Timestamp)
              ? (hd['created_at'] as Timestamp).toDate()
              : null;
          if (created == null) continue;
          // Respect date window
          if (created.isBefore(_range.start) || created.isAfter(_range.end)) continue;

          final refundInclGst = _num(hd['net_refund_including_gst']);
          refundsInclGst += refundInclGst;

          // Subtract from that day’s bar
          _addDaily(created, -refundInclGst);

          _recentRefunds.add(
            _RefundRow(
              id: doc.id,
              amount: refundInclGst,
              when: created,
              refundId: (hd['refund_id'] ?? '') as String,
            ),
          );
        }
      }

      // Process active (some may get refunds before completion)
      for (final d in activeSnap.docs) {
        await processBookingDoc(d, isCompleted: false);
      }
      // Process completed
      for (final d in completedSnap.docs) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        // date filter for completed: prefer completedAt in range, OR include all then table filters handle view
        final completedAt = (data['completedAt'] is Timestamp)
            ? (data['completedAt'] as Timestamp).toDate()
            : null;
        // Keep wide here; the daily/summary already used booking timestamp.
        await processBookingDoc(d, isCompleted: true);
      }

      // Sort tables
      _recentRefunds.sort((a, b) => b.when.compareTo(a.when));
      _recentPayouts.sort((a, b) => b.when.compareTo(a.when));

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // Helpers
  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: Text('Payment Dashboard', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _refresh)
            : RefreshIndicator(
          color: kPrimary,
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, cons) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterBar(
                      range: _range,
                      onPick: _pickRange,
                      onQuick7: () => _quickRange(7),
                      onQuick30: () => _quickRange(30),
                    ),
                    const SizedBox(height: 16),
                    _KpiGrid(
                      isWide: isWide,
                      items: [
                        KpiItem(
                          title: 'Your Earnings',
                          value: _money(ongoingEarnings + payoutsPending + payoutsDone),
                          sub: 'Ongoing + Pending + Paid',
                          color: kGreen,
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        KpiItem(
                          title: 'Ongoing Earnings',
                          value: _money(ongoingEarnings),
                          sub: 'Active bookings',
                          color: kIndigo,
                          icon: Icons.timelapse_rounded,
                        ),
                        KpiItem(
                          title: 'Pending Payouts',
                          value: _money(payoutsPending),
                          sub: 'Awaiting transfer',
                          color: kAccent,
                          icon: Icons.hourglass_bottom_rounded,
                        ),
                        KpiItem(
                          title: 'Completed Payouts',
                          value: _money(payoutsDone),
                          sub: 'Sent to bank',
                          color: kPrimary,
                          icon: Icons.payments_rounded,
                        ),
                        KpiItem(
                          title: 'Refunds',
                          value: _money(refundsInclGst),
                          sub: 'Issued (incl. GST)',
                          color: kRed,
                          icon: Icons.receipt_long_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    _MiniDailyBars(
                      range: _range,
                      daily: _dailyNet,
                    ),
                    const SizedBox(height: 18),
                    _TwoUp(
                      left: _CardShell(
                        title: 'Recent Refunds',
                        color: kRed,
                        child: _RefundTable(rows: _recentRefunds),
                      ),
                      right: _CardShell(
                        title: 'Recent Payouts',
                        color: kPrimary,
                        child: _PayoutTable(rows: _recentPayouts),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoNote(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Widgets
/// ─────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onQuick7;
  final VoidCallback onQuick30;
  final VoidCallback onPick;

  const _FilterBar({
    required this.range,
    required this.onQuick7,
    required this.onQuick30,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final txt = DateFormat('dd MMM').format(range.start) == DateFormat('dd MMM').format(range.end)
        ? DateFormat('dd MMM, yyyy').format(range.start)
        : '${DateFormat('dd MMM, yyyy').format(range.start)} — ${DateFormat('dd MMM, yyyy').format(range.end)}';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ChipButton(label: 'Last 7 Days', icon: Icons.calendar_view_week_rounded, onTap: onQuick7, color: kPrimary),
            _ChipButton(label: 'Last 30 Days', icon: Icons.date_range_rounded, onTap: onQuick30, color: kPrimary),
            _ChipButton(label: txt, icon: Icons.today_rounded, onTap: onPick, color: kAccent),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ChipButton({required this.label, required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(.12), color.withOpacity(.04)]),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final bool isWide;
  final List<KpiItem> items;

  const _KpiGrid({required this.isWide, required this.items});

  @override
  Widget build(BuildContext context) {
    final cross = isWide ? 2 : 1;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        childAspectRatio: isWide ? 2.5 : 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => _KpiCard(item: items[i]),
    );
  }
}

class KpiItem {
  final String title;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  KpiItem({required this.title, required this.value, required this.sub, required this.color, required this.icon});
}

class _KpiCard extends StatelessWidget {
  final KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [item.color.withOpacity(.12), Colors.white]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.color.withOpacity(.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: item.color.withOpacity(.12), shape: BoxShape.circle),
            padding: const EdgeInsets.all(10),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item.sub, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDailyBars extends StatelessWidget {
  final DateTimeRange range;
  final Map<String, double> daily;

  const _MiniDailyBars({required this.range, required this.daily});

  @override
  Widget build(BuildContext context) {
    // build ordered days
    final days = <DateTime>[];
    DateTime d = DateTime(range.start.year, range.start.month, range.start.day);
    while (!d.isAfter(range.end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    final vals = days.map((dd) => daily[DateFormat('yyyy-MM-dd').format(dd)] ?? 0).toList();
    final maxAbs = (vals.isEmpty) ? 1.0 : vals.map((e) => e.abs()).reduce(max).clamp(1, double.infinity);

    return _CardShell(
      title: 'Daily Net (Earnings - Refunds)',
      color: kIndigo,
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < days.length; i++) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // bar (positive above mid, negative below)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, c) {
                          final mid = c.maxHeight / 2;
                          final v = vals[i];
                          final h = (v.abs() / maxAbs) * (mid - 6);
                          return Stack(
                            children: [
                              // mid line
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment(0, 0),
                                  child: Container(height: 1, color: Colors.black12),
                                ),
                              ),
                              // bar
                              Align(
                                alignment: v >= 0 ? Alignment.bottomCenter : Alignment.topCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 10,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: v >= 0 ? kGreen : kRed,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(DateFormat('d MMM').format(days[i]),
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _TwoUp extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoUp({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      children: [
        left,
        const SizedBox(height: 12),
        right,
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final Color color;
  final Widget child;

  const _CardShell({required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.insights_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _RefundRow {
  final String id;
  final String refundId;
  final double amount;
  final DateTime when;

  _RefundRow({required this.id, required this.amount, required this.when, required this.refundId});
}
class _PayoutRow {
  final String id;
  final String? payoutId;
  final double amount;
  final DateTime when;
  final String status;

  _PayoutRow({
    required this.id,
    required this.amount,
    required this.when,
    required this.status,
    this.payoutId,
  });
}

class _RefundTable extends StatelessWidget {
  final List<_RefundRow> rows;
  const _RefundTable({required this.rows});

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text('No refunds in this range',
              style: GoogleFonts.poppins(color: Colors.black54)),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        dataTextStyle: GoogleFonts.poppins(),
        columns: const [
          DataColumn(label: Text('When')),
          DataColumn(label: Text('Order ID')),

          DataColumn(label: Text('Refund ID')),
          DataColumn(label: Text('Amount')),
        ],
        rows: rows.take(20).map((r) {
          return DataRow(cells: [
            DataCell(Text(DateFormat('d MMM, h:mm a').format(r.when))),
            DataCell(Text(r.id)),
            DataCell(Text(r.refundId.isEmpty ? '—' : r.refundId)),
            DataCell(Text(_money(r.amount), style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
          ]);
        }).toList(),
      ),
    );
  }
}

class _PayoutTable extends StatelessWidget {
  final List<_PayoutRow> rows;
  const _PayoutTable({required this.rows});

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text('No payouts in this range',
              style: GoogleFonts.poppins(color: Colors.black54)),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        dataTextStyle: GoogleFonts.poppins(),
        columns: const [
          DataColumn(label: Text('When')),
          DataColumn(label: Text('Order ID')),
          DataColumn(label: Text('Payout ID')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows.take(20).map((r) {
          return DataRow(cells: [
            DataCell(Text(DateFormat('d MMM, h:mm a').format(r.when))),
            DataCell(Text(r.id)),
            DataCell(Text(r.payoutId ?? '—')), // ✅ use payoutId property
            DataCell(Text(_money(r.amount), style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (r.status == 'processed'
                    ? kGreen
                    : r.status == 'reversed' || r.status == 'rejected'
                    ? kRed
                    : kAccent)
                    .withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                r.status.isNotEmpty ? r.status.toUpperCase() : 'PROCESSING',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: (r.status == 'processed'
                      ? kGreen
                      : r.status == 'reversed' || r.status == 'rejected'
                      ? kRed
                      : kAccent),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}


class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: kRed, size: 36),
              const SizedBox(height: 10),
              Text('Something went wrong', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message, style: GoogleFonts.poppins(color: Colors.black54)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
            'Notes:\n'
                '• “Your Earnings” = Ongoing + Pending + Completed payouts.\n'
                '• “Ongoing Earnings” shows confirmed but unfinished bookings.\n'
                '• “Refunds” include provider-side refunds (incl. GST).\n'
                '• “Completed Payouts” reflect payouts already sent to your bank.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}
