class Premise {
  final int premId;
  final String premName;
  final String premAddress;

  const Premise({
    required this.premId,
    required this.premName,
    required this.premAddress,
  });

  factory Premise.fromJson(Map<String, dynamic> json) {
    return Premise(
      premId: (json['prem_id'] as num).toInt(),
      premName: (json['prem_name'] ?? '') as String,
      premAddress: (json['prem_address'] ?? '') as String,
    );
  }
}
