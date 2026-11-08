import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  /// Converte centavos inteiros para string formatada em BRL (ex: R$ 35.000,00)
  static String formatCurrency(int cents) {
    final double value = cents / 100.0;
    return _currencyFormat.format(value);
  }

  /// Converte texto digitado pelo usuário em centavos inteiros.
  /// Suporta formatos como "35000", "35.000,00", "35000,50", "35000.50", "R$ 35.000,00".
  static int parseCurrencyToCents(String input) {
    if (input.trim().isEmpty) return 0;

    String clean = input
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();

    // Se tiver vírgula e pontos: ex: 35.000,50 -> 35000.50
    if (clean.contains(',') && clean.contains('.')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }

    final double? parsed = double.tryParse(clean);
    if (parsed == null) return 0;
    return (parsed * 100).round();
  }

  /// Normaliza placa: maiúsculas, sem traço e sem espaços (ex: "abc-1234" -> "ABC1234")
  static String normalizePlate(String input) {
    return input
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim();
  }

  /// Formata placa para exibição: padrão antigo ABC-1234 ou Mercosul ABC1D23
  static String formatPlate(String normalized) {
    final clean = normalizePlate(normalized);
    if (clean.length == 7) {
      final isOldPattern = RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(clean);
      if (isOldPattern) {
        return '${clean.substring(0, 3)}-${clean.substring(3)}';
      }
    }
    return clean;
  }

  /// Converte "AAAA-MM-DD" para "DD/MM/AAAA"
  static String formatDate(String isoDate) {
    if (isoDate.length != 10) return isoDate;
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Converte "DD/MM/AAAA" para "AAAA-MM-DD"
  static String parseDateToIso(String brazilianDate) {
    final parts = brazilianDate.split('/');
    if (parts.length != 3) return brazilianDate;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }

  /// Formata DateTime para data ISO (AAAA-MM-DD)
  static String toIsoDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Retorna a data de hoje no formato civil AAAA-MM-DD
  static String todayIsoDate() {
    return toIsoDate(DateTime.now());
  }

  /// Normaliza RENAVAM preservando zeros à esquerda (11 dígitos)
  static String? normalizeRenavam(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits.padLeft(11, '0');
  }

  /// Normaliza CRV preservando zeros à esquerda
  static String? normalizeCrv(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits;
  }

  /// Nome do mês por extenso em português
  static String monthName(int month) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }
}

