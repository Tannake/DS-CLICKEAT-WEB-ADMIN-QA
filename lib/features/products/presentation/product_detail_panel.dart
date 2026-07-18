import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/products/controllers/product_detail_controller.dart';
import 'package:ds_clickeat_web_admin/features/products/data/image_picker.dart';
import 'package:ds_clickeat_web_admin/features/products/models/product_detail.dart';

/// Opens the product detail slide-over from the right. Loads the detail for
/// [prodId] (scoped to [premId]) and clears the controller state on close.
Future<void> showProductDetailPanel(
  BuildContext context,
  WidgetRef ref, {
  required int premId,
  required int prodId,
  required String fallbackName,
}) {
  ref.read(productDetailControllerProvider.notifier).load(premId, prodId);
  return _showPanel(context, ref, fallbackName: fallbackName);
}

/// Opens the same slide-over in "create" mode: loads the premise catalogs into
/// a blank product and saves via `products/create`.
Future<void> showProductCreatePanel(
  BuildContext context,
  WidgetRef ref, {
  required int premId,
}) {
  ref.read(productDetailControllerProvider.notifier).loadForCreate(premId);
  return _showPanel(context, ref, fallbackName: 'Nuevo producto');
}

Future<void> _showPanel(
  BuildContext context,
  WidgetRef ref, {
  required String fallbackName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _ProductDetailPanel(fallbackName: fallbackName),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  ).whenComplete(
    () => ref.read(productDetailControllerProvider.notifier).clear(),
  );
}

class _ProductDetailPanel extends ConsumerWidget {
  final String fallbackName;
  const _ProductDetailPanel({required this.fallbackName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productDetailControllerProvider);
    final width = math.min(780.0, MediaQuery.of(context).size.width * 0.92);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          width: width,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(-4, 0),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _Header(
                detail: state.detail,
                fallbackName: fallbackName,
                creating: state.creating,
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              Expanded(child: _Body(state: state)),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Header
// ===========================================================================

class _Header extends StatelessWidget {
  final ProductDetail? detail;
  final String fallbackName;
  final bool creating;
  const _Header({
    required this.detail,
    required this.fallbackName,
    this.creating = false,
  });

  @override
  Widget build(BuildContext context) {
    // In create mode the product has no id/category yet, so show the fixed
    // "Nuevo producto" title (or the typed name) with no subtitle.
    final title = creating
        ? ((detail?.prodName.trim().isNotEmpty ?? false)
              ? detail!.prodName
              : fallbackName)
        : (detail?.prodName ?? fallbackName);
    final sub = (detail == null || creating)
        ? null
        : 'Producto #${detail!.prodId} · ${detail!.categoryName}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.ink3),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Body
// ===========================================================================

class _Body extends StatelessWidget {
  final ProductDetailState state;
  const _Body({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.red, fontSize: 14),
          ),
        ),
      );
    }
    final d = state.detail;
    if (d == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BasicInfoSection(detail: d),
          const _ImageSection(),
          const _PrepAreaSelector(),
          _Section(
            icon: Icons.tune_outlined,
            title: 'Variantes',
            sub: 'Precios y stock por tamaño y opción',
            child: const _VariantsTable(),
          ),
          _Section(
            icon: Icons.add_circle_outline,
            title: 'Adicionales',
            sub: 'Extras que el cliente puede agregar a este producto',
            child: const _AdditionalsSelector(),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Section wrapper
// ===========================================================================

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final Widget child;

  const _Section({
    required this.icon,
    required this.title,
    this.sub,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(icon, size: 16, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink3,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ===========================================================================
// Labeled editable text field
// ===========================================================================

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hint;

  const _EditField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.navy),
            ),
          ),
        ),
      ],
    );
  }
}

