import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../data/services/fipe_service.dart';
import '../../../domain/models/expense.dart';
import '../../../domain/models/vehicle.dart';
import '../../../domain/services/financial_calculator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/status_badge.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

enum _StockSort { newest, oldestInStock, lowestPrice, highestPrice, highestProfit }

class StockScreen extends StatefulWidget {
  final String workspaceId;
  final String userUid;
  final String? userEmail;
  final VehicleRepository vehicleRepository;
  final ExpenseRepository expenseRepository;
  final FipeService? fipeService;
  final FocusNode? searchFocusNode;
  final ValueListenable<int>? newVehicleTrigger;

  const StockScreen({
    super.key,
    required this.workspaceId,
    required this.userUid,
    this.userEmail,
    required this.vehicleRepository,
    required this.expenseRepository,
    this.fipeService,
    this.searchFocusNode,
    this.newVehicleTrigger,
  });

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _searchController = TextEditingController();
  String _filter = 'in_stock'; // 'all', 'in_stock', 'sold'
  String _searchQuery = '';
  bool _onlyDocIssue = false;
  bool _onlyPendingPayment = false;
  bool _onlyStagnant = false;
  _StockSort _sort = _StockSort.newest;
  late Stream<List<Vehicle>> _vehiclesStream;
  late Stream<List<Expense>> _expensesStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
    widget.newVehicleTrigger?.addListener(_onNewVehicleShortcut);
  }

  void _onNewVehicleShortcut() {
    if (!mounted) return;
    _openNewVehicleForm();
  }

  void _initStreams() {
    _vehiclesStream = widget.vehicleRepository.getVehiclesStream(widget.workspaceId);
    _expensesStream = widget.expenseRepository.getExpensesStream(widget.workspaceId);
  }

  @override
  void didUpdateWidget(covariant StockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.newVehicleTrigger != widget.newVehicleTrigger) {
      oldWidget.newVehicleTrigger?.removeListener(_onNewVehicleShortcut);
      widget.newVehicleTrigger?.addListener(_onNewVehicleShortcut);
    }
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

  @override
  void dispose() {
    widget.newVehicleTrigger?.removeListener(_onNewVehicleShortcut);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNewVehicleForm() async {
    final newVehicleId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VehicleFormScreen(
          workspaceId: widget.workspaceId,
          userUid: widget.userUid,
          userEmail: widget.userEmail,
          vehicleRepository: widget.vehicleRepository,
          fipeService: widget.fipeService,
        ),
      ),
    );

    if (!mounted) return;

    if (newVehicleId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veículo cadastrado com sucesso!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VehicleDetailScreen(
            workspaceId: widget.workspaceId,
            vehicleId: newVehicleId,
            userUid: widget.userUid,
            userEmail: widget.userEmail,
            vehicleRepository: widget.vehicleRepository,
            expenseRepository: widget.expenseRepository,
            fipeService: widget.fipeService,
          ),
        ),
      );
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: widget.searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Buscar por placa, modelo ou marca...',
        prefixIcon: const Icon(Icons.search, size: 22, color: AppTheme.textMuted),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                tooltip: 'Limpar busca',
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
    );
  }

  Widget _buildSegmentedFilter(int inStockCount, int soldCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterTab('in_stock', 'Em estoque', inStockCount),
          _buildFilterTab('sold', 'Vendidos', soldCount),
          _buildFilterTab('all', 'Todos', totalCount),
        ],
      ),
    );
  }

  String _sortLabel(_StockSort sort) {
    return switch (sort) {
      _StockSort.newest => 'Mais recentes',
      _StockSort.oldestInStock => 'Mais antigos',
      _StockSort.lowestPrice => 'Menor preço',
      _StockSort.highestPrice => 'Maior preço',
      _StockSort.highestProfit => 'Maior lucro',
    };
  }

  List<Vehicle> _sortVehicles(
    List<Vehicle> list,
    Map<String, int> expensesByVehicle,
  ) {
    if (_sort == _StockSort.newest) {
      return list;
    }

    final sorted = List<Vehicle>.from(list);
    int priceOf(Vehicle v) {
      return v.activeSale?.salePriceCents ??
          v.announcedPriceCents ??
          v.purchasePriceCents;
    }

    int profitOf(Vehicle v) {
      final p = v.isSold
          ? FinancialCalculator.calculateRealizedProfitFromMap(v, expensesByVehicle)
          : FinancialCalculator.calculateEstimatedProfitFromMap(v, expensesByVehicle);
      return p ?? -999999999;
    }

    sorted.sort((a, b) {
      switch (_sort) {
        case _StockSort.newest:
          return b.purchaseDate.compareTo(a.purchaseDate);
        case _StockSort.oldestInStock:
          return a.purchaseDate.compareTo(b.purchaseDate);
        case _StockSort.lowestPrice:
          return priceOf(a).compareTo(priceOf(b));
        case _StockSort.highestPrice:
          return priceOf(b).compareTo(priceOf(a));
        case _StockSort.highestProfit:
          return profitOf(b).compareTo(profitOf(a));
      }
    });
    return sorted;
  }

  Widget _buildQuickFilterAndSortBar({
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
    required List<Vehicle> allVehicles,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<_StockSort>(
            tooltip: 'Ordenar veículos',
            initialValue: _sort,
            onSelected: (selected) {
              setState(() {
                _sort = selected;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _StockSort.newest,
                child: Text('Mais recentes'),
              ),
              PopupMenuItem(
                value: _StockSort.oldestInStock,
                child: Text('Mais antigos no pátio'),
              ),
              PopupMenuItem(
                value: _StockSort.lowestPrice,
                child: Text('Menor preço'),
              ),
              PopupMenuItem(
                value: _StockSort.highestPrice,
                child: Text('Maior preço'),
              ),
              PopupMenuItem(
                value: _StockSort.highestProfit,
                child: Text('Maior lucro'),
              ),
            ],
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderInteractive),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 16, color: AppTheme.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    'Ordenar: ${_sortLabel(_sort)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.primaryDark),
                ],
              ),
            ),
          ),
          if (docIssueCount > 0 || _onlyDocIssue)
            FilterChip(
              selected: _onlyDocIssue,
              label: Text(
                'Doc pendente ($docIssueCount)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              selectedColor: AppTheme.warningLight,
              checkmarkColor: AppTheme.warningOrange,
              side: BorderSide(
                color: _onlyDocIssue ? AppTheme.warningBorder : AppTheme.borderInteractive,
              ),
              onSelected: (selected) {
                setState(() {
                  _onlyDocIssue = selected;
                  if (selected && _filter == 'in_stock') {
                    final hasInStockDocIssue = allVehicles.any(
                      (v) => v.isInStock && v.docStatus == AppConstants.docStatusWithIssue,
                    );
                    if (!hasInStockDocIssue) {
                      _filter = 'all';
                    }
                  }
                });
              },
            ),
          if (pendingPaymentCount > 0 || _onlyPendingPayment)
            FilterChip(
              selected: _onlyPendingPayment,
              label: Text(
                'Falta receber ($pendingPaymentCount)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              selectedColor: AppTheme.warningLight,
              checkmarkColor: AppTheme.warningOrange,
              side: BorderSide(
                color: _onlyPendingPayment
                    ? AppTheme.warningBorder
                    : AppTheme.borderInteractive,
              ),
              onSelected: (selected) {
                setState(() {
                  _onlyPendingPayment = selected;
                  if (selected) {
                    _filter = 'sold';
                    _onlyStagnant = false;
                  }
                });
              },
            ),
          if (stagnantCount > 0 || _onlyStagnant)
            FilterChip(
              selected: _onlyStagnant,
              label: Text(
                '+45d pátio ($stagnantCount)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              selectedColor: AppTheme.dangerLight,
              checkmarkColor: AppTheme.dangerRed,
              side: BorderSide(
                color: _onlyStagnant ? AppTheme.dangerBorder : AppTheme.borderInteractive,
              ),
              onSelected: (selected) {
                setState(() {
                  _onlyStagnant = selected;
                  if (selected) {
                    _filter = 'in_stock';
                    _onlyPendingPayment = false;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveBreakpoints.isTabletOrDesktop(context);

    return StreamBuilder<List<Vehicle>>(
      stream: _vehiclesStream,
      builder: (context, vSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: _expensesStream,
          builder: (context, eSnapshot) {
            final hasStreamError = vSnapshot.hasError || eSnapshot.hasError;
            final isWaitingInitial =
                (vSnapshot.connectionState == ConnectionState.waiting && !vSnapshot.hasData) ||
                    (eSnapshot.connectionState == ConnectionState.waiting && !eSnapshot.hasData);

            final allVehicles = vSnapshot.data ?? [];
            final allExpenses = eSnapshot.data ?? [];
            final expensesByVehicle =
                FinancialCalculator.aggregateValidExpensesByVehicle(allExpenses);

            final inStockCount = allVehicles.where((v) => v.isInStock).length;
            final soldCount = allVehicles.where((v) => v.isSold).length;
            final docIssueCount = allVehicles
                .where((v) => v.docStatus == AppConstants.docStatusWithIssue)
                .length;
            final pendingPaymentCount = allVehicles
                .where((v) => v.isSold && (v.activeSale?.balanceDueCents ?? 0) > 0)
                .length;
            final stagnantCount = allVehicles.where((v) {
              if (!v.isInStock) return false;
              return FinancialCalculator.calculateDaysInStock(v) >=
                  AppConstants.stagnantStockDaysThreshold;
            }).length;

            // Filtro de status
            var filtered = allVehicles;
            if (_filter == 'in_stock') {
              filtered = filtered.where((v) => v.isInStock).toList();
            } else if (_filter == 'sold') {
              filtered = filtered.where((v) => v.isSold).toList();
            }

            // Filtros rápidos
            if (_onlyDocIssue) {
              filtered = filtered
                  .where((v) => v.docStatus == AppConstants.docStatusWithIssue)
                  .toList();
            }
            if (_onlyPendingPayment) {
              filtered = filtered
                  .where((v) => v.isSold && (v.activeSale?.balanceDueCents ?? 0) > 0)
                  .toList();
            }
            if (_onlyStagnant) {
              filtered = filtered.where((v) {
                if (!v.isInStock) return false;
                return FinancialCalculator.calculateDaysInStock(v) >=
                    AppConstants.stagnantStockDaysThreshold;
              }).toList();
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

            filtered = _sortVehicles(filtered, expensesByVehicle);

            return Scaffold(
              backgroundColor: AppTheme.bgSurface,
              body: Column(
                children: [
                  // Barra de busca e filtros de topo
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 24 : 16,
                      isWide ? 18 : 14,
                      isWide ? 24 : 16,
                      isWide ? 14 : 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ResponsiveBreakpoints.maxContentWidth,
                        ),
                        child: Column(
                          children: [
                            // Título do Estoque (+ CTA no desktop)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estoque',
                                      style: TextStyle(
                                        fontSize: isWide ? 24 : 22,
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
                                if (isWide)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    label: const Text(
                                      'Cadastrar veículo',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryDark,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(180, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _openNewVehicleForm,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (isWide)
                              Row(
                                children: [
                                  Expanded(child: _buildSearchField()),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 380,
                                    child: _buildSegmentedFilter(
                                      inStockCount,
                                      soldCount,
                                      allVehicles.length,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildSearchField(),
                              const SizedBox(height: 12),
                              _buildSegmentedFilter(
                                inStockCount,
                                soldCount,
                                allVehicles.length,
                              ),
                            ],
                            const SizedBox(height: 10),
                            _buildQuickFilterAndSortBar(
                              docIssueCount: docIssueCount,
                              pendingPaymentCount: pendingPaymentCount,
                              stagnantCount: stagnantCount,
                              allVehicles: allVehicles,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Lista / Grid de veículos
                  Expanded(
                    child: hasStreamError
                        ? _buildErrorState()
                        : isWaitingInitial
                            ? const Center(child: CircularProgressIndicator())
                            : filtered.isEmpty
                                ? _buildEmptyState()
                                : isWide
                                    ? _buildDesktopGrid(
                                        filtered,
                                        expensesByVehicle,
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final vehicle = filtered[index];
                                          final totalCost = FinancialCalculator
                                              .calculateVehicleTotalCostFromMap(
                                                  vehicle, expensesByVehicle);
                                          final estimatedProfit = FinancialCalculator
                                              .calculateEstimatedProfitFromMap(
                                                  vehicle, expensesByVehicle);
                                          final realizedProfit = FinancialCalculator
                                              .calculateRealizedProfitFromMap(
                                                  vehicle, expensesByVehicle);

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
              floatingActionButton: isWide
                  ? null
                  : FloatingActionButton.extended(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text(
                        'Cadastrar veículo',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      onPressed: _openNewVehicleForm,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopGrid(
    List<Vehicle> filtered,
    Map<String, int> expensesByVehicle,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.maxContentWidth + 48),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= ResponsiveBreakpoints.wideGrid ? 3 : 2;
            final rowCount = (filtered.length / columns).ceil();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              itemCount: rowCount,
              itemBuilder: (context, rowIndex) {
                final startIndex = rowIndex * columns;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(columns, (colIndex) {
                        final itemIndex = startIndex + colIndex;
                        final Widget child;
                        if (itemIndex < filtered.length) {
                          final vehicle = filtered[itemIndex];
                          final totalCost =
                              FinancialCalculator.calculateVehicleTotalCostFromMap(
                                  vehicle, expensesByVehicle);
                          final estimatedProfit =
                              FinancialCalculator.calculateEstimatedProfitFromMap(
                                  vehicle, expensesByVehicle);
                          final realizedProfit =
                              FinancialCalculator.calculateRealizedProfitFromMap(
                                  vehicle, expensesByVehicle);

                          child = _buildVehicleCard(
                            vehicle: vehicle,
                            totalCost: totalCost,
                            estimatedProfit: estimatedProfit,
                            realizedProfit: realizedProfit,
                            inGrid: true,
                          );
                        } else {
                          child = const SizedBox.shrink();
                        }

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: colIndex < columns - 1 ? 14 : 0),
                            child: child,
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterTab(String filterKey, String title, int count) {
    final isSelected = _filter == filterKey;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () {
              setState(() {
                _filter = filterKey;
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: AnimatedContainer(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.dangerRed),
              const SizedBox(height: 16),
              const Text(
                'Não foi possível carregar o estoque',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verifique sua conexão com a internet e tente novamente.',
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
    bool inGrid = false,
  }) {
    final daysInStock = FinancialCalculator.calculateDaysInStock(vehicle);
    final isCriticalAge = vehicle.isInStock &&
        daysInStock >= AppConstants.criticalStockDaysThreshold;
    final isStagnantAge = vehicle.isInStock &&
        daysInStock >= AppConstants.stagnantStockDaysThreshold;

    final Color ageBg = isCriticalAge
        ? AppTheme.dangerLight
        : isStagnantAge
            ? AppTheme.warningLight
            : const Color(0xFFF1F5F9);
    final Color ageBorder = isCriticalAge
        ? AppTheme.dangerBorder
        : isStagnantAge
            ? AppTheme.warningBorder
            : AppTheme.borderSubtle;
    final Color ageTextColor = isCriticalAge
        ? AppTheme.dangerRed
        : isStagnantAge
            ? AppTheme.warningOrange
            : AppTheme.textMuted;

    final double? roiPercent = vehicle.isSold && realizedProfit != null
        ? FinancialCalculator.calculateRoiPercent(realizedProfit, totalCost)
        : (vehicle.isInStock && estimatedProfit != null)
            ? FinancialCalculator.calculateRoiPercent(estimatedProfit, totalCost)
            : null;

    return Container(
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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
                  fipeService: widget.fipeService,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  inGrid ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Real Car Plate + Badges
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          CarPlateWidget(plate: vehicle.plate, fontSize: 14),
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

                    // Title and Version
                    Text(
                      vehicle.title,
                      maxLines: inGrid ? 2 : null,
                      overflow: inGrid ? TextOverflow.ellipsis : null,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Years + Days in stock + User who registered
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (vehicle.manufactureYear != null || vehicle.modelYear != null)
                            Text(
                              'Ano: ${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: ageBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: ageBorder),
                            ),
                            child: Text(
                              vehicle.isInStock
                                  ? (daysInStock == 0
                                      ? 'Entrada hoje'
                                      : '${daysInStock}d no pátio')
                                  : 'Vendido em ${Formatters.formatDaysCount(daysInStock)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ageTextColor,
                                fontFeatures: AppTheme.tabularNumbers,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline, size: 13, color: AppTheme.textLight),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Text(
                                  vehicle.createdByEmail != null &&
                                          vehicle.createdByEmail!.isNotEmpty
                                      ? vehicle.createdByEmail!
                                      : 'Cadastrado',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),

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
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Investido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  Formatters.formatCurrency(totalCost),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryDark,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (vehicle.announcedPriceCents != null && estimatedProfit != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  estimatedProfit < 0 ? 'Prejuízo Previsto' : 'Lucro Previsto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${estimatedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(estimatedProfit.abs())}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: estimatedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                      fontFeatures: AppTheme.tabularNumbers,
                                    ),
                                  ),
                                ),
                                if (roiPercent != null)
                                  Text(
                                    'ROI ${Formatters.formatPercent(roiPercent)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: estimatedProfit < 0
                                          ? AppTheme.dangerRed
                                          : AppTheme.successGreen,
                                      fontFeatures: AppTheme.tabularNumbers,
                                    ),
                                  ),
                              ],
                            ),
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
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Venda Final', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      Formatters.formatCurrency(vehicle.activeSale!.salePriceCents),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryDark,
                                        fontFeatures: AppTheme.tabularNumbers,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (realizedProfit != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '${realizedProfit < 0 ? "-" : "+"}${Formatters.formatCurrency(realizedProfit.abs())}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: realizedProfit < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                            fontFeatures: AppTheme.tabularNumbers,
                                          ),
                                        ),
                                      ),
                                      if (roiPercent != null)
                                        Text(
                                          'ROI ${Formatters.formatPercent(roiPercent)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: realizedProfit < 0
                                                ? AppTheme.dangerRed
                                                : AppTheme.successGreen,
                                            fontFeatures: AppTheme.tabularNumbers,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 16, color: AppTheme.borderSubtle),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Status: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  StatusBadge.paymentStatus(vehicle.activeSale!.paymentStatus),
                                ],
                              ),
                              if (vehicle.activeSale!.balanceDueCents > 0)
                                Text(
                                  'Falta receber: ${Formatters.formatCurrency(vehicle.activeSale!.balanceDueCents)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.warningOrange,
                                    fontFeatures: AppTheme.tabularNumbers,
                                  ),
                                )
                              else
                                const Text(
                                  '100% recebido',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.successGreen),
                                ),
                            ],
                          ),
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
