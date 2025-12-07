import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // 👈 Import the google_fonts package
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'PendingProductsPage.dart';
import 'ProductSelectionPage.dart';
import 'file_saver.dart';
import 'file_saver_web.dart';

// --- Global Theme & Colors (Change this to your primary color) ---
const Color _primaryColor = Color(0xFF1E88E5); // Professional Deep Blue (Your Primary Color)
const Color _accentColor = Color(0xFFD84315); // Deep Orange for warnings/errors
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

class InventoryPage extends StatefulWidget {
  final String serviceId;

  const InventoryPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isLoading = true;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProductData();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPendingProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingProductsPage( // 👈 Use the PendingProductsPage here
          serviceId: widget.serviceId,
        ),
      ),
    );
  }

  // --- Data Fetching Logic (Omitted for brevity, assumed functional) ---
  Future<void> _fetchProductData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      QuerySnapshot productFilesSnapshot = await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(widget.serviceId)
          .collection('retailer_product_files')
          .where('verified', isEqualTo: true)
          .get();

      if (productFilesSnapshot.docs.isEmpty) {
        throw Exception('No verified products found.');
      }

      _products = [];
      int counter = 1;
      for (var doc in productFilesSnapshot.docs) {
        _products.add(Product(
          index: counter++,
          name: doc['name']?.toString() ?? 'N/A',
          primaryCategory: doc['primaryCategory']?.toString() ?? 'N/A',
          secondaryCategory: doc['secondaryCategory']?.toString() ?? 'N/A',
          tertiaryCategory: doc['tertiaryCategory']?.toString() ?? 'N/A',
          productId: doc.id,
          stock: doc['stock']?.toString() ?? '0',
        ));
      }

      setState(() {
        _filteredProducts = List.from(_products);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
        _isLoading = false;
        _products = [];
        _filteredProducts = [];
      });
    }
  }

  // --- Filtering Logic (Omitted for brevity, assumed functional) ---
  void _filterProducts() {
    String query = _searchController.text.toLowerCase().trim();
    if (!mounted) return;
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.primaryCategory.toLowerCase().contains(query) ||
            product.secondaryCategory.toLowerCase().contains(query) ||
            product.tertiaryCategory.toLowerCase().contains(query) ||
            product.productId.toLowerCase().contains(query) ||
            product.stock.contains(query);
      }).toList();
    });
  }

  // --- Stock Update Logic (Omitted for brevity, assumed functional) ---
  Future<void> _updateStock(String productId, String newStockStr) async {
    final trimmedStock = newStockStr.trim();
    if (int.tryParse(trimmedStock) == null || trimmedStock.isEmpty) {
      _showSnackBar('Stock must be a valid number.', isError: true);
      await _fetchProductData();
      return;
    }

    try {
      final index = _products.indexWhere((p) => p.productId == productId);
      if (index != -1) {
        _products[index] = Product.copyWith(_products[index], stock: trimmedStock);
        _filterProducts();
      }

      DocumentReference productDocRef = FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(widget.serviceId)
          .collection('retailer_product_files')
          .doc(productId);

      await productDocRef.update({'stock': trimmedStock});

      _showSnackBar('Stock updated successfully!');
    } catch (e) {
      await _fetchProductData();
      _showSnackBar('Error updating stock: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: poppinsStyle(color: _cardColor), // Use Poppins for SnackBar text
        ),
        backgroundColor: isError ? _accentColor : _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToAddProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductSelectionPage(
          serviceId: widget.serviceId,
        ),
      ),
    ).then((_) => _fetchProductData());
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddProducts,
        label: Text('Add Products', style: poppinsStyle(color: _cardColor, fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add_shopping_cart, color: _cardColor),
        backgroundColor: _primaryColor,
      ),
    );
  }

  // --- Export Logic ---
  Future<void> _exportToCsv() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch ALL data (unfiltered)
      QuerySnapshot productFilesSnapshot = await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(widget.serviceId)
          .collection('retailer_product_files')
          .where('verified', isEqualTo: true) // Only export verified products
          .get();

      if (productFilesSnapshot.docs.isEmpty) {
        _showSnackBar('No verified products to export.', isError: false);
        setState(() => _isLoading = false);
        return;
      }

      // 2. Prepare Data Structure (Headers and Rows)
      List<List<dynamic>> csvData = [];

      // Headers
      csvData.add([
        'Product ID',
        'Name',
        'Stock',
        'Primary Category',
        'Secondary Category',
        'Tertiary Category',
        'Submitted At',
      ]);

      // Rows
      for (var doc in productFilesSnapshot.docs) {
        // Safely access fields, providing defaults if null
        String submittedAt = (doc['timestamp'] as Timestamp?) != null
            ? (doc['timestamp'] as Timestamp).toDate().toIso8601String()
            : 'N/A';

        csvData.add([
          doc.id,
          doc['name']?.toString() ?? 'N/A',
          doc['stock']?.toString() ?? '0',
          doc['primaryCategory']?.toString() ?? 'N/A',
          doc['secondaryCategory']?.toString() ?? 'N/A',
          doc['tertiaryCategory']?.toString() ?? 'N/A',
          submittedAt,
        ]);
      }

      // 3. Convert to CSV String
      String csv = const ListToCsvConverter().convert(csvData);
      String fileName = 'Inventory_Export_${DateTime.now().millisecondsSinceEpoch}.csv';

      // 4. SAVE THE FILE (Platform-Independent Call)
      await saveFile(csv, fileName); // 👈 This uses file_saver.dart

      // 5. Notify user
      // The message is general because the save location is different on web vs mobile
      _showSnackBar('Data exported successfully! Check your device/browser downloads.', isError: false);

    } catch (e) {
      _showSnackBar('Error during export: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,

      title: Text(
        'Inventory Management',
        style: poppinsStyle(fontWeight: FontWeight.w600, color: _cardColor, fontSize: 18),
      ),
      backgroundColor: _primaryColor,
      elevation: 4,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryColor));
    }

    if (_errorMessage.isNotEmpty && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber, color: _accentColor, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: poppinsStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchProductData,
                icon: const Icon(Icons.refresh, color: _cardColor),
                label: Text('Retry', style: poppinsStyle(color: _cardColor, fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildHeaderActions(),
        _buildSearchBar(),
        Expanded(
          child: _filteredProducts.isEmpty && _searchController.text.isNotEmpty
              ? Center(
            child: Text(
              "No matching products found.",
              style: poppinsStyle(color: Colors.black54),
            ),
          )
              : _filteredProducts.isEmpty
              ? Center(
            child: Text(
              "Your verified inventory is empty. Start by adding products!",
              style: poppinsStyle(color: Colors.black54, fontSize: 16),
            ),
          )
              : _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildHeaderActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            label: 'Pending',
            icon: Icons.access_time_filled,
            color: Colors.orange,
            onPressed: _navigateToPendingProducts,
          ),
          _buildActionButton(
            label: 'Export',
            icon: Icons.file_download,
            color: _primaryColor,
            onPressed: _isLoading ? null : _exportToCsv,
          ),
          // Add a third button for mobile consistency/utility
          _buildActionButton(
            label: 'Refresh',
            icon: Icons.refresh,
            color: Colors.green,
            onPressed: _fetchProductData,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, style: poppinsStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        style: poppinsStyle(),
        decoration: InputDecoration(
          hintText: 'Search by Name, ID, or Category...',
          hintStyle: poppinsStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.search, color: _primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () {
              _searchController.clear();
              _filterProducts();
              FocusScope.of(context).unfocus();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0, top: 8.0),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: _filteredProducts[index],
          onStockUpdate: _updateStock,
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// --- Product Data Model (Updated with copyWith) ---
// ------------------------------------------------------------------

class Product {
  final int index;
  final String name;
  final String primaryCategory;
  final String secondaryCategory;
  final String tertiaryCategory;
  final String productId;
  final String stock; // Kept as String for simpler update logic

  Product({
    required this.index,
    required this.name,
    required this.primaryCategory,
    required this.secondaryCategory,
    required this.tertiaryCategory,
    required this.productId,
    required this.stock,
  });

  // Helper method for immutable updates
  static Product copyWith(Product original, {String? stock}) {
    return Product(
      index: original.index,
      name: original.name,
      primaryCategory: original.primaryCategory,
      secondaryCategory: original.secondaryCategory,
      tertiaryCategory: original.tertiaryCategory,
      productId: original.productId,
      stock: stock ?? original.stock,
    );
  }
}

// ------------------------------------------------------------------
// --- Responsive Mobile Product Card Widget ---
// ------------------------------------------------------------------

class ProductCard extends StatelessWidget {
  final Product product;
  final Function(String productId, String newStockStr) onStockUpdate;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onStockUpdate,
  }) : super(key: key);

  String _formatCategories(Product p) {
    String subCats = '${p.secondaryCategory}';
    if (p.tertiaryCategory != 'N/A' && p.tertiaryCategory.isNotEmpty) {
      subCats += ' / ${p.tertiaryCategory}';
    }
    return subCats;
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _primaryColor.withOpacity(0.8)),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Text(label, style: poppinsStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
        ),
        Expanded(
          flex: 6,
          child: Text(value, style: poppinsStyle(fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Index and Product Name
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Text(
                    product.index.toString(),
                    style: poppinsStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.name,
                    style: poppinsStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1, color: Colors.black12),

            // Row 2: Categories & ID
            _buildInfoRow(
              icon: Icons.label_outline,
              label: 'Primary Category:',
              value: product.primaryCategory,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: 'Sub-Categories:',
              value: _formatCategories(product),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.qr_code,
              label: 'Product ID:',
              value: product.productId,
            ),
            const Divider(height: 24, thickness: 1, color: Colors.black12),

            // Row 3: Editable Stock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Update Stock:',
                  style: poppinsStyle(fontWeight: FontWeight.w600, fontSize: 16, color: _primaryColor),
                ),
                SizedBox(
                  width: 100, // Fixed width for the editable field
                  child: StockEditField(
                    productId: product.productId,
                    initialStock: product.stock,
                    onStockUpdate: onStockUpdate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// --- Dedicated Widget for Editable Stock Field ---
// ------------------------------------------------------------------

class StockEditField extends StatefulWidget {
  final String productId;
  final String initialStock;
  final Function(String productId, String newStockStr) onStockUpdate;

  const StockEditField({
    Key? key,
    required this.productId,
    required this.initialStock,
    required this.onStockUpdate,
  }) : super(key: key);

  @override
  _StockEditFieldState createState() => _StockEditFieldState();
}

class _StockEditFieldState extends State<StockEditField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialStock);
  }

  // Update controller when the initial value changes (e.g., after a refresh)
  @override
  void didUpdateWidget(covariant StockEditField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStock != oldWidget.initialStock) {
      _controller.text = widget.initialStock;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: poppinsStyle(fontWeight: FontWeight.w700, color: _accentColor, fontSize: 16),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black26, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
      onFieldSubmitted: (newValue) {
        // Only trigger update if the value has actually changed
        if (newValue.trim() != widget.initialStock) {
          widget.onStockUpdate(widget.productId, newValue.trim());
          FocusScope.of(context).unfocus(); // Dismiss keyboard
        }
      },
      onTapOutside: (event) {
        // Revert to initial stock if user dismisses keyboard without submitting a change
        if (_controller.text != widget.initialStock) {
          _controller.text = widget.initialStock;
        }
        FocusScope.of(context).unfocus();
      },
    );
  }
}