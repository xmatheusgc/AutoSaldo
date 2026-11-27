import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/fipe_service.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/model_performance.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/csv_exporter.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/responsive_layout.dart';
import '../stock/vehicle_detail_screen.dart';
import 'csv_download_helper.dart';
import 'model_performance_view.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final String workspaceId;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final String? userUid;
  final String? userEmail;
  final FipeService? fipeService;
  final VoidCallback? onOpenAccount;
  final String? userInitial;

  const MonthlySummaryScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.userUid,
    this.userEmail,
    this.fipeService,
    this.onOpenAccount,
    this.userInitial,
  });

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  int _selectedSection = 0;
  late Stream<List<Vehicle>> _vehiclesStream;
  late Stream<List<Expense>> _expensesStream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _initStreams();
  }

  void _initStreams() {
    _vehiclesStream = widget.vehicleRepository.getVehiclesStream(widget.workspaceId);
    _expensesStream = widget.expenseRepository.getExpensesStream(widget.workspaceId);
  }

  @override
  void didUpdateWidget(covariant MonthlySummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.vehicleRepository != widget.vehicleRepository ||
        oldWidget.expenseRepository != widget.expenseRepository) {
      _initStreams();
    }
  }

  void _retryStreams() {
    setState(() {
      _initStreams();
    });
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  void _exportCsv(List<Vehicle> vehicles, List<Expense> expenses) {
    try {
      final csvContent = CsvExporter.generateCsv(
        vehicles: vehicles,
        expenses: expenses,
      );
      const filename = 'AutoSaldo_Extrato_Completo.csv';

      downloadCsv(csvContent, filename);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extrato CSV gerado com sucesso!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorMessages.friendly(
              e,
              fallback: 'Não foi possível exportar o extrato. Tente novamente.',
            ),
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  void _openVehicleDetail(BuildContext sheetContext, Vehicle vehicle) {
    Navigator.of(sheetContext).pop();
    if (widget.userUid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(
          workspaceId: widget.workspaceId,
          vehicleId: vehicle.id,
          userUid: widget.userUid!,
          userEmail: widget.userEmail,
          vehicleRepository: widget.vehicleRepository,
          expenseRepository: widget.expenseRepository,
          fipeService: widget.fipeService,
        ),
      ),
    );
  }

  void _showDrillDownSheet({
    required String title,
    required String subtitle,
    required List<Vehicle> items,
    required Widget Function(BuildContext sheetContext, Vehicle vehicle) itemBuilder,
  }) {
    showAdaptiveModalSheet(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Nenhum veículo nesta lista.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppTheme.borderSubtle,
                    ),
                    itemBuilder: (_, index) => itemBuilder(ctx, items[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrillDownTile({
    required BuildContext sheetContext,
    required Vehicle vehicle,
    required String subtitle,
    required String trailingLabel,
    required Color trailingColor,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openVehicleDetail(sheetContext, vehicle),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vehicle.formattedPlate,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        trailingLabel,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: trailingColor,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                vehicle.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  if (widget.userUid != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textLight,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSoldVehiclesDrillDown(
    List<Vehicle> allVehicles,
    Map<String, int> expensesByVehicle,
  ) {
    final monthPrefix = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
    final soldItems = allVehicles
        .where(
          (v) => v.activeSale != null && v.activeSale!.saleDate.startsWith(monthPrefix),
        )
        .toList()
      ..sort((a, b) => b.activeSale!.saleDate.compareTo(a.activeSale!.saleDate));

    _showDrillDownSheet(
      title: 'Vendas de ${Formatters.monthName(_selectedMonth)}/$_selectedYear',
      subtitle: '${soldItems.length} ${soldItems.length == 1 ? "veículo vendido" : "veículos vendidos"} no período',
      items: soldItems,
      itemBuilder: (ctx, v) {
        final cost = FinancialCalculator.calculateVehicleTotalCostFromMap(v, expensesByVehicle);
        final profit = v.activeSale!.salePriceCents - cost;
        final roi = FinancialCalculator.calculateRoiPercent(profit, cost);
        final days = FinancialCalculator.calculateDaysInStock(v);
        final isLoss = profit < 0;
        return _buildDrillDownTile(
          sheetContext: ctx,
          vehicle: v,
          subtitle:
              'Venda em ${Formatters.formatDate(v.activeSale!.saleDate)} • Giro: ${Formatters.formatDaysCount(days)}',
          trailingLabel:
              '${isLoss ? "-" : "+"}${Formatters.formatCurrency(profit.abs())}${roi != null ? " (${Formatters.formatPercent(roi)})" : ""}',
          trailingColor: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
        );
      },
    );
  }

  void _showStockDrillDown(
    List<Vehicle> allVehicles,
    Map<String, int> expensesByVehicle,
  ) {
    final stockItems = allVehicles.where((v) => v.isInStock).toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    _showDrillDownSheet(
      title: 'Veículos no Pátio (${stockItems.length})',
      subtitle: 'Ordenados do mais antigo para o mais recente no pátio',
      items: stockItems,
      itemBuilder: (ctx, v) {
        final cost = FinancialCalculator.calculateVehicleTotalCostFromMap(v, expensesByVehicle);
        final days = FinancialCalculator.calculateDaysInStock(v);
        final isStagnant = days >= AppConstants.stagnantStockDaysThreshold;
        final isCritical = days >= AppConstants.criticalStockDaysThreshold;
        return _buildDrillDownTile(
          sheetContext: ctx,
          vehicle: v,
          subtitle:
              'Pátio: ${Formatters.formatDaysCount(days)} • Investido: ${Formatters.formatCurrency(cost)}',
          trailingLabel: Formatters.formatDaysCount(days),
          trailingColor: isCritical
              ? AppTheme.dangerRed
              : isStagnant
                  ? AppTheme.warningOrange
                  : AppTheme.primaryDark,
        );
      },
    );
  }

  void _showPendingReceivablesDrillDown(List<Vehicle> allVehicles) {
    final pendingItems = allVehicles
        .where((v) => v.isSold && (v.activeSale?.balanceDueCents ?? 0) > 0)
        .toList()
      ..sort(
        (a, b) =>
            b.activeSale!.balanceDueCents.compareTo(a.activeSale!.balanceDueCents),
      );

    _showDrillDownSheet(
      title: 'Saldo a Receber (${pendingItems.length})',
      subtitle: 'Vendas com recebimento pendente',
      items: pendingItems,
      itemBuilder: (ctx, v) {
        final sale = v.activeSale!;
        return _buildDrillDownTile(
          sheetContext: ctx,
          vehicle: v,
          subtitle:
              'Recebido ${Formatters.formatCurrency(sale.totalReceivedCents)} de ${Formatters.formatCurrency(sale.salePriceCents)}',
          trailingLabel: Formatters.formatCurrency(sale.balanceDueCents),
          trailingColor: AppTheme.warningOrange,
        );
      },
    );
  }

  void _showModelSalesDrillDown(
    ModelPerformanceStats modelStats,
    Map<String, int> expensesByVehicle,
  ) {
    _showDrillDownSheet(
      title: modelStats.displayName,
      subtitle:
          '${modelStats.soldCount} ${modelStats.soldCount == 1 ? "venda registrada" : "vendas registradas"}',
      items: modelStats.soldVehicles,
      itemBuilder: (ctx, v) {
        final cost = FinancialCalculator.calculateVehicleTotalCostFromMap(v, expensesByVehicle);
        final profit = v.activeSale!.salePriceCents - cost;
        final roi = FinancialCalculator.calculateRoiPercent(profit, cost);
        final days = FinancialCalculator.calculateDaysInStock(v);
        final isLoss = profit < 0;
        return _buildDrillDownTile(
          sheetContext: ctx,
          vehicle: v,
          subtitle:
              'Venda em ${Formatters.formatDate(v.activeSale!.saleDate)} • Giro: ${Formatters.formatDaysCount(days)}',
          trailingLabel:
              '${isLoss ? "-" : "+"}${Formatters.formatCurrency(profit.abs())}${roi != null ? " (${Formatters.formatPercent(roi)})" : ""}',
          trailingColor: isLoss ? AppTheme.dangerRed : AppTheme.successGreen,
        );
      },
    );
  }

  Widget _buildTurnoverMetric({
    required String label,
    required String value,
    Color valueColor = AppTheme.textMain,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFeatures: AppTheme.tabularNumbers,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: _vehiclesStream,
      builder: (context, vSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, eSnapshot) {
            if (vSnapshot.hasError || eSnapshot.hasError) {
              return Scaffold(
                backgroundColor: AppTheme.bgSurface,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.dangerRed),
                          const SizedBox(height: 16),
                          const Text(
                            'Não foi possível carregar o resumo',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Confira sua conexão com a internet e tente novamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
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
                ),
              );
            }

            if ((vSnapshot.connectionState == ConnectionState.waiting && !vSnapshot.hasData) ||
                (eSnapshot.connectionState == ConnectionState.waiting && !eSnapshot.hasData)) {
              return const Scaffold(
                backgroundColor: AppTheme.bgSurface,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final vehicles = vSnapshot.data ?? [];
            final expenses = eSnapshot.data ?? [];
            final expensesByVehicle =
                FinancialCalculator.aggregateValidExpensesByVehicle(expenses);

            final summary = FinancialCalculator.calculateMonthlySummary(
              allVehicles: vehicles,
              allExpenses: expenses,
              year: _selectedYear,
              month: _selectedMonth,
            );

            final isNetPositive = summary.monthNetCashCents >= 0;
            final isProfitPositive = summary.soldVehiclesProfitCents >= 0;
            final isDesktopLayout = MediaQuery.sizeOf(context).width >= 840;

            final headerBar = Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ResponsiveBreakpoints.maxContentWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isDesktopLayout ? 24 : 16,
                            isDesktopLayout ? 14 : 10,
                            isDesktopLayout ? 24 : 12,
                            4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Resumo Financeiro',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isDesktopLayout ? 22 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.file_download_outlined, size: 17),
                                label: const Text(
                                  'Exportar CSV',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textMain,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: AppTheme.borderInteractive),
                                  minimumSize: const Size(110, 38),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _exportCsv(vehicles, expenses),
                              ),
                              if (!isDesktopLayout && widget.onOpenAccount != null) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Minha Conta',
                                  child: InkWell(
                                    onTap: widget.onOpenAccount,
                                    borderRadius: BorderRadius.circular(22),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Center(
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppTheme.sectionDivider,
                                          child: Text(
                                            widget.userInitial ?? 'U',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textMain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppUnderlineTabBar<int>(
                          selectedValue: _selectedSection,
                          padding: EdgeInsets.symmetric(horizontal: isDesktopLayout ? 24 : 16),
                          showBottomBorder: false,
                          onChanged: (idx) => setState(() => _selectedSection = idx),
                          items: const [
                            AppSegmentedItem(value: 0, label: 'Resumo do Mês'),
                            AppSegmentedItem(value: 1, label: 'Por Modelo'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            final monthSelector = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktopLayout ? 360 : double.infinity,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      onPressed: _previousMonth,
                      tooltip: 'Mês anterior',
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.sectionDivider,
                        foregroundColor: AppTheme.textMain,
                      ),
                    ),
                    Text(
                      '${Formatters.monthName(_selectedMonth).toUpperCase()} $_selectedYear',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppTheme.textMain,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      onPressed: _nextMonth,
                      tooltip: 'Próximo mês',
                      constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.sectionDivider,
                        foregroundColor: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            );

            final profitCard = Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: summary.soldCount > 0
                    ? () => _showSoldVehiclesDrillDown(vehicles, expensesByVehicle)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isProfitPositive ? AppTheme.successBorder : AppTheme.dangerBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isProfitPositive ? Icons.trending_up : Icons.trending_down,
                            color: isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Lucro das Vendas do Mês',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.sectionDivider,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              summary.soldCount == 1 ? '1 venda' : '${summary.soldCount} vendas',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${isProfitPositive ? "+" : "-"}${Formatters.formatCurrency(summary.soldVehiclesProfitCents.abs())}',
                          style: TextStyle(
                            fontSize: isDesktopLayout ? 32 : 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (summary.soldInMonthRoiPercent != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: isProfitPositive
                                          ? AppTheme.successLight
                                          : AppTheme.dangerLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'ROI ${Formatters.formatPercent(summary.soldInMonthRoiPercent!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isProfitPositive
                                            ? AppTheme.successGreen
                                            : AppTheme.dangerRed,
                                        fontFeatures: AppTheme.tabularNumbers,
                                      ),
                                    ),
                                  ),
                                if (summary.avgDaysToSell != null)
                                  Text(
                                    'Giro médio ${Formatters.formatDaysCount(summary.avgDaysToSell!.round())}',
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
                          if (summary.soldCount > 0) ...[
                            const Text(
                              'Ver carros',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppTheme.accentBlue,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );

            final cashFlowCard = Container(
              padding: EdgeInsets.all(isDesktopLayout ? 18 : 0),
              decoration: isDesktopLayout
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    )
                  : const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fluxo de Caixa no Mês',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCashRow(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppTheme.successGreen,
                    label: 'Entradas',
                    value: '+${Formatters.formatCurrency(summary.monthIncomeCents)}',
                    valueColor: AppTheme.successGreen,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                  _buildCashRow(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppTheme.dangerRed,
                    label: 'Saídas',
                    value: '-${Formatters.formatCurrency(summary.monthExpensesCents)}',
                    valueColor: AppTheme.dangerRed,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Saldo do período',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${isNetPositive ? "+" : "-"}${Formatters.formatCurrency(summary.monthNetCashCents.abs())}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isNetPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                                fontFeatures: AppTheme.tabularNumbers,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final positionRows = Container(
              padding: EdgeInsets.all(isDesktopLayout ? 16 : 0),
              decoration: isDesktopLayout
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    )
                  : const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Posição Geral (Hoje)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPositionTile(
                    icon: Icons.directions_car_outlined,
                    iconColor: AppTheme.textMain,
                    title: 'No Pátio',
                    subtitle:
                        '${summary.stockCount} ${summary.stockCount == 1 ? "carro" : "carros"} em estoque${summary.stagnantStockCount > 0 ? " • ${summary.stagnantStockCount} há +45d" : ""}',
                    subtitleColor: summary.stagnantStockCount > 0
                        ? AppTheme.warningOrange
                        : AppTheme.textMuted,
                    value: Formatters.formatCurrency(summary.currentStockInvestmentCents),
                    valueColor: AppTheme.textMain,
                    onTap: summary.stockCount > 0
                        ? () => _showStockDrillDown(vehicles, expensesByVehicle)
                        : null,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                  _buildPositionTile(
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: summary.toReceiveTodayCents > 0
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                    title: 'A Receber',
                    subtitle: summary.pendingReceiveVehiclesCount == 0
                        ? 'Nenhuma venda em aberto'
                        : '${summary.pendingReceiveVehiclesCount} ${summary.pendingReceiveVehiclesCount == 1 ? "venda em aberto" : "vendas em aberto"}',
                    value: Formatters.formatCurrency(summary.toReceiveTodayCents),
                    valueColor: summary.toReceiveTodayCents > 0
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                    onTap: summary.pendingReceiveVehiclesCount > 0
                        ? () => _showPendingReceivablesDrillDown(vehicles)
                        : null,
                  ),
                  const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                  const SizedBox(height: 12),
                  const Text(
                    'Giro & Saúde do Pátio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTurnoverMetric(
                        label: 'Giro médio',
                        value: summary.avgDaysToSell != null
                            ? Formatters.formatDaysCount(summary.avgDaysToSell!.round())
                            : '—',
                      ),
                      Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                      _buildTurnoverMetric(
                        label: 'Idade no pátio',
                        value: summary.avgStockAgeDays != null
                            ? Formatters.formatDaysCount(summary.avgStockAgeDays!.round())
                            : '—',
                      ),
                      Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                      _buildTurnoverMetric(
                        label: 'Parados (+45d)',
                        value: '${summary.stagnantStockCount}',
                        valueColor: summary.stagnantStockCount > 0
                            ? AppTheme.warningOrange
                            : AppTheme.successGreen,
                      ),
                    ],
                  ),
                ],
              ),
            );

            final sortedCategoryEntries = summary.monthExpensesByCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final totalCategoryExpensesCents = sortedCategoryEntries.fold<int>(
              0,
              (sum, e) => sum + e.value,
            );

            final categoryExpensesCard = Container(
              padding: EdgeInsets.all(isDesktopLayout ? 18 : 0),
              decoration: isDesktopLayout
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
                      const Expanded(
                        child: Text(
                          'Gastos do Mês por Categoria',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                      if (totalCategoryExpensesCents > 0)
                        Text(
                          Formatters.formatCurrency(totalCategoryExpensesCents),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dangerRed,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (sortedCategoryEntries.isEmpty)
                    const Text(
                      'Nenhuma despesa registrada neste mês.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    )
                  else
                    ...sortedCategoryEntries.map((entry) {
                      final label =
                          AppConstants.expenseCategoryLabels[entry.key] ?? entry.key;
                      final ratio = totalCategoryExpensesCents > 0
                          ? entry.value / totalCategoryExpensesCents
                          : 0.0;
                      final pct = (ratio * 100).round();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${Formatters.formatCurrency(entry.value)} ($pct%)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMuted,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: AppTheme.sectionDivider,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );

            return Scaffold(
              backgroundColor: isDesktopLayout ? AppTheme.desktopBg : Colors.white,
              body: Column(
                children: [
                  headerBar,
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: isDesktopLayout ? 32 : 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktopLayout
                                ? ResponsiveBreakpoints.maxContentWidth
                                : 640,
                          ),
                          child: _selectedSection == 1
                              ? Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isDesktopLayout ? 24 : 16,
                                    16,
                                    isDesktopLayout ? 24 : 16,
                                    0,
                                  ),
                                  child: ModelPerformanceView(
                                    vehicles: vehicles,
                                    expenses: expenses,
                                    isDesktopLayout: isDesktopLayout,
                                    onModelTap: (stats) =>
                                        _showModelSalesDrillDown(stats, expensesByVehicle),
                                  ),
                                )
                              : isDesktopLayout
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          monthSelector,
                                          const SizedBox(height: 16),
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(child: profitCard),
                                                const SizedBox(width: 16),
                                                Expanded(child: cashFlowCard),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          IntrinsicHeight(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(child: positionRows),
                                                const SizedBox(width: 16),
                                                Expanded(child: categoryExpensesCard),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                          child: monthSelector,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                          child: profitCard,
                                        ),
                                        Container(height: 8, color: AppTheme.sectionDivider),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: cashFlowCard,
                                        ),
                                        Container(height: 8, color: AppTheme.sectionDivider),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: positionRows,
                                        ),
                                        Container(height: 8, color: AppTheme.sectionDivider),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: categoryExpensesCard,
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCashRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  fontFeatures: AppTheme.tabularNumbers,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color subtitleColor = AppTheme.textMuted,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: subtitleColor == AppTheme.warningOrange
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  fontFeatures: AppTheme.tabularNumbers,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppTheme.textLight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
