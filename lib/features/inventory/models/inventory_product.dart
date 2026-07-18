/// Stock threshold (units) at or under which a variant/product is flagged
/// "Stock bajo". Mirrors the threshold used on the Products page.
const int kLowStockThreshold = 5;

/// Status of a single variant (size × option) or, when aggregated, of a whole
/// product. Priority order: not available → out → low → ok.
enum VariantStatus { disponible, stockBajo, agotado, noDisponible }

extension VariantStatusX on VariantStatus {
  String get label {
    switch (this) {
      case VariantStatus.disponible:
        return 'Disponible';
      case VariantStatus.stockBajo:
        return 'Stock Bajo';
      case VariantStatus.agotado:
        return 'Agotado';
      case VariantStatus.noDisponible:
        return 'No Disponible';
    }
  }

  /// Filter pill order shown in the toolbar (matches the Products page status
  /// filter, plus the leading "Todos").
  static const List<String> filterLabels = [
    'Todos',
    'Disponible',
    'No Disponible',
    'Stock Bajo',
    'Agotado',
  ];
}

class InventorySize {
  final int prodsId;
  final String prodsName;

  const InventorySize({required this.prodsId, required this.prodsName});

  factory InventorySize.fromJson(Map<String, dynamic> j) => InventorySize(
        prodsId: (j['prods_id'] as num).toInt(),
        prodsName: (j['prods_name'] ?? '').toString(),
      );
}

class InventoryOption {
  final int prodoId;
  final String prodoName;

  const InventoryOption({required this.prodoId, required this.prodoName});

  factory InventoryOption.fromJson(Map<String, dynamic> j) => InventoryOption(
        prodoId: (j['prodo_id'] as num).toInt(),
        prodoName: (j['prodo_name'] ?? '').toString(),
      );
}

/// One row of the size×option stock collection.
class InventoryCollect {
  final int prodsId;
  final int prodoId;
  final int stock; // prod_stock      → restantes
  final int stockLast; // prod_stock_last → inicial
  final int sell; // prod_sell       → vendidos
  final String price; // prod_price
  final bool available; // prod_available

  const InventoryCollect({
    required this.prodsId,
    required this.prodoId,
    required this.stock,
    required this.stockLast,
    required this.sell,
    required this.price,
    required this.available,
  });

  /// Derived status following priority order:
  ///   !available  → noDisponible
  ///   stock <= 0  → agotado
  ///   stock <= 5  → stockBajo
  ///   otherwise   → disponible
  VariantStatus get status {
    if (!available) return VariantStatus.noDisponible;
    if (stock <= 0) return VariantStatus.agotado;
    if (stock <= kLowStockThreshold) return VariantStatus.stockBajo;
    return VariantStatus.disponible;
  }

  factory InventoryCollect.fromJson(Map<String, dynamic> j) {
    final raw = j['prod_available'];
    bool avail;
    if (raw is bool) {
      avail = raw;
    } else if (raw is num) {
      avail = raw.toInt() == 1;
    } else if (raw is String) {
      final s = raw.toLowerCase().trim();
      avail = s == 'true' || s == '1';
    } else {
      avail = true;
    }
    return InventoryCollect(
      prodsId: (j['prods_id'] as num?)?.toInt() ?? 0,
      prodoId: (j['prodo_id'] as num?)?.toInt() ?? 0,
      stock: (j['prod_stock'] as num?)?.toInt() ?? 0,
      stockLast: (j['prod_stock_last'] as num?)?.toInt() ?? 0,
      sell: (j['prod_sell'] as num?)?.toInt() ?? 0,
      price: (j['prod_price'] ?? '0').toString(),
      available: avail,
    );
  }
}

class InventoryProduct {
  final int prodId;
  final String name;
  final String category;
  final String imageUrl;
  final List<InventorySize> sizes;
  final List<InventoryOption> options;
  final List<InventoryCollect> collect;

  const InventoryProduct({
    required this.prodId,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.sizes,
    required this.options,
    required this.collect,
  });

  String sizeNameOf(int prodsId) {
    if (prodsId == 0) return '';
    for (final s in sizes) {
      if (s.prodsId == prodsId) return s.prodsName;
    }
    return '';
  }

  String optionNameOf(int prodoId) {
    if (prodoId == 0) return '';
    for (final o in options) {
      if (o.prodoId == prodoId) return o.prodoName;
    }
    return '';
  }

  /// Total remaining stock across all variants (used for the product-level
  /// stat-card aggregation).
  int get totalStock =>
      collect.fold(0, (sum, c) => sum + (c.stock > 0 ? c.stock : 0));

  /// A product counts as available when at least one of its variants is
  /// available.
  bool get anyAvailable => collect.any((c) => c.available);

  /// Product-level status, aggregated from its variants. A product is the
  /// "worst" non-trivial state among its variants so the stat cards line up
  /// with the Products page semantics.
  VariantStatus get status {
    if (collect.isEmpty) return VariantStatus.noDisponible;
    if (!anyAvailable) return VariantStatus.noDisponible;
    final total = totalStock;
    if (total <= 0) return VariantStatus.agotado;
    if (total <= kLowStockThreshold) return VariantStatus.stockBajo;
    return VariantStatus.disponible;
  }

  /// True when any variant matches [statusLabel] (used by the status filter).
  bool hasVariantWithStatus(String statusLabel) =>
      collect.any((c) => c.status.label == statusLabel);

  factory InventoryProduct.fromJson(Map<String, dynamic> j) {
    return InventoryProduct(
      prodId: (j['prod_id'] as num).toInt(),
      name: (j['prod_name'] ?? '').toString(),
      category: (j['prod_category'] ?? '').toString(),
      imageUrl: (j['prod_image_url'] ?? '').toString(),
      sizes: ((j['prod_size'] as List?) ?? [])
          .map((e) => InventorySize.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      options: ((j['prod_option'] as List?) ?? [])
          .map((e) =>
              InventoryOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      collect: _dedupeCollect(
        ((j['prod_collect'] as List?) ?? [])
            .map((e) =>
                InventoryCollect.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      ),
    );
  }
}

/// Removes duplicate collect rows sharing the same (prodsId, prodoId). The
/// backend occasionally returns repeated rows for the same variant.
List<InventoryCollect> _dedupeCollect(List<InventoryCollect> raw) {
  final seen = <String>{};
  return raw.where((c) => seen.add('${c.prodsId}_${c.prodoId}')).toList();
}
