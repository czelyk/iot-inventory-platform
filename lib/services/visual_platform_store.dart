import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/shelf_counter.dart';

class VisualStock {
  final StockEstimate estimate;
  final DateTime measuredAt;

  const VisualStock(this.estimate, this.measuredAt);
}

class VisualPlatformData {
  final String? label, cameraKey;
  final ShelfFrame? empty, oneItem;
  final VisualStock? stock;

  const VisualPlatformData({
    this.label,
    this.cameraKey,
    this.empty,
    this.oneItem,
    this.stock,
  });
}

/// This prototype keeps calibration and stock per signed-in user, on-device.
class VisualPlatformStore {
  final String userId;
  const VisualPlatformStore(this.userId);

  String _key(String field) => 'visual_platform.v1.$userId.$field';

  Future<VisualPlatformData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(_key('label'));
    ShelfFrame? empty, one;
    String? source;
    VisualStock? stock;
    try {
      final raw = prefs.getString(_key('calibration'));
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        empty = ShelfFrame.decode(data['empty'] as String);
        one = ShelfFrame.decode(data['one'] as String);
        source = data['source'] as String;
      }
    } on Object {
      empty = one = null;
    }
    try {
      final raw = prefs.getString(_key('stock'));
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        stock = VisualStock(
          (count: data['count'] as int, lowerBound: data['lowerBound'] as bool),
          DateTime.parse(data['measuredAt'] as String),
        );
      }
    } on Object {
      stock = null;
    }
    return VisualPlatformData(
      label: label,
      empty: empty,
      oneItem: one,
      cameraKey: source,
      stock: stock,
    );
  }

  Future<void> _set(String name, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(name), value)) {
      throw StateError('Could not save visual platform');
    }
  }

  Future<void> saveLabel(String label) => _set('label', label);

  Future<void> saveCalibration(
    String source,
    ShelfFrame empty,
    ShelfFrame one,
  ) =>
      _set(
        'calibration',
        jsonEncode(
            {'source': source, 'empty': empty.encode(), 'one': one.encode()}),
      );

  Future<void> saveStock(VisualStock stock) => _set(
        'stock',
        jsonEncode({
          'count': stock.estimate.count,
          'lowerBound': stock.estimate.lowerBound,
          'measuredAt': stock.measuredAt.toUtc().toIso8601String(),
        }),
      );
}
