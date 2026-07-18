/// A product add-on (adicional/complemento) catalog entry scoped to a premise.
///
/// Backend shape (`products/variant/<premId>` → `product_additional`):
/// `{ proda_id, proda_name, proda_available, proda_price, prod_count }`.
///
/// [prodaPrice] is kept as the raw backend string (e.g. `"15.00"`) so it round
/// trips without precision loss; use [priceValue] for the numeric value and
/// [priceDisplay] for the `$`-prefixed display form.
class ProductAdditional {
  final int prodaId;
  final String prodaName;
  final bool prodaAvailable;
  final String prodaPrice;

  /// Number of products linked to this add-on.
  final int prodCount;

  const ProductAdditional({
    required this.prodaId,
    required this.prodaName,
    required this.prodaAvailable,
    required this.prodaPrice,
    required this.prodCount,
  });

  double get priceValue => double.tryParse(prodaPrice) ?? 0;

  String get priceDisplay => '\$${priceValue.toStringAsFixed(2)}';

  factory ProductAdditional.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['proda_price'];
    return ProductAdditional(
      prodaId: (json['proda_id'] as num?)?.toInt() ?? 0,
      prodaName: (json['proda_name'] as String?)?.trim() ?? '',
      prodaAvailable: json['proda_available'] == true,
      prodaPrice: rawPrice == null ? '0.00' : rawPrice.toString().trim(),
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
    );
  }
}
