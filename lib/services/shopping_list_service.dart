import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item_model.dart';

class ShoppingListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper method to get the collection reference
  CollectionReference? _getItemsCollection() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('shopping_list');
  }

  // Get a stream of shopping items
  Stream<List<ShoppingItem>> getItemsStream() {
    final collection = _getItemsCollection();
    if (collection == null) return Stream.value([]);

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ShoppingItem(
          id: doc.id,
          name: data['name'] ?? data['item_name'] ?? '',
          isBought: data['isBought'] ?? data['is_bought'] ?? false,
          category: data['category'] ?? 'Other', // Kategoriyi oku
        );
      }).toList();
    });
  }

  // Add a new item with category
  Future<void> addItem(String name, String category) async {
    final collection = _getItemsCollection();
    if (collection != null) {
      await collection.add({
        'name': name,
        'isBought': false,
        'category': category, // Kategoriyi kaydet
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Toggle item status (bought/not bought)
  Future<void> toggleItemStatus(String id, bool isBought) async {
    final collection = _getItemsCollection();
    if (collection != null) {
      await collection.doc(id).update({'isBought': isBought});
    }
  }

  // Delete an item
  Future<void> deleteItem(String id) async {
    final collection = _getItemsCollection();
    if (collection != null) {
      await collection.doc(id).delete();
    }
  }
}
