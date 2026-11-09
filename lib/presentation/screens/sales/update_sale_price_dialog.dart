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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pílula cinza iOS
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Topo com Título e Fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Corrigir Valor',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textMain,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Já recebido: ${Formatters.formatCurrency(totalReceived)}',
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

                    CurrencyTextField(
                      label: 'Novo valor negociado *',
                      initialValueCents: _newPriceCents,
                      required: true,
                      onChanged: (cents) {
                        setState(() {
                          _newPriceCents = cents;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Salvar
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
                          : const Text('Salvar Novo Valor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
