import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/tables/data/tables_repository.dart';
import 'package:ds_clickeat_web_admin/features/tables/models/table_section.dart';

class TablesState {
  final List<TableSection> sections;
  final bool loading;
  final String? error;

  const TablesState({
    this.sections = const [],
    this.loading = false,
    this.error,
  });

  TablesState copyWith({
    List<TableSection>? sections,
    bool? loading,
    String? error,
  }) => TablesState(
    sections: sections ?? this.sections,
    loading: loading ?? this.loading,
    error: error,
  );

  int get tableCount => sections.fold(0, (sum, s) => sum + s.tableIds.length);
}

final tablesControllerProvider =
    StateNotifierProvider<TablesController, TablesState>((ref) {
      return TablesController(ref);
    });

class TablesController extends StateNotifier<TablesState> {
  TablesController(this._ref) : super(const TablesState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(tablesRepositoryProvider)
          .getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      state = TablesState(sections: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Runs [action], reloads the list on success, and returns a user-facing
  /// error message (or null on success). Shared by every mutation below so the
  /// UI only has to surface the returned string.
  Future<String?> _mutate(int premId, Future<void> Function() action) async {
    try {
      await action();
      await load(premId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _mutateLocal(
    int premId,
    Future<void> Function() action,
    void Function() applyLocal,
  ) async {
    try {
      await action();
      if (premId == _activePremId) applyLocal();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> createSection(int premId, String name) => _mutate(
    premId,
    () => _ref
        .read(tablesRepositoryProvider)
        .createSection(premId: premId, sectName: name),
  );

  Future<String?> updateSection(int premId, int sectId, String name) =>
      _mutateLocal(
        premId,
        () => _ref
            .read(tablesRepositoryProvider)
            .updateSection(premId: premId, sectId: sectId, sectName: name),
        () => _patchSectionName(sectId, name),
      );

  Future<String?> deleteSection(int premId, int sectId) => _mutateLocal(
    premId,
    () => _ref
        .read(tablesRepositoryProvider)
        .deleteSection(premId: premId, sectId: sectId),
    () => state = state.copyWith(
      sections: [
        for (final section in state.sections)
          if (section.sectId != sectId) section,
      ],
    ),
  );

  Future<String?> addTable(int premId, int sectId, int tablId) => _mutateLocal(
    premId,
    () => _ref
        .read(tablesRepositoryProvider)
        .addTable(premId: premId, sectId: sectId, tablId: tablId),
    () => _patchTable(sectId, tablId, add: true),
  );

  Future<String?> removeTable(int premId, int sectId, int tablId) =>
      _mutateLocal(
        premId,
        () => _ref
            .read(tablesRepositoryProvider)
            .removeTable(premId: premId, sectId: sectId, tablId: tablId),
        () => _patchTable(sectId, tablId, add: false),
      );

  void _patchSectionName(int sectId, String name) {
    state = state.copyWith(
      sections: [
        for (final section in state.sections)
          if (section.sectId == sectId)
            TableSection(
              sectId: section.sectId,
              sectName: name,
              tableIds: section.tableIds,
            )
          else
            section,
      ],
    );
  }

  void _patchTable(int sectId, int tablId, {required bool add}) {
    state = state.copyWith(
      sections: [
        for (final section in state.sections)
          if (section.sectId == sectId)
            TableSection(
              sectId: section.sectId,
              sectName: section.sectName,
              tableIds: _updatedTableIds(section.tableIds, tablId, add: add),
            )
          else
            section,
      ],
    );
  }

  List<int> _updatedTableIds(
    List<int> current,
    int tablId, {
    required bool add,
  }) {
    final ids = {...current};
    if (add) {
      ids.add(tablId);
    } else {
      ids.remove(tablId);
    }
    return ids.toList()..sort();
  }
}
