import '../../core/constants.dart';
import '../models/expense.dart';
import '../models/model_performance.dart';
import '../models/monthly_summary.dart';
import '../models/vehicle.dart';

class FinancialCalculator {
  /// Pré-agrega as despesas válidas por vehicleId em uma única passagem O(E)
  static Map<String, int> aggregateValidExpensesByVehicle(List<Expense> expenses) {
    final Map<String, int> totals = {};
    for (final e in expenses) {
      if (e.isValid) {
        totals[e.vehicleId] = (totals[e.vehicleId] ?? 0) + e.amountCents;
      }
    }
    return totals;
  }

  /// Calcula o custo total usando mapa pré-agregado O(1)
  static int calculateVehicleTotalCostFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle,
  ) {
    return vehicle.purchasePriceCents + (expensesByVehicle[vehicle.id] ?? 0);
  }

  /// Lucro estimado usando mapa pré-agregado O(1)
  static int? calculateEstimatedProfitFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle,
  ) {
    if (vehicle.announcedPriceCents == null) return null;
    return vehicle.announcedPriceCents! -
        calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
  }

  /// Lucro realizado usando mapa pré-agregado O(1)
  static int? calculateRealizedProfitFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle,
  ) {
    if (vehicle.activeSale == null) return null;
    return vehicle.activeSale!.salePriceCents -
        calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
  }

  /// Calcula o custo total do veículo: valor da compra + despesas válidas
  static int calculateVehicleTotalCost(Vehicle vehicle, List<Expense> expenses) {
    int total = vehicle.purchasePriceCents;
    for (final e in expenses) {
      if (e.vehicleId == vehicle.id && e.isValid) {
        total += e.amountCents;
      }
    }
    return total;
  }

  /// Retorna as despesas válidas de um veículo específico
  static List<Expense> getVehicleValidExpenses(Vehicle vehicle, List<Expense> expenses) {
    return expenses.where((e) => e.vehicleId == vehicle.id && e.isValid).toList();
  }

  /// Lucro estimado para carro em estoque com preço anunciado (preço anunciado - custo total)
  static int? calculateEstimatedProfit(Vehicle vehicle, List<Expense> expenses) {
    if (vehicle.announcedPriceCents == null) return null;
    final totalCost = calculateVehicleTotalCost(vehicle, expenses);
    return vehicle.announcedPriceCents! - totalCost;
  }

  /// Lucro realizado por carro vendido (preço final negociado - custo total, incluindo despesas posteriores)
  static int? calculateRealizedProfit(Vehicle vehicle, List<Expense> expenses) {
    if (vehicle.activeSale == null) return null;
    final totalCost = calculateVehicleTotalCost(vehicle, expenses);
    return vehicle.activeSale!.salePriceCents - totalCost;
  }

  /// Saldo a receber de um veículo vendido (valor negociado - total recebido)
  static int calculateBalanceDue(Vehicle vehicle) {
    if (vehicle.activeSale == null) return 0;
    return vehicle.activeSale!.balanceDueCents;
  }

  static DateTime? _parseIsoLocalDate(String isoDate) {
    if (isoDate.length < 10) return null;
    final parts = isoDate.substring(0, 10).split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Calcula quantos dias o veículo ficou (ou está) no pátio entre compra e venda/hoje.
  static int calculateDaysInStock(Vehicle vehicle, {DateTime? now}) {
    final start = _parseIsoLocalDate(vehicle.purchaseDate);
    if (start == null) return 0;

    final refNow = now ?? DateTime.now();
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final end = vehicle.activeSale != null
        ? (_parseIsoLocalDate(vehicle.activeSale!.saleDate) ?? today)
        : today;

    return end.difference(start).inDays.clamp(0, 100000);
  }

  /// Calcula o retorno sobre o investimento (ROI %) considerando lucro e custo total.
  static double? calculateRoiPercent(int profitCents, int totalCostCents) {
    if (totalCostCents <= 0) return null;
    return (profitCents / totalCostCents) * 100.0;
  }

  /// Agrupa gastos válidos por categoria (opcionalmente filtrado por prefixo YYYY-MM).
  static Map<String, int> calculateExpensesByCategory(
    List<Expense> expenses, {
    String? monthPrefix,
  }) {
    final Map<String, int> byCategory = {};
    for (final e in expenses) {
      if (!e.isValid) continue;
      if (monthPrefix != null && !e.date.startsWith(monthPrefix)) continue;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountCents;
    }
    return byCategory;
  }

  /// Calcula todos os indicadores do Resumo Mensal para um determinado mês/ano
  static MonthlySummary calculateMonthlySummary({
    required List<Vehicle> allVehicles,
    required List<Expense> allExpenses,
    required int year,
    required int month,
    DateTime? now,
  }) {
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';
    final expensesByVehicle = aggregateValidExpensesByVehicle(allExpenses);

    // 1. Lucro, custo total e giro dos carros vendidos no mês
    int soldVehiclesProfitCents = 0;
    int soldVehiclesCostCents = 0;
    int soldInMonthCount = 0;
    int soldDaysSum = 0;

    for (final vehicle in allVehicles) {
      if (vehicle.activeSale != null && vehicle.activeSale!.saleDate.startsWith(monthPrefix)) {
        soldInMonthCount++;
        final cost = calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
        soldVehiclesCostCents += cost;
        soldDaysSum += calculateDaysInStock(vehicle, now: now);
        final profit = vehicle.activeSale!.salePriceCents - cost;
        soldVehiclesProfitCents += profit;
      }
    }

    final soldInMonthRoiPercent = soldInMonthCount > 0
        ? calculateRoiPercent(soldVehiclesProfitCents, soldVehiclesCostCents)
        : null;
    final avgDaysToSell = soldInMonthCount > 0 ? soldDaysSum / soldInMonthCount : null;

    // 2. Entradas no mês
    int monthIncomeCents = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.activeSale != null) {
        for (final payment in vehicle.activeSale!.payments) {
          if (payment.isValid && payment.date.startsWith(monthPrefix)) {
            monthIncomeCents += payment.amountCents;
          }
        }
      }
    }

    // 3. Saídas no mês + gastos por categoria
    int monthExpensesCents = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.purchaseDate.startsWith(monthPrefix)) {
        monthExpensesCents += vehicle.purchasePriceCents;
      }
    }
    final Map<String, int> monthExpensesByCategory = {};
    for (final expense in allExpenses) {
      if (expense.isValid && expense.date.startsWith(monthPrefix)) {
        monthExpensesCents += expense.amountCents;
        monthExpensesByCategory[expense.category] =
            (monthExpensesByCategory[expense.category] ?? 0) + expense.amountCents;
      }
    }

    // 4. Saldo do mês = Entradas - Saídas
    final monthNetCashCents = monthIncomeCents - monthExpensesCents;

    // 5. Investido no estoque atual + idade média + carros parados (+45d)
    int currentStockInvestmentCents = 0;
    int stockCount = 0;
    int stockAgeSum = 0;
    int stagnantStockCount = 0;

    for (final vehicle in allVehicles) {
      if (vehicle.isInStock) {
        stockCount++;
        currentStockInvestmentCents +=
            calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
        final days = calculateDaysInStock(vehicle, now: now);
        stockAgeSum += days;
        if (days >= AppConstants.stagnantStockDaysThreshold) {
          stagnantStockCount++;
        }
      }
    }

    final avgStockAgeDays = stockCount > 0 ? stockAgeSum / stockCount : null;

    // 6. A receber hoje (saldo das vendas ativas, independente do mês)
    int toReceiveTodayCents = 0;
    int pendingReceiveVehiclesCount = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.isSold) {
        final due = calculateBalanceDue(vehicle);
        toReceiveTodayCents += due;
        if (due > 0) pendingReceiveVehiclesCount++;
      }
    }

    return MonthlySummary(
      year: year,
      month: month,
      soldVehiclesProfitCents: soldVehiclesProfitCents,
      monthIncomeCents: monthIncomeCents,
      monthExpensesCents: monthExpensesCents,
      monthNetCashCents: monthNetCashCents,
      currentStockInvestmentCents: currentStockInvestmentCents,
      toReceiveTodayCents: toReceiveTodayCents,
      soldCount: soldInMonthCount,
      stockCount: stockCount,
      soldVehiclesCostCents: soldVehiclesCostCents,
      soldInMonthRoiPercent: soldInMonthRoiPercent,
      avgDaysToSell: avgDaysToSell,
      avgStockAgeDays: avgStockAgeDays,
      stagnantStockCount: stagnantStockCount,
      monthExpensesByCategory: monthExpensesByCategory,
      pendingReceiveVehiclesCount: pendingReceiveVehiclesCount,
    );
  }

  /// Indica se a margem prevista está negativa ou apertada (ROI abaixo do mínimo configurado).
  static bool isTightMargin(int? estimatedProfitCents, int totalCostCents) {
    if (estimatedProfitCents == null) return false;
    if (estimatedProfitCents < 0) return true;
    final roi = calculateRoiPercent(estimatedProfitCents, totalCostCents);
    return roi != null && roi < AppConstants.lowMarginRoiThresholdPercent;
  }

  static String _canonicalBrandKey(String rawBrand) {
    final normalized = _normalizeGroupText(rawBrand);
    const aliases = {
      'vw': 'volkswagen',
      'gm': 'chevrolet',
      'chevy': 'chevrolet',
      'mercedes': 'mercedes benz',
      'mercedes-benz': 'mercedes benz',
      'landrover': 'land rover',
    };
    return aliases[normalized] ?? normalized;
  }

  static String _normalizeGroupText(String raw) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final lower = raw.trim().toLowerCase();
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      buffer.write(accents[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static DateTime _subtractCalendarMonths(DateTime ref, int months) {
    var year = ref.year;
    var month = ref.month - months;
    while (month <= 0) {
      month += 12;
      year--;
    }
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = ref.day > maxDay ? maxDay : ref.day;
    return DateTime(year, month, day);
  }

  static bool _matchesWindow(
    String isoSaleDate,
    ModelAnalyticsWindow window,
    DateTime refNow,
  ) {
    if (window == ModelAnalyticsWindow.allTime) return true;
    final parsed = _parseIsoLocalDate(isoSaleDate);
    if (parsed == null) return false;
    final monthsBack = window == ModelAnalyticsWindow.last6Months ? 6 : 12;
    final cutoff = _subtractCalendarMonths(
      DateTime(refNow.year, refNow.month, refNow.day),
      monthsBack,
    );
    return !parsed.isBefore(cutoff);
  }

  static ModelPerformanceStats? _pickHighlight(
    List<ModelPerformanceStats> models,
    int Function(ModelPerformanceStats a, ModelPerformanceStats b) compareBestFirst,
  ) {
    if (models.isEmpty) return null;
    final recurring = models.where((m) => m.soldCount >= 2).toList();
    final pool = recurring.isNotEmpty ? recurring : models;
    final sorted = List<ModelPerformanceStats>.from(pool)..sort(compareBestFirst);
    return sorted.first;
  }

  /// Calcula métricas de desempenho e giro agrupadas por modelo e marca dos veículos vendidos.
  static PortfolioModelReport calculateModelReport({
    required List<Vehicle> allVehicles,
    required List<Expense> allExpenses,
    ModelAnalyticsWindow window = ModelAnalyticsWindow.allTime,
    DateTime? now,
  }) {
    final refNow = now ?? DateTime.now();
    final expensesByVehicle = aggregateValidExpensesByVehicle(allExpenses);

    // Conta quantos veículos de cada modelo estão em estoque no momento
    final inStockByModelKey = <String, int>{};
    for (final v in allVehicles) {
      if (v.isInStock) {
        final key = '${_canonicalBrandKey(v.brand)}|${_normalizeGroupText(v.model)}';
        inStockByModelKey[key] = (inStockByModelKey[key] ?? 0) + 1;
      }
    }

    final modelBuckets = <String, _ModelAccumulator>{};
    final brandBuckets = <String, _BrandAccumulator>{};

    int totalSoldCount = 0;
    int totalProfitCents = 0;
    int totalCostCents = 0;
    int totalDaysSum = 0;

    for (final vehicle in allVehicles) {
      final sale = vehicle.activeSale;
      if (sale == null || !_matchesWindow(sale.saleDate, window, refNow)) continue;

      final vehicleExpenses = expensesByVehicle[vehicle.id] ?? 0;
      final totalCost = vehicle.purchasePriceCents + vehicleExpenses;
      final profit = sale.salePriceCents - totalCost;
      final days = calculateDaysInStock(vehicle, now: refNow);

      totalSoldCount++;
      totalProfitCents += profit;
      totalCostCents += totalCost;
      totalDaysSum += days;

      final brandKey = _canonicalBrandKey(vehicle.brand);
      final modelKey = '$brandKey|${_normalizeGroupText(vehicle.model)}';

      final modelAcc = modelBuckets.putIfAbsent(
        modelKey,
        () => _ModelAccumulator(
          key: modelKey,
          brand: vehicle.brand.trim(),
          model: vehicle.model.trim(),
        ),
      );
      if (vehicle.brand.trim().length > modelAcc.brand.length) {
        modelAcc.brand = vehicle.brand.trim();
      }
      modelAcc.soldVehicles.add(vehicle);
      modelAcc.totalPurchaseCents += vehicle.purchasePriceCents;
      modelAcc.totalExpensesCents += vehicleExpenses;
      modelAcc.totalCostCents += totalCost;
      modelAcc.totalSaleCents += sale.salePriceCents;
      modelAcc.totalProfitCents += profit;
      modelAcc.totalDays += days;

      final brandAcc = brandBuckets.putIfAbsent(
        brandKey,
        () => _BrandAccumulator(brand: vehicle.brand.trim()),
      );
      if (vehicle.brand.trim().length > brandAcc.brand.length) {
        brandAcc.brand = vehicle.brand.trim();
      }
      brandAcc.soldCount++;
      brandAcc.totalCostCents += totalCost;
      brandAcc.totalProfitCents += profit;
      brandAcc.totalDays += days;
    }

    final models = modelBuckets.values.map((acc) {
      final count = acc.soldVehicles.length;
      acc.soldVehicles.sort(
        (a, b) => b.activeSale!.saleDate.compareTo(a.activeSale!.saleDate),
      );
      return ModelPerformanceStats(
        key: acc.key,
        brand: acc.brand,
        model: acc.model,
        soldCount: count,
        inStockCount: inStockByModelKey[acc.key] ?? 0,
        totalPurchaseCents: acc.totalPurchaseCents,
        totalExpensesCents: acc.totalExpensesCents,
        totalCostCents: acc.totalCostCents,
        totalSaleCents: acc.totalSaleCents,
        totalProfitCents: acc.totalProfitCents,
        avgProfitCents: (acc.totalProfitCents / count).round(),
        avgExpenseCents: (acc.totalExpensesCents / count).round(),
        avgDaysToSell: acc.totalDays / count,
        roiPercent: calculateRoiPercent(acc.totalProfitCents, acc.totalCostCents),
        soldVehicles: acc.soldVehicles,
      );
    }).toList()
      ..sort((a, b) => b.totalProfitCents.compareTo(a.totalProfitCents));

    final brands = brandBuckets.values.map((acc) {
      return BrandPerformanceStats(
        brand: acc.brand,
        soldCount: acc.soldCount,
        totalCostCents: acc.totalCostCents,
        totalProfitCents: acc.totalProfitCents,
        avgDaysToSell: acc.totalDays / acc.soldCount,
        roiPercent: calculateRoiPercent(acc.totalProfitCents, acc.totalCostCents),
      );
    }).toList()
      ..sort((a, b) => b.totalProfitCents.compareTo(a.totalProfitCents));

    final fastestModel = _pickHighlight(models, (a, b) {
      final cmp = a.avgDaysToSell.compareTo(b.avgDaysToSell);
      return cmp != 0 ? cmp : b.soldCount.compareTo(a.soldCount);
    });
    final highestAvgProfitModel = _pickHighlight(
      models,
      (a, b) => b.avgProfitCents.compareTo(a.avgProfitCents),
    );
    final bestRoiModel = _pickHighlight(
      models.where((m) => m.roiPercent != null).toList(),
      (a, b) => b.roiPercent!.compareTo(a.roiPercent!),
    );
    final highestTotalProfitModel = models.isEmpty ? null : models.first;

    return PortfolioModelReport(
      window: window,
      totalSoldCount: totalSoldCount,
      totalProfitCents: totalProfitCents,
      totalCostCents: totalCostCents,
      overallAvgDaysToSell: totalSoldCount > 0 ? totalDaysSum / totalSoldCount : null,
      overallRoiPercent: calculateRoiPercent(totalProfitCents, totalCostCents),
      models: models,
      brands: brands,
      fastestModel: fastestModel,
      highestAvgProfitModel: highestAvgProfitModel,
      bestRoiModel: bestRoiModel,
      highestTotalProfitModel: highestTotalProfitModel,
    );
  }
}

class _ModelAccumulator {
  final String key;
  String brand;
  final String model;
  final List<Vehicle> soldVehicles = [];
  int totalPurchaseCents = 0;
  int totalExpensesCents = 0;
  int totalCostCents = 0;
  int totalSaleCents = 0;
  int totalProfitCents = 0;
  int totalDays = 0;

  _ModelAccumulator({
    required this.key,
    required this.brand,
    required this.model,
  });
}

class _BrandAccumulator {
  String brand;
  int soldCount = 0;
  int totalCostCents = 0;
  int totalProfitCents = 0;
  int totalDays = 0;

  _BrandAccumulator({required this.brand});
}

