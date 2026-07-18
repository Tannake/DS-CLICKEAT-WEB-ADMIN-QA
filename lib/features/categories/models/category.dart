/// A product category (sección del menú) scoped to a premise.
///
/// Backend shape (`products/category/<premId>`):
/// `{ prodc_id, prodc_name, prodc_order, prodc_available, prod_count }`.
class Category {
  final int prodcId;
  final String prodcName;
  final int prodcOrder;
  final bool prodcAvailable;

  /// Number of products linked to this category.
  final int prodCount;

  const Category({
    required this.prodcId,
    required this.prodcName,
    required this.prodcOrder,
    required this.prodcAvailable,
    required this.prodCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      prodcId: (json['prodc_id'] as num?)?.toInt() ?? 0,
      prodcName: (json['prodc_name'] as String?)?.trim() ?? '',
      prodcOrder: (json['prodc_order'] as num?)?.toInt() ?? 0,
      prodcAvailable: json['prodc_available'] == true,
      prodCount: (json['prod_count'] as num?)?.toInt() ?? 0,
    );
  }
}
