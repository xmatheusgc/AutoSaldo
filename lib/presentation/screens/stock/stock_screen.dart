import 'package:flutter/material.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

class StockScreen extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const StockScreen({
    super.key,
    required this.workspaceId,
    required this.userUid,
    required this.vehicleRepository,
    required this.expenseRepository,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _searchController = TextEditingController();
  String _filter = 'in_stock'; // 'all', 'in_stock', 'sold'
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: widget.vehicleRepository.getVehiclesStream(widget.workspaceId),
      builder: (context, vSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: widget.expenseRepository.getExpensesStream(widget.workspaceId),
          builder: (context, eSnapshot) {
            final allVehicles = vSnapshot.data ?? [];
            final allExpenses = eSnapshot.data ?? [];

            final inStockCount = allVehicles.where((v) => v.isInStock).length;
            final soldCount = allVehicles.where((v) => v.isSold).length;

            // Filtro de status
            var filtered = allVehicles;
            if (_filter == 'in_stock') {
              filtered = filtered.where((v) => v.isInStock).toList();
            } else if (_filter == 'sold') {
              filtered = filtered.where((v) => v.isSold).toList();
            }

            // Filtro de busca (placa, marca, modelo, renavam)
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase().trim();
              final qPlate = Formatters.normalizePlate(q);
              filtered = filtered.where((v) {
                final matchBrand = v.brand.toLowerCase().contains(q);
                final matchModel = v.model.toLowerCase().contains(q);
                final matchPlate = v.plate.contains(qPlate);
                final matchRenavam = v.renavam != null && v.renavam!.contains(q);
                return matchBrand || matchModel || matchPlate || matchRenavam;
              }).toList();
            }

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    // Barra de busca e filtros
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.white,
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por placa, marca, modelo ou RENAVAM...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // Segmented filter buttons
                          Row(
                            children: [
                              _buildFilterChip('in_stock', 'Em estoque ($inStockCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('sold', 'Vendidos ($soldCount)'),
                              const SizedBox(width: 8),
                              _buildFilterChip('all', 'Todos (${allVehicles.length})'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderSubtle),

                    // Lista de veículos
                    Expanded(
                      child: vSnapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final vehicle = filtered[index];
                                    final totalCost = FinancialCalculator.calculateVehicleTotalCost(vehicle, allExpenses);
                                    final estimatedProfit = FinancialCalculator.calculateEstimatedProfit(vehicle, allExpenses);
                                    final realizedProfit = FinancialCalculator.calculateRealizedProfit(vehicle, allExpenses);

                                    return _buildVehicleCard(
                                      vehicle: vehicle,
                                      totalCost: totalCost,
                                      estimatedProfit: estimatedProfit,
                                      realizedProfit: realizedProfit,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar veículo', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  final newVehicleId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => VehicleFormScreen(
                        workspaceId: widget.workspaceId,
                        userUid: widget.userUid,
                        vehicleRepository: widget.vehicleRepository,
                      ),
                    ),
                  );

                  if (!context.mounted) return;

                  if (newVehicleId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VehicleDetailScreen(
                          workspaceId: widget.workspaceId,
                          vehicleId: newVehicleId,
                          userUid: widget.userUid,
                          vehicleRepository: widget.vehicleRepository,
                          expenseRepository: widget.expenseRepository,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _filter = filterKey;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryDark : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryDark : AppTheme.borderSubtle,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Icon(Icons.directions_car_outlined, size: 48, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum veículo encontrado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum resultado corresponde à sua busca "$_searchQuery".'
                  : 'Nenhum veículo cadastrado neste filtro.',
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard({
    required Vehicle vehicle,
    required int totalCost,
    required int? estimatedProfit,
    required int? realizedProfit,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailScreen(
              workspaceId: widget.workspaceId,
              vehicleId: vehicle.id,
              userUid: widget.userUid,
              vehicleRepository: widget.vehicleRepository,
              expenseRepository: widget.expenseRepository,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha Superior: Placa + Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vehicle.formattedPlate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      StatusBadge.stockStatus(vehicle.isInStock),
                      const SizedBox(width: 6),
                      StatusBadge.docStatus(vehicle.docStatus),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Título do veículo
              Text(
                vehicle.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              if (vehicle.manufactureYear != null || vehicle.modelYear != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Ano: ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
              const Divider(height: 20),

              // Resumo Financeiro
              if (vehicle.isInStock) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total investido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Text(
                          Formatters.formatCurrency(totalCost),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                        ),
                      ],
                    ),
                    if (vehicle.announcedPriceCents != null && estimatedProfit != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            estimatedProfit < 0 ? 'Prejuízo estimado' : 'Lucro estimado',
                            style: TextStyle(
                              fontSize: 11,
                              color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(estimatedProfit.abs()),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ] else if (vehicle.activeSale != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Venda', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Text(
                          Formatters.formatCurrency(vehicle.activeSale!.salePriceCents),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                        ),
                      ],
                    ),
                    if (realizedProfit != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            realizedProfit < 0 ? 'Prejuízo' : 'Lucro',
                            style: TextStyle(
                              fontSize: 11,
                              color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(realizedProfit.abs()),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Saldo a receber', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Formatters.formatCurrency(vehicle.activeSale!.balanceDueCents),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: vehicle.activeSale!.balanceDueCents > 0
                                    ? AppTheme.warningOrange
                                    : AppTheme.successGreen,
                              ),
                            ),
                            const SizedBox(width: 4),
                            StatusBadge.paymentStatus(vehicle.activeSale!.paymentStatus),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
