import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/inventory/data/inventory_repository.dart';
import 'package:ds_clickeat_web_admin/features/inventory/models/inventory_product.dart';

class InventoryState {
  final List<InventoryProduct> products;
  final bool loading;
  final String? error;

  const InventoryState({
    this.products = const [],
    this.loading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryProduct>? products,
    bool? loading,
    String? error,
  }) => InventoryState(
    products: products ?? this.products,
    loading: loading ?? this.loading,
    error: error,
  );
}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, InventoryState>((ref) {
      return InventoryController(ref);
    });

class InventoryController extends StateNotifier<InventoryState> {
  InventoryController(this._ref) : super(const InventoryState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(inventoryRepositoryProvider)
          .getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = InventoryState(products: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Persists a single variant's stock/availability, then reloads the list on
  /// success. Returns whether it succeeded.
  Future<bool> updateStock({
    required int premId,
    required int prodId,
    required int prodsId,
    required int prodoId,
    required int stock,
    required bool available,
  }) async {
    try {
      final ok = await _ref
          .read(inventoryRepositoryProvider)
          .updateStock(
            premId: premId,
            prodId: prodId,
            prodsId: prodsId,
            prodoId: prodoId,
            stock: stock,
            available: available,
          );
      if (ok && premId == _activePremId) {
        _patchCollect(
          prodId: prodId,
          prodsId: prodsId,
          prodoId: prodoId,
          stock: stock,
          available: available,
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  void _patchCollect({
    required int prodId,
    required int prodsId,
    required int prodoId,
    required int stock,
    required bool available,
  }) {
    state = state.copyWith(
      products: [
        for (final product in state.products)
          if (product.prodId == prodId)
            InventoryProduct(
              prodId: product.prodId,
              name: product.name,
              category: product.category,
              imageUrl: product.imageUrl,
              sizes: product.sizes,
              options: product.options,
              collect: [
                for (final collect in product.collect)
                  if (collect.prodsId == prodsId && collect.prodoId == prodoId)
                    InventoryCollect(
                      prodsId: collect.prodsId,
                      prodoId: collect.prodoId,
                      stock: stock,
                      stockLast: collect.stockLast,
                      sell: collect.sell,
                      price: collect.price,
                      available: available,
                    )
                  else
                    collect,
              ],
            )
          else
            product,
      ],
    );
  }
}
