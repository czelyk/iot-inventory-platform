import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';

import '../models/product_model.dart';
import '../services/inventory_service.dart';
import '../services/shopping_list_service.dart';
import '../utils/inventory_categories.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final InventoryService _inventoryService = InventoryService();
  final ShoppingListService _shoppingListService = ShoppingListService();
  final Set<String> _addingToRestock = {};

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
    var selectedCategory = InventoryCategories.values.contains(product.category)
        ? product.category
        : 'Other';
    var isSaving = false;

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
                      items: InventoryCategories.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                InventoryCategories.iconFor(category),
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  InventoryCategories.labelFor(category, l10n),
                                ),
                              ),
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
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

                    setDialogState(() => isSaving = true);
                    try {
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
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(l10n.updateFailed)),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
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

  Future<void> _addToRestockingList(InventoryProduct product) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _addingToRestock.add(product.id));
    try {
      await _shoppingListService.addInventoryProduct(
        productId: product.id,
        name: product.name,
        category: product.category,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addedToRestockingList)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.updateFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _addingToRestock.remove(product.id));
      }
    }
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

          final products = snapshot.data!;
          final now = DateTime.now();
          final lowStockCount = products
              .where(
                (product) =>
                    product.isLowStock == true &&
                    !product.isMeasurementStaleAt(now),
              )
              .length;
          final staleCount = products
              .where((product) => product.isMeasurementStaleAt(now))
              .length;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: products.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _InventorySummary(
                  platformCount: products.length,
                  lowStockCount: lowStockCount,
                  staleCount: staleCount,
                );
              }
              final product = products[index - 1];
              return _ProductCard(
                product: product,
                icon: InventoryCategories.iconFor(product.category),
                onEdit: () => _showEditDialog(context, product),
                isAddingToRestock: _addingToRestock.contains(product.id),
                onAddToRestock: () => _addToRestockingList(product),
              );
            },
          );
        },
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  final int platformCount;
  final int lowStockCount;
  final int staleCount;

  const _InventorySummary({
    required this.platformCount,
    required this.lowStockCount,
    required this.staleCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.sensors,
              value: platformCount,
              label: l10n.activePlatforms,
              color: Colors.teal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryTile(
              icon: Icons.warning_amber,
              value: lowStockCount,
              label: l10n.lowStockProducts,
              color: lowStockCount > 0 ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryTile(
              icon: Icons.cloud_off,
              value: staleCount,
              label: l10n.staleSensors,
              color: staleCount > 0 ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final InventoryProduct product;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onAddToRestock;
  final bool isAddingToRestock;

  const _ProductCard({
    required this.product,
    required this.icon,
    required this.onEdit,
    required this.onAddToRestock,
    required this.isAddingToRestock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final quantity = product.estimatedQuantity;
    final lowStock = product.isLowStock;
    final isStale = product.isMeasurementStaleAt(DateTime.now());
    final statusColor = isStale
        ? Colors.orange
        : lowStock == null
            ? Colors.blueGrey
            : lowStock
                ? Colors.red
                : Colors.green;
    final statusLabel = isStale
        ? l10n.sensorDataStale
        : lowStock == null
            ? l10n.thresholdNotConfigured
            : lowStock
                ? l10n.lowStock
                : l10n.stockOk;
    final lastUpdated = product.lastUpdated?.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    final lastUpdatedLabel = lastUpdated == null
        ? null
        : '${l10n.lastSensorUpdate}: '
            '${materialL10n.formatMediumDate(lastUpdated)} '
            '${materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(lastUpdated))}';

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
                    '${InventoryCategories.labelFor(product.category, l10n)} '
                    '• ${product.id}',
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
                  if (lastUpdatedLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      lastUpdatedLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (lowStock == true && !isStale) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isAddingToRestock ? null : onAddToRestock,
                      icon: isAddingToRestock
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart),
                      label: Text(l10n.addToRestockingList),
                    ),
                  ],
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
