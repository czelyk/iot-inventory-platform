import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product_model.dart';
import '../utils/input_validation.dart';
import '../utils/inventory_categories.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _productsCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;

    // Keep the existing collection name so deployed ESP32 devices continue to
    // publish without a coordinated firmware/database migration.
    return _db.collection('users').doc(user.uid).collection('platforms');
  }

  Stream<List<InventoryProduct>> getProductsStream() {
    final collection = _productsCollection();
    if (collection == null) return Stream.value(const []);

    return collection.snapshots().map((snapshot) {
      final products = snapshot.docs
          .map(InventoryProduct.fromFirestore)
          .where((product) => product.isActive)
          .toList(growable: false);
      products.sort((a, b) => a.id.compareTo(b.id));
      return products;
    });
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String category,
    double? unitWeightKg,
    int? minimumStockThreshold,
  }) async {
    final collection = _productsCollection();
    if (collection == null) throw StateError('User is not signed in.');

    final validProductId = InputValidation.platformId(productId);
    final validName = InputValidation.name(name);
    final validCategory = InputValidation.category(
      category,
      InventoryCategories.values,
    );
    final validUnitWeight = InputValidation.optionalWeight(unitWeightKg);
    final validThreshold = InputValidation.optionalThreshold(
      minimumStockThreshold,
    );

    await collection.doc(validProductId).set({
      'name': validName,
      'category': validCategory,
      'unit_weight_kg': validUnitWeight ?? FieldValue.delete(),
      'minimum_stock_threshold':
          validThreshold ?? FieldValue.delete(),
      'configuration_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
