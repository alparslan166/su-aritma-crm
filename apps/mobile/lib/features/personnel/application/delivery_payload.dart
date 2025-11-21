class DeliveryMaterial {
  DeliveryMaterial({
    required this.inventoryItemId,
    required this.quantity,
  });

  final String inventoryItemId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {
      "inventoryItemId": inventoryItemId,
      "quantity": quantity,
    };
  }
}

class DeliveryPayload {
  DeliveryPayload({
    this.note,
    this.collectedAmount,
    this.maintenanceIntervalMonths,
    this.photoUrls = const [],
    this.usedMaterials = const [],
  });

  final String? note;
  final double? collectedAmount;
  final int? maintenanceIntervalMonths;
  final List<String> photoUrls;
  final List<DeliveryMaterial> usedMaterials;

  Map<String, dynamic> toJson() {
    return {
      if (note != null && note!.isNotEmpty) "note": note,
      if (collectedAmount != null) "collectedAmount": collectedAmount,
      if (maintenanceIntervalMonths != null)
        "maintenanceIntervalMonths": maintenanceIntervalMonths,
      if (photoUrls.isNotEmpty) "photoUrls": photoUrls,
      if (usedMaterials.isNotEmpty)
        "usedMaterials": usedMaterials.map((m) => m.toJson()).toList(),
    };
  }
}
