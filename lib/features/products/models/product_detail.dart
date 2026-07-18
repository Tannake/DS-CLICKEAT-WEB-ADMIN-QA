/// One category available for the product (`product_category` entry).
class CategoryOption {
  final int prodcId;
  final String prodcName;
  final int prodcOrder;
  final bool prodcAvailable;

  const CategoryOption({
    required this.prodcId,
    required this.prodcName,
    required this.prodcOrder,
    required this.prodcAvailable,
  });

  factory CategoryOption.fromJson(Map<String, dynamic> json) {
    return CategoryOption(
      prodcId: (json['prodc_id'] as num?)?.toInt() ?? 0,
      prodcName: (json['prodc_name'] ?? '') as String,
      prodcOrder: (json['prodc_order'] as num?)?.toInt() ?? 0,
      prodcAvailable: json['prodc_available'] == true,
    );
  }
}

/// One preparation area / kitchen station (`product_preparation_area` entry).
class PrepAreaOption {
  final int prepId;
  final String prepName;
  final bool prepAvailable;

  const PrepAreaOption({
    required this.prepId,
    required this.prepName,
    required this.prepAvailable,
  });

  factory PrepAreaOption.fromJson(Map<String, dynamic> json) {
    return PrepAreaOption(
      prepId: (json['prep_id'] as num?)?.toInt() ?? 0,
      prepName: (json['prep_name'] ?? '') as String,
      prepAvailable: json['prep_available'] == true,
    );
  }
}

/// One selectable size from the catalog (`product_size` entry).
class SizeOption {
  final int prodsId;
  final String prodsName;
  final bool prodsAvailable;

  const SizeOption({
    required this.prodsId,
    required this.prodsName,
    required this.prodsAvailable,
  });

  factory SizeOption.fromJson(Map<String, dynamic> json) {
    return SizeOption(
      prodsId: (json['prods_id'] as num?)?.toInt() ?? 0,
      prodsName: (json['prods_name'] ?? '') as String,
      prodsAvailable: json['prods_available'] == true,
    );
  }
}

/// One selectable option from the catalog (`product_option` entry).
class OptionOption {
  final int prodoId;
  final String prodoName;
  final bool prodoAvailable;

  const OptionOption({
    required this.prodoId,
    required this.prodoName,
    required this.prodoAvailable,
  });

  factory OptionOption.fromJson(Map<String, dynamic> json) {
    return OptionOption(
      prodoId: (json['prodo_id'] as num?)?.toInt() ?? 0,
      prodoName: (json['prodo_name'] ?? '') as String,
      prodoAvailable: json['prodo_available'] == true,
    );
  }
}

/// One add-on product from the catalog (`product_additional` entry): a product
/// that can be linked to others as an extra.
class AdditionalOption {
  final int prodaId;
  final String prodaName;
  final bool prodaAvailable;

  const AdditionalOption({
    required this.prodaId,
    required this.prodaName,
    required this.prodaAvailable,
  });

  factory AdditionalOption.fromJson(Map<String, dynamic> json) {
    return AdditionalOption(
      prodaId: (json['proda_id'] as num?)?.toInt() ?? 0,
      prodaName: (json['proda_name'] ?? '') as String,
      prodaAvailable: json['proda_available'] == true,
    );
  }
}

/// One size×option variant of the product (`product_collect` entry).
class ProductVariant {
  final int prodsId;
  final String prodsName;
  final int prodoId;
  final String prodoName;
  final String prodPrice;
  final int prodStock;
  final bool prodAvailable;

  const ProductVariant({
    required this.prodsId,
    required this.prodsName,
    required this.prodoId,
    required this.prodoName,
    required this.prodPrice,
    required this.prodStock,
    required this.prodAvailable,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      prodsId: (json['prods_id'] as num?)?.toInt() ?? 0,
      prodsName: (json['prods_name'] ?? '') as String,
      prodoId: (json['prodo_id'] as num?)?.toInt() ?? 0,
      prodoName: (json['prodo_name'] ?? '') as String,
      prodPrice: (json['prod_price'] ?? '0.00').toString(),
      prodStock: (json['prod_stock'] as num?)?.toInt() ?? 0,
      prodAvailable: json['prod_available'] == true,
    );
  }

