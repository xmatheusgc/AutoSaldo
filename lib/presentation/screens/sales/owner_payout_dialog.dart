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

class OwnerPayoutDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final ActiveSale activeSale;
  final int netPayoutCents;
  final String? consignorName;
  final String userUid;
  final VehicleRepository vehicleRepository;

  const OwnerPayoutDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.activeSale,
    required this.netPayoutCents,
    this.consignorName,
    required this.userUid,
    required this.vehicleRepository,
  });

  @override
  State<OwnerPayoutDialog> createState() => _OwnerPayoutDialogState();
}

class _OwnerPayoutDialogState extends State<OwnerPayoutDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _payoutDate;
  int _amountCents = 0;
  bool _isSaving = false;
  String? _error;

  int get _remainingDueCents {
    final due = widget.netPayoutCents - widget.activeSale.totalOwnerPayoutPaidCents;
    return due > 0 ? due : 0;
  }

  @override
  void initState() {
    super.initState();
    _payoutDate = Formatters.todayIsoDate();
    _amountCents = _remainingDueCents;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountCents <= 0) {
      setState(() {
        _error = 'O valor do repasse deve ser maior que zero.';
      });
      return;
    }

    if (_amountCents > _remainingDueCents) {
      setState(() {
        _error =
            'O valor não pode ultrapassar o saldo de repasse de ${Formatters.formatCurrency(_remainingDueCents)}.';
      });
      return;
    }

    if (!Validators.isValidPaymentDate(widget.activeSale.saleDate, _payoutDate)) {
      setState(() {
        _error =
            'A data do repasse deve ser igual ou posterior à data da venda (${Formatters.formatDate(widget.activeSale.saleDate)}) e não pode ser futura.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final payout = Payment(
        id: 'payout_${now.millisecondsSinceEpoch}',
        amountCents: _amountCents,
        date: _payoutDate,
        createdAt: now,
        createdByUid: widget.userUid,
      );

      await widget.vehicleRepository.addOwnerPayout(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicleId,
        payout: payout,
        maxNetPayoutCents: widget.netPayoutCents,
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
            fallback: 'Não foi possível registrar o repasse. Tente novamente.',
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
    final remaining = _remainingDueCents;

    return AdaptiveModalContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registrar Repasse',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textMain,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.consignorName != null && widget.consignorName!.isNotEmpty
                            ? '${widget.consignorName} • Falta ${Formatters.formatCurrency(remaining)}'
                            : 'Saldo a repassar: ${Formatters.formatCurrency(remaining)}',
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
                  style: const TextStyle(
                    color: AppTheme.dangerRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            DatePickerField(
              label: 'Data do repasse *',
              isoDate: _payoutDate,
              minIsoDate: widget.activeSale.saleDate,
              onDateSelected: (newDate) {
                setState(() {
                  _payoutDate = newDate;
                });
              },
            ),
            const SizedBox(height: 14),
            CurrencyTextField(
              label: 'Valor repassado *',
              initialValueCents: _amountCents,
              required: true,
              onChanged: (cents) {
                setState(() {
                  _amountCents = cents;
                });
              },
            ),
            const SizedBox(height: 20),
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
                  : const Text(
                      'Confirmar Repasse',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
