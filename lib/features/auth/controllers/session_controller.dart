import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/auth/data/auth_repository.dart';
import 'package:ds_clickeat_web_admin/features/auth/models/session.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, Session?>((ref) {
  return SessionController(ref);
});

class SessionController extends StateNotifier<Session?> {
  SessionController(this._ref) : super(null);
  final Ref _ref;

  Future<void> bootstrap() async {
    final s = await _ref.read(authRepositoryProvider).readPersistedSession();
    state = s;
  }

  void set(Session s) {
    state = s;
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = null;
  }
}
