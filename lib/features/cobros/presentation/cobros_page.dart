import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/payments/controllers/payments_controller.dart';
import 'package:ds_clickeat_web_admin/features/payments/models/payment_method.dart';
import 'package:ds_clickeat_web_admin/features/premises/controllers/premises_controller.dart';
import 'package:ds_clickeat_web_admin/features/tips/controllers/tips_controller.dart';
import 'package:ds_clickeat_web_admin/features/tips/models/tip.dart';

/// Fixed card width for the cobros grids (matches the design's
/// `minmax(280px, 1fr)` columns).
const double _kCardWidth = 300;

/// "Cobros" groups everything related to taking payment for an order:
/// the payment methods (`payments/<premId>`) and the tip presets
/// (`orders/tips/<premId>`). Both are shown with the same card layout.
class CobrosPage extends ConsumerStatefulWidget {
  const CobrosPage({super.key});

  @override
  ConsumerState<CobrosPage> createState() => _CobrosPageState();
}

class _CobrosPageState extends ConsumerState<CobrosPage> {
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
    ref.read(paymentsControllerProvider.notifier).load(premId);
    ref.read(tipsControllerProvider.notifier).load(premId);
  }

  @override
  Widget build(BuildContext context) {
    final premState = ref.watch(premisesControllerProvider);
    final paymentsState = ref.watch(paymentsControllerProvider);
    final tipsState = ref.watch(tipsControllerProvider);
    final premId = premState.selectedPremId;
    _ensurePremiseLoaded(premId);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cobros',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Métodos de pago y propinas disponibles al cobrar.',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paymentsSection(premId, paymentsState),
                  const SizedBox(height: 28),
                  _tipsSection(premId, tipsState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Payment methods section
  // ===========================================================================

  Widget _paymentsSection(int? premId, PaymentsState state) {
    final total = state.methods.length;
    final available = state.availableCount;
    return _Section(
      title: 'Métodos de pago',
      subtitle:
          '$available de $total '
          '${total == 1 ? 'método activo' : 'métodos activos'}',
      addLabel: 'Método',
      onAdd: premId == null ? null : () => _createPayment(premId),
      child: _paymentsContent(premId, state),
    );
  }

  Widget _paymentsContent(int? premId, PaymentsState state) {
    if (premId == null) return const SizedBox.shrink();
    if (state.loading) {
      return const _SectionLoading();
    }
    if (state.error != null) {
      return _SectionError(state.error!);
    }
    if (state.methods.isEmpty) {
      return const _EmptyState(
        icon: Icons.payment_outlined,
        title: 'Sin métodos de pago',
        message: 'Agrega un método de pago para esta sucursal.',
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final m in state.methods)
          _CobroCard(
            title: m.paymName,
            available: m.paymAvailable,
            onToggle: () => _togglePayment(premId, m),
            onEdit: () => _editPayment(premId, m),
            onDelete: () => _deletePayment(premId, m),
          ),
      ],
    );
  }

  // ===========================================================================
  // Tips section
  // ===========================================================================

  Widget _tipsSection(int? premId, TipsState state) {
    final total = state.tips.length;
    final available = state.availableCount;
    return _Section(
      title: 'Propinas',
      subtitle:
          '$available de $total '
          '${total == 1 ? 'propina activa' : 'propinas activas'}',
      addLabel: 'Propina',
      onAdd: premId == null ? null : () => _createTip(premId),
      child: _tipsContent(premId, state),
    );
  }

  Widget _tipsContent(int? premId, TipsState state) {
    if (premId == null) return const SizedBox.shrink();
    if (state.loading) {
      return const _SectionLoading();
    }
    if (state.error != null) {
      return _SectionError(state.error!);
    }
    if (state.tips.isEmpty) {
      return const _EmptyState(
        icon: Icons.percent,
        title: 'Sin propinas',
        message: 'Agrega un porcentaje de propina para esta sucursal.',
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final t in state.tips)
          _CobroCard(
            title: '${t.tipsPercentage}%',
            available: t.tipsAvailable,
            onToggle: () => _toggleTip(premId, t),
            onEdit: () => _editTip(premId, t),
            onDelete: () => _deleteTip(premId, t),
          ),
      ],
    );
  }

  // ===========================================================================
  // Payment actions
  // ===========================================================================

  Future<void> _createPayment(int premId) async {
    final result = await _showNameEditor(title: 'Nuevo método de pago');
    if (result == null) return;
    final error = await ref
        .read(paymentsControllerProvider.notifier)
        .createPayment(premId, result.name, result.available);
    if (error != null) _toast(error);
  }

  Future<void> _editPayment(int premId, PaymentMethod method) async {
    final result = await _showNameEditor(
      title: 'Editar método de pago',
      initialName: method.paymName,
      initialAvailable: method.paymAvailable,
    );
    if (result == null) return;
    final error = await ref
        .read(paymentsControllerProvider.notifier)
        .updatePayment(premId, method.paymId, result.name, result.available);
    if (error != null) _toast(error);
  }

  Future<void> _deletePayment(int premId, PaymentMethod method) async {
    final ok = await _confirmDelete(
      'Eliminar método de pago',
      '¿Seguro que quieres eliminar "${method.paymName}"?',
    );
    if (ok != true) return;
    final error = await ref
        .read(paymentsControllerProvider.notifier)
        .deletePayment(premId, method.paymId);
    if (error != null) _toast(error);
  }

  Future<void> _togglePayment(int premId, PaymentMethod method) async {
    final error = await ref
        .read(paymentsControllerProvider.notifier)
        .toggleAvailable(premId, method);
    if (error != null) _toast(error);
  }

  // ===========================================================================
  // Tip actions
  // ===========================================================================

  Future<void> _createTip(int premId) async {
    final percentage = await _showTipEditor(title: 'Nueva propina');
    if (percentage == null) return;
    final error = await ref
        .read(tipsControllerProvider.notifier)
        .createTip(premId, percentage);
    if (error != null) _toast(error);
  }

  Future<void> _editTip(int premId, Tip tip) async {
    final percentage = await _showTipEditor(
      title: 'Editar propina',
      initialPercentage: tip.tipsPercentage,
    );
    if (percentage == null) return;
    final error = await ref
        .read(tipsControllerProvider.notifier)
        .updateTip(premId, tip.tipsId, percentage, tip.tipsAvailable);
    if (error != null) _toast(error);
  }

  Future<void> _deleteTip(int premId, Tip tip) async {
    final ok = await _confirmDelete(
      'Eliminar propina',
      '¿Seguro que quieres eliminar la propina de ${tip.tipsPercentage}%?',
    );
    if (ok != true) return;
    final error = await ref
        .read(tipsControllerProvider.notifier)
        .deleteTip(premId, tip.tipsId);
    if (error != null) _toast(error);
  }

  Future<void> _toggleTip(int premId, Tip tip) async {
    final error = await ref
        .read(tipsControllerProvider.notifier)
        .toggleAvailable(premId, tip);
    if (error != null) _toast(error);
  }

  // ===========================================================================
  // Shared helpers
  // ===========================================================================

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

  Future<({String name, bool available})?> _showNameEditor({
    required String title,
    String initialName = '',
    bool initialAvailable = true,
  }) {
    return showDialog<({String name, bool available})>(
      context: context,
      builder: (ctx) => _NameEditor(
        title: title,
        initialName: initialName,
        initialAvailable: initialAvailable,
      ),
    );
  }

  Future<int?> _showTipEditor({required String title, int? initialPercentage}) {
    return showDialog<int>(
      context: context,
      builder: (ctx) =>
          _TipEditor(title: title, initialPercentage: initialPercentage),
    );
  }
}

