import 'package:flutter/material.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_fields_section.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/responsive_layout.dart';

enum _SalePaymentOption { fullCash, downPayment, credit }

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
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _buyerDocumentController = TextEditingController();

  late String _saleDate;
  int _salePriceCents = 0;
  _SalePaymentOption _paymentOption = _SalePaymentOption.fullCash;
  int _downPaymentCents = 0;
  bool _buyerExpanded = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _saleDate = Formatters.todayIsoDate();
    _salePriceCents = widget.vehicle.announcedPriceCents ?? 0;
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _buyerDocumentController.dispose();
    super.dispose();
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

    if (_paymentOption == _SalePaymentOption.downPayment) {
      if (_downPaymentCents <= 0) {
        setState(() {
          _error = 'Informe o valor da entrada recebida hoje.';
        });
        return;
      }
      if (_downPaymentCents >= _salePriceCents) {
        setState(() {
          _error = 'Para receber o valor total hoje, selecione "À vista".';
        });
        return;
      }
    }

    final buyerName = _buyerNameController.text.trim();
    final buyerPhoneDigits = Formatters.digitsOnly(_buyerPhoneController.text);
    final buyerDocDigits = Formatters.digitsOnly(_buyerDocumentController.text);

    final profit = _salePriceCents - widget.totalCostCents;
    final roiPercent = FinancialCalculator.calculateRoiPercent(profit, widget.totalCostCents);
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
            if (buyerName.isNotEmpty) _summaryRow('Comprador:', buyerName),
            if (buyerPhoneDigits.isNotEmpty)
              _summaryRow('Telefone:', Formatters.formatPhone(buyerPhoneDigits)),
            if (buyerDocDigits.isNotEmpty)
              _summaryRow('CPF / CNPJ:', Formatters.formatCpfCnpj(buyerDocDigits)),
            _summaryRow('Custo total:', Formatters.formatCurrency(widget.totalCostCents)),
            _summaryRow('Valor negociado:', Formatters.formatCurrency(_salePriceCents), bold: true),
            const Divider(height: 18),
            _summaryRow(
              isLoss ? 'Prejuízo:' : 'Lucro:',
              '${Formatters.formatCurrency(profit.abs())}${roiPercent != null ? " (${Formatters.formatPercent(roiPercent)})" : ""}',
              valueColor: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
              bold: true,
            ),
            if (_paymentOption == _SalePaymentOption.fullCash)
              _summaryRow(
                'Recebimento à vista:',
                Formatters.formatCurrency(_salePriceCents),
                valueColor: AppTheme.accentBlue,
              )
            else if (_paymentOption == _SalePaymentOption.downPayment) ...[
              _summaryRow(
                'Entrada hoje:',
                Formatters.formatCurrency(_downPaymentCents),
                valueColor: AppTheme.successGreen,
              ),
              _summaryRow(
                'Restante a receber:',
                Formatters.formatCurrency(_salePriceCents - _downPaymentCents),
                valueColor: AppTheme.warningOrange,
              ),
            ] else
              _summaryRow(
                'Saldo a receber:',
                Formatters.formatCurrency(_salePriceCents),
                valueColor: AppTheme.warningOrange,
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

      final initialPaymentCents = switch (_paymentOption) {
        _SalePaymentOption.fullCash => _salePriceCents,
        _SalePaymentOption.downPayment => _downPaymentCents,
        _SalePaymentOption.credit => 0,
      };

      if (initialPaymentCents > 0) {
        payments.add(
          Payment(
            id: 'pay_${now.millisecondsSinceEpoch}',
            amountCents: initialPaymentCents,
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
        buyerName: buyerName.isEmpty ? null : buyerName,
        buyerPhone: buyerPhoneDigits.isEmpty ? null : buyerPhoneDigits,
        buyerDocument: buyerDocDigits.isEmpty ? null : buyerDocDigits,
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
          _error = ErrorMessages.friendly(
            e,
            fallback: 'Não foi possível registrar a venda. Tente novamente.',
          );
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
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppTheme.textMain,
                fontFeatures: AppTheme.tabularNumbers,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionPill({
    required _SalePaymentOption option,
    required String label,
    required IconData icon,
  }) {
    final selected = _paymentOption == option;
    return Expanded(
      child: Material(
        color: selected ? AppTheme.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _paymentOption = option;
              _error = null;
            });
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppTheme.primaryDark : AppTheme.borderInteractive,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : AppTheme.textMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: const StrutStyle(
                      fontSize: 12,
                      height: 1.15,
                      forceStrutHeight: true,
                    ),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.textMain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profit = _salePriceCents > 0 ? _salePriceCents - widget.totalCostCents : 0;
    final roiPercent = _salePriceCents > 0
        ? FinancialCalculator.calculateRoiPercent(profit, widget.totalCostCents)
        : null;
    final isLoss = profit < 0;

    final paymentHelperText = switch (_paymentOption) {
      _SalePaymentOption.fullCash => 'Valor total recebido na data da venda.',
      _SalePaymentOption.downPayment => 'Registra a entrada hoje e deixa o restante em aberto.',
      _SalePaymentOption.credit => 'Valor integral ficará em aberto para receber depois.',
    };

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Registrar Venda',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
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
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
                          tooltip: 'Fechar',
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

                    // Indicador de lucro ou prejuízo com ROI %
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
                            Expanded(
                              child: Text(
                                isLoss ? 'Prejuízo na venda:' : 'Lucro na venda:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${isLoss ? "-" : "+"}${Formatters.formatCurrency(profit.abs())}${roiPercent != null ? " (${Formatters.formatPercent(roiPercent)})" : ""}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Opções de recebimento (À vista, Entrada + Restante, A receber)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Forma de recebimento',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildPaymentOptionPill(
                                option: _SalePaymentOption.fullCash,
                                label: 'À vista',
                                icon: Icons.check_circle_outline,
                              ),
                              const SizedBox(width: 6),
                              _buildPaymentOptionPill(
                                option: _SalePaymentOption.downPayment,
                                label: 'Entrada',
                                icon: Icons.call_split_outlined,
                              ),
                              const SizedBox(width: 6),
                              _buildPaymentOptionPill(
                                option: _SalePaymentOption.credit,
                                label: 'A receber',
                                icon: Icons.schedule_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            paymentHelperText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_paymentOption == _SalePaymentOption.downPayment) ...[
                      const SizedBox(height: 12),
                      CurrencyTextField(
                        label: 'Valor da entrada hoje *',
                        initialValueCents: _downPaymentCents,
                        required: true,
                        onChanged: (cents) {
                          setState(() {
                            _downPaymentCents = cents;
                          });
                        },
                      ),
                      if (_salePriceCents > 0) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (_) {
                            final remaining = _salePriceCents - _downPaymentCents;
                            final isInvalid = _downPaymentCents > 0 && remaining <= 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isInvalid ? AppTheme.dangerLight : AppTheme.warningLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isInvalid ? AppTheme.dangerBorder : AppTheme.warningBorder,
                                ),
                              ),
                              child: Text(
                                isInvalid
                                    ? 'A entrada deve ser menor que o valor negociado (ou selecione "À vista").'
                                    : 'Restante a receber depois: ${Formatters.formatCurrency(remaining > 0 ? remaining : _salePriceCents)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isInvalid ? AppTheme.dangerRed : AppTheme.warningOrange,
                                  fontFeatures: AppTheme.tabularNumbers,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),

                    // Dados do comprador (opcional e recolhível para agilizar vendas rápidas)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _buyerExpanded = !_buyerExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 18, color: AppTheme.accentBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Dados do comprador (opcional)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textMain,
                                          ),
                                        ),
                                        if (!_buyerExpanded)
                                          const Text(
                                            'Nome, telefone e CPF/CNPJ',
                                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _buyerExpanded ? Icons.expand_less : Icons.expand_more,
                                    size: 20,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_buyerExpanded) ...[
                            const Divider(height: 1, color: AppTheme.borderSubtle),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: BuyerFieldsSection(
                                nameController: _buyerNameController,
                                phoneController: _buyerPhoneController,
                                documentController: _buyerDocumentController,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.dangerBorder),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
