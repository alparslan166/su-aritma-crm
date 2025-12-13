import "package:dio/dio.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/network/api_client.dart";
import "../../../core/session/session_provider.dart";
import "../application/delivery_payload.dart";
import "models/personnel_job.dart";

final personnelRepositoryProvider = Provider<PersonnelRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final session = ref.watch(authSessionProvider);
  return PersonnelRepository(client, session?.identifier);
});

class PersonnelRepository {
  PersonnelRepository(this._client, this._personnelId);

  final Dio _client;
  final String? _personnelId;

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

  Future<Map<String, dynamic>> fetchMyProfile() async {
    if (_personnelId == null) {
      throw Exception("Personnel ID not available. Please login first.");
    }
    final response = await _client.get("/personnel/$_personnelId");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchProfileById(String personnelId) async {
    final response = await _client.get("/personnel/$personnelId");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMyProfile({bool? canShareLocation}) async {
    final data = <String, dynamic>{};
    if (canShareLocation != null) {
      data["canShareLocation"] = canShareLocation;
    }
    final response = await _client.patch("/personnel/me/profile", data: data);
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<void> updateLocation(double lat, double lng, {String? jobId}) async {
    final data = <String, dynamic>{"lat": lat, "lng": lng};
    if (jobId != null) {
      data["jobId"] = jobId;
    }
    await _client.post("/personnel/location", data: data);
  }
}
