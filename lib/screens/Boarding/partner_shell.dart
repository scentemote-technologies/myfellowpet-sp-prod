import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:go_router/go_router.dart'; // REMOVED: No longer needed
import 'package:google_fonts/google_fonts.dart';
import 'package:myfellowpet_sp/screens/Boarding/payment/PaymentDashboardPage.dart';
import 'package:myfellowpet_sp/screens/Boarding/roles/role_service.dart';
import 'package:myfellowpet_sp/screens/Boarding/service_requests_page.dart';
import 'package:myfellowpet_sp/screens/Partner/email_signin.dart'; // REQUIRED: For sign-out navigation
import 'package:provider/provider.dart';

import '../../Widgets/reusable_splash_screen.dart';
import '../../providers/boarding_details_loader.dart';
import 'DaycareComingSoon.dart';
import 'ServiceProviderCalendarPage.dart';
import 'Service_Analytics_Page.dart';
import 'chat_support/chat_support.dart';
import 'employees/employees_management.dart';
import 'faq_sp.dart';
import 'logout_page.dart';

// --- NEW ENUM FOR PAGE IDENTIFICATION ---
enum PartnerPage {
  profile,
  overnightRequests,
  payments,
  schedule,
  performanceMonitor,
  faq,
  support,
  employees,
  settings,
  // Used for pages that are not main sidebar items (e.g., Edit, Ticket Detail)
  other,
}
// ----------------------------------------

const Color primary = Color(0xFF2CB4B6);
const double sidebarWidth = 300.0;
const double kDesktopBreakpoint = 1000.0;

class PartnerShell extends StatelessWidget {
  final String serviceId;
  final PartnerPage currentPage; // NEW: Used for title and sidebar highlighting
  final Widget child;
  final Widget? phonePreview;

  // Updated _menuItems to use the PartnerPage enum instead of paths
  static const _menuItems = [
    {'label': 'Overview', 'icon': Icons.dashboard, 'page': PartnerPage.profile},
    {'label': 'Overnight Requests', 'icon': Icons.nights_stay, 'page': PartnerPage.overnightRequests},
    {'label': 'Payments', 'icon': Icons.payment, 'page': PartnerPage.payments},
    {'label': 'Schedule', 'icon': Icons.schedule, 'page': PartnerPage.schedule},
    {'label': 'Performance', 'icon': Icons.show_chart, 'page': PartnerPage.performanceMonitor},
    {'label': 'FAQ', 'icon': Icons.question_answer, 'page': PartnerPage.faq},
    {'label': 'Support', 'icon': Icons.support_agent, 'page': PartnerPage.support},
    {'label': 'Employees', 'icon': Icons.group, 'page': PartnerPage.employees},
    {'label': 'Settings', 'icon': Icons.settings, 'page': PartnerPage.settings},
  ];

  const PartnerShell({
    Key? key,
    required this.serviceId,
    required this.currentPage, // REQUIRED
    required this.child,
    this.phonePreview,
  }) : super(key: key);

  // UPDATED: Now determines the title based on the passed 'currentPage' enum
  String _getCurrentTitle() {
    for (final item in _menuItems) {
      if (item['page'] == currentPage) {
        return item['label'] as String;
      }
    }
    // Default title for pages like Edit/Ticket Detail (PartnerPage.other)
    return 'Partner Panel';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kDesktopBreakpoint;

        if (isWide) {
          // DESKTOP / WIDE LAYOUT
          double mainContentWidth = constraints.maxWidth - sidebarWidth - 1;
          if (phonePreview != null) {
            mainContentWidth -= 400;
          }

          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: sidebarWidth,
                  color: Colors.white,
                  child: _SidebarContent(
                    serviceId: serviceId,
                    currentPage: currentPage, // PASS NEW PROPERTY
                    onSignOut: () => _confirmAndSignOut(context),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: mainContentWidth,
                  child: child,
                ),
                if (phonePreview != null)
                  Container(
                    width: 400,
                    color: Colors.grey.shade100,
                    child: phonePreview,
                  ),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              // UPDATED: Use the local method that checks the enum
              title: Text(
                _getCurrentTitle(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
              actions: [
                if (phonePreview != null)
                  IconButton(
                    icon: const Icon(Icons.phone_iphone_outlined),
                    onPressed: () => _showPhonePreviewDialog(context),
                  ),
              ],
            ),
            drawer: Drawer(
              width: sidebarWidth,
              child: _SidebarContent(
                serviceId: serviceId,
                currentPage: currentPage, // PASS NEW PROPERTY
                onSignOut: () {
                  Navigator.of(context).pop();
                  _confirmAndSignOut(context);
                },
              ),
            ),
            body: child,
          );
        }
      },
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sign Out', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldSignOut) return;

