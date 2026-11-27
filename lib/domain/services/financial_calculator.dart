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

  /// Pré-agrega despesas válidas marcadas para descontar do repasse ao proprietário (consignado)
  static Map<String, int> aggregateDeductedExpensesByVehicle(List<Expense> expenses) {
    final Map<String, int> totals = {};
    for (final e in expenses) {
      if (e.isValid && e.deductFromConsignmentPayout) {
        totals[e.vehicleId] = (totals[e.vehicleId] ?? 0) + e.amountCents;
      }
    }
    return totals;
  }

  /// Calcula o repasse base acordado com o proprietário (antes de descontos de despesas).
  /// Retorna `null` para veículos próprios ou quando depende do preço e [priceCents] não foi informado.
  static int? calculateOwnerBasePayoutCents(
    Vehicle vehicle, {
    int? priceCents,
  }) {
    if (!vehicle.isConsigned) return null;
    switch (vehicle.consignmentType) {
      case AppConstants.consignmentTypeCommissionPercent:
        if (priceCents == null) return null;
        final bps = vehicle.consignmentCommissionBps ?? 0;
        final commission = ((priceCents * bps) / 10000.0).round();
        final payout = priceCents - commission;
        return payout > 0 ? payout : 0;
      case AppConstants.consignmentTypeCommissionFixed:
        if (priceCents == null) return null;
        final payout = priceCents - vehicle.consignmentAgreementValueCents;
        return payout > 0 ? payout : 0;
      case AppConstants.consignmentTypeFixedPayout:
      default:
        return vehicle.consignmentAgreementValueCents;
    }
  }

  /// Calcula o repasse líquido devido ao proprietário após descontar despesas marcadas para desconto.
  static int? calculateOwnerNetPayoutCentsFromMap(
    Vehicle vehicle,
    Map<String, int> deductedByVehicle, {
    int? priceCents,
  }) {
    final base = calculateOwnerBasePayoutCents(vehicle, priceCents: priceCents);
    if (base == null) return null;
    final deducted = deductedByVehicle[vehicle.id] ?? 0;
    final net = base - deducted;
    return net > 0 ? net : 0;
  }

  /// Versão em lista de [calculateOwnerNetPayoutCentsFromMap].
  static int? calculateOwnerNetPayoutCents(
    Vehicle vehicle,
    List<Expense> expenses, {
    int? priceCents,
  }) {
    if (!vehicle.isConsigned) return null;
    int deducted = 0;
    for (final e in expenses) {
      if (e.vehicleId == vehicle.id && e.isValid && e.deductFromConsignmentPayout) {
        deducted += e.amountCents;
      }
    }
    final base = calculateOwnerBasePayoutCents(vehicle, priceCents: priceCents);
    if (base == null) return null;
    final net = base - deducted;
    return net > 0 ? net : 0;
  }

  /// Saldo restante a repassar ao proprietário em um veículo consignado vendido.
  static int calculateOwnerPayoutDueCentsFromMap(
    Vehicle vehicle,
    Map<String, int> deductedByVehicle,
  ) {
    if (!vehicle.isConsigned || vehicle.activeSale == null) return 0;
    final net = calculateOwnerNetPayoutCentsFromMap(
          vehicle,
          deductedByVehicle,
          priceCents: vehicle.activeSale!.salePriceCents,
        ) ??
        0;
    final due = net - vehicle.activeSale!.totalOwnerPayoutPaidCents;
    return due > 0 ? due : 0;
  }

  /// Versão em lista de [calculateOwnerPayoutDueCentsFromMap].
  static int calculateOwnerPayoutDueCents(Vehicle vehicle, List<Expense> expenses) {
    if (!vehicle.isConsigned || vehicle.activeSale == null) return 0;
    final net = calculateOwnerNetPayoutCents(
          vehicle,
          expenses,
          priceCents: vehicle.activeSale!.salePriceCents,
        ) ??
        0;
    final due = net - vehicle.activeSale!.totalOwnerPayoutPaidCents;
    return due > 0 ? due : 0;
  }

  /// Calcula o custo próprio investido usando mapa pré-agregado O(1).
  /// Para próprios: compra + despesas válidas. Para consignados: apenas despesas válidas da loja.
  static int calculateVehicleTotalCostFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle,
  ) {
    final base = vehicle.isConsigned ? 0 : vehicle.purchasePriceCents;
    return base + (expensesByVehicle[vehicle.id] ?? 0);
  }

  /// Lucro estimado usando mapa pré-agregado O(1)
  static int? calculateEstimatedProfitFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle, {
    Map<String, int> deductedByVehicle = const {},
  }) {
    if (vehicle.announcedPriceCents == null) return null;
    if (vehicle.isConsigned) {
      final netPayout = calculateOwnerNetPayoutCentsFromMap(
        vehicle,
        deductedByVehicle,
        priceCents: vehicle.announcedPriceCents,
      );
      if (netPayout == null) return null;
      return vehicle.announcedPriceCents! -
          netPayout -
          (expensesByVehicle[vehicle.id] ?? 0);
    }
    return vehicle.announcedPriceCents! -
        calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
  }

  /// Lucro realizado usando mapa pré-agregado O(1)
  static int? calculateRealizedProfitFromMap(
    Vehicle vehicle,
    Map<String, int> expensesByVehicle, {
    Map<String, int> deductedByVehicle = const {},
  }) {
    if (vehicle.activeSale == null) return null;
    if (vehicle.isConsigned) {
      final netPayout = calculateOwnerNetPayoutCentsFromMap(
            vehicle,
            deductedByVehicle,
            priceCents: vehicle.activeSale!.salePriceCents,
          ) ??
          0;
      return vehicle.activeSale!.salePriceCents -
          netPayout -
          (expensesByVehicle[vehicle.id] ?? 0);
    }
    return vehicle.activeSale!.salePriceCents -
        calculateVehicleTotalCostFromMap(vehicle, expensesByVehicle);
  }

  /// Calcula o custo próprio investido no veículo: compra (se próprio) + despesas válidas
  static int calculateVehicleTotalCost(Vehicle vehicle, List<Expense> expenses) {
    int total = vehicle.isConsigned ? 0 : vehicle.purchasePriceCents;
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

  /// Lucro estimado para carro em estoque com preço anunciado
  static int? calculateEstimatedProfit(Vehicle vehicle, List<Expense> expenses) {
    if (vehicle.announcedPriceCents == null) return null;
    if (vehicle.isConsigned) {
      final netPayout = calculateOwnerNetPayoutCents(
        vehicle,
        expenses,
        priceCents: vehicle.announcedPriceCents,
      );
      if (netPayout == null) return null;
      final totalExpenses = calculateVehicleTotalCost(vehicle, expenses);
      return vehicle.announcedPriceCents! - netPayout - totalExpenses;
    }
    final totalCost = calculateVehicleTotalCost(vehicle, expenses);
    return vehicle.announcedPriceCents! - totalCost;
  }

  /// Lucro realizado por carro vendido (preço final negociado - repasse/compra - despesas válidas)
  static int? calculateRealizedProfit(Vehicle vehicle, List<Expense> expenses) {
    if (vehicle.activeSale == null) return null;
    if (vehicle.isConsigned) {
      final netPayout = calculateOwnerNetPayoutCents(
            vehicle,
            expenses,
            priceCents: vehicle.activeSale!.salePriceCents,
          ) ??
          0;
      final totalExpenses = calculateVehicleTotalCost(vehicle, expenses);
      return vehicle.activeSale!.salePriceCents - netPayout - totalExpenses;
    }
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

  /// Calcula quantos dias o veículo ficou (ou está) no pátio entre entrada e venda/devolução/hoje.
  static int calculateDaysInStock(Vehicle vehicle, {DateTime? now}) {
    final start = _parseIsoLocalDate(vehicle.purchaseDate);
    if (start == null) return 0;

    final refNow = now ?? DateTime.now();
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final DateTime end;
    if (vehicle.activeSale != null) {
      end = _parseIsoLocalDate(vehicle.activeSale!.saleDate) ?? today;
    } else if (vehicle.isReturned && vehicle.consignmentReturnedDate != null) {
      end = _parseIsoLocalDate(vehicle.consignmentReturnedDate!) ?? today;
    } else {
      end = today;
    }

    return end.difference(start).inDays.clamp(0, 100000);
  }

  /// Calcula o retorno sobre o investimento (ROI %) considerando lucro e custo total.
  static double? calculateRoiPercent(int profitCents, int totalCostCents) {
    if (totalCostCents <= 0) return null;
    return (profitCents / totalCostCents) * 100.0;
  }

  /// Calcula o percentual exibido na linha/ficha do veículo:
  /// - Próprio: ROI % sobre custo total
  /// - Consignado: Margem % sobre o preço de referência (venda ou anúncio)
  static double? calculateVehiclePercentMetric(
    Vehicle vehicle, {
    required int profitCents,
    required int totalCostCents,
    required int? priceCents,
  }) {
    if (vehicle.isConsigned) {
      if (priceCents == null || priceCents <= 0) return null;
      return (profitCents / priceCents) * 100.0;
    }
    return calculateRoiPercent(profitCents, totalCostCents);
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
    final deductedByVehicle = aggregateDeductedExpensesByVehicle(allExpenses);

    // 1. Lucro, custo/repasse efetivo e giro dos carros vendidos no mês
    int soldVehiclesProfitCents = 0;
    int soldVehiclesCostCents = 0;
    int soldInMonthCount = 0;
    int soldDaysSum = 0;

    for (final vehicle in allVehicles) {
      if (vehicle.activeSale != null && vehicle.activeSale!.saleDate.startsWith(monthPrefix)) {
        soldInMonthCount++;
        final vehicleExpenses = expensesByVehicle[vehicle.id] ?? 0;
        final effectiveCost = vehicle.isConsigned
            ? ((calculateOwnerNetPayoutCentsFromMap(
                      vehicle,
                      deductedByVehicle,
                      priceCents: vehicle.activeSale!.salePriceCents,
                    ) ??
                    0) +
                vehicleExpenses)
            : (vehicle.purchasePriceCents + vehicleExpenses);
        soldVehiclesCostCents += effectiveCost;
        soldDaysSum += calculateDaysInStock(vehicle, now: now);
        final profit = vehicle.activeSale!.salePriceCents - effectiveCost;
        soldVehiclesProfitCents += profit;
      }
    }

    final soldInMonthRoiPercent = soldInMonthCount > 0
        ? calculateRoiPercent(soldVehiclesProfitCents, soldVehiclesCostCents)
        : null;
    final avgDaysToSell = soldInMonthCount > 0 ? soldDaysSum / soldInMonthCount : null;

    // 2. Entradas no mês (recebimentos de compradores)
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

    // 3. Saídas no mês (compras próprias + repasses pagos a consignantes + despesas do mês)
    int monthExpensesCents = 0;
    for (final vehicle in allVehicles) {
      if (!vehicle.isConsigned && vehicle.purchaseDate.startsWith(monthPrefix)) {
        monthExpensesCents += vehicle.purchasePriceCents;
      }
      if (vehicle.isConsigned && vehicle.activeSale != null) {
        for (final payout in vehicle.activeSale!.ownerPayouts) {
          if (payout.isValid && payout.date.startsWith(monthPrefix)) {
            monthExpensesCents += payout.amountCents;
          }
        }
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
    int consignedStockCount = 0;
    int stockAgeSum = 0;
    int stagnantStockCount = 0;

    for (final vehicle in allVehicles) {
      if (vehicle.isInStock) {
        stockCount++;
        if (vehicle.isConsigned) {
          consignedStockCount++;
        }
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

    // 6. A receber hoje e repasses pendentes a consignantes
    int toReceiveTodayCents = 0;
    int pendingReceiveVehiclesCount = 0;
    int toPayConsignorsTodayCents = 0;
    int pendingPayoutVehiclesCount = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.isSold) {
        final due = calculateBalanceDue(vehicle);
        toReceiveTodayCents += due;
        if (due > 0) pendingReceiveVehiclesCount++;

        if (vehicle.isConsigned) {
          final payoutDue = calculateOwnerPayoutDueCentsFromMap(
            vehicle,
            deductedByVehicle,
          );
          toPayConsignorsTodayCents += payoutDue;
          if (payoutDue > 0) pendingPayoutVehiclesCount++;
        }
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
      consignedStockCount: consignedStockCount,
      toPayConsignorsTodayCents: toPayConsignorsTodayCents,
      pendingPayoutVehiclesCount: pendingPayoutVehiclesCount,
    );
  }

  /// Indica se a margem prevista está negativa ou apertada (ROI abaixo do mínimo configurado).
  static bool isTightMargin(int? estimatedProfitCents, int totalCostCents) {
    if (estimatedProfitCents == null) return false;
    if (estimatedProfitCents < 0) return true;
    final roi = calculateRoiPercent(estimatedProfitCents, totalCostCents);
    return roi != null && roi < AppConstants.lowMarginRoiThresholdPercent;
  }

  /// Versão ciente de veículo consignado: para consignados, alerta apenas prejuízo previsto (< 0).
  static bool isTightMarginForVehicle(
    Vehicle vehicle,
    int? estimatedProfitCents,
    int totalCostCents,
  ) {
    if (estimatedProfitCents == null) return false;
    if (estimatedProfitCents < 0) return true;
    if (vehicle.isConsigned) return false;
    return isTightMargin(estimatedProfitCents, totalCostCents);
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
    final deductedByVehicle = aggregateDeductedExpensesByVehicle(allExpenses);

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
      final acquisitionOrPayout = vehicle.isConsigned
          ? (calculateOwnerNetPayoutCentsFromMap(
                vehicle,
                deductedByVehicle,
                priceCents: sale.salePriceCents,
              ) ??
              0)
          : vehicle.purchasePriceCents;
      final totalCost = acquisitionOrPayout + vehicleExpenses;
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
      modelAcc.totalPurchaseCents += acquisitionOrPayout;
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

