import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/model_performance.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_segmented_control.dart';

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
    final rounded = avgDays.round();
    return Formatters.formatDaysCount(rounded);
  }

  Widget _buildHighlightCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color tintColor,
    required ModelPerformanceStats stats,
    required String mainMetric,
    required String subMetric,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onModelTap(stats),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tintColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                stats.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textMain,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = FinancialCalculator.calculateModelReport(
      allVehicles: widget.vehicles,
      allExpenses: widget.expenses,
      window: _window,
    );

    final windowSelector = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in ModelAnalyticsWindow.values)
          AppFilterPill(
            label: _windowLabel(w),
            selected: _window == w,
            onTap: () => setState(() => _window = w),
          ),
      ],
    );

    if (report.totalSoldCount == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          windowSelector,
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: const Column(
              children: [
                Icon(Icons.analytics_outlined, size: 44, color: AppTheme.textLight),
                SizedBox(height: 12),
                Text(
                  'Sem vendas neste período',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Assim que houver veículos vendidos no período selecionado, mostraremos aqui os modelos de giro mais rápido e maior lucro.',
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

    final overviewBanner = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 18, color: AppTheme.accentBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desempenho Consolidado • ${_windowLabel(_window)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.isDesktopLayout)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCell(
                    'Vendas',
                    '${report.totalSoldCount}',
                  ),
                ),
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
                    valueColor: isOverallProfitPositive
                        ? AppTheme.successGreen
                        : AppTheme.dangerRed,
                  ),
                ),
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
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricCell(
                    'Vendas',
                    '${report.totalSoldCount}',
                  ),
                ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCell(
                    'Lucro total',
                    '${isOverallProfitPositive ? "+" : "-"}${Formatters.formatCurrency(report.totalProfitCents.abs())}',
                    valueColor: isOverallProfitPositive
                        ? AppTheme.successGreen
                        : AppTheme.dangerRed,
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
        ],
      ),
    );

    final highlightCards = <Widget>[
      if (report.fastestModel != null)
        _buildHighlightCard(
          title: 'Giro mais rápido',
          icon: Icons.bolt,
          accentColor: AppTheme.accentBlue,
          tintColor: const Color(0xFFEFF6FF),
          stats: report.fastestModel!,
          mainMetric: '${_formatAvgDays(report.fastestModel!.avgDaysToSell)} em média',
          subMetric:
              '${report.fastestModel!.soldCount} ${report.fastestModel!.soldCount == 1 ? "venda" : "vendas"} • ROI ${report.fastestModel!.roiPercent != null ? Formatters.formatPercent(report.fastestModel!.roiPercent!) : "--"}',
        ),
      if (report.highestAvgProfitModel != null)
        _buildHighlightCard(
          title: 'Maior lucro médio',
          icon: Icons.trending_up,
          accentColor: report.highestAvgProfitModel!.avgProfitCents >= 0
              ? AppTheme.successGreen
              : AppTheme.dangerRed,
          tintColor: AppTheme.successLight,
          stats: report.highestAvgProfitModel!,
          mainMetric:
              '${report.highestAvgProfitModel!.avgProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(report.highestAvgProfitModel!.avgProfitCents.abs())} / carro',
          subMetric:
              '${report.highestAvgProfitModel!.soldCount} ${report.highestAvgProfitModel!.soldCount == 1 ? "venda" : "vendas"} • Giro ${_formatAvgDays(report.highestAvgProfitModel!.avgDaysToSell)}',
        ),
      if (report.bestRoiModel != null)
        _buildHighlightCard(
          title: 'Melhor ROI',
          icon: Icons.percent,
          accentColor: (report.bestRoiModel!.roiPercent ?? 0) >= 0
              ? AppTheme.primaryDark
              : AppTheme.dangerRed,
          tintColor: const Color(0xFFF1F5F9),
          stats: report.bestRoiModel!,
          mainMetric: Formatters.formatPercent(report.bestRoiModel!.roiPercent!),
          subMetric:
              '${report.bestRoiModel!.soldCount} ${report.bestRoiModel!.soldCount == 1 ? "venda" : "vendas"} • Giro ${_formatAvgDays(report.bestRoiModel!.avgDaysToSell)}',
        ),
      if (report.highestTotalProfitModel != null)
        _buildHighlightCard(
          title: 'Maior lucro acumulado',
          icon: Icons.workspace_premium_outlined,
          accentColor: AppTheme.warningOrange,
          tintColor: const Color(0xFFFFFBEB),
          stats: report.highestTotalProfitModel!,
          mainMetric:
              '${report.highestTotalProfitModel!.totalProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(report.highestTotalProfitModel!.totalProfitCents.abs())}',
          subMetric:
              '${report.highestTotalProfitModel!.soldCount} ${report.highestTotalProfitModel!.soldCount == 1 ? "venda" : "vendas"} no total',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        windowSelector,
        const SizedBox(height: 14),
        overviewBanner,
        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Destaques',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = widget.isDesktopLayout
                ? (constraints.maxWidth >= 900 ? 4 : 2)
                : (constraints.maxWidth >= 460 ? 2 : 1);
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

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ranking por Modelo (${sortedModels.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _ModelRankingSort.values)
              AppFilterPill(
                label: _sortLabel(s),
                selected: _sort == s,
                onTap: () => setState(() => _sort = s),
              ),
          ],
        ),
        const SizedBox(height: 12),

        ...sortedModels.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final m = entry.value;
          final isPositive = m.totalProfitCents >= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => widget.onModelTap(m),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank <= 3 ? AppTheme.primaryDark : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: rank <= 3 ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              m.soldCount == 1 ? '1 venda' : '${m.soldCount} vendas',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          if (m.inStockCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${m.inStockCount} no pátio',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCell(
                              'Lucro total',
                              '${isPositive ? "+" : "-"}${Formatters.formatCurrency(m.totalProfitCents.abs())}',
                              valueColor: isPositive
                                  ? AppTheme.successGreen
                                  : AppTheme.dangerRed,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricCell(
                              'Lucro médio',
                              '${m.avgProfitCents >= 0 ? "+" : "-"}${Formatters.formatCurrency(m.avgProfitCents.abs())}',
                              valueColor: m.avgProfitCents >= 0
                                  ? AppTheme.successGreen
                                  : AppTheme.dangerRed,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricCell(
                              'Giro médio',
                              _formatAvgDays(m.avgDaysToSell),
                              valueColor: AppTheme.primaryDark,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricCell(
                              'ROI',
                              m.roiPercent != null
                                  ? Formatters.formatPercent(m.roiPercent!)
                                  : '--',
                              valueColor: (m.roiPercent ?? 0) >= 0
                                  ? AppTheme.successGreen
                                  : AppTheme.dangerRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Gasto médio pós-compra: ${Formatters.formatCurrency(m.avgExpenseCents)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ver vendas >',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        if (report.brands.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Desempenho por Marca',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < report.brands.length; i++) ...[
                  if (i > 0) const Divider(height: 16, color: AppTheme.borderSubtle),
                  Builder(
                    builder: (_) {
                      final b = report.brands[i];
                      final pos = b.totalProfitCents >= 0;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.brand,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                                Text(
                                  '${b.soldCount} ${b.soldCount == 1 ? "venda" : "vendas"} • Giro médio ${_formatAvgDays(b.avgDaysToSell)}',
                                  style: const TextStyle(
                                    fontSize: 11,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: pos ? AppTheme.successGreen : AppTheme.dangerRed,
                                  fontFeatures: AppTheme.tabularNumbers,
                                ),
                              ),
                              if (b.roiPercent != null)
                                Text(
                                  'ROI ${Formatters.formatPercent(b.roiPercent!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: pos ? AppTheme.successGreen : AppTheme.dangerRed,
                                  ),
                                ),
                            ],
                          ),
                        ],
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
}
