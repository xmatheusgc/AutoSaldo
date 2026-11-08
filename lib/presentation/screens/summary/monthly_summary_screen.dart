import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/csv_exporter.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import 'csv_download_helper.dart';

class MonthlySummaryScreen extends StatefulWidget {
  final String workspaceId;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const MonthlySummaryScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleRepository,
    required this.expenseRepository,
  });

  @override
  State<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends State<MonthlySummaryScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
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
          content: Text('Erro ao exportar CSV: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: widget.vehicleRepository.getVehiclesStream(widget.workspaceId),
      builder: (context, vSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: widget.expenseRepository.getExpensesStream(widget.workspaceId),
          builder: (context, eSnapshot) {
            final vehicles = vSnapshot.data ?? [];
            final expenses = eSnapshot.data ?? [];

            final summary = FinancialCalculator.calculateMonthlySummary(
              allVehicles: vehicles,
              allExpenses: expenses,
              year: _selectedYear,
              month: _selectedMonth,
            );

            return Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Seletor de Mês e Ano
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 28),
                                    onPressed: _previousMonth,
                                    tooltip: 'Mês anterior',
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        Formatters.monthName(_selectedMonth).toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
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
                                    icon: const Icon(Icons.chevron_right, size: 28),
                                    onPressed: _nextMonth,
                                    tooltip: 'Próximo mês',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 1. Lucro dos carros vendidos no mês
                          _buildIndicatorCard(
                            title: 'Lucro dos carros vendidos no mês',
                            subtitle: summary.soldCount == 1
                                ? '1 veículo vendido em ${Formatters.monthName(_selectedMonth)}'
                                : '${summary.soldCount} veículos vendidos em ${Formatters.monthName(_selectedMonth)}',
                            amountCents: summary.soldVehiclesProfitCents,
                            isProfitOrLoss: true,
                            icon: Icons.trending_up,
                            helpText:
                                'Soma o lucro pela data da venda, considerando inclusive despesas válidas lançadas posteriormente para os mesmos veículos.',
                          ),
                          const SizedBox(height: 12),

                          // 2. Movimento de Caixa do Mês (Entradas, Saídas e Saldo)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Movimentação de Caixa do Mês',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Movimento real de dinheiro no período (sem pressupor saldo inicial).',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 16),

                                  // Entradas
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.arrow_downward, color: AppTheme.successGreen, size: 18),
                                          SizedBox(width: 8),
                                          Text('Entradas no mês:', style: TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                      Text(
                                        '+ ${Formatters.formatCurrency(summary.monthIncomeCents)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Saídas
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.arrow_upward, color: AppTheme.dangerRed, size: 18),
                                          SizedBox(width: 8),
                                          Text('Saídas no mês (compras + despesas):', style: TextStyle(fontSize: 14)),
                                        ],
                                      ),
                                      Text(
                                        '- ${Formatters.formatCurrency(summary.monthExpensesCents)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.dangerRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // Saldo do Mês
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Saldo do mês:',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textMain,
                                        ),
                                      ),
                                      Text(
                                        '${summary.monthNetCashCents < 0 ? "-" : "+"}${Formatters.formatCurrency(summary.monthNetCashCents.abs())}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: summary.monthNetCashCents < 0
                                              ? AppTheme.dangerRed
                                              : AppTheme.successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. Indicadores Globais Atuais (Estoque e A Receber)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Posição Financeira Atual',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Indicadores consolidados de hoje, independente do mês filtrado.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Investido no estoque atual',
                                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                          Text(
                                            Formatters.formatCurrency(summary.currentStockInvestmentCents),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryDark,
                                            ),
                                          ),
                                          Text(
                                            '${summary.stockCount} carros em estoque',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'A receber hoje',
                                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                          Text(
                                            Formatters.formatCurrency(summary.toReceiveTodayCents),
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: summary.toReceiveTodayCents > 0
                                                  ? AppTheme.warningOrange
                                                  : AppTheme.successGreen,
                                            ),
                                          ),
                                          const Text(
                                            'Vendas em aberto/parciais',
                                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Card de Exportação para Planilha (CSV)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.table_chart_outlined, color: AppTheme.successGreen, size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Extrato para Planilha (CSV)',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textMain,
                                              ),
                                            ),
                                            Text(
                                              'Formato UTF-8 com separador ponto-e-vírgula (;)',
                                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Gera um arquivo de planilha compatível com Microsoft Excel, LibreOffice e Google Sheets contendo o extrato consolidado de veículos, despesas e recebimentos.',
                                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),

                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('Baixar Extrato CSV'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryDark,
                                    ),
                                    onPressed: () => _exportCsv(vehicles, expenses),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
  }

  Widget _buildIndicatorCard({
    required String title,
    required String subtitle,
    required int amountCents,
    required bool isProfitOrLoss,
    required IconData icon,
    required String helpText,
  }) {
    final isLoss = isProfitOrLoss && amountCents < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
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
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: isLoss ? AppTheme.dangerRed : AppTheme.successGreen, size: 24),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              '${isLoss ? "-" : (amountCents > 0 ? "+" : "")}${Formatters.formatCurrency(amountCents.abs())}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isLoss
                    ? AppTheme.dangerRed
                    : (amountCents > 0 ? AppTheme.successGreen : AppTheme.textMain),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              helpText,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