    await FirebaseAuth.instance.signOut();

    // REPLACED context.go('/') with standard Navigator
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => SignInPage()), // Assuming SignInPage is the target of '/'
            (Route<dynamic> route) => false, // Remove all previous routes
      );
    }
  }

  void _showPhonePreviewDialog(BuildContext context) {
    if (phonePreview == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 350,
          height: 700,
          padding: const EdgeInsets.all(8),
          child: phonePreview,
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final String serviceId;
  final PartnerPage currentPage; // NEW: For selection logic
  final VoidCallback onSignOut;

  const _SidebarContent({
    Key? key,
    required this.serviceId,
    required this.currentPage, // REQUIRED
    required this.onSignOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // REMOVED: final base = '/partner/$serviceId';
    // REMOVED: final location = GoRouterState.of(context).uri.toString();
    final me = context.watch<UserNotifier>().me;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        // ------------------ HEADER ------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/mfplogo.jpg', height: 50, width: 50),
              const SizedBox(width: 8),
              Text(
                'Partner Panel',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade300),

        // ------------------ MENU LIST ------------------
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: PartnerShell._menuItems.length,
            itemBuilder: (ctx, i) {
              final item = PartnerShell._menuItems[i];
              final targetPage = item['page'] as PartnerPage; // Get the page enum

              // UPDATED: Use the new currentPage property for selection
              final selected = currentPage == targetPage;

              return Material(
                color: selected ? primary.withOpacity(0.9) : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (Scaffold.of(context).isDrawerOpen) Navigator.of(context).pop();

                    // REPLACED context.go(target) with a generic push action.
                    // IMPORTANT: You must replace this with the actual Navigator.push() to the
                    // widget associated with 'targetPage'.
                    _handleSidebarNavigation(context, targetPage, serviceId);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: selected ? Colors.white : Colors.grey[700],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? Colors.white : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // ------------------ USER SECTION / EMAIL / USER ID / SIGN OUT (UNCHANGED) ------------------
        // ... (rest of the code is unchanged) ...

        if (me != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : null,
                  child: currentUser?.photoURL == null
                      ? const Icon(Icons.person, size: 24, color: Colors.white)
                      : null,
                  backgroundColor: Colors.grey.shade400,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 0),
                      Text(
                        me.role ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ------------------ EMAIL ------------------
        if (me != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Email ID: ",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                Expanded(
                  child: Tooltip(
                    message: currentUser?.email ?? '',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Text(
                      currentUser?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),


// ------------------ USER ID ------------------
        if (me != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "User ID: ",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                Expanded(
                  child: Tooltip(
                    message: me.uid,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Text(
                      me.uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),

                IconButton(
                  icon: Icon(Icons.copy, size: 14, color: Colors.grey[600]),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: me.uid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ),

        // ------------------ SIGN OUT ------------------
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onSignOut,
          ),
        ),
      ],
    );
  }
}
// Helper function moved here for completeness (based on your old routes.dart)
Future<bool> checkPaymentEnabled() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('payment')
        .get();

    // Check the specific field for the web dashboard
    return doc.data()?['boarder_web_dashboard_payment_enabled'] == true;
  } catch (e) {
    print('⚠️ Failed to check payment enabled: $e');
    return false;
  }
}

// You will need to define this function somewhere accessible (maybe in a helper file, or at the top of your PartnerShell page if you keep all imports there)
// This function determines which page widget to load and pushes it wrapped in a new PartnerShell.
void _handleSidebarNavigation(BuildContext context, PartnerPage page, String serviceId) {

  // We need to clear the current view and replace it with the new page wrapped in the PartnerShell
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) {
        // --- IMPORTANT: Map the PartnerPage enum to the actual loader widget ---
        final Widget targetChild;

        switch (page) {
          case PartnerPage.profile:
          // targetChild = BoardingDetailsLoader(serviceId: serviceId);
            targetChild = BoardingDetailsLoader(serviceId: serviceId);
            break;

          case PartnerPage.overnightRequests:
          // targetChild = ServiceRequestsPage(serviceId: serviceId);
            targetChild = ServiceRequestsPage(serviceId: serviceId);
            break;

          case PartnerPage.payments:
          // This case requires the conditional check via FutureBuilder
            targetChild = FutureBuilder<bool>(
              future: checkPaymentEnabled(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final isEnabled = snapshot.data ?? false;

                return isEnabled
                    ? PaymentDashboardPage(serviceId: serviceId)
                    : DaycareComingSoonPage();
              },
            );
            break;

          case PartnerPage.schedule:
          // targetChild = ServiceProviderCalendarPage(serviceId: serviceId);
            targetChild = ServiceProviderCalendarPage(serviceId: serviceId);
            break;

          case PartnerPage.performanceMonitor:
          // targetChild = ServiceAnalyticsPage(serviceId: serviceId);
            targetChild = ServiceAnalyticsPage(serviceId: serviceId);
            break;

          case PartnerPage.faq:
          // Note: SpFaqPage has an onTap handler that needs to navigate to Support
            targetChild = SpFaqPage(
              serviceId: serviceId,
              // The onTap action must call _handleSidebarNavigation recursively
              onContactSupport: () => _handleSidebarNavigation(context, PartnerPage.support, serviceId),
            );
            break;

          case PartnerPage.support:
          // targetChild = _ChatPageLoader(serviceId: serviceId, ticketId: null);
            targetChild = _ChatPageLoader(serviceId: serviceId, ticketId: null);
            break;

          case PartnerPage.employees:
          // targetChild = EmployeePage(serviceId: serviceId);
            targetChild = EmployeePage(serviceId: serviceId);
            break;

          case PartnerPage.settings:
          // targetChild = SettingsPage(serviceId: serviceId);
          // Note: SettingsPage also has onTap handlers for FAQ and Support
            targetChild = SettingsPage(
              serviceId: serviceId,
              onFAQ: () => _handleSidebarNavigation(context, PartnerPage.faq, serviceId),
              onContactSupport: () => _handleSidebarNavigation(context, PartnerPage.support, serviceId),
            );
            break;

          case PartnerPage.other:
          targetChild = const Center(child: Text('Navigation Error: Page not defined in menu.'));
            break;
        }

        // Return the new PartnerShell with the correct page highlighted
        return PartnerShell(
          serviceId: serviceId,
          currentPage: page, // Pass the target page to highlight it
          child: targetChild,
        );
      },
    ),
  );
}


class _ChatPageLoader extends StatefulWidget {
  final String serviceId;
  final String? ticketId;

  const _ChatPageLoader({
    Key? key,
    required this.serviceId,
    this.ticketId,
  }) : super(key: key);

  @override
  State<_ChatPageLoader> createState() => _ChatPageLoaderState();
}

class _ChatPageLoaderState extends State<_ChatPageLoader> {
  late Future<Widget> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
  }

  @override
  void didUpdateWidget(covariant _ChatPageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId || oldWidget.ticketId != widget.ticketId) {
      setState(() {
        _loadFuture = _loadChatPage(widget.serviceId, widget.ticketId);
      });
    }
  }

  Future<Widget> _loadChatPage(String serviceId, String? ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignInPage(); // Protected by router, but good fallback
    }

    // Fetch the service provider's document
    final snap = await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .where('service_id', isEqualTo: serviceId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      return const Center(child: Text("Error: Service provider profile not found."));
    }

    final d = snap.docs.first.data();

    // Extract the required fields (using the same fields as your _PartnerLoader)
    final shopName = d['shop_name'] as String? ?? '';
    final shopEmail = d['notification_email'] as String? ?? '';
    final shopPhone = d['dashboard_phone'] as String? ?? '';

    // Return the fully-formed SPChatPage
    return SPChatPage(
      initialOrderId: ticketId,
      serviceId: serviceId,
      shop_name: shopName,
      shop_email: shopEmail,
      shop_phone_number: shopPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _loadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ReusableSplashScreen();
        }
        if (snap.hasError) {
          return Center(child: Text("Error loading chat: ${snap.error}"));
        }
        return snap.data!;
      },
    );
  }
}
