/// A preparation area (área de preparación) scoped to a premise.
///
/// Backend shape (`products/category-preparation/<premId>` → `preparation_area`):
/// `{ prep_id, prep_name, prod_count }`.
class PreparationArea {
  final int prepId;
  final String prepName;

  /// Number of products linked to this preparation area.
  final int prodCount;

  const PreparationArea({
    required this.prepId,
    required this.prepName,
    required this.prodCount,
  });

  factory PreparationArea.fromJson(Map<String, dynamic> json) {
    return PreparationArea(
      prepId: (json['prep_id'] as num?)?.toInt() ?? 0,
      prepName: (json['prep_name'] as String?)?.trim() ?? '',
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
    );
  }
}
