import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item_model.dart';
import '../utils/input_validation.dart';
import '../utils/inventory_categories.dart';

class ShoppingListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _getItemsCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('shopping_list');
  }

  Stream<List<ShoppingItem>> getItemsStream() {
    final collection = _getItemsCollection();
    if (collection == null) return Stream.value(const []);

    return collection.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        return ShoppingItem(
          id: doc.id,
          name: _readString(data['name'] ?? data['item_name']),
          isBought: _readBool(data['isBought'] ?? data['is_bought']),
          category: _readString(data['category'], fallback: 'Other'),
          createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
          sourceProductId: data['sourceProductId'] is String
              ? data['sourceProductId'] as String
              : null,
        );
      }).where((item) => item.name.isNotEmpty).toList();

      items.sort((a, b) {
        if (a.isBought != b.isBought) return a.isBought ? 1 : -1;
        final aCreatedAt = a.createdAt;
        final bCreatedAt = b.createdAt;
        if (aCreatedAt != null && bCreatedAt != null) {
          final byDate = bCreatedAt.compareTo(aCreatedAt);
          if (byDate != 0) return byDate;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return items;
    });
  }

  Future<void> addItem(String name, String category) async {
    final collection = _getItemsCollection();
    if (collection == null) throw StateError('User is not signed in.');
    final normalizedName = InputValidation.name(name);
    final validCategory = InputValidation.category(
      category,
      InventoryCategories.values,
    );

    await collection.add({
      'name': normalizedName,
      'isBought': false,
      'category': validCategory,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds an inventory product with a deterministic document ID, preventing
  /// repeated taps or sensor updates from creating duplicate list entries.
  Future<void> addInventoryProduct({
    required String productId,
    required String name,
    required String category,
  }) async {
    final collection = _getItemsCollection();
    if (collection == null) throw StateError('User is not signed in.');

    final validProductId = InputValidation.platformId(productId);
    final validName = InputValidation.name(name);
    final validCategory = InputValidation.category(
      category,
      InventoryCategories.values,
    );

    await collection.doc('inventory_$validProductId').set({
      'name': validName,
      'isBought': false,
      'category': validCategory,
      'sourceProductId': validProductId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleItemStatus(String id, bool isBought) async {
    final collection = _getItemsCollection();
    if (collection == null) throw StateError('User is not signed in.');
    await collection
        .doc(InputValidation.documentId(id))
        .update({'isBought': isBought});
  }

  Future<void> deleteItem(String id) async {
    final collection = _getItemsCollection();
    if (collection == null) throw StateError('User is not signed in.');
    await collection.doc(InputValidation.documentId(id)).delete();
  }

  static String _readString(Object? value, {String fallback = ''}) =>
      value is String ? value.trim() : fallback;

  static bool _readBool(Object? value) => value is bool ? value : false;
}
