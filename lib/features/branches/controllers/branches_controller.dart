import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';
import 'package:ds_clickeat_web_admin/features/branches/data/branches_repository.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_detail.dart';
import 'package:ds_clickeat_web_admin/features/branches/models/branch_summary.dart';

class BranchesState {
  final List<BranchSummary> branches;
  final bool loading;
  final String? error;

  const BranchesState({
    this.branches = const [],
    this.loading = false,
    this.error,
  });

  BranchesState copyWith({
    List<BranchSummary>? branches,
    bool? loading,
    String? error,
  }) => BranchesState(
    branches: branches ?? this.branches,
    loading: loading ?? this.loading,
    error: error,
  );

  int get availableCount => branches.where((b) => b.premAvailable).length;
}

final branchesControllerProvider =
    StateNotifierProvider<BranchesController, BranchesState>((ref) {
      return BranchesController(ref);
    });

class BranchesController extends StateNotifier<BranchesState> {
  BranchesController(this._ref) : super(const BranchesState());
  final Ref _ref;
  int _loadToken = 0;

  /// Loads the branch cards for the signed-in user. The screen is user-scoped
  /// (not premise-scoped), so it reads the id straight from the session.
  Future<void> load() async {
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(branchesRepositoryProvider)
          .getByUser(session.userId);
      if (token != _loadToken) return;
      list.sort(
        (a, b) =>
            a.premName.toLowerCase().compareTo(b.premName.toLowerCase()),
      );
      state = BranchesState(branches: list, loading: false);
    } catch (e) {
      if (token != _loadToken) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Fetches the full editable shape for [premId]. Returns null on failure
  /// (the page surfaces the message separately).
  Future<BranchDetail?> fetchDetail(int premId) async {
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return null;
    return _ref.read(branchesRepositoryProvider).getDetail(
      session.userId,
      premId,
    );
  }

  /// Persists an edited branch, reloads the list on success, and returns a
  /// user-facing error message (or null on success).
  Future<String?> save(BranchDetail detail, String password) async {
    final session = _ref.read(sessionControllerProvider);
    if (session == null) return 'Sesión expirada.';
    try {
      await _ref.read(branchesRepositoryProvider).update(
        userId: session.userId,
        detail: detail,
        password: password,
      );
      await load();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
