import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show debugPrint;
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

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
    String? loginCode,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "hireDate": hireDate.toUtc().toIso8601String(),
      "status": status,
    };
    if (email != null) data["email"] = email;
    if (canShareLocation != null) data["canShareLocation"] = canShareLocation;
    // Always send photoUrl if provided (including empty string to remove photo)
    if (photoUrl != null) {
      data["photoUrl"] = photoUrl;
    }
    // Empty string means generate new code, null means keep existing, string means use provided
    if (loginCode != null) {
      data["loginCode"] = loginCode;
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
        "startDate": startDate.toUtc().toIso8601String(),
        "endDate": endDate.toUtc().toIso8601String(),
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
    String? loginCode,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "hireDate": hireDate.toUtc().toIso8601String(),
      "permissions": const <String, dynamic>{},
      "canShareLocation": canShareLocation,
    };
    if (email != null) data["email"] = email;
    if (photoUrl != null) data["photoUrl"] = photoUrl;
    if (loginCode != null && loginCode.isNotEmpty)
      data["loginCode"] = loginCode;
    await _client.post("/personnel", data: data);
  }

  Future<void> createJob({
    required String title,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? customerEmail,
    DateTime? scheduledAt,
    String? notes,
    double? latitude,
    double? longitude,
    String? locationDescription,
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
    if (location.isEmpty &&
        customerAddress != null &&
        customerAddress.isNotEmpty) {
      location["address"] = customerAddress;
    }
    // Location boşsa default bir değer ekle (backend zorunlu kılıyor)
    if (location.isEmpty) {
      location["address"] = "Konum bilgisi yok";
    }

    final requestData = <String, dynamic>{"title": title, "location": location};

    // Customer bilgileri sadece sağlanmışsa ekle
    if (customerName != null &&
        customerName.isNotEmpty &&
        customerPhone != null &&
        customerPhone.isNotEmpty &&
        customerAddress != null &&
        customerAddress.isNotEmpty) {
      final customerData = <String, dynamic>{
        "name": customerName,
        "phone": customerPhone,
        "address": customerAddress,
      };

      // Only include email if it's not empty and is a valid email
      if (customerEmail != null && customerEmail.trim().isNotEmpty) {
        customerData["email"] = customerEmail.trim();
      }

      requestData["customer"] = customerData;
    }

    // Only include optional fields if they have values
    if (scheduledAt != null) {
      requestData["scheduledAt"] = scheduledAt.toUtc().toIso8601String();
    }
    if (notes != null && notes.trim().isNotEmpty) {
      requestData["notes"] = notes.trim();
    }
    if (personnelIds != null && personnelIds.isNotEmpty) {
      requestData["personnelIds"] = personnelIds;
    }
    if (materialIds != null && materialIds.isNotEmpty) {
      requestData["materialIds"] = materialIds;
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
      data["scheduledAt"] = scheduledAt.toUtc().toIso8601String();
    }
    if (notes != null) data["notes"] = notes;
    if (price != null) data["price"] = price;
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
      queryParams["createdAtFrom"] = createdAtFrom.toUtc().toIso8601String();
    }
    if (createdAtTo != null) {
      queryParams["createdAtTo"] = createdAtTo.toUtc().toIso8601String();
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
    DateTime? nextMaintenanceDate,
    double? receivedAmount,
    DateTime? paymentDate,
  }) async {
    final data = <String, dynamic>{
      "name": name,
      "phone": phone,
      "address": address,
      if (email != null && email.isNotEmpty) "email": email,
      if (location != null) "location": location,
      if (createdAt != null) "createdAt": createdAt.toUtc().toIso8601String(),
      if (hasDebt != null) "hasDebt": hasDebt,
      if (debtAmount != null) "debtAmount": debtAmount,
      if (hasInstallment != null) "hasInstallment": hasInstallment,
      if (installmentCount != null) "installmentCount": installmentCount,
      if (nextDebtDate != null)
        "nextDebtDate": nextDebtDate.toUtc().toIso8601String(),
      if (installmentStartDate != null)
        "installmentStartDate": installmentStartDate.toUtc().toIso8601String(),
      if (installmentIntervalDays != null)
        "installmentIntervalDays": installmentIntervalDays,
      if (nextMaintenanceDate != null)
        "nextMaintenanceDate": nextMaintenanceDate.toUtc().toIso8601String(),
      if (receivedAmount != null) "receivedAmount": receivedAmount,
      if (paymentDate != null)
        "paymentDate": paymentDate.toUtc().toIso8601String(),
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
    DateTime?
    nextMaintenanceDate, // null gönderilirse temizlenir, undefined gönderilirse korunur
    bool sendNextMaintenanceDate =
        false, // nextMaintenanceDate gönderilmeli mi? (null olsa bile)
    double? receivedAmount,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? usedProducts, // Kullanılan ürünler listesi
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data["name"] = name;
    if (phone != null) data["phone"] = phone;
    if (address != null) data["address"] = address;
    if (status != null) data["status"] = status;
    if (email != null) data["email"] = email;
    if (location != null) data["location"] = location;
    if (createdAt != null)
      data["createdAt"] = createdAt.toUtc().toIso8601String();
    if (hasDebt != null) data["hasDebt"] = hasDebt;
    if (debtAmount != null) data["debtAmount"] = debtAmount;
    if (hasInstallment != null) data["hasInstallment"] = hasInstallment;
    if (installmentCount != null) data["installmentCount"] = installmentCount;
    if (nextDebtDate != null) {
      data["nextDebtDate"] = nextDebtDate.toUtc().toIso8601String();
    }
    if (installmentStartDate != null) {
      data["installmentStartDate"] = installmentStartDate
          .toUtc()
          .toIso8601String();
    }
    if (installmentIntervalDays != null) {
      data["installmentIntervalDays"] = installmentIntervalDays;
    }
    if (remainingDebtAmount != null)
      data["remainingDebtAmount"] = remainingDebtAmount;
    if (receivedAmount != null) data["receivedAmount"] = receivedAmount;
    if (paymentDate != null) {
      data["paymentDate"] = paymentDate.toUtc().toIso8601String();
    }
    // nextMaintenanceDate gönder
    // NOT: nextMaintenanceDate parametresi sadece değişiklik yapıldığında gönderilir
    // Eğer null gönderilirse, backend'de null olarak set edilir (temizlenir)
    // Eğer hiç gönderilmezse (undefined), backend'de mevcut değer korunur
    // sendNextMaintenanceDate flag'i true ise, null olsa bile gönderilmeli
    debugPrint(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    debugPrint("🔵🔵🔵 Frontend Repository - updateCustomer BAŞLADI 🔵🔵🔵");
    debugPrint("   Customer ID: $id");
    debugPrint("   sendNextMaintenanceDate: $sendNextMaintenanceDate");
    debugPrint("   nextMaintenanceDate (raw): $nextMaintenanceDate");
    if (sendNextMaintenanceDate) {
      if (nextMaintenanceDate != null) {
        final dateString = nextMaintenanceDate.toUtc().toIso8601String();
        data["nextMaintenanceDate"] = dateString;
        debugPrint("   ✅ nextMaintenanceDate gönderiliyor: $dateString");
      } else {
        // Null göndermek için null olarak gönder
        // Backend'de payload.nextMaintenanceDate !== undefined kontrolü var
        // null gönderilirse !== undefined true olur ve işlenir (null olarak set edilir)
        data["nextMaintenanceDate"] = null;
        debugPrint(
          "   ✅ nextMaintenanceDate null olarak gönderiliyor (temizlenecek)",
        );
      }
    } else {
      debugPrint(
        "   ⚠️ nextMaintenanceDate gönderilmiyor (undefined - mevcut değer korunacak)",
      );
    }
    debugPrint("   Gönderilecek data: ${data.toString()}");
    debugPrint(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    // usedProducts gönder
    if (usedProducts != null) {
      data["usedProducts"] = usedProducts;
      debugPrint("   ✅ usedProducts gönderiliyor: ${usedProducts.length} adet");
    }
    // Eğer sendNextMaintenanceDate false ise, nextMaintenanceDate hiç gönderilmez (undefined)
    final response = await _client.put("/customers/$id", data: data);
    final updatedCustomer = Customer.fromJson(
      response.data["data"] as Map<String, dynamic>,
    );
    debugPrint(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    debugPrint("🔵🔵🔵 Frontend Repository - updateCustomer TAMAMLANDI 🔵🔵🔵");
    debugPrint(
      "   Response nextMaintenanceDate: ${updatedCustomer.nextMaintenanceDate}",
    );
    debugPrint(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    return updatedCustomer;
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
    // Backend requires at least one field in location
    if (locationDescription != null && locationDescription.isNotEmpty) {
      location["address"] = locationDescription;
    } else if (location.isEmpty) {
      // Fallback: add default address if no location data is available
      location["address"] = "Konum bilgisi yok";
    }

    final requestData = <String, dynamic>{
      "title": title,
      "customerId": customerId,
      "location": location,
    };

    if (scheduledAt != null) {
      requestData["scheduledAt"] = scheduledAt.toUtc().toIso8601String();
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
        if (jobDate != null) "jobDate": jobDate.toUtc().toIso8601String(),
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

  // Create customer-only invoice (no job required)
  Future<Invoice> createCustomerInvoice({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String? customerEmail,
    required double subtotal,
    double? tax,
    required double total,
    String? notes,
    DateTime? invoiceDate,
  }) async {
    final response = await _client.post(
      "/invoices/customer",
      data: {
        "customerId": customerId,
        "customerName": customerName,
        "customerPhone": customerPhone,
        "customerAddress": customerAddress,
        if (customerEmail != null && customerEmail.isNotEmpty)
          "customerEmail": customerEmail,
        "subtotal": subtotal,
        if (tax != null) "tax": tax,
        "total": total,
        if (notes != null && notes.isNotEmpty) "notes": notes,
        if (invoiceDate != null)
          "invoiceDate": invoiceDate.toUtc().toIso8601String(),
      },
    );
    return Invoice.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  // Installment methods
  Future<List<Map<String, dynamic>>> getInstallments(String customerId) async {
    final response = await _client.get("/installments/customer/$customerId");
    final data = response.data["data"] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> payInstallment(String installmentId) async {
    final response = await _client.post("/installments/$installmentId/pay");
    return response.data["data"] as Map<String, dynamic>;
  }

  // Pay debt method
  Future<Customer> payDebt(String customerId, double amount) async {
    final response = await _client.post(
      "/customers/$customerId/pay-debt",
      data: {"amount": amount},
    );
    return Customer.fromJson(response.data["data"] as Map<String, dynamic>);
  }

  // Profile methods
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _client.get("/auth/profile");
    return response.data["data"] as Map<String, dynamic>;
  }

  // Subscription methods
  Future<Map<String, dynamic>?> getSubscription() async {
    try {
      final response = await _client.get(
        "/subscriptions",
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      debugPrint("📦 Subscription API response: ${response.data}");
      if (response.data["data"] == null) {
        debugPrint("⚠️ Subscription data is null");
        return null;
      }
      final subscription = response.data["data"] as Map<String, dynamic>;
      debugPrint("✅ Subscription loaded: $subscription");
      return subscription;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        debugPrint("❌ Subscription API timeout: ${e.message}");
        debugPrint(
          "⚠️ Backend'e bağlanılamıyor. Backend çalışıyor mu kontrol edin.",
        );
      } else if (e.type == DioExceptionType.connectionError) {
        debugPrint("❌ Subscription API connection error: ${e.message}");
        debugPrint(
          "⚠️ Backend'e bağlanılamıyor. API URL doğru mu kontrol edin: ${_client.options.baseUrl}",
        );
      } else if (e.response?.statusCode == 404) {
        debugPrint(
          "⚠️ Subscription not found (404) - Admin'in subscription'ı yok",
        );
        return null;
      } else {
        debugPrint("❌ Subscription API error: ${e.type} - ${e.message}");
        if (e.response != null) {
          debugPrint("   Response status: ${e.response?.statusCode}");
          debugPrint("   Response data: ${e.response?.data}");
        }
      }
      // Subscription not found or error - return null to show empty state
      return null;
    } catch (e) {
      debugPrint("❌ Subscription API unexpected error: $e");
      return null;
    }
  }

  Future<void> markTrialNoticeSeen() async {
    await _client.post("/subscriptions/mark-trial-notice-seen");
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

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await _client.get("/notifications");
    final items = response.data["data"] as List<dynamic>? ?? [];
    return items
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  // Helper function to write bytes to file (only works on non-Web platforms)
  /// Open invoice PDF by invoice ID - opens directly from URL
  Future<String> openInvoicePdf(String invoiceId) async {
    final baseUrl = _client.options.baseUrl;
    final pdfUrl = "$baseUrl/invoices/$invoiceId/pdf";
    final uri = Uri.parse(pdfUrl);

    try {
      bool launched = false;
      String? lastError;

      // Try externalApplication first (works better for PDFs on Android)
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          debugPrint("✅ PDF opened successfully with externalApplication");
          return "pdf_$invoiceId";
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint("⚠️ externalApplication failed: $e");
      }

      // If externalApplication fails, try platformDefault
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launched) {
            debugPrint("✅ PDF opened successfully with platformDefault");
            return "pdf_$invoiceId";
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint("⚠️ platformDefault failed: $e");
        }
      }

      debugPrint("❌ All launch modes failed. Last error: $lastError");
      throw Exception(
        "PDF açılamadı. Lütfen bir web tarayıcısı veya PDF görüntüleyici uygulaması yüklü olduğundan emin olun.",
      );
    } catch (e) {
      debugPrint("❌ PDF açma hatası: $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception("PDF açılamadı: ${e.toString()}. Lütfen tekrar deneyin.");
    }
  }

  /// Generate invoice PDF - opens directly from URL, never saves to device
  Future<String> generateInvoicePdf(String jobId) async {
    // Always open PDF directly from URL - never save to device storage
    final baseUrl = _client.options.baseUrl;
    final pdfUrl = "$baseUrl/invoices/job/$jobId/pdf";
    final uri = Uri.parse(pdfUrl);

    try {
      // canLaunchUrl sometimes returns false for valid URLs on Android
      // So we'll try to launch directly without checking first
      bool launched = false;
      String? lastError;

      // Try externalApplication first (works better for PDFs on Android)
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          debugPrint("✅ PDF opened successfully with externalApplication");
          return "pdf_$jobId";
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint("⚠️ externalApplication failed: $e");
      }

      // If externalApplication fails, try platformDefault
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launched) {
            debugPrint("✅ PDF opened successfully with platformDefault");
            return "pdf_$jobId";
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint("⚠️ platformDefault failed: $e");
        }
      }

      // If both fail, provide helpful error message
      debugPrint("❌ All launch modes failed. Last error: $lastError");
      throw Exception(
        "PDF açılamadı. Lütfen bir web tarayıcısı (Chrome, Firefox vb.) veya PDF görüntüleyici uygulaması yüklü olduğundan emin olun. URL: $pdfUrl",
      );
    } catch (e) {
      debugPrint("❌ PDF açma hatası: $e");
      // Re-throw if it's already an Exception with a message
      if (e is Exception) {
        rethrow;
      }
      // Otherwise wrap it
      throw Exception("PDF açılamadı: ${e.toString()}. Lütfen tekrar deneyin.");
    }
  }

  /// Export all admin data to Excel and return download URL
  Future<String> exportAllDataToExcel() async {
    try {
      // Get base URL from client options
      final baseUrl = _client.options.baseUrl;
      
      // Get auth token from headers
      final headers = _client.options.headers;
      final authHeader = headers["Authorization"] as String?;
      
      if (authHeader == null) {
        throw Exception("Yetkilendirme hatası. Lütfen tekrar giriş yapın.");
      }
      
      // Construct export URL with token as query param for download
      final token = authHeader.replaceFirst("Bearer ", "");
      final exportUrl = "$baseUrl/export/excel";
      
      debugPrint("📦 Excel export URL: $exportUrl");
      
      // Open URL in browser for download
      final uri = Uri.parse(exportUrl);
      
      // Add Authorization header for the download
      // Since we can't add headers to launchUrl, we'll use a workaround
      // by making the request and returning the URL that can be opened
      final response = await _client.get(
        "/export/excel",
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      
      // Return the bytes as base64 data URL for download
      // This is a workaround for web platform
      final bytes = response.data as List<int>;
      debugPrint("✅ Excel export successful: ${bytes.length} bytes");
      
      // For now, return the bytes count as success indicator
      return "success:${bytes.length}";
    } catch (e) {
      debugPrint("❌ Excel export hatası: $e");
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw Exception("Bağlantı zaman aşımı. Lütfen tekrar deneyin.");
        }
        throw Exception("Dışarı aktarma hatası: ${e.message}");
      }
      rethrow;
    }
  }

  /// Export all data and trigger download
  Future<Uint8List> downloadExcelExport() async {
    try {
      debugPrint("📦 Excel export başlatılıyor...");
      
      final response = await _client.get(
        "/export/excel",
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      
      final bytes = response.data as List<int>;
      debugPrint("✅ Excel export tamamlandı: ${bytes.length} bytes");
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint("❌ Excel export hatası: $e");
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw Exception("Bağlantı zaman aşımı. Lütfen tekrar deneyin.");
        }
        throw Exception("Dışarı aktarma hatası: ${e.message}");
      }
      rethrow;
    }
  }
}
