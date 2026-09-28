import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';

import '../models/product_model.dart';
import '../services/inventory_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final InventoryService _inventoryService = InventoryService();

  final Map<String, IconData> _categories = const {
    'Automotive': Icons.directions_car,
    'Electronics': Icons.memory,
    'Hardware': Icons.handyman,
    'Packaged Goods': Icons.inventory_2,
    'Cleaning Supplies': Icons.cleaning_services,
    'Office Supplies': Icons.business_center,
    'Other': Icons.category,
  };

  Future<void> _showEditDialog(
    BuildContext context,
    InventoryProduct product,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: product.name);
    final unitWeightController = TextEditingController(
      text: product.unitWeightKg == null
          ? ''
          : (product.unitWeightKg! * 1000).toStringAsFixed(1),
    );
    final thresholdController = TextEditingController(
      text: product.minimumStockThreshold?.toString() ?? '',
    );
    var selectedCategory = _categories.containsKey(product.category)
        ? product.category
        : 'Other';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.productSettings),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.productName,
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: l10n.category,
                        border: const OutlineInputBorder(),
                      ),
                      items: _categories.keys.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(_categories[category], color: Colors.teal),
                              const SizedBox(width: 10),
                              Flexible(child: Text(category)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: unitWeightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.unitWeight,
                        suffixText: 'g',
                        helperText: l10n.unitWeightHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.minimumStockThreshold,
                        helperText: l10n.optionalField,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final unitWeightGrams = _parsePositiveDouble(
                      unitWeightController.text,
                    );
                    final threshold = _parseNonNegativeInt(
                      thresholdController.text,
                    );

                    if (name.isEmpty ||
                        (unitWeightController.text.trim().isNotEmpty &&
                            unitWeightGrams == null) ||
                        (thresholdController.text.trim().isNotEmpty &&
                            threshold == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.invalidProductSettings)),
                      );
                      return;
                    }

                    await _inventoryService.updateProduct(
                      productId: product.id,
                      name: name,
                      category: selectedCategory,
                      unitWeightKg: unitWeightGrams == null
                          ? null
                          : unitWeightGrams / 1000,
                      minimumStockThreshold: threshold,
                    );

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    unitWeightController.dispose();
    thresholdController.dispose();
  }

  double? _parsePositiveDouble(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _parseNonNegativeInt(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryMonitoring)),
      body: StreamBuilder<List<InventoryProduct>>(
        stream: _inventoryService.getProductsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${l10n.error}: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noProductsFound));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final product = snapshot.data![index];
              return _ProductCard(
                product: product,
                icon: _categories[product.category] ?? Icons.category,
                onEdit: () => _showEditDialog(context, product),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final InventoryProduct product;
  final IconData icon;
  final VoidCallback onEdit;

  const _ProductCard({
    required this.product,
    required this.icon,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final quantity = product.estimatedQuantity;
    final lowStock = product.isLowStock;
    final statusColor = lowStock == null
        ? Colors.blueGrey
        : lowStock
            ? Colors.red
            : Colors.green;
    final statusLabel = lowStock == null
        ? l10n.thresholdNotConfigured
        : lowStock
            ? l10n.lowStock
            : l10n.stockOk;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.teal.shade50,
              radius: 25,
              child: Icon(icon, color: Colors.teal, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.category} • ${product.id}',
                    style: TextStyle(color: Colors.teal.shade700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _Metric(
                        label: l10n.currentWeight,
                        value:
                            '${product.currentWeightKg.toStringAsFixed(2)} kg',
                      ),
                      _Metric(
                        label: l10n.estimatedQuantity,
                        value: quantity?.toString() ?? l10n.notConfigured,
                      ),
                      _Metric(
                        label: l10n.stockStatus,
                        value: statusLabel,
                        color: statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.productSettings,
              icon: const Icon(Icons.edit, color: Colors.blueGrey),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Metric({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
