import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/premises/data/premises_repository.dart';
import 'package:ds_clickeat_web_admin/features/premises/models/premise.dart';

class PremisesState {
  final List<Premise> premises;
  final int? selectedPremId;
  final bool loading;

  const PremisesState({
    this.premises = const [],
    this.selectedPremId,
    this.loading = false,
  });

  PremisesState copyWith({
    List<Premise>? premises,
    int? selectedPremId,
    bool? loading,
  }) =>
      PremisesState(
        premises: premises ?? this.premises,
        selectedPremId: selectedPremId ?? this.selectedPremId,
        loading: loading ?? this.loading,
      );

  Premise? get selected {
    if (selectedPremId == null) return null;
    try {
      return premises.firstWhere((p) => p.premId == selectedPremId);
    } catch (_) {
      return null;
    }
  }
}

final premisesControllerProvider =
    StateNotifierProvider<PremisesController, PremisesState>((ref) {
  return PremisesController(ref);
});

class PremisesController extends StateNotifier<PremisesState> {
  PremisesController(this._ref) : super(const PremisesState());
  final Ref _ref;

  Future<void> load() async {
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return;

    state = state.copyWith(loading: true);
    try {
      final list = await _ref
          .read(premisesRepositoryProvider)
          .getEssential(session.userId);
      final defaultId = list.isNotEmpty ? list.first.premId : null;
      state = PremisesState(
        premises: list,
        selectedPremId: state.selectedPremId ?? defaultId,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void select(int premId) {
    state = state.copyWith(selectedPremId: premId);
  }
}
