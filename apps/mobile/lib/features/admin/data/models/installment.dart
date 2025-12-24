/// Taksit modeli - müşteri taksitli ödemelerini takip eder
class Installment {
  Installment({
    required this.id,
    required this.customerId,
    required this.installmentNo,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    this.paidAt,
    this.invoiceId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final int installmentNo;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime? paidAt;
  final String? invoiceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: json["id"] as String,
      customerId: json["customerId"] as String,
      installmentNo: json["installmentNo"] as int,
      amount: _parseDouble(json["amount"]) ?? 0.0,
      dueDate: DateTime.parse(json["dueDate"] as String),
      isPaid: json["isPaid"] as bool? ?? false,
      paidAt: json["paidAt"] != null
          ? DateTime.parse(json["paidAt"] as String)
          : null,
      invoiceId: json["invoiceId"] as String?,
      createdAt: DateTime.parse(json["createdAt"] as String),
      updatedAt: DateTime.parse(json["updatedAt"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "customerId": customerId,
      "installmentNo": installmentNo,
      "amount": amount,
      "dueDate": dueDate.toUtc().toIso8601String(),
      "isPaid": isPaid,
      "paidAt": paidAt?.toUtc().toIso8601String(),
      "invoiceId": invoiceId,
      "createdAt": createdAt.toUtc().toIso8601String(),
      "updatedAt": updatedAt.toUtc().toIso8601String(),
    };
  }
}

// Safe double parsing helper
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
