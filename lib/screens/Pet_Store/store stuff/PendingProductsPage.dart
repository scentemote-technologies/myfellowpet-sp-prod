import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Global Theme & Colors (Copied from InventoryPage) ---
const Color _primaryColor = Color(0xFF1E88E5); // Professional Deep Blue
const Color _accentColor = Color(0xFFD84315); // Deep Orange for warnings/errors
const Color _backgroundColor = Color(0xFFF0F2F5); // Very light background
const Color _cardColor = Colors.white;

// --- Helper for consistent Poppins styling (Copied from InventoryPage) ---
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

class PendingProductsPage extends StatefulWidget {
  final String serviceId;

  const PendingProductsPage({Key? key, required this.serviceId}) : super(key: key);

  @override
  _PendingProductsPageState createState() => _PendingProductsPageState();
}

class _PendingProductsPageState extends State<PendingProductsPage> {
  bool _isLoading = true;
  List<PendingProduct> _products = [];
  List<PendingProduct> _filteredProducts = [];
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPendingProductData();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

// --- Data Fetching Logic: Query where 'verified' is false ---
  Future<void> _fetchPendingProductData() async {
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

      // 👈 KEY CHANGE: Filter for verified == false
      QuerySnapshot productFilesSnapshot = await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(widget.serviceId)
          .collection('retailer_product_files')
          .where('verified', isEqualTo: false)
          .get();

      if (productFilesSnapshot.docs.isEmpty) {
        throw Exception('No products are currently pending verification.');
      }

      _products = [];
      int counter = 1;
      for (var doc in productFilesSnapshot.docs) {
        _products.add(PendingProduct(
          index: counter++,
          name: doc['name']?.toString() ?? 'N/A',
          primaryCategory: doc['primaryCategory']?.toString() ?? 'N/A',
          secondaryCategory: doc['secondaryCategory']?.toString() ?? 'N/A',
          tertiaryCategory: doc['tertiaryCategory']?.toString() ?? 'N/A',
          productId: doc.id,
          stock: doc['stock']?.toString() ?? '0',
          // Assuming 'timestamp' is used to show when it was submitted
          submittedAt: (doc['timestamp'] as Timestamp?)?.toDate(),
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

// --- Filtering Logic (Same as InventoryPage) ---
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

// --- Delete Logic ---
  Future<void> _deletePendingProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(widget.serviceId)
          .collection('retailer_product_files')
          .doc(productId)
          .delete();

      _showSnackBar('Product deleted successfully!', isError: false);
      await _fetchPendingProductData(); // Refresh the list
    } catch (e) {
      _showSnackBar('Error deleting product: ${e.toString()}', isError: true);
    }
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

// --- Build Methods (Adapted for Pending Page) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'Pending Products',
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

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_filled, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: poppinsStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchPendingProductData,
                icon: const Icon(Icons.refresh, color: _cardColor),
                label: Text('Refresh', style: poppinsStyle(color: _cardColor, fontWeight: FontWeight.w500)),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _filteredProducts.isEmpty && _searchController.text.isNotEmpty
              ? Center(
            child: Text(
              "No matching pending products found.",
              style: poppinsStyle(color: Colors.black54),
            ),
          )
              : _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        style: poppinsStyle(),
        decoration: InputDecoration(
          hintText: 'Search pending products...',
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
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        return PendingProductCard(
          product: _filteredProducts[index],
          onDelete: _deletePendingProduct,
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// --- Pending Product Data Model ---
// ------------------------------------------------------------------

class PendingProduct {
  final int index;
  final String name;
  final String primaryCategory;
  final String secondaryCategory;
  final String tertiaryCategory;
  final String productId;
  final String stock;
  final DateTime? submittedAt; // To show submission time

  PendingProduct({
    required this.index,
    required this.name,
    required this.primaryCategory,
    required this.secondaryCategory,
    required this.tertiaryCategory,
    required this.productId,
    required this.stock,
    this.submittedAt,
  });
}

// ------------------------------------------------------------------
// --- Responsive Mobile Pending Product Card Widget ---
// ------------------------------------------------------------------

class PendingProductCard extends StatelessWidget {
  final PendingProduct product;
  final Function(String productId) onDelete;

  const PendingProductCard({
    Key? key,
    required this.product,
    required this.onDelete,
  }) : super(key: key);

  String _formatCategories(PendingProduct p) {
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
        side: const BorderSide(color: Colors.orange, width: 2), // Highlight pending status
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Status Badge and Product Name
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: const Icon(Icons.access_time, size: 18, color: Colors.white),
                  label: Text('Pending Approval', style: poppinsStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                Text(
                  '#${product.index}',
                  style: poppinsStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              style: poppinsStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              icon: Icons.inventory_2_outlined,
              label: 'Initial Stock:',
              value: product.stock,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.qr_code_2,
              label: 'Product ID:',
              value: product.productId,
            ),
            const Divider(height: 24, thickness: 1, color: Colors.black12),

            // Row 3: Submission Time and Delete Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.submittedAt != null
                        ? 'Submitted: ${MaterialLocalizations.of(context).formatMediumDate(product.submittedAt!)}'
                        : 'Submitted: N/A',
                    style: poppinsStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.black54),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => onDelete(product.productId),
                    icon: const Icon(Icons.delete_forever, size: 18, color: _cardColor),
                    label: Text('Delete', style: poppinsStyle(color: _cardColor, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
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