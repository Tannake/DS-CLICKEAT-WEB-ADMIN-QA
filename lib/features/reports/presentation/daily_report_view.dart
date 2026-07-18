import 'package:flutter/material.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/reports/controllers/daily_report_controller.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_daily.dart';
import 'package:ds_clickeat_web_admin/features/reports/models/report_view.dart';

/// Maps the live `reports/daily` payload (held in [DailyReportState]) into
/// the same [ReportView] shape the mock report screens use, so the
/// dashboard reuses the existing KPI/chart renderers in `reports_page.dart`
/// instead of a parallel set of widgets. Mirrors the "V1 — Dashboard
/// clásico" layout from the Reportes ClickEat design: a KPI row, a
/// categoría/top-10/venta-$ row, and a venta-mayor/venta-menor/sin-venta/
/// órdenes-por-hora row.
ReportView buildDailyReportView(DailyReportState state) {
  final data = state.data ?? DailyReportData.empty;
  final cards = data.cards;
  final previous = data.cardsPrevious;

  final ordersHours = [...data.ordersHours]
    ..sort((a, b) => a.ordeHour.compareTo(b.ordeHour));
  // `top_product` is the one list the backend always caps at exactly 10, so
  // it never needs to scroll. `product_sales` and `product_category` can
  // come back with more than 10 rows — keep every record and let the chart
  // scroll for the rest instead of truncating data here.
  final topProduct = data.topProduct;
  final productSales = data.productSales;
  final productCategory = [...data.productCategory]
    ..sort((a, b) => b.prodQuantity.compareTo(a.prodQuantity));

  return ReportView(
    title: 'Dashboard diario',
    subtitle: 'Así va el negocio hoy',
    filters: const [],
    kpis: [
      ReportKpi(
        label: 'Venta total de hoy',
        value: _money(cards.salesTotal ?? 0),
        sub: _pctDelta(cards.salesTotal, previous.salesTotal) ?? '',
        accent: AppColors.green,
        subColor: _deltaColor(cards.salesTotal, previous.salesTotal),
      ),
      ReportKpi(
        label: 'Órdenes generadas',
        value: _num(cards.ordersTotal),
        sub: _pctDelta(cards.ordersTotal, previous.ordersTotal) ?? '',
        accent: AppColors.navy,
        subColor: _deltaColor(cards.ordersTotal, previous.ordersTotal),
      ),
      ReportKpi(
        label: 'Ticket promedio',
        value: _money(cards.averageTicket ?? 0),
        sub: _pctDelta(cards.averageTicket, previous.averageTicket) ?? '',
        accent: const Color(0xFF2563EB),
        subColor: _deltaColor(cards.averageTicket, previous.averageTicket),
      ),
      ReportKpi(
        label: 'Clientes únicos',
        value: _num(cards.custTotal),
        sub: _pctDelta(cards.custTotal, previous.custTotal) ?? '',
        accent: const Color(0xFF7C3AED),
        subColor: _deltaColor(cards.custTotal, previous.custTotal),
      ),
      ReportKpi(
        label: 'Órdenes canceladas',
        value: _num(cards.ordersCancelled),
        sub: cards.ordersTotal > 0
            ? '${(cards.ordersCancelled / cards.ordersTotal * 100).toStringAsFixed(1)}% del total'
            : '',
        accent: AppColors.red,
        subColor: AppColors.redInk,
      ),
    ],
    charts: [
      HBarsChart(
        'Cantidad por categoría',
        2,
        visibleRows: 10,
        items: [
          for (final c in productCategory)
            HBarItem(c.prodcName, c.prodQuantity.toDouble(), AppColors.navy,
                '${c.prodQuantity}'),
        ],
      ),
      HBarsChart(
        'Top 10 productos',
        2,
        visibleRows: 10,
        items: [
          for (final p in topProduct)
            HBarItem(p.prodName, p.prodQuantity.toDouble(), AppColors.gold,
                '${p.prodQuantity}'),
        ],
      ),
      HBarsChart(
        'Venta de producto',
        2,
        visibleRows: 10,
        items: [
          for (final p in productSales)
            HBarItem(p.prodName, p.prodTotal.toDouble(), AppColors.green,
                _money(p.prodTotal)),
        ],
      ),
    ],
    tableTitle: '',
    tableCount: '',
    headers: const [],
    rows: const [],
    buckets: [
      ProductListChart(
        'Venta mayor',
        68,
        color: AppColors.greenInk,
        badgeText: 'Alta rotación',
        badgeColor: AppColors.greenInk,
        subtitle: '${data.productSalesHighest.length} productos',
        visibleRows: 12,
        items: [
          for (final p in data.productSalesHighest)
            ProductListItem(p.prodName, valueText: '${p.prodQuantity}'),
        ],
      ),
      ProductListChart(
        'Venta menor',
        68,
        color: AppColors.amberInk,
        badgeText: 'Baja rotación',
        badgeColor: AppColors.amberInk,
        subtitle: '${data.productSalesLower.length} productos',
        visibleRows: 12,
        items: [
          for (final p in data.productSalesLower)
            ProductListItem(p.prodName, valueText: '${p.prodQuantity}'),
        ],
      ),
      ProductListChart(
        'Sin venta',
        68,
        color: AppColors.redInk,
        badgeText: 'Atención',
        badgeColor: AppColors.redInk,
        subtitle: '${data.productSalesNot.length} productos',
        visibleRows: 12,
        items: [
          for (final p in data.productSalesNot) ProductListItem(p.prodName),
        ],
      ),
    ],
    bucketsSideChart: BarsChart(
      'Órdenes por hora',
      96,
      labels: [for (final h in ordersHours) '${h.ordeHour}:00'],
      values: [for (final h in ordersHours) h.ordersTotal.toDouble()],
      valueLabels: [for (final h in ordersHours) '${h.ordersTotal}'],
      color: AppColors.gold,
    ),
  );
}

// ===== formatting helpers ====================================================

String _money(num n) => '\$${_grouped(n.round())}';
String _num(num n) => _grouped(n.round());

String _grouped(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

String? _pctDelta(num? current, num? previous) {
  if (current == null || previous == null || previous == 0) return null;
  final pct = (current - previous) / previous * 100;
  final arrow = pct >= 0 ? '▲' : '▼';
  return '$arrow ${pct.abs().toStringAsFixed(0)}% vs ayer';
}

Color _deltaColor(num? current, num? previous) {
  if (current == null || previous == null || previous == 0) {
    return const Color(0xFF8A93A3);
  }
  return current >= previous ? AppColors.greenInk : AppColors.amberInk;
}
