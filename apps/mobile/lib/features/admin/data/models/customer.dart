
class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.email,
    this.location,
    this.jobs,
    this.createdAt,
    this.status = "ACTIVE",
    this.hasDebt = false,
    this.debtAmount,
    this.hasInstallment = false,
    this.installmentCount,
    this.nextDebtDate,
    this.installmentStartDate,
    this.installmentIntervalDays,
    this.remainingDebtAmount,
    this.paidDebtAmount,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String address;
  final CustomerLocation? location;
  final List<CustomerJob>? jobs;
  final DateTime? createdAt;
  final String status;
  final bool hasDebt;
  final double? debtAmount;
  final bool hasInstallment;
  final int? installmentCount;
  final DateTime? nextDebtDate;
  final DateTime? installmentStartDate;
  final int? installmentIntervalDays;
  final double? remainingDebtAmount;
  final double? paidDebtAmount;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final jobsList = json["jobs"] as List<dynamic>?;
    return Customer(
      id: json["id"] as String,
      name: json["name"] as String? ?? "-",
      phone: json["phone"] as String? ?? "",
      email: json["email"] as String?,
      address: json["address"] as String? ?? "",
      location: CustomerLocation.maybeFromJson(json["location"] as Map<String, dynamic>?),
      jobs: jobsList?.map((e) => CustomerJob.fromJson(e as Map<String, dynamic>)).toList(),
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"] as String)
          : null,
      status: json["status"] != null ? (json["status"] as String) : "ACTIVE",
      hasDebt: json["hasDebt"] as bool? ?? false,
      debtAmount: _parseDouble(json["debtAmount"]),
      hasInstallment: json["hasInstallment"] as bool? ?? false,
      installmentCount: json["installmentCount"] as int?,
      nextDebtDate: json["nextDebtDate"] != null
          ? DateTime.tryParse(json["nextDebtDate"] as String)
          : null,
      installmentStartDate: json["installmentStartDate"] != null
          ? DateTime.tryParse(json["installmentStartDate"] as String)
          : null,
      installmentIntervalDays: json["installmentIntervalDays"] as int?,
      remainingDebtAmount: _parseDouble(json["remainingDebtAmount"]),
      paidDebtAmount: _parseDouble(json["paidDebtAmount"]),
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    CustomerLocation? location,
    List<CustomerJob>? jobs,
    DateTime? createdAt,
    String? status,
    bool? hasDebt,
    double? debtAmount,
    bool? hasInstallment,
    int? installmentCount,
    DateTime? nextDebtDate,
    DateTime? installmentStartDate,
    int? installmentIntervalDays,
    double? remainingDebtAmount,
    double? paidDebtAmount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      location: location ?? this.location,
      jobs: jobs ?? this.jobs,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      hasDebt: hasDebt ?? this.hasDebt,
      debtAmount: debtAmount ?? this.debtAmount,
      hasInstallment: hasInstallment ?? this.hasInstallment,
      installmentCount: installmentCount ?? this.installmentCount,
      nextDebtDate: nextDebtDate ?? this.nextDebtDate,
      installmentStartDate: installmentStartDate ?? this.installmentStartDate,
      installmentIntervalDays: installmentIntervalDays ?? this.installmentIntervalDays,
      remainingDebtAmount: remainingDebtAmount ?? this.remainingDebtAmount,
      paidDebtAmount: paidDebtAmount ?? this.paidDebtAmount,
    );
  }

  bool get hasOverduePayment {
    // 1. Müşterinin kendi borç bilgilerini kontrol et
    if (hasDebt && nextDebtDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final debtDate = DateTime(
        nextDebtDate!.year,
        nextDebtDate!.month,
        nextDebtDate!.day,
      );
      // Borç ödeme tarihi geçmişse (bugün dahil)
      if (debtDate.isBefore(today) || debtDate == today) {
        // Kalan borç varsa ödemesi geçmiş
        if (remainingDebtAmount != null && remainingDebtAmount! > 0) {
          return true;
        }
      }
    }
    
    // 2. Job'lardaki ödeme durumunu kontrol et
    if (jobs != null && jobs!.isNotEmpty) {
      final hasUnpaidJob = jobs!.any((job) {
        if (job.price == null) return false;
        final collected = job.collectedAmount ?? 0.0;
        final remaining = job.price! - collected;
        // Borç varsa ve ödeme durumu NOT_PAID veya PARTIAL ise
        if (remaining > 0) {
          return job.paymentStatus == "NOT_PAID" || job.paymentStatus == "PARTIAL";
        }
        return false;
      });
      if (hasUnpaidJob) return true;
    }
    
    return false;
  }

  bool get hasUpcomingMaintenance {
    if (jobs == null) return false;
    return jobs!.any((job) {
      if (job.maintenanceDueAt == null) return false;
      final now = DateTime.now();
      final dueDate = job.maintenanceDueAt!;
      // Geçmiş veya 30 gün içinde olan bakımlar
      final daysUntilDue = dueDate.difference(now).inDays;
      return daysUntilDue <= 30; // Geçmiş olanlar da dahil (negatif değerler)
    });
  }

  /// Sonraki bakım tarihini döndürür (en yakın)
  DateTime? get nextMaintenanceDate {
    if (jobs == null) return null;
    DateTime? nearest;
    for (final job in jobs!) {
      if (job.maintenanceDueAt != null) {
        if (nearest == null || job.maintenanceDueAt!.isBefore(nearest)) {
          nearest = job.maintenanceDueAt;
        }
      }
    }
    return nearest;
  }

  /// Kalan süreyi ay ve gün olarak döndürür
  String? get maintenanceTimeRemaining {
    final nextDate = nextMaintenanceDate;
    if (nextDate == null) return null;
    final now = DateTime.now();
    final difference = nextDate.difference(now);
    final totalDays = difference.inDays;
    
    if (totalDays < 0) {
      // Geçmiş
      final overdueDays = -totalDays;
      final months = overdueDays ~/ 30;
      final days = overdueDays % 30;
      if (months > 0) {
        return "$months ay $days gün geçti";
      }
      return "$days gün geçti";
    }
    
    final months = totalDays ~/ 30;
    final days = totalDays % 30;
    if (months > 0) {
      return "$months ay $days gün kaldı";
    }
    return "$days gün kaldı";
  }

  bool get hasOverdueInstallment {
    // Borcu olan ve ödeme tarihi geçmiş müşteriler (taksit olsun veya olmasın)
    if (!hasDebt || nextDebtDate == null) return false;
    return nextDebtDate!.isBefore(DateTime.now());
  }
}

