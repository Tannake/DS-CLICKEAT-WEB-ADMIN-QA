import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/reasons/data/reasons_repository.dart';
import 'package:ds_clickeat_web_admin/features/reasons/models/cancel_reason.dart';

class ReasonsState {
  final List<CancelReason> reasons;
  final bool loading;
  final String? error;

  const ReasonsState({
    this.reasons = const [],
    this.loading = false,
    this.error,
  });

  ReasonsState copyWith({
    List<CancelReason>? reasons,
    bool? loading,
    String? error,
  }) => ReasonsState(
    reasons: reasons ?? this.reasons,
    loading: loading ?? this.loading,
    error: error,
  );

  int get availableCount => reasons.where((r) => r.reasAvailable).length;
}

final reasonsControllerProvider =
    StateNotifierProvider<ReasonsController, ReasonsState>((ref) {
      return ReasonsController(ref);
    });

class ReasonsController extends StateNotifier<ReasonsState> {
  ReasonsController(this._ref) : super(const ReasonsState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(reasonsRepositoryProvider)
          .getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort(
        (a, b) => a.reasName.toLowerCase().compareTo(b.reasName.toLowerCase()),
      );
      state = ReasonsState(reasons: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Runs [action], reloads the list on success, and returns a user-facing
  /// error message (or null on success).
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

  Future<String?> createReason(int premId, String name) => _mutate(
    premId,
    () => _ref
        .read(reasonsRepositoryProvider)
        .createReason(premId: premId, name: name),
  );

  Future<String?> updateReason(
    int premId,
    int reasId,
    String name,
    bool available,
  ) => _mutateLocal(
    premId,
    () => _ref
        .read(reasonsRepositoryProvider)
        .updateReason(
          premId: premId,
          reasId: reasId,
          name: name,
          available: available,
        ),
    () => _patchReason(reasId, name, available),
  );

  Future<String?> deleteReason(int premId, int reasId) => _mutateLocal(
    premId,
    () => _ref
        .read(reasonsRepositoryProvider)
        .deleteReason(premId: premId, reasId: reasId),
    () => state = state.copyWith(
      reasons: [
        for (final reason in state.reasons)
          if (reason.reasId != reasId) reason,
      ],
    ),
  );

  /// Flips a reason's availability, persisting the change via update.
  Future<String?> toggleAvailable(int premId, CancelReason reason) =>
      updateReason(
        premId,
        reason.reasId,
        reason.reasName,
        !reason.reasAvailable,
      );

  void _patchReason(int reasId, String name, bool available) {
    final reasons =
        [
          for (final reason in state.reasons)
            if (reason.reasId == reasId)
              reason.copyWith(reasName: name, reasAvailable: available)
            else
              reason,
        ]..sort(
          (a, b) =>
              a.reasName.toLowerCase().compareTo(b.reasName.toLowerCase()),
        );
    state = state.copyWith(reasons: reasons);
  }
}
