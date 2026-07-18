import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/premises/data/premises_repository.dart';
import 'package:ds_clickeat_web_admin/features/premises/models/premise.dart';
import 'package:ds_clickeat_web_admin/features/reports/data/reports_repository.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';

class DailyReportState {
  final List<Premise> premises;
  final List<OrderTypeOption> orderTypes;
  final Set<int> selectedPremIds;
  final Set<String> selectedOrderTypes;
  final DailyReportData? data;
  final bool loadingParams;
  final bool loadingData;
  final bool hasQueried;
  final String? error;

  const DailyReportState({
    this.premises = const [],
    this.orderTypes = const [],
    this.selectedPremIds = const {},
    this.selectedOrderTypes = const {},
    this.data,
    this.loadingParams = false,
    this.loadingData = false,
    this.hasQueried = false,
    this.error,
  });

  DailyReportState copyWith({
    List<Premise>? premises,
    List<OrderTypeOption>? orderTypes,
    Set<int>? selectedPremIds,
    Set<String>? selectedOrderTypes,
    DailyReportData? data,
    bool? loadingParams,
    bool? loadingData,
    bool? hasQueried,
    String? error,
  }) {
    return DailyReportState(
      premises: premises ?? this.premises,
      orderTypes: orderTypes ?? this.orderTypes,
      selectedPremIds: selectedPremIds ?? this.selectedPremIds,
      selectedOrderTypes: selectedOrderTypes ?? this.selectedOrderTypes,
      data: data ?? this.data,
      loadingParams: loadingParams ?? this.loadingParams,
      loadingData: loadingData ?? this.loadingData,
      hasQueried: hasQueried ?? this.hasQueried,
      error: error,
    );
  }
}

final dailyReportControllerProvider =
    StateNotifierProvider<DailyReportController, DailyReportState>((ref) {
  return DailyReportController(ref);
});

class DailyReportController extends StateNotifier<DailyReportState> {
  DailyReportController(this._ref) : super(const DailyReportState());
  final Ref _ref;
  int _loadToken = 0;

  /// Loads the two filter parameter sources (premises, order types) and
  /// defaults both selections to "all", but does NOT fetch the report —
  /// the user must pick filters and press "Consultar" ([search]) first.
  /// Safe to call more than once; it no-ops once the parameters are already
  /// loaded.
  Future<void> loadParameters() async {
    if (state.premises.isNotEmpty || state.loadingParams) return;
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return;

    state = state.copyWith(loadingParams: true, error: null);
    try {
      final results = await Future.wait([
        _ref.read(premisesRepositoryProvider).getEssential(session.userId),
        _ref.read(reportsRepositoryProvider).getOrderTypes(),
      ]);
      final premises = results[0] as List<Premise>;
      final orderTypes = results[1] as List<OrderTypeOption>;
      state = state.copyWith(
        premises: premises,
        orderTypes: orderTypes,
        selectedPremIds: {for (final p in premises) p.premId},
        selectedOrderTypes: {for (final o in orderTypes) o.ordeType},
        loadingParams: false,
      );
    } catch (e) {
      state = state.copyWith(loadingParams: false, error: e.toString());
    }
  }

  /// Stages the premise selection without querying — the report only
  /// refreshes when the user presses "Consultar" ([search]).
  void applyPremises(Set<int> ids) {
    state = state.copyWith(selectedPremIds: ids);
  }

  /// Stages the order-type selection without querying — the report only
  /// refreshes when the user presses "Consultar" ([search]).
  void applyOrderTypes(Set<String> types) {
    state = state.copyWith(selectedOrderTypes: types);
  }

  /// Runs the report query with the currently staged filters. This is the
  /// only way [DailyReportData] gets (re)loaded — entering the screen or
  /// changing a filter chip no longer triggers a fetch on its own.
  Future<void> search() async {
    state = state.copyWith(hasQueried: true);
    await loadData();
  }

  Future<void> loadData() async {
    final token = ++_loadToken;
    state = state.copyWith(loadingData: true, error: null);
    try {
      final data = await _ref.read(reportsRepositoryProvider).getDaily(
            premIds: state.selectedPremIds.toList(),
            orderTypes: state.selectedOrderTypes.toList(),
          );
      if (token != _loadToken) return;
      state = state.copyWith(data: data, loadingData: false);
    } catch (e) {
      if (token != _loadToken) return;
      state = state.copyWith(loadingData: false, error: e.toString());
    }
  }
}
