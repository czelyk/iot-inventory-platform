import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';
import '../models/shopping_item_model.dart';
import '../services/shopping_list_service.dart';
import '../utils/inventory_categories.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final ShoppingListService _shoppingListService = ShoppingListService();

  Future<void> _showAddItemDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    var selectedCategory = 'Other';
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(l10n.addNewItem),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.itemName,
                        prefixIcon: const Icon(Icons.edit),
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
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                InventoryCategories.iconFor(category),
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                InventoryCategories.labelFor(category, l10n),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setDialogState(() => selectedCategory = newValue);
                        }
                      },
                    ),
                  ],
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
                            if (name.isEmpty) return;

                            setDialogState(() => isSaving = true);
                            try {
                              await _shoppingListService.addItem(
                                name,
                                selectedCategory,
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
                        : Text(l10n.add),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _runUpdate(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.updateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shoppingList),
      ),
      body: StreamBuilder<List<ShoppingItem>>(
        stream: _shoppingListService.getItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${l10n.error}: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.yourShoppingListIsEmpty,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final items = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: item.isBought,
                    activeColor: Colors.teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (bool? value) {
                      _runUpdate(
                        () => _shoppingListService.toggleItemStatus(
                          item.id,
                          value ?? false,
                        ),
                      );
                    },
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.isBought ? TextDecoration.lineThrough : null,
                      color: item.isBought
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Kategori bilgisi ve ikonu
                  subtitle: Row(
                    children: [
                      Icon(
                        InventoryCategories.iconFor(item.category),
                        size: 14, 
                        color: Colors.grey
                      ),
                      const SizedBox(width: 4),
                      Text(
                        InventoryCategories.labelFor(item.category, l10n),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _runUpdate(
                      () => _shoppingListService.deleteItem(item.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
        backgroundColor: Colors.teal,
      ),
    );
  }
}