// ===========================================================================
// Section wrapper (title + subtitle + add button, then a child grid)
// ===========================================================================

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final String addLabel;
  final VoidCallback? onAdd;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
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
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  const _SectionError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.red, fontSize: 14),
        ),
      ),
    );
  }
}

// ===========================================================================
// Cobro card (shared by payment methods and tips)
// ===========================================================================

class _CobroCard extends StatelessWidget {
  final String title;
  final bool available;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CobroCard({
    required this.title,
    required this.available,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCardWidth,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? const Color(0xFFCFE9D8) : AppColors.line,
        ),
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
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _Toggle(on: available, onChanged: (_) => onToggle()),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                available ? 'Disponible' : 'No disponible',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: available ? AppColors.greenInk : AppColors.ink3,
                ),
              ),
              const Spacer(),
              _IconBtn(
                icon: Icons.edit_outlined,
                color: AppColors.ink3,
                tooltip: 'Editar',
                onPressed: onEdit,
              ),
              _IconBtn(
                icon: Icons.delete_outline,
                color: AppColors.red,
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

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

// ===========================================================================
// Toggle (matches the design's green pill switch)
// ===========================================================================

class _Toggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AppColors.green : const Color(0xFFD4DAE3),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Name editor dialog (name + availability) — used by payment methods
// ===========================================================================

class _NameEditor extends StatefulWidget {
  final String title;
  final String initialName;
  final bool initialAvailable;

  const _NameEditor({
    required this.title,
    required this.initialName,
    required this.initialAvailable,
  });

  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late bool _available = widget.initialAvailable;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    Navigator.of(context).pop((name: name, available: _available));
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
          const Text(
            'Nombre',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: _fieldDecoration(hint: 'Ej. Tarjeta', error: _error),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.red),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disponible',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _available ? 'Visible al cobrar' : 'Oculto al cobrar',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              _Toggle(
                on: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
            ],
          ),
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ===========================================================================
// Tip editor dialog (percentage). On insert the backend defaults availability,
// on update it is preserved by the caller, so the dialog only edits the value.
// ===========================================================================

class _TipEditor extends StatefulWidget {
  final String title;
  final int? initialPercentage;

  const _TipEditor({required this.title, this.initialPercentage});

  @override
  State<_TipEditor> createState() => _TipEditorState();
}

class _TipEditorState extends State<_TipEditor> {
  late final TextEditingController _percentage = TextEditingController(
    text: widget.initialPercentage?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _percentage.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_percentage.text.trim());
    if (value == null || value < 0 || value > 100) {
      setState(() => _error = 'Ingresa un porcentaje entre 0 y 100.');
      return;
    }
    Navigator.of(context).pop(value);
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
          const Text(
            'Porcentaje',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _percentage,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: _fieldDecoration(
              hint: 'Ej. 10',
              error: _error,
              suffixText: '%',
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({
  required String hint,
  String? error,
  String? suffixText,
}) {
  return InputDecoration(
    isDense: true,
    hintText: hint,
    suffixText: suffixText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: error != null ? AppColors.red : AppColors.line,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: error != null ? AppColors.red : AppColors.navy,
        width: 1.5,
      ),
    ),
  );
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
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
      ),
    );
  }
}
