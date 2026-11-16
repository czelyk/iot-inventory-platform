import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_kuhlschrank/services/visual_platform_store.dart';
import 'package:smart_kuhlschrank/utils/shelf_counter.dart';

typedef Box = ({int x, int y, int w, int h});

ShelfFrame sample(List<Box> products,
    {int light = 0, bool cameraMoved = false}) {
  const side = ShelfFrame.side;
  final pixels = Uint8List(ShelfFrame.byteCount);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final p = (y * side + x) * 3;
      final product = products.any((item) =>
          x >= item.x &&
          x < item.x + item.w &&
          y >= item.y &&
          y < item.y + item.h);
      pixels[p] = (product ? 190 : 110) + light;
      pixels[p + 1] = product ? 160 : 128;
      pixels[p + 2] = 128;
      if (cameraMoved && y < 3 && x < half) pixels[p] = 180;
    }
  }
  return ShelfFrame(pixels);
}

const half = ShelfFrame.side ~/ 2;
const referenceProduct = (x: 14, y: 25, w: 11, h: 19);
const fiveProducts = [
  referenceProduct,
  (x: 31, y: 25, w: 11, h: 19),
  (x: 49, y: 25, w: 11, h: 19),
  (x: 66, y: 25, w: 11, h: 19),
  (x: 49, y: 57, w: 11, h: 19),
];

void main() {
  final empty = sample([]);
  final one = sample([referenceProduct]);
  final counter = ShelfCounter.calibrate(empty, one)!;

  test('calibrates one product and counts five separately visible silhouettes',
      () {
    expect(
        counter.estimate(sample(fiveProducts)), (count: 5, lowerBound: false));
    expect(counter.estimate(empty), (count: 0, lowerBound: false));
  });

  test('5+ means at least five visible products when others may be hidden', () {
    expect(counter.estimate(sample(fiveProducts), expectHidden: true),
        (count: 5, lowerBound: true));
    expect(counter.estimate(empty, expectHidden: true),
        (count: 0, lowerBound: false));
  });

  test('merging silhouettes marks the estimate as a lower bound', () {
    final touching = sample([
      referenceProduct,
      (x: 25, y: 25, w: 11, h: 19),
      (x: 65, y: 25, w: 11, h: 19),
    ]);
    expect(counter.estimate(touching), (count: 2, lowerBound: true));
  });

  test('rejects wrong references and camera movement, tolerates light shift',
      () {
    expect(ShelfCounter.calibrate(empty, empty), isNull);
    expect(ShelfCounter.calibrate(empty, sample(fiveProducts)), isNull);
    expect(counter.estimate(sample(fiveProducts, cameraMoved: true)), isNull);
    expect(counter.estimate(sample(fiveProducts, light: 14)),
        (count: 5, lowerBound: false));
  });

  test('unstable and rejected frames do not replace the last saved count', () {
    final stable = StableStockEstimate();
    const five = (count: 5, lowerBound: true);
    expect(stable.add(five), isNull);
    expect(stable.add(five), isNull);
    expect(stable.add(null), isNull);
    expect(stable.add(five), isNull);
    expect(stable.add(five), isNull);
    expect(stable.add(five), five);
    expect(stable.add((count: 4, lowerBound: false)), isNull);
  });

  test('calibration, platform label, date and 5+ stock survive reloading',
      () async {
    SharedPreferences.setMockInitialValues({});
    const store = VisualPlatformStore('student');
    final measuredAt = DateTime.utc(2026, 11, 16);
    await store.saveLabel('Raf A3');
    await store.saveCalibration('back', empty, one);
    await store
        .saveStock(VisualStock((count: 5, lowerBound: true), measuredAt));
    final saved = await const VisualPlatformStore('student').load();
    expect(saved.label, 'Raf A3');
    expect(saved.cameraKey, 'back');
    expect(saved.stock!.estimate, (count: 5, lowerBound: true));
    expect(saved.stock!.measuredAt, measuredAt);
    final restored = ShelfCounter.calibrate(saved.empty!, saved.oneItem!);
    expect(restored!.estimate(sample(fiveProducts))!.count, 5);
    expect((await const VisualPlatformStore('other').load()).stock, isNull);
  });
}
