import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';

class UpdateSalePriceDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final ActiveSale activeSale;
  final String userUid;
  final VehicleRepository vehicleRepository;

  const UpdateSalePriceDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.activeSale,
    required this.userUid,
    required this.vehicleRepository,
  });

  @override
  State<UpdateSalePriceDialog> createState() => _UpdateSalePriceDialogState();
}

class _UpdateSalePriceDialogState extends State<UpdateSalePriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _newPriceCents;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newPriceCents = widget.activeSale.salePriceCents;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPriceCents <= 0) {
      setState(() {
        _error = 'O valor deve ser maior que zero.';
      });
      return;
    }

    final totalReceived = widget.activeSale.totalReceivedCents;
    if (_newPriceCents < totalReceived) {
      setState(() {
        _error = 'O valor não pode ser menor que o total já recebido (${Formatters.formatCurrency(totalReceived)}).';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.vehicleRepository.updateSalePrice(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicleId,
        newSalePriceCents: _newPriceCents,
        userUid: widget.userUid,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao atualizar valor da venda: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReceived = widget.activeSale.totalReceivedCents;

    return AlertDialog(
      title: const Text('Corrigir Valor Negociado'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total já recebido:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    Text(
                      Formatters.formatCurrency(totalReceived),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                CurrencyTextField(
                  label: 'Novo valor da venda *',
                  initialValueCents: _newPriceCents,
                  required: true,
                  onChanged: (cents) {
                    setState(() {
                      _newPriceCents = cents;
                    });
                  },
                  helperText: 'Deve ser igual ou maior que o total já recebido.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Atualizar'),
        ),
      ],
    );
  }
}

