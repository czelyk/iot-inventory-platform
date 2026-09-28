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
  });
}
