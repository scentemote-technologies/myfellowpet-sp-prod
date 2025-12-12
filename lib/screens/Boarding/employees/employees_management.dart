// NEW, PREFIXED IMPORT
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart' as staggered;import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// Assuming these imports are correctly pointing to your files
import '../../../EmployeeComingSoon.dart';
import '../partner_shell.dart';
import '../roles/role_service.dart';
import 'employee_tasks.dart'; // Uncomment if TasksPage is needed and defined here

const Color primaryColor = Color(0xFF25ADAD);
const Color accentColor = Color(0xFFF67B0D);

class EmployeePage extends StatefulWidget {
  final String serviceId;
  const EmployeePage({Key? key, required this.serviceId}) : super(key: key);

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  bool _isLoading = true;
  int employeeLimit = 0;

  // Assuming a placeholder for your UserNotifier for context
  // Replace with your actual implementation

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    // This logic remains the same
    final snapshot = await FirebaseFirestore.instance
        .collection('company_documents')
        .doc('employees')
        .get();

    final raw = snapshot.data()?['boarding'];
    final limit = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;

    if (mounted) {
      setState(() {
        employeeLimit = limit;
        _isLoading = false;
      });
    }
  }

  void _showFormerEmployeesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Former Employees', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8, // Responsive width
          height: MediaQuery.of(context).size.height * 0.7,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users-sp-boarding')
                .doc(widget.serviceId)
                .collection('former_employees')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryColor));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState('No Former Employees', 'This list is empty.');
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  // We'll reuse the employee card but tell it this is a "former" employee
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildEmployeeCard(docs[index], isFormerEmployee: true),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _styledButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return TextButton.icon(
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }



  void _openAddEmployeeForm(int currentCount) {
  Navigator.of(context).push(
  MaterialPageRoute(
  builder: (context) => AddEmployeePage(
    serviceId: widget.serviceId,
    employeeCount: currentCount,
    employeeLimit: employeeLimit,
    onAdded:  () => setState(() {}),
  ), // Use 'const' if possible
  ),
  );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<UserNotifier>().me;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("settings")
          .doc("employees")
          .snapshots(),
      builder: (context, settingSnap) {
        if (settingSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        final settingData = settingSnap.data?.data() as Map<String, dynamic>?;

        final bool isAllowed =
            settingData?["home_boarder_web_sp"] == true;

        // ❌ If false → show Coming Soon instead of Employee Page
        if (!isAllowed) {
          return const EmployeeComingSoon(); // <-- your coming soon page
        }

        // ❇️ If allowed → continue showing normal employee UI below
        final List<String> visibleRoles = (me?.role == 'Owner')
            ? ['Owner', 'Manager', 'Staff']
            : (me?.role == 'Manager')
            ? ['Manager', 'Staff']
            : ['Staff'];

        if (_isLoading) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text('Employees', style: GoogleFonts.poppins()),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        return DefaultTabController(
          length: visibleRoles.length,
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              scrolledUnderElevation: 0.5,
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'Employees',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              actions: [
                if (me?.role != 'Staff')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _styledButton(
                      'Ex-Employees',
                      Icons.edit_outlined,
                      primaryColor,
                          () => _showFormerEmployeesDialog(),
                    ),
                  ),
              ],
              bottom: TabBar(
                indicator: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.poppins(),
                tabs: visibleRoles.map((r) => Tab(text: r)).toList(),
              ),
            ),

            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users-sp-boarding')
                  .doc(widget.serviceId)
                  .collection('employees')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _buildEmptyState(
                      'No Employees Found',
                      'Add your first employee to get started.');
                }

                final docs = snap.data!.docs;

                return TabBarView(
                  children: visibleRoles.map((role) {
                    final roleDocs = docs.where((d) {
                      final data = d.data()! as Map<String, dynamic>;
                      return data['role'] == role;
                    }).toList();

                    if (roleDocs.isEmpty) {
                      return _buildEmptyState(
                        'No $role Found',
                        'There are currently no employees assigned to this role.',
                      );
                    }

                    return LayoutBuilder(
                      builder: (ctx, constraints) {
                        final crossCount =
                        (constraints.maxWidth / 350).floor().clamp(1, 4);
                        return staggered.MasonryGridView.count(
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: crossCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          itemCount: roleDocs.length,
                          itemBuilder: (ctx, i) => _buildEmployeeCard(roleDocs[i])
                              .animate()
                              .fadeIn(duration: 400.ms, delay: (i * 50).ms)
                              .slideY(begin: 0.2, end: 0),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),

            floatingActionButton:
            me?.role == 'Owner' ? _buildFloatingActionButton() : null,
          ),
        );
      },
    );
  }


  Widget _buildFloatingActionButton() {
    return Builder(
      builder: (fabCtx) {
        final tabController = DefaultTabController.of(fabCtx);
        return AnimatedBuilder(
          animation: tabController.animation!,
          builder: (_, __) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users-sp-boarding')
                  .doc(widget.serviceId)
                  .snapshots(),
              builder: (_, parentSnap) {
                if (!parentSnap.hasData) {
                  return const SizedBox.shrink(); // hide while loading
                }

                final data = parentSnap.data!.data() as Map<String, dynamic>?;
                final adminApproved = data?['adminApproved'] == true;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users-sp-boarding')
                      .doc(widget.serviceId)
                      .collection('employees')
                      .snapshots(),
                  builder: (_, snap) {
                    final allDocs = snap.data?.docs ?? [];
                    final totalCount = allDocs.length;
                    final hitOverall = totalCount >= employeeLimit;

                    final canAdd = !hitOverall;
                    final tooltipMessage = hitOverall
                        ? 'Employee limit of $employeeLimit reached'
                        : 'Add New Employee';

                    return FloatingActionButton.extended(
                      onPressed: () {
                        if (!adminApproved) {
                          ScaffoldMessenger.of(fabCtx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'You can add employees once your service has been approved by the admin.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (canAdd) {
                          _openAddEmployeeForm(totalCount);
                        }
                      },
                      tooltip: tooltipMessage,
                      backgroundColor:
                      (adminApproved && canAdd) ? primaryColor : Colors.grey.shade400,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        'Add Employee',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ).animate().scale(duration: 300.ms);
                  },
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(DocumentSnapshot doc, {bool isFormerEmployee = false}) {    final data = doc.data()! as Map<String, dynamic>;
    final employeeId = doc.id;
    final bool isActive = isFormerEmployee ? false : (data['active'] ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important: This helps the column shrink
          children: [
            // --- HEADER: Avatar, Name, Role, and Status Toggle ---
            // ... (Header Row is unchanged)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  backgroundImage:
                  data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
                  child: data['photoUrl'] == null
                      ? Text(
                    data['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: GoogleFonts.poppins(
                        color: primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w600),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'No Name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['jobTitle'] ?? 'No Title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)
                        ),
                        child: Text(
                          data['role'] ?? 'No Role',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                // Only show the Switch for CURRENT employees
                if (!isFormerEmployee)
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isActive,
                      activeColor: primaryColor,
                      onChanged: (newVal) => _toggleEmployeeStatus(doc, newVal),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEEEEEE)),
            const SizedBox(height: 8),

            // --- DETAILS (WITH UPDATE) ---
            _infoRow(Icons.email_outlined, data['email']),
            _infoRow(Icons.call, data['phone']),

            // THIS IS THE ONLY CHANGE IN THIS SECTION
            _ExpandableInfoRow(icon: Icons.location_pin, value: data['address']),

            // The Spacer is now gone! Replaced with a SizedBox for consistent spacing.
            const SizedBox(height: 16),

            // --- ACTION BUTTONS ---
            // ... (Action buttons are unchanged)
            // --- ACTION BUTTONS (Updated Logic) ---
            Row(
              children: [
                // --- Case 1: For CURRENT Employees ---
                if (!isFormerEmployee) ...[
                  // Show "Tasks" button ONLY if they are active
                  if (isActive)

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => PartnerShell(
                                serviceId: widget.serviceId,
                                // Use 'PartnerPage.other' or a dedicated enum for nested routes
                                currentPage: PartnerPage.other,
                                child: TasksScreen(
                                    serviceId: widget.serviceId,
                                    employeeId: employeeId
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.task, size: 18, color: primaryColor),
                        label: const Text('Tasks'),
                        style: _actionButtonStyle(),
                      ),
                    ),
                  // Add spacing if the Tasks button was shown
                  if (isActive) const SizedBox(width: 8),

                  // "ID" button is always shown for current employees if the URL exists
                  if (data['idProofUrl'] != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          html.AnchorElement(href: data['idProofUrl'])
                            ..setAttribute('download', 'id_proof_${data['name']}')
                            ..click();
                        },
                        icon: const Icon(Icons.perm_identity, size: 18, color: primaryColor),
                        label: const Text('ID'),
                        style: _actionButtonStyle(),
                      ),
                    ),
                  if (data['idProofUrl'] != null) const SizedBox(width: 8),

                  // "Delete" button is always shown for current employees
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                    onPressed: () => _deleteEmployee(doc),
                    style: IconButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade100),
                      backgroundColor: Colors.red.withOpacity(0.05),
                    ),
                  ),
                ],

                // --- Case 2: For FORMER Employees ---
                if (isFormerEmployee)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _restoreEmployee(doc), // You will need to create this function
                      icon: const Icon(Icons.history_toggle_off, size: 18, color: Colors.green),
                      label: const Text('Restore'),
                      style: _actionButtonStyle().copyWith(
                        foregroundColor: MaterialStateProperty.all(Colors.green),
                        side: MaterialStateProperty.all(BorderSide(color: Colors.green.withOpacity(0.3))),
                      ),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Add this function inside your _EmployeePageState class

  Future<void> _restoreEmployee(DocumentSnapshot doc) async {
    // 1. Confirm the action with the user first.
    final confirm = await _showConfirmationDialog(
      title: 'Restore Employee?',
      content: 'Are you sure you want to move this person back to the active employee list?',
      confirmText: 'Yes, Restore',
    );
    if (!confirm) return;

    try {
      // 2. Get the data from the former employee document.
      final data = doc.data()! as Map<String, dynamic>;

      // 3. Prepare the new data for the active employees collection.
      // We set 'active' to true and remove the 'movedToFormerAt' field.
      data['active'] = true;
      data.remove('movedToFormerAt');

      // Get references to the old and new document locations.
      final formerEmployeeRef = FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('former_employees')
          .doc(doc.id);

      final activeEmployeeRef = FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('employees')
          .doc(doc.id);

      // 4. Use a batch write to perform the move atomically.
      // This ensures both operations succeed or both fail together.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(activeEmployeeRef, data); // Create the new active record
      batch.delete(formerEmployeeRef);   // Delete the old former record
      await batch.commit();

      // 5. Show a success message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data['name'] ?? 'Employee'} has been restored.'),
          backgroundColor: Colors.green,
        ),
      );
      // Close the dialog after the action is complete
      Navigator.of(context).pop();

    } catch (e) {
      // Show an error message if something goes wrong.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore employee: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- HELPER METHODS FOR DIALOGS AND ACTIONS ---

  Future<void> _toggleEmployeeStatus(DocumentSnapshot doc, bool newVal) async {
    final confirm = await _showConfirmationDialog(
      title: newVal ? 'Activate Employee?' : 'Deactivate Employee?',
      content: 'Are you sure you want to ${newVal ? "activate" : "deactivate"} this employee?',
    );
    if (!confirm) return;

    await FirebaseFirestore.instance
        .collection('users-sp-boarding')
        .doc(widget.serviceId)
        .collection('employees')
        .doc(doc.id)
        .update({'active': newVal});
  }

  Future<void> _deleteEmployee(DocumentSnapshot doc) async {
    final confirm = await _showConfirmationDialog(
      title: 'Remove Employee?',
      content:
      'This will move the employee to a "former employees" list AND remove their serviceId. This action cannot be undone. Continue?',
      confirmText: 'Yes, Remove',
    );
    if (!confirm) return;

    final dataMap = doc.data()! as Map<String, dynamic>;
    final uid = doc.id; // Assuming doc.id = employee UID

    try {
      // 1️⃣ Remove employee from active employees
      await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('employees')
          .doc(uid)
          .delete();

      // 2️⃣ Remove from directory
      await FirebaseFirestore.instance
          .collection('employeeDirectory')
          .doc(uid)
          .delete();

      // 3️⃣ Move to former employees
      await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .collection('former_employees')
          .doc(uid)
          .set({
        ...dataMap,
        'active': false,
        'movedToFormerAt': Timestamp.now(),
      });

      // 4️⃣ Call your Cloud Function to remove serviceId from custom claims
      final callable =
      FirebaseFunctions.instance.httpsCallable('removeServiceIdFromUser');

      final result = await callable.call({
        "uid": uid,
        "serviceId": widget.serviceId, // pass the specific serviceId
      });

      if (result.data['success'] == true) {
        print("✅ ServiceId removed for $uid");
      } else {
        print("⚠️ Function error: ${result.data['error']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing serviceId: ${result.data['error']}")),
        );
        return;
      }

      // 5️⃣ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee removed successfully")),
      );
    } catch (e) {
      print("🔥 Error removing employee: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }



  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = 'Yes',
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(content, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText, style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  // --- HELPER WIDGETS ---

  ButtonStyle _actionButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: BorderSide(color: primaryColor.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
    );
  }

  Widget _infoRow(IconData icon, String? value) {
    final displayValue = value != null && value.isNotEmpty ? value : '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PLACEHOLDER FOR NOTIFIER ---

class AddEmployeePage extends StatefulWidget {
  final String serviceId;
  final int employeeCount;
  final int employeeLimit;
  final VoidCallback onAdded;

  const AddEmployeePage({
    Key? key,
    required this.serviceId,
    required this.employeeCount,
    required this.employeeLimit,
    required this.onAdded,
  }) : super(key: key);

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {

  bool isSendingOtp = false;
  bool isVerifyingOtp = false;
  bool isPhoneVerified = false;


  String? _emailError;

  final Map<String, dynamic> form = {};
  Uint8List? previewImage;
  bool isUploadingImage = false;
  bool isUploadingID = false;
  bool isSubmitting = false;

  String _selectedRole = _roles.first;
  static const List<String> _roles = ['Owner', 'Manager', 'Staff'];
  static const Map<String, String> _roleDescriptions = {
    'Owner': 'Full access — users, settings, bookings, pricing, staff, analytics, etc.',
    'Manager': 'Can manage bookings, view earnings, assign roles (except Owner), assign tasks, edit listings.',
    'Staff': 'Can view and update bookings, chat with customers, mark pet status.',
  };

  Future<String> _getSmsFunctionName() async {
    final settingsSnap = await FirebaseFirestore.instance
        .collection("settings")
        .doc("employees")
        .get();

    final data = settingsSnap.data() ?? {};

    final bool live = data["number_verification"] == true;

    return live ? "sendSms" : "sendTestSms";
  }

  Future<void> _sendOtp() async {
    if (form["phone"] == null || form["phone"].toString().length < 13) {
      _showAppDialog(context, message: "Enter a valid number first.");
      return;
    }

    setState(() => isSendingOtp = true);

    try {
      final functionName = await _getSmsFunctionName();
      final callable = FirebaseFunctions.instance.httpsCallable(functionName);

      await callable.call({
        "phoneNumber": form["phone"],
        "docId": widget.serviceId,
        "verificationType": "sms",
      });

      _showAppDialog(
        context,
        title: "OTP Sent",
        message: "A verification code has been sent to ${form["phone"]}.",
        icon: Icons.sms,
        iconColor: primaryColor,
      );
    } finally {
      setState(() => isSendingOtp = false);
    }
  }

  Future<void> _pickAndUploadFile(String type) async {
    // 1. Set the correct loading state based on the button pressed
    setState(() {
      if (type == 'photo') {
        isUploadingImage = true;
      } else {
        isUploadingID = true;
      }
    });

    try {
      // 2. Pick the file using file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, // We'll stick to images for both for simplicity
      );

      // If the user cancels the picker, result will be null
      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (fileBytes == null) return; // Make sure we have file data

      // If it's a photo, show a preview immediately
      if (type == 'photo') {
        setState(() {
          previewImage = fileBytes;
        });
      }

      // 3. Create a reference in Firebase Storage
      // We'll create a unique path for each file to avoid overwriting files
      final storageRef = FirebaseStorage.instance.ref();
      final filePath = 'employee_uploads/${widget.serviceId}/${DateTime.now().millisecondsSinceEpoch}-$fileName';
      final fileRef = storageRef.child(filePath);

      // 4. Upload the file data
      debugPrint('Uploading to: $filePath');
      final uploadTask = fileRef.putData(fileBytes);
      final snapshot = await uploadTask.whenComplete(() => {});

      // 5. Get the public download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ File uploaded successfully. URL: $downloadUrl');

      // 6. Save the URL to your form map
      setState(() {
        if (type == 'photo') {
          form['photoUrl'] = downloadUrl;
        } else {
          form['idProofUrl'] = downloadUrl;
        }
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == 'photo' ? 'Photo' : 'ID Proof'} uploaded successfully!')),
      );

    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase Storage Error: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: ${e.message}')),
      );
    } catch (e) {
      debugPrint('🔥 An unexpected error occurred: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred.')),
      );
    } finally {
      // 7. ALWAYS turn off the loading indicator
      setState(() {
        if (type == 'photo') {
          isUploadingImage = false;
        } else {
          isUploadingID = false;
        }
      });
    }
  }
  Future<void> _showAppDialog(
      BuildContext context, {
        required String message,
        String title = "",
        IconData icon = Icons.info,
        Color iconColor = Colors.teal,
      }) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 12),
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLoadingDialog(BuildContext context, String message) async {
    showDialog(
      context: context,
      barrierDismissible: false, // ❌ cannot close manually
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (widget.employeeCount + 1 > widget.employeeLimit) {
      await _showAppDialog(
        context,
        message: "Employee limit of ${widget.employeeLimit} reached.",
        title: "Limit Reached",
        icon: Icons.error_outline,
        iconColor: Colors.redAccent,
      );
      return;
    }

    final email = form['email'] as String?;
    if (email == null || email.isEmpty) {
      await _showAppDialog(
        context,
        message: "Please enter the email.",
        title: "Missing Field",
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // 🔍 fetch shopName + areaName from Firestore
      final docSnap = await FirebaseFirestore.instance
          .collection('users-sp-boarding')
          .doc(widget.serviceId)
          .get();

      if (!docSnap.exists) {
        throw Exception("Service not found for id ${widget.serviceId}");
      }

      final shopData = docSnap.data() as Map<String, dynamic>;
      final areaName = shopData['area_name'] ?? '';
      final shopName = shopData['shop_name'] ?? '';

      final payload = {
        'serviceId': widget.serviceId,
        'shopName': shopName,
        'areaName': areaName,
        'name': form['name'] ?? '',
        'phone': form['phone'] ?? '',
        'email': email,
        'address': form['address'] ?? '',
        'jobTitle': form['jobTitle'] ?? '',
        'role': _selectedRole,
        'photoUrl': form['photoUrl'],
        'idProofUrl': form['idProofUrl'],
      };
      print("🔥 FINAL PAYLOAD SENT TO FUNCTION:");
      payload.forEach((k, v) => print("  $k → $v"));
      print("🔥 photoUrl bytes exist? ${previewImage != null}");
      print("🔥 idProofUrl exists? ${form['idProofUrl'] != null}");


      final callable = FirebaseFunctions.instance.httpsCallable('createBoardingEmployee');
      final resp = await callable.call(payload);

      if (resp.data is Map && resp.data['employeeId'] != null) {
        final employeeId = resp.data['employeeId'];

        // show loading until Firestore confirms
        await _showLoadingDialog(context, "📧 Sending invitation...\nPlease wait.");

        final empRef = FirebaseFirestore.instance
            .collection('users-sp-boarding')
            .doc(widget.serviceId)
            .collection('employees')
            .doc(employeeId);

        empRef.snapshots().listen((snap) async {
          if (!snap.exists) return;

          final data = snap.data() as Map<String, dynamic>;
          if (data['active'] == true && data['pending'] == false) {
            // close loading
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            // show success
            await _showAppDialog(
              context,
              message: "✅ ${data['name']} confirmed successfully!",
              title: "Employee Added",
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
            );

            widget.onAdded();
            Navigator.of(context).pop(); // close form
          }
        });
      } else {
        throw FirebaseFunctionsException(
          code: 'UNKNOWN',
          message: 'Failed to create employee',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // close loading if open
      await _showAppDialog(
        context,
        message: "Error: ${e.message}",
        title: "Error",
        icon: Icons.error,
        iconColor: Colors.red,
      );
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // close loading if open
      await _showAppDialog(
        context,
        message: "Unexpected error: $e",
        title: "Error",
        icon: Icons.error,
        iconColor: Colors.red,
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }





  @override
  Widget build(BuildContext context) {
    final isBusy = isUploadingImage || isUploadingID;
    final mq = MediaQuery.of(context);
    final maxW = mq.size.width > 900 ? 650.0 : mq.size.width * 0.95;

    Widget buildButton(String label, VoidCallback onTap, bool busy,
        {Color? color}) {
      return ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          elevation: 2,
        ),
        child: busy
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
          label,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15),
        ),
      );
    }

    InputDecoration fieldDecoration(String label, {String? helper}) {
      return InputDecoration(
        labelText: label,
        helperText: helper,
        labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Add Employee',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Card(
            elevation: 3,
            shadowColor: Colors.black12,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role Heading
                    Text(
                      'Select Role',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Choice Chips
                    Column(
                      children: _roles.map((role) {
                        final isSelected = role == _selectedRole;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.08)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.grey.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ChoiceChip(
                                  label: Text(role, style: GoogleFonts.poppins()),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedRole = role;
                                      form['role'] = role;
                                    });
                                  },
                                  selectedColor: accentColor, // 🔥 always orange when selected
                                  backgroundColor: Colors.white,
                                  labelStyle: GoogleFonts.poppins(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _roleDescriptions[role]!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // Form fields
                    TextField(
                      decoration: fieldDecoration('Full Name'),
                      onChanged: (v) => form['name'] = v,
                    ),
                    const SizedBox(height: 16),

                    // PHONE NUMBER FIELD + VERIFIED STATE
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: fieldDecoration('Phone Number',
                                helper: 'Prefix +91 added automatically'),
                            maxLength: 10,
                            keyboardType: TextInputType.phone,
                            onChanged: (v) {
                              form['phone'] = '+91$v';
                              if (isPhoneVerified) {
                                setState(() => isPhoneVerified = false); // reset if modifying
                              }
                            },
                            enabled: !isPhoneVerified, // disable after verification
                          ),
                        ),

                        const SizedBox(width: 12),

                        // VERIFIED ICON
                        if (isPhoneVerified)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

// SHOW SEND + VERIFY ONLY IF NOT VERIFIED
                    // SHOW SEND + VERIFY ONLY IF NOT VERIFIED
                    if (!isPhoneVerified) ...[
                      // SEND OTP BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSendingOtp ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                          child: isSendingOtp
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text("Send OTP", style: GoogleFonts.poppins(color: Colors.white)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // OTP FIELD
                      TextField(
                        decoration: fieldDecoration("OTP Code"),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => form['otp'] = v,
                      ),

                      const SizedBox(height: 10),

                      // VERIFY BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isVerifyingOtp ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: isVerifyingOtp
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text("Verify OTP", style: GoogleFonts.poppins(color: Colors.white)),
                        ),
                      ),
                    ],

// CHANGE NUMBER BUTTON AFTER VERIFIED
                    if (isPhoneVerified) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isPhoneVerified = false;
                            form['otp'] = '';
                          });
                        },
                        child: Text("Change Number", style: GoogleFonts.poppins(color: primaryColor)),
                      )
                    ],

                    const SizedBox(height: 16),
                    TextField(
                      decoration: fieldDecoration('Email').copyWith(
                        errorText: _emailError,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) {
                        setState(() {
                          form['email'] = v.trim(); // ✅ remove spaces at start/end
                          _emailError = null; // clear error on change
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      decoration: fieldDecoration('Address'),
                      onChanged: (v) => form['address'] = v,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      decoration: fieldDecoration('Job Title'),
                      onChanged: (v) => form['jobTitle'] = v,
                    ),

                    const SizedBox(height: 24),

                    // Upload buttons
                    Row(
                      children: [
                        Expanded(
                          child: buildButton(
                            previewImage != null ? 'Change Photo' : 'Upload Photo',
                                () => _pickAndUploadFile('photo'),
                            isUploadingImage,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: buildButton(
                            form['idProofUrl'] != null
                                ? 'Change ID Proof'
                                : 'Upload ID Proof',
                                () => _pickAndUploadFile('idproof'),
                            isUploadingID,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),

                    if (previewImage != null) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            previewImage!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),

                    // Submit button
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: buildButton(
                          'Submit',
                          _submit,
                          isBusy || isSubmitting,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Action Blocked"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
  Future<void> _verifyOtp() async {
    final otp = form["otp"];
    if (otp == null || otp.isEmpty) {
      _showAppDialog(context, message: "Enter the OTP first.");
      return;
    }

    setState(() => isVerifyingOtp = true);

    final settingsSnap = await FirebaseFirestore.instance
        .collection("settings")
        .doc("employees")
        .get();

    final data = settingsSnap.data() ?? {};
    final bool live = data["number_verification"] == true;

    final verifyFunction = live ? "verifySmsCode" : "verifyTestSmsCode";
    final callable = FirebaseFunctions.instance.httpsCallable(verifyFunction);

    try {
      final result = await callable.call({
        "code": otp,
        "docId": widget.serviceId,
      });

      if (result.data["success"] == true) {
        setState(() => isPhoneVerified = true);
        _showAppDialog(
          context,
          title: "Success",
          message: "Phone number verified!",
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
        );
      }
    } finally {
      setState(() => isVerifyingOtp = false);
    }
  }
}
class _ExpandableInfoRow extends StatefulWidget {
  final IconData icon;
  final String? value;
  final int truncateLength;

  const _ExpandableInfoRow({
    Key? key,
    required this.icon,
    this.value,
    this.truncateLength = 40, // Collapse text longer than 40 characters
  }) : super(key: key);

  @override
  _ExpandableInfoRowState createState() => _ExpandableInfoRowState();
}

class _ExpandableInfoRowState extends State<_ExpandableInfoRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.value != null && widget.value!.isNotEmpty ? widget.value! : '-';
    final canBeTruncated = displayValue.length > widget.truncateLength;

    // The content of the row
    Widget content = Text(
      canBeTruncated && !_isExpanded
          ? '${displayValue.substring(0, widget.truncateLength)}…'
          : displayValue,
      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 13),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0), // Align icon better with multi-line text
                child: Icon(widget.icon, size: 16, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Use AnimatedSize to smoothly expand/collapse the card's height
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topLeft,
                  child: content,
                ),
              ),
            ],
          ),
          if (canBeTruncated)
            Padding(
              padding: const EdgeInsets.only(left: 24.0), // Indent under the text
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(
                  _isExpanded ? 'Show Less' : 'Show More',
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}