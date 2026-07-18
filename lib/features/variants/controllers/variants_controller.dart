import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/variants/data/variants_repository.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_additional.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_option.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_size.dart';

class VariantsState {
  final List<ProductSize> sizes;
  final List<ProductOption> options;
  final List<ProductAdditional> additionals;
  final bool loading;
  final String? error;

  const VariantsState({
    this.sizes = const [],
    this.options = const [],
    this.additionals = const [],
    this.loading = false,
    this.error,
  });

  VariantsState copyWith({
    List<ProductSize>? sizes,
    List<ProductOption>? options,
    List<ProductAdditional>? additionals,
    bool? loading,
    String? error,
  }) => VariantsState(
    sizes: sizes ?? this.sizes,
    options: options ?? this.options,
    additionals: additionals ?? this.additionals,
    loading: loading ?? this.loading,
    error: error,
  );
}

final variantsControllerProvider =
    StateNotifierProvider<VariantsController, VariantsState>((ref) {
      return VariantsController(ref);
    });

class VariantsController extends StateNotifier<VariantsState> {
  VariantsController(this._ref) : super(const VariantsState());
  final Ref _ref;

  int? _premId;
  int _loadToken = 0;

  VariantsRepository get _repo => _ref.read(variantsRepositoryProvider);

  Future<void> load(int premId) async {
    _premId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _repo.getByPremise(premId);
      if (token != _loadToken || premId != _premId) return;

      final sizes = [...data.sizes]
        ..sort((a, b) => a.prodsName.compareTo(b.prodsName));
      final options = [...data.options]
        ..sort((a, b) => a.prodoName.compareTo(b.prodoName));
      final additionals = [...data.additionals]
        ..sort((a, b) => a.prodaName.compareTo(b.prodaName));

      state = VariantsState(
        sizes: sizes,
        options: options,
        additionals: additionals,
        loading: false,
      );
    } catch (e) {
      if (token != _loadToken || premId != _premId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  // ===== Size CRUD =========================================================
  // Each action returns `null` on success or an error message string. On
  // success the catalogs are reloaded so the lists stay in sync with the
  // backend.

  Future<String?> createSize(String name) =>
      _run(() => _repo.createSize(premId: _premId!, name: name));

  Future<String?> updateSize(int prodsId, String name, bool available) =>
      _runLocal(
        () => _repo.updateSize(
          premId: _premId!,
          prodsId: prodsId,
          name: name,
          available: available,
        ),
        () => _patchSize(prodsId, name, available),
      );

  Future<String?> deleteSize(int prodsId) => _runLocal(
    () => _repo.deleteSize(premId: _premId!, prodsId: prodsId),
    () => state = state.copyWith(
      sizes: [
        for (final size in state.sizes)
          if (size.prodsId != prodsId) size,
      ],
    ),
  );

  // ===== Option CRUD =======================================================

  Future<String?> createOption(String name) =>
      _run(() => _repo.createOption(premId: _premId!, name: name));

  Future<String?> updateOption(int prodoId, String name, bool available) =>
      _runLocal(
        () => _repo.updateOption(
          premId: _premId!,
          prodoId: prodoId,
          name: name,
          available: available,
        ),
        () => _patchOption(prodoId, name, available),
      );

  Future<String?> deleteOption(int prodoId) => _runLocal(
    () => _repo.deleteOption(premId: _premId!, prodoId: prodoId),
    () => state = state.copyWith(
      options: [
        for (final option in state.options)
          if (option.prodoId != prodoId) option,
      ],
    ),
  );

  // ===== Add-on CRUD =======================================================

  Future<String?> createAdditional(String name, String price) => _run(
    () => _repo.createAdditional(premId: _premId!, name: name, price: price),
  );

  Future<String?> updateAdditional(
    int prodaId,
    String name,
    String price,
    bool available,
  ) => _runLocal(
    () => _repo.updateAdditional(
      premId: _premId!,
      prodaId: prodaId,
      name: name,
      price: price,
      available: available,
    ),
    () => _patchAdditional(prodaId, name, price, available),
  );

  Future<String?> deleteAdditional(int prodaId) => _runLocal(
    () => _repo.deleteAdditional(premId: _premId!, prodaId: prodaId),
    () => state = state.copyWith(
      additionals: [
        for (final additional in state.additionals)
          if (additional.prodaId != prodaId) additional,
      ],
    ),
  );

  Future<String?> _run(Future<void> Function() action) async {
    if (_premId == null) return 'No hay sucursal seleccionada.';
    try {
      await action();
      await load(_premId!);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _runLocal(
    Future<void> Function() action,
    void Function() applyLocal,
  ) async {
    if (_premId == null) return 'No hay sucursal seleccionada.';
    final premId = _premId;
    try {
      await action();
      if (premId == _premId) applyLocal();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void _patchSize(int prodsId, String name, bool available) {
    final sizes = [
      for (final size in state.sizes)
        if (size.prodsId == prodsId)
          ProductSize(
            prodsId: size.prodsId,
            prodsName: name,
            prodsAvailable: available,
            prodCount: size.prodCount,
          )
        else
          size,
    ]..sort((a, b) => a.prodsName.compareTo(b.prodsName));
    state = state.copyWith(sizes: sizes);
  }

  void _patchOption(int prodoId, String name, bool available) {
    final options = [
      for (final option in state.options)
        if (option.prodoId == prodoId)
          ProductOption(
            prodoId: option.prodoId,
            prodoName: name,
            prodoAvailable: available,
            prodCount: option.prodCount,
          )
        else
          option,
    ]..sort((a, b) => a.prodoName.compareTo(b.prodoName));
    state = state.copyWith(options: options);
  }

  void _patchAdditional(
    int prodaId,
    String name,
    String price,
    bool available,
  ) {
    final additionals = [
      for (final additional in state.additionals)
        if (additional.prodaId == prodaId)
          ProductAdditional(
            prodaId: additional.prodaId,
            prodaName: name,
            prodaAvailable: available,
            prodaPrice: price,
            prodCount: additional.prodCount,
          )
        else
          additional,
    ]..sort((a, b) => a.prodaName.compareTo(b.prodaName));
    state = state.copyWith(additionals: additionals);
  }
}
