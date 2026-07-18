import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/inventory/models/inventory_product.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(dioProvider));
});

class InventoryRepository {
  InventoryRepository(this._dio);
  final Dio _dio;

  /// GET `products/inventory/<premId>` — products with their per-variant stock
  /// collection (initial, sold, remaining) for the inventory screen.
  Future<List<InventoryProduct>> getByPremise(int premId) async {
    final res = await _dio.get('products/inventory/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) =>
              InventoryProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// POST products/update-stock — updates a single variant's stock and
  /// availability. Success is `state == 1`. The auth token is injected by the
  /// interceptor.
  Future<bool> updateStock({
    required int premId,
    required int prodId,
    required int prodsId,
    required int prodoId,
    required int stock,
    required bool available,
  }) async {
    final res = await _dio.post('products/update-stock', data: {
      'prem_id': premId,
      'prod_id': prodId,
      'prods_id': prodsId,
      'prodo_id': prodoId,
      'prod_stock': stock,
      'prod_available': available,
    });
    final data = res.data;
    return data is Map && data['state'] == 1;
  }
}
