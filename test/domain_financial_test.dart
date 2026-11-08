import 'package:flutter_test/flutter_test.dart';
import 'package:autosaldo/core/constants.dart';
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
  });
}

