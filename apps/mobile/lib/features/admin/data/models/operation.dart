class Operation {
  Operation({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      id: json["id"] as String,
      name: json["name"] as String? ?? "-",
      description: json["description"] as String?,
      isActive: json["isActive"] as bool? ?? true,
    );
  }

  Operation copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return Operation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}

