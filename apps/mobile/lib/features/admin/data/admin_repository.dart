import "package:dio/dio.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";

import "../../../core/network/api_client.dart";
import "models/customer.dart";
import "models/inventory_item.dart";
import "models/job.dart";
import "models/maintenance_reminder.dart";
import "models/operation.dart";
import "models/personnel.dart";

// Re-export PersonnelLeave for convenience
export "models/personnel.dart" show PersonnelLeave;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AdminRepository(client);
});

class AdminRepository {
  AdminRepository(this._client);

  final Dio _client;

  Future<List<Personnel>> fetchPersonnel() async {
    final response = await _client.get("/personnel");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => Personnel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Personnel> fetchPersonnelDetail(String id) async {
    final response = await _client.get("/personnel/$id");
    return Personnel.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Personnel> updatePersonnel({
    required String id,
    required String name,
    required String phone,
    String? email,
    required DateTime hireDate,
    required String status,
    required bool canShareLocation,
  }) async {
    final response = await _client.put(
      "/personnel/$id",
      data: {
        "name": name,
        "phone": phone,
        "email": email,
        "hireDate": hireDate.toIso8601String(),
        "status": status,
        "canShareLocation": canShareLocation,
      },
    );
    return Personnel.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> deletePersonnel(String id) async {
    await _client.delete("/personnel/$id");
  }

  Future<String> resetPersonnelCode(String id) async {
    final response = await _client.post("/personnel/$id/reset-code");
    return response.data["data"]["loginCode"] as String;
  }

  Future<List<PersonnelLeave>> fetchPersonnelLeaves(String personnelId) async {
    final response = await _client.get("/personnel/$personnelId/leaves");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => PersonnelLeave.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PersonnelLeave> createPersonnelLeave({
    required String personnelId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async {
    final response = await _client.post(
      "/personnel/$personnelId/leaves",
      data: {
        "startDate": startDate.toIso8601String(),
        "endDate": endDate.toIso8601String(),
        if (reason != null && reason.isNotEmpty) "reason": reason,
      },
    );
    return PersonnelLeave.fromJson(
      response.data["data"] as Map<String, dynamic>,
    );
  }

  Future<void> deletePersonnelLeave({
    required String personnelId,
    required String leaveId,
  }) async {
    await _client.delete("/personnel/$personnelId/leaves/$leaveId");
  }

  Future<List<Job>> fetchJobs() async {
    final response = await _client.get("/jobs");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Job> fetchJobDetail(String id) async {
    final response = await _client.get("/jobs/$id");
    return Job.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> assignPersonnelToJob({
    required String jobId,
    required List<String> personnelIds,
  }) async {
    await _client.post(
      "/jobs/$jobId/assign",
      data: {"personnelIds": personnelIds},
    );
  }

  Future<List<InventoryItem>> fetchInventory() async {
    final response = await _client.get("/inventory");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryItem> fetchInventoryDetail(String id) async {
    final response = await _client.get("/inventory/$id");
    return InventoryItem.fromJson(
      response.data["data"] as Map<String, dynamic>,
    );
  }

  Future<void> createInventoryItem({
    required String name,
    required String category,
    required int stockQty,
    required double unitPrice,
    required int criticalThreshold,
    String? photoUrl,
    String? sku,
    String? unit,
    int? reorderPoint,
    int? reorderQuantity,
  }) async {
    await _client.post(
      "/inventory",
      data: {
        "name": name,
        "category": category,
        "stockQty": stockQty,
        "unitPrice": unitPrice,
        "criticalThreshold": criticalThreshold,
        if (photoUrl != null && photoUrl.isNotEmpty) "photoUrl": photoUrl,
        if (sku != null && sku.isNotEmpty) "sku": sku,
        if (unit != null && unit.isNotEmpty) "unit": unit,
        if (reorderPoint != null) "reorderPoint": reorderPoint,
        if (reorderQuantity != null) "reorderQuantity": reorderQuantity,
        "isActive": true,
      },
    );
  }

  Future<InventoryItem> updateInventoryItem({
    required String id,
    String? name,
    String? category,
    int? stockQty,
    double? unitPrice,
    int? criticalThreshold,
    String? photoUrl,
    String? sku,
    String? unit,
    int? reorderPoint,
    int? reorderQuantity,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (category != null) data["category"] = category;
    if (stockQty != null) data["stockQty"] = stockQty;
    if (unitPrice != null) data["unitPrice"] = unitPrice;
    if (criticalThreshold != null)
      data["criticalThreshold"] = criticalThreshold;
    if (photoUrl != null) data["photoUrl"] = photoUrl;
    if (sku != null) data["sku"] = sku;
    if (unit != null) data["unit"] = unit;
    if (reorderPoint != null) data["reorderPoint"] = reorderPoint;
    if (reorderQuantity != null) data["reorderQuantity"] = reorderQuantity;
    if (isActive != null) data["isActive"] = isActive;
    final response = await _client.put("/inventory/$id", data: data);
    return InventoryItem.fromJson(
      response.data["data"] as Map<String, dynamic>,
    );
  }

  Future<void> deleteInventoryItem(String id) async {
    await _client.delete("/inventory/$id");
  }

  Future<List<MaintenanceReminder>> fetchMaintenanceReminders() async {
    final response = await _client.get("/maintenance/reminders");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => MaintenanceReminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPersonnel({
    required String name,
    required String phone,
    String? email,
    required DateTime hireDate,
    bool canShareLocation = true,
  }) async {
    await _client.post(
      "/personnel",
      data: {
        "name": name,
        "phone": phone,
        "email": email,
        "hireDate": hireDate.toIso8601String(),
        "permissions": const <String, dynamic>{},
        "canShareLocation": canShareLocation,
      },
    );
  }

  Future<void> createJob({
    required String title,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String? customerEmail,
    DateTime? scheduledAt,
    String? notes,
    double? latitude,
    double? longitude,
    String? locationDescription,
    List<String>? personnelIds,
  }) async {
    final location = <String, dynamic>{};
    if (latitude != null && longitude != null) {
      location["latitude"] = latitude;
      location["longitude"] = longitude;
    }
    if (locationDescription != null && locationDescription.isNotEmpty) {
      location["address"] = locationDescription;
    }
    if (location.isEmpty) {
      location["address"] = customerAddress;
    }

    final customerData = <String, dynamic>{
      "name": customerName,
      "phone": customerPhone,
      "address": customerAddress,
    };

    // Only include email if it's not empty and is a valid email
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      customerData["email"] = customerEmail.trim();
    }

    final requestData = <String, dynamic>{
      "title": title,
      "customer": customerData,
      "location": location,
    };

    // Only include optional fields if they have values
    if (scheduledAt != null) {
      requestData["scheduledAt"] = scheduledAt.toIso8601String();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      requestData["notes"] = notes.trim();
    }
    if (personnelIds != null && personnelIds.isNotEmpty) {
      requestData["personnelIds"] = personnelIds;
    }

    await _client.post("/jobs", data: requestData);
  }

  Future<Job> updateJob({
    required String id,
    String? title,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? customerEmail,
    DateTime? scheduledAt,
    String? notes,
    double? price,
    int? priority,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data["title"] = title;
    if (customerName != null ||
        customerPhone != null ||
        customerAddress != null) {
      data["customer"] = <String, dynamic>{};
      if (customerName != null) data["customer"]["name"] = customerName;
      if (customerPhone != null) data["customer"]["phone"] = customerPhone;
      if (customerAddress != null)
        data["customer"]["address"] = customerAddress;
      if (customerEmail != null && customerEmail.isNotEmpty) {
        data["customer"]["email"] = customerEmail;
      }
    }
    if (scheduledAt != null)
      data["scheduledAt"] = scheduledAt.toIso8601String();
    if (notes != null) data["notes"] = notes;
    if (price != null) data["price"] = price;
    if (priority != null) data["priority"] = priority;
    final response = await _client.put("/jobs/$id", data: data);
    return Job.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> deleteJob(String id) async {
    await _client.delete("/jobs/$id");
  }

  // Customer methods
  Future<List<Customer>> fetchCustomers({
    String? search,
    bool? hasOverduePayment,
    bool? hasUpcomingMaintenance,
    bool? hasOverdueInstallment,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams["search"] = search;
    }
    if (hasOverduePayment == true) {
      queryParams["hasOverduePayment"] = "true";
    }
    if (hasUpcomingMaintenance == true) {
      queryParams["hasUpcomingMaintenance"] = "true";
    }
    if (hasOverdueInstallment == true) {
      queryParams["hasOverdueInstallment"] = "true";
    }
    final response = await _client.get(
      "/customers",
      queryParameters: queryParams,
    );
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> fetchCustomerDetail(String id) async {
    final response = await _client.get("/customers/$id");
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String address,
    String? email,
    Map<String, dynamic>? location,
    bool? hasDebt,
    double? debtAmount,
    bool? hasInstallment,
    int? installmentCount,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "address": address,
      if (email != null && email.isNotEmpty) "email": email,
      if (location != null) "location": location,
      if (hasDebt != null) "hasDebt": hasDebt,
      if (debtAmount != null) "debtAmount": debtAmount,
      if (hasInstallment != null) "hasInstallment": hasInstallment,
      if (installmentCount != null) "installmentCount": installmentCount,
    };
    final response = await _client.post("/customers", data: data);
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Customer> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? address,
    String? email,
    Map<String, dynamic>? location,
    bool? hasDebt,
    double? debtAmount,
    bool? hasInstallment,
    int? installmentCount,
    double? remainingDebtAmount,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (phone != null) data["phone"] = phone;
    if (address != null) data["address"] = address;
    if (email != null) data["email"] = email;
    if (location != null) data["location"] = location;
    if (hasDebt != null) data["hasDebt"] = hasDebt;
    if (debtAmount != null) data["debtAmount"] = debtAmount;
    if (hasInstallment != null) data["hasInstallment"] = hasInstallment;
    if (installmentCount != null) data["installmentCount"] = installmentCount;
    if (remainingDebtAmount != null)
      data["remainingDebtAmount"] = remainingDebtAmount;
    final response = await _client.put("/customers/$id", data: data);
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Customer> payCustomerDebt({
    required String id,
    required double amount,
    int? installmentCount,
  }) async {
    final data = <String, dynamic>{"amount": amount};
    if (installmentCount != null) data["installmentCount"] = installmentCount;
    final response = await _client.post("/customers/$id/pay-debt", data: data);
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.delete("/customers/$id");
  }

  // Operation methods
  Future<List<Operation>> fetchOperations({bool activeOnly = false}) async {
    final response = await _client.get(
      "/operations",
      queryParameters: activeOnly ? {"activeOnly": "true"} : null,
    );
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => Operation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Operation> fetchOperationDetail(String id) async {
    final response = await _client.get("/operations/$id");
    return Operation.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Operation> createOperation({
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final response = await _client.post(
      "/operations",
      data: {
        "name": name,
        if (description != null && description.isNotEmpty)
          "description": description,
        "isActive": isActive,
      },
    );
    return Operation.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Operation> updateOperation({
    required String id,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (description != null) data["description"] = description;
    if (isActive != null) data["isActive"] = isActive;
    final response = await _client.put("/operations/$id", data: data);
    return Operation.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> deleteOperation(String id) async {
    await _client.delete("/operations/$id");
  }

  // Updated job creation with new fields
  Future<void> createJobForCustomer({
    required String customerId,
    required String title,
    String? operationId,
    DateTime? scheduledAt,
    String? notes,
    double? latitude,
    double? longitude,
    String? locationDescription,
    double? price,
    bool hasInstallment = false,
    List<String>? personnelIds,
    List<Map<String, dynamic>>? materialIds,
  }) async {
    final location = <String, dynamic>{};
    if (latitude != null && longitude != null) {
      location["latitude"] = latitude;
      location["longitude"] = longitude;
    }
    if (locationDescription != null && locationDescription.isNotEmpty) {
      location["address"] = locationDescription;
    }

    final requestData = <String, dynamic>{
      "title": title,
      "customerId": customerId,
      "location": location,
    };

    if (operationId != null) requestData["operationId"] = operationId;
    if (scheduledAt != null) {
      requestData["scheduledAt"] = scheduledAt.toIso8601String();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      requestData["notes"] = notes.trim();
    }
    if (price != null) requestData["price"] = price;
    requestData["hasInstallment"] = hasInstallment;
    if (personnelIds != null && personnelIds.isNotEmpty) {
      requestData["personnelIds"] = personnelIds;
    }
    if (materialIds != null && materialIds.isNotEmpty) {
      requestData["materialIds"] = materialIds;
    }

    await _client.post("/jobs", data: requestData);
  }
}
