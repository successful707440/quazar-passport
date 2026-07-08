class SvodService {
  final String code;
  final String name;
  final String? description;
  final String? categoryName;
  final int basePrice;
  final int minQuantity;
  final int maxQuantity;

  SvodService({
    required this.code,
    required this.name,
    this.description,
    this.categoryName,
    required this.basePrice,
    required this.minQuantity,
    required this.maxQuantity,
  });

  factory SvodService.fromJson(Map<String, dynamic> json) {
    return SvodService(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      categoryName: json['category_name'] as String?,
      basePrice: (json['base_price'] as num?)?.toInt() ?? 0,
      minQuantity: (json['min_quantity'] as num?)?.toInt() ?? 1,
      maxQuantity: (json['max_quantity'] as num?)?.toInt() ?? 100,
    );
  }
}
