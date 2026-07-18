import 'package:ds_clickeat_web_admin/features/branches/models/bool_parse.dart';

/// One day's opening hours for a branch, from the `horarios` array of
/// `premises-detail`. Hours are kept as the backend's 12-hour strings
/// (e.g. `"10:00 AM"`).
class BranchSchedule {
  final String premDay;
  final String premHourOpen;
  final String premHourClose;
  final bool premAvailableDays;

  const BranchSchedule({
    required this.premDay,
    required this.premHourOpen,
    required this.premHourClose,
    required this.premAvailableDays,
  });

  factory BranchSchedule.fromJson(Map<String, dynamic> j) {
    return BranchSchedule(
      premDay: (j['prem_day'] ?? '').toString(),
      premHourOpen: (j['prem_hour_open'] ?? '').toString(),
      premHourClose: (j['prem_hour_close'] ?? '').toString(),
      premAvailableDays: parseBool(j['prem_available_days']),
    );
  }

  BranchSchedule copyWith({
    String? premHourOpen,
    String? premHourClose,
    bool? premAvailableDays,
  }) {
    return BranchSchedule(
      premDay: premDay,
      premHourOpen: premHourOpen ?? this.premHourOpen,
      premHourClose: premHourClose ?? this.premHourClose,
      premAvailableDays: premAvailableDays ?? this.premAvailableDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'prem_day': premDay,
        'prem_hour_open': premHourOpen,
        'prem_hour_close': premHourClose,
        'prem_available_days': premAvailableDays,
      };

  /// Monday-first index used to order the days for display; unknown days
  /// sort last.
  int get weekdayOrder {
    const order = {
      'lunes': 0,
      'martes': 1,
      'miércoles': 2,
      'miercoles': 2,
      'jueves': 3,
      'viernes': 4,
      'sábado': 5,
      'sabado': 5,
      'domingo': 6,
    };
    return order[premDay.toLowerCase().trim()] ?? 99;
  }
}
