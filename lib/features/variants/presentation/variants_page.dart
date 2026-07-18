import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/core/widgets/scrollable_table.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/variants/controllers/variants_controller.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_additional.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_option.dart';
import 'package:ds_clickeat_web_admin/features/variants/models/product_size.dart';

class VariantsPage extends ConsumerStatefulWidget {
  const VariantsPage({super.key});

  @override
  ConsumerState<VariantsPage> createState() => _VariantsPageState();
}

class _VariantsPageState extends ConsumerState<VariantsPage> {
  int? _lastPremId;

  // A single row across the three tables can be in edit/create mode at a time.
  // Keys: 'size-<id>', 'size-new', 'opt-<id>', 'opt-new', 'add-<id>', 'add-new'.
  // null = none.
  String? _editKey;
  bool _saving = false;

  void _ensurePremiseLoaded(int? premId) {
    if (premId == null || premId == _lastPremId) return;
    _lastPremId = premId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPremise(premId);
    });
  }

  void _loadPremise(int premId) {
    _editKey = null;
    if (mounted) setState(() {});
    ref.read(variantsControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premId = ref.watch(
      premisesControllerProvider.select((state) => state.selectedPremId),
    );
    final varState = ref.watch(variantsControllerProvider);
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== header =====
          const Text(
            'Opciones y modificaciones',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Administra los tamaños, opciones y adicionales disponibles para los '
            'productos de esta sucursal',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent(varState)),
        ],
      ),
    );
  }

  Widget _buildContent(VariantsState state) {
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSizesSection(state.sizes),
          const SizedBox(height: 28),
          _buildOptionsSection(state.options),
          const SizedBox(height: 28),
          _buildAdditionalsSection(state.additionals),
        ],
      ),
    );
  }

  // ===========================================================================
  // Sizes section
  // ===========================================================================

  Widget _buildSizesSection(List<ProductSize> sizes) {
    final creating = _editKey == 'size-new';
    return _Section(
      title: 'Tamaños',
      addLabel: 'Agregar tamaño',
      onAdd: _editKey == null
          ? () => setState(() => _editKey = 'size-new')
          : null,
      child: (sizes.isEmpty && !creating)
          ? const _EmptyState(
              icon: Icons.straighten_outlined,
              title: 'Sin tamaños',
              message: 'Esta sucursal aún no tiene tamaños registrados.',
            )
          : _Card(
              minWidth: 640,
              children: [
                const _TableHeader(
                  columns: [
                    _Col('NOMBRE', 42),
                    _Col('PRODUCTOS', 28),
                    _Col('ESTADO', 20),
                    _Col('', 12),
                  ],
                ),
                for (final s in sizes)
                  if (_editKey == 'size-${s.prodsId}')
                    _NameEditRow(
                      key: ValueKey('size-edit-${s.prodsId}'),
                      initialName: s.prodsName,
                      initialAvailable: s.prodsAvailable,
                      isNew: false,
                      saving: _saving,
                      onCancel: _cancelEdit,
                      onSave: (name, available) =>
                          _saveSize(s.prodsId, name, available),
                    )
                  else
                    _NameRow(
                      name: s.prodsName,
                      available: s.prodsAvailable,
                      prodCount: s.prodCount,
                      enabled: _editKey == null,
                      onEdit: () =>
                          setState(() => _editKey = 'size-${s.prodsId}'),
                      onDelete: () => _deleteSize(s),
                    ),
                if (creating)
                  _NameEditRow(
                    key: const ValueKey('size-new'),
                    initialName: '',
                    initialAvailable: true,
                    isNew: true,
                    saving: _saving,
                    onCancel: _cancelEdit,
                    onSave: (name, available) =>
                        _saveSize(null, name, available),
                  ),
              ],
            ),
    );
  }

  Future<void> _saveSize(int? id, String name, bool available) async {
    if (name.trim().isEmpty) {
      _toast('El nombre es obligatorio.');
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(variantsControllerProvider.notifier);
    final error = id == null
        ? await notifier.createSize(name.trim())
        : await notifier.updateSize(id, name.trim(), available);
    _finishEdit(error);
  }

  Future<void> _deleteSize(ProductSize s) async {
    if (s.prodCount > 0) {
      _toast(
        'Primero desvincula los productos ligados al tamaño "${s.prodsName}" '
        'antes de eliminarlo.',
      );
      return;
    }
    final ok = await _confirmDelete(
      'Eliminar tamaño',
      '¿Seguro que quieres eliminar el tamaño "${s.prodsName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(variantsControllerProvider.notifier)
        .deleteSize(s.prodsId);
    if (error != null) _toast(error);
  }

  // ===========================================================================
  // Options section
  // ===========================================================================

  Widget _buildOptionsSection(List<ProductOption> options) {
    final creating = _editKey == 'opt-new';
    return _Section(
      title: 'Opciones',
      addLabel: 'Agregar opción',
      onAdd: _editKey == null
          ? () => setState(() => _editKey = 'opt-new')
          : null,
      child: (options.isEmpty && !creating)
          ? const _EmptyState(
              icon: Icons.tune_outlined,
              title: 'Sin opciones',
              message: 'Esta sucursal aún no tiene opciones registradas.',
            )
          : _Card(
              minWidth: 640,
              children: [
                const _TableHeader(
                  columns: [
                    _Col('NOMBRE', 42),
                    _Col('PRODUCTOS', 28),
                    _Col('ESTADO', 20),
                    _Col('', 12),
                  ],
                ),
                for (final o in options)
                  if (_editKey == 'opt-${o.prodoId}')
                    _NameEditRow(
                      key: ValueKey('opt-edit-${o.prodoId}'),
                      initialName: o.prodoName,
                      initialAvailable: o.prodoAvailable,
                      isNew: false,
                      saving: _saving,
                      onCancel: _cancelEdit,
                      onSave: (name, available) =>
                          _saveOption(o.prodoId, name, available),
                    )
                  else
                    _NameRow(
                      name: o.prodoName,
                      available: o.prodoAvailable,
                      prodCount: o.prodCount,
                      enabled: _editKey == null,
                      onEdit: () =>
                          setState(() => _editKey = 'opt-${o.prodoId}'),
                      onDelete: () => _deleteOption(o),
                    ),
                if (creating)
                  _NameEditRow(
                    key: const ValueKey('opt-new'),
                    initialName: '',
                    initialAvailable: true,
                    isNew: true,
                    saving: _saving,
                    onCancel: _cancelEdit,
                    onSave: (name, available) =>
                        _saveOption(null, name, available),
                  ),
              ],
            ),
    );
  }

  Future<void> _saveOption(int? id, String name, bool available) async {
    if (name.trim().isEmpty) {
      _toast('El nombre es obligatorio.');
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(variantsControllerProvider.notifier);
    final error = id == null
        ? await notifier.createOption(name.trim())
        : await notifier.updateOption(id, name.trim(), available);
    _finishEdit(error);
  }

  Future<void> _deleteOption(ProductOption o) async {
    if (o.prodCount > 0) {
      _toast(
        'Primero desvincula los productos ligados a la opción "${o.prodoName}" '
        'antes de eliminarla.',
      );
      return;
    }
    final ok = await _confirmDelete(
      'Eliminar opción',
      '¿Seguro que quieres eliminar la opción "${o.prodoName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(variantsControllerProvider.notifier)
        .deleteOption(o.prodoId);
    if (error != null) _toast(error);
  }

  // ===========================================================================
  // Additionals (add-ons) section
  // ===========================================================================

  Widget _buildAdditionalsSection(List<ProductAdditional> additionals) {
    final creating = _editKey == 'add-new';
    return _Section(
      title: 'Adicionales',
      addLabel: 'Agregar adicional',
      onAdd: _editKey == null
          ? () => setState(() => _editKey = 'add-new')
          : null,
      child: (additionals.isEmpty && !creating)
          ? const _EmptyState(
              icon: Icons.add_circle_outline,
              title: 'Sin adicionales',
              message: 'Esta sucursal aún no tiene adicionales registrados.',
            )
          : _Card(
              minWidth: 700,
              children: [
                const _TableHeader(
                  columns: [
                    _Col('NOMBRE', 34),
                    _Col('PRECIO', 18),
                    _Col('PRODUCTOS', 24),
                    _Col('ESTADO', 18),
                    _Col('', 12),
                  ],
                ),
                for (final a in additionals)
                  if (_editKey == 'add-${a.prodaId}')
                    _AdditionalEditRow(
                      key: ValueKey('add-edit-${a.prodaId}'),
                      initialName: a.prodaName,
                      initialPrice: a.prodaPrice,
                      initialAvailable: a.prodaAvailable,
                      isNew: false,
                      saving: _saving,
                      onCancel: _cancelEdit,
                      onSave: (name, price, available) =>
                          _saveAdditional(a.prodaId, name, price, available),
                    )
                  else
                    _AdditionalRow(
                      additional: a,
                      enabled: _editKey == null,
                      onEdit: () =>
                          setState(() => _editKey = 'add-${a.prodaId}'),
                      onDelete: () => _deleteAdditional(a),
                    ),
                if (creating)
                  _AdditionalEditRow(
                    key: const ValueKey('add-new'),
                    initialName: '',
                    initialPrice: '',
                    initialAvailable: true,
                    isNew: true,
                    saving: _saving,
                    onCancel: _cancelEdit,
                    onSave: (name, price, available) =>
                        _saveAdditional(null, name, price, available),
                  ),
              ],
            ),
    );
  }

  Future<void> _saveAdditional(
    int? id,
    String name,
    String price,
    bool available,
  ) async {
    if (name.trim().isEmpty) {
      _toast('El nombre es obligatorio.');
      return;
    }
    final parsed = double.tryParse(price.trim());
    if (parsed == null || parsed < 0) {
      _toast('Ingresa un precio válido.');
      return;
    }
    final normalizedPrice = parsed.toStringAsFixed(2);
    setState(() => _saving = true);
    final notifier = ref.read(variantsControllerProvider.notifier);
    final error = id == null
        ? await notifier.createAdditional(name.trim(), normalizedPrice)
        : await notifier.updateAdditional(
            id,
            name.trim(),
            normalizedPrice,
            available,
          );
    _finishEdit(error);
  }

  Future<void> _deleteAdditional(ProductAdditional a) async {
    if (a.prodCount > 0) {
      _toast(
        'Primero desvincula los productos ligados al adicional "${a.prodaName}" '
        'antes de eliminarlo.',
      );
      return;
    }
    final ok = await _confirmDelete(
      'Eliminar adicional',
      '¿Seguro que quieres eliminar el adicional "${a.prodaName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(variantsControllerProvider.notifier)
        .deleteAdditional(a.prodaId);
    if (error != null) _toast(error);
  }

  // ===== shared helpers =====================================================

  /// Clears the saving flag and, when the action succeeded, closes the editor.
  void _finishEdit(String? error) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) _editKey = null;
    });
    if (error != null) _toast(error);
  }

  void _cancelEdit() => setState(() => _editKey = null);

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _confirmDelete(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
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
  }
}

