class Invoice {
  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.jobTitle,
    required this.jobDate,
    required this.subtotal,
    required this.total,
    this.customerEmail,
    this.tax,
    this.notes,
    this.isDraft = true,
    this.jobId,
  });

  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? customerEmail;
  final String jobTitle;
  final DateTime jobDate;
  final double subtotal;
  final double? tax;
  final double total;
  final String? notes;
  final bool isDraft;
  final String? jobId;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json["id"] as String,
      invoiceNumber: json["invoiceNumber"] as String,
      customerName: json["customerName"] as String,
      customerPhone: json["customerPhone"] as String,
      customerAddress: json["customerAddress"] as String,
      customerEmail: json["customerEmail"] as String?,
      jobTitle: json["jobTitle"] as String,
      jobDate: DateTime.parse(json["jobDate"] as String),
      subtotal: (json["subtotal"] as num).toDouble(),
      tax: json["tax"] != null ? (json["tax"] as num).toDouble() : null,
      total: (json["total"] as num).toDouble(),
      notes: json["notes"] as String?,
      isDraft: json["isDraft"] as bool? ?? true,
      jobId: json["jobId"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "invoiceNumber": invoiceNumber,
      "customerName": customerName,
      "customerPhone": customerPhone,
      "customerAddress": customerAddress,
      "customerEmail": customerEmail,
      "jobTitle": jobTitle,
      "jobDate": jobDate.toUtc().toIso8601String(),
      "subtotal": subtotal,
      "tax": tax,
      "total": total,
      "notes": notes,
      "isDraft": isDraft,
      "jobId": jobId,
    };
  }
}