  ProductVariant copyWith({
    int? prodsId,
    String? prodsName,
    int? prodoId,
    String? prodoName,
    String? prodPrice,
    int? prodStock,
    bool? prodAvailable,
  }) {
    return ProductVariant(
      prodsId: prodsId ?? this.prodsId,
      prodsName: prodsName ?? this.prodsName,
      prodoId: prodoId ?? this.prodoId,
      prodoName: prodoName ?? this.prodoName,
      prodPrice: prodPrice ?? this.prodPrice,
      prodStock: prodStock ?? this.prodStock,
      prodAvailable: prodAvailable ?? this.prodAvailable,
    );
  }

  /// Size name, or "—" for the base variant (no size).
  String get sizeLabel => prodsName.trim().isEmpty ? '—' : prodsName;

  /// Option name, or "—" for variants without options.
  String get optionLabel => prodoName.trim().isEmpty ? '—' : prodoName;
}

/// Full detail of a product, returned by `products/detail/<premId>/<prodId>`.
class ProductDetail {
  final int prodId;
  final String prodName;
  final String prodDesc;
  final bool prodAvailable;
  final int prodOrder;
  final bool prodAdult;
  final String prodImageUrl;
  final int prodPreparationAreaId;
  final int prodCategoryId;
  final List<CategoryOption> categories;
  final List<PrepAreaOption> prepAreas;
  final List<SizeOption> sizes;
  final List<OptionOption> options;

  /// Catalog of add-on products that can be linked (`product_additional`).
  final List<AdditionalOption> additionals;

  /// Ids of the add-ons currently linked to this product
  /// (`product_additional_collect`).
  final Set<int> linkedAdditionalIds;
  final List<ProductVariant> variants;

  const ProductDetail({
    required this.prodId,
    required this.prodName,
    required this.prodDesc,
    required this.prodAvailable,
    required this.prodOrder,
    required this.prodAdult,
    required this.prodImageUrl,
    required this.prodPreparationAreaId,
    required this.prodCategoryId,
    required this.categories,
    required this.prepAreas,
    required this.sizes,
    required this.options,
    required this.additionals,
    required this.linkedAdditionalIds,
    required this.variants,
  });

  ProductDetail copyWith({
    String? prodName,
    String? prodDesc,
    bool? prodAvailable,
    int? prodOrder,
    bool? prodAdult,
    String? prodImageUrl,
    int? prodPreparationAreaId,
    int? prodCategoryId,
    List<ProductVariant>? variants,
    Set<int>? linkedAdditionalIds,
  }) {
    return ProductDetail(
      prodId: prodId,
      prodName: prodName ?? this.prodName,
      prodDesc: prodDesc ?? this.prodDesc,
      prodAvailable: prodAvailable ?? this.prodAvailable,
      prodOrder: prodOrder ?? this.prodOrder,
      prodAdult: prodAdult ?? this.prodAdult,
      prodImageUrl: prodImageUrl ?? this.prodImageUrl,
      prodPreparationAreaId:
          prodPreparationAreaId ?? this.prodPreparationAreaId,
      prodCategoryId: prodCategoryId ?? this.prodCategoryId,
      categories: categories,
      prepAreas: prepAreas,
      sizes: sizes,
      options: options,
      additionals: additionals,
      linkedAdditionalIds: linkedAdditionalIds ?? this.linkedAdditionalIds,
      variants: variants ?? this.variants,
    );
  }