/// A labeled container that wraps an arbitrary control (combo, toggle…) so it
/// lines up with [_EditField].
class _LabeledControl extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledControl({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ===========================================================================
// Basic info (editable: name, description, category, order, 18+)
// ===========================================================================

class _BasicInfoSection extends ConsumerStatefulWidget {
  final ProductDetail detail;
  const _BasicInfoSection({required this.detail});

  @override
  ConsumerState<_BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends ConsumerState<_BasicInfoSection> {
  late final TextEditingController _name = TextEditingController(
    text: widget.detail.prodName,
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.detail.prodDesc,
  );
  late final TextEditingController _order = TextEditingController(
    text: '${widget.detail.prodOrder}',
  );

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch so category/adult reflect external changes; text fields keep their
    // own controllers (one-way UI → state) to avoid cursor jumps.
    final d = ref.watch(productDetailControllerProvider).detail ?? widget.detail;
    final notifier = ref.read(productDetailControllerProvider.notifier);

    return _Section(
      icon: Icons.inventory_2_outlined,
      title: 'Información básica',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditField(
            label: 'Nombre',
            controller: _name,
            onChanged: notifier.setName,
          ),
          const SizedBox(height: 14),
          _EditField(
            label: 'Descripción',
            controller: _desc,
            onChanged: notifier.setDesc,
            maxLines: 4,
            hint: 'Sin descripción',
          ),
          const SizedBox(height: 14),
          // Categoría on its own row so the menu and the switches below have
          // room.
          _LabeledControl(
            label: 'Categoría',
            child: _ComboCell(
              selectedId: d.prodCategoryId,
              items: [
                for (final c in d.categories) (id: c.prodcId, name: c.prodcName),
              ],
              onChanged: notifier.setCategory,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _EditField(
                  label: 'Orden',
                  controller: _order,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => notifier.setOrder(int.tryParse(v) ?? 0),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _LabeledControl(
                  label: '18+',
                  child: _MiniSwitch(
                    value: d.prodAdult,
                    onChanged: notifier.setAdult,
                    labelOn: 'Sí',
                    labelOff: 'No',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _LabeledControl(
                  label: 'Disponible',
                  child: _MiniSwitch(
                    value: d.prodAvailable,
                    onChanged: notifier.setAvailable,
                    labelOn: 'Sí',
                    labelOff: 'No',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact, friendly-colored switch with an on/off text label.
class _MiniSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String labelOn;
  final String labelOff;

  const _MiniSwitch({
    required this.value,
    required this.onChanged,
    required this.labelOn,
    required this.labelOff,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.scale(
          scale: 0.78,
          alignment: Alignment.centerLeft,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.ink4,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value ? labelOn : labelOff,
          style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
        ),
      ],
    );
  }
}

// ===========================================================================
// Image (preview + upload)
// ===========================================================================

class _ImageSection extends ConsumerWidget {
  const _ImageSection();

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final picked = await pickImageFile();
    if (picked == null) return;
    await ref
        .read(productDetailControllerProvider.notifier)
        .uploadImage(picked.bytes, picked.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productDetailControllerProvider);
    final d = state.detail;
    if (d == null) return const SizedBox.shrink();

    // Surface the one-shot image error as a snackbar, then clear it.
    ref.listen<String?>(
      productDetailControllerProvider.select((s) => s.imageError),
      (_, err) {
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
          ref.read(productDetailControllerProvider.notifier).clearImageError();
        }
      },
    );

    return _Section(
      icon: Icons.image_outlined,
      title: 'Imagen del producto',
      sub: 'Solo se aceptan archivos .jpg',
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            // While creating, the picked image lives only in memory (no URL
            // yet), so preview it from bytes; otherwise load the hosted URL.
            child: state.pendingImage != null
                ? Image.memory(
                    state.pendingImage!.bytes,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                  )
                : Image.network(
                    d.prodImageUrl,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 28,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: state.uploadingImage ? null : () => _pickAndUpload(ref),
            icon: state.uploadingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_outlined, size: 18),
            label: Text(
              state.uploadingImage
                  ? 'Subiendo…'
                  : (state.creating && state.pendingImage == null
                        ? 'Subir imagen'
                        : 'Cambiar imagen'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.line),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Preparation-area selector (single select)
// ===========================================================================

class _PrepAreaSelector extends ConsumerWidget {
  const _PrepAreaSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(productDetailControllerProvider).detail;
    if (d == null) return const SizedBox.shrink();
    final notifier = ref.read(productDetailControllerProvider.notifier);

    return _Section(
      icon: Icons.local_fire_department_outlined,
      title: 'Área de preparación',
      sub: 'Estación que prepara este producto',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in d.prepAreas)
            _AreaPill(
              label: a.prepName,
              active: a.prepId == d.prodPreparationAreaId,
              onTap: () => notifier.setPrepArea(a.prepId),
            ),
        ],
      ),
    );
  }
}

class _AreaPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AreaPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.navy : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? Colors.white : AppColors.ink2,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Additionals multi-select (link/unlink add-on products)
// ===========================================================================

/// Renders the add-on catalog (`product_additional`) as toggleable pills.
/// Active pills are the ones linked to this product
/// (`product_additional_collect`); tapping links/unlinks them in memory.
class _AdditionalsSelector extends ConsumerWidget {
  const _AdditionalsSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailControllerProvider).detail;
    if (detail == null) return const SizedBox.shrink();

    if (detail.additionals.isEmpty) {
      return const Text(
        'No hay productos adicionales disponibles.',
        style: TextStyle(fontSize: 13, color: AppColors.ink3),
      );
    }

    final notifier = ref.read(productDetailControllerProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in detail.additionals)
          _AdditionalPill(
            label: a.prodaName,
            active: detail.linkedAdditionalIds.contains(a.prodaId),
            onTap: () => notifier.toggleAdditional(a.prodaId),
          ),
      ],
    );
  }
}

class _AdditionalPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _AdditionalPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 8, 15, 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? AppColors.navy : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check : Icons.add,
              size: 15,
              color: active ? Colors.white : AppColors.ink3,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? Colors.white : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Variants table (Tamaño · Opción · Precio · Stock · Estado) with inline edit
// ===========================================================================

// Shared column flex weights so the header and rows line up.
const _vcSize = 3;
const _vcOption = 3;
const _vcPrice = 2;
const _vcStock = 2;
const _vcStatus = 3;
const _vcActions = 2;

class _VariantsTable extends ConsumerWidget {
  const _VariantsTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productDetailControllerProvider);
    final detail = state.detail;
    if (detail == null) return const SizedBox.shrink();

    final variants = detail.variants;
    final editingIndex = state.editingIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (variants.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Sin variantes.',
              style: TextStyle(fontSize: 13, color: AppColors.ink3),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _VariantHeader(),
                for (var i = 0; i < variants.length; i++)
                  if (editingIndex == i)
                    _EditableVariantRow(
                      key: ValueKey('edit-$i'),
                      index: i,
                      variant: variants[i],
                      sizes: detail.sizes,
                      options: detail.options,
                      isLast: i == variants.length - 1,
                    )
                  else
                    _VariantRow(
                      variant: variants[i],
                      isLast: i == variants.length - 1,
                      // Hide per-row actions while another row is being edited.
                      enabled: editingIndex == null,
                      onEdit: () => ref
                          .read(productDetailControllerProvider.notifier)
                          .startEdit(i),
                      onDelete: () => _confirmDelete(context, ref, i),
                    ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: editingIndex == null
                ? () => ref
                      .read(productDetailControllerProvider.notifier)
                      .startAdd()
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar variante'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Eliminar variante'),
        content: const Text('¿Seguro que quieres eliminar esta variante?'),
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
    if (ok == true) {
      ref.read(productDetailControllerProvider.notifier).deleteVariant(index);
    }
  }
}

class _VariantHeader extends StatelessWidget {
  const _VariantHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: AppColors.ink3,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: const Row(
        children: [
          Expanded(flex: _vcSize, child: Text('TAMAÑO', style: style)),
          Expanded(flex: _vcOption, child: Text('OPCIÓN', style: style)),
          Expanded(flex: _vcPrice, child: Text('PRECIO', style: style)),
          Expanded(flex: _vcStock, child: Text('STOCK', style: style)),
          Expanded(flex: _vcStatus, child: Text('ESTADO', style: style)),
          Expanded(flex: _vcActions, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  final ProductVariant variant;
  final bool isLast;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariantRow({
    required this.variant,
    required this.isLast,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: _vcSize,
            child: Text(
              variant.sizeLabel,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: _vcOption,
            child: Text(
              variant.optionLabel,
              style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: _vcPrice,
            child: Text(
              '\$${variant.prodPrice}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: _vcStock,
            child: Text(
              '${variant.prodStock}',
              style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
            ),
          ),
          Expanded(
            flex: _vcStatus,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusChip(
                available: variant.prodAvailable,
                dense: true,
                activeLabel: 'Disponible',
                inactiveLabel: 'No disponible',
              ),
            ),
          ),
          Expanded(
            flex: _vcActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _RowIconButton(
                  icon: Icons.edit_outlined,
                  color: AppColors.ink3,
                  tooltip: 'Editar',
                  onPressed: enabled ? onEdit : null,
                ),
                _RowIconButton(
                  icon: Icons.delete_outline,
                  color: AppColors.red,
                  tooltip: 'Eliminar',
                  onPressed: enabled ? onDelete : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Editable variant row (inline edit / create)
// ===========================================================================

class _EditableVariantRow extends ConsumerStatefulWidget {
  final int index;
  final ProductVariant variant;
  final List<SizeOption> sizes;
  final List<OptionOption> options;
  final bool isLast;

  const _EditableVariantRow({
    super.key,
    required this.index,
    required this.variant,
    required this.sizes,
    required this.options,
    required this.isLast,
  });

  @override
  ConsumerState<_EditableVariantRow> createState() =>
      _EditableVariantRowState();
}

class _EditableVariantRowState extends ConsumerState<_EditableVariantRow> {
  late int _sizeId = widget.variant.prodsId;
  late int _optionId = widget.variant.prodoId;
  late final TextEditingController _price = TextEditingController(
    text: widget.variant.prodPrice,
  );
  late final TextEditingController _stock = TextEditingController(
    text: '${widget.variant.prodStock}',
  );
  late bool _available = widget.variant.prodAvailable;

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  void _save() {
    final notifier = ref.read(productDetailControllerProvider.notifier);
    if (notifier.isDuplicate(_sizeId, _optionId, widget.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa combinación tamaño/opción ya existe.'),
        ),
      );
      return;
    }
    final priceText = _price.text.trim().isEmpty ? '0.00' : _price.text.trim();
    final stock = int.tryParse(_stock.text.trim()) ?? 0;
    final sizeName = _sizeId == 0
        ? ''
        : widget.sizes
              .firstWhere(
                (s) => s.prodsId == _sizeId,
                orElse: () => const SizeOption(
                  prodsId: 0,
                  prodsName: '',
                  prodsAvailable: true,
                ),
              )
              .prodsName;
    final optionName = _optionId == 0
        ? ''
        : widget.options
              .firstWhere(
                (o) => o.prodoId == _optionId,
                orElse: () => const OptionOption(
                  prodoId: 0,
                  prodoName: '',
                  prodoAvailable: true,
                ),
              )
              .prodoName;
    notifier.saveVariant(
      widget.index,
      widget.variant.copyWith(
        prodsId: _sizeId,
        prodsName: sizeName,
        prodoId: _optionId,
        prodoName: optionName,
        prodPrice: priceText,
        prodStock: stock,
        prodAvailable: _available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeItems = [
      (id: 0, name: '—'),
      for (final s in widget.sizes) (id: s.prodsId, name: s.prodsName),
    ];
    final optionItems = [
      (id: 0, name: '—'),
      for (final o in widget.options) (id: o.prodoId, name: o.prodoName),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: widget.isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: _vcSize,
            child: _ComboCell(
              selectedId: _sizeId,
              items: sizeItems,
              onChanged: (v) => setState(() => _sizeId = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _vcOption,
            child: _ComboCell(
              selectedId: _optionId,
              items: optionItems,
              onChanged: (v) => setState(() => _optionId = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _vcPrice,
            child: _CellField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              prefix: '\$',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _vcStock,
            child: _CellField(
              controller: _stock,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: _vcStatus,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => setState(() => _available = !_available),
                child: _StatusChip(
                  available: _available,
                  dense: true,
                  activeLabel: 'Disponible',
                  inactiveLabel: 'No disponible',
                ),
              ),
            ),
          ),
          Expanded(
            flex: _vcActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _RowIconButton(
                  icon: Icons.check,
                  color: AppColors.available,
                  tooltip: 'Guardar',
                  onPressed: _save,
                ),
                _RowIconButton(
                  icon: Icons.close,
                  color: AppColors.ink3,
                  tooltip: 'Cancelar',
                  onPressed: () => ref
                      .read(productDetailControllerProvider.notifier)
                      .cancelEdit(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Small reusable cell controls
// ===========================================================================

class _RowIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _RowIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: color,
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }
}

/// Compact rounded combo with a custom overlay menu that is left-aligned and
/// the same width as the trigger, capped to [_maxVisible] rows (then scrolls).
/// Custom (not [DropdownButton]/[PopupMenuButton]) to keep the rounded look,
/// the alignment, and avoid Material's default highlight colors.
class _ComboCell extends StatefulWidget {
  final int selectedId;
  final List<({int id, String name})> items;
  final ValueChanged<int> onChanged;

  const _ComboCell({
    required this.selectedId,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_ComboCell> createState() => _ComboCellState();
}

class _ComboCellState extends State<_ComboCell> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  static const double _itemHeight = 42;
  static const int _maxVisible = 5;

  bool get _isOpen => _entry != null;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final topLeft = box.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(context).size.height;

    final rows = math.min(widget.items.length, _maxVisible);
    final menuHeight = rows * _itemHeight + 8;
    final spaceBelow = screenH - (topLeft.dy + size.height);
    final openUp = spaceBelow < menuHeight + 12 && topLeft.dy > menuHeight;

    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: openUp ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: openUp
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, openUp ? -4 : 4),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: size.width,
                constraints: BoxConstraints(maxHeight: menuHeight),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemExtent: _itemHeight,
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final it = widget.items[i];
                    final sel = it.id == widget.selectedId;
                    return InkWell(
                      onTap: () {
                        widget.onChanged(it.id);
                        _close();
                      },
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: sel ? AppColors.surface2 : null,
                        child: Text(
                          it.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sel ? AppColors.navy : AppColors.ink2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.items.firstWhere(
      (it) => it.id == widget.selectedId,
      orElse: () => (id: 0, name: '—'),
    );
    return CompositedTransformTarget(
      link: _link,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _toggle,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isOpen ? AppColors.navy : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                ),
              ),
              Icon(
                _isOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? prefix;

  const _CellField({
    required this.controller,
    required this.keyboardType,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          prefixText: prefix,
          prefixStyle: const TextStyle(fontSize: 13.5, color: AppColors.ink3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          filled: true,
          fillColor: AppColors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared status chip
// ===========================================================================

class _StatusChip extends StatelessWidget {
  final bool available;
  final bool dense;

  /// Labels override. Defaults to the product-level "Activo/Inactivo"; pass
  /// "Disponible/No disponible" for per-variant availability.
  final String activeLabel;
  final String inactiveLabel;

  const _StatusChip({
    required this.available,
    this.dense = false,
    this.activeLabel = 'Activo',
    this.inactiveLabel = 'Inactivo',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: available
            ? AppColors.available.withValues(alpha: 0.12)
            : AppColors.unavailable.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        available ? activeLabel : inactiveLabel,
        style: TextStyle(
          fontSize: dense ? 11.5 : 12.5,
          fontWeight: FontWeight.w600,
          color: available ? AppColors.available : AppColors.unavailable,
        ),
      ),
    );
  }
}

// ===========================================================================
// Footer
// ===========================================================================

class _Footer extends ConsumerWidget {
  const _Footer();

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final creating = ref.read(productDetailControllerProvider).creating;
    final ok = await ref.read(productDetailControllerProvider.notifier).save();
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(creating ? 'Producto creado.' : 'Producto guardado.'),
        ),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            creating
                ? 'No se pudo crear el producto.'
                : 'No se pudo guardar el producto.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productDetailControllerProvider);
    // Disable saving while loading, mid-variant-edit, or already saving.
    final canSave =
        state.detail != null &&
        state.editingIndex == null &&
        !state.saving &&
        !state.uploadingImage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.line),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            child: const Text('Cerrar'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: canSave ? () => _save(context, ref) : null,
            icon: state.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(
              state.saving
                  ? 'Guardando…'
                  : (state.creating ? 'Crear producto' : 'Guardar producto'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
