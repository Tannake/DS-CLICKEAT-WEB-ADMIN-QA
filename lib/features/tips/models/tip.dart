/// A tip (propina) preset available for a premise. The backend
/// (`orders/tips/<premId>`) returns just an id, a percentage and an
/// availability flag — mirroring the shape of `PaymentMethod`.
class Tip {
  final int tipsId;
  final int tipsPercentage;
  final bool tipsAvailable;

  const Tip({
    required this.tipsId,
    required this.tipsPercentage,
    required this.tipsAvailable,
  });

  Tip copyWith({int? tipsPercentage, bool? tipsAvailable}) => Tip(
        tipsId: tipsId,
        tipsPercentage: tipsPercentage ?? this.tipsPercentage,
        tipsAvailable: tipsAvailable ?? this.tipsAvailable,
      );

  factory Tip.fromJson(Map<String, dynamic> j) {
    final raw = j['tips_available'];
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
    return Tip(
      tipsId: (j['tips_id'] as num).toInt(),
      tipsPercentage: (j['tips_percentage'] as num?)?.toInt() ?? 0,
      tipsAvailable: available,
    );
  }
}
