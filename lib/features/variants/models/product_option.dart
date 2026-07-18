/// A product option (opción/modificación) catalog entry scoped to a premise.
///
/// Backend shape (`products/variant/<premId>` → `product_option`):
/// `{ prodo_id, prodo_name, prodo_available, prod_count }`.
class ProductOption {
  final int prodoId;
  final String prodoName;
  final bool prodoAvailable;

  /// Number of products linked to this option.
  final int prodCount;

  const ProductOption({
    required this.prodoId,
    required this.prodoName,
    required this.prodoAvailable,
    required this.prodCount,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      prodoId: (json['prodo_id'] as num?)?.toInt() ?? 0,
      prodoName: (json['prodo_name'] as String?)?.trim() ?? '',
      prodoAvailable: json['prodo_available'] == true,
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
    );
  }
}
