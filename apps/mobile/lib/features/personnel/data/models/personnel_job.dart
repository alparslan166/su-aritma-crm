class PersonnelJobCustomer {
  PersonnelJobCustomer({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;

  factory PersonnelJobCustomer.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PersonnelJobCustomer(name: "-", phone: "-", address: "-");
    }
    return PersonnelJobCustomer(
      name: json["name"] as String? ?? "-",
      phone: json["phone"] as String? ?? "-",
      address: json["address"] as String? ?? "-",
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

class PersonnelJob {
  PersonnelJob({
    required this.id,
    required this.title,
    required this.status,
    required this.readOnly,
    required this.customer,
    required this.scheduledAt,
    required this.priority,
  });

  final String id;
  final String title;
  final String status;
  final bool readOnly;
  final PersonnelJobCustomer customer;
  final DateTime? scheduledAt;
  final int? priority;

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
