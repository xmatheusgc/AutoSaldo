import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/data/repositories/expense_repository.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/data/services/fipe_service.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/payment.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/domain/services/csv_exporter.dart';
import 'package:autosaldo/domain/services/financial_calculator.dart';
import 'package:autosaldo/presentation/screens/expenses/expense_form_dialog.dart';
import 'package:autosaldo/presentation/screens/stock/stock_screen.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_detail_screen.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_form_screen.dart';
import 'package:autosaldo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MockVehicleRepository implements VehicleRepository {
  final List<Vehicle> vehicles;
  Vehicle? lastSavedVehicle;
  Payment? lastAddedOwnerPayout;
  String? lastReturnedVehicleId;

  _MockVehicleRepository(this.vehicles);

  @override
  Stream<List<Vehicle>> getVehiclesStream(String workspaceId) =>
      Stream.value(vehicles);

  @override
  Stream<Vehicle?> getVehicleStream(String workspaceId, String vehicleId) {
    final matches = vehicles.where((v) => v.id == vehicleId);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  @override
  Future<bool> hasStockDuplicate(
    String workspaceId, {
    required String plate,
    String? renavam,
    String? excludeVehicleId,
  }) async =>
      false;

  @override
  Future<String> saveVehicle(
    String workspaceId,
    Vehicle vehicle,
    String userUid, {
    String? userEmail,
  }) async {
    lastSavedVehicle = vehicle;
    return 'saved_id_1';
  }

  @override
  Future<void> addOwnerPayout({
    required String workspaceId,
    required String vehicleId,
    required Payment payout,
    required int maxNetPayoutCents,
    required String userUid,
  }) async {
    lastAddedOwnerPayout = payout;
  }

  @override
  Future<void> returnConsignedVehicle({
    required String workspaceId,
    required String vehicleId,
    required String returnedDate,
    String? notes,
    required String userUid,
  }) async {
    lastReturnedVehicleId = vehicleId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockExpenseRepository implements ExpenseRepository {
  final List<Expense> expenses;
  Expense? lastCreatedExpense;

  _MockExpenseRepository(this.expenses);

  @override
  Stream<List<Expense>> getExpensesStream(String workspaceId) =>
      Stream.value(expenses);

  @override
  Stream<List<Expense>> getVehicleExpensesStream(
    String workspaceId,
    String vehicleId,
  ) =>
      Stream.value(expenses.where((e) => e.vehicleId == vehicleId).toList());

  @override
  Future<String> createExpense(
    String workspaceId,
    Expense expense,
    String userUid, {
    String? userEmail,
  }) async {
    lastCreatedExpense = expense;
    return 'exp_new';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Consigned Vehicle Domain & Financial Calculations', () {
    test('Serialization preserves consignment fields and defaults legacy maps to own', () {
      final now = DateTime(2026, 11, 1);
      final legacy = Vehicle.fromMap('legacy1', {
        'brand': 'Fiat',
        'model': 'Uno',
        'plate': 'ABC1234',
        'purchaseDate': '2026-10-01',
        'purchasePriceCents': 2500000,
      });
      expect(legacy.isOwn, isTrue);
      expect(legacy.isConsigned, isFalse);
      expect(legacy.isInStock, isTrue);

      final consigned = Vehicle(
        id: 'c1',
        brand: 'Honda',
        model: 'Civic',
        plate: 'BRA2E19',
        purchaseDate: '2026-10-05',
        purchasePriceCents: 0,
        announcedPriceCents: 8500000,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeCommissionPercent,
        consignmentCommissionBps: 500, // 5%
        consignorName: 'Maria Oliveira',
        consignorPhone: '11999998888',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final roundTrip = Vehicle.fromMap('c1', consigned.toMap());
      expect(roundTrip.isConsigned, isTrue);
      expect(roundTrip.consignmentType, AppConstants.consignmentTypeCommissionPercent);
      expect(roundTrip.consignmentCommissionBps, 500);
      expect(roundTrip.consignorName, 'Maria Oliveira');
      expect(roundTrip.consignorPhone, '11999998888');
    });

    test('Fixed payout, commission %, commission fixed, and deducted expenses calculate accurately', () {
      final now = DateTime(2026, 11, 1);

      // 1. Repasse fixo: R$ 50.000, venda R$ 60.000
      //    Despesa da loja (lavagem): R$ 500 (não desconta)
      //    Despesa descontada do dono (oficina): R$ 2.000 (desconta do repasse)
      //    -> Repasse líquido = 50.000 - 2.000 = 48.000
      //    -> Lucro da loja = 60.000 - 48.000 - (500 + 2.000) = 9.500
      final vFixed = Vehicle(
        id: 'cf1',
        brand: 'VW',
        model: 'T-Cross',
        plate: 'AAA1111',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 0,
        announcedPriceCents: 6000000,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeFixedPayout,
        consignmentAgreementValueCents: 5000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
        activeSale: ActiveSale(
          id: 's1',
          saleDate: '2026-10-15',
          salePriceCents: 6000000,
          payments: [
            Payment(
              id: 'p1',
              amountCents: 6000000,
              date: '2026-10-15',
              createdAt: now,
              createdByUid: 'u1',
            ),
          ],
          ownerPayouts: [
            Payment(
              id: 'po1',
              amountCents: 3000000,
              date: '2026-10-20',
              createdAt: now,
              createdByUid: 'u1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      );

      final expenses = [
        Expense(
          id: 'e1',
          vehicleId: 'cf1',
          amountCents: 50000,
          date: '2026-10-02',
          category: AppConstants.expenseCategoryCarWash,
          deductFromConsignmentPayout: false,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
        Expense(
          id: 'e2',
          vehicleId: 'cf1',
          amountCents: 200000,
          date: '2026-10-03',
          category: AppConstants.expenseCategoryWorkshop,
          deductFromConsignmentPayout: true,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      ];

      expect(
        FinancialCalculator.calculateOwnerNetPayoutCents(
          vFixed,
          expenses,
          priceCents: 6000000,
        ),
        4800000,
      );
      expect(FinancialCalculator.calculateOwnerPayoutDueCents(vFixed, expenses), 1800000);
      expect(FinancialCalculator.calculateRealizedProfit(vFixed, expenses), 950000);

      // 2. Comissão percentual: 5% sobre R$ 80.000 = R$ 4.000 comissão, R$ 76.000 repasse
      final vPct = Vehicle(
        id: 'cp1',
        brand: 'Toyota',
        model: 'Corolla',
        plate: 'BBB2222',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 0,
        announcedPriceCents: 8000000,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeCommissionPercent,
        consignmentCommissionBps: 500,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );
      expect(
        FinancialCalculator.calculateOwnerBasePayoutCents(vPct, priceCents: 8000000),
        7600000,
      );
      expect(FinancialCalculator.calculateEstimatedProfit(vPct, []), 400000);
      expect(
        FinancialCalculator.isTightMarginForVehicle(vPct, 400000, 0),
        isFalse,
      );

      // 3. Comissão fixa: R$ 3.500 sobre anunciado R$ 50.000 -> repasse R$ 46.500
      final vComFixed = Vehicle(
        id: 'ccf1',
        brand: 'Chevrolet',
        model: 'Onix',
        plate: 'CCC3333',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 0,
        announcedPriceCents: 5000000,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeCommissionFixed,
        consignmentAgreementValueCents: 350000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );
      expect(
        FinancialCalculator.calculateOwnerBasePayoutCents(vComFixed, priceCents: 5000000),
        4650000,
      );
      expect(FinancialCalculator.calculateEstimatedProfit(vComFixed, []), 350000);
    });

    test('MonthlySummary excludes consigned acquisition from stock investment and counts payouts on payout date', () {
      final now = DateTime(2026, 10, 25);
      final consignedSold = Vehicle(
        id: 'c_sold',
        brand: 'Jeep',
        model: 'Compass',
        plate: 'AAA1111',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 0,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeFixedPayout,
        consignmentAgreementValueCents: 9000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
        activeSale: ActiveSale(
          id: 's1',
          saleDate: '2026-10-10',
          salePriceCents: 10000000,
          payments: [
            Payment(
              id: 'p1',
              amountCents: 10000000,
              date: '2026-10-10',
              createdAt: now,
              createdByUid: 'u1',
            ),
          ],
          ownerPayouts: [
            Payment(
              id: 'po1',
              amountCents: 5000000,
              date: '2026-10-12',
              createdAt: now,
              createdByUid: 'u1',
            ),
            Payment(
              id: 'po2',
              amountCents: 4000000,
              date: '2026-11-05',
              createdAt: now,
              createdByUid: 'u1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      );

      final consignedInStock = Vehicle(
        id: 'c_stock',
        brand: 'Hyundai',
        model: 'Creta',
        plate: 'BBB2222',
        purchaseDate: '2026-10-05',
        purchasePriceCents: 0,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeFixedPayout,
        consignmentAgreementValueCents: 7500000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final consignedReturned = Vehicle(
        id: 'c_ret',
        brand: 'Ford',
        model: 'Ka',
        plate: 'CCC3333',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 0,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeFixedPayout,
        consignmentAgreementValueCents: 3000000,
        consignmentReturnedDate: '2026-10-11',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final expenses = [
        Expense(
          id: 'e1',
          vehicleId: 'c_stock',
          amountCents: 30000,
          date: '2026-10-06',
          category: AppConstants.expenseCategoryCarWash,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      ];

      expect(consignedReturned.isInStock, isFalse);
      expect(consignedReturned.isReturned, isTrue);
      expect(FinancialCalculator.calculateDaysInStock(consignedReturned, now: now), 10);

      final octSummary = FinancialCalculator.calculateMonthlySummary(
        allVehicles: [consignedSold, consignedInStock, consignedReturned],
        allExpenses: expenses,
        year: 2026,
        month: 10,
        now: now,
      );

      expect(octSummary.stockCount, 1); // apenas c_stock (c_ret devolvido)
      expect(octSummary.consignedStockCount, 1);
      // Capital próprio investido no pátio: apenas R$ 300 de despesa do c_stock (não soma R$ 75.000)
      expect(octSummary.currentStockInvestmentCents, 30000);
      expect(octSummary.monthIncomeCents, 10000000);
      // Saídas em Outubro: R$ 50.000 repasse + R$ 300 despesa
      expect(octSummary.monthExpensesCents, 5030000);
      expect(octSummary.soldVehiclesProfitCents, 1000000);
      // Ambos po1 (Out) e po2 (Nov) já constam como pagos no total
      expect(octSummary.toPayConsignorsTodayCents, 0);

      final novSummary = FinancialCalculator.calculateMonthlySummary(
        allVehicles: [consignedSold, consignedInStock, consignedReturned],
        allExpenses: expenses,
        year: 2026,
        month: 11,
        now: now,
      );
      expect(novSummary.monthExpensesCents, 4000000); // segunda parcela do repasse em Novembro

      final csv = CsvExporter.generateCsv(
        vehicles: [consignedSold, consignedInStock, consignedReturned],
        expenses: expenses,
      );
      expect(csv, contains('Consignado'));
      expect(csv, contains('Devolvido'));
      expect(csv, contains('--- 4. REPASSES CONSIGNADOS ---'));
    });
  });

  group('Consigned Vehicle UI Flows', () {
    Future<void> setViewportSize(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('VehicleFormScreen saves consigned vehicle with fixed payout and consignor',
        (tester) async {
      final repo = _MockVehicleRepository(const []);
      final fipeService = FipeService(
        client: MockClient((request) async => http.Response('err', 500)),
      );
      addTearDown(fipeService.dispose);

      await setViewportSize(tester, const Size(1280, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VehicleFormScreen(
            workspaceId: 'ws1',
            userUid: 'u1',
            vehicleRepository: repo,
            fipeService: fipeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preencher marca, modelo, placa (modo manual pq FIPE retornou vazio)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Marca *'),
        'Honda',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Modelo *'),
        'HR-V',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Placa *'),
        'BRA2E19',
      );

      // Alternar para Consignado
      await tester.tap(find.text('Consignado'));
      await tester.pumpAndSettle();

      expect(find.text('Dados do Consignado'), findsOneWidget);
      expect(find.text('Valor de repasse ao proprietário *'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor de repasse ao proprietário *'),
        '8000000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Preço anunciado para venda (opcional)'),
        '9200000',
      );
      await tester.pumpAndSettle();

      // Prévia automática de repasse e comissão
      expect(find.text('Repasse estimado'), findsOneWidget);
      expect(find.textContaining('12.000,00'), findsOneWidget);

      await tester.ensureVisible(find.text('Concluir Cadastro'));
      await tester.tap(find.text('Concluir Cadastro'));
      await tester.pumpAndSettle();

      expect(repo.lastSavedVehicle, isNotNull);
      expect(repo.lastSavedVehicle!.isConsigned, isTrue);
      expect(repo.lastSavedVehicle!.purchasePriceCents, 0);
      expect(repo.lastSavedVehicle!.consignmentAgreementValueCents, 8000000);
      expect(repo.lastSavedVehicle!.announcedPriceCents, 9200000);
    });

    testWidgets('ExpenseFormDialog saves deductFromConsignmentPayout when toggled',
        (tester) async {
      final expenseRepo = _MockExpenseRepository(const []);

      await setViewportSize(tester, const Size(420, 860));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ExpenseFormDialog(
              workspaceId: 'ws1',
              vehicleId: 'c1',
              userUid: 'u1',
              expenseRepository: expenseRepo,
              isConsignedVehicle: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Descontar do repasse ao proprietário'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor da despesa *'),
        '150000',
      );
      await tester.tap(find.text('Descontar do repasse ao proprietário'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar Despesa'));
      await tester.pumpAndSettle();

      expect(expenseRepo.lastCreatedExpense, isNotNull);
      expect(expenseRepo.lastCreatedExpense!.deductFromConsignmentPayout, isTrue);
      expect(expenseRepo.lastCreatedExpense!.amountCents, 150000);
    });

    testWidgets('VehicleDetailScreen shows Consignado payout card and registers owner payout',
        (tester) async {
      final now = DateTime(2026, 11, 10);
      final consignedSold = Vehicle(
        id: 'c1',
        brand: 'Jeep',
        model: 'Renegade',
        plate: 'BRA2E19',
        purchaseDate: '2026-11-01',
        purchasePriceCents: 0,
        ownershipType: AppConstants.ownershipConsigned,
        consignmentType: AppConstants.consignmentTypeFixedPayout,
        consignmentAgreementValueCents: 7000000,
        consignorName: 'Carlos Silva',
        consignorPhone: '11988887777',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
        activeSale: ActiveSale(
          id: 's1',
          saleDate: '2026-11-05',
          salePriceCents: 8000000,
          payments: [
            Payment(
              id: 'p1',
              amountCents: 8000000,
              date: '2026-11-05',
              createdAt: now,
              createdByUid: 'u1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      );

      final vehicleRepo = _MockVehicleRepository([consignedSold]);
      final expenseRepo = _MockExpenseRepository(const []);

      await setViewportSize(tester, const Size(1280, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VehicleDetailScreen(
            workspaceId: 'ws1',
            vehicleId: 'c1',
            userUid: 'u1',
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consignado'), findsOneWidget);
      expect(find.text('Acerto com o Proprietário'), findsOneWidget);
      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.textContaining('Registrar repasse'), findsOneWidget);

      await tester.ensureVisible(find.textContaining('Registrar repasse'));
      await tester.tap(find.textContaining('Registrar repasse'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Repasse'), findsOneWidget);
      await tester.tap(find.text('Confirmar Repasse'));
      await tester.pumpAndSettle();

      expect(vehicleRepo.lastAddedOwnerPayout, isNotNull);
      expect(vehicleRepo.lastAddedOwnerPayout!.amountCents, 7000000);
    });

    testWidgets('StockScreen displays Consignado label and supports filtering by Consignados',
        (tester) async {
      final now = DateTime(2026, 11, 10);
      final vehicles = [
        Vehicle(
          id: 'own1',
          brand: 'VW',
          model: 'Gol',
          plate: 'AAA1111',
          purchaseDate: '2026-11-01',
          purchasePriceCents: 3500000,
          announcedPriceCents: 4200000,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
        Vehicle(
          id: 'con1',
          brand: 'Honda',
          model: 'Fit',
          plate: 'BBB2222',
          purchaseDate: '2026-11-02',
          purchasePriceCents: 0,
          announcedPriceCents: 6500000,
          ownershipType: AppConstants.ownershipConsigned,
          consignmentType: AppConstants.consignmentTypeFixedPayout,
          consignmentAgreementValueCents: 5800000,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      ];

      await setViewportSize(tester, const Size(420, 860));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StockScreen(
            workspaceId: 'ws1',
            userUid: 'u1',
            vehicleRepository: _MockVehicleRepository(vehicles),
            expenseRepository: _MockExpenseRepository(const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VW Gol'), findsOneWidget);
      expect(find.text('Honda Fit'), findsOneWidget);
      expect(find.text('Consignado'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Filtros'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Consignados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('VW Gol'), findsNothing);
      expect(find.text('Honda Fit'), findsOneWidget);
    });
  });
}
