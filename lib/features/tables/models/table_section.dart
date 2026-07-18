/// A "zone" (sección/sucursal area) plus the ids of the tables linked to it.
///
/// The backend (`premises/section/<premId>`) returns one flat row per
/// section×table link — `{ sect_id, sect_name, tabl_id }` — so a section with
/// several tables appears as several rows, and a section with no tables appears
/// once with a null `tabl_id`. [fromBackendList] regroups those rows by section.
class TableSection {
  final int sectId;
  final String sectName;
  final List<int> tableIds;

  const TableSection({
    required this.sectId,
    required this.sectName,
    this.tableIds = const [],
  });

  /// Groups the flat link rows into one [TableSection] per `sect_id`, with the
  /// table ids collected (de-duplicated and sorted) under each one. Sections are
  /// returned ordered by `sect_id` so the layout is stable across reloads.
  static List<TableSection> fromBackendList(List<dynamic> rows) {
    final byId = <int, String>{};
    final tables = <int, Set<int>>{};

    for (final raw in rows) {
      if (raw is! Map) continue;
      final j = Map<String, dynamic>.from(raw);
      final sectId = (j['sect_id'] as num?)?.toInt();
      if (sectId == null) continue;
      byId[sectId] = (j['sect_name'] ?? '').toString();
      final tablId = (j['tabl_id'] as num?)?.toInt();
      final set = tables.putIfAbsent(sectId, () => <int>{});
      if (tablId != null && tablId != 0) set.add(tablId);
    }

    final sections = byId.entries.map((e) {
      final ids = (tables[e.key] ?? const <int>{}).toList()..sort();
      return TableSection(sectId: e.key, sectName: e.value, tableIds: ids);
    }).toList()
      ..sort((a, b) => a.sectId.compareTo(b.sectId));

    return sections;
  }
}
