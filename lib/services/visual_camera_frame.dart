import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../utils/shelf_counter.dart';

/// Samples the same centered square that the camera preview displays.
ShelfFrame? sampleCameraFrame(CameraImage image) {
  final yuv = image.format.group == ImageFormatGroup.yuv420;
  final bgra = image.format.group == ImageFormatGroup.bgra8888;
  if (!(yuv && image.planes.length >= 3) &&
      !(bgra && image.planes.length == 1)) {
    return null;
  }
  final output = Uint8List(ShelfFrame.byteCount);
  const side = ShelfFrame.side;
  final short = math.min(image.width, image.height);
  final x0 = (image.width - short) ~/ 2;
  final y0 = (image.height - short) ~/ 2;
  final planes = image.planes;
  int sample(int index, int x, int y) {
    final plane = planes[index];
    return plane.bytes[y * plane.bytesPerRow + x * (plane.bytesPerPixel ?? 1)];
  }

  for (var y = 0; y < side; y++) {
    final srcY = y0 + ((y + .5) * short / side).floor();
    for (var x = 0; x < side; x++) {
      final srcX = x0 + ((x + .5) * short / side).floor();
      final idx = (y * side + x) * 3;
      if (yuv) {
        output[idx] = sample(0, srcX, srcY);
        output[idx + 1] = sample(1, srcX ~/ 2, srcY ~/ 2);
        output[idx + 2] = sample(2, srcX ~/ 2, srcY ~/ 2);
      } else {
        final plane = planes.first;
        final pos = srcY * plane.bytesPerRow + srcX * 4;
        final b = plane.bytes[pos],
            g = plane.bytes[pos + 1],
            r = plane.bytes[pos + 2];
        output[idx] = ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255);
        output[idx + 1] =
            (128 + ((-43 * r - 85 * g + 128 * b) >> 8)).clamp(0, 255);
        output[idx + 2] =
            (128 + ((128 * r - 107 * g - 21 * b) >> 8)).clamp(0, 255);
      }
    }
  }
  return ShelfFrame(output);
}
