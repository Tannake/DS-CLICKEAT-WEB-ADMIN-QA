import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product_detail.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(dioProvider));
});

class ProductsRepository {
  ProductsRepository(this._dio);
  final Dio _dio;

  Future<List<Product>> getByPremise(int premId) async {
    final res = await _dio.get('products/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return (data['result'] as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Fetches the full detail of a single product. The endpoint wraps the
  /// product in a single-element list, so we read the first entry.
  Future<ProductDetail?> getDetail(int premId, int prodId) async {
    final res = await _dio.get('products/detail/$premId/$prodId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final list = data['result'] as List;
      if (list.isNotEmpty) {
        return ProductDetail.fromJson(
          Map<String, dynamic>.from(list.first as Map),
        );
      }
    }
    return null;
  }

  /// Uploads a product image (must be a .jpg). Returns the hosted image URL.
  Future<String?> uploadProductImage({
    required int premId,
    required int prodId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
      'prem_id': premId,
      'prod_id': prodId,
    });
    final res = await _dio.post('files/upload-product-image', data: form);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return (data['result'] as Map)['image_url'] as String?;
    }
    return null;
  }

  /// Fetches the premise-scoped catalogs (categories, preparation areas, sizes,
  /// options and add-ons) used to populate the "new product" form. Returns a
  /// blank [ProductDetail] carrying just those catalogs.
  Future<ProductDetail?> getMasterData(int premId) async {
    final res = await _dio.get('products/master-data/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return ProductDetail.fromMasterData(
        Map<String, dynamic>.from(data['result'] as Map),
      );
    }
    return null;
  }

  /// Persists the full product (header fields, variants and linked add-ons).
  /// [payload] is built by [ProductDetail.toBackendJson]. Success is `state == 1`
  /// (0 means a server/DB error). The auth token is injected by the interceptor.
  Future<bool> saveProduct(Map<String, dynamic> payload) async {
    final res = await _dio.post('products/update', data: payload);
    final data = res.data;
    return data is Map && data['state'] == 1;
  }

  /// Creates a new product. [payload] is built by [ProductDetail.toCreateJson]
  /// (same shape as the update payload but without `prod_id`). On success
  /// (`state == 1`) the backend returns the new product's id in
  /// `result.prod_id`, which is needed to upload its image. Returns that id, or
  /// `null` on failure (`state == 0`). Token injected by the interceptor.
  Future<int?> createProduct(Map<String, dynamic> payload) async {
    final res = await _dio.post('products/create', data: payload);
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is Map) {
      return ((data['result'] as Map)['prod_id'] as num?)?.toInt();
    }
    return null;
  }

  /// Deletes a product. Success is `state == 1` (0 means a server/DB error).
  Future<bool> deleteProduct({
    required int premId,
    required int prodId,
  }) async {
    final res = await _dio.post(
      'products/delete',
      data: {'prem_id': premId, 'prod_id': prodId},
    );
    final data = res.data;
    return data is Map && data['state'] == 1;
  }
}
