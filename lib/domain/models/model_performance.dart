import 'vehicle.dart';

enum ModelAnalyticsWindow {
  allTime,
  last12Months,
  last6Months,
}

class ModelPerformanceStats {
  final String key;
  final String brand;
  final String model;
  final int soldCount;
  final int inStockCount;
  final int totalPurchaseCents;
  final int totalExpensesCents;
  final int totalCostCents;
  final int totalSaleCents;
  final int totalProfitCents;
  final int avgProfitCents;
  final int avgExpenseCents;
  final double avgDaysToSell;
  final double? roiPercent;
  final List<Vehicle> soldVehicles;

  const ModelPerformanceStats({
    required this.key,
    required this.brand,
    required this.model,
    required this.soldCount,
    required this.inStockCount,
    required this.totalPurchaseCents,
    required this.totalExpensesCents,
    required this.totalCostCents,
    required this.totalSaleCents,
    required this.totalProfitCents,
    required this.avgProfitCents,
    required this.avgExpenseCents,
    required this.avgDaysToSell,
    required this.roiPercent,
    required this.soldVehicles,
  });

  String get displayName => '$brand $model'.trim();
}

class BrandPerformanceStats {
  final String brand;
  final int soldCount;
  final int totalCostCents;
  final int totalProfitCents;
  final double avgDaysToSell;
  final double? roiPercent;

  const BrandPerformanceStats({
    required this.brand,
    required this.soldCount,
    required this.totalCostCents,
    required this.totalProfitCents,
    required this.avgDaysToSell,
    required this.roiPercent,
  });
}

class PortfolioModelReport {
  final ModelAnalyticsWindow window;
  final int totalSoldCount;
  final int totalProfitCents;
  final int totalCostCents;
  final double? overallAvgDaysToSell;
  final double? overallRoiPercent;
  final List<ModelPerformanceStats> models;
  final List<BrandPerformanceStats> brands;
  final ModelPerformanceStats? fastestModel;
  final ModelPerformanceStats? highestAvgProfitModel;
  final ModelPerformanceStats? bestRoiModel;
  final ModelPerformanceStats? highestTotalProfitModel;

  const PortfolioModelReport({
    required this.window,
    required this.totalSoldCount,
    required this.totalProfitCents,
    required this.totalCostCents,
    required this.overallAvgDaysToSell,
    required this.overallRoiPercent,
    required this.models,
    required this.brands,
    required this.fastestModel,
    required this.highestAvgProfitModel,
    required this.bestRoiModel,
    required this.highestTotalProfitModel,
  });
}
