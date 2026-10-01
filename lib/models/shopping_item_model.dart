class ShoppingItem {
  final String id;
  final String name;
  final bool isBought;
  final String category;
  final DateTime? createdAt;
  final String? sourceProductId;

  ShoppingItem({
    required this.id,
    required this.name,
    this.isBought = false,
    this.category = 'Other',
    this.createdAt,
    this.sourceProductId,
  });
}