class CustomerLocation {
  CustomerLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;

  static CustomerLocation? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final latValue = json["latitude"] ?? json["lat"];
    final lngValue = json["longitude"] ?? json["lng"];
    final lat = _parseDouble(latValue);
    final lng = _parseDouble(lngValue);
    if (lat == null || lng == null) return null;
    return CustomerLocation(
      latitude: lat,
      longitude: lng,
      address: json["address"] as String?,
    );
  }
}

class CustomerJob {
  CustomerJob({
    required this.id,
    required this.title,
    required this.status,
    this.price,
    this.collectedAmount,
    this.paymentStatus,
    this.maintenanceDueAt,
  });

  final String id;
  final String title;
  final String status;
  final double? price;
  final double? collectedAmount;
  final String? paymentStatus;
  final DateTime? maintenanceDueAt;

  factory CustomerJob.fromJson(Map<String, dynamic> json) {
    final reminders = json["maintenanceReminders"] as List<dynamic>? ?? [];
    DateTime? maintenanceDueAt;
    if (reminders.isNotEmpty) {
      final reminder = reminders[0] as Map<String, dynamic>?;
      if (reminder != null) {
        maintenanceDueAt = DateTime.tryParse(reminder["dueAt"] as String? ?? "");
      }
    }
    return CustomerJob(
      id: json["id"] as String,
      title: json["title"] as String? ?? "-",
      status: json["status"] as String? ?? "PENDING",
      price: _parseDouble(json["price"]),
      collectedAmount: _parseDouble(json["collectedAmount"]),
      paymentStatus: json["paymentStatus"] as String?,
      maintenanceDueAt: maintenanceDueAt,
    );
  }
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

