class ShoppingItem {
  final String id;
  final String name;
  final bool isBought;
  final String category; // Yeni alan

  ShoppingItem({
    required this.id,
    required this.name,
    this.isBought = false,
    this.category = 'Other', // Varsayılan değer
  });
}
