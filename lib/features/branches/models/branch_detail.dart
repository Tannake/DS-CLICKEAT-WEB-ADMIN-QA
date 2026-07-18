import 'package:ds_clickeat_web_admin/features/branches/models/bool_parse.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_schedule.dart';

/// The full editable shape for a branch, loaded on demand from
/// `premises-detail/<userId>/<premId>`. `userEmail` is read-only; everything
/// else can be edited and posted back via `premises-update`.
class BranchDetail {
  final int premId;
  final String premName;
  final String userEmail;
  final String premLatitud;
  final String premLongitud;
  final String premAddress;
  final bool premAvailable;
  final String premStatementDescriptor;
  final int premNumberTable;
  final String premState;
  final String premCity;
  final String premImageUrl;
  final bool premPickUp;
  final String premPickUpCost;
  final bool premPickUpMandatory;
  final List<BranchSchedule> horarios;

  const BranchDetail({
    required this.premId,
    required this.premName,
    required this.userEmail,
    required this.premLatitud,
    required this.premLongitud,
    required this.premAddress,
    required this.premAvailable,
    required this.premStatementDescriptor,
    required this.premNumberTable,
    required this.premState,
    required this.premCity,
    required this.premImageUrl,
    required this.premPickUp,
    required this.premPickUpCost,
    required this.premPickUpMandatory,
    required this.horarios,
  });

  factory BranchDetail.fromJson(Map<String, dynamic> j) {
    return BranchDetail(
      premId: (j['prem_id'] as num).toInt(),
      premName: (j['prem_name'] ?? '').toString(),
      userEmail: (j['user_email'] ?? '').toString(),
      premLatitud: (j['prem_latitud'] ?? '').toString(),
      premLongitud: (j['prem_longitud'] ?? '').toString(),
      premAddress: (j['prem_address'] ?? '').toString(),
      premAvailable: parseBool(j['prem_available']),
      premStatementDescriptor: (j['prem_statement_descriptor'] ?? '').toString(),
      premNumberTable: (j['prem_number_table'] as num?)?.toInt() ?? 0,
      premState: (j['prem_state'] ?? '').toString(),
      premCity: (j['prem_city'] ?? '').toString(),
      premImageUrl: (j['prem_image_url'] ?? '').toString(),
      premPickUp: parseBool(j['prem_pick_up']),
      premPickUpCost: (j['prem_pick_up_cost'] ?? '0.00').toString(),
      premPickUpMandatory: parseBool(j['prem_pick_up_mandatory']),
      horarios: (j['horarios'] is List)
          ? (j['horarios'] as List)
              .map((e) =>
                  BranchSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }

  BranchDetail copyWith({
    String? premName,
    String? premLatitud,
    String? premLongitud,
    String? premAddress,
    bool? premAvailable,
    String? premStatementDescriptor,
    int? premNumberTable,
    String? premState,
    String? premCity,
    bool? premPickUp,
    String? premPickUpCost,
    bool? premPickUpMandatory,
    List<BranchSchedule>? horarios,
  }) {
    return BranchDetail(
      premId: premId,
      premName: premName ?? this.premName,
      userEmail: userEmail,
      premLatitud: premLatitud ?? this.premLatitud,
      premLongitud: premLongitud ?? this.premLongitud,
      premAddress: premAddress ?? this.premAddress,
      premAvailable: premAvailable ?? this.premAvailable,
      premStatementDescriptor:
          premStatementDescriptor ?? this.premStatementDescriptor,
      premNumberTable: premNumberTable ?? this.premNumberTable,
      premState: premState ?? this.premState,
      premCity: premCity ?? this.premCity,
      premImageUrl: premImageUrl,
      premPickUp: premPickUp ?? this.premPickUp,
      premPickUpCost: premPickUpCost ?? this.premPickUpCost,
      premPickUpMandatory: premPickUpMandatory ?? this.premPickUpMandatory,
      horarios: horarios ?? this.horarios,
    );
  }

  /// Builds the `premises-update` body: every field plus the password fields.
  /// `password` is `''` when the user left the password unchanged, so
  /// `user_password_chance` is true only when a new password was typed.
  Map<String, dynamic> toUpdateJson({
    required int userId,
    required String password,
  }) {
    return {
      'user_id': userId,
      'prem_id': premId,
      'prem_name': premName,
      'user_email': userEmail,
      'user_password_chance': password.isNotEmpty,
      'user_password': password,
      'prem_latitud': premLatitud,
      'prem_longitud': premLongitud,
      'prem_address': premAddress,
      'prem_available': premAvailable,
      'prem_statement_descriptor': premStatementDescriptor,
      'prem_number_table': premNumberTable,
      'prem_state': premState,
      'prem_city': premCity,
      'prem_pick_up': premPickUp,
      'prem_pick_up_cost': premPickUpCost,
      'prem_pick_up_mandatory': premPickUpMandatory,
      'horarios': horarios.map((h) => h.toJson()).toList(),
    };
  }
}
