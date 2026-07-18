import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/features/products/data/products_repository.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product.dart';

class ProductsState {
  final List<Product> products;
  final bool loading;
  final String? error;

  const ProductsState({
    this.products = const [],
    this.loading = false,
    this.error,
  });

  ProductsState copyWith({
    List<Product>? products,
    bool? loading,
    String? error,
  }) => ProductsState(
    products: products ?? this.products,
    loading: loading ?? this.loading,
    error: error,
  );
}

final productsControllerProvider =
    StateNotifierProvider<ProductsController, ProductsState>((ref) {
      return ProductsController(ref);
    });

class ProductsController extends StateNotifier<ProductsState> {
  ProductsController(this._ref) : super(const ProductsState());
  final Ref _ref;
  int? _activePremId;
  int _loadToken = 0;

  Future<void> load(int premId) async {
    _activePremId = premId;
    final token = ++_loadToken;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _ref
          .read(productsRepositoryProvider)
          .getByPremise(premId);
      if (token != _loadToken || premId != _activePremId) return;
      // Backend returns products in insertion order (new ones land last). Sort
      // by `prod_order`, then name, so the list follows the configured order
      // and a freshly created product slots into its place.
      list.sort((a, b) {
        final byOrder = a.prodOrder.compareTo(b.prodOrder);
        return byOrder != 0
            ? byOrder
            : a.prodName.toLowerCase().compareTo(b.prodName.toLowerCase());
      });
      state = ProductsState(products: list, loading: false);
    } catch (e) {
      if (token != _loadToken || premId != _activePremId) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Deletes [prodId] and reloads the list on success. Returns whether it
  /// succeeded.
  Future<bool> delete(int premId, int prodId) async {
    try {
      final ok = await _ref
          .read(productsRepositoryProvider)
          .deleteProduct(premId: premId, prodId: prodId);
      if (ok && premId == _activePremId) {
        state = state.copyWith(
          products: [
            for (final product in state.products)
              if (product.prodId != prodId) product,
          ],
        );
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
