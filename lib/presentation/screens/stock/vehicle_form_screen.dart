import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/fipe_service.dart';
import '../../../domain/models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/searchable_select_field.dart';

class VehicleFormScreen extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final Vehicle? vehicleToEdit;
  final FipeService? fipeService;

  const VehicleFormScreen({
    super.key,
    required this.workspaceId,
    required this.userUid,
    this.userEmail,
    required this.vehicleRepository,
    this.vehicleToEdit,
    this.fipeService,
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
  bool _isDirty = false;
  bool _docsExpanded = false;
  String? _duplicateWarning;
  String? _saveError;
  Timer? _duplicateDebounce;
  int _duplicateCheckSeq = 0;

  // FIPE
  late final FipeService _fipeService;
  late final bool _ownsFipeService;
  List<FipeBrand> _allFipeBrands = [];
  List<FipeBrand> _commonFipeBrands = [];
  List<FipeModelGroup> _fipeModels = [];
  bool _loadingBrands = false;
  bool _loadingModels = false;
  bool _loadingFipePrice = false;
  bool _fipeError = false;
  FipeBrand? _selectedBrand;
  FipeModelGroup? _selectedModel;
  FipePriceResult? _fipePriceResult;
  String? _fipeLookupMessage;
  bool _brandOther = false;
  bool _modelOther = false;
  bool _versionOther = false;

  bool get isEditing => widget.vehicleToEdit != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicleToEdit;
    _ownsFipeService = widget.fipeService == null;
    _fipeService = widget.fipeService ?? FipeService();

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

    if (v != null) {
      _docsExpanded = (v.renavam != null && v.renavam!.isNotEmpty) ||
          v.licensingYear != null ||
          v.manufactureYear != null ||
          v.modelYear != null ||
          (v.crvNumber != null && v.crvNumber!.isNotEmpty) ||
          v.docStatus != AppConstants.docStatusPendingCheck ||
          (v.docNotes != null && v.docNotes!.isNotEmpty) ||
          (v.notes != null && v.notes!.isNotEmpty);
    }

    if (isEditing) {
      _brandOther = true;
      _modelOther = true;
      _versionOther = true;
      if (_brandController.text.trim().isNotEmpty &&
          _modelController.text.trim().isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _runAutomaticFipeLookup();
        });
      }
    }

    _loadFipeBrands();
  }

  @override
  void dispose() {
    _duplicateDebounce?.cancel();
    if (_ownsFipeService) {
      _fipeService.dispose();
    }
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

  Future<void> _loadFipeBrands() async {
    setState(() {
      _loadingBrands = true;
      _fipeError = false;
    });

    try {
      final brands = await _fipeService.getBrands();
      if (!mounted) return;

      FipeBrand? matchedBrand;
      if (isEditing && _brandController.text.trim().isNotEmpty) {
        final target = _brandController.text.trim().toLowerCase();
        for (final b in brands) {
          if (b.name.toLowerCase() == target || b.rawName.toLowerCase() == target) {
            matchedBrand = b;
            break;
          }
        }
      }

      final common = FipeService.filterCommonBrands(brands);

      setState(() {
        _allFipeBrands = brands;
        _commonFipeBrands = common.isNotEmpty ? common : brands;
        _loadingBrands = false;
        if (matchedBrand != null) {
          _selectedBrand = matchedBrand;
          _brandOther = false;
        }
      });

      if (matchedBrand != null) {
        await _loadFipeModels(matchedBrand.code, preserveExisting: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBrands = false;
        _fipeError = true;
        _brandOther = true;
        _modelOther = true;
        _versionOther = true;
      });
    }
  }

  Future<void> _loadFipeModels(String brandCode, {bool preserveExisting = false}) async {
    setState(() {
      _loadingModels = true;
      _fipeError = false;
    });

    try {
      final models = await _fipeService.getModelsByBrand(brandCode);
      if (!mounted) return;

      FipeModelGroup? matchedModel;
      bool versionMatched = false;

      if (preserveExisting && _modelController.text.trim().isNotEmpty) {
        final targetModel = _modelController.text.trim().toLowerCase();
        for (final m in models) {
          if (m.baseModel.toLowerCase() == targetModel) {
            matchedModel = m;
            break;
          }
        }

        if (matchedModel != null) {
          final targetVersion = _versionController.text.trim().toLowerCase();
          if (targetVersion.isEmpty) {
            versionMatched = matchedModel.versions.isNotEmpty;
          } else {
            versionMatched = matchedModel.versions.any((v) => v.toLowerCase() == targetVersion);
          }
        }
      }

      setState(() {
        _fipeModels = models;
        _loadingModels = false;
        if (preserveExisting) {
          if (matchedModel != null) {
            _selectedModel = matchedModel;
            _modelOther = false;
            _versionOther = !versionMatched;
          } else {
            _modelOther = true;
            _versionOther = true;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingModels = false;
        _fipeError = true;
        _modelOther = true;
        _versionOther = true;
      });
    }
  }

  void _resetFipeLookup() {
    _fipePriceResult = null;
    _fipeLookupMessage = null;
  }

  void _onBrandSelected(String brandName) {
    final brand = _allFipeBrands.firstWhere((b) => b.name == brandName);
    setState(() {
      _selectedBrand = brand;
      _brandOther = false;
      _brandController.text = brand.name;

      _selectedModel = null;
      _fipeModels = [];
      _modelOther = false;
      _versionOther = false;
      _modelController.clear();
      _versionController.clear();
      _resetFipeLookup();
    });
    _loadFipeModels(brand.code);
  }

  void _onBrandOtherSelected() {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _fipeModels = [];
      _brandOther = true;
      _modelOther = true;
      _versionOther = true;
      _brandController.clear();
      _modelController.clear();
      _versionController.clear();
      _resetFipeLookup();
    });
  }

  void _onBrandSwitchToSelect() {
    setState(() {
      _brandOther = false;
      _modelOther = false;
      _versionOther = false;
      _selectedBrand = null;
      _selectedModel = null;
      _fipeModels = [];
      _brandController.clear();
      _modelController.clear();
      _versionController.clear();
      _resetFipeLookup();
    });
    if (_allFipeBrands.isEmpty) {
      _loadFipeBrands();
    }
  }

  void _onModelSelected(String modelName) {
    final group = _fipeModels.firstWhere((m) => m.baseModel == modelName);
    setState(() {
      _selectedModel = group;
      _modelOther = false;
      _modelController.text = group.baseModel;
      _versionController.clear();
      _versionOther = group.versions.isEmpty;
      _resetFipeLookup();
    });
  }

  void _onModelOtherSelected() {
    setState(() {
      _selectedModel = null;
      _modelOther = true;
      _versionOther = true;
      _modelController.clear();
      _versionController.clear();
      _resetFipeLookup();
    });
  }

  void _onModelSwitchToSelect() {
    setState(() {
      _modelOther = false;
      _versionOther = false;
      _selectedModel = null;
      _modelController.clear();
      _versionController.clear();
      _resetFipeLookup();
    });
  }

  void _onVersionSelected(String version) {
    setState(() {
      _versionOther = false;
      _versionController.text = version;
      _resetFipeLookup();
    });
  }

  void _onVersionOtherSelected() {
    setState(() {
      _versionOther = true;
      _versionController.clear();
      _resetFipeLookup();
    });
  }

  void _onVersionSwitchToSelect() {
    setState(() {
      _versionOther = false;
      _versionController.clear();
      _resetFipeLookup();
    });
  }

  Future<void> _runAutomaticFipeLookup() async {
    if (_brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty) {
      setState(() {
        _fipeLookupMessage = 'Informe a marca e o modelo para consultar a FIPE.';
      });
      return;
    }

    setState(() {
      _loadingFipePrice = true;
      _fipeLookupMessage = null;
    });

    try {
      final price = await _fipeService.lookupVehicleReference(
        brand: _brandController.text,
        model: _modelController.text,
        version: _versionController.text,
        modelYear: int.tryParse(_modelYearController.text.trim()),
        manufactureYear: int.tryParse(_manufactureYearController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _loadingFipePrice = false;
        _fipePriceResult = price;
        _fipeLookupMessage = price == null
            ? 'Não encontramos referência exata na FIPE para este modelo/ano.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFipePrice = false;
        _fipeLookupMessage = ErrorMessages.friendly(
          e,
          fallback: 'Não foi possível consultar a Tabela FIPE agora.',
        );
      });
    }
  }

  Future<void> _lookupFipePrice() async {
    final brand = _selectedBrand;
    final model = _selectedModel;
    final exactModelCode =
        (brand != null && model != null && !_versionOther)
            ? model.codeForVersion(_versionController.text)
            : null;

    if (exactModelCode == null) {
      await _runAutomaticFipeLookup();
      return;
    }

    setState(() {
      _loadingFipePrice = true;
      _fipeLookupMessage = null;
    });

    try {
      final years = await _fipeService.getModelYears(brand!.code, exactModelCode);
      if (!mounted) return;

      if (years.isEmpty) {
        setState(() {
          _loadingFipePrice = false;
          _fipeLookupMessage = 'Nenhum ano disponível na Tabela FIPE para esta versão.';
        });
        return;
      }

      final typedYear = int.tryParse(_modelYearController.text.trim());
      final yearMatches = typedYear != null
          ? years.where((y) => y.yearNumber == typedYear).toList()
          : <FipeYearOption>[];

      FipeYearOption? chosenYear;
      if (yearMatches.length == 1) {
        chosenYear = yearMatches.first;
      } else {
        setState(() => _loadingFipePrice = false);
        final listToShow = yearMatches.isNotEmpty ? yearMatches : years;
        chosenYear = await showAdaptiveModalSheet<FipeYearOption>(
          context: context,
          builder: (ctx) {
            return AdaptiveModalContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Selecione o ano-modelo FIPE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: listToShow.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = listToShow[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.of(ctx).pop(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
        if (!mounted || chosenYear == null) return;
        setState(() => _loadingFipePrice = true);
      }

      final price = await _fipeService.getFipePrice(brand.code, exactModelCode, chosenYear.code);
      if (!mounted) return;

      setState(() {
        _loadingFipePrice = false;
        _fipePriceResult = price;
        _fipeLookupMessage = null;
        if (_modelYearController.text.trim().isEmpty &&
            chosenYear!.yearNumber != null &&
            chosenYear.yearNumber != 32000) {
          _modelYearController.text = chosenYear.yearNumber.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFipePrice = false;
        _fipeLookupMessage = ErrorMessages.friendly(
          e,
          fallback: 'Não foi possível consultar a Tabela FIPE agora.',
        );
      });
    }
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'Você preencheu dados que ainda não foram salvos. Deseja sair mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _checkDuplicate() {
    _duplicateDebounce?.cancel();
    _duplicateDebounce = Timer(const Duration(milliseconds: 450), () async {
      final plate = _plateController.text.trim();
      final renavam = _renavamController.text.trim();
      final normalizedPlate = Formatters.normalizePlate(plate);
      final renavamDigits = renavam.replaceAll(RegExp(r'\D'), '');

      if (normalizedPlate.length < 7 && renavamDigits.length != 11) {
        if (mounted && _duplicateWarning != null) {
          setState(() {
            _duplicateWarning = null;
          });
        }
        return;
      }

      final seq = ++_duplicateCheckSeq;
      try {
        final hasDuplicate = await widget.vehicleRepository.hasStockDuplicate(
          widget.workspaceId,
          plate: normalizedPlate.length >= 7 ? plate : '',
          renavam: renavamDigits.length == 11 ? renavam : null,
          excludeVehicleId: widget.vehicleToEdit?.id,
        );

        if (mounted && seq == _duplicateCheckSeq) {
          setState(() {
            _duplicateWarning = hasDuplicate
                ? 'Atenção: Já existe outro veículo em estoque com esta placa ou RENAVAM.'
                : null;
          });
        }
      } catch (_) {
        // Silencioso se offline/sem índice para não travar a digitação
      }
    });
  }

  bool _hasInvalidCollapsedDocs() {
    if (!Validators.isValidRenavam(_renavamController.text)) return true;
    final licText = _licensingYearController.text.trim();
    if (licText.isNotEmpty &&
        (licText.length != 4 || !Validators.isValidYear(int.tryParse(licText)))) {
      return true;
    }
    final fabText = _manufactureYearController.text.trim();
    final fabYear = int.tryParse(fabText);
    if (fabText.isNotEmpty && (fabText.length != 4 || !Validators.isValidYear(fabYear))) {
      return true;
    }
    final modText = _modelYearController.text.trim();
    final modYear = int.tryParse(modText);
    if (modText.isNotEmpty) {
      if (modText.length != 4 || !Validators.isValidYear(modYear)) return true;
      if (fabYear != null && modYear != null && modYear < fabYear) return true;
    }
    return false;
  }

  Future<void> _handleSave() async {
    if (!_docsExpanded && _hasInvalidCollapsedDocs()) {
      setState(() => _docsExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
      return;
    }

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
        docNotes: _docStatus == AppConstants.docStatusWithIssue &&
                _docNotesController.text.trim().isNotEmpty
            ? _docNotesController.text.trim()
            : null,
        activeSale: widget.vehicleToEdit?.activeSale,
        cancelledSales: widget.vehicleToEdit?.cancelledSales ?? const [],
        createdAt: widget.vehicleToEdit?.createdAt ?? now,
        updatedAt: now,
        createdByUid: widget.vehicleToEdit?.createdByUid ?? widget.userUid,
        updatedByUid: widget.userUid,
        createdByEmail: widget.vehicleToEdit?.createdByEmail,
        updatedByEmail: widget.userEmail ?? widget.vehicleToEdit?.updatedByEmail,
      );

      final savedId = await widget.vehicleRepository.saveVehicle(
        widget.workspaceId,
        vehicle,
        widget.userUid,
        userEmail: widget.userEmail,
      );

      if (mounted) {
        _isDirty = false;
        Navigator.of(context).pop(savedId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = ErrorMessages.friendly(
            e,
            fallback:
                'Registro não confirmado pelo servidor. Seus dados continuam preenchidos. Verifique a conexão e tente novamente.',
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
    final identificationCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Identificação do Veículo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
                if (_fipeError)
                  TextButton.icon(
                    onPressed: _loadFipeBrands,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Recarregar FIPE', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SearchableSelectField(
              label: 'Marca *',
              hintText: 'Selecione a marca',
              manualHintText: 'Ex: Volkswagen',
              options: _commonFipeBrands.map((b) => b.name).toList(),
              allOptions: _allFipeBrands.map((b) => b.name).toList(),
              selectedValue: _selectedBrand?.name,
              isOtherMode: _brandOther,
              canSwitchToSelect: _allFipeBrands.isNotEmpty && !_fipeError,
              manualController: _brandController,
              isLoading: _loadingBrands,
              onOptionSelected: _onBrandSelected,
              onOtherSelected: _onBrandOtherSelected,
              onSwitchToSelect: _onBrandSwitchToSelect,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Informe a marca' : null,
            ),
            const SizedBox(height: 14),
            SearchableSelectField(
              label: 'Modelo *',
              hintText: _selectedBrand == null && !_brandOther
                  ? 'Selecione a marca antes'
                  : 'Selecione o modelo',
              manualHintText: 'Ex: Gol',
              options: _fipeModels.map((m) => m.baseModel).toList(),
              selectedValue: _selectedModel?.baseModel,
              isOtherMode: _modelOther,
              canSwitchToSelect:
                  _selectedBrand != null && _fipeModels.isNotEmpty && !_fipeError,
              manualController: _modelController,
              isLoading: _loadingModels,
              enabled: _brandOther || _selectedBrand != null,
              onOptionSelected: _onModelSelected,
              onOtherSelected: _onModelOtherSelected,
              onSwitchToSelect: _onModelSwitchToSelect,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Informe o modelo' : null,
            ),
            const SizedBox(height: 14),
            SearchableSelectField(
              label: 'Versão',
              hintText: _selectedModel == null && !_modelOther
                  ? 'Selecione o modelo antes'
                  : 'Selecione a versão',
              manualHintText: 'Ex: 1.6 MSI Flex',
              options: _selectedModel?.versions ?? const [],
              selectedValue:
                  _versionController.text.isNotEmpty ? _versionController.text : null,
              isOtherMode: _versionOther,
              canSwitchToSelect: _selectedModel != null &&
                  _selectedModel!.versions.isNotEmpty &&
                  !_fipeError,
              manualController: _versionController,
              enabled: _modelOther || _selectedModel != null,
              onOptionSelected: _onVersionSelected,
              onOtherSelected: _onVersionOtherSelected,
              onSwitchToSelect: _onVersionSwitchToSelect,
            ),
            const SizedBox(height: 14),
            TextFormField(
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
          ],
        ),
      ),
    );

    final purchaseCard = Card(
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
                  _isDirty = true;
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
                setState(() {
                  _purchasePriceCents = cents;
                });
                _markDirty();
              },
              helperText: 'A compra compõe o custo inicial do veículo.',
            ),
            const SizedBox(height: 14),
            CurrencyTextField(
              label: 'Preço anunciado para venda (opcional)',
              initialValueCents: _announcedPriceCents,
              onChanged: (cents) {
                setState(() {
                  _announcedPriceCents = cents > 0 ? cents : null;
                });
                _markDirty();
              },
              helperText: 'Usado para calcular a estimativa de lucro em estoque.',
            ),
            if (_brandController.text.trim().isNotEmpty &&
                _modelController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildFipeReferenceBox(),
            ],
          ],
        ),
      ),
    );

    final saveButton = ElevatedButton(
      onPressed: _isSaving ? null : _handleSave,
      child: _isSaving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Text(isEditing ? 'Salvar Alterações' : 'Concluir Cadastro'),
    );

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscardChanges();
        if (!discard || !context.mounted) return;
        if (mounted) {
          _isDirty = false;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Veículo' : 'Cadastrar Veículo'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTwoColumn ? 24 : 16,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isTwoColumn ? 1060 : 640),
                  child: Form(
                    key: _formKey,
                    onChanged: _markDirty,
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

                        if (isTwoColumn)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    identificationCard,
                                    const SizedBox(height: 14),
                                    purchaseCard,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildDocumentationCard(collapsible: false),
                                    const SizedBox(height: 20),
                                    saveButton,
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          identificationCard,
                          const SizedBox(height: 14),
                          purchaseCard,
                          const SizedBox(height: 14),
                          _buildDocumentationCard(collapsible: true),
                          const SizedBox(height: 24),
                          saveButton,
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildFipeReferenceBox() {
    final price = _fipePriceResult;
    double? diffPercent;
    if (price != null && price.priceCents > 0 && _purchasePriceCents > 0) {
      diffPercent = ((_purchasePriceCents - price.priceCents) / price.priceCents) * 100.0;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_check_outlined, size: 18, color: AppTheme.accentBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Referência Tabela FIPE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loadingFipePrice ? null : _lookupFipePrice,
                style: TextButton.styleFrom(
                  minimumSize: const Size(88, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: _loadingFipePrice
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(price == null ? 'Consultar FIPE' : 'Atualizar'),
              ),
            ],
          ),
          if (_loadingFipePrice && price == null) ...[
            const SizedBox(height: 4),
            const Text(
              'Consultando valor atualizado na Tabela FIPE...',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ] else if (price != null) ...[
            const SizedBox(height: 6),
            Text(
              '${Formatters.formatCurrency(price.priceCents)} (${price.modelYear == 32000 ? "Zero KM" : price.modelYear} • ${price.fuel})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDark,
                fontFeatures: AppTheme.tabularNumbers,
              ),
            ),
            Text(
              'Mês ref.: ${price.referenceMonth} • Código ${price.fipeCode}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            if (diffPercent != null) ...[
              const SizedBox(height: 4),
              Text(
                diffPercent <= 0
                    ? 'Compra ${Formatters.formatPercent(diffPercent.abs(), showSign: false)} abaixo da FIPE'
                    : 'Compra ${Formatters.formatPercent(diffPercent, showSign: false)} acima da FIPE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: diffPercent <= 0 ? AppTheme.successGreen : AppTheme.warningOrange,
                ),
              ),
            ],
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.south_east, size: 15),
              label: const Text('Usar no preço anunciado'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(140, 38),
                backgroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                setState(() {
                  _announcedPriceCents = price.priceCents;
                  _isDirty = true;
                });
              },
            ),
          ] else if (_fipeLookupMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _fipeLookupMessage!,
              style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange),
            ),
          ] else ...[
            const Text(
              'Veja o valor médio FIPE antes de definir o preço anunciado.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentationCard({required bool collapsible}) {
    final isExpanded = !collapsible || _docsExpanded;
    final hasAnyDocData = _renavamController.text.trim().isNotEmpty ||
        _licensingYearController.text.trim().isNotEmpty ||
        _manufactureYearController.text.trim().isNotEmpty ||
        _modelYearController.text.trim().isNotEmpty ||
        _crvNumberController.text.trim().isNotEmpty ||
        _docStatus != AppConstants.docStatusPendingCheck ||
        _docNotesController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: collapsible
                  ? () => setState(() => _docsExpanded = !_docsExpanded)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: collapsible ? 48 : 0),
                child: Row(
                  children: [
                    Expanded(
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
                          const SizedBox(height: 3),
                          Text(
                            collapsible && !isExpanded
                                ? (hasAnyDocData
                                    ? 'Dados preenchidos • toque para editar'
                                    : 'Opcional — toque para preencher RENAVAM, anos e notas')
                                : 'Preenchimento opcional. Zeros à esquerda são estritamente preservados.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (collapsible) ...[
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final renavamField = TextFormField(
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
                                );

                                final licensingField = TextFormField(
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
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return null;
                                    final parsed = int.tryParse(val.trim());
                                    if (val.trim().length != 4 || !Validators.isValidYear(parsed)) {
                                      return 'Ano inválido';
                                    }
                                    return null;
                                  },
                                );

                                if (constraints.maxWidth < 460) {
                                  return Column(
                                    children: [
                                      renavamField,
                                      const SizedBox(height: 14),
                                      licensingField,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 2, child: renavamField),
                                    const SizedBox(width: 12),
                                    Expanded(child: licensingField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return null;
                                      final parsed = int.tryParse(val.trim());
                                      if (val.trim().length != 4 || !Validators.isValidYear(parsed)) {
                                        return 'Ano inválido';
                                      }
                                      return null;
                                    },
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
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return null;
                                      final parsed = int.tryParse(val.trim());
                                      if (val.trim().length != 4 || !Validators.isValidYear(parsed)) {
                                        return 'Ano inválido';
                                      }
                                      final fab = int.tryParse(_manufactureYearController.text.trim());
                                      if (fab != null && parsed != null && parsed < fab) {
                                        return 'Menor que fab.';
                                      }
                                      return null;
                                    },
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
                          ],
                        ),
                      ),
                    );
  }
}
