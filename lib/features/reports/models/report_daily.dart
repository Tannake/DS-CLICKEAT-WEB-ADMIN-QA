/// One entry of `reports/parameter/orders-type` — a selectable order-type
/// filter value (`orde_type` is the code sent back to the backend, e.g. "W";
/// `orde_name` is what the user sees, e.g. "POS").
class OrderTypeOption {
  final String ordeType;
  final String ordeName;

  const OrderTypeOption({required this.ordeType, required this.ordeName});

  factory OrderTypeOption.fromJson(Map<String, dynamic> json) {
    return OrderTypeOption(
      ordeType: (json['orde_type'] ?? '') as String,
      ordeName: (json['orde_name'] ?? '') as String,
    );
  }
}

/// The `cards` / `cards_previous` block of `reports/daily`. Backend returns
/// `null` for money fields when there is no data for the period (e.g. an
/// empty previous day), so they're kept nullable rather than defaulted to 0
/// to distinguish "no data" from "zero sales".
class DailyCards {
  final int custTotal;
  final int ordersTotal;
  final num? salesTotal;
  final num? averageTicket;
  final int ordersCancelled;

  const DailyCards({
    required this.custTotal,
    required this.ordersTotal,
    required this.salesTotal,
    required this.averageTicket,
    required this.ordersCancelled,
  });

  factory DailyCards.fromJson(Map<String, dynamic> json) {
    return DailyCards(
      custTotal: (json['cust_total'] as num?)?.toInt() ?? 0,
      ordersTotal: (json['orders_total'] as num?)?.toInt() ?? 0,
      salesTotal: json['sales_total'] as num?,
      averageTicket: json['average_ticket'] as num?,
      ordersCancelled: (json['orders_cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = DailyCards(
    custTotal: 0,
    ordersTotal: 0,
    salesTotal: null,
    averageTicket: null,
    ordersCancelled: 0,
  );
}

class OrdersHourItem {
  final int ordeHour;
  final int ordersTotal;

  const OrdersHourItem({required this.ordeHour, required this.ordersTotal});

  factory OrdersHourItem.fromJson(Map<String, dynamic> json) {
    return OrdersHourItem(
      ordeHour: (json['orde_hour'] as num?)?.toInt() ?? 0,
      ordersTotal: (json['orders_total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A product + units-sold pair — shape shared by `top_product`,
/// `product_sales_lower` and `product_sales_highest`.
class ProductQuantityItem {
  final String prodName;
  final int prodQuantity;

  const ProductQuantityItem({
    required this.prodName,
    required this.prodQuantity,
  });

  factory ProductQuantityItem.fromJson(Map<String, dynamic> json) {
    return ProductQuantityItem(
      prodName: (json['prod_name'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A product + MXN total pair — `product_sales`.
class ProductSalesItem {
  final String prodName;
  final num prodTotal;

  const ProductSalesItem({required this.prodName, required this.prodTotal});

  factory ProductSalesItem.fromJson(Map<String, dynamic> json) {
    return ProductSalesItem(
      prodName: (json['prod_name'] ?? '') as String,
      prodTotal: (json['prod_total'] as num?) ?? 0,
    );
  }
}

/// A category + units-sold pair — `product_category`.
class ProductCategoryItem {
  final String prodcName;
  final int prodQuantity;

  const ProductCategoryItem({
    required this.prodcName,
    required this.prodQuantity,
  });

  factory ProductCategoryItem.fromJson(Map<String, dynamic> json) {
    return ProductCategoryItem(
      prodcName: (json['prodc_name'] ?? '') as String,
      prodQuantity: (json['prod_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A bare product name — `product_sales_not` (products with zero sales in
/// the period carry no quantity field at all).
class ProductNameItem {
  final String prodName;

  const ProductNameItem({required this.prodName});

  factory ProductNameItem.fromJson(Map<String, dynamic> json) {
    return ProductNameItem(prodName: (json['prod_name'] ?? '') as String);
  }
}

/// Full payload of `reports/daily` — `result` itself (some deployments still
/// nest it one level under `result.fun_reports_daily`; the repository
/// unwraps that case if present).
class DailyReportData {
  final DailyCards cards;
  final DailyCards cardsPrevious;
  final List<ProductQuantityItem> topProduct;
  final List<OrdersHourItem> ordersHours;
  final List<ProductSalesItem> productSales;
  final List<ProductCategoryItem> productCategory;
  final List<ProductNameItem> productSalesNot;
  final List<ProductQuantityItem> productSalesLower;
  final List<ProductQuantityItem> productSalesHighest;

  const DailyReportData({
    required this.cards,
    required this.cardsPrevious,
    required this.topProduct,
    required this.ordersHours,
    required this.productSales,
    required this.productCategory,
    required this.productSalesNot,
    required this.productSalesLower,
    required this.productSalesHighest,
  });

  factory DailyReportData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return DailyReportData(
      cards: json['cards'] is Map
          ? DailyCards.fromJson(Map<String, dynamic>.from(json['cards'] as Map))
          : DailyCards.empty,
      cardsPrevious: json['cards_previous'] is Map
          ? DailyCards.fromJson(
              Map<String, dynamic>.from(json['cards_previous'] as Map))
          : DailyCards.empty,
      topProduct: list('top_product', ProductQuantityItem.fromJson),
      ordersHours: list('orders_hours', OrdersHourItem.fromJson),
      productSales: list('product_sales', ProductSalesItem.fromJson),
      productCategory: list('product_category', ProductCategoryItem.fromJson),
      productSalesNot: list('product_sales_not', ProductNameItem.fromJson),
      productSalesLower:
          list('product_sales_lower', ProductQuantityItem.fromJson),
      productSalesHighest:
          list('product_sales_highest', ProductQuantityItem.fromJson),
    );
  }

  static const empty = DailyReportData(
    cards: DailyCards.empty,
    cardsPrevious: DailyCards.empty,
    topProduct: [],
    ordersHours: [],
    productSales: [],
    productCategory: [],
    productSalesNot: [],
    productSalesLower: [],
    productSalesHighest: [],
  );
}
