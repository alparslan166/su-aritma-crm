class JobCustomer {
  JobCustomer({required this.name, required this.phone, required this.address});

  final String name;
  final String phone;
  final String address;

  factory JobCustomer.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return JobCustomer(name: "-", phone: "-", address: "-");
    }
    return JobCustomer(
      name: json["name"] as String? ?? "-",
      phone: json["phone"] as String? ?? "-",
      address: json["address"] as String? ?? "-",
    );
  }

  /// Yeni bir JobCustomer instance'ı oluşturur, belirtilen alanları günceller
  JobCustomer copyWith({
    String? name,
    String? phone,
    String? address,
  }) {
    return JobCustomer(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }
}

class JobAssignment {
  JobAssignment({required this.personnelName, this.personnelId});

  final String personnelName;
  final String? personnelId;

  factory JobAssignment.fromJson(Map<String, dynamic> json) {
    final personnel = json["personnel"] as Map<String, dynamic>? ?? {};
    return JobAssignment(
      personnelName: personnel["name"] as String? ?? "Bilinmiyor",
      personnelId: json["personnelId"] as String?,
    );
  }

  /// Yeni bir JobAssignment instance'ı oluşturur, belirtilen alanları günceller
  JobAssignment copyWith({
    String? personnelName,
    String? personnelId,
  }) {
    return JobAssignment(
      personnelName: personnelName ?? this.personnelName,
      personnelId: personnelId ?? this.personnelId,
    );
  }
}

class JobMaterial {
  JobMaterial({
    required this.id,
    required this.inventoryItemName,
    required this.quantity,
    required this.unitPrice,
  });

  final String id;
  final String inventoryItemName;
  final int quantity;
  final double unitPrice;

  factory JobMaterial.fromJson(Map<String, dynamic> json) {
    final item = json["inventoryItem"] as Map<String, dynamic>? ?? {};
    return JobMaterial(
      id: json["id"] as String,
      inventoryItemName: item["name"] as String? ?? "-",
      quantity: _parseInt(json["quantity"]) ?? 0,
      unitPrice: _parseDouble(json["unitPrice"]) ?? 0,
    );
  }

  /// Yeni bir JobMaterial instance'ı oluşturur, belirtilen alanları günceller
  JobMaterial copyWith({
    String? id,
    String? inventoryItemName,
    int? quantity,
    double? unitPrice,
  }) {
    return JobMaterial(
      id: id ?? this.id,
      inventoryItemName: inventoryItemName ?? this.inventoryItemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class Job {
  Job({
    required this.id,
    required this.title,
    required this.status,
    required this.customer,
    required this.scheduledAt,
    required this.priority,
    required this.assignments,
    this.location,
    this.price,
    this.paymentStatus,
    this.collectedAmount,
    this.notes,
    this.maintenanceDueAt,
    this.materials,
    this.deliveryNote,
    this.deliveryMediaUrls,
  });

  final String id;
  final String title;
  final String status;
  final JobCustomer customer;
  final DateTime? scheduledAt;
  final int? priority;
  final List<JobAssignment> assignments;
  final JobLocation? location;
  final double? price;
  final String? paymentStatus;
  final double? collectedAmount;
  final String? notes;
  final DateTime? maintenanceDueAt;
  final List<JobMaterial>? materials;
  final String? deliveryNote;
  final List<String>? deliveryMediaUrls;

  factory Job.fromJson(Map<String, dynamic> json) {
    final personnelList = (json["personnel"] as List<dynamic>? ?? [])
        .map((e) => JobAssignment.fromJson(e as Map<String, dynamic>))
        .toList();

    final materialsList = (json["materials"] as List<dynamic>? ?? [])
        .map((e) => JobMaterial.fromJson(e as Map<String, dynamic>))
        .toList();

    final deliveryMediaUrls = json["deliveryMediaUrls"] as List<dynamic>?;
    final mediaUrls = deliveryMediaUrls?.map((e) => e.toString()).toList();

    return Job(
      id: json["id"] as String,
      title: json["title"] as String? ?? "İş",
      status: json["status"] as String? ?? "PENDING",
      customer: JobCustomer.fromJson(json["customer"] as Map<String, dynamic>?),
      scheduledAt: DateTime.tryParse(json["scheduledAt"] as String? ?? ""),
          priority: _parseInt(json["priority"]),
      assignments: personnelList,
      location: JobLocation.maybeFromJson(
        json["location"] as Map<String, dynamic>?,
      ),
      price: _parseDouble(json["price"]),
      paymentStatus: json["paymentStatus"] as String?,
      collectedAmount: _parseDouble(json["collectedAmount"]),
      notes: json["notes"] as String?,
      maintenanceDueAt: json["maintenanceDueAt"] != null
          ? DateTime.tryParse(json["maintenanceDueAt"] as String)
          : null,
      materials: materialsList.isNotEmpty ? materialsList : null,
      deliveryNote: json["deliveryNote"] as String?,
      deliveryMediaUrls: mediaUrls,
    );
  }

  /// Yeni bir Job instance'ı oluşturur, belirtilen alanları günceller
  Job copyWith({
    String? id,
    String? title,
    String? status,
    JobCustomer? customer,
    DateTime? scheduledAt,
    int? priority,
    List<JobAssignment>? assignments,
    JobLocation? location,
    double? price,
    String? paymentStatus,
    double? collectedAmount,
    String? notes,
    DateTime? maintenanceDueAt,
    List<JobMaterial>? materials,
    String? deliveryNote,
    List<String>? deliveryMediaUrls,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      assignments: assignments ?? this.assignments,
      location: location ?? this.location,
      price: price ?? this.price,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      notes: notes ?? this.notes,
      maintenanceDueAt: maintenanceDueAt ?? this.maintenanceDueAt,
      materials: materials ?? this.materials,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryMediaUrls: deliveryMediaUrls ?? this.deliveryMediaUrls,
    );
  }
}

class JobLocation {
  JobLocation({required this.latitude, required this.longitude, this.address});

  final double latitude;
  final double longitude;
  final String? address;

  static JobLocation? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final latValue = json["latitude"] ?? json["lat"];
    final lngValue = json["longitude"] ?? json["lng"];

    final lat = _parseDoubleFromAny(latValue);
    final lng = _parseDoubleFromAny(lngValue);

    if (lat == null || lng == null) {
      return null;
    }

    final address =
        json["address"] as String? ??
        json["formattedAddress"] as String? ??
        json["description"] as String?;

    return JobLocation(
      latitude: lat,
      longitude: lng,
      address: address,
    );
  }

  /// Yeni bir JobLocation instance'ı oluşturur, belirtilen alanları günceller
  JobLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return JobLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}

// Helper functions for safe parsing
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

double? _parseDoubleFromAny(dynamic value) {
  return _parseDouble(value);
}
