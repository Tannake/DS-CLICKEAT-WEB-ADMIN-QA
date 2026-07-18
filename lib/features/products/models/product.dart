class Product {
  final int prodId;
  final String prodName;
  final String prodDesc;
  final bool prodAvailable;
  final int prodOrder;
  final bool prodAdult;
  final String prodImageUrl;
  final String prodPreparationArea;
  final String prodCategory;

  /// Price range as sent by the backend, e.g. "149.00 - 1699.00" (or a single
  /// "149.00" when all variants share the same price). Use [priceDisplay] for
  /// the formatted, currency-prefixed string.
  final String prodPrice;

  /// Total stock across all of the product's variants (already summed backend).
  final int prodStock;

  const Product({
    required this.prodId,
    required this.prodName,
    required this.prodDesc,
    required this.prodAvailable,
    required this.prodOrder,
    required this.prodAdult,
    required this.prodImageUrl,
    required this.prodPreparationArea,
    required this.prodCategory,
    required this.prodPrice,
    required this.prodStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      prodId: (json['prod_id'] as num).toInt(),
      prodName: (json['prod_name'] ?? '') as String,
      prodDesc: (json['prod_desc'] ?? '') as String,
      prodAvailable: json['prod_available'] == true,
      prodOrder: (json['prod_order'] as num?)?.toInt() ?? 0,
      prodAdult: json['prod_adult'] == true,
      prodImageUrl: (json['prod_image_url'] ?? '') as String,
      prodPreparationArea: (json['prod_preparation_area'] ?? '') as String,
      prodCategory: (json['prod_category'] ?? '') as String,
      prodPrice: (json['prod_price'] ?? '').toString(),
      prodStock: (json['prod_stock'] as num?)?.toInt() ?? 0,
    );
  }

  /// Price formatted for display, prefixing each amount with "$":
  /// "149.00 - 1699.00" → "$149.00 - $1699.00". Returns "—" when empty.
  String get priceDisplay {
    final raw = prodPrice.trim();
    if (raw.isEmpty) return '—';
    return raw.split(' - ').map((p) => '\$${p.trim()}').join(' - ');
  }
}
