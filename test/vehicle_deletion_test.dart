import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/data/repositories/expense_repository.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/data/services/fipe_service.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_detail_screen.dart';
import 'package:autosaldo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _DeleteTrackingVehicleRepo implements VehicleRepository {
  final List<Vehicle> vehicles;
  final List<String> deletedVehicleIds = [];

  _DeleteTrackingVehicleRepo(this.vehicles);

  @override
  Stream<Vehicle?> getVehicleStream(String workspaceId, String vehicleId) {
    final matches = vehicles.where((v) => v.id == vehicleId);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  @override
  Future<void> deleteVehicleWithExpenses({
    required String workspaceId,
    required String vehicleId,
  }) async {
    deletedVehicleIds.add(vehicleId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticExpenseRepo implements ExpenseRepository {
  final List<Expense> expenses;

  _StaticExpenseRepo(this.expenses);

  @override
  Stream<List<Expense>> getVehicleExpensesStream(
    String workspaceId,
    String vehicleId,
  ) =>
      Stream.value(expenses.where((e) => e.vehicleId == vehicleId).toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> openDetail(
    WidgetTester tester, {
    required Vehicle vehicle,
    required List<Expense> expenses,
    required _DeleteTrackingVehicleRepo vehicleRepo,
  }) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fipeService = FipeService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(fipeService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => VehicleDetailScreen(
                        workspaceId: 'ws1',
                        vehicleId: vehicle.id,
                        userUid: 'u1',
                        vehicleRepository: vehicleRepo,
                        expenseRepository: _StaticExpenseRepo(expenses),
                        fipeService: fipeService,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir Ficha'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir Ficha'));
    await tester.pumpAndSettle();
  }

  testWidgets('Blocks deletion when vehicle has an activeSale', (tester) async {
    final now = DateTime(2026, 11, 20);
    final soldVehicle = Vehicle(
      id: 'v_sold',
      brand: 'Honda',
      model: 'Civic',
      plate: 'BRA2E19',
      purchaseDate: '2026-11-01',
      purchasePriceCents: 8000000,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
      activeSale: ActiveSale(
        id: 's1',
        saleDate: '2026-11-10',
        salePriceCents: 9000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      ),
    );
    final repo = _DeleteTrackingVehicleRepo([soldVehicle]);

    await openDetail(
      tester,
      vehicle: soldVehicle,
      expenses: const [],
      vehicleRepo: repo,
    );

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir veículo'));
    await tester.pumpAndSettle();

    expect(find.text('Exclusão bloqueada'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    expect(repo.deletedVehicleIds, isEmpty);
  });

  testWidgets('Deletes clean vehicle with simple confirmation and pops back',
      (tester) async {
    final now = DateTime(2026, 11, 20);
    final cleanVehicle = Vehicle(
      id: 'v_clean',
      brand: 'Fiat',
      model: 'Uno',
      plate: 'ABC1234',
      purchaseDate: '2026-11-01',
      purchasePriceCents: 3000000,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    );
    final repo = _DeleteTrackingVehicleRepo([cleanVehicle]);

    await openDetail(
      tester,
      vehicle: cleanVehicle,
      expenses: const [],
      vehicleRepo: repo,
    );

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir veículo'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir Veículo'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(repo.deletedVehicleIds, ['v_clean']);
    expect(find.text('Abrir Ficha'), findsOneWidget);
    expect(find.text('Veículo excluído com sucesso.'), findsOneWidget);
  });

  testWidgets(
      'Requires plate confirmation when vehicle has expenses or cancelled sales',
      (tester) async {
    final now = DateTime(2026, 11, 20);
    final vehicleWithHistory = Vehicle(
      id: 'v_hist',
      brand: 'VW',
      model: 'Gol',
      plate: 'ABC1234',
      purchaseDate: '2026-11-01',
      purchasePriceCents: 3500000,
      cancelledSales: const [
        {'id': 'old_sale', 'saleDate': '2026-11-05'}
      ],
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    );
    final expenses = [
      Expense(
        id: 'e1',
        vehicleId: 'v_hist',
        amountCents: 120000,
        date: '2026-11-03',
        category: AppConstants.expenseCategoryWorkshop,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      ),
    ];
    final repo = _DeleteTrackingVehicleRepo([vehicleWithHistory]);

    await openDetail(
      tester,
      vehicle: vehicleWithHistory,
      expenses: expenses,
      vehicleRepo: repo,
    );

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir veículo'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir Veículo e Histórico'), findsOneWidget);
    expect(find.textContaining('1 despesa registrada'), findsOneWidget);
    expect(find.textContaining('1 venda cancelada'), findsOneWidget);

    final deleteBtnFinder =
        find.widgetWithText(ElevatedButton, 'Excluir permanentemente');
    expect(tester.widget<ElevatedButton>(deleteBtnFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc1234');
    await tester.pumpAndSettle();

    expect(
      tester.widget<ElevatedButton>(deleteBtnFinder).onPressed,
      isNotNull,
    );

    await tester.tap(deleteBtnFinder);
    await tester.pumpAndSettle();

    expect(repo.deletedVehicleIds, ['v_hist']);
    expect(find.text('Abrir Ficha'), findsOneWidget);
  });
}
