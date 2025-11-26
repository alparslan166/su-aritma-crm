class Personnel {
  Personnel({
    required this.id,
    this.personnelId,
    required this.name,
    required this.phone,
    required this.email,
    required this.status,
    required this.loginCode,
    required this.hireDate,
    required this.canShareLocation,
    this.photoUrl,
    this.lastKnownLocation,
    this.leaves,
  });

  final String id;
  final String? personnelId;
  final String name;
  final String phone;
  final String? email;
  final String status;
  final String loginCode;
  final DateTime hireDate;
  final bool canShareLocation;
  final String? photoUrl;
  final PersonnelLocation? lastKnownLocation;
  final List<PersonnelLeave>? leaves;

  // İzinli olup olmadığını kontrol et
  bool get isOnLeave {
    if (leaves == null || leaves!.isEmpty) return false;
    final now = DateTime.now();
    // Sadece bugünün tarihini kullan (saat bilgisini sıfırla)
    final today = DateTime(now.year, now.month, now.day);
    return leaves!.any((leave) {
      // İzin başlangıç ve bitiş tarihlerini sadece tarih olarak al (saat bilgisini sıfırla)
      final start = DateTime(
        leave.startDate.year,
        leave.startDate.month,
        leave.startDate.day,
      );
      final end = DateTime(
        leave.endDate.year,
        leave.endDate.month,
        leave.endDate.day,
      );
      // Bugün izin aralığında mı kontrol et (başlangıç dahil, bitiş dahil)
      // today >= start && today <= end
      return today.compareTo(start) >= 0 && today.compareTo(end) <= 0;
    });
  }

  factory Personnel.fromJson(Map<String, dynamic> json) {
    final leavesList = json["leaves"] as List<dynamic>?;
    return Personnel(
      id: json["id"] as String,
      personnelId: json["personnelId"] as String?,
      name: json["name"] as String? ?? "-",
      phone: json["phone"] as String? ?? "",
      email: json["email"] as String?,
      status: json["status"] as String? ?? "UNKNOWN",
      loginCode: json["loginCode"] as String? ?? "",
      hireDate:
          DateTime.tryParse(json["hireDate"] as String? ?? "") ??
          DateTime.now(),
      canShareLocation: json["canShareLocation"] as bool? ?? false,
      photoUrl: json["photoUrl"] as String?,
      lastKnownLocation: PersonnelLocation.fromJson(
        json["lastKnownLocation"] as Map<String, dynamic>?,
      ),
      leaves: leavesList?.map((e) => PersonnelLeave.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Yeni bir Personnel instance'ı oluşturur, belirtilen alanları günceller
  Personnel copyWith({
    String? id,
    String? personnelId,
    String? name,
    String? phone,
    String? email,
    String? status,
    String? loginCode,
    DateTime? hireDate,
    bool? canShareLocation,
    String? photoUrl,
    PersonnelLocation? lastKnownLocation,
    List<PersonnelLeave>? leaves,
  }) {
    return Personnel(
      id: id ?? this.id,
      personnelId: personnelId ?? this.personnelId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      loginCode: loginCode ?? this.loginCode,
      hireDate: hireDate ?? this.hireDate,
      canShareLocation: canShareLocation ?? this.canShareLocation,
      photoUrl: photoUrl ?? this.photoUrl,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      leaves: leaves ?? this.leaves,
    );
  }
}

class PersonnelLeave {
  PersonnelLeave({
    required this.id,
    required this.personnelId,
    required this.startDate,
    required this.endDate,
    this.reason,
  });

  final String id;
  final String personnelId;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;

  factory PersonnelLeave.fromJson(Map<String, dynamic> json) {
    return PersonnelLeave(
      id: json["id"] as String,
      personnelId: json["personnelId"] as String,
      startDate: DateTime.parse(json["startDate"] as String),
      endDate: DateTime.parse(json["endDate"] as String),
      reason: json["reason"] as String?,
    );
  }
}

class PersonnelLocation {
  PersonnelLocation({
    required this.lat,
    required this.lng,
    this.jobId,
    this.timestamp,
  });

  final double lat;
  final double lng;
  final String? jobId;
  final DateTime? timestamp;

  static PersonnelLocation? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final latValue = json["lat"];
    final lngValue = json["lng"];
    final lat = _parseDouble(latValue);
    final lng = _parseDouble(lngValue);
    if (lat == null || lng == null) return null;
    return PersonnelLocation(
      lat: lat,
      lng: lng,
      jobId: json["jobId"] as String?,
      timestamp: DateTime.tryParse(json["startedAt"] as String? ?? ""),
    );
  }

  /// Yeni bir PersonnelLocation instance'ı oluşturur, belirtilen alanları günceller
  PersonnelLocation copyWith({
    double? lat,
    double? lng,
    String? jobId,
    DateTime? timestamp,
  }) {
    return PersonnelLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      jobId: jobId ?? this.jobId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // Helper function for safe parsing
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
