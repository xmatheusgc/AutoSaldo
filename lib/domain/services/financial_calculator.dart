import '../models/expense.dart';
import '../models/monthly_summary.dart';
import '../models/vehicle.dart';

class FinancialCalculator {
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

  /// Calcula todos os indicadores do Resumo Mensal para um determinado mês/ano
  static MonthlySummary calculateMonthlySummary({
    required List<Vehicle> allVehicles,
    required List<Expense> allExpenses,
    required int year,
    required int month,
  }) {
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';

    // 1. Lucro dos carros vendidos no mês
    // Somar o lucro por carro pela data da venda, incluindo gastos válidos lançados posteriormente.
    int soldVehiclesProfitCents = 0;
    int soldInMonthCount = 0;

    for (final vehicle in allVehicles) {
      if (vehicle.activeSale != null && vehicle.activeSale!.saleDate.startsWith(monthPrefix)) {
        soldInMonthCount++;
        final profit = calculateRealizedProfit(vehicle, allExpenses);
        if (profit != null) {
          soldVehiclesProfitCents += profit;
        }
      }
    }

    // 2. Entradas no mês
    // Somar recebimentos válidos pela data do recebimento, inclusive de carros vendidos em outros meses.
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

    // 3. Saídas no mês
    // Somar compras pela data da compra e despesas válidas pela data do pagamento.
    int monthExpensesCents = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.purchaseDate.startsWith(monthPrefix)) {
        monthExpensesCents += vehicle.purchasePriceCents;
      }
    }
    for (final expense in allExpenses) {
      if (expense.isValid && expense.date.startsWith(monthPrefix)) {
        monthExpensesCents += expense.amountCents;
      }
    }

    // 4. Saldo do mês = Entradas - Saídas
    final monthNetCashCents = monthIncomeCents - monthExpensesCents;

    // 5. Investido no estoque atual (carros atualmente em estoque, independente do mês)
    int currentStockInvestmentCents = 0;
    int stockCount = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.isInStock) {
        stockCount++;
        currentStockInvestmentCents += calculateVehicleTotalCost(vehicle, allExpenses);
      }
    }

    // 6. A receber hoje (saldo das vendas ativas, independente do mês)
    int toReceiveTodayCents = 0;
    for (final vehicle in allVehicles) {
      if (vehicle.isSold) {
        toReceiveTodayCents += calculateBalanceDue(vehicle);
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
    );
  }
}

