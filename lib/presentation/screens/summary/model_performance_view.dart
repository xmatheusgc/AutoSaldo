import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/model_performance.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';

enum _ModelRankingSort {
  totalProfit,
  avgProfit,
  fastest,
  bestRoi,
  mostSold,
}

class ModelPerformanceView extends StatefulWidget {
  final List<Vehicle> vehicles;
  final List<Expense> expenses;
  final bool isDesktopLayout;
  final void Function(ModelPerformanceStats modelStats) onModelTap;

  const ModelPerformanceView({
    super.key,
    required this.vehicles,
    required this.expenses,
    required this.isDesktopLayout,
    required this.onModelTap,
  });

  @override
  State<ModelPerformanceView> createState() => _ModelPerformanceViewState();
}

class _ModelPerformanceViewState extends State<ModelPerformanceView> {
  ModelAnalyticsWindow _window = ModelAnalyticsWindow.allTime;
  _ModelRankingSort _sort = _ModelRankingSort.totalProfit;

  List<ModelPerformanceStats> _sortedModels(List<ModelPerformanceStats> models) {
    final sorted = List<ModelPerformanceStats>.from(models);
    sorted.sort((a, b) {
      return switch (_sort) {
        _ModelRankingSort.totalProfit => b.totalProfitCents.compareTo(a.totalProfitCents),
        _ModelRankingSort.avgProfit => b.avgProfitCents.compareTo(a.avgProfitCents),
        _ModelRankingSort.fastest => () {
            final cmp = a.avgDaysToSell.compareTo(b.avgDaysToSell);
            return cmp != 0 ? cmp : b.soldCount.compareTo(a.soldCount);
          }(),
        _ModelRankingSort.bestRoi =>
          (b.roiPercent ?? double.negativeInfinity)
              .compareTo(a.roiPercent ?? double.negativeInfinity),
        _ModelRankingSort.mostSold => () {
            final cmp = b.soldCount.compareTo(a.soldCount);
            return cmp != 0 ? cmp : b.totalProfitCents.compareTo(a.totalProfitCents);
          }(),
      };
    });
    return sorted;
  }

  String _windowLabel(ModelAnalyticsWindow w) => switch (w) {
        ModelAnalyticsWindow.allTime => 'Todo o período',
        ModelAnalyticsWindow.last12Months => 'Últimos 12 meses',
        ModelAnalyticsWindow.last6Months => 'Últimos 6 meses',
      };

  String _sortLabel(_ModelRankingSort s) => switch (s) {
        _ModelRankingSort.totalProfit => 'Maior lucro',
        _ModelRankingSort.avgProfit => 'Lucro médio',
        _ModelRankingSort.fastest => 'Mais rápido',
        _ModelRankingSort.bestRoi => 'Melhor ROI',
        _ModelRankingSort.mostSold => 'Mais vendidos',
      };

  String _formatAvgDays(double avgDays) {
    return Formatters.formatDaysCount(avgDays.round());
  }

