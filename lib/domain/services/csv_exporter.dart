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

    final vehiclesById = <String, Vehicle>{
      for (final v in vehicles) v.id: v,
    };
    final expensesByVehicle = FinancialCalculator.aggregateValidExpensesByVehicle(expenses);

    // --- SEÇÃO 1: VEÍCULOS ---
    buffer.writeln('--- 1. VEÍCULOS ---');
    buffer.writeln(
      'Placa;Marca;Modelo;Versão;Ano Fab;Ano Mod;RENAVAM;CRV;Situação Documento;Status;Cadastrado Por;Data Compra;Valor Compra (R\$);Preço Anunciado (R\$);Data Venda;Valor Venda (R\$);Total Recebido (R\$);Saldo a Receber (R\$);Custo Total (R\$);Lucro/Prejuízo (R\$)',
    );

    for (final v in vehicles) {
      final totalCost =
          FinancialCalculator.calculateVehicleTotalCostFromMap(v, expensesByVehicle);
      final profit = v.isSold
          ? FinancialCalculator.calculateRealizedProfitFromMap(v, expensesByVehicle)
          : FinancialCalculator.calculateEstimatedProfitFromMap(v, expensesByVehicle);

      final row = [
        _escapeText(v.formattedPlate),
        _escapeText(v.brand),
        _escapeText(v.model),
        _escapeText(v.version ?? ''),
        _escape(v.manufactureYear?.toString() ?? ''),
        _escape(v.modelYear?.toString() ?? ''),
        _escape(v.renavam != null ? '\t${v.renavam}' : ''), // Tab prefix para preservar zeros à esquerda no Excel
        _escape(v.crvNumber != null ? '\t${v.crvNumber}' : ''),
        _escapeText(v.docStatusLabel),
        _escapeText(v.isInStock ? 'Em estoque' : 'Vendido'),
        _escapeText(v.createdByEmail ?? 'Operador'),
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
    buffer.writeln('ID;Data Pagamento;Placa Veículo;Veículo;Categoria;Descrição;Valor (R\$);Cadastrado Por;Status');

    for (final e in expenses) {
      final relatedVehicle = vehiclesById[e.vehicleId];

      final row = [
        _escapeText(e.id),
        _escape(Formatters.formatDate(e.date)),
        _escapeText(relatedVehicle != null ? relatedVehicle.formattedPlate : ''),
        _escapeText(relatedVehicle != null ? relatedVehicle.title : ''),
        _escapeText(e.categoryLabel),
        _escapeText(e.description ?? ''),
        _escapeCurrency(e.amountCents),
        _escapeText(e.createdByEmail ?? 'Operador'),
        _escapeText(e.isValid ? 'Válida' : 'Estornada'),
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
            _escapeText(p.id),
            _escape(Formatters.formatDate(p.date)),
            _escapeText(v.formattedPlate),
            _escapeText(v.title),
            _escapeCurrency(p.amountCents),
            _escapeText(p.isValid ? 'Válido' : 'Estornado'),
          ];
          buffer.writeln(row.join(';'));
        }
      }
    }

    return buffer.toString();
  }

  static String _escapeText(String field) {
    final trimmed = field.trimLeft();
    final safe = trimmed.isNotEmpty &&
            (trimmed.startsWith('=') ||
                trimmed.startsWith('+') ||
                trimmed.startsWith('-') ||
                trimmed.startsWith('@'))
        ? "'$field"
        : field;
    return _escape(safe);
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
