class PersonnelJobCustomer {
  PersonnelJobCustomer({
    required this.name,
    required this.phone,
    required this.address,
    this.location,
  });

  final String name;
  final String phone;
  final String address;
  final Map<String, dynamic>? location;

  factory PersonnelJobCustomer.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PersonnelJobCustomer(name: "-", phone: "-", address: "-");
    }
    return PersonnelJobCustomer(
      name: json["name"] as String? ?? "-",
      phone: json["phone"] as String? ?? "-",
      address: json["address"] as String? ?? "-",
      location: json["location"] as Map<String, dynamic>?,
    );
  }
}

class PersonnelJobAssignment {
  PersonnelJobAssignment({required this.startedAt, required this.deliveredAt});

  final DateTime? startedAt;
  final DateTime? deliveredAt;

  factory PersonnelJobAssignment.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PersonnelJobAssignment(startedAt: null, deliveredAt: null);
    }
    return PersonnelJobAssignment(
      startedAt: DateTime.tryParse(json["startedAt"] as String? ?? ""),
      deliveredAt: DateTime.tryParse(json["deliveredAt"] as String? ?? ""),
    );
  }
}

class PersonnelJobMaterial {
  PersonnelJobMaterial({
    required this.quantity,
    required this.inventoryItem,
  });

  final int quantity;
  final PersonnelJobMaterialItem inventoryItem;

  factory PersonnelJobMaterial.fromJson(Map<String, dynamic> json) {
    return PersonnelJobMaterial(
      quantity: (json["quantity"] as num?)?.toInt() ?? 0,
      inventoryItem: PersonnelJobMaterialItem.fromJson(
        json["inventoryItem"] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class PersonnelJobMaterialItem {
  PersonnelJobMaterialItem({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory PersonnelJobMaterialItem.fromJson(Map<String, dynamic> json) {
    return PersonnelJobMaterialItem(
      id: json["id"] as String? ?? "",
      name: json["name"] as String? ?? "-",
    );
  }
}

class PersonnelJob {
  PersonnelJob({
    required this.id,
    required this.title,
    required this.status,
    required this.readOnly,
    required this.customer,
    required this.scheduledAt,
    required this.priority,
    this.materials,
  });

  final String id;
  final String title;
  final String status;
  final bool readOnly;
  final PersonnelJobCustomer customer;
  final DateTime? scheduledAt;
  final int? priority;
  final List<PersonnelJobMaterial>? materials;

  factory PersonnelJob.fromJson(Map<String, dynamic> json) {
    return PersonnelJob(
      id: json["id"] as String,
      title: json["title"] as String? ?? "İş",
      status: json["status"] as String? ?? "PENDING",
      readOnly: json["readOnly"] as bool? ?? false,
      customer: PersonnelJobCustomer.fromJson(
        json["customer"] as Map<String, dynamic>?,
      ),
      scheduledAt: DateTime.tryParse(json["scheduledAt"] as String? ?? ""),
      priority: json["priority"] as int?,
      materials: (json["materials"] as List<dynamic>?)
          ?.map((e) => PersonnelJobMaterial.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PersonnelJobDetail {
  PersonnelJobDetail({required this.job, required this.assignment});

  final PersonnelJob job;
  final PersonnelJobAssignment assignment;

  factory PersonnelJobDetail.fromJson(Map<String, dynamic> json) {
    return PersonnelJobDetail(
      job: PersonnelJob.fromJson(json),
      assignment: PersonnelJobAssignment.fromJson(
        json["assignment"] as Map<String, dynamic>?,
      ),
    );
  }
}
