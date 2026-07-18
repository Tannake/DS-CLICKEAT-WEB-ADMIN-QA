import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/theme/app_theme.dart';
import 'package:ds_clickeat_web_admin/features/inventory/controllers/inventory_controller.dart';
import 'package:ds_clickeat_web_admin/features/inventory/models/inventory_product.dart';

/// Opens the stock-edit modal for a single variant. Unlike the POS version,
/// the admin panel does NOT ask for an authorization code.
Future<void> showInventoryEditDialog(
  BuildContext context, {
  required int premId,
  required InventoryProduct product,
  required InventoryCollect collect,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _InventoryEditDialog(
      premId: premId,
      product: product,
      collect: collect,
    ),
  );
}

class _InventoryEditDialog extends ConsumerStatefulWidget {
  final int premId;
  final InventoryProduct product;
  final InventoryCollect collect;

  const _InventoryEditDialog({
    required this.premId,
    required this.product,
    required this.collect,
  });

  @override
  ConsumerState<_InventoryEditDialog> createState() =>
      _InventoryEditDialogState();
}

class _InventoryEditDialogState extends ConsumerState<_InventoryEditDialog> {
  late final TextEditingController _stockCtrl =
      TextEditingController(text: '${widget.collect.stock}');
  late bool _available = widget.collect.available;
  bool _saving = false;
  String? _stockError;

  @override
  void dispose() {
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _stockError = null);

    final text = _stockCtrl.text.trim();
    final newStock = int.tryParse(text);
    if (text.isEmpty || newStock == null) {
      setState(() => _stockError = 'Ingresa una cantidad válida');
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await ref.read(inventoryControllerProvider.notifier).updateStock(
          premId: widget.premId,
          prodId: widget.product.prodId,
          prodsId: widget.collect.prodsId,
          prodoId: widget.collect.prodoId,
          stock: newStock,
          available: _available,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Inventario actualizado.' : 'No se pudo actualizar el inventario.',
        ),
      ),
    );
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sizeName = widget.product.sizeNameOf(widget.collect.prodsId);
    final optionName = widget.product.optionNameOf(widget.collect.prodoId);
    final hasVariant = sizeName.isNotEmpty || optionName.isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Actualizar inventario',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.ink3),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      if (hasVariant) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (sizeName.isNotEmpty)
                              _VariantTag(label: sizeName),
                            if (optionName.isNotEmpty)
                              _VariantTag(label: optionName),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(
                          height: 1, thickness: 1, color: AppColors.line),
                      const SizedBox(height: 18),

                      // Stock field
                      const _FieldLabel('Cantidad en inventario'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _stockCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        ],
                        style:
                            const TextStyle(fontSize: 14, color: AppColors.ink),
                        onSubmitted: (_) => _saving ? null : _submit(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Ej. 50',
                          errorText: _stockError,
                          filled: true,
                          fillColor: AppColors.surface2,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
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

                      const SizedBox(height: 16),

                      // Availability toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _available
                              ? AppColors.green.withValues(alpha: 0.10)
                              : AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _available
                                ? AppColors.green.withValues(alpha: 0.35)
                                : AppColors.line,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _available ? 'Disponible' : 'No disponible',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _available
                                          ? AppColors.greenInk
                                          : AppColors.ink2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _available
                                        ? 'El producto se puede pedir'
                                        : 'El producto no se puede seleccionar',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.ink3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _available,
                              onChanged: (v) => setState(() => _available = v),
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.green,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: AppColors.ink4,
                              trackOutlineColor:
                                  WidgetStateProperty.all(Colors.transparent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.line),
                      shape: const StadiumBorder(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_saving ? 'Guardando…' : 'Confirmar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      shape: const StadiumBorder(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
      ),
    );
  }
}

class _VariantTag extends StatelessWidget {
  final String label;
  const _VariantTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink2,
        ),
      ),
    );
  }
}
