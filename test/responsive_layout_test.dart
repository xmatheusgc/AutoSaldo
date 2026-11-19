import 'dart:convert';
import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/data/repositories/auth_repository.dart';
import 'package:autosaldo/data/repositories/expense_repository.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/data/services/fipe_service.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/payment.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/presentation/screens/home_shell.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_detail_screen.dart';
import 'package:autosaldo/presentation/screens/stock/vehicle_form_screen.dart';
import 'package:autosaldo/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVehicleRepository implements VehicleRepository {
  final List<Vehicle> vehicles;

  _FakeVehicleRepository(this.vehicles);

  @override
  Stream<List<Vehicle>> getVehiclesStream(String workspaceId) =>
      Stream.value(vehicles);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> expenses;

  _FakeExpenseRepository(this.expenses);

  @override
  Stream<List<Expense>> getExpensesStream(String workspaceId) =>
      Stream.value(expenses);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Vehicle> _sampleVehicles() {
  final now = DateTime(2026, 11, 1);
  return [
    Vehicle(
      id: 'v1',
      brand: 'Volkswagen',
      model: 'Gol',
      version: '1.6 MSI Flex',
      plate: 'ABC1234',
      purchaseDate: '2026-10-05',
      purchasePriceCents: 3500000,
      announcedPriceCents: 4500000,
      manufactureYear: 2021,
      modelYear: 2022,
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
      version: 'EXL 2.0 Flex Aut.',
      plate: 'BRA2E19',
      purchaseDate: '2026-10-10',
      purchasePriceCents: 8000000,
      manufactureYear: 2020,
      modelYear: 2021,
      docStatus: AppConstants.docStatusWithIssue,
      activeSale: ActiveSale(
        id: 's1',
        saleDate: '2026-11-01',
        salePriceCents: 9500000,
        payments: [
          Payment(
            id: 'p1',
            amountCents: 5000000,
            date: '2026-11-01',
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
      brand: 'Toyota',
      model: 'Corolla',
      version: 'XEi 2.0 Aut.',
      plate: 'XYZ9876',
      purchaseDate: '2026-10-12',
      purchasePriceCents: 9000000,
      announcedPriceCents: 10500000,
      docStatus: AppConstants.docStatusPendingCheck,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    ),
    Vehicle(
      id: 'v4',
      brand: 'Fiat',
      model: 'Strada',
      version: 'Freedom 1.3',
      plate: 'DEF4G56',
      purchaseDate: '2026-10-15',
      purchasePriceCents: 6500000,
      announcedPriceCents: 7800000,
      docStatus: AppConstants.docStatusUpToDate,
      createdAt: now,
      updatedAt: now,
      createdByUid: 'u1',
      updatedByUid: 'u1',
    ),
  ];
}

List<Expense> _sampleExpenses() {
  final now = DateTime(2026, 11, 2);
  return [
    Expense(
      id: 'e1',
      vehicleId: 'v1',
      amountCents: 150000,
      date: '2026-10-08',
      category: AppConstants.expenseCategoryWorkshop,
      description: 'Revisão geral',
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

  group('Responsive Mobile vs Desktop Layout', () {
    testWidgets('HomeShell keeps NavigationBar on mobile and switches to sidebar on desktop',
        (tester) async {
      final authRepo = _FakeAuthRepository();
      final vehicleRepo = _FakeVehicleRepository(_sampleVehicles());
      final expenseRepo = _FakeExpenseRepository(_sampleExpenses());

      // Mobile 390x844
      await setViewportSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeShell(
            key: const ValueKey('mobile_shell'),
            userUid: 'u1',
            userEmail: 'teste@autosaldo.com',
            authRepository: authRepo,
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Olá, Teste'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Switch to Resumo on mobile
      await tester.tap(find.text('Resumo'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo Financeiro'), findsOneWidget);

      // Desktop 1280x800
      await setViewportSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeShell(
            key: const ValueKey('desktop_shell'),
            userUid: 'u1',
            userEmail: 'teste@autosaldo.com',
            authRepository: authRepo,
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('AutoSaldo'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Cadastrar veículo'), findsOneWidget);

      // Switch to Resumo on desktop
      await tester.tap(find.text('Resumo'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo Financeiro'), findsOneWidget);
    });

    testWidgets('VehicleDetailScreen renders 2 columns on desktop and adaptive modal dialog',
        (tester) async {
      final vehicles = _sampleVehicles();
      final vehicleRepo = _FakeVehicleRepository(vehicles);
      final expenseRepo = _FakeExpenseRepository(_sampleExpenses());

      // Desktop 1280x800
      await setViewportSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VehicleDetailScreen(
            workspaceId: 'ws1',
            vehicleId: 'v2',
            userUid: 'u1',
            userEmail: 'teste@autosaldo.com',
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custos e Venda'), findsOneWidget);
      expect(find.text('Venda & Recebimentos'), findsOneWidget);
      expect(find.text('Despesas (0)'), findsOneWidget);

      // Open Novo Gasto -> should open centered Dialog on desktop
      await tester.tap(find.text('Novo Gasto'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Lançar Despesa'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Mobile 390x844 -> Novo Gasto should open BottomSheet (no Dialog)
      await setViewportSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: VehicleDetailScreen(
            workspaceId: 'ws1',
            vehicleId: 'v1',
            userUid: 'u1',
            userEmail: 'teste@autosaldo.com',
            vehicleRepository: vehicleRepo,
            expenseRepository: expenseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Novo Gasto'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Lançar Despesa'), findsOneWidget);
    });

    testWidgets('VehicleFormScreen adapts to desktop 2-column and mobile 1-column',
        (tester) async {
      final vehicleRepo = _FakeVehicleRepository(const []);
      final fipeService = FipeService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {'codigo': '21', 'nome': 'Fiat'},
              {'codigo': '59', 'nome': 'VW - VolksWagen'},
            ]),
            200,
          );
        }),
      );

      // Desktop 1280x800
      await setViewportSize(tester, const Size(1280, 800));
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

      expect(find.text('Identificação do Veículo'), findsOneWidget);
      expect(find.text('Dados Financeiros da Compra'), findsOneWidget);
      expect(find.text('Documentação (CRLV-e)'), findsOneWidget);

      // Mobile 390x844
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

      expect(find.text('Identificação do Veículo'), findsOneWidget);
      expect(find.text('Concluir Cadastro'), findsOneWidget);
      fipeService.dispose();
    });
  });
}
