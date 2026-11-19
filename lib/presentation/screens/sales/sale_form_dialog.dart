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
import '../../widgets/responsive_layout.dart';

class SaleFormDialog extends StatefulWidget {
  final String workspaceId;
  final Vehicle vehicle;
  final int totalCostCents;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;

  const SaleFormDialog({
    super.key,
    required this.workspaceId,
    required this.vehicle,
    required this.totalCostCents,
    required this.userUid,
    this.userEmail,
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

    final profit = _salePriceCents - widget.totalCostCents;
    final isLoss = profit < 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Venda', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Veículo:', widget.vehicle.title),
            _summaryRow('Placa:', widget.vehicle.formattedPlate),
            _summaryRow('Data:', Formatters.formatDate(_saleDate)),
            _summaryRow('Custo total:', Formatters.formatCurrency(widget.totalCostCents)),
            _summaryRow('Valor negociado:', Formatters.formatCurrency(_salePriceCents), bold: true),
            const Divider(height: 18),
            _summaryRow(
              isLoss ? 'Prejuízo:' : 'Lucro:',
              Formatters.formatCurrency(profit.abs()),
              valueColor: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
              bold: true,
            ),
            _summaryRow(
              _receiveAllAtSale ? 'Recebimento à vista:' : 'Saldo a receber:',
              Formatters.formatCurrency(_salePriceCents),
              valueColor: _receiveAllAtSale ? AppTheme.accentBlue : AppTheme.warningOrange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Venda'),
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
      final payments = <Payment>[];

      if (_receiveAllAtSale) {
        payments.add(
          Payment(
            id: 'pay_${now.millisecondsSinceEpoch}',
            amountCents: _salePriceCents,
            date: _saleDate,
            createdAt: now,
            createdByUid: widget.userUid,
          ),
        );
      }

      final activeSale = ActiveSale(
        id: saleId,
        saleDate: _saleDate,
        salePriceCents: _salePriceCents,
        payments: payments,
        createdAt: now,
        updatedAt: now,
        createdByUid: widget.userUid,
        updatedByUid: widget.userUid,
        createdByEmail: widget.userEmail,
        updatedByEmail: widget.userEmail,
      );

      await widget.vehicleRepository.registerSale(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicle.id,
        sale: activeSale,
        userUid: widget.userUid,
        userEmail: widget.userEmail,
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

    return AdaptiveModalContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

                    // Topo com Título e Fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Registrar Venda',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textMain,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.vehicle.title} • ${widget.vehicle.formattedPlate}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13, fontWeight: FontWeight.w600),
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
                    const SizedBox(height: 12),

                    // Indicador de lucro ou prejuízo
                    if (_salePriceCents > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isLoss ? AppTheme.dangerLight : AppTheme.successLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLoss ? AppTheme.dangerBorder : AppTheme.successBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isLoss ? 'Prejuízo na venda:' : 'Lucro na venda:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                              ),
                            ),
                            Text(
                              '${isLoss ? "-" : "+"}${Formatters.formatCurrency(profit.abs())}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Atalho receber à vista
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Receber total na venda (à vista)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                    const SizedBox(height: 20),

                    // Botão Principal
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleConfirmSale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Continuar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                    ),
          ],
        ),
      ),
    );
  }
}
