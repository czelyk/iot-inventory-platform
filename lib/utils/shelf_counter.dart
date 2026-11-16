import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// A centered, square sample from a fixed camera. Each pixel stores Y, U, V.
class ShelfFrame {
  static const side = 96;
  static const byteCount = side * side * 3;
  final Uint8List pixels;

  ShelfFrame(this.pixels) {
    if (pixels.length != byteCount) throw ArgumentError('Invalid shelf frame');
  }

  String encode() => base64Encode(pixels);
  static ShelfFrame decode(String value) => ShelfFrame(base64Decode(value));
}

typedef StockEstimate = ({int count, bool lowerBound});

class ShelfCounter {
  final ShelfFrame empty;
  final _Blob _reference;
  static const _side = ShelfFrame.side;

  ShelfCounter._(this.empty, this._reference);

  /// Rejects a reference with movement at the edges or multiple distinct items.
  static ShelfCounter? calibrate(ShelfFrame empty, ShelfFrame oneItem) {
    final blobs = _foreground(empty, oneItem);
    if (blobs == null || blobs.isEmpty) return null;
    final reference = blobs.first;
    if (reference.area < 48 ||
        reference.area > _side * _side * .35 ||
        reference.width < 5 ||
        reference.height < 5 ||
        (blobs.length > 1 && blobs[1].area > reference.area * .22)) {
      return null;
    }
    return ShelfCounter._(empty, reference);
  }

  /// Counts isolated reference-sized silhouettes. A joined or partly visible
  /// group contributes a conservative count, with a '+' instead of an exact claim.
  StockEstimate? estimate(ShelfFrame current, {bool expectHidden = false}) {
    final blobs = _foreground(empty, current);
    if (blobs == null) return null;
    if (blobs.isEmpty) return (count: 0, lowerBound: false);

    var count = 0;
    var uncertain = false;
    for (final blob in blobs) {
      final ratio = blob.area / _reference.area;
      if (ratio < .19) continue;
      final width = blob.width / _reference.width;
      final height = blob.height / _reference.height;
      final isolated = ratio >= .68 &&
          ratio <= 1.26 &&
          width >= .65 &&
          width <= 1.32 &&
          height >= .65 &&
          height <= 1.32;
      if (isolated) {
        count++;
      } else if (ratio >= .4) {
        count += math.max(1, (ratio / 1.38).floor());
        uncertain = true;
      } else {
        uncertain = true;
      }
    }
    if (count == 0) return null;
    return (count: count, lowerBound: uncertain || expectHidden);
  }

  static List<_Blob>? _foreground(ShelfFrame empty, ShelfFrame current) {
    final border = List.generate(3, (_) => <int>[]);
    for (var y = 0; y < _side; y++) {
      for (var x = 0; x < _side; x++) {
        if (x >= 3 && x < _side - 3 && y >= 3 && y < _side - 3) continue;
        final p = (y * _side + x) * 3;
        for (var c = 0; c < 3; c++) {
          border[c].add(current.pixels[p + c] - empty.pixels[p + c]);
        }
      }
    }
    final shift = border.map((values) {
      values.sort();
      return values[values.length ~/ 2];
    }).toList();
    if (shift[0].abs() > 45 || shift[1].abs() > 25 || shift[2].abs() > 25) {
      return null;
    }

    final edgeTolerance = [22, 17, 17];
    for (var c = 0; c < 3; c++) {
      final edge = border[c];
      if ((edge[edge.length ~/ 10] - shift[c]).abs() > edgeTolerance[c] ||
          (edge[edge.length * 9 ~/ 10] - shift[c]).abs() > edgeTolerance[c]) {
        return null;
      }
    }

    final raw = Uint8List(_side * _side);
    for (var y = 4; y < _side - 4; y++) {
      for (var x = 4; x < _side - 4; x++) {
        final i = y * _side + x;
        final p = i * 3;
        final dy = (current.pixels[p] - empty.pixels[p] - shift[0]).abs();
        final du =
            (current.pixels[p + 1] - empty.pixels[p + 1] - shift[1]).abs();
        final dv =
            (current.pixels[p + 2] - empty.pixels[p + 2] - shift[2]).abs();
        if (dy >= 27 || du + dv >= 25) raw[i] = 1;
      }
    }
    final mask = Uint8List(raw.length);
    var area = 0;
    for (var y = 4; y < _side - 4; y++) {
      for (var x = 4; x < _side - 4; x++) {
        final i = y * _side + x;
        if (raw[i] == 0) continue;
        if (raw[i - 1] + raw[i + 1] + raw[i - _side] + raw[i + _side] >= 2) {
          mask[i] = 1;
          area++;
        }
      }
    }
    if (area > mask.length * .72) return null;

    final blobs = <_Blob>[];
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0) continue;
      final queue = [i];
      mask[i] = 0;
      var minX = _side, minY = _side, maxX = 0, maxY = 0;
      for (var head = 0; head < queue.length; head++) {
        final p = queue[head];
        final x = p % _side, y = p ~/ _side;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        for (final j in [p - 1, p + 1, p - _side, p + _side]) {
          if (mask[j] == 0) continue;
          mask[j] = 0;
          queue.add(j);
        }
      }
      if (queue.length >= 16) {
        blobs.add(_Blob(queue.length, maxX - minX + 1, maxY - minY + 1));
      }
    }
    return blobs..sort((a, b) => b.area.compareTo(a.area));
  }
}

class _Blob {
  final int area, width, height;
  const _Blob(this.area, this.width, this.height);
}

/// Ignore changing estimates until the same result repeats in three frames.
class StableStockEstimate {
  StockEstimate? _candidate;
  int _streak = 0;

  StockEstimate? add(StockEstimate? value) {
    if (value == null || _candidate != value) {
      _candidate = value;
      _streak = 0;
    }
    if (value == null) return null;
    return ++_streak >= 3 ? value : null;
  }
}
