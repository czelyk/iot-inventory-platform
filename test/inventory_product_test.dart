import 'package:flutter_test/flutter_test.dart';
import 'package:smart_kuhlschrank/models/product_model.dart';

void main() {
  group('InventoryProduct estimation', () {
    test('rounds current weight to the nearest item count', () {
      const product = InventoryProduct(
        id: 'platform1',
        name: 'Brake cleaner spray',
        currentWeightKg: 0.995,
        unitWeightKg: 0.1,
        minimumStockThreshold: 3,
        category: 'Automotive',
      );

      expect(product.estimatedQuantity, 10);
      expect(product.isLowStock, isFalse);
    });

    test('treats near-zero load-cell drift as an empty platform', () {
      const product = InventoryProduct(
        id: 'platform2',
        name: 'Fastener box',
        currentWeightKg: 0.004,
        unitWeightKg: 0.1,
        minimumStockThreshold: 1,
        category: 'Hardware',
      );

      expect(product.estimatedQuantity, 0);
      expect(product.isLowStock, isTrue);
    });

    test('does not estimate quantity until unit weight is configured', () {
      const product = InventoryProduct(
        id: 'platform3',
        name: 'Unconfigured product',
        currentWeightKg: 2.5,
        category: 'Other',
      );

      expect(product.estimatedQuantity, isNull);
      expect(product.isLowStock, isNull);
    });

    test('handles non-finite constructor values safely', () {
      const product = InventoryProduct(
        id: 'platform4',
        name: 'Invalid sensor reading',
        currentWeightKg: double.nan,
        unitWeightKg: 0.1,
        category: 'Other',
      );

      expect(product.estimatedQuantity, 0);
    });
  });

  group('InventoryProduct data parsing', () {
    test('accepts legacy string values and normalizes fields', () {
      final product = InventoryProduct.fromMap('platform5', {
        'name': '  Cable box  ',
        'weight': '1,25',
        'unitWeight': '0.25',
        'minimumStockThreshold': '2',
        'category': 'Electronics',
        'status': 'ACTIVE',
        'lastUpdated': '2026-10-01T12:00:00Z',
      });

      expect(product.name, 'Cable box');
      expect(product.currentWeightKg, 1.25);
      expect(product.estimatedQuantity, 5);
      expect(product.minimumStockThreshold, 2);
      expect(product.category, 'Electronics');
      expect(product.isActive, isTrue);
      expect(product.lastUpdated, DateTime.utc(2026, 10, 1, 12));
    });

    test('falls back safely for malformed external data', () {
      final product = InventoryProduct.fromMap('platform6', {
        'name': 42,
        'current_weight_kg': 'not-a-number',
        'unit_weight_kg': double.infinity,
        'minimum_stock_threshold': -1,
        'category': 'Unsupported',
        'status': 'inactive',
      });

      expect(product.name, 'Product 6');
      expect(product.currentWeightKg, 0);
      expect(product.unitWeightKg, isNull);
      expect(product.minimumStockThreshold, isNull);
      expect(product.category, 'Other');
      expect(product.isActive, isFalse);
    });

    test('marks old sensor measurements as stale', () {
      final now = DateTime.utc(2026, 10, 1, 12);
      final product = InventoryProduct(
        id: 'platform7',
        name: 'Fasteners',
        currentWeightKg: 1,
        category: 'Hardware',
        lastUpdated: now.subtract(const Duration(minutes: 3)),
      );

      expect(product.isMeasurementStaleAt(now), isTrue);
      expect(
        product.isMeasurementStaleAt(
          now.subtract(const Duration(minutes: 2)),
        ),
        isFalse,
      );
    });
  });
}
