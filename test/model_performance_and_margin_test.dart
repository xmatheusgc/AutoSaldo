import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/data/repositories/expense_repository.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/model_performance.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/domain/services/financial_calculator.dart';
import 'package:autosaldo/presentation/screens/stock/stock_screen.dart';
import 'package:autosaldo/presentation/screens/summary/monthly_summary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeVehicleRepo extends VehicleRepository {
  final List<Vehicle> items;
  _FakeVehicleRepo(this.items) : super(firestore: _FakeFirestore());

  @override
  Stream<List<Vehicle>> getVehiclesStream(String workspaceId) => Stream.value(items);
}

class _FakeExpenseRepo extends ExpenseRepository {
  final List<Expense> items;
  _FakeExpenseRepo(this.items) : super(firestore: _FakeFirestore());

  @override
  Stream<List<Expense>> getExpensesStream(String workspaceId) => Stream.value(items);
}

Vehicle _makeVehicle({
  required String id,
  required String brand,
  required String model,
  required String purchaseDate,
  required int purchasePriceCents,
  int? announcedPriceCents,
  String? saleDate,
  int? salePriceCents,
}) {
  final now = DateTime(2026, 11, 1);
  return Vehicle(
    id: id,
    plate: 'ABC${id.padLeft(4, '0').substring(0, 4)}',
    brand: brand,
    model: model,
    purchaseDate: purchaseDate,
    purchasePriceCents: purchasePriceCents,
    announcedPriceCents: announcedPriceCents,
    activeSale: saleDate != null && salePriceCents != null
        ? ActiveSale(
            id: 'sale_$id',
            saleDate: saleDate,
            salePriceCents: salePriceCents,
            createdAt: now,
            updatedAt: now,
            createdByUid: 'u1',
            updatedByUid: 'u1',
          )
        : null,
    createdAt: now,
    updatedAt: now,
    createdByUid: 'u1',
    updatedByUid: 'u1',
  );
}

Expense _makeExpense({
  required String id,
  required String vehicleId,
  required int amountCents,
  String date = '2026-10-05',
}) {
  final now = DateTime(2026, 10, 5);
  return Expense(
    id: id,
    vehicleId: vehicleId,
    date: date,
    category: AppConstants.expenseCategoryWorkshop,
    amountCents: amountCents,
    createdAt: now,
    updatedAt: now,
    createdByUid: 'u1',
    updatedByUid: 'u1',
  );
}

