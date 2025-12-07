import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class UnverifiedProductsPage extends StatefulWidget {
  @override
  _UnverifiedProductsPageState createState() => _UnverifiedProductsPageState();
}

class _UnverifiedProductsPageState extends State<UnverifiedProductsPage> {
  bool _isLoading = true;
  List<Product> _unverifiedProducts = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUnverifiedProductData();
  }

  Future<void> _fetchUnverifiedProductData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User not found in the database';
          _isLoading = false;
        });
        return;
      }

      QuerySnapshot productFilesSnapshot = await FirebaseFirestore.instance
          .collection('users-sp-store')
          .doc(user.uid)
          .collection('retailer_product_files')
          .where('verified', isEqualTo: false) // Fetch only unverified products
          .get();

      if (productFilesSnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No unverified products found';
          _isLoading = false;
        });
        return;
      }

      // Map Firestore data to Product list
      _unverifiedProducts = productFilesSnapshot.docs.map((doc) {
        return Product(
          name: doc['name'],
          primaryCategory: doc['primaryCategory'],
          productId: doc['productId'],
          secondaryCategory: doc['secondaryCategory'],
          stock: _parseStock(doc['stock']),
          tertiaryCategory: doc['tertiaryCategory'],
        );
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _isLoading = false;
      });
    }
  }

  // Convert stock to an integer, assuming it's a string representation of a number
  int _parseStock(String stock) {
    try {
      return int.parse(stock); // Try to convert stock to an integer
    } catch (e) {
      return 0; // If conversion fails, return 0
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unverified Products'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(child: Text(_errorMessage))
            : Column(
          children: [
            Text(
              'Unverified Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: SfDataGrid(
                source: ProductDataSource(_unverifiedProducts),
                columnWidthMode: ColumnWidthMode.auto,
                columns: [
                  GridColumn(columnName: 'name', label: Text('Name')),
                  GridColumn(columnName: 'primaryCategory', label: Text('Primary Category')),
                  GridColumn(columnName: 'productId', label: Text('Product ID')),
                  GridColumn(columnName: 'secondaryCategory', label: Text('Secondary Category')),
                  GridColumn(columnName: 'stock', label: Text('Stock')),
                  GridColumn(columnName: 'tertiaryCategory', label: Text('Tertiary Category')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Product {
  final String name;
  final String primaryCategory;
  final String productId;
  final String secondaryCategory;
  final int stock;
  final String tertiaryCategory;

  Product({
    required this.name,
    required this.primaryCategory,
    required this.productId,
    required this.secondaryCategory,
    required this.stock,
    required this.tertiaryCategory,
  });
}

class ProductDataSource extends DataGridSource {
  final List<Product> products;

  ProductDataSource(this.products);

  @override
  List<DataGridRow> get rows {
    return products.map((product) {
      return DataGridRow(cells: [
        DataGridCell<String>(columnName: 'name', value: product.name),
        DataGridCell<String>(columnName: 'primaryCategory', value: product.primaryCategory),
        DataGridCell<String>(columnName: 'productId', value: product.productId),
        DataGridCell<String>(columnName: 'secondaryCategory', value: product.secondaryCategory),
        DataGridCell<int>(columnName: 'stock', value: product.stock),
        DataGridCell<String>(columnName: 'tertiaryCategory', value: product.tertiaryCategory),
      ]);
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(cells: [
      Text(row.getCells()[0].value.toString()),
      Text(row.getCells()[1].value.toString()),
      Text(row.getCells()[2].value.toString()),
      Text(row.getCells()[3].value.toString()),
      Text(row.getCells()[4].value.toString()),
      Text(row.getCells()[5].value.toString()),
    ]);
  }
}
