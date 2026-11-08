import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/payment.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';

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
    // Sugere o saldo restante
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
          _error = 'Erro ao registrar recebimento: $e';
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

    return AlertDialog(
      title: const Text('Registrar Entrada'),
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
                    const Text('Saldo a receber hoje:', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                    Text(
                      Formatters.formatCurrency(balanceDue),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.warningOrange),
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

                DatePickerField(
                  label: 'Data do recebimento *',
                  isoDate: _paymentDate,
                  minIsoDate: widget.activeSale.saleDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      _paymentDate = newDate;
                    });
                  },
                  helperText: 'Deve ser igual ou posterior à venda (${Formatters.formatDate(widget.activeSale.saleDate)}).',
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            minimumSize: const Size(120, 44),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Gravar'),
        ),
      ],
    );
  }
}

