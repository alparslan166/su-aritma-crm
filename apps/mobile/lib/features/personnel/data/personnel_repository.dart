import "package:dio/dio.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/network/api_client.dart";
import "../application/delivery_payload.dart";
import "models/personnel_job.dart";

final personnelRepositoryProvider = Provider<PersonnelRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return PersonnelRepository(client);
});

class PersonnelRepository {
  PersonnelRepository(this._client);

  final Dio _client;

  Future<List<PersonnelJob>> fetchAssignedJobs({
    String? status,
    String? search,
  }) async {
    final response = await _client.get(
      "/personnel/jobs",
      queryParameters: {
        if (status != null) "status": status,
        if (search != null && search.isNotEmpty) "search": search,
      },
    );
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => PersonnelJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PersonnelJobDetail> fetchJobDetail(String id) async {
    final response = await _client.get("/personnel/jobs/$id");
    return PersonnelJobDetail.fromJson(
      response.data["data"] as Map<String, dynamic>,
    );
  }

  Future<void> startJob(String id) async {
    await _client.post("/personnel/jobs/$id/start");
  }

  Future<void> deliverJob(String id, DeliveryPayload payload) async {
    await _client.post("/personnel/jobs/$id/deliver", data: payload.toJson());
  }
}
