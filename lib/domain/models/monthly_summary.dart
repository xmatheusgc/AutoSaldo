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
  });
}

