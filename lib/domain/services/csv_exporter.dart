import 'dart:convert';
import '../../core/formatters.dart';
import '../models/expense.dart';
import '../models/vehicle.dart';
import 'financial_calculator.dart';

class CsvExporter {
  /// Gera arquivo CSV em formato UTF-8 (com BOM \uFEFF) e separador ponto-e-vírgula ';'
  /// estruturado para abertura direta no Microsoft Excel, LibreOffice e Google Sheets.
  static String generateCsv({
    required List<Vehicle> vehicles,
    required List<Expense> expenses,
  }) {
    final buffer = StringBuffer();
    // BOM UTF-8
    buffer.write('\uFEFF');

    final now = DateTime.now();
    final dateFormatted =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    buffer.writeln('# AutoSaldo - Extrato Consolidado para Planilha');
    buffer.writeln('# Gerado em: $dateFormatted');
    buffer.writeln('# Nota: Este extrato destina-se a controle financeiro e importação em planilhas.');
    buffer.writeln('');

    // --- SEÇÃO 1: VEÍCULOS ---
    buffer.writeln('--- 1. VEÍCULOS ---');
    buffer.writeln(
      'Placa;Marca;Modelo;Versão;Ano Fab;Ano Mod;RENAVAM;CRV;Situação Documento;Status;Data Compra;Valor Compra (R\$);Preço Anunciado (R\$);Data Venda;Valor Venda (R\$);Total Recebido (R\$);Saldo a Receber (R\$);Custo Total (R\$);Lucro/Prejuízo (R\$)',
    );

    for (final v in vehicles) {
      final totalCost = FinancialCalculator.calculateVehicleTotalCost(v, expenses);
      final profit = v.isSold
          ? FinancialCalculator.calculateRealizedProfit(v, expenses)
          : FinancialCalculator.calculateEstimatedProfit(v, expenses);

      final row = [
        _escape(v.formattedPlate),
        _escape(v.brand),
        _escape(v.model),
        _escape(v.version ?? ''),
        _escape(v.manufactureYear?.toString() ?? ''),
        _escape(v.modelYear?.toString() ?? ''),
        _escape(v.renavam != null ? '\t${v.renavam}' : ''), // Tab prefix para preservar zeros à esquerda no Excel
        _escape(v.crvNumber != null ? '\t${v.crvNumber}' : ''),
        _escape(v.docStatusLabel),
        _escape(v.isInStock ? 'Em estoque' : 'Vendido'),
        _escape(Formatters.formatDate(v.purchaseDate)),
        _escapeCurrency(v.purchasePriceCents),
        _escapeCurrency(v.announcedPriceCents),
        _escape(v.activeSale != null ? Formatters.formatDate(v.activeSale!.saleDate) : ''),
        _escapeCurrency(v.activeSale?.salePriceCents),
        _escapeCurrency(v.activeSale?.totalReceivedCents),
        _escapeCurrency(v.activeSale?.balanceDueCents),
        _escapeCurrency(totalCost),
        _escapeCurrency(profit),
      ];
      buffer.writeln(row.join(';'));
    }

    buffer.writeln('');

    // --- SEÇÃO 2: DESPESAS ---
    buffer.writeln('--- 2. DESPESAS ---');
    buffer.writeln('ID;Data Pagamento;Placa Veículo;Veículo;Categoria;Descrição;Valor (R\$);Status');

    for (final e in expenses) {
      final relatedVehicle = vehicles.cast<Vehicle?>().firstWhere(
            (v) => v?.id == e.vehicleId,
            orElse: () => null,
          );

      final row = [
        _escape(e.id),
        _escape(Formatters.formatDate(e.date)),
        _escape(relatedVehicle != null ? relatedVehicle.formattedPlate : ''),
        _escape(relatedVehicle != null ? relatedVehicle.title : ''),
        _escape(e.categoryLabel),
        _escape(e.description ?? ''),
        _escapeCurrency(e.amountCents),
        _escape(e.isValid ? 'Válida' : 'Estornada'),
      ];
      buffer.writeln(row.join(';'));
    }

    buffer.writeln('');

    // --- SEÇÃO 3: RECEBIMENTOS ---
    buffer.writeln('--- 3. RECEBIMENTOS ---');
    buffer.writeln('ID;Data Recebimento;Placa Veículo;Veículo;Valor (R\$);Status');

    for (final v in vehicles) {
      if (v.activeSale != null) {
        for (final p in v.activeSale!.payments) {
          final row = [
            _escape(p.id),
            _escape(Formatters.formatDate(p.date)),
            _escape(v.formattedPlate),
            _escape(v.title),
            _escapeCurrency(p.amountCents),
            _escape(p.isValid ? 'Válido' : 'Estornado'),
          ];
          buffer.writeln(row.join(';'));
        }
      }
    }

    return buffer.toString();
  }

  static String _escape(String field) {
    if (field.contains(';') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static String _escapeCurrency(int? cents) {
    if (cents == null) return '';
    final double value = cents / 100.0;
    // Formato com vírgula decimal para planilhas brasileiras
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  /// Retorna os bytes UTF-8 com BOM para download
  static List<int> getCsvBytes(String csvContent) {
    return utf8.encode(csvContent);
  }
}
