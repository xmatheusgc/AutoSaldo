import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/status_badge.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

class StockScreen extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;

  const StockScreen({
    super.key,
    required this.workspaceId,
    required this.userUid,
    this.userEmail,
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
              backgroundColor: AppTheme.bgSurface,
              body: Column(
                children: [
                  // Barra de busca e filtros de topo estilo App
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Título do Estoque
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Estoque',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '$inStockCount ${inStockCount == 1 ? "veículo ativo" : "veículos ativos"}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Campo de Busca
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por placa, modelo ou marca...',
                            prefixIcon: const Icon(Icons.search, size: 22, color: AppTheme.textMuted),
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
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Filtros de seleção rápida estilo iOS Segmented Control
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildFilterTab('in_stock', 'Em estoque', inStockCount),
                              _buildFilterTab('sold', 'Vendidos', soldCount),
                              _buildFilterTab('all', 'Todos', allVehicles.length),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                    // Lista de veículos
                    Expanded(
                      child: vSnapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
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
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                elevation: 3,
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text(
                  'Cadastrar veículo',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                onPressed: () async {
                  final newVehicleId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => VehicleFormScreen(
                        workspaceId: widget.workspaceId,
                        userUid: widget.userUid,
                        userEmail: widget.userEmail,
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
                          userEmail: widget.userEmail,
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

  Widget _buildFilterTab(String filterKey, String title, int count) {
    final isSelected = _filter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filter = filterKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$title ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppTheme.primaryDark : AppTheme.textMuted,
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
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined, size: 52, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum veículo encontrado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum resultado para "$_searchQuery".'
                  : 'Nenhum carro nesta categoria no momento.',
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VehicleDetailScreen(
                  workspaceId: widget.workspaceId,
                  vehicleId: vehicle.id,
                  userUid: widget.userUid,
                  userEmail: widget.userEmail,
                  vehicleRepository: widget.vehicleRepository,
                  expenseRepository: widget.expenseRepository,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Real Car Plate + Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CarPlateWidget(plate: vehicle.plate, fontSize: 14),
                    const Spacer(),
                    StatusBadge.stockStatus(vehicle.isInStock),
                    if (vehicle.docStatus == AppConstants.docStatusWithIssue) ...[
                      const SizedBox(width: 6),
                      StatusBadge.docStatus(vehicle.docStatus),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Title and Version
                Text(
                  vehicle.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Years + User who registered
                Row(
                  children: [
                    if (vehicle.manufactureYear != null || vehicle.modelYear != null) ...[
                      Text(
                        'Ano: ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      ),
                      const Text(' • ', style: TextStyle(color: AppTheme.textLight)),
                    ],
                    const Icon(Icons.person_outline, size: 13, color: AppTheme.textLight),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        vehicle.createdByEmail != null && vehicle.createdByEmail!.isNotEmpty
                            ? vehicle.createdByEmail!
                            : 'Cadastrado',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Financial Summary Cards
                if (vehicle.isInStock) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Investido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatCurrency(totalCost),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
                            ),
                          ],
                        ),
                        if (vehicle.announcedPriceCents != null && estimatedProfit != null) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                estimatedProfit < 0 ? 'Prejuízo Previsto' : 'Lucro Previsto',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${estimatedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(estimatedProfit.abs())}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else if (vehicle.activeSale != null) ...[
                  // Sold vehicle: 3 clear boxes
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Venda Final', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.formatCurrency(vehicle.activeSale!.salePriceCents),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
                                ),
                              ],
                            ),
                            if (realizedProfit != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: realizedProfit < 0 ? AppTheme.dangerLight : AppTheme.successLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: realizedProfit < 0 ? AppTheme.dangerBorder : AppTheme.successBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      realizedProfit < 0 ? 'Prejuízo Realizado' : 'Lucro Realizado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                      ),
                                    ),
                                    Text(
                                      '${realizedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(realizedProfit.abs())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 16, color: AppTheme.borderSubtle),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Status: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                StatusBadge.paymentStatus(vehicle.activeSale!.paymentStatus),
                              ],
                            ),
                            if (vehicle.activeSale!.balanceDueCents > 0) ...[
                              Text(
                                'Falta receber: ${Formatters.formatCurrency(vehicle.activeSale!.balanceDueCents)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warningOrange),
                              ),
                            ] else ...[
                              const Text(
                                '100% recebido',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.successGreen),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
