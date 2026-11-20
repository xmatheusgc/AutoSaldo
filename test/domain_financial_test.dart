import 'package:flutter_test/flutter_test.dart';
import 'package:autosaldo/core/constants.dart';
import 'package:autosaldo/core/error_messages.dart';
import 'package:autosaldo/core/formatters.dart';
import 'package:autosaldo/core/validators.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/expense.dart';
import 'package:autosaldo/domain/models/payment.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/domain/services/csv_exporter.dart';
import 'package:autosaldo/domain/services/financial_calculator.dart';

void main() {
  group('Formatters & Validators', () {
    test('Currency parsing and formatting', () {
      expect(Formatters.parseCurrencyToCents('35000'), 3500000);
      expect(Formatters.parseCurrencyToCents('35.000,00'), 3500000);
      expect(Formatters.parseCurrencyToCents('R\$ 1.250,50'), 125050);
      expect(Formatters.parseCurrencyToCents('0,99'), 99);
      expect(Formatters.parseCurrencyToCents(''), 0);

      expect(Formatters.formatCurrency(3500000), contains('35.000,00'));
      expect(Formatters.formatCurrency(125050), contains('1.250,50'));
    });

    test('Plate normalization and validation', () {
      expect(Formatters.normalizePlate('abc-1234'), 'ABC1234');
      expect(Formatters.normalizePlate('bra2e19'), 'BRA2E19');
      expect(Formatters.formatPlate('ABC1234'), 'ABC-1234');
      expect(Formatters.formatPlate('BRA2E19'), 'BRA2E19');

      // Valid plates
      expect(Validators.isValidPlate('ABC-1234'), isTrue);
      expect(Validators.isValidPlate('abc1234'), isTrue);
      expect(Validators.isValidPlate('BRA2E19'), isTrue);
      expect(Validators.isValidPlate('bra-2e19'), isTrue);

      // Invalid plates
      expect(Validators.isValidPlate('ABC12'), isFalse);
      expect(Validators.isValidPlate('1234ABC'), isFalse);
      expect(Validators.isValidPlate('ABCD123'), isFalse);
    });

    test('RENAVAM and CRV zero padding preservation', () {
      expect(Formatters.normalizeRenavam('00123456789'), '00123456789');
      expect(Formatters.normalizeRenavam('123456789'), '00123456789');
      expect(Validators.isValidRenavam('00123456789'), isTrue);
      expect(Validators.isValidRenavam(null), isTrue); // opcional
      expect(Validators.isValidRenavam('1234'), isFalse); // deve ter 11 dígitos se fornecido

      expect(Formatters.normalizeCrv('00987654'), '00987654');
    });

    test('Date sequence validations', () {
      expect(Validators.isValidSaleDate('2026-10-01', '2026-10-05', '2026-11-08'), isTrue);
      expect(Validators.isValidSaleDate('2026-10-05', '2026-10-01', '2026-11-08'), isFalse); // venda antes da compra
      expect(Validators.isValidSaleDate('2026-10-05', '2026-12-01', '2026-11-08'), isFalse); // venda no futuro

      expect(Validators.isValidPaymentDate('2026-10-05', '2026-10-05', '2026-11-08'), isTrue);
      expect(Validators.isValidPaymentDate('2026-10-05', '2026-10-10', '2026-11-08'), isTrue);
      expect(Validators.isValidPaymentDate('2026-10-05', '2026-10-01', '2026-11-08'), isFalse); // recebimento antes da venda
    });
  });

  group('Domain & Financial Calculator', () {
    test('Vehicle cost calculation with valid and reverted expenses', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v1',
        brand: 'Volkswagen',
        model: 'Gol',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 3000000, // R$ 30.000,00
        announcedPriceCents: 3600000, // R$ 36.000,00
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
      );

      final expenses = [
        Expense(
          id: 'e1',
          vehicleId: 'v1',
          amountCents: 150000, // R$ 1.500,00
          date: '2026-10-05',
          category: AppConstants.expenseCategoryWorkshop,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
        Expense(
          id: 'e2',
          vehicleId: 'v1',
          amountCents: 50000, // R$ 500,00 (estornado)
          date: '2026-10-06',
          category: AppConstants.expenseCategoryTransport,
          status: AppConstants.statusReverted,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      ];

      final totalCost = FinancialCalculator.calculateVehicleTotalCost(vehicle, expenses);
      expect(totalCost, 3150000); // 30.000 + 1.500 = 31.500 (ignora 500 estornado)

      final estimatedProfit = FinancialCalculator.calculateEstimatedProfit(vehicle, expenses);
      expect(estimatedProfit, 450000); // 36.000 - 31.500 = 4.500
    });

    test('Pre-aggregated FromMap helpers exclude reverted expenses and match list calculations', () {
      final now = DateTime.now();
      final inStockVehicle = Vehicle(
        id: 'v1',
        brand: 'Volkswagen',
        model: 'Gol',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 3000000,
        announcedPriceCents: 3600000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
      );
      final soldVehicle = Vehicle(
        id: 'v2',
        brand: 'Honda',
        model: 'Civic',
        plate: 'BRA2E19',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 5000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
        activeSale: ActiveSale(
          id: 's1',
          saleDate: '2026-10-20',
          salePriceCents: 5800000,
          payments: [
            Payment(
              id: 'p1',
              amountCents: 5800000,
              date: '2026-10-20',
              createdAt: now,
              createdByUid: 'uid1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      );

      final expenses = [
        Expense(
          id: 'e1',
          vehicleId: 'v1',
          amountCents: 120000,
          date: '2026-10-05',
          category: AppConstants.expenseCategoryWorkshop,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
        Expense(
          id: 'e2',
          vehicleId: 'v1',
          amountCents: 80000,
          date: '2026-10-06',
          category: AppConstants.expenseCategoryTransport,
          status: AppConstants.statusReverted,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
        Expense(
          id: 'e3',
          vehicleId: 'v2',
          amountCents: 250000,
          date: '2026-10-10',
          category: AppConstants.expenseCategoryWorkshop,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      ];

      final map = FinancialCalculator.aggregateValidExpensesByVehicle(expenses);
      expect(map['v1'], 120000);
      expect(map['v2'], 250000);

      expect(
        FinancialCalculator.calculateVehicleTotalCostFromMap(inStockVehicle, map),
        FinancialCalculator.calculateVehicleTotalCost(inStockVehicle, expenses),
      );
      expect(
        FinancialCalculator.calculateEstimatedProfitFromMap(inStockVehicle, map),
        FinancialCalculator.calculateEstimatedProfit(inStockVehicle, expenses),
      );
      expect(
        FinancialCalculator.calculateRealizedProfitFromMap(soldVehicle, map),
        FinancialCalculator.calculateRealizedProfit(soldVehicle, expenses),
      );
    });

    test('Reproducing the exact specification example from Section 3', () {
      final now = DateTime.now();
      // "Um carro comprado por R$ 35.000, com R$ 2.000 em despesas, tem custo de R$ 37.000.
      // Vendido por R$ 42.000, gera lucro de R$ 5.000.
      // Se o vendedor receber R$ 40.000 no mês da venda e R$ 2.000 no mês seguinte,
      // o lucro continua no mês da venda e o caixa registra as entradas nos respectivos meses.
      // Se houver uma comissão de R$ 300 paga depois, o lucro da venda passa a R$ 4.700
      // e a saída de R$ 300 entra no mês do pagamento."

      final vehicle = Vehicle(
        id: 'v_example',
        brand: 'Honda',
        model: 'Civic',
        plate: 'BRA2E19',
        purchaseDate: '2026-10-05',
        purchasePriceCents: 3500000, // R$ 35.000,00
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
        activeSale: ActiveSale(
          id: 'sale1',
          saleDate: '2026-10-20',
          salePriceCents: 4200000, // R$ 42.000,00
          payments: [
            Payment(
              id: 'pay1',
              amountCents: 4000000, // R$ 40.000,00 recebido em Outubro
              date: '2026-10-20',
              createdAt: now,
              createdByUid: 'uid1',
            ),
            Payment(
              id: 'pay2',
              amountCents: 200000, // R$ 2.000,00 recebido em Novembro
              date: '2026-11-05',
              createdAt: now,
              createdByUid: 'uid1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      );

      final expenses = [
        // R$ 2.000 pago em Outubro
        Expense(
          id: 'exp1',
          vehicleId: 'v_example',
          amountCents: 200000,
          date: '2026-10-10',
          category: AppConstants.expenseCategoryWorkshop,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
        // Comissão de R$ 300 paga em Novembro (após a venda)
        Expense(
          id: 'exp2',
          vehicleId: 'v_example',
          amountCents: 30000,
          date: '2026-11-12',
          category: AppConstants.expenseCategoryCommission,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      ];

      // Verificação do Custo Total acumulado: 35.000 + 2.000 + 300 = R$ 37.300
      final totalCost = FinancialCalculator.calculateVehicleTotalCost(vehicle, expenses);
      expect(totalCost, 3730000);

      // Lucro final da venda com comissão tardia = 42.000 - 37.300 = R$ 4.700
      final realizedProfit = FinancialCalculator.calculateRealizedProfit(vehicle, expenses);
      expect(realizedProfit, 470000);

      // Verificação do Resumo de Outubro/2026:
      final octSummary = FinancialCalculator.calculateMonthlySummary(
        allVehicles: [vehicle],
        allExpenses: expenses,
        year: 2026,
        month: 10,
      );

      // Lucro dos carros vendidos em Outubro = R$ 4.700 (inclui despesa tardia de comissão no cálculo do carro!)
      expect(octSummary.soldVehiclesProfitCents, 470000);
      // Entradas em Outubro = R$ 40.000
      expect(octSummary.monthIncomeCents, 4000000);
      // Saídas em Outubro = R$ 35.000 (compra) + R$ 2.000 (oficina) = R$ 37.000
      expect(octSummary.monthExpensesCents, 3700000);
      // Saldo do mês em Outubro = 40.000 - 37.000 = R$ 3.000
      expect(octSummary.monthNetCashCents, 300000);

      // Verificação do Resumo de Novembro/2026:
      final novSummary = FinancialCalculator.calculateMonthlySummary(
        allVehicles: [vehicle],
        allExpenses: expenses,
        year: 2026,
        month: 11,
      );

      // Lucro dos carros vendidos em Novembro = 0 (o carro foi vendido em Outubro)
      expect(novSummary.soldVehiclesProfitCents, 0);
      // Entradas em Novembro = R$ 2.000 (segunda parcela)
      expect(novSummary.monthIncomeCents, 200000);
      // Saídas em Novembro = R$ 300 (comissão paga em Novembro)
      expect(novSummary.monthExpensesCents, 30000);
      // Saldo do mês em Novembro = 2.000 - 300 = R$ 1.700
      expect(novSummary.monthNetCashCents, 170000);
      // Saldo a receber hoje = 0 (venda quitada)
      expect(novSummary.toReceiveTodayCents, 0);
    });

    test('Sale with loss (Prejuízo)', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v_loss',
        brand: 'Fiat',
        model: 'Uno',
        plate: 'XYZ9876',
        purchaseDate: '2026-11-01',
        purchasePriceCents: 2000000, // R$ 20.000
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
        activeSale: ActiveSale(
          id: 'sale_loss',
          saleDate: '2026-11-05',
          salePriceCents: 1800000, // Vendido por R$ 18.000
          payments: [
            Payment(
              id: 'p1',
              amountCents: 1800000,
              date: '2026-11-05',
              createdAt: now,
              createdByUid: 'uid1',
            ),
          ],
          createdAt: now,
          updatedAt: now,
          createdByUid: 'uid1',
          updatedByUid: 'uid1',
        ),
      );

      final profit = FinancialCalculator.calculateRealizedProfit(vehicle, []);
      expect(profit, -200000); // Prejuízo de R$ 2.000
    });

    test('CSV Exporter generates valid UTF-8 BOM spreadsheet', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v1',
        brand: 'Toyota',
        model: 'Corolla',
        version: 'XEi 2.0',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 8000000,
        renavam: '00123456789',
        crvNumber: '00987654',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
      );

      final csv = CsvExporter.generateCsv(vehicles: [vehicle], expenses: []);
      expect(csv.startsWith('\uFEFF'), isTrue); // BOM UTF-8
      expect(csv, contains('Toyota'));
      expect(csv, contains('Corolla'));
      expect(csv, contains('00123456789')); // Zeros preservados
      expect(csv, contains('00987654'));
      expect(csv, contains('AutoSaldo - Extrato Consolidado para Planilha'));
    });

    test('CSV Exporter neutralizes formula injection while preserving RENAVAM tab prefix', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v1',
        brand: '+Ford',
        model: '@Ka',
        version: '-SE',
        plate: 'ABC1234',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 4000000,
        renavam: '00123456789',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
      );
      final expense = Expense(
        id: 'e1',
        vehicleId: 'v1',
        amountCents: 25000,
        date: '2026-10-03',
        category: AppConstants.expenseCategoryWorkshop,
        description: '=SUM(A1:A2)',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'uid1',
        updatedByUid: 'uid1',
      );

      final csv = CsvExporter.generateCsv(vehicles: [vehicle], expenses: [expense]);
      expect(csv, contains("'+Ford"));
      expect(csv, contains("'@Ka"));
      expect(csv, contains("'-SE"));
      expect(csv, contains("'=SUM(A1:A2)"));
      expect(csv, contains('\t00123456789'));
    });

    test('Calculates days in stock, ROI %, category breakdown, and extended MonthlySummary', () {
      final now = DateTime(2026, 11, 20);
      final vSold = Vehicle(
        id: 'v_sold',
        brand: 'Fiat',
        model: 'Argo',
        plate: 'AAA1111',
        purchaseDate: '2026-11-01',
        purchasePriceCents: 4000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
        activeSale: ActiveSale(
          id: 's1',
          saleDate: '2026-11-11',
          salePriceCents: 4600000,
          payments: [
            Payment(
              id: 'p1',
              amountCents: 2000000,
              date: '2026-11-11',
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

      final vStagnant = Vehicle(
        id: 'v_old',
        brand: 'VW',
        model: 'Voyage',
        plate: 'BBB2222',
        purchaseDate: '2026-09-20', // 61 days before 2026-11-20
        purchasePriceCents: 3000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final vFresh = Vehicle(
        id: 'v_new',
        brand: 'Hyundai',
        model: 'HB20',
        plate: 'CCC3333',
        purchaseDate: '2026-11-10', // 10 days before 2026-11-20
        purchasePriceCents: 5000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final expenses = [
        Expense(
          id: 'e1',
          vehicleId: 'v_sold',
          amountCents: 100000,
          date: '2026-11-03',
          category: AppConstants.expenseCategoryWorkshop,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
        Expense(
          id: 'e2',
          vehicleId: 'v_stagnant',
          amountCents: 50000,
          date: '2026-11-05',
          category: AppConstants.expenseCategoryDocumentation,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
        Expense(
          id: 'e3',
          vehicleId: 'v_fresh',
          amountCents: 99999,
          date: '2026-11-06',
          category: AppConstants.expenseCategoryParts,
          status: AppConstants.statusReverted,
          createdAt: now,
          updatedAt: now,
          createdByUid: 'u1',
          updatedByUid: 'u1',
        ),
      ];

      expect(FinancialCalculator.calculateDaysInStock(vSold, now: now), 10);
      expect(FinancialCalculator.calculateDaysInStock(vStagnant, now: now), 61);
      expect(FinancialCalculator.calculateDaysInStock(vFresh, now: now), 10);

      expect(FinancialCalculator.calculateRoiPercent(500000, 4100000), closeTo(12.195, 0.01));
      expect(FinancialCalculator.calculateRoiPercent(100000, 0), isNull);

      final categories = FinancialCalculator.calculateExpensesByCategory(
        expenses,
        monthPrefix: '2026-11',
      );
      expect(categories[AppConstants.expenseCategoryWorkshop], 100000);
      expect(categories[AppConstants.expenseCategoryDocumentation], 50000);
      expect(categories.containsKey(AppConstants.expenseCategoryParts), isFalse);

      final summary = FinancialCalculator.calculateMonthlySummary(
        allVehicles: [vSold, vStagnant, vFresh],
        allExpenses: expenses,
        year: 2026,
        month: 11,
        now: now,
      );

      expect(summary.soldCount, 1);
      expect(summary.soldVehiclesCostCents, 4100000);
      expect(summary.soldVehiclesProfitCents, 500000);
      expect(summary.soldInMonthRoiPercent, closeTo(12.195, 0.01));
      expect(summary.avgDaysToSell, 10.0);
      expect(summary.stockCount, 2);
      expect(summary.avgStockAgeDays, 35.5);
      expect(summary.stagnantStockCount, 1);
      expect(summary.pendingReceiveVehiclesCount, 1);
      expect(summary.toReceiveTodayCents, 2600000);
      expect(summary.monthExpensesByCategory[AppConstants.expenseCategoryWorkshop], 100000);
    });

    test('Formatters percent/days helpers and ErrorMessages.friendly sanitize technical errors', () {
      expect(Formatters.formatPercent(14.26), '+14,3%');
      expect(Formatters.formatPercent(-5.14), '-5,1%');
      expect(Formatters.formatPercent(-0.04), '0,0%');
      expect(Formatters.formatDaysCount(0), 'Hoje');
      expect(Formatters.formatDaysCount(1), '1 dia');
      expect(Formatters.formatDaysCount(15), '15 dias');

      expect(
        ErrorMessages.friendly('[cloud_firestore/permission-denied] Missing permissions'),
        'Você não tem permissão para realizar esta ação.',
      );
      expect(
        ErrorMessages.friendly('SocketException: Failed host lookup'),
        'Sem conexão com a internet ou servidor indisponível. Verifique seu sinal e tente novamente.',
      );
      expect(
        ErrorMessages.friendly('Exception: O veículo já está em estoque.'),
        'O veículo já está em estoque.',
      );
    });
  });
}

