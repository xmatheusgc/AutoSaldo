import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/active_sale.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
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
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const VehicleDetailScreen({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.userUid,
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
        title: const Text('Estornar Despesa'),
        content: Text(
          'Deseja estornar a despesa de ${Formatters.formatCurrency(expense.amountCents)} (${expense.categoryLabel})? Esta ação abaterá o valor do custo do veículo e do fluxo de caixa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Estornar Despesa'),
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
            const SnackBar(content: Text('Despesa estornada com sucesso!')),
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
        title: const Text('Estornar Recebimento'),
        content: Text(
          'Deseja estornar o recebimento de ${Formatters.formatCurrency(payment.amountCents)} de ${Formatters.formatDate(payment.date)}? O saldo a receber do veículo será restabelecido.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Estornar Entrada'),
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
            SnackBar(content: Text('Erro ao estornar recebimento: $e'), backgroundColor: AppTheme.dangerRed),
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
          title: const Text('Ação Bloqueada'),
          content: const Text(
            'Para cancelar uma venda e retornar o veículo ao estoque, todos os recebimentos ativos devem ser estornados previamente.',
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
          'Tem certeza que deseja cancelar esta venda? O histórico será preservado e o veículo retornará para o status "Em estoque".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Retornar ao Estoque'),
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
            const SnackBar(content: Text('Venda cancelada. Veículo de volta ao estoque.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao cancelar venda: $e'), backgroundColor: AppTheme.dangerRed),
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
                title: Text('${vehicle.brand} ${vehicle.model}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar Cadastro',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VehicleFormScreen(
                            workspaceId: widget.workspaceId,
                            userUid: widget.userUid,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Card de Identificação Rápida e Placa
                          _buildHeaderCard(vehicle),
                          const SizedBox(height: 14),

                          // 2. Resumo Financeiro
                          _buildFinancialSummaryCard(
                            vehicle: vehicle,
                            totalCost: totalCost,
                            validExpensesTotal: validExpensesTotal,
                            estimatedProfit: estimatedProfit,
                            realizedProfit: realizedProfit,
                          ),
                          const SizedBox(height: 14),

                          // 3. Documentação CRLV-e
                          _buildDocsCard(vehicle),
                          const SizedBox(height: 14),

                          // 4. Seção Venda e Recebimentos
                          _buildSaleSection(vehicle: vehicle, totalCost: totalCost),
                          const SizedBox(height: 14),

                          // 5. Seção Despesas
                          _buildExpensesSection(vehicle: vehicle, expenses: vehicleExpenses),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                vehicle.formattedPlate,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge.stockStatus(vehicle.isInStock),
                      const SizedBox(width: 8),
                      StatusBadge.docStatus(vehicle.docStatus),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard({
    required Vehicle vehicle,
    required int totalCost,
    required int validExpensesTotal,
    required int? estimatedProfit,
    required int? realizedProfit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo Financeiro do Veículo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 14),

            _rowInfo('Valor pago na compra:', Formatters.formatCurrency(vehicle.purchasePriceCents)),
            _rowInfo('Despesas adicionais pagas:', Formatters.formatCurrency(validExpensesTotal)),
            const Divider(height: 20),
            _rowInfo(
              'Custo Total Investido:',
              Formatters.formatCurrency(totalCost),
              bold: true,
              valueColor: AppTheme.primaryDark,
            ),

            if (vehicle.isInStock) ...[
              if (vehicle.announcedPriceCents != null) ...[
                const SizedBox(height: 10),
                _rowInfo('Preço anunciado:', Formatters.formatCurrency(vehicle.announcedPriceCents!)),
                if (estimatedProfit != null)
                  _rowInfo(
                    estimatedProfit < 0 ? 'Prejuízo estimado:' : 'Lucro estimado:',
                    '${estimatedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(estimatedProfit.abs())}',
                    bold: true,
                    valueColor: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                  ),
              ],
            ] else if (vehicle.activeSale != null) ...[
              const Divider(height: 20),
              _rowInfo('Valor negociado na venda:', Formatters.formatCurrency(vehicle.activeSale!.salePriceCents), bold: true),
              if (realizedProfit != null)
                _rowInfo(
                  realizedProfit < 0 ? 'Prejuízo realizado:' : 'Lucro realizado:',
                  '${realizedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(realizedProfit.abs())}',
                  bold: true,
                  valueColor: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                ),
              _rowInfo('Total já recebido:', Formatters.formatCurrency(vehicle.activeSale!.totalReceivedCents), valueColor: AppTheme.accentBlue),
              _rowInfo(
                'Saldo a receber hoje:',
                Formatters.formatCurrency(vehicle.activeSale!.balanceDueCents),
                bold: true,
                valueColor: vehicle.activeSale!.balanceDueCents > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocsCard(Vehicle vehicle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Documentação (CRLV-e)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
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
                  'Pendência: ${vehicle.docNotes}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _rowInfo('Código RENAVAM:', vehicle.renavam ?? 'Não informado'),
            _rowInfo('Exercício CRLV:', vehicle.licensingYear?.toString() ?? 'Não informado'),
            _rowInfo('Ano Fabricação / Modelo:', '${vehicle.manufactureYear ?? "-"} / ${vehicle.modelYear ?? "-"}'),
            _rowInfo('Número do CRV:', vehicle.crvNumber ?? 'Não informado'),
            _rowInfo('Data da Compra:', Formatters.formatDate(vehicle.purchaseDate)),
            if (vehicle.notes != null && vehicle.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _rowInfo('Observações gerais:', vehicle.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaleSection({required Vehicle vehicle, required int totalCost}) {
    final sale = vehicle.activeSale;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Venda e Recebimentos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                ),
                if (sale != null) StatusBadge.paymentStatus(sale.paymentStatus),
              ],
            ),
            const SizedBox(height: 14),

            if (vehicle.isInStock) ...[
              const Text(
                'Veículo disponível em estoque. Ao concretizar a negociação, registre a venda para iniciar o ciclo de recebimentos.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.monetization_on_outlined, size: 20),
                label: const Text('Registrar Venda'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => SaleFormDialog(
                      workspaceId: widget.workspaceId,
                      vehicle: vehicle,
                      totalCostCents: totalCost,
                      userUid: widget.userUid,
                      vehicleRepository: widget.vehicleRepository,
                    ),
                  );
                },
              ),
            ] else if (sale != null) ...[
              // Informações da venda ativa
              _rowInfo('Data da venda:', Formatters.formatDate(sale.saleDate)),
              _rowInfo('Valor negociado:', Formatters.formatCurrency(sale.salePriceCents), bold: true),
              const SizedBox(height: 8),

              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Corrigir valor'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(140, 38)),
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
                  const SizedBox(width: 10),
                  if (sale.balanceDueCents > 0) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Receber entrada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        minimumSize: const Size(150, 38),
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
                ],
              ),
              const Divider(height: 24),

              // Lista de recebimentos registrados
              const Text(
                'Entradas Registradas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMain),
              ),
              const SizedBox(height: 8),

              if (sale.payments.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum recebimento registrado ainda.', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                ),
              ] else ...[
                ...sale.payments.map((p) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.isValid ? AppTheme.bgSurface : AppTheme.dangerLight.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formatters.formatCurrency(p.amountCents),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: p.isValid ? null : TextDecoration.lineThrough,
                                color: p.isValid ? AppTheme.textMain : AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              'Data: ${Formatters.formatDate(p.date)}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        if (p.isValid) ...[
                          IconButton(
                            icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 20),
                            tooltip: 'Estornar entrada',
                            onPressed: () => _revertPayment(p),
                          ),
                        ] else ...[
                          const Text('Estornado', style: TextStyle(color: AppTheme.dangerRed, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 18),
                  label: const Text('Cancelar venda e retornar ao estoque', style: TextStyle(color: AppTheme.dangerRed, fontSize: 13)),
                  onPressed: () => _cancelSale(sale),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesSection({required Vehicle vehicle, required List<Expense> expenses}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Despesas do Veículo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Lançar despesa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    minimumSize: const Size(140, 36),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => ExpenseFormDialog(
                        workspaceId: widget.workspaceId,
                        vehicleId: vehicle.id,
                        userUid: widget.userUid,
                        expenseRepository: widget.expenseRepository,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (expenses.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhuma despesa adicional registrada para este veículo. A compra já compõe o custo inicial.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ] else ...[
              ...expenses.map((e) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.isValid ? AppTheme.bgSurface : AppTheme.dangerLight.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  e.categoryLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: e.isValid ? AppTheme.textMain : AppTheme.textMuted,
                                    decoration: e.isValid ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Formatters.formatDate(e.date),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            if (e.description != null && e.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                e.description!,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            Formatters.formatCurrency(e.amountCents),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: e.isValid ? AppTheme.dangerRed : AppTheme.textMuted,
                              decoration: e.isValid ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          if (e.isValid) ...[
                            IconButton(
                              icon: const Icon(Icons.undo, color: AppTheme.warningOrange, size: 18),
                              tooltip: 'Estornar despesa',
                              onPressed: () => _revertExpense(e),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            const Text('Estornada', style: TextStyle(color: AppTheme.dangerRed, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rowInfo(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
