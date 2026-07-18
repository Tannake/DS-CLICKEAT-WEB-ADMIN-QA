/// Coerces the various truthy shapes the backend uses (`true`, `1`, `"1"`,
/// `"true"`) into a Dart `bool`. Shared by the branch models.
bool parseBool(Object? raw, {bool fallback = false}) {
  if (raw is bool) return raw;
  if (raw is num) return raw.toInt() == 1;
  if (raw is String) {
    final s = raw.toLowerCase().trim();
    return s == 'true' || s == '1';
  }
  return fallback;
}
