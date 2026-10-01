import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

abstract final class InventoryCategories {
  static const List<String> values = [
    'Automotive',
    'Electronics',
    'Hardware',
    'Packaged Goods',
    'Cleaning Supplies',
    'Office Supplies',
    'Other',
  ];

  static IconData iconFor(String category) {
    return switch (category) {
      'Automotive' => Icons.directions_car,
      'Electronics' => Icons.memory,
      'Hardware' => Icons.handyman,
      'Packaged Goods' => Icons.inventory_2,
      'Cleaning Supplies' => Icons.cleaning_services,
      'Office Supplies' => Icons.business_center,
      _ => Icons.category,
    };
  }

  static String labelFor(String category, AppLocalizations l10n) {
    return switch (category) {
      'Automotive' => l10n.categoryAutomotive,
      'Electronics' => l10n.categoryElectronics,
      'Hardware' => l10n.categoryHardware,
      'Packaged Goods' => l10n.categoryPackagedGoods,
      'Cleaning Supplies' => l10n.categoryCleaningSupplies,
      'Office Supplies' => l10n.categoryOfficeSupplies,
      _ => l10n.categoryOther,
    };
  }
}
