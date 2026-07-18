import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/horizontal_pill_row.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/products/controllers/products_controller.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product.dart';
import 'package:ds_clickeat_web_admin/features/products/presentation/product_detail_panel.dart';

/// Stock threshold (units) under which a product is flagged "Stock bajo".
const int _lowStockThreshold = 5;

enum _StockLevel { ok, low, out }

_StockLevel _stockLevel(Product p) {
  final total = p.prodStock;
  if (total <= 0) return _StockLevel.out;
  if (total <= _lowStockThreshold) return _StockLevel.low;
  return _StockLevel.ok;
}

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

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  int? _lastPremId;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'all'; // 'all' or a category name
  String _statusFilter = 'all'; // all | available | unavailable | low | out

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
    _statusFilter = 'all';
    if (mounted) setState(() {});
    ref.read(productsControllerProvider.notifier).load(premId);
  }

  /// Opens the detail slide-over for [p], loading its full detail by id.
  void _openDetail(Product p) {
    final premId = ref.read(premisesControllerProvider).selectedPremId;
    if (premId == null) return;
    showProductDetailPanel(
      context,
      ref,
      premId: premId,
      prodId: p.prodId,
      fallbackName: p.prodName,
    );
  }

  /// Opens the slide-over in create mode (blank form seeded with catalogs).
  void _openCreate() {
    final premId = ref.read(premisesControllerProvider).selectedPremId;
    if (premId == null) return;
    showProductCreatePanel(context, ref, premId: premId);
  }

  /// Confirms and deletes [p], then reloads the list.
  Future<void> _confirmDelete(Product p) async {
    final premId = ref.read(premisesControllerProvider).selectedPremId;
    if (premId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que quieres eliminar "${p.prodName}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(productsControllerProvider.notifier)
        .delete(premId, p.prodId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Producto eliminado.' : 'No se pudo eliminar el producto.',
        ),
      ),
    );
  }

  /// True when [p] matches the currently selected status pill.
  bool _statusMatches(Product p) {
    switch (_statusFilter) {
      case 'available':
        return p.prodAvailable;
      case 'unavailable':
        return !p.prodAvailable;
      case 'low':
        return _stockLevel(p) == _StockLevel.low;
      case 'out':
        return _stockLevel(p) == _StockLevel.out;
      default: // 'all'
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final prodState = ref.watch(productsControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: premId == null ? null : _openCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo producto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildContent(prodState)),
        ],
      ),
    );
  }

  Widget _buildContent(ProductsState state) {
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

    // ----- stats -----
    final out = products.where((p) => _stockLevel(p) == _StockLevel.out).length;
    final low = products.where((p) => _stockLevel(p) == _StockLevel.low).length;
    final available = products.where((p) => p.prodAvailable).length;

    // ----- categories (derived from loaded products) -----
    final catCounts = <String, int>{};
    for (final p in products) {
      final c = p.prodCategory.trim();
      if (c.isEmpty) continue;
      catCounts[c] = (catCounts[c] ?? 0) + 1;
    }
    final categories = catCounts.keys.toList()..sort();

    // ----- filtering -----
    // Search matches the product name only, ignoring case AND accents so
    // typing "cafe" finds "Café de olla".
    final nq = _normalize(_query);
    final filtered = products.where((p) {
      if (_category != 'all' && p.prodCategory != _category) return false;
      if (!_statusMatches(p)) return false;
      if (nq.isNotEmpty && !_normalize(p.prodName).contains(nq)) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== stat cards =====
        _StatRow(
          total: products.length,
          available: available,
          low: low,
          out: out,
        ),
        const SizedBox(height: 12),
        // ===== filter bar: compact search + status pills (white card) =====
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
              // --- search + status pills ---
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
              // --- category pills ---
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 1, color: AppColors.line),
                const SizedBox(height: 8),
                HorizontalPillRow(
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
        // ===== table =====
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyResults()
              : _ProductsTable(
                  products: filtered,
                  onEdit: _openDetail,
                  onDelete: _confirmDelete,
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
            // left color bar
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

  // (key, label, active color). Active pill paints this color with white text.
  static const _options = <(String, String, Color)>[
    ('all', 'Todos', Color(0xFF1F2E4D)),
    ('available', 'Disponible', Color(0xFF2E7D32)),
    ('unavailable', 'No Disponible', Color(0xFF6B7280)),
    ('low', 'Stock Bajo', Color(0xFFE65100)),
    ('out', 'Agotado', Color(0xFFC62828)),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (key, label, color) in _options)
          _StatusPill(
            label: label,
            color: color,
            active: value == key,
            onTap: () => onChanged(key),
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
            'Ajusta los filtros o crea un producto nuevo.',
            style: TextStyle(fontSize: 13, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Products table (one row per product)
// ===========================================================================

/// Flex weights shared by the table header and every row so columns align.
const _colProduct = 4;
const _colCategory = 2;
const _colDesc = 3;
const _colPrice = 2;
const _colStock = 1;
const _colArea = 2;
const _colOrder = 1;
const _colAdult = 1;
const _colActive = 1;
const double _colActionsWidth = 92;

class _ProductsTable extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  const _ProductsTable({
    required this.products,
    required this.onEdit,
    required this.onDelete,
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
      child: ScrollableTable(
        minWidth: 1120,
        child: Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) => _ProductRow(
                  product: products[index],
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Row(
        children: [
          Expanded(
            flex: _colProduct,
            child: Text('PRODUCTO', style: _headerStyle),
          ),
          Expanded(
            flex: _colCategory,
            child: Text('CATEGORÍA', style: _headerStyle),
          ),
          Expanded(
            flex: _colDesc,
            child: Text('DESCRIPCIÓN', style: _headerStyle),
          ),
          Expanded(
            flex: _colPrice,
            child: Text('PRECIO', style: _headerStyle),
          ),
          Expanded(
            flex: _colStock,
            child: Text('STOCK', style: _headerStyle),
          ),
          Expanded(
            flex: _colArea,
            child: Text('ÁREA DE PREPARACIÓN', style: _headerStyle),
          ),
          Expanded(
            flex: _colOrder,
            child: Text('ORDEN', style: _headerStyle),
          ),
          Expanded(
            flex: _colAdult,
            child: Text('18+', style: _headerStyle),
          ),
          Expanded(
            flex: _colActive,
            child: Text('ACTIVO', style: _headerStyle),
          ),
          SizedBox(width: _colActionsWidth),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
  color: AppColors.ink3,
);

const _rowStyle = TextStyle(fontSize: 14, color: AppColors.ink);

class _ProductRow extends StatelessWidget {
  final Product product;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  const _ProductRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final desc = product.prodDesc.trim();
    return InkWell(
      onTap: () => onEdit(product),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // PRODUCTO: image + name
            Expanded(
              flex: _colProduct,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.prodImageUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product.prodName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // CATEGORÍA
            Expanded(
              flex: _colCategory,
              child: Text(
                product.prodCategory.isEmpty ? '—' : product.prodCategory,
                style: _rowStyle,
              ),
            ),
            // DESCRIPCIÓN
            Expanded(
              flex: _colDesc,
              child: Text(
                desc.isEmpty ? '—' : desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.ink2),
              ),
            ),
            // PRECIO (low – high range)
            Expanded(
              flex: _colPrice,
              child: Text(
                product.priceDisplay,
                style: _rowStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            // STOCK (total across variants)
            Expanded(
              flex: _colStock,
              child: Text('${product.prodStock}', style: _rowStyle),
            ),
            // ÁREA DE PREPARACIÓN
            Expanded(
              flex: _colArea,
              child: Text(
                product.prodPreparationArea.isEmpty
                    ? '—'
                    : product.prodPreparationArea,
                style: _rowStyle,
              ),
            ),
            // ORDEN
            Expanded(
              flex: _colOrder,
              child: Text('${product.prodOrder}', style: _rowStyle),
            ),
            // 18+
            Expanded(
              flex: _colAdult,
              child: product.prodAdult
                  ? const _AdultBadge()
                  : const Text('—', style: _rowStyle),
            ),
            // ACTIVO
            Expanded(
              flex: _colActive,
              child: _AvailabilityChip(available: product.prodAvailable),
            ),
            // actions
            SizedBox(
              width: _colActionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.black45,
                    ),
                    onPressed: () => onEdit(product),
                    tooltip: 'Editar',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.red,
                    ),
                    onPressed: () => onDelete(product),
                    tooltip: 'Eliminar',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdultBadge extends StatelessWidget {
  const _AdultBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '18+',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.red,
          ),
        ),
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;
  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: available
              ? AppColors.available.withValues(alpha: 0.12)
              : AppColors.unavailable.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          available ? 'Activo' : 'Inactivo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: available ? AppColors.available : AppColors.unavailable,
          ),
        ),
      ),
    );
  }
}
