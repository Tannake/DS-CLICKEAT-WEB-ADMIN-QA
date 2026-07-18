import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/data/auth_repository.dart';

class LoginState {
  final bool loading;
  final String? error;
  const LoginState({this.loading = false, this.error});

  LoginState copyWith({bool? loading, String? error}) =>
      LoginState(loading: loading ?? this.loading, error: error);
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
  return LoginController(ref);
});

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._ref) : super(const LoginState());
  final Ref _ref;

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      state = state.copyWith(loading: false, error: null);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'No se pudo iniciar sesión',
      );
      return false;
    }
  }
}
