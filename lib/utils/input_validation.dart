abstract final class InputValidation {
  static const int maxNameLength = 100;
  static const int maxThreshold = 1000000;
  static const double maxWeightKg = 10000;

  static final RegExp _platformId = RegExp(r'^platform[0-9]{1,2}$');
  static final RegExp _documentId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

  static String name(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > maxNameLength ||
        _controlCharacters.hasMatch(normalized)) {
      throw ArgumentError.value(value, 'value', 'Invalid name.');
    }
    return normalized;
  }

  static String category(String value, Iterable<String> allowed) {
    if (!allowed.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid category.');
    }
    return value;
  }

  static String platformId(String value) {
    if (!_platformId.hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid platform ID.');
    }
    return value;
  }

  static String documentId(String value) {
    if (!_documentId.hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid document ID.');
    }
    return value;
  }

  static double? optionalWeight(double? value) {
    if (value != null &&
        (!value.isFinite || value <= 0 || value > maxWeightKg)) {
      throw ArgumentError.value(value, 'value', 'Invalid weight.');
    }
    return value;
  }

  static int? optionalThreshold(int? value) {
    if (value != null && (value < 0 || value > maxThreshold)) {
      throw ArgumentError.value(value, 'value', 'Invalid threshold.');
    }
    return value;
  }
}