  /// Shared body of the update/create payloads: header fields, flattened
  /// variants and linked add-on ids. Excludes `prem_id`/`prod_id` so callers
  /// can add the right identity keys for their endpoint.
  Map<String, dynamic> _bodyJson() {
    return {
      'prod_name': prodName,
      'prod_desc': prodDesc,
      'prod_available': prodAvailable,
      'prod_order': prodOrder,
      'prod_adult': prodAdult,
      'prod_image_url': prodImageUrl,
      'prod_preparation_area': prodPreparationAreaId,
      'prod_category': prodCategoryId,
      'product_collect': [
        for (final v in variants)
          {
            'prods_id': v.prodsId,
            'prodo_id': v.prodoId,
            'prod_price': num.tryParse(v.prodPrice) ?? 0,
            'prod_stock': v.prodStock,
            'prod_available': v.prodAvailable,
          },
      ],
      'product_additional': linkedAdditionalIds.toList(),
    };
  }

  /// Builds the payload posted to `products/update` on save.
  Map<String, dynamic> toBackendJson(int premId) {
    return {'prem_id': premId, 'prod_id': prodId, ..._bodyJson()};
  }

  /// Builds the payload posted to `products/create`. Identical to
  /// [toBackendJson] but without `prod_id` (the backend assigns it).
  Map<String, dynamic> toCreateJson(int premId) {
    return {'prem_id': premId, ..._bodyJson()};
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      prodId: (json['prod_id'] as num).toInt(),
      prodName: (json['prod_name'] ?? '') as String,
      prodDesc: (json['prod_desc'] ?? '') as String,
      prodAvailable: json['prod_available'] == true,
      prodOrder: (json['prod_order'] as num?)?.toInt() ?? 0,
      prodAdult: json['prod_adult'] == true,
      prodImageUrl: (json['prod_image_url'] ?? '') as String,
      // `prod_preparation_area` is sent as an int id; `prod_category` as a
      // string id (e.g. "751") — parse both to int for catalog lookups.
      prodPreparationAreaId:
          int.tryParse(json['prod_preparation_area'].toString()) ?? 0,
      prodCategoryId: int.tryParse(json['prod_category'].toString()) ?? 0,
      categories: (json['product_category'] as List? ?? [])
          .map(
            (e) => CategoryOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      prepAreas: (json['product_preparation_area'] as List? ?? [])
          .map(
            (e) => PrepAreaOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      sizes: (json['product_size'] as List? ?? [])
          .map((e) => SizeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      options: (json['product_option'] as List? ?? [])
          .map(
            (e) => OptionOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      additionals: (json['product_additional'] as List? ?? [])
          .map(
            (e) =>
                AdditionalOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      linkedAdditionalIds: {
        for (final e in (json['product_additional_collect'] as List? ?? []))
          ((e as Map)['proda_id'] as num?)?.toInt() ?? 0,
      },
      variants: (json['product_collect'] as List? ?? [])
          .map(
            (e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  /// Builds a blank product carrying only the premise catalogs, used to seed
  /// the "new product" form. [json] is the `result` of `products/master-data`.
  factory ProductDetail.fromMasterData(Map<String, dynamic> json) {
    return ProductDetail(
      prodId: 0,
      prodName: '',
      prodDesc: '',
      prodAvailable: true,
      prodOrder: 0,
      prodAdult: false,
      prodImageUrl: '',
      prodPreparationAreaId: 0,
      prodCategoryId: 0,
      categories: (json['product_category'] as List? ?? [])
          .map(
            (e) => CategoryOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      prepAreas: (json['product_preparation_area'] as List? ?? [])
          .map(
            (e) => PrepAreaOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      sizes: (json['product_size'] as List? ?? [])
          .map((e) => SizeOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      options: (json['product_option'] as List? ?? [])
          .map(
            (e) => OptionOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      additionals: (json['product_additional'] as List? ?? [])
          .map(
            (e) =>
                AdditionalOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      linkedAdditionalIds: const {},
      variants: const [],
    );
  }

  /// Display name of the product's category, or "—" if not found.
  String get categoryName {
    for (final c in categories) {
      if (c.prodcId == prodCategoryId) return c.prodcName;
    }
    return '—';
  }

  /// Display name of the product's preparation area, or "—" if not found.
  String get prepAreaName {
    for (final a in prepAreas) {
      if (a.prepId == prodPreparationAreaId) return a.prepName;
    }
    return '—';
  }
}
