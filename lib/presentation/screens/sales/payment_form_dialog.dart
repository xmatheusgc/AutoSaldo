import 'package:flutter/material.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/payment.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/responsive_layout.dart';

class PaymentFormDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final ActiveSale activeSale;
  final String userUid;
  final VehicleRepository vehicleRepository;

  const PaymentFormDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.activeSale,
    required this.userUid,
    required this.vehicleRepository,
  });

  @override
  State<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _paymentDate;
  int _amountCents = 0;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _paymentDate = Formatters.todayIsoDate();
    _amountCents = widget.activeSale.balanceDueCents;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountCents <= 0) {
      setState(() {
        _error = 'O valor recebido deve ser maior que zero.';
      });
      return;
    }

    if (_amountCents > widget.activeSale.balanceDueCents) {
      setState(() {
        _error = 'O valor não pode ultrapassar o saldo a receber de ${Formatters.formatCurrency(widget.activeSale.balanceDueCents)}.';
      });
      return;
    }

    if (!Validators.isValidPaymentDate(widget.activeSale.saleDate, _paymentDate)) {
      setState(() {
        _error = 'A data do recebimento deve ser igual ou posterior à data da venda (${Formatters.formatDate(widget.activeSale.saleDate)}) e não pode ser futura.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final payment = Payment(
        id: 'pay_${now.millisecondsSinceEpoch}',
        amountCents: _amountCents,
        date: _paymentDate,
        createdAt: now,
        createdByUid: widget.userUid,
      );

      await widget.vehicleRepository.addPayment(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicleId,
        payment: payment,
        userUid: widget.userUid,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMessages.friendly(
            e,
            fallback: 'Não foi possível registrar o recebimento. Tente novamente.',
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

  @override
  Widget build(BuildContext context) {
    final balanceDue = widget.activeSale.balanceDueCents;

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
                                'Receber Parcela',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Saldo restante: ${Formatters.formatCurrency(balanceDue)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: AppTheme.tabularNumbers,
                                ),
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
                      label: 'Data do recebimento *',
                      isoDate: _paymentDate,
                      minIsoDate: widget.activeSale.saleDate,
                      onDateSelected: (newDate) {
                        setState(() {
                          _paymentDate = newDate;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    CurrencyTextField(
                      label: 'Valor recebido *',
                      initialValueCents: _amountCents,
                      required: true,
                      onChanged: (cents) {
                        setState(() {
                          _amountCents = cents;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Gravar
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
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
                          : const Text('Confirmar Recebimento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
          ],
        ),
      ),
    );
  }
}
