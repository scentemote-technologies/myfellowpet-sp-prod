import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // 👈 Using Google Fonts

// --- Global Theme & Colors (Consistent with InventoryPage) ---
const Color _primaryColor = Color(0xFF1E88E5); // Professional Deep Blue
const Color _accentColor = Color(0xFFD84315); // Deep Orange
const Color _backgroundColor = Color(0xFFF0F2F5); // Very light background
const Color _cardColor = Colors.white;

// --- Helper for consistent Poppins styling ---
TextStyle poppinsStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black87,
}) {
  return GoogleFonts.poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

class ProductSelectionPage extends StatefulWidget {
  final String serviceId;

  const ProductSelectionPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _ProductSelectionPageState createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialLoading = true;
  List<String> _primaryCategories = [];
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _fetchPrimaryCategories();
  }

// --- Data Fetching Logic (Retained from Original) ---
  Future<void> _fetchPrimaryCategories() async {
    try {
      final querySnapshot = await _firestore.collection('primary category').get();
      setState(() {
        _primaryCategories = querySnapshot.docs.map((doc) => doc.id).toList();
        _isInitialLoading = false;
        // Add one initial row if categories are found
        if (_primaryCategories.isNotEmpty && _rows.isEmpty) {
          _addRow();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        _showSnackBar('Error fetching categories: $e', isError: true);
      }
    }
  }

  Future<void> _fetchSecondaryCategories(int rowIndex, String primaryCategory) async {
    final querySnapshot = await _firestore
        .collection('primary category')
        .doc(primaryCategory)
        .collection('secondary category')
        .get();

    if (!mounted) return;
    setState(() {
      _rows[rowIndex]['secondaryCategories'] = querySnapshot.docs.map((doc) => doc.id).toList();
      _rows[rowIndex]['secondaryCategory'] = null;
      _rows[rowIndex]['tertiaryCategories'] = [];
      _rows[rowIndex]['tertiaryCategory'] = null;
      _rows[rowIndex]['quaternaryCategories'] = [];
      _rows[rowIndex]['quaternaryCategory'] = null;
    });
  }

  Future<void> _fetchTertiaryCategories(int rowIndex, String primaryCategory, String secondaryCategory) async {
    final querySnapshot = await _firestore
        .collection('primary category')
        .doc(primaryCategory)
        .collection('secondary category')
        .doc(secondaryCategory)
        .collection('tertiary category')
        .get();

    if (!mounted) return;
    setState(() {
      _rows[rowIndex]['tertiaryCategories'] = querySnapshot.docs.map((doc) => doc.id).toList();
      _rows[rowIndex]['tertiaryCategory'] = null;
      _rows[rowIndex]['quaternaryCategories'] = [];
      _rows[rowIndex]['quaternaryCategory'] = null;
    });
  }

  Future<void> _fetchQuaternaryCategories(int rowIndex, String primaryCategory, String secondaryCategory, String tertiaryCategory) async {
    final querySnapshot = await _firestore
        .collection('primary category')
        .doc(primaryCategory)
        .collection('secondary category')
        .doc(secondaryCategory)
        .collection('tertiary category')
        .doc(tertiaryCategory)
        .collection('quaternary category')
        .get();

    if (!mounted) return;
    setState(() {
      _rows[rowIndex]['quaternaryCategories'] = querySnapshot.docs
          .map((doc) => {'name': doc['name']?.toString() ?? 'N/A', 'id': doc.id})
          .toList();
      _rows[rowIndex]['quaternaryCategory'] = null;
    });
  }

// --- Row Management and Submission ---
  void _addRow() {
    setState(() {
      _rows.add({
        'index': _rows.length + 1,
        'primaryCategory': null,
        'secondaryCategories': [],
        'secondaryCategory': null,
        'tertiaryCategories': [],
        'tertiaryCategory': null,
        'quaternaryCategories': [],
        'quaternaryCategory': null,
        'stock': null,
      });
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
      // Re-index the remaining rows
      for (int i = index; i < _rows.length; i++) {
        _rows[i]['index'] = i + 1;
      }
    });
  }

  Future<void> _submitRows() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    final retailerDocRef = _firestore.collection('users-sp-store').doc(widget.serviceId);
    final retailerProductFilesCollection = retailerDocRef.collection('retailer_product_files');

    for (var row in _rows) {
      if (row['primaryCategory'] == null ||
          row['secondaryCategory'] == null ||
          row['tertiaryCategory'] == null ||
          row['quaternaryCategory'] == null ||
          row['stock'] == null ||
          int.tryParse(row['stock'].toString()) == null) {
        _showSnackBar('Please fill all category fields and enter a valid stock number for all items.', isError: true);
        return;
      }

      final selectedProduct = row['quaternaryCategories']
          .firstWhere((product) => product['name'] == row['quaternaryCategory']);

      final productId = selectedProduct['id'];

      // Check if product already exists in the retailer's pending or verified list
      final existingDoc = await retailerProductFilesCollection.doc(productId).get();
      if (existingDoc.exists) {
        _showSnackBar('Product "${row['quaternaryCategory']}" is already in your inventory (ID: $productId).', isError: true);
        return;
      }

      await retailerProductFilesCollection.doc(productId).set({
        'primaryCategory': row['primaryCategory'],
        'secondaryCategory': row['secondaryCategory'],
        'tertiaryCategory': row['tertiaryCategory'],
        'name': row['quaternaryCategory'],
        // 'productId': productId, // Doc ID is used as the product ID
        'stock': row['stock'].toString(), // Ensure stock is saved as string (consistent with InventoryPage)
        'retailer_id': currentUser.uid,
        'verified': false, // Newly added products are pending verification
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Clear rows and show success message
    setState(() {
      _rows.clear();
      _addRow(); // Add one empty row back
    });
    _showSnackBar('Products submitted successfully! They are now awaiting verification.', isError: false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: poppinsStyle(color: _cardColor),
        ),
        backgroundColor: isError ? _accentColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

// --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Add Inventory Products',
          style: poppinsStyle(fontWeight: FontWeight.w600, color: _cardColor, fontSize: 18),
        ),
        backgroundColor: _primaryColor,
        elevation: 4,
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              'Select the exact products you want to stock',
              style: poppinsStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                return ProductRowCard(
                  key: ValueKey(_rows[index]['index']),
                  row: _rows[index],
                  primaryCategories: _primaryCategories,
                  onCategoryChanged: (level, value) => _handleCategoryChange(index, level, value),
                  onStockChanged: (value) {
                    setState(() {
                      _rows[index]['stock'] = value;
                    });
                  },
                  onRemove: () => _removeRow(index),
                );
              },
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  void _handleCategoryChange(int rowIndex, int level, String? value) {
    setState(() {
      if (level == 1) {
        _rows[rowIndex]['primaryCategory'] = value;
        if (value != null) {
          _fetchSecondaryCategories(rowIndex, value);
        }
      } else if (level == 2) {
        _rows[rowIndex]['secondaryCategory'] = value;
        if (value != null && _rows[rowIndex]['primaryCategory'] != null) {
          _fetchTertiaryCategories(rowIndex, _rows[rowIndex]['primaryCategory'], value);
        }
      } else if (level == 3) {
        _rows[rowIndex]['tertiaryCategory'] = value;
        if (value != null && _rows[rowIndex]['primaryCategory'] != null && _rows[rowIndex]['secondaryCategory'] != null) {
          _fetchQuaternaryCategories(rowIndex, _rows[rowIndex]['primaryCategory'], _rows[rowIndex]['secondaryCategory'], value);
        }
      } else if (level == 4) {
        _rows[rowIndex]['quaternaryCategory'] = value;
      }
    });
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_circle_outline, color: _primaryColor),
              label: Text('Add Item', style: poppinsStyle(fontWeight: FontWeight.w600, color: _primaryColor)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColor,
                side: const BorderSide(color: _primaryColor, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _submitRows,
              icon: const Icon(Icons.send, color: _cardColor),
              label: Text('Submit', style: poppinsStyle(fontWeight: FontWeight.w600, color: _cardColor)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- Custom Widget for a Single Product Selection Row (Mobile Focused) ---
// ------------------------------------------------------------------

class ProductRowCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final List<String> primaryCategories;
  final Function(int level, String? value) onCategoryChanged;
  final Function(String value) onStockChanged;
  final VoidCallback onRemove;

  const ProductRowCard({
    Key? key,
    required this.row,
    required this.primaryCategories,
    required this.onCategoryChanged,
    required this.onStockChanged,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Index and Remove Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item #${row['index']}',
                  style: poppinsStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primaryColor),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _accentColor),
                  onPressed: onRemove,
                ),
              ],
            ),
            const Divider(height: 16),

            // Category Dropdowns (Vertical Stack)
            _buildCategoryDropdown(
              context,
              label: '1. Primary Category',
              value: row['primaryCategory'],
              items: primaryCategories,
              onChanged: (v) => onCategoryChanged(1, v),
            ),
            _buildCategoryDropdown(
              context,
              label: '2. Secondary Category',
              value: row['secondaryCategory'],
              items: List<String>.from(row['secondaryCategories']),
              onChanged: (v) => onCategoryChanged(2, v),
              enabled: row['primaryCategory'] != null,
            ),
            _buildCategoryDropdown(
              context,
              label: '3. Tertiary Category',
              value: row['tertiaryCategory'],
              items: List<String>.from(row['tertiaryCategories']),
              onChanged: (v) => onCategoryChanged(3, v),
              enabled: row['secondaryCategory'] != null,
            ),
            _buildCategoryDropdown(
              context,
              label: '4. Product Name',
              value: row['quaternaryCategory'],
              items: List<Map<String, dynamic>>.from(row['quaternaryCategories'])
                  .map((e) => e['name'].toString())
                  .toList(),
              onChanged: (v) => onCategoryChanged(4, v),
              enabled: row['tertiaryCategory'] != null,
            ),

            const SizedBox(height: 16),
            const Divider(height: 8),

            // Stock Input Field
            Text(
              '5. Initial Stock Quantity',
              style: poppinsStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextFormField(
              keyboardType: TextInputType.number,
              initialValue: row['stock']?.toString() ?? '',
              style: poppinsStyle(),
              decoration: InputDecoration(
                hintText: 'e.g., 50',
                hintStyle: poppinsStyle(color: Colors.black45),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                prefixIcon: const Icon(Icons.production_quantity_limits, color: Colors.grey),
              ),
              onChanged: onStockChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(
      BuildContext context, {
        required String label,
        required String? value,
        required List<String> items,
        required ValueChanged<String?> onChanged,
        bool enabled = true,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: poppinsStyle(fontWeight: FontWeight.w600, color: enabled ? Colors.black87 : Colors.black45),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: 'Select $label',
              hintStyle: poppinsStyle(color: Colors.black45),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: enabled ? _primaryColor.withOpacity(0.5) : Colors.grey.shade300, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              fillColor: enabled ? _cardColor : Colors.grey.shade100,
              filled: true,
            ),
            style: poppinsStyle(fontWeight: FontWeight.w500),
            isExpanded: true,
            dropdownColor: _cardColor,
            items: items.isEmpty && !enabled
                ? [
              DropdownMenuItem(
                value: null,
                child: Text('Select previous category first', style: poppinsStyle(color: Colors.grey)),
              )
            ]
                : items.map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: poppinsStyle()),
              );
            }).toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}