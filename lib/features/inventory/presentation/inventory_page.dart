import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/inventory/controllers/inventory_controller.dart';
import 'package:ds_clickeat_web_admin/features/inventory/models/inventory_product.dart';
import 'package:ds_clickeat_web_admin/features/inventory/presentation/inventory_edit_dialog.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';

/// Lowercases [s] and strips common Spanish diacritics so searches are
/// accent-insensitive ("cafe" matches "Café de olla").
String _normalize(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buf = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString();
}

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  int? _lastPremId;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'all'; // 'all' or a category name
  String _statusFilter = 'Todos'; // matches VariantStatusX.filterLabels
  final Set<int> _expanded = {}; // prodIds currently expanded

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _ensurePremiseLoaded(int? premId) {
    if (premId == null || premId == _lastPremId) return;
    _lastPremId = premId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPremise(premId);
    });
  }

  void _loadPremise(int premId) {
    _category = 'all';
    _statusFilter = 'Todos';
    _expanded.clear();
    if (mounted) setState(() {});
    ref.read(inventoryControllerProvider.notifier).load(premId);
  }

  Future<void> _openEdit(InventoryProduct product, InventoryCollect collect) {
    final premId = ref.read(premisesControllerProvider).selectedPremId;
    if (premId == null) return Future.value();
    return showInventoryEditDialog(
      context,
      premId: premId,
      product: product,
      collect: collect,
    );
  }

  @override
  Widget build(BuildContext context) {
    final premId = ref.watch(
      premisesControllerProvider.select((state) => state.selectedPremId),
    );
    final invState = ref.watch(inventoryControllerProvider);
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventario',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildContent(invState)),
        ],
      ),
    );
  }

  Widget _buildContent(InventoryState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(
          state.error!,
          style: const TextStyle(color: AppColors.red, fontSize: 14),
        ),
      );
    }

    final products = state.products;

    // ----- stats (product-level, mirroring the Products page) -----
    final out = products.where((p) => p.status == VariantStatus.agotado).length;
    final low = products
        .where((p) => p.status == VariantStatus.stockBajo)
        .length;
    final available = products.where((p) => p.anyAvailable).length;

    // ----- categories (derived from loaded products) -----
    final catCounts = <String, int>{};
    for (final p in products) {
      final c = p.category.trim();
      if (c.isEmpty) continue;
      catCounts[c] = (catCounts[c] ?? 0) + 1;
    }
    final categories = catCounts.keys.toList()..sort();

    // ----- filtering -----
    final nq = _normalize(_query);
    final filtered = products.where((p) {
      if (_category != 'all' && p.category != _category) return false;
      if (_statusFilter != 'Todos' && !p.hasVariantWithStatus(_statusFilter)) {
        return false;
      }
      if (nq.isNotEmpty && !_normalize(p.name).contains(nq)) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow(
          total: products.length,
          available: available,
          low: low,
          out: out,
        ),
        const SizedBox(height: 12),
        // ===== filter bar =====
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 240,
                      maxWidth: 360,
                    ),
                    child: _SearchBox(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  _StatusFilter(
                    value: _statusFilter,
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ],
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 1, color: AppColors.line),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _CategoryPill(
                      label: 'Todas',
                      count: products.length,
                      active: _category == 'all',
                      onTap: () => setState(() => _category = 'all'),
                    ),
                    for (final c in categories)
                      _CategoryPill(
                        label: c,
                        count: catCounts[c] ?? 0,
                        active: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ===== product list =====
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyResults()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return _ProductCard(
                      product: p,
                      expanded: _expanded.contains(p.prodId),
                      onToggle: () => setState(() {
                        if (!_expanded.add(p.prodId)) {
                          _expanded.remove(p.prodId);
                        }
                      }),
                      onEditCollect: (c) => _openEdit(p, c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Stat cards
// ===========================================================================

class _StatRow extends StatelessWidget {
  final int total;
  final int available;
  final int low;
  final int out;

  const _StatRow({
    required this.total,
    required this.available,
    required this.low,
    required this.out,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    final cards = [
      _StatCard(
        color: AppColors.navy,
        label: 'Total productos',
        value: '$total',
        sub: 'en el menú',
      ),
      _StatCard(
        color: AppColors.green,
        label: 'Disponibles',
        value: '$available',
        sub: 'con stock',
      ),
      _StatCard(
        color: AppColors.amber,
        label: 'Stock bajo',
        value: '$low',
        sub: 'requieren reabasto',
      ),
      _StatCard(
        color: AppColors.red,
        label: 'Agotados',
        value: '$out',
        sub: 'sin existencias',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 640 ? 2 : 4;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _StatCard({
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.ink3,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -0.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Search box
// ===========================================================================

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar producto...',
                hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF6B7280),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Status filter pills
// ===========================================================================

class _StatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StatusFilter({required this.value, required this.onChanged});

  // (label, active color). Active pill paints this color with white text.
  static const _options = <(String, Color)>[
    ('Todos', Color(0xFF1F2E4D)),
    ('Disponible', Color(0xFF2E7D32)),
    ('No Disponible', Color(0xFF6B7280)),
    ('Stock Bajo', Color(0xFFE65100)),
    ('Agotado', Color(0xFFC62828)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, color) in _options)
          _StatusPill(
            label: label,
            color: color,
            active: value == label,
            onTap: () => onChanged(label),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Category pills
// ===========================================================================

class _CategoryPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.navy : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.ink2,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Product card (collapsible header + variant table)
// ===========================================================================

// Shared column flex weights so the header and variant rows line up.
const _vcSize = 3;
const _vcOption = 3;
const _vcInitial = 2;
const _vcSold = 2;
const _vcRemaining = 2;
const _vcStatus = 3;
const double _vcActionsWidth = 44;

class _ProductCard extends StatelessWidget {
  final InventoryProduct product;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(InventoryCollect) onEditCollect;

  const _ProductCard({
    required this.product,
    required this.expanded,
    required this.onToggle,
    required this.onEditCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ----- header (clickable to expand/collapse) -----
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  _ProductThumb(url: product.imageUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.category.isEmpty ? '—' : product.category,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${product.collect.length} '
                    '${product.collect.length == 1 ? "variante" : "variantes"}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink3,
                    ),
                  ),
                  const SizedBox(width: 14),
                  _StatusChip(status: product.status),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ----- expanded variant table -----
          if (expanded) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.line),
            if (product.collect.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sin variantes.',
                    style: TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ),
              )
            else
              ScrollableTable(
                minWidth: 780,
                child: Column(
                  children: [
                    const _CollectHeader(),
                    for (var i = 0; i < product.collect.length; i++)
                      _CollectRow(
                        product: product,
                        collect: product.collect[i],
                        isLast: i == product.collect.length - 1,
                        onEdit: () => onEditCollect(product.collect[i]),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CollectHeader extends StatelessWidget {
  const _CollectHeader();

  static const _s = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: AppColors.ink3,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(
            flex: _vcSize,
            child: Text('TAMAÑO', style: _s),
          ),
          Expanded(
            flex: _vcOption,
            child: Text('OPCIÓN', style: _s),
          ),
          Expanded(
            flex: _vcInitial,
            child: Text('INICIAL', style: _s, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: _vcSold,
            child: Text('VENDIDOS', style: _s, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: _vcRemaining,
            child: Text('RESTANTE', style: _s, textAlign: TextAlign.center),
          ),
          Expanded(
            flex: _vcStatus,
            child: Text('ESTADO', style: _s),
          ),
          SizedBox(width: _vcActionsWidth),
        ],
      ),
    );
  }
}

class _CollectRow extends StatelessWidget {
  final InventoryProduct product;
  final InventoryCollect collect;
  final bool isLast;
  final VoidCallback onEdit;

  const _CollectRow({
    required this.product,
    required this.collect,
    required this.isLast,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final sizeName = product.sizeNameOf(collect.prodsId);
    final optionName = product.optionNameOf(collect.prodoId);
    final strike = collect.status == VariantStatus.noDisponible;

    final base = TextStyle(
      fontSize: 13.5,
      color: strike ? AppColors.ink4 : AppColors.ink,
      decoration: strike ? TextDecoration.lineThrough : null,
      decorationColor: AppColors.ink4,
    );
    final num = base.copyWith(fontWeight: FontWeight.w600);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: _vcSize,
            child: Text(
              sizeName.isEmpty ? '—' : sizeName,
              style: base.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: _vcOption,
            child: Text(optionName.isEmpty ? '—' : optionName, style: base),
          ),
          Expanded(
            flex: _vcInitial,
            child: Text(
              '${collect.stockLast}',
              style: num,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: _vcSold,
            child: Text(
              '${collect.sell}',
              style: num,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: _vcRemaining,
            child: Text(
              '${collect.stock}',
              style: num,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: _vcStatus,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusChip(status: collect.status),
            ),
          ),
          SizedBox(
            width: _vcActionsWidth,
            child: IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: strike ? AppColors.ink4 : AppColors.navy,
              ),
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Status chip
// ===========================================================================

class _StatusChip extends StatelessWidget {
  final VariantStatus status;
  const _StatusChip({required this.status});

  (Color, Color) get _colors {
    switch (status) {
      case VariantStatus.disponible:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case VariantStatus.stockBajo:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case VariantStatus.agotado:
        return (const Color(0xFFFFEBEE), const Color(0xFFC62828));
      case VariantStatus.noDisponible:
        return (AppColors.surface2, AppColors.ink3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ===========================================================================
// Product thumbnail
// ===========================================================================

class _ProductThumb extends StatelessWidget {
  final String url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_outlined, size: 22, color: Colors.grey),
    );
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 44, color: AppColors.ink4),
          SizedBox(height: 14),
          Text(
            'Sin resultados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Ajusta los filtros para ver el inventario.',
            style: TextStyle(fontSize: 13, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
