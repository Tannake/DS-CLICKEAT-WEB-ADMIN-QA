/// A cancellation reason available for a premise. The backend
/// (`orders/reason-cancel/<premId>`) returns an id, a name and an
/// availability flag — mirroring the shape of `PaymentMethod`.
class CancelReason {
  final int reasId;
  final String reasName;
  final bool reasAvailable;

  const CancelReason({
    required this.reasId,
    required this.reasName,
    required this.reasAvailable,
  });

  CancelReason copyWith({String? reasName, bool? reasAvailable}) => CancelReason(
        reasId: reasId,
        reasName: reasName ?? this.reasName,
        reasAvailable: reasAvailable ?? this.reasAvailable,
      );

  factory CancelReason.fromJson(Map<String, dynamic> j) {
    final raw = j['reas_available'];
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
    return CancelReason(
      reasId: (j['reas_id'] as num).toInt(),
      reasName: (j['reas_name'] ?? '').toString(),
      reasAvailable: available,
    );
  }
}
