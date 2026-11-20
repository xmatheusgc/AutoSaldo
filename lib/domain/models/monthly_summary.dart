class MonthlySummary {
  final int year;
  final int month;
  final int soldVehiclesProfitCents;
  final int monthIncomeCents;
  final int monthExpensesCents;
  final int monthNetCashCents;
  final int currentStockInvestmentCents;
  final int toReceiveTodayCents;
  final int soldCount;
  final int stockCount;
  final int soldVehiclesCostCents;
  final double? soldInMonthRoiPercent;
  final double? avgDaysToSell;
  final double? avgStockAgeDays;
  final int stagnantStockCount;
  final Map<String, int> monthExpensesByCategory;
  final int pendingReceiveVehiclesCount;

  MonthlySummary({
    required this.year,
    required this.month,
    required this.soldVehiclesProfitCents,
    required this.monthIncomeCents,
    required this.monthExpensesCents,
    required this.monthNetCashCents,
    required this.currentStockInvestmentCents,
    required this.toReceiveTodayCents,
    required this.soldCount,
    required this.stockCount,
    this.soldVehiclesCostCents = 0,
    this.soldInMonthRoiPercent,
    this.avgDaysToSell,
    this.avgStockAgeDays,
    this.stagnantStockCount = 0,
    this.monthExpensesByCategory = const {},
    this.pendingReceiveVehiclesCount = 0,
  });
}

