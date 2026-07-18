import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/tips/data/tips_repository.dart';
import 'package:ds_clickeat_web_admin/features/tips/models/tip.dart';

class TipsState {
  final List<Tip> tips;
  final bool loading;
  final String? error;

  const TipsState({this.tips = const [], this.loading = false, this.error});

  TipsState copyWith({List<Tip>? tips, bool? loading, String? error}) =>
      TipsState(
        tips: tips ?? this.tips,
        loading: loading ?? this.loading,
        error: error,
      );

  int get availableCount => tips.where((t) => t.tipsAvailable).length;
}

final tipsControllerProvider = StateNotifierProvider<TipsController, TipsState>(
  (ref) {
    return TipsController(ref);
  },
);

class TipsController extends StateNotifier<TipsState> {
  TipsController(this._ref) : super(const TipsState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref.read(tipsRepositoryProvider).getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort((a, b) => a.tipsPercentage.compareTo(b.tipsPercentage));
      state = TipsState(tips: list, loading: false);
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

  Future<String?> createTip(int premId, int percentage) => _mutate(
    premId,
    () => _ref
        .read(tipsRepositoryProvider)
        .createTip(premId: premId, percentage: percentage),
  );

  Future<String?> updateTip(
    int premId,
    int tipsId,
    int percentage,
    bool available,
  ) => _mutateLocal(
    premId,
    () => _ref
        .read(tipsRepositoryProvider)
        .updateTip(
          premId: premId,
          tipsId: tipsId,
          percentage: percentage,
          available: available,
        ),
    () => _patchTip(tipsId, percentage, available),
  );

  Future<String?> deleteTip(int premId, int tipsId) => _mutateLocal(
    premId,
    () => _ref
        .read(tipsRepositoryProvider)
        .deleteTip(premId: premId, tipsId: tipsId),
    () => state = state.copyWith(
      tips: [
        for (final tip in state.tips)
          if (tip.tipsId != tipsId) tip,
      ],
    ),
  );

  /// Flips a tip's availability, persisting the change via update.
  Future<String?> toggleAvailable(int premId, Tip tip) =>
      updateTip(premId, tip.tipsId, tip.tipsPercentage, !tip.tipsAvailable);

  void _patchTip(int tipsId, int percentage, bool available) {
    final tips = [
      for (final tip in state.tips)
        if (tip.tipsId == tipsId)
          tip.copyWith(tipsPercentage: percentage, tipsAvailable: available)
        else
          tip,
    ]..sort((a, b) => a.tipsPercentage.compareTo(b.tipsPercentage));
    state = state.copyWith(tips: tips);
  }
}
