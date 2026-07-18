import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/tables/controllers/tables_controller.dart';
import 'package:ds_clickeat_web_admin/features/tables/models/table_section.dart';

/// Fixed cell width for the zone table grid (matches the design's
/// `minmax(118px, 1fr)` columns closely enough for a Wrap layout).
const double _kCellWidth = 132;

class TablesPage extends ConsumerStatefulWidget {
  const TablesPage({super.key});

  @override
  ConsumerState<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends ConsumerState<TablesPage> {
  int? _lastPremId;

  void _ensurePremiseLoaded(int? premId) {
    if (premId == null || premId == _lastPremId) return;
    _lastPremId = premId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPremise(premId);
    });
  }

  void _loadPremise(int premId) {
    ref.read(tablesControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final tablesState = ref.watch(tablesControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    final tableCount = tablesState.tableCount;
    final zoneCount = tablesState.sections.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== header =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mesas y zonas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tableCount ${tableCount == 1 ? 'mesa' : 'mesas'} '
                      'en $zoneCount ${zoneCount == 1 ? 'zona' : 'zonas'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: premId == null ? null : () => _createZone(premId),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Zona'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.navy.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white70,
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildContent(premId, tablesState)),
        ],
      ),
    );
  }

  Widget _buildContent(int? premId, TablesState state) {
    if (premId == null) {
      return const SizedBox.shrink();
    }
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
    if (state.sections.isEmpty) {
      return const _EmptyState(
        icon: Icons.table_restaurant_outlined,
        title: 'Sin zonas',
        message: 'Crea una zona para empezar a organizar las mesas.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in state.sections)
            _ZoneGroup(
              section: section,
              onAddTable: () => _addTable(premId, section),
              onRemoveTable: (tablId) => _removeTable(premId, section, tablId),
              onEdit: () => _editZone(premId, section),
              onDelete: () => _deleteZone(premId, section),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _createZone(int premId) async {
    final name = await _promptText(
      title: 'Nueva zona',
      label: 'Nombre de la zona',
      hint: 'Ej. Terraza',
      confirmLabel: 'Crear',
    );
    if (name == null) return;
    final error = await ref
        .read(tablesControllerProvider.notifier)
        .createSection(premId, name);
    if (error != null) _toast(error);
  }

  Future<void> _editZone(int premId, TableSection section) async {
    final name = await _promptText(
      title: 'Editar zona',
      label: 'Nombre de la zona',
      hint: 'Ej. Terraza',
      initial: section.sectName,
      confirmLabel: 'Guardar',
    );
    if (name == null) return;
    final error = await ref
        .read(tablesControllerProvider.notifier)
        .updateSection(premId, section.sectId, name);
    if (error != null) _toast(error);
  }

  Future<void> _deleteZone(int premId, TableSection section) async {
    final ok = await _confirmDelete(
      'Eliminar zona',
      '¿Seguro que quieres eliminar la zona "${section.sectName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(tablesControllerProvider.notifier)
        .deleteSection(premId, section.sectId);
    if (error != null) _toast(error);
  }

  Future<void> _addTable(int premId, TableSection section) async {
    // A table can only live in one zone, so validate against every zone — not
    // just this one — inside the dialog before it closes.
    final sections = ref.read(tablesControllerProvider).sections;
    String? validate(int number) {
      for (final s in sections) {
        if (s.tableIds.contains(number)) {
          return s.sectId == section.sectId
              ? 'La mesa $number ya está en esta zona.'
              : 'La mesa $number ya está en la zona "${s.sectName}".';
        }
      }
      return null;
    }

    final number = await _promptNumber(
      title: 'Agregar mesa',
      label: 'Número de mesa',
      hint: 'Ej. 7',
      validator: validate,
    );
    if (number == null) return;
    final error = await ref
        .read(tablesControllerProvider.notifier)
        .addTable(premId, section.sectId, number);
    if (error != null) _toast(error);
  }

  Future<void> _removeTable(
    int premId,
    TableSection section,
    int tablId,
  ) async {
    final error = await ref
        .read(tablesControllerProvider.notifier)
        .removeTable(premId, section.sectId, tablId);
    if (error != null) _toast(error);
  }

  // ===== shared helpers =====================================================

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

  /// Free-text input dialog. Returns the trimmed value, or null if cancelled or
  /// left empty.
  Future<String?> _promptText({
    required String title,
    required String label,
    required String hint,
    String initial = '',
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialog(
        title: title,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        initial: initial,
        validate: (text) {
          final value = text.trim();
          if (value.isEmpty) {
            return (error: 'El nombre es obligatorio.', value: null);
          }
          return (error: null, value: value);
        },
      ),
    );
  }

  /// Numeric input dialog. Returns the entered table number, or null if
  /// cancelled. [validator] receives the parsed number and returns an error
  /// message to show inline (keeping the dialog open) or null to accept.
  Future<int?> _promptNumber({
    required String title,
    required String label,
    required String hint,
    String? Function(int)? validator,
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => _InputDialog(
        title: title,
        label: label,
        hint: hint,
        confirmLabel: 'Agregar',
        numeric: true,
        validate: (text) {
          final value = int.tryParse(text.trim());
          if (value == null || value <= 0) {
            return (error: 'Ingresa un número de mesa válido.', value: null);
          }
          final err = validator?.call(value);
          return (error: err, value: err == null ? value : null);
        },
      ),
    );
  }
}

// ===========================================================================
// Zone group (header + table grid)
// ===========================================================================

class _ZoneGroup extends StatelessWidget {
  final TableSection section;
  final VoidCallback onAddTable;
  final ValueChanged<int> onRemoveTable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ZoneGroup({
    required this.section,
    required this.onAddTable,
    required this.onRemoveTable,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final count = section.tableIds.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- zone header -----
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 18, color: AppColors.navy),
              const SizedBox(width: 8),
              Text(
                section.sectName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· $count ${count == 1 ? 'mesa' : 'mesas'}',
                style: const TextStyle(fontSize: 13, color: AppColors.ink3),
              ),
              const Spacer(),
              _HeaderIconBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Editar zona',
                color: AppColors.ink3,
                onPressed: onEdit,
              ),
              _HeaderIconBtn(
                icon: Icons.delete_outline,
                tooltip: 'Eliminar zona',
                color: AppColors.red,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 13),
          // ----- table grid: add button first, then the tables -----
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AddTableCard(onTap: onAddTable),
              for (final tablId in section.tableIds)
                _TableCard(
                  tablId: tablId,
                  onRemove: () => onRemoveTable(tablId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
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

// ===========================================================================
// Table card
// ===========================================================================

class _TableCard extends StatelessWidget {
  final int tablId;
  final VoidCallback onRemove;

  const _TableCard({required this.tablId, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCellWidth,
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // #mesa badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$tablId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const Spacer(),
              // remove-from-zone icon
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(8),
                child: const Tooltip(
                  message: 'Quitar mesa',
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // Mesa #
          Text(
            'Mesa $tablId',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTableCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTableCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: _kCellWidth,
        constraints: const BoxConstraints(minHeight: 118),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.line,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 22, color: AppColors.ink3),
            SizedBox(height: 6),
            Text(
              'Agregar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Input dialog (shared by zone create/edit and add-table)
// ===========================================================================

/// Result of an [_InputDialog] validation: an [error] to show inline (keeps the
/// dialog open) or a [value] to pop when [error] is null.
typedef _InputResult = ({String? error, Object? value});

class _InputDialog extends StatefulWidget {
  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final String initial;
  final bool numeric;
  final _InputResult Function(String text) validate;

  const _InputDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.validate,
    this.initial = '',
    this.numeric = false,
  });

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final result = widget.validate(_controller.text);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop(result.value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.numeric
                ? TextInputType.number
                : TextInputType.text,
            inputFormatters: widget.numeric
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _error != null ? AppColors.red : AppColors.line,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _error != null ? AppColors.red : AppColors.navy,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

// ===========================================================================
// Empty state
// ===========================================================================

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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.ink4),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
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
