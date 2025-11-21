enum MaintenanceWindow { sevenDays, threeDays, oneDay, overdue }

class MaintenanceReminder {
  MaintenanceReminder({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.dueAt,
    required this.status,
    required this.daysUntilDue,
    this.lastWindowNotified,
  });

  final String id;
  final String jobId;
  final String jobTitle;
  final DateTime dueAt;
  final String status;
  final int daysUntilDue;
  final MaintenanceWindow? lastWindowNotified;

  factory MaintenanceReminder.fromJson(Map<String, dynamic> json) {
    final window = switch (json["lastWindowNotified"] as String? ?? "") {
      "SEVEN_DAYS" => MaintenanceWindow.sevenDays,
      "THREE_DAYS" => MaintenanceWindow.threeDays,
      "ONE_DAY" => MaintenanceWindow.oneDay,
      "OVERDUE" => MaintenanceWindow.overdue,
      _ => null,
    };

    return MaintenanceReminder(
      id: json["id"] as String,
      jobId: json["jobId"] as String,
      jobTitle: json["jobTitle"] as String? ?? "İş",
      dueAt: DateTime.parse(json["dueAt"] as String),
      status: json["status"] as String? ?? "PENDING",
      daysUntilDue: _parseInt(json["daysUntilDue"]) ?? 0,
      lastWindowNotified: window,
    );
  }

  // Helper function for safe parsing
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
