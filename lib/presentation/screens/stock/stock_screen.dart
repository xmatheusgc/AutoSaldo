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
import '../../widgets/app_segmented_control.dart';
import '../../widgets/car_plate_widget.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/screen_header_row.dart';
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
  final VoidCallback? onOpenAccount;
  final String? userInitial;

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
    this.onOpenAccount,
    this.userInitial,
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

  void _openVehicleDetail(Vehicle vehicle) {
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
  }

  String? _shortAuthor(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    final prefix = email.trim().split('@').first;
    if (prefix.isEmpty) return null;
    return prefix[0].toUpperCase() + prefix.substring(1);
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

  int get _activeControlCount {
    int count = 0;
    if (_onlyDocIssue) count++;
    if (_onlyPendingPayment) count++;
    if (_onlyStagnant) count++;
    if (_sort != _StockSort.newest) count++;
    return count;
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

  void _toggleDocIssueFilter(bool selected, List<Vehicle> allVehicles) {
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
  }

  void _togglePendingPaymentFilter(bool selected) {
    setState(() {
      _onlyPendingPayment = selected;
      if (selected) {
        _filter = 'sold';
        _onlyStagnant = false;
      }
    });
  }

  void _toggleStagnantFilter(bool selected) {
    setState(() {
      _onlyStagnant = selected;
      if (selected) {
        _filter = 'in_stock';
        _onlyPendingPayment = false;
      }
    });
  }

  void _clearAllControls() {
    setState(() {
      _onlyDocIssue = false;
      _onlyPendingPayment = false;
      _onlyStagnant = false;
      _sort = _StockSort.newest;
    });
  }

  void _showFilterSortSheet({
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
    required List<Vehicle> allVehicles,
  }) {
    showAdaptiveModalSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final hasAnyQuickFilter = docIssueCount > 0 ||
                _onlyDocIssue ||
                pendingPaymentCount > 0 ||
                _onlyPendingPayment ||
                stagnantCount > 0 ||
                _onlyStagnant;

            return AdaptiveModalContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Ordenar e Filtrar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_activeControlCount > 0)
                            TextButton(
                              onPressed: () {
                                _clearAllControls();
                                setModalState(() {});
                              },
                              child: const Text(
                                'Limpar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 22),
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ordenação',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _StockSort.values.map((option) {
                      final selected = _sort == option;
                      return ChoiceChip(
                        label: Text(
                          _sortLabel(option),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : AppTheme.textMain,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AppTheme.primaryDark,
                        backgroundColor: Colors.white,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? AppTheme.primaryDark
                              : AppTheme.borderInteractive,
                        ),
                        onSelected: (_) {
                          setState(() => _sort = option);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  if (hasAnyQuickFilter) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Filtros rápidos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (docIssueCount > 0 || _onlyDocIssue)
                          FilterChip(
                            selected: _onlyDocIssue,
                            label: Text(
                              'Doc pendente ($docIssueCount)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selectedColor: AppTheme.warningLight,
                            checkmarkColor: AppTheme.warningOrange,
                            side: BorderSide(
                              color: _onlyDocIssue
                                  ? AppTheme.warningBorder
                                  : AppTheme.borderInteractive,
                            ),
                            onSelected: (selected) {
                              _toggleDocIssueFilter(selected, allVehicles);
                              setModalState(() {});
                            },
                          ),
                        if (pendingPaymentCount > 0 || _onlyPendingPayment)
                          FilterChip(
                            selected: _onlyPendingPayment,
                            label: Text(
                              'Falta receber ($pendingPaymentCount)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selectedColor: AppTheme.warningLight,
                            checkmarkColor: AppTheme.warningOrange,
                            side: BorderSide(
                              color: _onlyPendingPayment
                                  ? AppTheme.warningBorder
                                  : AppTheme.borderInteractive,
                            ),
                            onSelected: (selected) {
                              _togglePendingPaymentFilter(selected);
                              setModalState(() {});
                            },
                          ),
                        if (stagnantCount > 0 || _onlyStagnant)
                          FilterChip(
                            selected: _onlyStagnant,
                            label: Text(
                              '+45d pátio ($stagnantCount)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            selectedColor: AppTheme.dangerLight,
                            checkmarkColor: AppTheme.dangerRed,
                            side: BorderSide(
                              color: _onlyStagnant
                                  ? AppTheme.dangerBorder
                                  : AppTheme.borderInteractive,
                            ),
                            onSelected: (selected) {
                              _toggleStagnantFilter(selected);
                              setModalState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchField({bool compact = false}) {
    return SizedBox(
      height: compact ? 40 : 42,
      child: TextField(
        controller: _searchController,
        focusNode: widget.searchFocusNode,
        style: const TextStyle(fontSize: 14, color: AppTheme.textMain),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar modelo ou placa...',
          hintStyle: const TextStyle(fontSize: 13.5, color: AppTheme.textLight),
          prefixIcon: const Icon(Icons.search, size: 19, color: AppTheme.textMuted),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 17),
                  tooltip: 'Limpar busca',
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.sectionDivider,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryDark, width: 1.2),
          ),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  Widget _buildFilterButton({
    required bool compact,
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
    required List<Vehicle> allVehicles,
  }) {
    final activeCount = _activeControlCount;
    final hasActive = activeCount > 0;

    return Tooltip(
      message: 'Ordenar e filtrar',
      child: Semantics(
        button: true,
        label: 'Filtros',
        child: Material(
          color: hasActive ? AppTheme.primaryDark : AppTheme.sectionDivider,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showFilterSortSheet(
              docIssueCount: docIssueCount,
              pendingPaymentCount: pendingPaymentCount,
              stagnantCount: stagnantCount,
              allVehicles: allVehicles,
            ),
            child: Container(
              height: compact ? 40 : 42,
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: hasActive ? Colors.white : AppTheme.textMain,
                  ),
                  if (!compact || hasActive) ...[
                    const SizedBox(width: 6),
                    Text(
                      compact ? '$activeCount' : (hasActive ? 'Filtros ($activeCount)' : 'Filtros'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasActive ? Colors.white : AppTheme.textMain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabsBar(
    int inStockCount,
    int soldCount,
    int totalCount, {
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16),
    bool showBottomBorder = true,
  }) {
    return AppUnderlineTabBar<String>(
      selectedValue: _filter,
      padding: padding,
      showBottomBorder: showBottomBorder,
      onChanged: (value) {
        setState(() {
          _filter = value;
        });
      },
      items: [
        AppSegmentedItem(value: 'in_stock', label: 'Em estoque ($inStockCount)'),
        AppSegmentedItem(value: 'sold', label: 'Vendidos ($soldCount)'),
        AppSegmentedItem(value: 'all', label: 'Todos ($totalCount)'),
      ],
    );
  }

  Widget _buildActiveFiltersStrip({
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
    required EdgeInsetsGeometry padding,
  }) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_sort != _StockSort.newest) ...[
              _buildRemovablePill(
                label: 'Ordenar: ${_sortLabel(_sort)}',
                color: AppTheme.textMain,
                bgColor: AppTheme.sectionDivider,
                onRemove: () => setState(() => _sort = _StockSort.newest),
              ),
              const SizedBox(width: 6),
            ],
            if (_onlyDocIssue) ...[
              _buildRemovablePill(
                label: 'Doc pendente ($docIssueCount)',
                color: AppTheme.warningOrange,
                bgColor: AppTheme.warningLight,
                onRemove: () => setState(() => _onlyDocIssue = false),
              ),
              const SizedBox(width: 6),
            ],
            if (_onlyPendingPayment) ...[
              _buildRemovablePill(
                label: 'Falta receber ($pendingPaymentCount)',
                color: AppTheme.warningOrange,
                bgColor: AppTheme.warningLight,
                onRemove: () => setState(() => _onlyPendingPayment = false),
              ),
              const SizedBox(width: 6),
            ],
            if (_onlyStagnant)
              _buildRemovablePill(
                label: '+45d pátio ($stagnantCount)',
                color: AppTheme.dangerRed,
                bgColor: AppTheme.dangerLight,
                onRemove: () => setState(() => _onlyStagnant = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovablePill({
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onRemove,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 14, color: color),
            ],
          ),
        ),
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

            if (isWide) {
              return _buildDesktopLayout(
                allVehicles: allVehicles,
                filtered: filtered,
                expensesByVehicle: expensesByVehicle,
                hasStreamError: hasStreamError,
                isWaitingInitial: isWaitingInitial,
                inStockCount: inStockCount,
                soldCount: soldCount,
                docIssueCount: docIssueCount,
                pendingPaymentCount: pendingPaymentCount,
                stagnantCount: stagnantCount,
              );
            }

            return _buildMobileLayout(
              allVehicles: allVehicles,
              filtered: filtered,
              expensesByVehicle: expensesByVehicle,
              hasStreamError: hasStreamError,
              isWaitingInitial: isWaitingInitial,
              inStockCount: inStockCount,
              soldCount: soldCount,
              docIssueCount: docIssueCount,
              pendingPaymentCount: pendingPaymentCount,
              stagnantCount: stagnantCount,
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout({
    required List<Vehicle> allVehicles,
    required List<Vehicle> filtered,
    required Map<String, int> expensesByVehicle,
    required bool hasStreamError,
    required bool isWaitingInitial,
    required int inStockCount,
    required int soldCount,
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
  }) {
    final hasActiveStrip = _activeControlCount > 0;
    final pinnedHeight = hasActiveStrip ? 82.0 : 42.0;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        tooltip: 'Cadastrar veículo',
        onPressed: _openNewVehicleForm,
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              primary: false,
              automaticallyImplyLeading: false,
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 108,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScreenHeaderRow(
                      title: 'Estoque',
                      userInitial: widget.userInitial,
                      onOpenAccount: widget.onOpenAccount,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildSearchField(compact: true)),
                        const SizedBox(width: 8),
                        _buildFilterButton(
                          compact: true,
                          docIssueCount: docIssueCount,
                          pendingPaymentCount: pendingPaymentCount,
                          stagnantCount: stagnantCount,
                          allVehicles: allVehicles,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedTabsDelegate(
                height: pinnedHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabsBar(
                      inStockCount,
                      soldCount,
                      allVehicles.length,
                      showBottomBorder: !hasActiveStrip,
                    ),
                    if (hasActiveStrip) ...[
                      _buildActiveFiltersStrip(
                        docIssueCount: docIssueCount,
                        pendingPaymentCount: pendingPaymentCount,
                        stagnantCount: stagnantCount,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),
                    ],
                  ],
                ),
              ),
            ),
            if (hasStreamError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              )
            else if (isWaitingInitial)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else ...[
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppTheme.borderSubtle,
                ),
                itemBuilder: (context, index) {
                  final vehicle = filtered[index];
                  return _buildMobileVehicleRow(
                    vehicle: vehicle,
                    expensesByVehicle: expensesByVehicle,
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout({
    required List<Vehicle> allVehicles,
    required List<Vehicle> filtered,
    required Map<String, int> expensesByVehicle,
    required bool hasStreamError,
    required bool isWaitingInitial,
    required int inStockCount,
    required int soldCount,
    required int docIssueCount,
    required int pendingPaymentCount,
    required int stagnantCount,
  }) {
    final hasActiveStrip = _activeControlCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.desktopBg,
      body: Column(
        children: [
          Container(
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const Text(
                              'Estoque',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _buildSearchField()),
                            const SizedBox(width: 10),
                            _buildFilterButton(
                              compact: false,
                              docIssueCount: docIssueCount,
                              pendingPaymentCount: pendingPaymentCount,
                              stagnantCount: stagnantCount,
                              allVehicles: allVehicles,
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Cadastrar veículo',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryDark,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(168, 42),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _openNewVehicleForm,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTabsBar(
                        inStockCount,
                        soldCount,
                        allVehicles.length,
                        padding: EdgeInsets.zero,
                        showBottomBorder: false,
                      ),
                      if (hasActiveStrip)
                        _buildActiveFiltersStrip(
                          docIssueCount: docIssueCount,
                          pendingPaymentCount: pendingPaymentCount,
                          stagnantCount: stagnantCount,
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: hasStreamError
                ? _buildErrorState()
                : isWaitingInitial
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildDesktopTable(filtered, expensesByVehicle),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    List<Vehicle> filtered,
    Map<String, int> expensesByVehicle,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ResponsiveBreakpoints.maxContentWidth + 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showCostCol = constraints.maxWidth >= 860;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Cabeçalho da tabela
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 120,
                            child: _TableHeaderCell('PLACA'),
                          ),
                          const Expanded(
                            child: _TableHeaderCell('VEÍCULO'),
                          ),
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 78,
                            child: _TableHeaderCell('PÁTIO'),
                          ),
                          if (showCostCol) ...[
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 110,
                              child: _TableHeaderCell('CUSTO', alignRight: true),
                            ),
                          ],
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 112,
                            child: _TableHeaderCell('PREÇO', alignRight: true),
                          ),
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 132,
                            child: _TableHeaderCell('MARGEM', alignRight: true),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.borderSubtle,
                        ),
                        itemBuilder: (context, index) {
                          final vehicle = filtered[index];
                          return _buildDesktopTableRow(
                            vehicle: vehicle,
                            expensesByVehicle: expensesByVehicle,
                            showCostCol: showCostCol,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTableRow({
    required Vehicle vehicle,
    required Map<String, int> expensesByVehicle,
    required bool showCostCol,
  }) {
    final totalCost = FinancialCalculator.calculateVehicleTotalCostFromMap(
      vehicle,
      expensesByVehicle,
    );
    final estimatedProfit = FinancialCalculator.calculateEstimatedProfitFromMap(
      vehicle,
      expensesByVehicle,
    );
    final realizedProfit = FinancialCalculator.calculateRealizedProfitFromMap(
      vehicle,
      expensesByVehicle,
    );
    final daysInStock = FinancialCalculator.calculateDaysInStock(vehicle);
    final profit = vehicle.isSold ? realizedProfit : estimatedProfit;
    final roiPercent = profit != null
        ? FinancialCalculator.calculateRoiPercent(profit, totalCost)
        : null;

    final int? displayPriceCents = vehicle.isSold
        ? vehicle.activeSale?.salePriceCents
        : vehicle.announcedPriceCents;

    final alerts = _collectAlerts(
      vehicle: vehicle,
      daysInStock: daysInStock,
      estimatedProfit: estimatedProfit,
      totalCost: totalCost,
    );

    final author = _shortAuthor(vehicle.createdByEmail);
    final yearText = (vehicle.manufactureYear != null || vehicle.modelYear != null)
        ? '${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}'
        : null;

    final isCriticalAge =
        vehicle.isInStock && daysInStock >= AppConstants.criticalStockDaysThreshold;
    final isStagnantAge =
        vehicle.isInStock && daysInStock >= AppConstants.stagnantStockDaysThreshold;

    final ageColor = isCriticalAge
        ? AppTheme.dangerRed
        : isStagnantAge
            ? AppTheme.warningOrange
            : AppTheme.textMuted;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openVehicleDetail(vehicle),
        hoverColor: const Color(0xFFF8FAFC),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CarPlateWidget(
                        plate: vehicle.plate,
                        fontSize: 11.5,
                        compact: true,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vehicle.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                              ),
                            ),
                          ),
                          if (_filter == 'all' && vehicle.isSold) ...[
                            const SizedBox(width: 8),
                            const _MicroStatusText('Vendido', AppTheme.successGreen),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (yearText != null)
                            Text(
                              yearText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          if (!showCostCol)
                            Text(
                              'Custo ${Formatters.formatCurrency(totalCost)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                fontFeatures: AppTheme.tabularNumbers,
                              ),
                            ),
                          if (author != null)
                            Text(
                              yearText != null || !showCostCol ? '• $author' : author,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          if (alerts.isNotEmpty) ...[
                            const Text('•', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                            _AlertTextInline(alerts: alerts),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 78,
                  child: Text(
                    vehicle.isInStock
                        ? (daysInStock == 0 ? 'Hoje' : '${daysInStock}d')
                        : Formatters.formatDaysCount(daysInStock),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isStagnantAge ? FontWeight.w700 : FontWeight.w500,
                      color: ageColor,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                ),
                if (showCostCol) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: Text(
                      Formatters.formatCurrency(totalCost),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                        fontFeatures: AppTheme.tabularNumbers,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Text(
                    displayPriceCents != null
                        ? Formatters.formatCurrency(displayPriceCents)
                        : 'Sem anúncio',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: displayPriceCents != null ? 14 : 12.5,
                      fontWeight: displayPriceCents != null ? FontWeight.w800 : FontWeight.w500,
                      color: displayPriceCents != null ? AppTheme.textMain : AppTheme.textMuted,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 132,
                  child: _buildMarginColumn(
                    vehicle: vehicle,
                    profit: profit,
                    roiPercent: roiPercent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginColumn({
    required Vehicle vehicle,
    required int? profit,
    required double? roiPercent,
  }) {
    if (profit == null) {
      return const Text(
        '—',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 13, color: AppTheme.textLight),
      );
    }
    final isLoss = profit < 0;
    final color = isLoss ? AppTheme.dangerRed : AppTheme.successGreen;
    final sign = isLoss ? '-' : '+';
    final roiText = roiPercent != null ? ' • ${Formatters.formatPercent(roiPercent)}' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$sign${Formatters.formatCurrency(profit.abs())}',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: AppTheme.tabularNumbers,
          ),
        ),
        if (roiText.isNotEmpty)
          Text(
            roiText.replaceFirst(' • ', ''),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileVehicleRow({
    required Vehicle vehicle,
    required Map<String, int> expensesByVehicle,
  }) {
    final totalCost = FinancialCalculator.calculateVehicleTotalCostFromMap(
      vehicle,
      expensesByVehicle,
    );
    final estimatedProfit = FinancialCalculator.calculateEstimatedProfitFromMap(
      vehicle,
      expensesByVehicle,
    );
    final realizedProfit = FinancialCalculator.calculateRealizedProfitFromMap(
      vehicle,
      expensesByVehicle,
    );
    final daysInStock = FinancialCalculator.calculateDaysInStock(vehicle);

    final int? profit = vehicle.isSold ? realizedProfit : estimatedProfit;
    final double? roiPercent = profit != null
        ? FinancialCalculator.calculateRoiPercent(profit, totalCost)
        : null;

    final int? displayPriceCents = vehicle.isSold
        ? vehicle.activeSale?.salePriceCents
        : vehicle.announcedPriceCents;

    final alerts = _collectAlerts(
      vehicle: vehicle,
      daysInStock: daysInStock,
      estimatedProfit: estimatedProfit,
      totalCost: totalCost,
    );

    final metaParts = <String>[
      if (vehicle.manufactureYear != null || vehicle.modelYear != null)
        '${vehicle.manufactureYear ?? "-"}/${vehicle.modelYear ?? "-"}',
      if (vehicle.isInStock)
        daysInStock == 0 ? 'Entrada hoje' : '${daysInStock}d pátio'
      else
        'Vendido ${Formatters.formatDaysCount(daysInStock)}',
      'Custo ${Formatters.formatCurrency(totalCost)}',
      if (_shortAuthor(vehicle.createdByEmail) != null)
        _shortAuthor(vehicle.createdByEmail)!,
    ];

    final isLoss = (profit ?? 0) < 0;
    final profitColor = isLoss ? AppTheme.dangerRed : AppTheme.successGreen;
    final profitSign = isLoss ? '-' : '+';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openVehicleDetail(vehicle),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha A: Placa (+ status apenas se tab Todos) | Preço principal
              Row(
                children: [
                  CarPlateWidget(
                    plate: vehicle.plate,
                    fontSize: 11.5,
                    compact: true,
                  ),
                  if (_filter == 'all' && vehicle.isSold) ...[
                    const SizedBox(width: 8),
                    const _MicroStatusText('Vendido', AppTheme.successGreen),
                  ],
                  const Spacer(),
                  Text(
                    displayPriceCents != null
                        ? Formatters.formatCurrency(displayPriceCents)
                        : 'Sem anúncio',
                    style: TextStyle(
                      fontSize: displayPriceCents != null ? 15.5 : 13,
                      fontWeight: displayPriceCents != null ? FontWeight.w800 : FontWeight.w500,
                      color: displayPriceCents != null ? AppTheme.textMain : AppTheme.textMuted,
                      fontFeatures: AppTheme.tabularNumbers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // Linha B: Título do veículo | Lucro e ROI
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      vehicle.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (profit != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '$profitSign${Formatters.formatCurrency(profit.abs())}${roiPercent != null ? " (${Formatters.formatPercent(roiPercent)})" : ""}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                        fontFeatures: AppTheme.tabularNumbers,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),

              // Linha C: Metadados curtos
              Text(
                metaParts.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontFeatures: AppTheme.tabularNumbers,
                ),
              ),

              // Linha D: Exceções reais (omitida quando saudável)
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 4),
                _AlertTextInline(alerts: alerts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_VehicleAlert> _collectAlerts({
    required Vehicle vehicle,
    required int daysInStock,
    required int? estimatedProfit,
    required int totalCost,
  }) {
    final alerts = <_VehicleAlert>[];

    if (vehicle.isInStock && estimatedProfit != null) {
      if (estimatedProfit < 0) {
        alerts.add(const _VehicleAlert('Prejuízo previsto', AppTheme.dangerRed));
      } else if (FinancialCalculator.isTightMargin(estimatedProfit, totalCost)) {
        alerts.add(const _VehicleAlert('Margem < 5%', AppTheme.warningOrange));
      }
    }

    if (vehicle.isSold && (vehicle.activeSale?.balanceDueCents ?? 0) > 0) {
      alerts.add(
        _VehicleAlert(
          'Falta receber ${Formatters.formatCurrency(vehicle.activeSale!.balanceDueCents)}',
          AppTheme.warningOrange,
        ),
      );
    }

    if (vehicle.docStatus == AppConstants.docStatusWithIssue) {
      alerts.add(const _VehicleAlert('Doc pendente', AppTheme.warningOrange));
    }

    if (vehicle.isInStock) {
      if (daysInStock >= AppConstants.criticalStockDaysThreshold) {
        alerts.add(_VehicleAlert('${daysInStock}d no pátio', AppTheme.dangerRed));
      } else if (daysInStock >= AppConstants.stagnantStockDaysThreshold) {
        alerts.add(_VehicleAlert('+${daysInStock}d pátio', AppTheme.warningOrange));
      }
    }

    return alerts;
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
              const Icon(Icons.cloud_off_outlined, size: 44, color: AppTheme.dangerRed),
              const SizedBox(height: 14),
              const Text(
                'Não foi possível carregar o estoque',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
              ),
              const SizedBox(height: 6),
              const Text(
                'Verifique sua conexão com a internet e tente novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
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
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.sectionDivider,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined, size: 42, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhum veículo encontrado',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Nenhum resultado para "$_searchQuery".'
                  : 'Nenhum carro nesta categoria no momento.',
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            if (_activeControlCount > 0 || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _onlyDocIssue = false;
                    _onlyPendingPayment = false;
                    _onlyStagnant = false;
                    _sort = _StockSort.newest;
                  });
                },
                child: const Text('Limpar busca e filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinnedTabsDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedTabsDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: height,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabsDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _MicroStatusText extends StatelessWidget {
  final String label;
  final Color color;

  const _MicroStatusText(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _VehicleAlert {
  final String label;
  final Color color;

  const _VehicleAlert(this.label, this.color);
}

class _AlertTextInline extends StatelessWidget {
  final List<_VehicleAlert> alerts;

  const _AlertTextInline({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final primaryColor = alerts.first.color;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Icon(Icons.warning_amber_rounded, size: 13, color: primaryColor),
        for (int i = 0; i < alerts.length; i++) ...[
          if (i > 0)
            const Text('•', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
          Text(
            alerts[i].label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: alerts[i].color,
              fontFeatures: AppTheme.tabularNumbers,
            ),
          ),
        ],
      ],
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  final bool alignRight;

  const _TableHeaderCell(this.label, {this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
