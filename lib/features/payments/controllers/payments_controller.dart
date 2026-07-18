import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/payments/data/payments_repository.dart';
import 'package:ds_clickeat_web_admin/features/payments/models/payment_method.dart';

class PaymentsState {
  final List<PaymentMethod> methods;
  final bool loading;
  final String? error;

  const PaymentsState({
    this.methods = const [],
    this.loading = false,
    this.error,
  });

  PaymentsState copyWith({
    List<PaymentMethod>? methods,
    bool? loading,
    String? error,
  }) => PaymentsState(
    methods: methods ?? this.methods,
    loading: loading ?? this.loading,
    error: error,
  );

  int get availableCount => methods.where((m) => m.paymAvailable).length;
}

final paymentsControllerProvider =
    StateNotifierProvider<PaymentsController, PaymentsState>((ref) {
      return PaymentsController(ref);
    });

class PaymentsController extends StateNotifier<PaymentsState> {
  PaymentsController(this._ref) : super(const PaymentsState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(paymentsRepositoryProvider)
          .getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort(
        (a, b) => a.paymName.toLowerCase().compareTo(b.paymName.toLowerCase()),
      );
      state = PaymentsState(methods: list, loading: false);
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

  Future<String?> createPayment(int premId, String name, bool available) =>
      _mutate(
        premId,
        () => _ref
            .read(paymentsRepositoryProvider)
            .createPayment(premId: premId, name: name, available: available),
      );

  Future<String?> updatePayment(
    int premId,
    int paymId,
    String name,
    bool available,
  ) => _mutateLocal(
    premId,
    () => _ref
        .read(paymentsRepositoryProvider)
        .updatePayment(
          premId: premId,
          paymId: paymId,
          name: name,
          available: available,
        ),
    () => _patchPayment(paymId, name, available),
  );

  Future<String?> deletePayment(int premId, int paymId) => _mutateLocal(
    premId,
    () => _ref
        .read(paymentsRepositoryProvider)
        .deletePayment(premId: premId, paymId: paymId),
    () => state = state.copyWith(
      methods: [
        for (final method in state.methods)
          if (method.paymId != paymId) method,
      ],
    ),
  );

  /// Flips a method's availability, persisting the change via update.
  Future<String?> toggleAvailable(int premId, PaymentMethod method) =>
      updatePayment(
        premId,
        method.paymId,
        method.paymName,
        !method.paymAvailable,
      );

  void _patchPayment(int paymId, String name, bool available) {
    final methods =
        [
          for (final method in state.methods)
            if (method.paymId == paymId)
              method.copyWith(paymName: name, paymAvailable: available)
            else
              method,
        ]..sort(
          (a, b) =>
              a.paymName.toLowerCase().compareTo(b.paymName.toLowerCase()),
        );
    state = state.copyWith(methods: methods);
  }
}
