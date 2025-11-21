class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stockQty,
    required this.criticalThreshold,
    required this.unitPrice,
    required this.isActive,
    this.photoUrl,
    this.sku,
    this.unit,
    this.reorderPoint,
    this.reorderQuantity,
  });

  final String id;
  final String name;
  final String category;
  final int stockQty;
  final int criticalThreshold;
  final double unitPrice;
  final bool isActive;
  final String? photoUrl;
  final String? sku;
  final String? unit;
  final int? reorderPoint;
  final int? reorderQuantity;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json["id"] as String,
      name: json["name"] as String? ?? "-",
      category: json["category"] as String? ?? "-",
      stockQty: _parseInt(json["stockQty"]) ?? 0,
      criticalThreshold: _parseInt(json["criticalThreshold"]) ?? 0,
      unitPrice: _parseDouble(json["unitPrice"]) ?? 0,
      isActive: json["isActive"] as bool? ?? true,
      photoUrl: json["photoUrl"] as String?,
      sku: json["sku"] as String?,
      unit: json["unit"] as String?,
      reorderPoint: _parseInt(json["reorderPoint"]),
      reorderQuantity: _parseInt(json["reorderQuantity"]),
    );
  }

  // Helper functions for safe parsing
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

  bool get isBelowThreshold => stockQty <= criticalThreshold;

  /// Yeni bir InventoryItem instance'ı oluşturur, belirtilen alanları günceller
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? stockQty,
    int? criticalThreshold,
    double? unitPrice,
    bool? isActive,
    String? photoUrl,
    String? sku,
    String? unit,
    int? reorderPoint,
    int? reorderQuantity,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      stockQty: stockQty ?? this.stockQty,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      unitPrice: unitPrice ?? this.unitPrice,
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      reorderQuantity: reorderQuantity ?? this.reorderQuantity,
    );
  }
}
