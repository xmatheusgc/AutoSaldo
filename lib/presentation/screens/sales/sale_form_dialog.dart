import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';

class SaleFormDialog extends StatefulWidget {
  final String workspaceId;
  final Vehicle vehicle;
  final int totalCostCents;
  final String userUid;
  final VehicleRepository vehicleRepository;

  const SaleFormDialog({
    super.key,
    required this.workspaceId,
    required this.vehicle,
    required this.totalCostCents,
    required this.userUid,
    required this.vehicleRepository,
  });

  @override
  State<SaleFormDialog> createState() => _SaleFormDialogState();
}

class _SaleFormDialogState extends State<SaleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _saleDate;
  int _salePriceCents = 0;
  bool _receiveAllAtSale = true; // Atalho à vista por padrão
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _saleDate = Formatters.todayIsoDate();
    // Sugere preço anunciado se preenchido
    _salePriceCents = widget.vehicle.announcedPriceCents ?? 0;
  }

  Future<void> _handleConfirmSale() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salePriceCents <= 0) {
      setState(() {
        _error = 'O valor negociado deve ser maior que zero.';
      });
      return;
    }

    if (!Validators.isValidSaleDate(widget.vehicle.purchaseDate, _saleDate)) {
      setState(() {
        _error = 'A data da venda deve ser igual ou posterior à data da compra (${Formatters.formatDate(widget.vehicle.purchaseDate)}) e não pode ser futura.';
      });
      return;
    }

    // Diálogo de confirmação do resumo antes de gravar
    final profit = _salePriceCents - widget.totalCostCents;
    final isLoss = profit < 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Venda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confira o resumo financeiro antes de registrar:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            _summaryRow('Veículo:', widget.vehicle.title),
            _summaryRow('Placa:', widget.vehicle.formattedPlate),
            _summaryRow('Data da venda:', Formatters.formatDate(_saleDate)),
            _summaryRow('Custo total:', Formatters.formatCurrency(widget.totalCostCents)),
            _summaryRow('Valor negociado:', Formatters.formatCurrency(_salePriceCents), bold: true),
            const Divider(height: 20),
            _summaryRow(
              isLoss ? 'Prejuízo estimado:' : 'Lucro na venda:',
              Formatters.formatCurrency(profit.abs()),
              valueColor: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
              bold: true,
            ),
            if (_receiveAllAtSale) ...[
              const SizedBox(height: 8),
              _summaryRow('Recebimento à vista:', Formatters.formatCurrency(_salePriceCents), valueColor: AppTheme.accentBlue),
            ] else ...[
              const SizedBox(height: 8),
              _summaryRow('Saldo a receber:', Formatters.formatCurrency(_salePriceCents), valueColor: AppTheme.warningOrange),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar e revisar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
            child: const Text('Confirmar e Gravar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final saleId = 'sale_${now.millisecondsSinceEpoch}';

      final List<Payment> initialPayments = [];
      if (_receiveAllAtSale) {
        initialPayments.add(Payment(
          id: 'pay_${now.millisecondsSinceEpoch}',
          amountCents: _salePriceCents,
          date: _saleDate,
          createdAt: now,
          createdByUid: widget.userUid,
        ));
      }

      final activeSale = ActiveSale(
        id: saleId,
        saleDate: _saleDate,
        salePriceCents: _salePriceCents,
        payments: initialPayments,
        createdAt: now,
        updatedAt: now,
        createdByUid: widget.userUid,
        updatedByUid: widget.userUid,
      );

      await widget.vehicleRepository.registerSale(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicle.id,
        sale: activeSale,
        userUid: widget.userUid,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao registrar venda: $e';
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

  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profit = _salePriceCents > 0 ? _salePriceCents - widget.totalCostCents : 0;
    final isLoss = profit < 0;

    return AlertDialog(
      title: const Text('Registrar Venda'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.vehicle.title} • ${widget.vehicle.formattedPlate}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                ),
                Text(
                  'Custo total investido: ${Formatters.formatCurrency(widget.totalCostCents)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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

                DatePickerField(
                  label: 'Data da venda *',
                  isoDate: _saleDate,
                  minIsoDate: widget.vehicle.purchaseDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      _saleDate = newDate;
                    });
                  },
                  helperText: 'Deve ser igual ou posterior a ${Formatters.formatDate(widget.vehicle.purchaseDate)}.',
                ),
                const SizedBox(height: 14),

                CurrencyTextField(
                  label: 'Valor final negociado *',
                  initialValueCents: _salePriceCents,
                  required: true,
                  onChanged: (cents) {
                    setState(() {
                      _salePriceCents = cents;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Indicador de lucro ou prejuízo em tempo real
                if (_salePriceCents > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLoss ? AppTheme.dangerLight : AppTheme.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLoss ? 'Prejuízo na venda:' : 'Lucro na venda:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(profit.abs()),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Atalho receber total na venda
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Receber total na venda (à vista)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Registra entrada do valor integral na data da venda.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    value: _receiveAllAtSale,
                    activeThumbColor: AppTheme.accentBlue,
                    onChanged: (val) {
                      setState(() {
                        _receiveAllAtSale = val;
                      });
                    },
                  ),
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
          onPressed: _isSaving ? null : _handleConfirmSale,
          style: ElevatedButton.styleFrom(minimumSize: const Size(130, 44)),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Continuar'),
        ),
      ],
    );
  }
}
