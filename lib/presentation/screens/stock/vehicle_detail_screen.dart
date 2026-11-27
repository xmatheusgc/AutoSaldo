import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/fipe_service.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/status_badge.dart';
import '../expenses/expense_form_dialog.dart';
import '../sales/owner_payout_dialog.dart';
import '../sales/payment_form_dialog.dart';
import '../sales/sale_form_dialog.dart';
import '../sales/update_buyer_dialog.dart';
import '../sales/update_sale_price_dialog.dart';
import 'vehicle_form_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final FipeService? fipeService;

  const VehicleDetailScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.userUid,
    this.userEmail,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.fipeService,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Stream<Vehicle?> _vehicleStream;
  late Stream<List<Expense>> _expensesStream;
  FipeService? _ownedFipeService;
  bool _loadingFipe = false;
  FipePriceResult? _fipeResult;
  String? _fipeMessage;
  String? _lastAutoFipeSignature;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  @override
  void dispose() {
    _ownedFipeService?.dispose();
    super.dispose();
  }

  FipeService get _fipeService =>
      widget.fipeService ?? (_ownedFipeService ??= FipeService());

  void _initStreams() {
    _vehicleStream =
        widget.vehicleRepository.getVehicleStream(widget.workspaceId, widget.vehicleId);
    _expensesStream =
        widget.expenseRepository.getVehicleExpensesStream(widget.workspaceId, widget.vehicleId);
  }

  @override
  void didUpdateWidget(covariant VehicleDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.vehicleId != widget.vehicleId ||
        oldWidget.vehicleRepository != widget.vehicleRepository ||
        oldWidget.expenseRepository != widget.expenseRepository) {
      _initStreams();
      _fipeResult = null;
      _fipeMessage = null;
      _lastAutoFipeSignature = null;
    }
  }

  void _retryStreams() {
    setState(() {
      _initStreams();
    });
  }

  void _copyText(String text, String snackMessage) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackMessage),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _copyBuyerAd(Vehicle vehicle) {
    final lines = <String>[
      vehicle.title,
    ];
    if (vehicle.manufactureYear != null || vehicle.modelYear != null) {
      lines.add('Ano: ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}');
    }
    if (vehicle.announcedPriceCents != null) {
      lines.add('Valor: ${Formatters.formatCurrency(vehicle.announcedPriceCents!)}');
    } else {
      lines.add('Valor: Sob consulta');
    }
    if (vehicle.docStatus == AppConstants.docStatusUpToDate) {
      lines.add('Documentação em dia');
    }
    _copyText(
      lines.join('\n'),
      'Anúncio copiado para a área de transferência!',
    );
  }

  void _copyDispatcherData(Vehicle vehicle) {
    final lines = <String>[
      'Veículo: ${vehicle.title}',
      'Placa: ${vehicle.formattedPlate}',
      if (vehicle.manufactureYear != null || vehicle.modelYear != null)
        'Ano: ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
      'RENAVAM: ${vehicle.renavam ?? "-"}',
      'CRV: ${vehicle.crvNumber ?? "-"}',
      'Exercício CRLV: ${vehicle.licensingYear?.toString() ?? "-"}',
    ];
    _copyText(
      lines.join('\n'),
      'Dados de documentação copiados!',
    );
  }

  String _fipeSignatureFor(Vehicle vehicle) =>
      '${vehicle.id}|${vehicle.brand}|${vehicle.model}|${vehicle.version}|${vehicle.modelYear}|${vehicle.manufactureYear}';

  void _ensureAutoFipeLookup(Vehicle vehicle) {
    if (vehicle.brand.trim().isEmpty || vehicle.model.trim().isEmpty) return;
    final signature = _fipeSignatureFor(vehicle);
    if (_lastAutoFipeSignature == signature) return;
    _lastAutoFipeSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lookupFipeReference(vehicle);
    });
  }

  Future<void> _lookupFipeReference(Vehicle vehicle) async {
    setState(() {
      _loadingFipe = true;
      _fipeMessage = null;
    });

    try {
      final result = await _fipeService.lookupVehicleReference(
        brand: vehicle.brand,
        model: vehicle.model,
        version: vehicle.version,
        modelYear: vehicle.modelYear,
        manufactureYear: vehicle.manufactureYear,
      );
      if (!mounted) return;
      setState(() {
        _loadingFipe = false;
        _fipeResult = result;
        _fipeMessage = result == null
            ? 'Modelo/versão ou ano não encontrado automaticamente na Tabela FIPE.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFipe = false;
        _fipeMessage = ErrorMessages.friendly(
          e,
          fallback: 'Não foi possível consultar a Tabela FIPE agora.',
        );
      });
    }
  }

  String? _formatAuthorName(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    final prefix = email.trim().split('@').first;
    if (prefix.isEmpty) return null;
    return prefix[0].toUpperCase() + prefix.substring(1);
  }

  Future<void> _confirmAndExecute({
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var isSubmitting = false;
        String? inlineError;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (inlineError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      inlineError!,
                      style: const TextStyle(
                        color: AppTheme.dangerRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                child: Text(cancelLabel),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          isSubmitting = true;
                          inlineError = null;
                        });
                        try {
                          await action();
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              inlineError = ErrorMessages.friendly(e);
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );

    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _revertExpense(Expense expense) => _confirmAndExecute(
        title: 'Estornar Gasto',
        message:
            'Deseja estornar o gasto de ${Formatters.formatCurrency(expense.amountCents)} (${expense.categoryLabel})? O valor será removido do custo do carro e do caixa.',
        cancelLabel: 'Cancelar',
        confirmLabel: 'Estornar',
        action: () => widget.expenseRepository.revertExpense(
          widget.workspaceId,
          expense.id,
          widget.userUid,
        ),
        successMessage: 'Gasto estornado com sucesso!',
      );

  Future<void> _revertPayment(Payment payment) => _confirmAndExecute(
        title: 'Estornar Pagamento',
        message:
            'Deseja estornar o recebimento de ${Formatters.formatCurrency(payment.amountCents)}? O valor voltará a constar como saldo a receber.',
        cancelLabel: 'Cancelar',
        confirmLabel: 'Estornar',
        action: () => widget.vehicleRepository.revertPayment(
          workspaceId: widget.workspaceId,
          vehicleId: widget.vehicleId,
          paymentId: payment.id,
          userUid: widget.userUid,
        ),
        successMessage: 'Recebimento estornado com sucesso!',
      );

  Future<void> _revertOwnerPayout(Payment payout) => _confirmAndExecute(
        title: 'Estornar Repasse',
        message:
            'Deseja estornar o repasse de ${Formatters.formatCurrency(payout.amountCents)} ao proprietário? O valor voltará a constar como saldo a repassar.',
        cancelLabel: 'Cancelar',
        confirmLabel: 'Estornar',
        action: () => widget.vehicleRepository.revertOwnerPayout(
          workspaceId: widget.workspaceId,
          vehicleId: widget.vehicleId,
          payoutId: payout.id,
          userUid: widget.userUid,
        ),
        successMessage: 'Repasse estornado com sucesso!',
      );

  Future<void> _returnConsignedVehicle(Vehicle vehicle) async {
    String returnedDate = Formatters.todayIsoDate();
    if (returnedDate.compareTo(vehicle.purchaseDate) < 0) {
      returnedDate = vehicle.purchaseDate;
    }
    final notesController = TextEditingController();
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var isSubmitting = false;
        String? inlineError;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Devolver ao Proprietário'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'O veículo sairá do estoque ativo como devolvido, mantendo histórico e despesas registradas.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),
                  DatePickerField(
                    label: 'Data da devolução *',
                    isoDate: returnedDate,
                    minIsoDate: vehicle.purchaseDate,
                    onDateSelected: (newDate) {
                      setDialogState(() {
                        returnedDate = newDate;
                        inlineError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      hintText: 'Ex: Proprietário desistiu da venda',
                    ),
                  ),
                  if (inlineError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        inlineError!,
                        style: const TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          isSubmitting = true;
                          inlineError = null;
                        });
                        try {
                          await widget.vehicleRepository.returnConsignedVehicle(
                            workspaceId: widget.workspaceId,
                            vehicleId: vehicle.id,
                            returnedDate: returnedDate,
                            notes: notesController.text,
                            userUid: widget.userUid,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              inlineError = ErrorMessages.friendly(e);
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirmar Devolução'),
              ),
            ],
          ),
        );
      },
    );
    notesController.dispose();

    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veículo marcado como devolvido ao proprietário.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _reopenConsignedVehicle(Vehicle vehicle) => _confirmAndExecute(
        title: 'Retornar ao Estoque',
        message:
            'Deseja retornar este veículo consignado para o estoque ativo?',
        cancelLabel: 'Cancelar',
        confirmLabel: 'Retornar ao Estoque',
        action: () => widget.vehicleRepository.reopenConsignedVehicle(
          workspaceId: widget.workspaceId,
          vehicleId: vehicle.id,
          userUid: widget.userUid,
        ),
        successMessage: 'Veículo retornado ao estoque ativo!',
      );

  Future<void> _cancelSale(ActiveSale sale) {
    final hasPayments = sale.hasValidPayments;
    final hasPayouts = sale.hasValidOwnerPayouts;
    final hasActiveEntries = hasPayments || hasPayouts;
    return _confirmAndExecute(
      title: hasActiveEntries ? 'Cancelar Venda e Estornar' : 'Cancelar Venda',
      message: hasActiveEntries
          ? 'Esta venda possui ${hasPayments ? "${Formatters.formatCurrency(sale.totalReceivedCents)} em recebimentos" : ""}${hasPayments && hasPayouts ? " e " : ""}${hasPayouts ? "${Formatters.formatCurrency(sale.totalOwnerPayoutPaidCents)} em repasses ao proprietário" : ""}.\n\nAo confirmar, esses lançamentos serão estornados automaticamente e o veículo voltará para o estoque.'
          : 'Deseja cancelar esta venda e retornar o veículo para o estoque? O histórico da venda será preservado.',
      cancelLabel: 'Voltar',
      confirmLabel:
          hasActiveEntries ? 'Cancelar e Estornar' : 'Cancelar e Voltar ao Estoque',
      action: () => widget.vehicleRepository.cancelSale(
        workspaceId: widget.workspaceId,
        vehicleId: widget.vehicleId,
        userUid: widget.userUid,
        revertPaymentsAtomically: hasActiveEntries,
      ),
      successMessage: hasActiveEntries
          ? 'Venda cancelada, lançamentos estornados e veículo no estoque!'
          : 'Venda cancelada! Veículo de volta ao estoque.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Vehicle?>(
      stream: _vehicleStream,
      builder: (context, vSnapshot) {
        if (vSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ficha do Veículo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.dangerRed),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro ao carregar dados do veículo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Confira sua conexão com a internet e tente novamente.',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tentar novamente'),
                      onPressed: _retryStreams,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (vSnapshot.connectionState == ConnectionState.waiting && !vSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ficha do Veículo')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final vehicle = vSnapshot.data;
        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ficha do Veículo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'Veículo não encontrado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este registro não existe ou foi removido.',
                      style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Voltar ao estoque'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        _ensureAutoFipeLookup(vehicle);

        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, eSnapshot) {
            if (eSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(vehicle.title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.dangerRed),
                        const SizedBox(height: 16),
                        const Text(
                          'Erro ao carregar despesas do veículo',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tentar novamente'),
                          onPressed: _retryStreams,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final vehicleExpenses = eSnapshot.data ?? [];

            final totalCost = FinancialCalculator.calculateVehicleTotalCost(vehicle, vehicleExpenses);
            final validExpensesTotal = vehicleExpenses
                .where((e) => e.isValid)
                .fold<int>(0, (sum, e) => sum + e.amountCents);
            final deductedExpensesTotal = vehicleExpenses
                .where((e) => e.isValid && e.deductFromConsignmentPayout)
                .fold<int>(0, (sum, e) => sum + e.amountCents);
            final estimatedProfit = FinancialCalculator.calculateEstimatedProfit(vehicle, vehicleExpenses);
            final realizedProfit = FinancialCalculator.calculateRealizedProfit(vehicle, vehicleExpenses);

            Future<void> openEditForm() async {
              final savedId = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => VehicleFormScreen(
                    workspaceId: widget.workspaceId,
                    userUid: widget.userUid,
                    userEmail: widget.userEmail,
                    vehicleRepository: widget.vehicleRepository,
                    vehicleToEdit: vehicle,
                    fipeService: widget.fipeService,
                  ),
                ),
              );
              if (savedId != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cadastro atualizado com sucesso!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isTwoColumn =
                    constraints.maxWidth >= ResponsiveBreakpoints.detailTwoColumn;

                return Scaffold(
                  backgroundColor: isTwoColumn ? AppTheme.desktopBg : Colors.white,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    title: Text(
                      vehicle.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    actions: [
                      Tooltip(
                        message: 'Editar Cadastro',
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text(
                            'Editar',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMain,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: openEditForm,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Mais opções',
                        icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMain),
                        onSelected: (value) {
                          if (value == 'copy_ad') {
                            _copyBuyerAd(vehicle);
                          } else if (value == 'copy_dispatcher') {
                            _copyDispatcherData(vehicle);
                          } else if (value == 'return_to_owner') {
                            _returnConsignedVehicle(vehicle);
                          } else if (value == 'reopen_stock') {
                            _reopenConsignedVehicle(vehicle);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'copy_ad',
                            child: Row(
                              children: [
                                Icon(Icons.copy_outlined, size: 18, color: AppTheme.textMuted),
                                SizedBox(width: 10),
                                Text('Copiar anúncio'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy_dispatcher',
                            child: Row(
                              children: [
                                Icon(Icons.copy_all_outlined, size: 18, color: AppTheme.textMuted),
                                SizedBox(width: 10),
                                Text('Copiar p/ despachante'),
                              ],
                            ),
                          ),
                          if (vehicle.isConsigned && vehicle.isInStock)
                            const PopupMenuItem(
                              value: 'return_to_owner',
                              child: Row(
                                children: [
                                  Icon(Icons.assignment_return_outlined, size: 18, color: AppTheme.warningOrange),
                                  SizedBox(width: 10),
                                  Text('Devolver ao proprietário'),
                                ],
                              ),
                            ),
                          if (vehicle.isConsigned && vehicle.isReturned)
                            const PopupMenuItem(
                              value: 'reopen_stock',
                              child: Row(
                                children: [
                                  Icon(Icons.replay_outlined, size: 18, color: AppTheme.accentBlue),
                                  SizedBox(width: 10),
                                  Text('Retornar ao estoque'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  bottomNavigationBar: isTwoColumn
                      ? null
                      : _buildMobileBottomBar(
                          vehicle: vehicle,
                          totalCost: totalCost,
                          deductedExpensesTotal: deductedExpensesTotal,
                        ),
                  body: SafeArea(
                    top: false,
                    bottom: isTwoColumn,
                    child: isTwoColumn
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1120),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildHeaderCard(vehicle, isWide: true),
                                          if (vehicle.isReturned) ...[
                                            const SizedBox(height: 14),
                                            _buildReturnedCard(vehicle, isWide: true),
                                          ],
                                          const SizedBox(height: 14),
                                          _buildFinancialHeroCard(
                                            vehicle: vehicle,
                                            totalCost: totalCost,
                                            validExpensesTotal: validExpensesTotal,
                                            deductedExpensesTotal: deductedExpensesTotal,
                                            estimatedProfit: estimatedProfit,
                                            realizedProfit: realizedProfit,
                                          ),
                                          if (vehicle.isInStock ||
                                              (vehicle.activeSale != null &&
                                                  vehicle.activeSale!.balanceDueCents > 0)) ...[
                                            const SizedBox(height: 14),
                                            _buildActionButtons(
                                              vehicle: vehicle,
                                              totalCost: totalCost,
                                              deductedExpensesTotal: deductedExpensesTotal,
                                            ),
                                          ],
                                          if (vehicle.isSold) ...[
                                            const SizedBox(height: 14),
                                            _buildDocsCard(vehicle, isWide: true),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (vehicle.isSold && vehicle.activeSale != null) ...[
                                            _buildSaleDetailsCard(vehicle: vehicle, isWide: true),
                                            if (vehicle.isConsigned) ...[
                                              const SizedBox(height: 14),
                                              _buildOwnerPayoutCard(
                                                vehicle: vehicle,
                                                deductedExpensesTotal: deductedExpensesTotal,
                                                isWide: true,
                                              ),
                                            ],
                                            const SizedBox(height: 14),
                                          ],
                                          _buildExpensesCard(
                                            vehicle: vehicle,
                                            expenses: vehicleExpenses,
                                            isWide: true,
                                          ),
                                          if (!vehicle.isSold) ...[
                                            const SizedBox(height: 14),
                                            _buildDocsCard(vehicle, isWide: true),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 680),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildHeaderCard(vehicle, isWide: false),
                                    if (vehicle.isReturned)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                        child: _buildReturnedCard(vehicle, isWide: false),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                      child: _buildFinancialHeroCard(
                                        vehicle: vehicle,
                                        totalCost: totalCost,
                                        validExpensesTotal: validExpensesTotal,
                                        deductedExpensesTotal: deductedExpensesTotal,
                                        estimatedProfit: estimatedProfit,
                                        realizedProfit: realizedProfit,
                                      ),
                                    ),
                                    if (vehicle.isSold && vehicle.activeSale != null) ...[
                                      Container(height: 8, color: AppTheme.sectionDivider),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: _buildSaleDetailsCard(vehicle: vehicle, isWide: false),
                                      ),
                                      if (vehicle.isConsigned) ...[
                                        Container(height: 8, color: AppTheme.sectionDivider),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: _buildOwnerPayoutCard(
                                            vehicle: vehicle,
                                            deductedExpensesTotal: deductedExpensesTotal,
                                            isWide: false,
                                          ),
                                        ),
                                      ],
                                    ],
                                    Container(height: 8, color: AppTheme.sectionDivider),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildExpensesCard(
                                        vehicle: vehicle,
                                        expenses: vehicleExpenses,
                                        isWide: false,
                                      ),
                                    ),
                                    Container(height: 8, color: AppTheme.sectionDivider),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _buildDocsCard(vehicle, isWide: false),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openNewExpenseModal(Vehicle vehicle) async {
    final saved = await showAdaptiveModalSheet<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        workspaceId: widget.workspaceId,
        vehicleId: vehicle.id,
        userUid: widget.userUid,
        userEmail: widget.userEmail,
        expenseRepository: widget.expenseRepository,
        isConsignedVehicle: vehicle.isConsigned,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Despesa lançada com sucesso!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Widget _buildMobileBottomBar({
    required Vehicle vehicle,
    required int totalCost,
    required int deductedExpensesTotal,
  }) {
    final sale = vehicle.activeSale;
    final hasPrimary = vehicle.isInStock || (sale != null && sale.balanceDueCents > 0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (hasPrimary) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Gasto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMain,
                    minimumSize: const Size(112, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: const BorderSide(color: AppTheme.borderInteractive),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _openNewExpenseModal(vehicle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButtons(
                    vehicle: vehicle,
                    totalCost: totalCost,
                    deductedExpensesTotal: deductedExpensesTotal,
                    compactHeight: 46,
                  ),
                ),
              ] else
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Lançar Gasto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMain,
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: AppTheme.borderInteractive),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _openNewExpenseModal(vehicle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Vehicle vehicle, {bool isWide = false}) {
    final rawCreator = (vehicle.createdByEmail != null && vehicle.createdByEmail!.isNotEmpty)
        ? vehicle.createdByEmail!.split('@')[0]
        : null;
    final creatorName = (rawCreator != null && rawCreator.isNotEmpty)
        ? rawCreator[0].toUpperCase() + rawCreator.substring(1).toLowerCase()
        : null;
    final daysInStock = FinancialCalculator.calculateDaysInStock(vehicle);
    final isCritical =
        vehicle.isInStock && daysInStock >= AppConstants.criticalStockDaysThreshold;
    final isStagnant =
        vehicle.isInStock && daysInStock >= AppConstants.stagnantStockDaysThreshold;

    final metaParts = <String>[
      if (vehicle.manufactureYear != null || vehicle.modelYear != null)
        'Ano ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
      if (vehicle.isReturned)
        'Devolvido em ${Formatters.formatDate(vehicle.consignmentReturnedDate!)} (${Formatters.formatDaysCount(daysInStock)})'
      else if (vehicle.isInStock)
        daysInStock == 0 ? 'Entrada hoje' : '${Formatters.formatDaysCount(daysInStock)} no pátio'
      else
        'Vendido em ${Formatters.formatDaysCount(daysInStock)}',
      if (creatorName != null) 'Por: $creatorName',
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 16 : 16, isWide ? 16 : 8, isWide ? 16 : 16, 12),
      decoration: isWide
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                CarPlateWidget(plate: vehicle.plate, fontSize: 15),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (vehicle.isConsigned) StatusBadge.consigned(),
                    if (vehicle.isReturned)
                      StatusBadge.returnedToOwner()
                    else
                      StatusBadge.stockStatus(vehicle.isInStock),
                    if (vehicle.docStatus == AppConstants.docStatusWithIssue)
                      StatusBadge.docStatus(vehicle.docStatus),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            vehicle.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                metaParts.join(' • '),
                style: TextStyle(
                  fontSize: 12.5,
                  color: isCritical
                      ? AppTheme.dangerRed
                      : isStagnant
                          ? AppTheme.warningOrange
                          : AppTheme.textMuted,
                  fontWeight: isStagnant ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: AppTheme.tabularNumbers,
                ),
              ),
            ],
          ),
          if (vehicle.isConsigned && vehicle.hasConsignorInfo) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.sectionDivider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proprietário (Consignante)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (vehicle.consignorName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      vehicle.consignorName!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                  if ((vehicle.consignorPhone != null && vehicle.consignorPhone!.isNotEmpty) ||
                      (vehicle.consignorDocument != null &&
                          vehicle.consignorDocument!.isNotEmpty)) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (vehicle.consignorPhone != null &&
                            vehicle.consignorPhone!.isNotEmpty)
                          _buildCopyableBuyerChip(
                            icon: Icons.phone_outlined,
                            value: Formatters.formatPhone(vehicle.consignorPhone),
                            snackMessage: 'Telefone do proprietário copiado!',
                          ),
                        if (vehicle.consignorDocument != null &&
                            vehicle.consignorDocument!.isNotEmpty)
                          _buildCopyableBuyerChip(
                            icon: Icons.badge_outlined,
                            value: Formatters.formatCpfCnpj(vehicle.consignorDocument),
                            snackMessage: 'CPF/CNPJ do proprietário copiado!',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (isWide) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copiar anúncio'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _copyBuyerAd(vehicle),
                ),
                if (vehicle.isConsigned && vehicle.isInStock)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                    label: const Text('Devolver ao proprietário'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warningOrange,
                      minimumSize: const Size(160, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _returnConsignedVehicle(vehicle),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnedCard(Vehicle vehicle, {bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sectionDivider,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_return_outlined, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Devolvido ao proprietário em ${Formatters.formatDate(vehicle.consignmentReturnedDate!)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
          if (vehicle.consignmentReturnedNotes != null &&
              vehicle.consignmentReturnedNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              vehicle.consignmentReturnedNotes!,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.replay_outlined, size: 16),
            label: const Text('Retornar ao estoque'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 38),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _reopenConsignedVehicle(vehicle),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialHeroCard({
    required Vehicle vehicle,
    required int totalCost,
    required int validExpensesTotal,
    required int deductedExpensesTotal,
    required int? estimatedProfit,
    required int? realizedProfit,
  }) {
    final isSold = vehicle.isSold && vehicle.activeSale != null;
    final int? heroProfit = isSold ? realizedProfit : estimatedProfit;
    final int? referencePriceCents = isSold
        ? vehicle.activeSale!.salePriceCents
        : vehicle.announcedPriceCents;
    final double? heroRoi = heroProfit != null
        ? FinancialCalculator.calculateVehiclePercentMetric(
            vehicle,
            profitCents: heroProfit,
            totalCostCents: totalCost,
            priceCents: referencePriceCents,
          )
        : null;
    final bool isLoss = (heroProfit ?? 0) < 0;
    final Color profitColor = isLoss ? AppTheme.dangerRed : AppTheme.successGreen;

    final int? netPayoutCents = vehicle.isConsigned
        ? FinancialCalculator.calculateOwnerNetPayoutCentsFromMap(
            vehicle,
            {vehicle.id: deductedExpensesTotal},
            priceCents: referencePriceCents,
          )
        : null;

    String consignmentAgreementLabel() {
      switch (vehicle.consignmentType) {
        case AppConstants.consignmentTypeCommissionPercent:
          final bps = vehicle.consignmentCommissionBps ?? 0;
          final pct = (bps / 100.0)
              .toStringAsFixed(bps % 100 == 0 ? 0 : 2)
              .replaceAll('.', ',');
          return '$pct%';
        case AppConstants.consignmentTypeCommissionFixed:
          return Formatters.formatCurrency(vehicle.consignmentAgreementValueCents);
        case AppConstants.consignmentTypeFixedPayout:
        default:
          return Formatters.formatCurrency(vehicle.consignmentAgreementValueCents);
      }
    }

    String consignmentAgreementTitle() {
      switch (vehicle.consignmentType) {
        case AppConstants.consignmentTypeCommissionPercent:
          return 'Comissão';
        case AppConstants.consignmentTypeCommissionFixed:
          return 'Comissão fixa';
        case AppConstants.consignmentTypeFixedPayout:
        default:
          return 'Repasse base';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vehicle.isConsigned ? 'Resumo do Consignado' : 'Custos e Venda',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),

          // Bloco principal: Preço e Lucro lado a lado sem subcaixas
          if ((vehicle.isInStock && vehicle.announcedPriceCents != null) || isSold) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSold ? 'Vendido Por' : 'Preço Anunciado',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.formatCurrency(
                            isSold
                                ? vehicle.activeSale!.salePriceCents
                                : vehicle.announcedPriceCents!,
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            letterSpacing: -0.5,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (heroProfit != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isSold
                              ? (isLoss ? 'Prejuízo Realizado' : 'Lucro Realizado')
                              : (isLoss ? 'Prejuízo Previsto' : 'Lucro Estimado'),
                          style: TextStyle(
                            fontSize: 12,
                            color: profitColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isLoss ? "-" : "+"}${Formatters.formatCurrency(heroProfit.abs())}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: profitColor,
                              letterSpacing: -0.4,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                        ),
                        if (heroRoi != null)
                          Text(
                            '${vehicle.isConsigned ? "Margem" : "ROI"} ${Formatters.formatPercent(heroRoi)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: profitColor,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 22, color: AppTheme.borderSubtle),
          ],

          // Três colunas planas
          Row(
            children: [
              Expanded(
                child: _buildMetricCell(
                  vehicle.isConsigned ? consignmentAgreementTitle() : 'Compra',
                  vehicle.isConsigned
                      ? consignmentAgreementLabel()
                      : Formatters.formatCurrency(vehicle.purchasePriceCents),
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.borderSubtle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildMetricCell(
                    deductedExpensesTotal > 0 ? 'Despesas*' : 'Despesas',
                    Formatters.formatCurrency(validExpensesTotal),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: AppTheme.borderSubtle),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildMetricCell(
                    vehicle.isConsigned ? 'Repasse Líq.' : 'Custo Total',
                    vehicle.isConsigned
                        ? (netPayoutCents != null
                            ? Formatters.formatCurrency(netPayoutCents)
                            : 'Sob venda')
                        : Formatters.formatCurrency(totalCost),
                    bold: true,
                  ),
                ),
              ),
            ],
          ),
          if (vehicle.isConsigned && deductedExpensesTotal > 0) ...[
            const SizedBox(height: 6),
            Text(
              '* ${Formatters.formatCurrency(deductedExpensesTotal)} descontados do repasse ao proprietário.',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],

          if (vehicle.isInStock &&
              vehicle.announcedPriceCents != null &&
              estimatedProfit != null &&
              FinancialCalculator.isTightMarginForVehicle(
                  vehicle, estimatedProfit, totalCost)) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (_) {
                final isNegative = estimatedProfit < 0;
                final roi =
                    FinancialCalculator.calculateRoiPercent(estimatedProfit, totalCost);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNegative ? AppTheme.dangerLight : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isNegative ? AppTheme.dangerBorder : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isNegative ? Icons.warning_amber_rounded : Icons.trending_flat,
                        size: 16,
                        color: isNegative ? AppTheme.dangerRed : AppTheme.warningOrange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isNegative
                              ? 'Prejuízo previsto: o custo total (compra + gastos) ultrapassou o preço anunciado em ${Formatters.formatCurrency(estimatedProfit.abs())}. Reajuste o anúncio para não vender no prejuízo.'
                              : 'Margem apertada (${roi != null ? Formatters.formatPercent(roi, showSign: false) : ""}): considere revisar o preço anunciado após as despesas.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isNegative ? AppTheme.dangerRed : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Referência FIPE integrada sem subcaixa
          const Divider(height: 22, color: AppTheme.borderSubtle),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'FIPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _loadingFipe && _fipeResult == null
                        ? const Text(
                            'Consultando Tabela FIPE...',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          )
                        : _fipeResult != null
                            ? Text(
                                '${Formatters.formatCurrency(_fipeResult!.priceCents)} (${_fipeResult!.referenceMonth})',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textMain,
                                  fontFeatures: AppTheme.tabularNumbers,
                                ),
                              )
                            : Text(
                                _fipeMessage ?? 'Sem referência automática',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warningOrange,
                                ),
                              ),
                  ),
                  TextButton(
                    onPressed: _loadingFipe ? null : () => _lookupFipeReference(vehicle),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(44, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.accentBlue,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: _loadingFipe
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _fipeResult != null
                                ? 'Atualizar'
                                : (_fipeMessage != null ? 'Tentar' : 'Consultar'),
                          ),
                  ),
                ],
              ),
              if (_fipeResult != null) ...[
                Builder(
                  builder: (_) {
                    final r = _fipeResult!;
                    final baseComparison = vehicle.announcedPriceCents ?? totalCost;
                    final compLabel = vehicle.announcedPriceCents != null
                        ? 'Anunciado'
                        : 'Custo total';
                    final diffPct = r.priceCents > 0
                        ? ((baseComparison - r.priceCents) / r.priceCents) * 100.0
                        : null;
                    return Text(
                      '${r.model} (${r.modelYear == 32000 ? "Zero KM" : r.modelYear})${diffPct != null ? " • $compLabel ${Formatters.formatPercent(diffPct.abs(), showSign: false)} ${diffPct <= 0 ? "abaixo" : "acima"} da FIPE" : ""}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: bold ? 14 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: AppTheme.textMain,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons({
    required Vehicle vehicle,
    required int totalCost,
    required int deductedExpensesTotal,
    double compactHeight = 50,
  }) {
    final sale = vehicle.activeSale;

    if (vehicle.isInStock) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.handshake, size: 20),
        label: Text(
          'Vender Veículo',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: compactHeight < 48 ? 15 : 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: Colors.white,
          minimumSize: Size.fromHeight(compactHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final saved = await showAdaptiveModalSheet<bool>(
            context: context,
            builder: (_) => SaleFormDialog(
              workspaceId: widget.workspaceId,
              vehicle: vehicle,
              totalCostCents: totalCost,
              deductedExpensesCents: deductedExpensesTotal,
              userUid: widget.userUid,
              userEmail: widget.userEmail,
              vehicleRepository: widget.vehicleRepository,
            ),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Venda registrada com sucesso!'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      );
    }

    if (sale != null && sale.balanceDueCents > 0) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.payments_outlined, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            compactHeight < 48
                ? 'Receber (${Formatters.formatCurrency(sale.balanceDueCents)})'
                : 'Receber Parcela (${Formatters.formatCurrency(sale.balanceDueCents)})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          minimumSize: Size.fromHeight(compactHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final saved = await showAdaptiveModalSheet<bool>(
            context: context,
            builder: (_) => PaymentFormDialog(
              workspaceId: widget.workspaceId,
              vehicleId: vehicle.id,
              activeSale: sale,
              userUid: widget.userUid,
              vehicleRepository: widget.vehicleRepository,
            ),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recebimento registrado com sucesso!'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _openEditBuyerDialog(Vehicle vehicle, ActiveSale sale) async {
    final saved = await showAdaptiveModalSheet<bool>(
      context: context,
      builder: (_) => UpdateBuyerDialog(
        workspaceId: widget.workspaceId,
        vehicleId: vehicle.id,
        activeSale: sale,
        userUid: widget.userUid,
        vehicleRepository: widget.vehicleRepository,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do comprador atualizados com sucesso!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Widget _buildBuyerInfoCard(Vehicle vehicle, ActiveSale sale) {
    if (!sale.hasBuyerInfo) {
      return Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Comprador não informado',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 15),
            label: const Text('Adicionar', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(70, 34),
            ),
            onPressed: () => _openEditBuyerDialog(vehicle, sale),
          ),
        ],
      );
    }

    final formattedPhone = Formatters.formatPhone(sale.buyerPhone);
    final formattedDoc = Formatters.formatCpfCnpj(sale.buyerDocument);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Comprador',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Editar', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(64, 32),
              ),
              onPressed: () => _openEditBuyerDialog(vehicle, sale),
            ),
          ],
        ),
        if (sale.buyerName != null) ...[
          const SizedBox(height: 2),
          Text(
            sale.buyerName!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
        ],
        if (formattedPhone.isNotEmpty || formattedDoc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (formattedPhone.isNotEmpty)
                _buildCopyableBuyerChip(
                  icon: Icons.phone_outlined,
                  value: formattedPhone,
                  snackMessage: 'Telefone copiado para a área de transferência!',
                ),
              if (formattedDoc.isNotEmpty)
                _buildCopyableBuyerChip(
                  icon: Icons.badge_outlined,
                  value: formattedDoc,
                  snackMessage: 'CPF/CNPJ copiado para a área de transferência!',
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCopyableBuyerChip({
    required IconData icon,
    required String value,
    required String snackMessage,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _copyText(value, snackMessage),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
                fontFeatures: AppTheme.tabularNumbers,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy_outlined, size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleDetailsCard({required Vehicle vehicle, bool isWide = false}) {
    final sale = vehicle.activeSale!;

    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 0),
      decoration: isWide
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  'Venda & Recebimentos',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                ),
                StatusBadge.paymentStatus(sale.paymentStatus),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Resumo plano em 3 colunas sem caixa cinza interna
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Venda', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.formatCurrency(sale.salePriceCents),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recebido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.formatCurrency(sale.totalReceivedCents),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.successGreen,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Restante', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.formatCurrency(sale.balanceDueCents),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: sale.balanceDueCents > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Data: ${Formatters.formatDate(sale.saleDate)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Corrigir valor', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  onPressed: () async {
                    final saved = await showAdaptiveModalSheet<bool>(
                      context: context,
                      builder: (_) => UpdateSalePriceDialog(
                        workspaceId: widget.workspaceId,
                        vehicleId: vehicle.id,
                        activeSale: sale,
                        userUid: widget.userUid,
                        vehicleRepository: widget.vehicleRepository,
                      ),
                    );
                    if (saved == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Valor da venda atualizado com sucesso!'),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16, color: AppTheme.borderSubtle),

          // Dados do comprador (opcional)
          _buildBuyerInfoCard(vehicle, sale),
          const Divider(height: 16, color: AppTheme.borderSubtle),

          // Entradas registradas (lista plana com divisores 1px)
          const Text('Pagamentos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain)),
          const SizedBox(height: 6),

          if (sale.payments.isEmpty) ...[
            const Text('Nenhum pagamento registrado.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ] else ...[
            for (int i = 0; i < sale.payments.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      sale.payments[i].isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: sale.payments[i].isValid ? AppTheme.successGreen : AppTheme.dangerRed,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${Formatters.formatDate(sale.payments[i].date)}: ${Formatters.formatCurrency(sale.payments[i].amountCents)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: sale.payments[i].isValid ? null : TextDecoration.lineThrough,
                          color: sale.payments[i].isValid ? AppTheme.textMain : AppTheme.textMuted,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    ),
                    if (sale.payments[i].isValid)
                      IconButton(
                        icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 18),
                        tooltip: 'Estornar valor',
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: () => _revertPayment(sale.payments[i]),
                      )
                    else
                      const Text(
                        'Estornado',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.dangerRed, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 16),
              label: const Text('Cancelar venda e retornar ao estoque', style: TextStyle(color: AppTheme.dangerRed, fontSize: 12.5)),
              onPressed: () => _cancelSale(sale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerPayoutCard({
    required Vehicle vehicle,
    required int deductedExpensesTotal,
    bool isWide = false,
  }) {
    final sale = vehicle.activeSale!;
    final netPayoutCents = FinancialCalculator.calculateOwnerNetPayoutCentsFromMap(
          vehicle,
          {vehicle.id: deductedExpensesTotal},
          priceCents: sale.salePriceCents,
        ) ??
        0;
    final paidCents = sale.totalOwnerPayoutPaidCents;
    final remainingCents =
        (netPayoutCents - paidCents) > 0 ? (netPayoutCents - paidCents) : 0;

    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 0),
      decoration: isWide
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text(
                  'Acerto com o Proprietário',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                StatusBadge.payoutStatus(netPayoutCents, paidCents),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCell(
                    'Repasse Líquido',
                    Formatters.formatCurrency(netPayoutCents),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Repassado',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.formatCurrency(paidCents),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.successGreen,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Falta Repassar',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Formatters.formatCurrency(remainingCents),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: remainingCents > 0
                                  ? AppTheme.warningOrange
                                  : AppTheme.successGreen,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (remainingCents > 0) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(
                'Registrar repasse (${Formatters.formatCurrency(remainingCents)})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final saved = await showAdaptiveModalSheet<bool>(
                  context: context,
                  builder: (_) => OwnerPayoutDialog(
                    workspaceId: widget.workspaceId,
                    vehicleId: vehicle.id,
                    activeSale: sale,
                    netPayoutCents: netPayoutCents,
                    consignorName: vehicle.consignorName,
                    userUid: widget.userUid,
                    vehicleRepository: widget.vehicleRepository,
                  ),
                );
                if (saved == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Repasse registrado com sucesso!'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
            ),
          ],
          const Divider(height: 20, color: AppTheme.borderSubtle),
          const Text(
            'Repasses registrados',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          if (sale.ownerPayouts.isEmpty)
            const Text(
              'Nenhum repasse pago ao proprietário ainda.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            for (int i = 0; i < sale.ownerPayouts.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      sale.ownerPayouts[i].isValid
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: sale.ownerPayouts[i].isValid
                          ? AppTheme.successGreen
                          : AppTheme.dangerRed,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${Formatters.formatDate(sale.ownerPayouts[i].date)}: ${Formatters.formatCurrency(sale.ownerPayouts[i].amountCents)}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: sale.ownerPayouts[i].isValid
                              ? null
                              : TextDecoration.lineThrough,
                          color: sale.ownerPayouts[i].isValid
                              ? AppTheme.textMain
                              : AppTheme.textMuted,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    ),
                    if (sale.ownerPayouts[i].isValid)
                      IconButton(
                        icon: const Icon(
                          Icons.undo,
                          color: AppTheme.warningOrange,
                          size: 18,
                        ),
                        tooltip: 'Estornar repasse',
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: () =>
                            _revertOwnerPayout(sale.ownerPayouts[i]),
                      )
                    else
                      const Text(
                        'Estornado',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.dangerRed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildExpensesCard({
    required Vehicle vehicle,
    required List<Expense> expenses,
    bool isWide = false,
  }) {
    final validCount = expenses.where((e) => e.isValid).length;
    final validTotal = expenses.where((e) => e.isValid).fold<int>(0, (s, e) => s + e.amountCents);
    final byCategoryEntries = FinancialCalculator.calculateExpensesByCategory(expenses)
        .entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 0),
      decoration: isWide
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Despesas ($validCount)',
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                    ),
                    if (validTotal > 0)
                      Text(
                        'Total ${Formatters.formatCurrency(validTotal)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Gasto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.sectionDivider,
                  foregroundColor: AppTheme.textMain,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openNewExpenseModal(vehicle),
              ),
            ],
          ),
          if (byCategoryEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: byCategoryEntries.map((entry) {
                final label = AppConstants.expenseCategoryLabels[entry.key] ?? entry.key;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.sectionDivider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$label: ${Formatters.formatCurrency(entry.value)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMain,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),

          if (expenses.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma despesa lançada.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          ] else ...[
            for (int i = 0; i < expenses.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
              Builder(
                builder: (_) {
                  final e = expenses[i];
                  final authorName = _formatAuthorName(e.createdByEmail);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        _getCategoryIcon(e.category),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.categoryLabel,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: e.isValid ? AppTheme.textMain : AppTheme.textMuted,
                                  decoration: e.isValid ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              if (e.description != null && e.description!.isNotEmpty)
                                Text(
                                  e.description!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              if (e.deductFromConsignmentPayout)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, bottom: 2),
                                  child: Text(
                                    'Desconta do repasse ao proprietário',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentBlue,
                                    ),
                                  ),
                                ),
                              Text(
                                '${Formatters.formatDate(e.date)}${authorName != null ? " • $authorName" : ""}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textLight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.formatCurrency(e.amountCents),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: e.isValid ? AppTheme.dangerRed : AppTheme.textMuted,
                            decoration: e.isValid ? null : TextDecoration.lineThrough,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                        if (e.isValid) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 17),
                            tooltip: 'Editar gasto',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final saved = await showAdaptiveModalSheet<bool>(
                                context: context,
                                builder: (_) => ExpenseFormDialog(
                                  workspaceId: widget.workspaceId,
                                  vehicleId: vehicle.id,
                                  userUid: widget.userUid,
                                  userEmail: widget.userEmail,
                                  expenseRepository: widget.expenseRepository,
                                  expenseToEdit: e,
                                  isConsignedVehicle: vehicle.isConsigned,
                                ),
                              );
                              if (saved == true && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Despesa atualizada com sucesso!'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 17),
                            tooltip: 'Estornar gasto',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            padding: EdgeInsets.zero,
                            onPressed: () => _revertExpense(e),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData iconData = Icons.build_outlined;
    if (category == AppConstants.expenseCategoryParts) iconData = Icons.settings_outlined;
    if (category == AppConstants.expenseCategoryDocumentation) iconData = Icons.description_outlined;
    if (category == AppConstants.expenseCategoryTransport) iconData = Icons.local_shipping_outlined;
    if (category == AppConstants.expenseCategoryAdvertising) iconData = Icons.campaign_outlined;
    if (category == AppConstants.expenseCategoryCommission) iconData = Icons.paid_outlined;
    if (category == AppConstants.expenseCategoryCarWash) iconData = Icons.local_car_wash_outlined;

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 16, color: AppTheme.primaryDark),
    );
  }

  Widget _buildDocsCard(Vehicle vehicle, {bool isWide = false}) {
    return Container(
      padding: EdgeInsets.all(isWide ? 16 : 0),
      decoration: isWide
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            )
          : const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Documentos (CRLV-e)',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 15),
                label: const Text('Copiar p/ despachante', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(80, 36),
                ),
                onPressed: () => _copyDispatcherData(vehicle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (vehicle.docNotes != null && vehicle.docNotes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Observação: ${vehicle.docNotes}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _buildDocField(
                  'RENAVAM',
                  vehicle.renavam ?? '-',
                  copyValue: vehicle.renavam,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDocField(
                  'CRV',
                  vehicle.crvNumber ?? '-',
                  copyValue: vehicle.crvNumber,
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppTheme.borderSubtle),
          Row(
            children: [
              Expanded(child: _buildDocField('Exercício CRLV', vehicle.licensingYear?.toString() ?? '-')),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDocField(
                  vehicle.isConsigned ? 'Data Entrada' : 'Data Compra',
                  Formatters.formatDate(vehicle.purchaseDate),
                ),
              ),
            ],
          ),
          if (vehicle.notes != null && vehicle.notes!.isNotEmpty) ...[
            const Divider(height: 18, color: AppTheme.borderSubtle),
            Text('Notas: ${vehicle.notes}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildDocField(String label, String value, {String? copyValue}) {
    final canCopy = copyValue != null && copyValue.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canCopy ? () => _copyText(copyValue, '$label copiado!') : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                ],
              ),
            ),
            if (canCopy)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.copy, size: 14, color: AppTheme.accentBlue),
              ),
          ],
        ),
      ),
    );
  }
}
