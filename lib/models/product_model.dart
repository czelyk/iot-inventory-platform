import 'package:cloud_firestore/cloud_firestore.dart';

/// A product assigned to one physical weighing platform.
class InventoryProduct {
  static const double sensorNoiseFloorKg = 0.005;
  static const Duration staleMeasurementAfter = Duration(minutes: 2);

  final String id;
  final String name;
  final double currentWeightKg;
  final double? unitWeightKg;
  final int? minimumStockThreshold;
  final String category;
  final String status;
  final DateTime? lastUpdated;

  const InventoryProduct({
    required this.id,
    required this.name,
    required this.currentWeightKg,
    required this.category,
    this.unitWeightKg,
    this.minimumStockThreshold,
    this.status = 'active',
    this.lastUpdated,
  });

  bool get isActive => status != 'inactive';

  bool isMeasurementStaleAt(DateTime now) {
    final updatedAt = lastUpdated;
    if (updatedAt == null) return false;
    return now.difference(updatedAt) > staleMeasurementAfter;
  }

  /// Estimated item count derived from the measured and calibrated unit weight.
  ///
  /// Small values around zero are treated as sensor noise. Rounding, instead of
  /// truncating, keeps normal load-cell drift from systematically undercounting.
  int? get estimatedQuantity {
    final unitWeight = unitWeightKg;
    if (unitWeight == null || !unitWeight.isFinite || unitWeight <= 0) {
      return null;
    }

    final measuredWeight = currentWeightKg.isFinite ? currentWeightKg : 0.0;
    final stableWeight = measuredWeight.abs() < sensorNoiseFloorKg
        ? 0.0
        : measuredWeight < 0
            ? 0.0
            : measuredWeight;
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

    final rawData = doc.data();
    if (rawData is! Map<String, dynamic>) {
      throw StateError('Product document has an invalid data format.');
    }

    return InventoryProduct.fromMap(doc.id, rawData);
  }

  factory InventoryProduct.fromMap(String id, Map<String, dynamic> data) {
    final currentWeight =
        data['current_weight_kg'] ?? data['currentWeight'] ?? data['weight'];
    final unitWeight = data['unit_weight_kg'] ?? data['unitWeight'];
    final minimumThreshold = data['minimum_stock_threshold'] ??
        data['minimumStockThreshold'];
    final parsedName = data['name'] is String
        ? (data['name'] as String).trim()
        : '';
    final parsedThreshold = _readInt(minimumThreshold);

    return InventoryProduct(
      id: id,
      name: parsedName.isEmpty ? _defaultName(id) : parsedName,
      currentWeightKg: _readDouble(currentWeight) ?? 0.0,
      unitWeightKg: _readDouble(unitWeight),
      minimumStockThreshold:
          parsedThreshold != null && parsedThreshold >= 0
              ? parsedThreshold
              : null,
      category: _normalizeCategory(
        data['category'] is String ? data['category'] as String : null,
      ),
      status: data['status'] is String
          ? (data['status'] as String).toLowerCase()
          : 'active',
      lastUpdated: _readDateTime(data['last_updated'] ?? data['lastUpdated']),
    );
  }

  static double? _readDouble(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : value is String
            ? double.tryParse(value.replaceAll(',', '.'))
            : null;
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
