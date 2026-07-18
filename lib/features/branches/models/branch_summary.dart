import 'package:ds_clickeat_web_admin/features/branches/models/bool_parse.dart';

/// The list-card summary for a branch (sucursal), returned by
/// `premises/<userId>`. The full editable shape lives in [BranchDetail],
/// loaded on demand from `premises-detail/<userId>/<premId>`.
class BranchSummary {
  final int premId;
  final String premName;
  final String premAddress;
  final int premNumberTable;
  final bool premAvailable;
  final String premCity;

  const BranchSummary({
    required this.premId,
    required this.premName,
    required this.premAddress,
    required this.premNumberTable,
    required this.premAvailable,
    required this.premCity,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> j) {
    return BranchSummary(
      premId: (j['prem_id'] as num).toInt(),
      premName: (j['prem_name'] ?? '').toString(),
      premAddress: (j['prem_address'] ?? '').toString(),
      premNumberTable: (j['prem_number_table'] as num?)?.toInt() ?? 0,
      premAvailable: parseBool(j['prem_available']),
      premCity: (j['prem_city'] ?? '').toString(),
    );
  }
}
