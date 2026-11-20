import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/fipe_service.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/csv_exporter.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/responsive_layout.dart';
import '../stock/vehicle_detail_screen.dart';
import 'csv_download_helper.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final String workspaceId;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final String? userUid;
  final String? userEmail;
  final FipeService? fipeService;

  const MonthlySummaryScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.userUid,
    this.userEmail,
    this.fipeService,
  });

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late int _selectedYear;
  late int _selectedMonth;
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
      final filename =
          'AutoSaldo_Extrato_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv';

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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openVehicleDetail(sheetContext, vehicle),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CarPlateWidget(plate: vehicle.plate, fontSize: 12),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        trailingLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: trailingColor,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                vehicle.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  if (widget.userUid != null) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Abrir >',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                  ],
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
            final isDesktopLayout =
                MediaQuery.sizeOf(context).width >= 840;

            final headerRow = SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumo Financeiro',
                        style: TextStyle(
                          fontSize: isDesktopLayout ? 24 : 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Lucro, entradas e saídas consolidadas',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text(
                      'Exportar CSV',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryDark,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderInteractive),
                      minimumSize: const Size(136, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _exportCsv(vehicles, expenses),
                  ),
                ],
              ),
            );

            final monthSelector = Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: _previousMonth,
                    tooltip: 'Mês anterior',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        Formatters.monthName(_selectedMonth).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        '$_selectedYear',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: _nextMonth,
                    tooltip: 'Próximo mês',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
            );

            final profitCard = Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: summary.soldCount > 0
                    ? () => _showSoldVehiclesDrillDown(vehicles, expensesByVehicle)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isProfitPositive ? AppTheme.successBorder : AppTheme.dangerBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed)
                            .withAlpha(12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: isDesktopLayout
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isProfitPositive
                                        ? AppTheme.successLight
                                        : AppTheme.dangerLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isProfitPositive ? Icons.trending_up : Icons.trending_down,
                                    color: isProfitPositive
                                        ? AppTheme.successGreen
                                        : AppTheme.dangerRed,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Lucro das Vendas do Mês',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              summary.soldCount == 1 ? '1 venda' : '${summary.soldCount} vendas',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${isProfitPositive ? "+" : "-"}${Formatters.formatCurrency(summary.soldVehiclesProfitCents.abs())}',
                              style: TextStyle(
                                fontSize: isDesktopLayout ? 34 : 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isProfitPositive
                                    ? AppTheme.successGreen
                                    : AppTheme.dangerRed,
                                fontFeatures: AppTheme.tabularNumbers,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (summary.soldInMonthRoiPercent != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isProfitPositive
                                        ? AppTheme.successLight
                                        : AppTheme.dangerLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ROI: ${Formatters.formatPercent(summary.soldInMonthRoiPercent!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isProfitPositive
                                          ? AppTheme.successGreen
                                          : AppTheme.dangerRed,
                                      fontFeatures: AppTheme.tabularNumbers,
                                    ),
                                  ),
                                ),
                              if (summary.avgDaysToSell != null)
                                Text(
                                  'Giro médio: ${Formatters.formatDaysCount(summary.avgDaysToSell!.round())}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Valor final das vendas menos o custo total investido nos carros.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ),
                              if (summary.soldCount > 0) ...[
                                const SizedBox(width: 8),
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
                    ],
                  ),
                ),
              ),
            );

            final cashFlowCard = Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movimento de Dinheiro no Mês',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'O que realmente entrou e saiu do seu caixa neste período.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.successBorder.withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_downward, color: AppTheme.successGreen, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Entradas no mês',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              Text(
                                'Pagamentos recebidos',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+ ${Formatters.formatCurrency(summary.monthIncomeCents)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.successGreen,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dangerBorder.withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward, color: AppTheme.dangerRed, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saídas no mês',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              Text(
                                'Compras e despesas pagas',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '- ${Formatters.formatCurrency(summary.monthExpensesCents)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.dangerRed,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 26, color: AppTheme.borderSubtle),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sobrou no período:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isNetPositive ? "+" : "-"}${Formatters.formatCurrency(summary.monthNetCashCents.abs())}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isNetPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            final stockPositionCard = Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: summary.stockCount > 0
                    ? () => _showStockDrillDown(vehicles, expensesByVehicle)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_filled, size: 18, color: AppTheme.accentBlue),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'No Pátio',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          if (summary.stockCount > 0)
                            const Icon(Icons.chevron_right, size: 16, color: AppTheme.textLight),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.formatCurrency(summary.currentStockInvestmentCents),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.stockCount} ${summary.stockCount == 1 ? "carro" : "carros"} em estoque',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (summary.stagnantStockCount > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.warningBorder),
                          ),
                          child: Text(
                            '${summary.stagnantStockCount} há +45d',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );

            final toReceiveCard = Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: summary.pendingReceiveVehiclesCount > 0
                    ? () => _showPendingReceivablesDrillDown(vehicles)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hourglass_bottom, size: 18, color: AppTheme.warningOrange),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'A Receber',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          if (summary.pendingReceiveVehiclesCount > 0)
                            const Icon(Icons.chevron_right, size: 16, color: AppTheme.textLight),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.formatCurrency(summary.toReceiveTodayCents),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: summary.toReceiveTodayCents > 0
                                ? AppTheme.warningOrange
                                : AppTheme.successGreen,
                            fontFeatures: AppTheme.tabularNumbers,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.pendingReceiveVehiclesCount == 0
                            ? 'Nenhuma venda em aberto'
                            : '${summary.pendingReceiveVehiclesCount} ${summary.pendingReceiveVehiclesCount == 1 ? "venda em aberto" : "vendas em aberto"}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final turnoverCard = Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed_outlined, size: 18, color: AppTheme.primaryDark),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Giro & Saúde do Pátio',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildTurnoverMetric(
                        label: 'Giro médio',
                        value: summary.avgDaysToSell != null
                            ? Formatters.formatDaysCount(summary.avgDaysToSell!.round())
                            : '—',
                      ),
                      Container(width: 1, height: 28, color: AppTheme.borderSubtle),
                      _buildTurnoverMetric(
                        label: 'Idade no pátio',
                        value: summary.avgStockAgeDays != null
                            ? Formatters.formatDaysCount(summary.avgStockAgeDays!.round())
                            : '—',
                      ),
                      Container(width: 1, height: 28, color: AppTheme.borderSubtle),
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
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
                        padding: const EdgeInsets.only(bottom: 10),
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
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: const Color(0xFFF1F5F9),
                                color: AppTheme.accentBlue,
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
              backgroundColor: AppTheme.bgSurface,
              body: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isDesktopLayout ? 24 : 16,
                  isDesktopLayout ? 20 : 14,
                  isDesktopLayout ? 24 : 16,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktopLayout ? ResponsiveBreakpoints.maxContentWidth : 640,
                    ),
                    child: isDesktopLayout
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              headerRow,
                              const SizedBox(height: 18),
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
                              const SizedBox(height: 20),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Text(
                                  'Posição Geral (Hoje)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: stockPositionCard),
                                    const SizedBox(width: 14),
                                    Expanded(child: toReceiveCard),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 2, child: turnoverCard),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              categoryExpensesCard,
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              headerRow,
                              const SizedBox(height: 14),
                              monthSelector,
                              const SizedBox(height: 14),
                              profitCard,
                              const SizedBox(height: 14),
                              cashFlowCard,
                              const SizedBox(height: 14),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Text(
                                  'Posição Geral (Hoje)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: stockPositionCard),
                                    const SizedBox(width: 12),
                                    Expanded(child: toReceiveCard),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              turnoverCard,
                              const SizedBox(height: 14),
                              categoryExpensesCard,
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
