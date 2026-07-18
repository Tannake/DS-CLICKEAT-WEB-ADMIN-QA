/// A product size (tamaño) catalog entry scoped to a premise.
///
/// Backend shape (`products/variant/<premId>` → `product_size`):
/// `{ prods_id, prods_name, prods_available, prod_count }`.
class ProductSize {
  final int prodsId;
  final String prodsName;
  final bool prodsAvailable;

  /// Number of products linked to this size.
  final int prodCount;

  const ProductSize({
    required this.prodsId,
    required this.prodsName,
    required this.prodsAvailable,
    required this.prodCount,
  });

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    return ProductSize(
      prodsId: (json['prods_id'] as num?)?.toInt() ?? 0,
      prodsName: (json['prods_name'] as String?)?.trim() ?? '',
      prodsAvailable: json['prods_available'] == true,
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
    );
  }
}
