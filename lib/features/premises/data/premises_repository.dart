import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/premises/models/premise.dart';

final premisesRepositoryProvider = Provider<PremisesRepository>((ref) {
  return PremisesRepository(ref.read(dioProvider));
});

class PremisesRepository {
  PremisesRepository(this._dio);
  final Dio _dio;

  Future<List<Premise>> getEssential(int userId) async {
    final res = await _dio.get('premises/essential/$userId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      final list = (data['result'] as List)
          .map((e) => Premise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort(
          (a, b) => a.premName.toLowerCase().compareTo(b.premName.toLowerCase()));
      return list;
    }
    return [];
  }
}
