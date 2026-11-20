import 'dart:convert';
import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/core/formatters.dart';
import 'package:autosaldo/data/repositories/expense_repository.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/data/services/fipe_service.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/payment.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/presentation/screens/expenses/expense_form_dialog.dart';
import 'package:autosaldo/presentation/screens/sales/sale_form_dialog.dart';
import 'package:autosaldo/presentation/screens/stock/stock_screen.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_detail_screen.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_form_screen.dart';
import 'package:autosaldo/presentation/screens/summary/monthly_summary_screen.dart';
import 'package:autosaldo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _RecordingVehicleRepository implements VehicleRepository {
  final List<Vehicle> vehicles;
  ActiveSale? lastRegisteredSale;
  bool? lastCancelRevertAtomically;
  String? lastCancelledVehicleId;

  _RecordingVehicleRepository(this.vehicles);

  @override
  Stream<List<Vehicle>> getVehiclesStream(String workspaceId) =>
      Stream.value(vehicles);

  @override
  Stream<Vehicle?> getVehicleStream(String workspaceId, String vehicleId) {
    final matches = vehicles.where((v) => v.id == vehicleId);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  @override
  Future<void> registerSale({
    required String workspaceId,
    required String vehicleId,
    required ActiveSale sale,
    required String userUid,
    String? userEmail,
  }) async {
    lastRegisteredSale = sale;
  }

  @override
  Future<void> cancelSale({
    required String workspaceId,
    required String vehicleId,
    required String userUid,
    bool revertPaymentsAtomically = false,
  }) async {
    lastCancelledVehicleId = vehicleId;
    lastCancelRevertAtomically = revertPaymentsAtomically;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingExpenseRepository implements ExpenseRepository {
  final List<Expense> expenses;
  Expense? lastUpdatedExpense;

  _RecordingExpenseRepository(this.expenses);

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
  Future<void> updateExpense(
    String workspaceId,
    Expense expense,
    String userUid, {
    String? userEmail,
  }) async {
    lastUpdatedExpense = expense;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Vehicle> _buildSampleVehicles() {
  final now = DateTime.now();
  final currentMonthPrefix =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final oldDate = Formatters.toIsoDate(now.subtract(const Duration(days: 55)));
  final recentDate = Formatters.toIsoDate(now.subtract(const Duration(days: 3)));
  final saleDate = '$currentMonthPrefix-05';
  final safeSaleDate =
      saleDate.compareTo(Formatters.todayIsoDate()) > 0 ? Formatters.todayIsoDate() : saleDate;

  return [
    Vehicle(
      id: 'v1',
      brand: 'Volkswagen',
      model: 'Gol',
      version: '1.6 MSI',
      plate: 'ABC1234',
      purchaseDate: recentDate,
      purchasePriceCents: 3500000,
      announcedPriceCents: 4500000,
      manufactureYear: 2021,
      modelYear: 2022,
      renavam: '00123456789',
      docStatus: AppConstants.docStatusUpToDate,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
      createdByEmail: 'teste@autosaldo.com',
    ),
    Vehicle(
      id: 'v2',
      brand: 'Honda',
      model: 'Civic',
      version: 'EXL 2.0',
      plate: 'BRA2E19',
      purchaseDate: oldDate,
      purchasePriceCents: 8000000,
      manufactureYear: 2020,
      modelYear: 2021,
      docStatus: AppConstants.docStatusWithIssue,
      activeSale: ActiveSale(
        id: 's1',
        saleDate: safeSaleDate,
        salePriceCents: 9500000,
        payments: [
          Payment(
            id: 'p1',
            amountCents: 5000000,
            date: safeSaleDate,
            createdAt: now,
            createdByUid: 'u1',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      ),
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    ),
    Vehicle(
      id: 'v3',
      brand: 'Fiat',
      model: 'Uno',
      version: 'Attractive 1.0',
      plate: 'XYZ9876',
      purchaseDate: oldDate,
      purchasePriceCents: 2800000,
      announcedPriceCents: 3500000,
      docStatus: AppConstants.docStatusPendingCheck,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    ),
  ];
}

List<Expense> _buildSampleExpenses() {
  final now = DateTime.now();
  final today = Formatters.todayIsoDate();
  return [
    Expense(
      id: 'e1',
      vehicleId: 'v1',
      amountCents: 150000,
      date: today,
      category: AppConstants.expenseCategoryWorkshop,
      description: 'Troca de pastilhas',
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    ),
  ];
}

void main() {
  Future<void> setViewportSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('SaleFormDialog registers Entrada + Restante payment cleanly',
      (tester) async {
    final vehicles = _buildSampleVehicles();
    final vehicleRepo = _RecordingVehicleRepository(vehicles);

    await setViewportSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: SaleFormDialog(
                        workspaceId: 'ws1',
                        vehicle: vehicles.first,
                        totalCostCents: 3650000,
                        userUid: 'u1',
                        vehicleRepository: vehicleRepo,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir Venda'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Venda'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrada'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da entrada hoje *'),
      '1500000',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Restante a receber depois'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar Venda'));
    await tester.pumpAndSettle();

    expect(vehicleRepo.lastRegisteredSale, isNotNull);
    expect(vehicleRepo.lastRegisteredSale!.payments.length, 1);
    expect(vehicleRepo.lastRegisteredSale!.payments.first.amountCents, 1500000);
  });

  testWidgets('ExpenseFormDialog edits an existing expense via updateExpense',
      (tester) async {
    final expenses = _buildSampleExpenses();
    final expenseRepo = _RecordingExpenseRepository(expenses);

    await setViewportSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ExpenseFormDialog(
            workspaceId: 'ws1',
            vehicleId: 'v1',
            userUid: 'u1',
            expenseRepository: expenseRepo,
            expenseToEdit: expenses.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar Despesa'), findsOneWidget);
    expect(find.text('1.500,00'), findsOneWidget);
    expect(find.text('Troca de pastilhas'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor da despesa *'),
      '180000',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar Alterações'));
    await tester.pumpAndSettle();

    expect(expenseRepo.lastUpdatedExpense, isNotNull);
    expect(expenseRepo.lastUpdatedExpense!.id, 'e1');
    expect(expenseRepo.lastUpdatedExpense!.amountCents, 180000);
  });

  testWidgets('VehicleDetailScreen supports atomic sale cancellation when payments exist',
      (tester) async {
    final vehicles = _buildSampleVehicles();
    final expenses = _buildSampleExpenses();
    final vehicleRepo = _RecordingVehicleRepository(vehicles);
    final expenseRepo = _RecordingExpenseRepository(expenses);

    await setViewportSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: VehicleDetailScreen(
          workspaceId: 'ws1',
          vehicleId: 'v2',
          userUid: 'u1',
          vehicleRepository: vehicleRepo,
          expenseRepository: expenseRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancelar venda e retornar ao estoque'));
    await tester.tap(find.text('Cancelar venda e retornar ao estoque'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar Venda e Estornar'), findsOneWidget);
    await tester.tap(find.text('Cancelar e Estornar'));
    await tester.pumpAndSettle();

    expect(vehicleRepo.lastCancelledVehicleId, 'v2');
    expect(vehicleRepo.lastCancelRevertAtomically, isTrue);
  });

  testWidgets('VehicleFormScreen collapses CRLV-e on mobile until tapped',
      (tester) async {
    final vehicleRepo = _RecordingVehicleRepository(const []);
    final fipeService = FipeService(
      client: MockClient((request) async => http.Response(jsonEncode([]), 200)),
    );
    addTearDown(fipeService.dispose);

    await setViewportSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: VehicleFormScreen(
          workspaceId: 'ws1',
          userUid: 'u1',
          vehicleRepository: vehicleRepo,
          fipeService: fipeService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Documentação (CRLV-e)'), findsOneWidget);
    expect(find.text('Código RENAVAM'), findsNothing);

    await tester.ensureVisible(find.text('Documentação (CRLV-e)'));
    await tester.tap(find.text('Documentação (CRLV-e)'));
    await tester.pumpAndSettle();

    expect(find.text('Código RENAVAM'), findsOneWidget);
  });

  testWidgets('StockScreen quick filters and sort work cleanly on mobile and desktop',
      (tester) async {
    final vehicles = _buildSampleVehicles();
    final expenses = _buildSampleExpenses();
    final vehicleRepo = _RecordingVehicleRepository(vehicles);
    final expenseRepo = _RecordingExpenseRepository(expenses);

    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      await setViewportSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StockScreen(
            key: ValueKey(size),
            workspaceId: 'ws1',
            userUid: 'u1',
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+45d pátio (1)'), findsOneWidget);
      expect(find.text('Doc pendente (1)'), findsOneWidget);
      expect(find.text('Falta receber (1)'), findsOneWidget);
      expect(find.text('Ordenar: Mais recentes'), findsOneWidget);

      await tester.tap(find.text('+45d pátio (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Fiat Uno Attractive 1.0'), findsOneWidget);
      expect(find.text('Volkswagen Gol 1.6 MSI'), findsNothing);
    }
  });

  testWidgets('MonthlySummaryScreen shows single CSV export, analytics cards, and drill-downs on mobile & desktop',
      (tester) async {
    final vehicles = _buildSampleVehicles();
    final expenses = _buildSampleExpenses();
    final vehicleRepo = _RecordingVehicleRepository(vehicles);
    final expenseRepo = _RecordingExpenseRepository(expenses);

    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      await setViewportSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MonthlySummaryScreen(
            workspaceId: 'ws1',
            userUid: 'u1',
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only one CSV export button (duplicate card removed)
      expect(find.text('Exportar CSV'), findsOneWidget);
      expect(find.text('Extrato para Planilha'), findsNothing);

      // Stage 3 cards rendered
      expect(find.text('Giro & Saúde do Pátio'), findsOneWidget);
      expect(find.text('Gastos do Mês por Categoria'), findsOneWidget);

      // Drill-down on Lucro das Vendas do Mês
      await tester.tap(find.text('Lucro das Vendas do Mês'));
      await tester.pumpAndSettle();
      expect(find.text('Honda Civic EXL 2.0'), findsOneWidget);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      // Drill-down on A Receber
      await tester.ensureVisible(find.text('A Receber'));
      await tester.tap(find.text('A Receber'));
      await tester.pumpAndSettle();
      expect(find.text('Saldo a Receber (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
    }
  });
}
