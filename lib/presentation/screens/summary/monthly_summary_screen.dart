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

            final isNetPositive = summary.monthNetCashCents >= 0;
            final isProfitPositive = summary.soldVehiclesProfitCents >= 0;

            return Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Seletor de Mês e Ano Estilo iOS
                          Container(
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
                          ),
                          const SizedBox(height: 14),

                          // 2. Card de Destaque: Lucro das Vendas do Mês
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isProfitPositive ? AppTheme.successBorder : AppTheme.dangerBorder,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed).withAlpha(12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isProfitPositive ? AppTheme.successLight : AppTheme.dangerLight,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isProfitPositive ? Icons.trending_up : Icons.trending_down,
                                            color: isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Lucro das Vendas do Mês',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textMain,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        summary.soldCount == 1 ? '1 venda' : '${summary.soldCount} vendas',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '${isProfitPositive ? "+" : "-"}${Formatters.formatCurrency(summary.soldVehiclesProfitCents.abs())}',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: isProfitPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Valor final das vendas menos o custo total investido nos carros.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Card Movimentação de Caixa (Entradas vs Saídas) sem NENHUM overflow
                          Container(
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

                                // Linha de Entradas
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
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
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
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.successGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Linha de Saídas (Evitando overflow de texto)
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
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMain),
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
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.dangerRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 26, color: AppTheme.borderSubtle),

                                // Saldo do Caixa
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Sobrou no período:',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    Text(
                                      '${isNetPositive ? "+" : "-"}${Formatters.formatCurrency(summary.monthNetCashCents.abs())}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: isNetPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Posição Atual (Hoje)
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

                          Row(
                            children: [
                              // Investido em estoque
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.borderSubtle),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.directions_car_filled, size: 18, color: AppTheme.accentBlue),
                                          SizedBox(width: 6),
                                          Text(
                                            'No Pátio',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        Formatters.formatCurrency(summary.currentStockInvestmentCents),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${summary.stockCount} carros em estoque',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // A receber
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.borderSubtle),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.hourglass_bottom, size: 18, color: AppTheme.warningOrange),
                                          SizedBox(width: 6),
                                          Text(
                                            'A Receber',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        Formatters.formatCurrency(summary.toReceiveTodayCents),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: summary.toReceiveTodayCents > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Vendas em aberto',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 5. Card de Exportação CSV
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.table_view_outlined, color: AppTheme.primaryDark, size: 24),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Extrato para Planilha',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                                      ),
                                      Text(
                                        'Exportar veículos e caixa em CSV',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Exportar', style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    minimumSize: const Size(110, 42),
                                  ),
                                  onPressed: () => _exportCsv(vehicles, expenses),
                                ),
                              ],
                            ),
                          ),
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
}