  Widget _buildCompactDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item,
            child: Row(
              children: [
                if (item == value)
                  const Icon(Icons.check, size: 16, color: AppTheme.textMain)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  labelBuilder(item),
                  style: TextStyle(
                    fontWeight: item == value ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.sectionDivider,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, {Color? valueColor}) {
    return Column(
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textMain,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard({
    required String title,
    required ModelPerformanceStats stats,
    required String mainMetric,
    required Color accentColor,
    required String subMetric,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onModelTap(stats),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stats.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  mainMetric,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    fontFeatures: AppTheme.tabularNumbers,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subMetric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = FinancialCalculator.calculateModelReport(
      allVehicles: widget.vehicles,
      allExpenses: widget.expenses,
      window: _window,
    );

    final selectorsRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildCompactDropdown<ModelAnalyticsWindow>(
          label: _windowLabel(_window),
          value: _window,
          items: ModelAnalyticsWindow.values,
          labelBuilder: _windowLabel,
          onSelected: (w) => setState(() => _window = w),
        ),
        if (report.totalSoldCount > 0)
          _buildCompactDropdown<_ModelRankingSort>(
            label: 'Ordenar: ${_sortLabel(_sort)}',
            value: _sort,
            items: _ModelRankingSort.values,
            labelBuilder: _sortLabel,
            onSelected: (s) => setState(() => _sort = s),
          ),
      ],
    );

    if (report.totalSoldCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selectorsRow,
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: const Column(
              children: [
                Icon(Icons.analytics_outlined, size: 42, color: AppTheme.textLight),
                SizedBox(height: 10),
                Text(
                  'Sem vendas neste período',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Nenhuma venda encontrada para o intervalo selecionado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final sortedModels = _sortedModels(report.models);
    final isOverallProfitPositive = report.totalProfitCents >= 0;

    final overviewStrip = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: widget.isDesktopLayout
          ? Row(
              children: [
                Expanded(child: _buildMetricCell('Vendas', '${report.totalSoldCount}')),
                Expanded(
                  child: _buildMetricCell(
                    'Giro médio',
                    report.overallAvgDaysToSell != null
                        ? _formatAvgDays(report.overallAvgDaysToSell!)
                        : '--',
                  ),
                ),
                Expanded(
                  child: _buildMetricCell(
                    'Lucro total',
                    '${isOverallProfitPositive ? "+" : "-"}${Formatters.formatCurrency(report.totalProfitCents.abs())}',
                    valueColor:
                        isOverallProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                  ),
                ),
                Expanded(
                  child: _buildMetricCell(
                    'ROI médio',
                    report.overallRoiPercent != null
                        ? Formatters.formatPercent(report.overallRoiPercent!)
                        : '--',
                    valueColor:
                        (report.overallRoiPercent ?? 0) >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMetricCell('Vendas', '${report.totalSoldCount}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCell(
                        'Giro médio',
                        report.overallAvgDaysToSell != null
                            ? _formatAvgDays(report.overallAvgDaysToSell!)
                            : '--',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18, color: AppTheme.borderSubtle),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCell(
                        'Lucro total',
                        '${isOverallProfitPositive ? "+" : "-"}${Formatters.formatCurrency(report.totalProfitCents.abs())}',
                        valueColor:
                            isOverallProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCell(
                        'ROI médio',
                        report.overallRoiPercent != null
                            ? Formatters.formatPercent(report.overallRoiPercent!)
                            : '--',
                        valueColor: (report.overallRoiPercent ?? 0) >= 0
                            ? AppTheme.successGreen
                            : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

    final highlightCards = <Widget>[
      if (report.fastestModel != null)
        _buildHighlightCard(
          title: 'Giro mais rápido',
          stats: report.fastestModel!,
          mainMetric: '${_formatAvgDays(report.fastestModel!.avgDaysToSell)} / venda',
          accentColor: AppTheme.accentBlue,
          subMetric:
              '${report.fastestModel!.soldCount} ${report.fastestModel!.soldCount == 1 ? "venda" : "vendas"}',
        ),
      if (report.highestAvgProfitModel != null)
        _buildHighlightCard(
          title: 'Maior lucro médio',
          stats: report.highestAvgProfitModel!,
          mainMetric:
              '${report.highestAvgProfitModel!.avgProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(report.highestAvgProfitModel!.avgProfitCents.abs())}',
          accentColor: report.highestAvgProfitModel!.avgProfitCents >= 0
              ? AppTheme.successGreen
              : AppTheme.dangerRed,
          subMetric: 'Giro ${_formatAvgDays(report.highestAvgProfitModel!.avgDaysToSell)}',
        ),
      if (report.bestRoiModel != null)
        _buildHighlightCard(
          title: 'Melhor ROI',
          stats: report.bestRoiModel!,
          mainMetric: Formatters.formatPercent(report.bestRoiModel!.roiPercent!),
          accentColor: (report.bestRoiModel!.roiPercent ?? 0) >= 0
              ? AppTheme.textMain
              : AppTheme.dangerRed,
          subMetric:
              '${report.bestRoiModel!.soldCount} ${report.bestRoiModel!.soldCount == 1 ? "venda" : "vendas"}',
        ),
      if (report.highestTotalProfitModel != null)
        _buildHighlightCard(
          title: 'Lucro acumulado',
          stats: report.highestTotalProfitModel!,
          mainMetric:
              '${report.highestTotalProfitModel!.totalProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(report.highestTotalProfitModel!.totalProfitCents.abs())}',
          accentColor: report.highestTotalProfitModel!.totalProfitCents >= 0
              ? AppTheme.successGreen
              : AppTheme.dangerRed,
          subMetric:
              '${report.highestTotalProfitModel!.soldCount} ${report.highestTotalProfitModel!.soldCount == 1 ? "venda" : "vendas"}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selectorsRow,
        const SizedBox(height: 12),
        overviewStrip,
        const SizedBox(height: 16),

        const Text(
          'Destaques',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = widget.isDesktopLayout
                ? (constraints.maxWidth >= 900 ? 4 : 2)
                : 2;
            const spacing = 10.0;
            final itemWidth = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final card in highlightCards)
                  SizedBox(width: itemWidth, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        Text(
          'Ranking por Modelo (${sortedModels.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < sortedModels.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                _buildModelRankRow(i + 1, sortedModels[i]),
              ],
            ],
          ),
        ),

        if (report.brands.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Desempenho por Marca',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < report.brands.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                  Builder(
                    builder: (_) {
                      final b = report.brands[i];
                      final pos = b.totalProfitCents >= 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.brand,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  Text(
                                    '${b.soldCount} ${b.soldCount == 1 ? "venda" : "vendas"} • Giro médio ${_formatAvgDays(b.avgDaysToSell)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${pos ? "+" : "-"}${Formatters.formatCurrency(b.totalProfitCents.abs())}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: pos ? AppTheme.successGreen : AppTheme.dangerRed,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                ),
                                if (b.roiPercent != null)
                                  Text(
                                    'ROI ${Formatters.formatPercent(b.roiPercent!)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: pos ? AppTheme.successGreen : AppTheme.dangerRed,
                                      fontFeatures: AppTheme.tabularNumbers,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelRankRow(int rank, ModelPerformanceStats m) {
    final isPositive = m.totalProfitCents >= 0;
    final totalProfitColor = isPositive ? AppTheme.successGreen : AppTheme.dangerRed;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => widget.onModelTap(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3 ? AppTheme.textMain : AppTheme.textMuted,
                        fontFeatures: AppTheme.tabularNumbers,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      m.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${isPositive ? "+" : "-"}${Formatters.formatCurrency(m.totalProfitCents.abs())}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: totalProfitColor,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${m.soldCount} ${m.soldCount == 1 ? "venda" : "vendas"} • Giro ${_formatAvgDays(m.avgDaysToSell)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                          Text(
                            'Média ${m.avgProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(m.avgProfitCents.abs())}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                              fontFeatures: AppTheme.tabularNumbers,
                            ),
                          ),
                          if (m.inStockCount > 0)
                            Text(
                              '• ${m.inStockCount} pátio',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (m.roiPercent != null)
                      Text(
                        'ROI ${Formatters.formatPercent(m.roiPercent!)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: (m.roiPercent ?? 0) >= 0
                              ? AppTheme.successGreen
                              : AppTheme.dangerRed,
                          fontFeatures: AppTheme.tabularNumbers,
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: AppTheme.textLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
