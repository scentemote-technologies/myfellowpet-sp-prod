// historypage.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../Colors/AppColor.dart';


class EditHistoryPage extends StatefulWidget {
  final String serviceId;
  const EditHistoryPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _EditHistoryPageState createState() => _EditHistoryPageState();
}

class _EditHistoryPageState extends State<EditHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = All, 'Pending', 'Handled'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        title: Text(
          'Edit Request History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterPanel(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users-sp-boarding')
                  .doc(widget.serviceId)
                  .collection('profile_edit_requests')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No History Found', 'Submitted edit requests will appear here.');
                }

                final filteredRequests = _filterRequests(snapshot.data!.docs);

                if (filteredRequests.isEmpty) {
                  return _buildEmptyState('No Matching Requests', 'Try adjusting your search or filter.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    return _HistoryCard(
                      request: filteredRequests[index],
                      index: index + 1,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterRequests(List<QueryDocumentSnapshot> allDocs) {
    return allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final isHandled = data['handled'] == true;
      final changes = data['changes'] as List<dynamic>? ?? [];
      final approvedCount = (data['approvedFields'] as List<dynamic>? ?? []).length;
      final rejectedCount = (data['rejectedFields'] as Map<String, dynamic>? ?? {}).length;

      // Filter by status
      bool statusMatch = true;
      if (_statusFilter == 'Pending' && isHandled) statusMatch = false;
      if (_statusFilter == 'Handled' && !isHandled) statusMatch = false;
      if (_statusFilter == 'Approved' && (!isHandled || approvedCount == 0)) statusMatch = false;
      if (_statusFilter == 'Rejected' && (!isHandled || rejectedCount == 0)) statusMatch = false;

      // Filter by search query
      bool searchMatch = true;
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final idMatch = doc.id.toLowerCase().contains(searchLower);
        final changesMatch = changes.any((c) => (c['label'] as String? ?? '').toLowerCase().contains(searchLower));
        searchMatch = idMatch || changesMatch;
      }

      return statusMatch && searchMatch;
    }).toList();
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              hintText: 'Search by ID or field name...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(label: 'All', value: null, groupValue: _statusFilter, onPressed: (v) => setState(() => _statusFilter = v)),
                _FilterChip(label: 'Pending', value: 'Pending', groupValue: _statusFilter, onPressed: (v) => setState(() => _statusFilter = v)),
                _FilterChip(label: 'Handled', value: 'Handled', groupValue: _statusFilter, onPressed: (v) => setState(() => _statusFilter = v)),
                _FilterChip(label: 'Approved', value: 'Approved', groupValue: _statusFilter, onPressed: (v) => setState(() => _statusFilter = v)),
                _FilterChip(label: 'Rejected', value: 'Rejected', groupValue: _statusFilter, onPressed: (v) => setState(() => _statusFilter = v)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? groupValue;
  final ValueChanged<String?> onPressed;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return ActionChip(
      label: Text(label),
      onPressed: () => onPressed(value),
      backgroundColor: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? primaryColor : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: isSelected ? primaryColor : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QueryDocumentSnapshot request;
  final int index;

  const _HistoryCard({required this.request, required this.index});

  @override
  Widget build(BuildContext context) {
    final data = request.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final isHandled = data['handled'] == true;
    final approvedCount = (data['approvedFields'] as List<dynamic>? ?? []).length;
    final rejectedCount = (data['rejectedFields'] as Map<String, dynamic>? ?? {}).length;

    // Determine the primary status for the chip
    final String statusText = isHandled ? (rejectedCount > 0 ? 'Rejected' : 'Approved') : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailsModal(context, request),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Request #$index',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    _StatusChip(status: statusText),
                  ],
                ),
                Text(
                  'Requested: ${timestamp != null ? DateFormat.yMMMd().add_jm().format(timestamp) : 'N/A'}',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Divider(height: 32),
                _buildInfoRow('Approved', '$approvedCount Fields', color: Colors.green.shade800),
                const SizedBox(height: 8),
                _buildInfoRow('Rejected', '$rejectedCount Fields', color: Colors.red.shade800),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('View Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: primaryColor, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      children: [
        Text(
          '$label:',
          style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Approved':
        color = Colors.green.shade700;
        icon = Icons.check_circle_rounded;
        break;
      case 'Rejected':
        color = Colors.red.shade700;
        icon = Icons.cancel_rounded;
        break;
      default: // Pending
        color = accentColor;
        icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --- MODAL DETAILS VIEW ---

void _showDetailsModal(BuildContext context, QueryDocumentSnapshot request) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DetailsView(request: request),
  );
}

class _DetailsView extends StatelessWidget {
  final QueryDocumentSnapshot request;
  const _DetailsView({required this.request});

  String _formatPolicyKey(String key) {
    try {
      final parts = key.split('_');
      if (parts.length != 2) return key;
      String condition;
      switch (parts[0]) {
        case 'gt':
          condition = 'Greater than';
          break;
        case 'lt':
          condition = 'Lesser than';
          break;
        default:
          return key;
      }
      final hours = parts[1].replaceAll('h', '');
      return '$condition $hours hours';
    } catch (e) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Data extraction from the document
    final data = request.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final handledAt = (data['handledAt'] as Timestamp?)?.toDate();
    final changes = data['changes'] as List<dynamic>? ?? [];
    final approvedFields = (data['approvedFields'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final rejectedFieldsData = data['rejectedFields'] as Map<String, dynamic>? ?? {};
    final rejectedFields = rejectedFieldsData.entries.map((e) => '${e.key}: ${e.value}').toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Request Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildModalInfoRow('Requested', timestamp != null ? DateFormat.yMMMd().add_jm().format(timestamp) : 'N/A'),
                    _buildModalInfoRow('Handled', handledAt != null ? DateFormat.yMMMd().add_jm().format(handledAt) : 'Pending'),
                    _buildIdRow(request.id, context),
                    const SizedBox(height: 24),

                    //... inside _DetailsView build method
                    _buildSection(
                      title: 'Requested Changes',
                      icon: Icons.edit_note_rounded,
                      iconColor: Colors.blue.shade700,
                      content: _buildChangesList(changes, _formatPolicyKey), // <-- Pass the function here
                    ),

                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Approved Fields',
                      icon: Icons.check_circle_rounded,
                      iconColor: Colors.green.shade700,
                      content: approvedFields.isEmpty
                          ? Text('None', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.grey.shade600))
                          : _buildBulletedList(approvedFields),
                    ),
                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'Rejected Fields & Reasons',
                      icon: Icons.cancel_rounded,
                      iconColor: Colors.red.shade700,
                      content: rejectedFields.isEmpty
                          ? Text('None', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.grey.shade600))
                          : _buildBulletedList(rejectedFields),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- MODAL HELPER WIDGETS ---

String _formatValue(dynamic value) {
  if (value == null) return 'N/A';
  if (value is Map) return value.entries.map((e) => '${e.key}: ${e.value}').join('; ');
  if (value is List) return value.join(', ');
  return value.toString();
}

Widget _buildChangesList(List<dynamic> changes, String Function(String) formatPolicyKey) {
  if (changes.isEmpty) {
    return Text("None", style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: Colors.grey.shade600));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: changes.map<Widget>((change) {
      final item = change as Map<String, dynamic>;
      final label = item['label'] ?? 'Unknown Field';
      String oldValue;
      String newValue;

      // Special formatting for Refund Policy
      if (label == 'Refund Policy' && (item.containsKey('oldValueMap') || item.containsKey('newValueMap'))) {
        final oldMap = item['oldValueMap'] as Map<String, dynamic>? ?? {};
        final newMap = item['newValueMap'] as Map<String, dynamic>? ?? {};

        oldValue = oldMap.entries.map((e) => '${formatPolicyKey(e.key)}: ${e.value}%').join('; ');
        newValue = newMap.entries.map((e) => '${formatPolicyKey(e.key)}: ${e.value}%').join('; ');

        if (oldValue.isEmpty) oldValue = 'N/A';
        if (newValue.isEmpty) newValue = 'N/A';

      } else {
        // Standard formatting for everything else
        oldValue = _formatValue(item['oldValue'] ?? item['oldValueList'] ?? item['oldValueMap']);
        newValue = _formatValue(item['newValue'] ?? item['newValueList'] ?? item['newValueMap']);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('From: $oldValue', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            Text('To: $newValue', style: GoogleFonts.poppins(color: Colors.black87)),
            const Divider(height: 16),
          ],
        ),
      );
    }).toList(),
  );
}

Widget _buildModalInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget _buildIdRow(String requestId, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Request ID", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        Row(
          children: [
            Expanded(child: SelectableText(requestId, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600))),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              color: Colors.grey.shade600,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: requestId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request ID copied to clipboard'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSection({required String title, required IconData icon, required Color iconColor, required Widget content}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.only(left: 12.0),
        child: content,
      ),
    ],
  );
}

Widget _buildBulletedList(List<String> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(child: Text(item, style: GoogleFonts.poppins())),
        ],
      ),
    )).toList(),
  );
}