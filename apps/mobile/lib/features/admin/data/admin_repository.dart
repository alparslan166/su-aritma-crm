import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:path_provider/path_provider.dart";
import "package:url_launcher/url_launcher.dart";

// Conditional import for dart:io (not available on Web)
// On Web, we import a stub file that provides a File class
// On other platforms, dart:io is imported
import "dart:io" if (dart.library.html) "file_stub.dart" as io;

import "../../../core/network/api_client.dart";
import "models/customer.dart";
import "models/inventory_item.dart";
import "models/invoice.dart";
import "models/job.dart";
import "models/maintenance_reminder.dart";
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

  Future<List<Personnel>> fetchPersonnel({
    String? search,
    String? phoneSearch,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) async {
    // Backend'e search parametresi gönder (backend hem name, hem phone, hem email'de arar)
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams["search"] = search;
    }

    final response = await _client.get(
      "/personnel",
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final items = response.data["data"] as List<dynamic>? ?? [];
    var personnelList = items
        .map((e) => Personnel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Frontend'de ek filtreleme: phoneSearch
    if (phoneSearch != null && phoneSearch.isNotEmpty) {
      personnelList = personnelList.where((personnel) {
        return personnel.phone.contains(phoneSearch);
      }).toList();
    }

    // Frontend'de tarih filtrelemesi (hireDate'e göre)
    if (createdAtFrom != null || createdAtTo != null) {
      personnelList = personnelList.where((personnel) {
        final date = personnel.hireDate;
        if (createdAtFrom != null && date.isBefore(createdAtFrom)) {
          return false;
        }
        if (createdAtTo != null &&
            date.isAfter(createdAtTo.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
    }

    return personnelList;
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
    bool? canShareLocation,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "hireDate": hireDate.toIso8601String(),
      "status": status,
    };
    if (email != null) data["email"] = email;
    if (canShareLocation != null) data["canShareLocation"] = canShareLocation;
    // Always send photoUrl if provided (including empty string to remove photo)
    if (photoUrl != null) {
      data["photoUrl"] = photoUrl;
    }
    final response = await _client.put("/personnel/$id", data: data);
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

  Future<List<Job>> fetchJobs({String? personnelId}) async {
    final queryParams = <String, dynamic>{};
    if (personnelId != null && personnelId.isNotEmpty) {
      queryParams["personnelId"] = personnelId;
    }
    final response = await _client.get("/jobs", queryParameters: queryParams);
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
    if (criticalThreshold != null) {
      data["criticalThreshold"] = criticalThreshold;
    }
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
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "hireDate": hireDate.toIso8601String(),
      "permissions": const <String, dynamic>{},
      "canShareLocation": canShareLocation,
    };
    if (email != null) data["email"] = email;
    if (photoUrl != null) data["photoUrl"] = photoUrl;
    await _client.post("/personnel", data: data);
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
      if (customerAddress != null) {
        data["customer"]["address"] = customerAddress;
      }
      if (customerEmail != null && customerEmail.isNotEmpty) {
        data["customer"]["email"] = customerEmail;
      }
    }
    if (scheduledAt != null) {
      data["scheduledAt"] = scheduledAt.toIso8601String();
    }
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
    String? phoneSearch,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
    bool? hasOverduePayment,
    bool? hasUpcomingMaintenance,
    bool? hasOverdueInstallment,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) {
      queryParams["search"] = search;
    }
    if (phoneSearch != null && phoneSearch.isNotEmpty) {
      queryParams["phoneSearch"] = phoneSearch;
    }
    if (createdAtFrom != null) {
      queryParams["createdAtFrom"] = createdAtFrom.toIso8601String();
    }
    if (createdAtTo != null) {
      queryParams["createdAtTo"] = createdAtTo.toIso8601String();
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
    DateTime? createdAt,
    bool? hasDebt,
    double? debtAmount,
    bool? hasInstallment,
    int? installmentCount,
    DateTime? nextDebtDate,
    DateTime? installmentStartDate,
    int? installmentIntervalDays,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "address": address,
      if (email != null && email.isNotEmpty) "email": email,
      if (location != null) "location": location,
      if (createdAt != null) "createdAt": createdAt.toIso8601String(),
      if (hasDebt != null) "hasDebt": hasDebt,
      if (debtAmount != null) "debtAmount": debtAmount,
      if (hasInstallment != null) "hasInstallment": hasInstallment,
      if (installmentCount != null) "installmentCount": installmentCount,
      if (nextDebtDate != null) "nextDebtDate": nextDebtDate.toIso8601String(),
      if (installmentStartDate != null)
        "installmentStartDate": installmentStartDate.toIso8601String(),
      if (installmentIntervalDays != null)
        "installmentIntervalDays": installmentIntervalDays,
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
    String? status,
    DateTime? createdAt,
    bool? hasDebt,
    double? debtAmount,
    bool? hasInstallment,
    int? installmentCount,
    DateTime? nextDebtDate,
    DateTime? installmentStartDate,
    int? installmentIntervalDays,
    double? remainingDebtAmount,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (phone != null) data["phone"] = phone;
    if (address != null) data["address"] = address;
    if (status != null) data["status"] = status;
    if (email != null) data["email"] = email;
    if (location != null) data["location"] = location;
    if (createdAt != null) data["createdAt"] = createdAt.toIso8601String();
    if (hasDebt != null) data["hasDebt"] = hasDebt;
    if (debtAmount != null) data["debtAmount"] = debtAmount;
    if (hasInstallment != null) data["hasInstallment"] = hasInstallment;
    if (installmentCount != null) data["installmentCount"] = installmentCount;
    if (nextDebtDate != null) {
      data["nextDebtDate"] = nextDebtDate.toIso8601String();
    }
    if (installmentStartDate != null) {
      data["installmentStartDate"] = installmentStartDate.toIso8601String();
    }
    if (installmentIntervalDays != null) {
      data["installmentIntervalDays"] = installmentIntervalDays;
    }
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

  Future<Customer> markInstallmentOverdue(String id) async {
    final response = await _client.post(
      "/customers/$id/mark-installment-overdue",
    );
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.delete("/customers/$id");
  }

  // Updated job creation with new fields
  Future<void> createJobForCustomer({
    required String customerId,
    required String title,
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

  // Invoice methods
  Future<Invoice> createInvoiceDraft({
    required String jobId,
    double? subtotal,
    double? tax,
    double? total,
    String? notes,
  }) async {
    final response = await _client.post(
      "/invoices",
      data: {
        "jobId": jobId,
        if (subtotal != null) "subtotal": subtotal,
        if (tax != null) "tax": tax,
        if (total != null) "total": total,
        if (notes != null && notes.isNotEmpty) "notes": notes,
      },
    );
    return Invoice.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Invoice> updateInvoice({
    required String invoiceId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? customerEmail,
    String? jobTitle,
    DateTime? jobDate,
    double? subtotal,
    double? tax,
    double? total,
    String? notes,
    bool? isDraft,
  }) async {
    final response = await _client.put(
      "/invoices/$invoiceId",
      data: {
        if (customerName != null) "customerName": customerName,
        if (customerPhone != null) "customerPhone": customerPhone,
        if (customerAddress != null) "customerAddress": customerAddress,
        if (customerEmail != null) "customerEmail": customerEmail,
        if (jobTitle != null) "jobTitle": jobTitle,
        if (jobDate != null) "jobDate": jobDate.toIso8601String(),
        if (subtotal != null) "subtotal": subtotal,
        if (tax != null) "tax": tax,
        if (total != null) "total": total,
        if (notes != null) "notes": notes,
        if (isDraft != null) "isDraft": isDraft,
      },
    );
    return Invoice.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<Invoice> fetchInvoice(String invoiceId) async {
    final response = await _client.get("/invoices/$invoiceId");
    return Invoice.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  Future<List<Invoice>> fetchInvoices() async {
    final response = await _client.get("/invoices");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteInvoice(String invoiceId) async {
    await _client.delete("/invoices/$invoiceId");
  }

  // Profile methods
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get("/auth/profile");
    return response.data["data"] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? taxOffice,
    String? taxNumber,
    String? logoUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (phone != null) data["phone"] = phone;
    if (email != null) data["email"] = email;
    if (companyName != null) data["companyName"] = companyName;
    if (companyAddress != null) data["companyAddress"] = companyAddress;
    if (companyPhone != null) data["companyPhone"] = companyPhone;
    if (companyEmail != null) data["companyEmail"] = companyEmail;
    if (taxOffice != null) data["taxOffice"] = taxOffice;
    if (taxNumber != null) data["taxNumber"] = taxNumber;
    if (logoUrl != null) data["logoUrl"] = logoUrl;
    final response = await _client.put("/auth/profile", data: data);
    return response.data["data"] as Map<String, dynamic>;
  }

  // Helper function to write bytes to file (only works on non-Web platforms)
  Future<void> _writeBytesToFile(String filePath, List<int> bytes) async {
    if (kIsWeb) {
      throw UnsupportedError("File operations not supported on Web");
    }
    final file = io.File(filePath);
    await file.writeAsBytes(bytes);
  }

  Future<String> generateInvoicePdf(String jobId) async {
    // On Web, open PDF directly in browser
    if (kIsWeb) {
      final baseUrl = _client.options.baseUrl;
      final pdfUrl = "$baseUrl/invoices/job/$jobId/pdf";
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return "web_pdf_$jobId";
      }
      throw Exception("PDF açılamadı. Lütfen tekrar deneyin.");
    }

    // For mobile/desktop platforms, save PDF to file
    try {
      final directory = await getTemporaryDirectory();
      final response = await _client.get(
        "/invoices/job/$jobId/pdf",
        options: Options(
          responseType: ResponseType.bytes,
          headers: {"Accept": "application/pdf"},
        ),
      );
      final filePath = "${directory.path}/fatura_$jobId.pdf";
      await _writeBytesToFile(filePath, response.data as List<int>);
      return filePath;
    } catch (e) {
      // If temporary directory fails, try application documents directory
      try {
        final directory = await getApplicationDocumentsDirectory();
        final response = await _client.get(
          "/invoices/job/$jobId/pdf",
          options: Options(
            responseType: ResponseType.bytes,
            headers: {"Accept": "application/pdf"},
          ),
        );
        final filePath = "${directory.path}/fatura_$jobId.pdf";
        await _writeBytesToFile(filePath, response.data as List<int>);
        return filePath;
      } catch (e2) {
        // If both fail, open PDF directly from URL
        final baseUrl = _client.options.baseUrl;
        final pdfUrl = "$baseUrl/invoices/job/$jobId/pdf";
        final uri = Uri.parse(pdfUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return "web_pdf_$jobId";
        }
        throw Exception("PDF açılamadı. Lütfen tekrar deneyin.");
      }
    }
  }
}
