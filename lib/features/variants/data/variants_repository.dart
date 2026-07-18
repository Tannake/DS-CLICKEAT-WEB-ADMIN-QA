import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_additional.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_option.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_size.dart';

final variantsRepositoryProvider = Provider<VariantsRepository>((ref) {
  return VariantsRepository(ref.read(dioProvider));
});

/// Combined payload returned by `products/variant/<premId>`: the size, option
/// and add-on catalogs of a premise.
class VariantsData {
  final List<ProductSize> sizes;
  final List<ProductOption> options;
  final List<ProductAdditional> additionals;

  const VariantsData({
    this.sizes = const [],
    this.options = const [],
    this.additionals = const [],
  });
}

class VariantsRepository {
  VariantsRepository(this._dio);
  final Dio _dio;

  /// Fetches the size/option/add-on catalogs for [premId]. The auth token is
  /// injected by the Dio interceptor. Returns empty lists on a non-success
  /// envelope.
  Future<VariantsData> getByPremise(int premId) async {
    final res = await _dio.get('products/variant/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      final result = Map<String, dynamic>.from(data['result'] as Map);
      final sizes = (result['product_size'] as List? ?? const [])
          .map((e) => ProductSize.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final options = (result['product_option'] as List? ?? const [])
          .map(
            (e) => ProductOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final additionals = (result['product_additional'] as List? ?? const [])
          .map(
            (e) =>
                ProductAdditional.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      return VariantsData(
        sizes: sizes,
        options: options,
        additionals: additionals,
      );
    }
    return const VariantsData();
  }

  // ===== Size CRUD (products/size-crud) ====================================
  // `prods_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createSize({
    required int premId,
    required String name,
  }) async {
    await _crud('products/size-crud', {
      'prem_id': premId,
      'prods_type': 'I',
      'prods_name': name,
    });
  }

  Future<void> updateSize({
    required int premId,
    required int prodsId,
    required String name,
    required bool available,
  }) async {
    await _crud('products/size-crud', {
      'prem_id': premId,
      'prods_type': 'U',
      'prods_id': prodsId,
      'prods_name': name,
      'prods_available': available,
    });
  }

  Future<void> deleteSize({
    required int premId,
    required int prodsId,
  }) async {
    await _crud('products/size-crud', {
      'prem_id': premId,
      'prods_type': 'D',
      'prods_id': prodsId,
    });
  }

  // ===== Option CRUD (products/option-crud) ================================
  // `prodo_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createOption({
    required int premId,
    required String name,
  }) async {
    await _crud('products/option-crud', {
      'prem_id': premId,
      'prodo_type': 'I',
      'prodo_name': name,
    });
  }

  Future<void> updateOption({
    required int premId,
    required int prodoId,
    required String name,
    required bool available,
  }) async {
    await _crud('products/option-crud', {
      'prem_id': premId,
      'prodo_type': 'U',
      'prodo_id': prodoId,
      'prodo_name': name,
      'prodo_available': available,
    });
  }

  Future<void> deleteOption({
    required int premId,
    required int prodoId,
  }) async {
    await _crud('products/option-crud', {
      'prem_id': premId,
      'prodo_type': 'D',
      'prodo_id': prodoId,
    });
  }

  // ===== Add-on CRUD (products/additional-crud) ============================
  // `proda_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createAdditional({
    required int premId,
    required String name,
    required String price,
  }) async {
    await _crud('products/additional-crud', {
      'prem_id': premId,
      'proda_type': 'I',
      'proda_name': name,
      'proda_price': price,
    });
  }

  Future<void> updateAdditional({
    required int premId,
    required int prodaId,
    required String name,
    required String price,
    required bool available,
  }) async {
    await _crud('products/additional-crud', {
      'prem_id': premId,
      'proda_type': 'U',
      'proda_id': prodaId,
      'proda_name': name,
      'proda_price': price,
      'proda_available': available,
    });
  }

  Future<void> deleteAdditional({
    required int premId,
    required int prodaId,
  }) async {
    await _crud('products/additional-crud', {
      'prem_id': premId,
      'proda_type': 'D',
      'proda_id': prodaId,
    });
  }

  /// Posts a CRUD body and throws if the backend reports failure.
  Future<void> _crud(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    final data = res.data;
    if (data is Map && data['state'] == 1) return;
    final message = (data is Map ? data['message'] : null) as String?;
    throw Exception(message ?? 'La operación no se pudo completar.');
  }
}
