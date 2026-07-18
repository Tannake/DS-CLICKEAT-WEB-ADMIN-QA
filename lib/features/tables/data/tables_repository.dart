import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/tables/models/table_section.dart';

final tablesRepositoryProvider = Provider<TablesRepository>((ref) {
  return TablesRepository(ref.read(dioProvider));
});

class TablesRepository {
  TablesRepository(this._dio);
  final Dio _dio;

  /// GET `premises/section/<premId>` — the zones (sections) of a premise with
  /// the tables linked to each one. The auth token is injected by the
  /// interceptor.
  Future<List<TableSection>> getByPremise(int premId) async {
    final res = await _dio.get('premises/section/$premId');
    final data = res.data;
    if (data is Map && data['state'] == 1 && data['result'] is List) {
      return TableSection.fromBackendList(data['result'] as List);
    }
    return const [];
  }

  // ===== Section CRUD (premises/section-crud) ================================
  // `sect_type` flags the operation: I (insert), U (update), D (delete).

  Future<void> createSection({
    required int premId,
    required String sectName,
  }) async {
    await _crud('premises/section-crud', {
      'sect_type': 'I',
      'prem_id': premId,
      'sect_name': sectName,
    });
  }

  Future<void> updateSection({
    required int premId,
    required int sectId,
    required String sectName,
  }) async {
    await _crud('premises/section-crud', {
      'sect_type': 'U',
      'sect_id': sectId,
      'prem_id': premId,
      'sect_name': sectName,
    });
  }

  Future<void> deleteSection({
    required int premId,
    required int sectId,
  }) async {
    await _crud('premises/section-crud', {
      'sect_type': 'D',
      'sect_id': sectId,
      'prem_id': premId,
    });
  }

  // ===== Section ↔ table CRUD (premises/section-tables-crud) =================
  // `sect_type` flags the operation: I (link a table), D (unlink a table).

  Future<void> addTable({
    required int premId,
    required int sectId,
    required int tablId,
  }) async {
    await _crud('premises/section-tables-crud', {
      'sect_type': 'I',
      'sect_id': sectId,
      'prem_id': premId,
      'tabl_id': tablId,
    });
  }

  Future<void> removeTable({
    required int premId,
    required int sectId,
    required int tablId,
  }) async {
    await _crud('premises/section-tables-crud', {
      'sect_type': 'D',
      'sect_id': sectId,
      'prem_id': premId,
      'tabl_id': tablId,
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
