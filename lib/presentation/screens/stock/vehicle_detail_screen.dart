import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/status_badge.dart';
import '../expenses/expense_form_dialog.dart';
import '../sales/payment_form_dialog.dart';
import '../sales/sale_form_dialog.dart';
import '../sales/update_sale_price_dialog.dart';
import 'vehicle_form_screen.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const VehicleDetailScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.userUid,
    this.userEmail,
    required this.vehicleRepository,
    required this.expenseRepository,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Future<void> _revertExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar Gasto'),
        content: Text(
          'Deseja estornar o gasto de ${Formatters.formatCurrency(expense.amountCents)} (${expense.categoryLabel})? O valor será removido do custo do carro e do caixa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.expenseRepository.revertExpense(
          widget.workspaceId,
          expense.id,
          widget.userUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto estornado com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao estornar: $e'), backgroundColor: AppTheme.dangerRed),
          );
        }
      }
    }
  }

  Future<void> _revertPayment(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar Pagamento'),
        content: Text(
          'Deseja estornar o recebimento de ${Formatters.formatCurrency(payment.amountCents)}? O valor voltará a constar como saldo a receber.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.vehicleRepository.revertPayment(
          workspaceId: widget.workspaceId,
          vehicleId: widget.vehicleId,
          paymentId: payment.id,
          userUid: widget.userUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recebimento estornado com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.dangerRed),
          );
        }
      }
    }
  }

  Future<void> _cancelSale(ActiveSale sale) async {
    if (sale.hasValidPayments) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recebimentos Pendentes'),
          content: const Text(
            'Para cancelar uma venda e retornar o carro ao estoque, todos os pagamentos recebidos devem ser estornados antes.',
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Entendi')),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Venda'),
        content: const Text(
          'Deseja cancelar esta venda e retornar o veículo para o estoque? O histórico da venda será preservado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Cancelar e Voltar ao Estoque'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.vehicleRepository.cancelSale(
          workspaceId: widget.workspaceId,
          vehicleId: widget.vehicleId,
          userUid: widget.userUid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venda cancelada! Veículo de volta ao estoque.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar: $e'), backgroundColor: AppTheme.dangerRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: widget.vehicleRepository.getVehiclesStream(widget.workspaceId),
      builder: (context, vSnapshot) {
        final vehicles = vSnapshot.data ?? [];
        final vehicle = vehicles.cast<Vehicle?>().firstWhere(
              (v) => v?.id == widget.vehicleId,
              orElse: () => null,
            );

        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ficha do Veículo')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<List<Expense>>(
          stream: widget.expenseRepository.getExpensesStream(widget.workspaceId),
          builder: (context, eSnapshot) {
            final allExpenses = eSnapshot.data ?? [];
            final vehicleExpenses = allExpenses.where((e) => e.vehicleId == vehicle.id).toList();

            final totalCost = FinancialCalculator.calculateVehicleTotalCost(vehicle, allExpenses);
            final validExpensesTotal = totalCost - vehicle.purchasePriceCents;
            final estimatedProfit = FinancialCalculator.calculateEstimatedProfit(vehicle, allExpenses);
            final realizedProfit = FinancialCalculator.calculateRealizedProfit(vehicle, allExpenses);

            return Scaffold(
              appBar: AppBar(
                title: Text(vehicle.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_note, size: 26),
                    tooltip: 'Editar Cadastro',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleFormScreen(
                            workspaceId: widget.workspaceId,
                            userUid: widget.userUid,
                            userEmail: widget.userEmail,
                            vehicleRepository: widget.vehicleRepository,
                            vehicleToEdit: vehicle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Cabeçalho de Identificação com Placa Real
                          _buildHeaderCard(vehicle),
                          const SizedBox(height: 14),

                          // 2. Card de Matemática Financeira
                          _buildFinancialHeroCard(
                            vehicle: vehicle,
                            totalCost: totalCost,
                            validExpensesTotal: validExpensesTotal,
                            estimatedProfit: estimatedProfit,
                            realizedProfit: realizedProfit,
                          ),
                          const SizedBox(height: 14),

                          // 3. Ações Rápidas (Registrar Venda / Recebimento / Despesa)
                          _buildActionButtons(vehicle: vehicle, totalCost: totalCost),
                          const SizedBox(height: 14),

                          // 4. Seção Venda e Recebimentos (Se vendido)
                          if (vehicle.isSold && vehicle.activeSale != null) ...[
                            _buildSaleDetailsCard(vehicle: vehicle),
                            const SizedBox(height: 14),
                          ],

                          // 5. Seção de Despesas / Gastos Realizados
                          _buildExpensesCard(vehicle: vehicle, expenses: vehicleExpenses),
                          const SizedBox(height: 14),

                          // 6. Dados de Documentação (CRLV-e)
                          _buildDocsCard(vehicle),
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

  Widget _buildHeaderCard(Vehicle vehicle) {
    return Container(
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
              CarPlateWidget(plate: vehicle.plate, fontSize: 16),
              const Spacer(),
              StatusBadge.stockStatus(vehicle.isInStock),
              const SizedBox(width: 6),
              StatusBadge.docStatus(vehicle.docStatus),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vehicle.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textMain),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (vehicle.manufactureYear != null || vehicle.modelYear != null) ...[
                Text(
                  'Ano ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
                const Text(' • ', style: TextStyle(color: AppTheme.textLight)),
              ],
              const Icon(Icons.person, size: 14, color: AppTheme.accentBlue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  vehicle.createdByEmail != null && vehicle.createdByEmail!.isNotEmpty
                      ? 'Cadastrado por: ${vehicle.createdByEmail}'
                      : 'Cadastrado no estoque',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialHeroCard({
    required Vehicle vehicle,
    required int totalCost,
    required int validExpensesTotal,
    required int? estimatedProfit,
    required int? realizedProfit,
  }) {
    return Container(
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
            'Matemática do Veículo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
          ),
          const SizedBox(height: 14),

          // Decomposição: Compra + Gastos = Custo Total
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                _buildMathRow('Valor pago na compra', Formatters.formatCurrency(vehicle.purchasePriceCents)),
                const SizedBox(height: 8),
                _buildMathRow('+ Gastos realizados (mecânica, peças...)', Formatters.formatCurrency(validExpensesTotal)),
                const Divider(height: 18, color: AppTheme.borderSubtle),
                _buildMathRow(
                  '= CUSTO TOTAL INVESTIDO',
                  Formatters.formatCurrency(totalCost),
                  bold: true,
                  color: AppTheme.primaryDark,
                  fontSize: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Se está em estoque: Preço Anunciado e Lucro Previsto
          if (vehicle.isInStock) ...[
            if (vehicle.announcedPriceCents != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Preço Anunciado', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.formatCurrency(vehicle.announcedPriceCents!),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
                        ),
                      ],
                    ),
                    if (estimatedProfit != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            estimatedProfit < 0 ? 'Prejuízo Previsto' : 'Lucro Previsto',
                            style: TextStyle(
                              fontSize: 12,
                              color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${estimatedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(estimatedProfit.abs())}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ] else if (vehicle.activeSale != null) ...[
            // Se está vendido: Resultado Realizado e Saldo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (realizedProfit != null && realizedProfit < 0) ? AppTheme.dangerLight : AppTheme.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (realizedProfit != null && realizedProfit < 0) ? AppTheme.dangerBorder : AppTheme.successBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vendido Por', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(vehicle.activeSale!.salePriceCents),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                  if (realizedProfit != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          realizedProfit < 0 ? 'Prejuízo Real' : 'Lucro no Bolso',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${realizedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(realizedProfit.abs())}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMathRow(String label, String value, {bool bold = false, Color? color, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? AppTheme.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: color ?? AppTheme.textMain,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons({required Vehicle vehicle, required int totalCost}) {
    final sale = vehicle.activeSale;

    return Column(
      children: [
        if (vehicle.isInStock) ...[
          // Botão Verde Grande para Vender
          ElevatedButton.icon(
            icon: const Icon(Icons.handshake, size: 22),
            label: const Text('Registrar Venda deste Veículo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SaleFormDialog(
                  workspaceId: widget.workspaceId,
                  vehicle: vehicle,
                  totalCostCents: totalCost,
                  userUid: widget.userUid,
                  userEmail: widget.userEmail,
                  vehicleRepository: widget.vehicleRepository,
                ),
              );
            },
          ),
        ] else if (sale != null && sale.balanceDueCents > 0) ...[
          // Botão de Receber Pagamento Pendente
          ElevatedButton.icon(
            icon: const Icon(Icons.payments_outlined, size: 22),
            label: Text('Receber Pagamento (${Formatters.formatCurrency(sale.balanceDueCents)})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PaymentFormDialog(
                  workspaceId: widget.workspaceId,
                  vehicleId: vehicle.id,
                  activeSale: sale,
                  userUid: widget.userUid,
                  vehicleRepository: widget.vehicleRepository,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 10),

        // Botão para Lançar Despesa (Disponível em estoque ou após a venda)
        OutlinedButton.icon(
          icon: const Icon(Icons.build_circle_outlined, size: 20, color: AppTheme.primaryDark),
          label: const Text('Lançar Gasto com este Veículo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => ExpenseFormDialog(
                workspaceId: widget.workspaceId,
                vehicleId: vehicle.id,
                userUid: widget.userUid,
                userEmail: widget.userEmail,
                expenseRepository: widget.expenseRepository,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSaleDetailsCard({required Vehicle vehicle}) {
    final sale = vehicle.activeSale!;

    return Container(
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
              const Text(
                'Detalhes da Venda',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              StatusBadge.paymentStatus(sale.paymentStatus),
            ],
          ),
          const SizedBox(height: 14),

          _buildMathRow('Data da venda:', Formatters.formatDate(sale.saleDate)),
          const SizedBox(height: 6),
          _buildMathRow('Valor negociado:', Formatters.formatCurrency(sale.salePriceCents), bold: true),
          const SizedBox(height: 6),
          _buildMathRow('Total já recebido:', Formatters.formatCurrency(sale.totalReceivedCents), color: AppTheme.successGreen, bold: true),
          const SizedBox(height: 6),
          _buildMathRow(
            'Saldo restante a receber:',
            Formatters.formatCurrency(sale.balanceDueCents),
            color: sale.balanceDueCents > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
            bold: true,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 15),
                label: const Text('Corrigir valor', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(minimumSize: const Size(130, 36)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => UpdateSalePriceDialog(
                      workspaceId: widget.workspaceId,
                      vehicleId: vehicle.id,
                      activeSale: sale,
                      userUid: widget.userUid,
                      vehicleRepository: widget.vehicleRepository,
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.borderSubtle),

          // Entradas registradas
          const Text('Pagamentos Recebidos:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          if (sale.payments.isEmpty) ...[
            const Text('Nenhum pagamento registrado.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ] else ...[
            ...sale.payments.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${Formatters.formatDate(p.date)}: ${Formatters.formatCurrency(p.amountCents)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration: p.isValid ? null : TextDecoration.lineThrough,
                          color: p.isValid ? AppTheme.textMain : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (p.isValid) ...[
                      IconButton(
                        icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 18),
                        tooltip: 'Estornar este valor',
                        onPressed: () => _revertPayment(p),
                      ),
                    ] else ...[
                      const Text('Estornado', style: TextStyle(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 14),
          TextButton.icon(
            icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 18),
            label: const Text('Cancelar venda e retornar ao estoque', style: TextStyle(color: AppTheme.dangerRed, fontSize: 13)),
            onPressed: () => _cancelSale(sale),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesCard({required Vehicle vehicle, required List<Expense> expenses}) {
    return Container(
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
              const Text(
                'Gastos com o Carro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.accentBlue, size: 24),
                tooltip: 'Lançar gasto',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ExpenseFormDialog(
                      workspaceId: widget.workspaceId,
                      vehicleId: vehicle.id,
                      userUid: widget.userUid,
                      userEmail: widget.userEmail,
                      expenseRepository: widget.expenseRepository,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (expenses.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum gasto extra lançado para este veículo. Apenas o valor da compra.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          ] else ...[
            ...expenses.map((e) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: e.isValid ? const Color(0xFFF8FAFC) : AppTheme.dangerLight.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              decoration: e.isValid ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          if (e.description != null && e.description!.isNotEmpty) ...[
                            Text(e.description!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                          Text(
                            'Data: ${Formatters.formatDate(e.date)}${e.createdByEmail != null ? " • por ${e.createdByEmail}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(e.amountCents),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: e.isValid ? AppTheme.dangerRed : AppTheme.textMuted,
                        decoration: e.isValid ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    if (e.isValid) ...[
                      IconButton(
                        icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 18),
                        tooltip: 'Estornar gasto',
                        onPressed: () => _revertExpense(e),
                      ),
                    ],
                  ],
                ),
              );
            }),
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

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 18, color: AppTheme.primaryDark),
    );
  }

  Widget _buildDocsCard(Vehicle vehicle) {
    return Container(
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
              const Text(
                'Documentação (CRLV-e)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              StatusBadge.docStatus(vehicle.docStatus),
            ],
          ),
          const SizedBox(height: 12),
          if (vehicle.docNotes != null && vehicle.docNotes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Observação da pendência: ${vehicle.docNotes}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildMathRow('Código RENAVAM:', vehicle.renavam ?? 'Não informado'),
          const SizedBox(height: 6),
          _buildMathRow('Exercício CRLV:', vehicle.licensingYear?.toString() ?? 'Não informado'),
          const SizedBox(height: 6),
          _buildMathRow('Número do CRV:', vehicle.crvNumber ?? 'Não informado'),
          const SizedBox(height: 6),
          _buildMathRow('Data da Compra:', Formatters.formatDate(vehicle.purchaseDate)),
          if (vehicle.notes != null && vehicle.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Notas: ${vehicle.notes}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }
}
