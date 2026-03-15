import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:industrynight_shared/shared.dart';
import '../../../providers/admin_state.dart';

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  ProductType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() { _isLoading = true; _error = null; });

    final adminApi = context.read<AdminState>().adminApi;
    try {
      final products = await adminApi.getProducts(type: _filterType);
      if (!mounted) return;
      setState(() { _products = products; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Failed to load products';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This will fail if any customers have purchased this product.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminApi = context.read<AdminState>().adminApi;
    try {
      await adminApi.deleteProduct(product.id);
      if (!mounted) return;
      _loadProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Cannot delete: product may be in use'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/products/add');
              _loadProducts();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                SegmentedButton<ProductType?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(value: ProductType.sponsorship, label: Text('Sponsorship')),
                    ButtonSegment(value: ProductType.vendorSpace, label: Text('Vendor Space')),
                    ButtonSegment(value: ProductType.dataProduct, label: Text('Data Product')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (values) {
                    setState(() => _filterType = values.first);
                    _loadProducts();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: Card(child: _buildContent())),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) return const Center(child: Text('No products yet'));

    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Base Price')),
          DataColumn(label: Text('Standard')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _products.map((product) {
          final typeLabel = switch (product.productType) {
            ProductType.sponsorship => 'Sponsorship',
            ProductType.vendorSpace => 'Vendor Space',
            ProductType.dataProduct => 'Data Product',
          };
          final typeColor = switch (product.productType) {
            ProductType.sponsorship => Colors.purple.shade100,
            ProductType.vendorSpace => Colors.blue.shade100,
            ProductType.dataProduct => Colors.green.shade100,
          };

          return DataRow(cells: [
            DataCell(Text(product.name)),
            DataCell(Chip(
              label: Text(typeLabel, style: const TextStyle(fontSize: 12)),
              backgroundColor: typeColor,
              visualDensity: VisualDensity.compact,
            )),
            DataCell(Text(product.displayPrice)),
            DataCell(Icon(
              product.isStandard ? Icons.check_circle : Icons.handyman,
              color: product.isStandard ? Colors.green : Colors.orange,
              size: 20,
            )),
            DataCell(Chip(
              label: Text(product.isActive ? 'Active' : 'Inactive'),
              backgroundColor: product.isActive
                  ? Colors.green.shade100 : Colors.grey.shade200,
              visualDensity: VisualDensity.compact,
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit',
                  onPressed: () async {
                    await context.push('/products/${product.id}/edit', extra: product);
                    _loadProducts();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _deleteProduct(product),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
