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
import '../../widgets/responsive_layout.dart';
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTwoColumn =
                        constraints.maxWidth >= ResponsiveBreakpoints.detailTwoColumn;

                    if (isTwoColumn) {
                      return SingleChildScrollView(
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
                                      _buildHeaderCard(vehicle),
                                      const SizedBox(height: 14),
                                      _buildFinancialHeroCard(
                                        vehicle: vehicle,
                                        totalCost: totalCost,
                                        validExpensesTotal: validExpensesTotal,
                                        estimatedProfit: estimatedProfit,
                                        realizedProfit: realizedProfit,
                                      ),
                                      if (vehicle.isInStock ||
                                          (vehicle.activeSale != null &&
                                              vehicle.activeSale!.balanceDueCents > 0)) ...[
                                        const SizedBox(height: 14),
                                        _buildActionButtons(vehicle: vehicle, totalCost: totalCost),
                                      ],
                                      const SizedBox(height: 14),
                                      _buildDocsCard(vehicle),
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
                                        _buildSaleDetailsCard(vehicle: vehicle),
                                        const SizedBox(height: 14),
                                      ],
                                      _buildExpensesCard(
                                        vehicle: vehicle,
                                        expenses: vehicleExpenses,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
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

                              // 3. Ação Principal (Vender ou Receber)
                              if (vehicle.isInStock ||
                                  (vehicle.activeSale != null &&
                                      vehicle.activeSale!.balanceDueCents > 0)) ...[
                                _buildActionButtons(vehicle: vehicle, totalCost: totalCost),
                                const SizedBox(height: 14),
                              ],

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
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderCard(Vehicle vehicle) {
    final rawCreator = (vehicle.createdByEmail != null && vehicle.createdByEmail!.isNotEmpty)
        ? vehicle.createdByEmail!.split('@')[0]
        : null;
    final creatorName = rawCreator != null
        ? rawCreator[0].toUpperCase() + rawCreator.substring(1).toLowerCase()
        : null;

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
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                CarPlateWidget(plate: vehicle.plate, fontSize: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textMain),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (vehicle.manufactureYear != null || vehicle.modelYear != null)
                Text(
                  'Ano ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              if (creatorName != null) ...[
                if (vehicle.manufactureYear != null || vehicle.modelYear != null)
                  const Text(' • ', style: TextStyle(color: AppTheme.textLight)),
                const Icon(Icons.person, size: 14, color: AppTheme.accentBlue),
                Text(
                  'Por: $creatorName',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custos e Venda',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
          ),
          const SizedBox(height: 12),

          // Decomposição simplificada: Compra + Despesas = Custo Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                _buildMathRow('Compra', Formatters.formatCurrency(vehicle.purchasePriceCents)),
                const SizedBox(height: 8),
                _buildMathRow('+ Despesas', Formatters.formatCurrency(validExpensesTotal)),
                const Divider(height: 16, color: AppTheme.borderSubtle),
                _buildMathRow(
                  'Custo Total',
                  Formatters.formatCurrency(totalCost),
                  bold: true,
                  color: AppTheme.primaryDark,
                  fontSize: 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Se está em estoque: Preço Anunciado e Lucro Previsto
          if (vehicle.isInStock && vehicle.announcedPriceCents != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
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
                  ),
                  if (estimatedProfit != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          estimatedProfit < 0 ? 'Prejuízo Previsto' : 'Lucro Estimado',
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
          ] else if (vehicle.isSold && vehicle.activeSale != null) ...[
            // Se está vendido: Resultado Realizado e Lucro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (realizedProfit != null && realizedProfit < 0) ? AppTheme.dangerLight : AppTheme.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (realizedProfit != null && realizedProfit < 0) ? AppTheme.dangerBorder : AppTheme.successBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vendido Por', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.formatCurrency(vehicle.activeSale!.salePriceCents),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                        ),
                      ],
                    ),
                  ),
                  if (realizedProfit != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          realizedProfit < 0 ? 'Prejuízo Realizado' : 'Lucro Realizado',
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
                            fontSize: 18,
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
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

    if (vehicle.isInStock) {
      // Botão Verde Direto para Venda
      return ElevatedButton.icon(
        icon: const Icon(Icons.handshake, size: 22),
        label: const Text('Vender Veículo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          showAdaptiveModalSheet(
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
      );
    }

    if (sale != null && sale.balanceDueCents > 0) {
      // Botão de Receber Pagamento Pendente
      return ElevatedButton.icon(
        icon: const Icon(Icons.payments_outlined, size: 22),
        label: Text(
          'Receber Parcela (${Formatters.formatCurrency(sale.balanceDueCents)})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          showAdaptiveModalSheet(
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
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSaleDetailsCard({required Vehicle vehicle}) {
    final sale = vehicle.activeSale!;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Venda & Recebimentos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              StatusBadge.paymentStatus(sale.paymentStatus),
            ],
          ),
          const SizedBox(height: 12),

          // Resumo em 3 colunas compactas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Venda', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(sale.salePriceCents),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Recebido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(sale.totalReceivedCents),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.successGreen),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.borderSubtle),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Restante', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(sale.balanceDueCents),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: sale.balanceDueCents > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data: ${Formatters.formatDate(sale.saleDate)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Corrigir valor', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                onPressed: () {
                  showAdaptiveModalSheet(
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
          const Divider(height: 16, color: AppTheme.borderSubtle),

          // Entradas registradas
          const Text('Pagamentos:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          if (sale.payments.isEmpty) ...[
            const Text('Nenhum pagamento registrado.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ] else ...[
            ...sale.payments.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 16),
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
                        icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 16),
                        tooltip: 'Estornar valor',
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

          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 16),
              label: const Text('Cancelar venda e retornar ao estoque', style: TextStyle(color: AppTheme.dangerRed, fontSize: 12)),
              onPressed: () => _cancelSale(sale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesCard({required Vehicle vehicle, required List<Expense> expenses}) {
    final validCount = expenses.where((e) => e.isValid).length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Despesas ($validCount)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo Gasto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentSoft,
                  foregroundColor: AppTheme.accentBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  showAdaptiveModalSheet(
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
                'Nenhuma despesa lançada.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
          ] else ...[
            ...expenses.map((e) {
              final rawEmail = (e.createdByEmail != null && e.createdByEmail!.isNotEmpty)
                  ? e.createdByEmail!.split('@')[0]
                  : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            '${Formatters.formatDate(e.date)}${rawEmail != null ? " • Por: $rawEmail" : ""}',
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
                        icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 16),
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
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 16, color: AppTheme.primaryDark),
    );
  }

  Widget _buildDocsCard(Vehicle vehicle) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Documentos (CRLV-e)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                ),
              ),
              if (vehicle.docStatus == AppConstants.docStatusWithIssue) ...[
                const SizedBox(width: 8),
                StatusBadge.docStatus(vehicle.docStatus),
              ],
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
                'Observação: ${vehicle.docNotes}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _buildDocField('RENAVAM', vehicle.renavam ?? '-')),
              const SizedBox(width: 10),
              Expanded(child: _buildDocField('CRV', vehicle.crvNumber ?? '-')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDocField('Exercício CRLV', vehicle.licensingYear?.toString() ?? '-')),
              const SizedBox(width: 10),
              Expanded(child: _buildDocField('Data Compra', Formatters.formatDate(vehicle.purchaseDate))),
            ],
          ),
          if (vehicle.notes != null && vehicle.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Notas: ${vehicle.notes}', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildDocField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMain)),
        ],
      ),
    );
  }
}