void main() {
  group('FinancialCalculator model analytics & margin alerts', () {
    test('Groups models consistently across brand aliases, computes giro/ROI/expenses, and prioritizes recurring highlights', () {
      final vehicles = [
        // 2 vendas de Gol (VW + Volkswagen) com giro rápido (10d e 20d -> média 15d)
        _makeVehicle(
          id: '1',
          brand: 'VW',
          model: 'Gol',
          purchaseDate: '2026-10-01',
          purchasePriceCents: 3000000,
          saleDate: '2026-10-11',
          salePriceCents: 3700000,
        ),
        _makeVehicle(
          id: '2',
          brand: 'Volkswagen',
          model: ' gol ',
          purchaseDate: '2026-09-01',
          purchasePriceCents: 3200000,
          saleDate: '2026-09-21',
          salePriceCents: 4000000,
        ),
        // 1 Gol em estoque
        _makeVehicle(
          id: '3',
          brand: 'Volkswagen',
          model: 'Gol',
          purchaseDate: '2026-11-01',
          purchasePriceCents: 3500000,
        ),
        // 2 vendas de Onix com giro mais lento (30d e 50d -> 40d) e lucro médio maior
        _makeVehicle(
          id: '4',
          brand: 'Chevrolet',
          model: 'Onix',
          purchaseDate: '2026-08-01',
          purchasePriceCents: 4500000,
          saleDate: '2026-08-31',
          salePriceCents: 5500000,
        ),
        _makeVehicle(
          id: '5',
          brand: 'GM',
          model: 'Onix',
          purchaseDate: '2026-06-01',
          purchasePriceCents: 4600000,
          saleDate: '2026-07-21',
          salePriceCents: 5800000,
        ),
        // 1 venda isolada (1 dia) não deve roubar o destaque de giro rápido dos modelos com 2+ vendas
        _makeVehicle(
          id: '6',
          brand: 'Fiat',
          model: 'Uno',
          purchaseDate: '2026-11-10',
          purchasePriceCents: 2000000,
          saleDate: '2026-11-11',
          salePriceCents: 2300000,
        ),
      ];

      final expenses = [
        _makeExpense(id: 'e1', vehicleId: '1', amountCents: 100000), // Gol #1: custo 31k, lucro 6k
        _makeExpense(id: 'e2', vehicleId: '2', amountCents: 200000), // Gol #2: custo 34k, lucro 6k
        _makeExpense(id: 'e3', vehicleId: '4', amountCents: 100000), // Onix #1: custo 46k, lucro 9k
      ];

      final report = FinancialCalculator.calculateModelReport(
        allVehicles: vehicles,
        allExpenses: expenses,
        window: ModelAnalyticsWindow.allTime,
        now: DateTime(2026, 11, 20),
      );

      expect(report.totalSoldCount, 5);
      expect(report.models.length, 3);
      expect(report.brands.length, 3);

      final gol = report.models.firstWhere((m) => m.model.toLowerCase() == 'gol');
      expect(gol.brand, 'Volkswagen');
      expect(gol.soldCount, 2);
      expect(gol.inStockCount, 1);
      expect(gol.avgDaysToSell, 15.0);
      expect(gol.avgExpenseCents, 150000);
      expect(gol.totalProfitCents, 1200000);
      expect(gol.avgProfitCents, 600000);

      // Destaques priorizam modelos com >= 2 vendas (Gol bate Uno de 1 venda no giro; Onix lidera lucro médio)
      expect(report.fastestModel?.key, gol.key);
      expect(report.highestAvgProfitModel?.model, 'Onix');
    });

    test('Filters sold vehicles correctly by 6-month window', () {
      final vehicles = [
        _makeVehicle(
          id: 'old',
          brand: 'Ford',
          model: 'Ka',
          purchaseDate: '2025-12-01',
          purchasePriceCents: 2500000,
          saleDate: '2026-01-10',
          salePriceCents: 3000000,
        ),
        _makeVehicle(
          id: 'recent',
          brand: 'Honda',
          model: 'Civic',
          purchaseDate: '2026-09-01',
          purchasePriceCents: 7000000,
          saleDate: '2026-10-10',
          salePriceCents: 8000000,
        ),
      ];

      final report6m = FinancialCalculator.calculateModelReport(
        allVehicles: vehicles,
        allExpenses: [],
        window: ModelAnalyticsWindow.last6Months,
        now: DateTime(2026, 11, 20),
      );

      expect(report6m.totalSoldCount, 1);
      expect(report6m.models.single.model, 'Civic');
    });

    test('isTightMargin detects negative and < 5% ROI margins', () {
      expect(FinancialCalculator.isTightMargin(-50000, 3000000), isTrue);
      expect(FinancialCalculator.isTightMargin(100000, 3000000), isTrue); // 3.33%
      expect(FinancialCalculator.isTightMargin(200000, 3000000), isFalse); // 6.67%
      expect(FinancialCalculator.isTightMargin(null, 3000000), isFalse);
    });
  });

  group('UI integration for Por Modelo and Tight Margin alerts', () {
    testWidgets('MonthlySummaryScreen switches to Por Modelo tab and opens drill-down', (tester) async {
      final vehicles = [
        _makeVehicle(
          id: '1',
          brand: 'Volkswagen',
          model: 'Gol',
          purchaseDate: '2026-10-01',
          purchasePriceCents: 3000000,
          saleDate: '2026-10-15',
          salePriceCents: 3600000,
        ),
        _makeVehicle(
          id: '2',
          brand: 'Chevrolet',
          model: 'Onix',
          purchaseDate: '2026-09-01',
          purchasePriceCents: 4500000,
          saleDate: '2026-10-20',
          salePriceCents: 5400000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MonthlySummaryScreen(
            workspaceId: 'ws1',
            vehicleRepository: _FakeVehicleRepo(vehicles),
            expenseRepository: _FakeExpenseRepo([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Por Modelo'));
      await tester.pumpAndSettle();

      expect(find.text('Ranking por Modelo (2)'), findsOneWidget);
      expect(find.text('Desempenho por Marca'), findsOneWidget);
      expect(find.text('Giro mais rápido'), findsOneWidget);

      await tester.ensureVisible(find.text('Volkswagen Gol').first);
      await tester.tap(find.text('Volkswagen Gol').first);
      await tester.pumpAndSettle();

      expect(find.text('1 venda registrada'), findsOneWidget);
    });

    testWidgets('StockScreen shows Prejuízo previsto and Margem < 5% pills', (tester) async {
      final vehicles = [
        _makeVehicle(
          id: 'loss',
          brand: 'Fiat',
          model: 'Argo',
          purchaseDate: '2026-11-01',
          purchasePriceCents: 4800000,
          announcedPriceCents: 5000000,
        ),
        _makeVehicle(
          id: 'tight',
          brand: 'Hyundai',
          model: 'HB20',
          purchaseDate: '2026-11-02',
          purchasePriceCents: 5000000,
          announcedPriceCents: 5150000, // 3% ROI
        ),
      ];
      final expenses = [
        // Argo fica com custo 51k vs anunciado 50k -> prejuízo previsto
        _makeExpense(id: 'el1', vehicleId: 'loss', amountCents: 300000),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StockScreen(
            workspaceId: 'ws1',
            userUid: 'u1',
            vehicleRepository: _FakeVehicleRepo(vehicles),
            expenseRepository: _FakeExpenseRepo(expenses),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Prejuízo previsto'), findsOneWidget);
      expect(find.text('Margem < 5%'), findsOneWidget);
    });
  });
}
