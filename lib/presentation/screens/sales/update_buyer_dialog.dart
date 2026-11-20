import 'package:flutter/material.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_fields_section.dart';
import '../../widgets/responsive_layout.dart';

class UpdateBuyerDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final ActiveSale activeSale;
  final String userUid;
  final VehicleRepository vehicleRepository;

  const UpdateBuyerDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.activeSale,
    required this.userUid,
    required this.vehicleRepository,
  });

  @override
  State<UpdateBuyerDialog> createState() => _UpdateBuyerDialogState();
}

class _UpdateBuyerDialogState extends State<UpdateBuyerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _documentController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.activeSale.buyerName ?? '');
    _phoneController = TextEditingController(
      text: Formatters.formatPhone(widget.activeSale.buyerPhone),
    );
    _documentController = TextEditingController(
      text: Formatters.formatCpfCnpj(widget.activeSale.buyerDocument),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final rawName = _nameController.text.trim();
      final phoneDigits = Formatters.digitsOnly(_phoneController.text);
      final docDigits = Formatters.digitsOnly(_documentController.text);

      await widget.vehicleRepository.updateSaleBuyerInfo(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicleId,
        buyerName: rawName.isEmpty ? null : rawName,
        buyerPhone: phoneDigits.isEmpty ? null : phoneDigits,
        buyerDocument: docDigits.isEmpty ? null : docDigits,
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
            fallback: 'Não foi possível salvar os dados do comprador.',
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
                const Text(
                  'Dados do Comprador',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              const SizedBox(height: 12),
            ],
            BuyerFieldsSection(
              nameController: _nameController,
              phoneController: _phoneController,
              documentController: _documentController,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Salvar dados do comprador',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
