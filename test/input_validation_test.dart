import 'package:flutter_test/flutter_test.dart';
import 'package:smart_kuhlschrank/utils/input_validation.dart';

void main() {
  group('InputValidation', () {
    test('normalizes bounded names', () {
      expect(InputValidation.name('  Fasteners  '), 'Fasteners');
      expect(
        () => InputValidation.name(List.filled(101, 'x').join()),
        throwsArgumentError,
      );
      expect(() => InputValidation.name('   '), throwsArgumentError);
      expect(() => InputValidation.name('Line\nbreak'), throwsArgumentError);
    });

    test('rejects document path injection', () {
      expect(InputValidation.platformId('platform10'), 'platform10');
      expect(
        () => InputValidation.platformId('../platform1'),
        throwsArgumentError,
      );
      expect(
        () => InputValidation.documentId('item/child'),
        throwsArgumentError,
      );
    });

    test('rejects non-finite and excessive numeric values', () {
      expect(
        () => InputValidation.optionalWeight(double.nan),
        throwsArgumentError,
      );
      expect(
        () => InputValidation.optionalWeight(10001),
        throwsArgumentError,
      );
      expect(
        () => InputValidation.optionalThreshold(1000001),
        throwsArgumentError,
      );
    });
  });
}
