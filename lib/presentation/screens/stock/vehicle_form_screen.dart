import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';

class VehicleFormScreen extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final Vehicle? vehicleToEdit;

  const VehicleFormScreen({
    super.key,
    required this.workspaceId,
    required this.userUid,
    this.userEmail,
    required this.vehicleRepository,
    this.vehicleToEdit,
  });

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _versionController;
  late TextEditingController _plateController;
  late TextEditingController _notesController;

  // CRLV-e
  late TextEditingController _renavamController;
  late TextEditingController _licensingYearController;
  late TextEditingController _manufactureYearController;
  late TextEditingController _modelYearController;
  late TextEditingController _crvNumberController;
  late TextEditingController _docNotesController;

  late String _purchaseDate;
  int _purchasePriceCents = 0;
  int? _announcedPriceCents;
  String _docStatus = AppConstants.docStatusPendingCheck;

  bool _isSaving = false;
  String? _duplicateWarning;
  String? _saveError;

  bool get isEditing => widget.vehicleToEdit != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicleToEdit;

    _brandController = TextEditingController(text: v?.brand ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _versionController = TextEditingController(text: v?.version ?? '');
    _plateController = TextEditingController(text: v?.formattedPlate ?? '');
    _notesController = TextEditingController(text: v?.notes ?? '');

    _renavamController = TextEditingController(text: v?.renavam ?? '');
    _licensingYearController = TextEditingController(text: v?.licensingYear?.toString() ?? '');
    _manufactureYearController = TextEditingController(text: v?.manufactureYear?.toString() ?? '');
    _modelYearController = TextEditingController(text: v?.modelYear?.toString() ?? '');
    _crvNumberController = TextEditingController(text: v?.crvNumber ?? '');
    _docNotesController = TextEditingController(text: v?.docNotes ?? '');

    _purchaseDate = v?.purchaseDate ?? Formatters.todayIsoDate();
    _purchasePriceCents = v?.purchasePriceCents ?? 0;
    _announcedPriceCents = v?.announcedPriceCents;
    _docStatus = v?.docStatus ?? AppConstants.docStatusPendingCheck;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _versionController.dispose();
    _plateController.dispose();
    _notesController.dispose();
    _renavamController.dispose();
    _licensingYearController.dispose();
    _manufactureYearController.dispose();
    _modelYearController.dispose();
    _crvNumberController.dispose();
    _docNotesController.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    final plate = _plateController.text.trim();
    final renavam = _renavamController.text.trim();

    if (plate.isEmpty && renavam.isEmpty) return;

    final hasDuplicate = await widget.vehicleRepository.hasStockDuplicate(
      widget.workspaceId,
      plate: plate,
      renavam: renavam.isNotEmpty ? renavam : null,
      excludeVehicleId: widget.vehicleToEdit?.id,
    );

    if (mounted) {
      setState(() {
        _duplicateWarning = hasDuplicate
            ? 'Atenção: Já existe outro veículo em estoque com esta placa ou RENAVAM.'
            : null;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_purchasePriceCents <= 0) {
      setState(() {
        _saveError = 'O valor pago na compra deve ser maior que zero.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final now = DateTime.now();
      final normalizedPlate = Formatters.normalizePlate(_plateController.text);
      final normalizedRenavam = Formatters.normalizeRenavam(_renavamController.text);
      final normalizedCrv = Formatters.normalizeCrv(_crvNumberController.text);

      final licensingYear = int.tryParse(_licensingYearController.text.trim());
      final manufactureYear = int.tryParse(_manufactureYearController.text.trim());
      final modelYear = int.tryParse(_modelYearController.text.trim());

      final vehicle = Vehicle(
        id: widget.vehicleToEdit?.id ?? '',
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        version: _versionController.text.trim().isNotEmpty ? _versionController.text.trim() : null,
        plate: normalizedPlate,
        purchaseDate: _purchaseDate,
        purchasePriceCents: _purchasePriceCents,
        announcedPriceCents: _announcedPriceCents != null && _announcedPriceCents! > 0
            ? _announcedPriceCents
            : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        renavam: normalizedRenavam,
        licensingYear: licensingYear,
        manufactureYear: manufactureYear,
        modelYear: modelYear,
        crvNumber: normalizedCrv,
        docStatus: _docStatus,
        docNotes: _docNotesController.text.trim().isNotEmpty ? _docNotesController.text.trim() : null,
        activeSale: widget.vehicleToEdit?.activeSale,
        cancelledSales: widget.vehicleToEdit?.cancelledSales ?? const [],
        createdAt: widget.vehicleToEdit?.createdAt ?? now,
        updatedAt: now,
        createdByUid: widget.vehicleToEdit?.createdByUid ?? widget.userUid,
        updatedByUid: widget.userUid,
      );

      final savedId = await widget.vehicleRepository.saveVehicle(
        widget.workspaceId,
        vehicle,
        widget.userUid,
        userEmail: widget.userEmail,
      );

      if (mounted) {
        Navigator.of(context).pop(savedId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = 'Registro não confirmado pelo servidor ($e). Seus dados continuam preenchidos. Verifique a conexão e tente novamente.';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Veículo' : 'Cadastrar Veículo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Aviso de duplicidade
                    if (_duplicateWarning != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.warningOrange.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _duplicateWarning!,
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Erro de gravação
                    if (_saveError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.dangerRed.withAlpha(60)),
                        ),
                        child: Text(
                          _saveError!,
                          style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bloco 1: Identificação Principal
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Identificação do Veículo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _brandController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Marca *',
                                      hintText: 'Ex: Volkswagen',
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty
                                        ? 'Informe a marca'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Modelo *',
                                      hintText: 'Ex: Gol',
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty
                                        ? 'Informe o modelo'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _plateController,
                                    textCapitalization: TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Placa *',
                                      hintText: 'ABC1234 ou BRA2E19',
                                    ),
                                    onChanged: (_) => _checkDuplicate(),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Informe a placa';
                                      }
                                      if (!Validators.isValidPlate(val)) {
                                        return 'Placa inválida (padrão antigo ou Mercosul)';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _versionController,
                                    decoration: const InputDecoration(
                                      labelText: 'Versão',
                                      hintText: 'Ex: 1.6 MSI Flex',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bloco 2: Compra e Valores
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dados Financeiros da Compra',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 16),

                            DatePickerField(
                              label: 'Data da Compra *',
                              isoDate: _purchaseDate,
                              onDateSelected: (newDate) {
                                setState(() {
                                  _purchaseDate = newDate;
                                });
                              },
                              helperText: 'A compra não aceita datas futuras.',
                            ),
                            const SizedBox(height: 14),

                            CurrencyTextField(
                              label: 'Valor pago na compra *',
                              initialValueCents: _purchasePriceCents,
                              required: true,
                              onChanged: (cents) {
                                _purchasePriceCents = cents;
                              },
                              helperText: 'A compra compõe o custo inicial do veículo.',
                            ),
                            const SizedBox(height: 14),

                            CurrencyTextField(
                              label: 'Preço anunciado para venda (opcional)',
                              initialValueCents: _announcedPriceCents,
                              onChanged: (cents) {
                                _announcedPriceCents = cents > 0 ? cents : null;
                              },
                              helperText: 'Usado para calcular a estimativa de lucro em estoque.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bloco 3: Dados do CRLV-e e Documentação
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Documentação (CRLV-e)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Preenchimento opcional. Zeros à esquerda são estritamente preservados.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _renavamController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Código RENAVAM',
                                      hintText: '11 dígitos',
                                    ),
                                    onChanged: (_) => _checkDuplicate(),
                                    validator: (val) {
                                      if (!Validators.isValidRenavam(val)) {
                                        return 'O RENAVAM deve conter 11 dígitos.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _licensingYearController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Exercício',
                                      hintText: 'Ex: 2026',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _manufactureYearController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Ano fabricação',
                                      hintText: 'Ex: 2021',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _modelYearController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Ano modelo',
                                      hintText: 'Ex: 2022',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _crvNumberController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Número do CRV',
                                hintText: 'Número impresso no documento',
                              ),
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: _docStatus,
                              decoration: const InputDecoration(
                                labelText: 'Situação da Documentação',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: AppConstants.docStatusPendingCheck,
                                  child: Text('A verificar'),
                                ),
                                DropdownMenuItem(
                                  value: AppConstants.docStatusUpToDate,
                                  child: Text('Em dia'),
                                ),
                                DropdownMenuItem(
                                  value: AppConstants.docStatusWithIssue,
                                  child: Text('Com pendência'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _docStatus = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            if (_docStatus == AppConstants.docStatusWithIssue) ...[
                              TextFormField(
                                controller: _docNotesController,
                                decoration: const InputDecoration(
                                  labelText: 'Observação da pendência',
                                  hintText: 'Ex: Multa pendente DETRAN-SP',
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Observações gerais do veículo',
                                hintText: 'Ex: Chave reserva presente, manual do proprietário...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Salvar
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(isEditing ? 'Salvar Alterações' : 'Concluir Cadastro'),
                    ),
                    const SizedBox(height: 12),
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
