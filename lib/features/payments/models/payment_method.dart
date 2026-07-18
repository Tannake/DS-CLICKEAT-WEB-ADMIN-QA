/// A payment method available for a premise. The backend
/// (`payments/<premId>`) returns just an id, a name and an availability flag —
/// no icon, description or commission (those are handled dynamically elsewhere).
class PaymentMethod {
  final int paymId;
  final String paymName;
  final bool paymAvailable;

  const PaymentMethod({
    required this.paymId,
    required this.paymName,
    required this.paymAvailable,
  });

  PaymentMethod copyWith({String? paymName, bool? paymAvailable}) =>
      PaymentMethod(
        paymId: paymId,
        paymName: paymName ?? this.paymName,
        paymAvailable: paymAvailable ?? this.paymAvailable,
      );

  factory PaymentMethod.fromJson(Map<String, dynamic> j) {
    final raw = j['paym_available'];
    bool available;
    if (raw is bool) {
      available = raw;
    } else if (raw is num) {
      available = raw.toInt() == 1;
    } else if (raw is String) {
      final s = raw.toLowerCase().trim();
      available = s == 'true' || s == '1';
    } else {
      available = true;
    }
    return PaymentMethod(
      paymId: (j['paym_id'] as num).toInt(),
      paymName: (j['paym_name'] ?? '').toString(),
      paymAvailable: available,
    );
  }
}
