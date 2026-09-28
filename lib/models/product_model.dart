import 'package:cloud_firestore/cloud_firestore.dart';

/// A product assigned to one physical weighing platform.
class InventoryProduct {
  static const double sensorNoiseFloorKg = 0.005;

  final String id;
  final String name;
  final double currentWeightKg;
  final double? unitWeightKg;
  final int? minimumStockThreshold;
  final String category;

  const InventoryProduct({
    required this.id,
    required this.name,
    required this.currentWeightKg,
    required this.category,
    this.unitWeightKg,
    this.minimumStockThreshold,
  });

  /// Estimated item count derived from the measured and calibrated unit weight.
  ///
  /// Small values around zero are treated as sensor noise. Rounding, instead of
  /// truncating, keeps normal load-cell drift from systematically undercounting.
  int? get estimatedQuantity {
    final unitWeight = unitWeightKg;
    if (unitWeight == null || unitWeight <= 0) return null;

    final stableWeight = currentWeightKg.abs() < sensorNoiseFloorKg
        ? 0.0
        : currentWeightKg < 0
            ? 0.0
            : currentWeightKg;
    final quantity = (stableWeight / unitWeight).round();
    return quantity < 0 ? 0 : quantity;
  }

  bool? get isLowStock {
    final quantity = estimatedQuantity;
    final threshold = minimumStockThreshold;
    if (quantity == null || threshold == null) return null;
    return quantity <= threshold;
  }

  factory InventoryProduct.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      throw StateError('Product document does not exist or has no data.');
    }

    final data = doc.data()! as Map<String, dynamic>;
    final currentWeight =
        data['current_weight_kg'] ?? data['currentWeight'] ?? data['weight'];
    final unitWeight = data['unit_weight_kg'] ?? data['unitWeight'];
    final minimumThreshold = data['minimum_stock_threshold'] ??
        data['minimumStockThreshold'];

    return InventoryProduct(
      id: doc.id,
      name: data['name'] as String? ?? _defaultName(doc.id),
      currentWeightKg: (currentWeight as num?)?.toDouble() ?? 0.0,
      unitWeightKg: (unitWeight as num?)?.toDouble(),
      minimumStockThreshold: (minimumThreshold as num?)?.toInt(),
      category: _normalizeCategory(data['category'] as String?),
    );
  }

  static String _defaultName(String id) {
    final platformNumber = RegExp(r'\d+').firstMatch(id)?.group(0);
    return platformNumber == null
        ? 'Unconfigured product'
        : 'Product $platformNumber';
  }

  static String _normalizeCategory(String? category) {
    const supportedCategories = {
      'Automotive',
      'Electronics',
      'Hardware',
      'Packaged Goods',
      'Cleaning Supplies',
      'Office Supplies',
      'Other',
    };
    return supportedCategories.contains(category) ? category! : 'Other';
  }
}