// ===========================================================================
// Section wrapper (title + "add" action + child)
// ===========================================================================

class _Section extends StatelessWidget {
  final String title;
  final String addLabel;
  final VoidCallback? onAdd;
  final Widget child;

  const _Section({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final double minWidth;
  final List<Widget> children;
  const _Card({required this.minWidth, required this.children});

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
        minWidth: minWidth,
        child: Column(children: children),
      ),
    );
  }
}

// ===========================================================================
// Table header
// ===========================================================================

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, this.flex);
}

class _TableHeader extends StatelessWidget {
  final List<_Col> columns;
  const _TableHeader({required this.columns});

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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: Text(c.label, style: style),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Name-only rows (shared by sizes and options)
// ===========================================================================

class _NameRow extends StatelessWidget {
  final String name;
  final bool available;
  final int prodCount;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NameRow({
    required this.name,
    required this.available,
    required this.prodCount,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 42,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(flex: 28, child: _ProductsCount(count: prodCount)),
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AvailabilityChip(available: available),
            ),
          ),
          Expanded(
            flex: 12,
            child: _RowActions(
              enabled: enabled,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameEditRow extends StatefulWidget {
  final String initialName;
  final bool initialAvailable;
  final bool isNew;
  final bool saving;
  final VoidCallback onCancel;
  final void Function(String name, bool available) onSave;

  const _NameEditRow({
    super.key,
    required this.initialName,
    required this.initialAvailable,
    required this.isNew,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_NameEditRow> createState() => _NameEditRowState();
}

class _NameEditRowState extends State<_NameEditRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late bool _available = widget.initialAvailable;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => widget.onSave(_name.text, _available);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 42,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _name,
                hint: 'Nombre',
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const Expanded(flex: 28, child: SizedBox.shrink()),
          Expanded(
            flex: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.isNew
                  ? const SizedBox.shrink()
                  : _StatusToggle(
                      available: _available,
                      onChanged: (v) => setState(() => _available = v),
                    ),
            ),
          ),
          Expanded(
            flex: 12,
            child: _EditActions(
              saving: widget.saving,
              onSave: _submit,
              onCancel: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Additional (add-on) rows — name + price + status
// ===========================================================================

class _AdditionalRow extends StatelessWidget {
  final ProductAdditional additional;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdditionalRow({
    required this.additional,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 34,
            child: Text(
              additional.prodaName,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              additional.priceDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink2,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: _ProductsCount(count: additional.prodCount),
          ),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AvailabilityChip(available: additional.prodaAvailable),
            ),
          ),
          Expanded(
            flex: 12,
            child: _RowActions(
              enabled: enabled,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdditionalEditRow extends StatefulWidget {
  final String initialName;
  final String initialPrice;
  final bool initialAvailable;
  final bool isNew;
  final bool saving;
  final VoidCallback onCancel;
  final void Function(String name, String price, bool available) onSave;

  const _AdditionalEditRow({
    super.key,
    required this.initialName,
    required this.initialPrice,
    required this.initialAvailable,
    required this.isNew,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_AdditionalEditRow> createState() => _AdditionalEditRowState();
}

class _AdditionalEditRowState extends State<_AdditionalEditRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.initialPrice,
  );
  late bool _available = widget.initialAvailable;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() => widget.onSave(_name.text, _price.text, _available);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 34,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _name,
                hint: 'Nombre',
                autofocus: true,
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CellField(
                controller: _price,
                hint: 'Precio',
                decimal: true,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const Expanded(flex: 24, child: SizedBox.shrink()),
          Expanded(
            flex: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.isNew
                  ? const SizedBox.shrink()
                  : _StatusToggle(
                      available: _available,
                      onChanged: (v) => setState(() => _available = v),
                    ),
            ),
          ),
          Expanded(
            flex: 12,
            child: _EditActions(
              saving: widget.saving,
              onSave: _submit,
              onCancel: widget.onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared small widgets
// ===========================================================================

class _CellField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const _CellField({
    required this.controller,
    required this.hint,
    this.decimal = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
          : null,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixText: decimal ? '\$ ' : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
    );
  }
}

class _ProductsCount extends StatelessWidget {
  final int count;
  const _ProductsCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${count == 1 ? 'producto' : 'productos'}',
      style: const TextStyle(fontSize: 13, color: AppColors.ink2),
    );
  }
}

class _RowActions extends StatelessWidget {
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RowActions({
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconBtn(
          icon: Icons.edit_outlined,
          color: AppColors.ink3,
          tooltip: 'Editar',
          onPressed: enabled ? onEdit : null,
        ),
        _IconBtn(
          icon: Icons.delete_outline,
          color: AppColors.red,
          tooltip: 'Eliminar',
          onPressed: enabled ? onDelete : null,
        ),
      ],
    );
  }
}

class _EditActions extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _EditActions({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (saving) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconBtn(
          icon: Icons.check,
          color: AppColors.green,
          tooltip: 'Guardar',
          onPressed: onSave,
        ),
        _IconBtn(
          icon: Icons.close,
          color: AppColors.ink3,
          tooltip: 'Cancelar',
          onPressed: onCancel,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 19),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;
  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? AppColors.available.withValues(alpha: 0.12)
            : AppColors.unavailable.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        available ? 'Disponible' : 'No disponible',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: available ? AppColors.available : AppColors.unavailable,
        ),
      ),
    );
  }
}

/// Tappable variant of [_AvailabilityChip] used while editing a row.
/// Toggles between the two possible `*_available` values (true/false).
class _StatusToggle extends StatelessWidget {
  final bool available;
  final ValueChanged<bool> onChanged;

  const _StatusToggle({required this.available, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.available : AppColors.unavailable;
    return InkWell(
      onTap: () => onChanged(!available),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              available ? 'Disponible' : 'No disponible',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.ink4),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
