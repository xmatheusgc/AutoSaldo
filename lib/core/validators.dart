import 'formatters.dart';

class Validators {
  static final RegExp _plateRegex = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');
  static final RegExp _isoDateRegex = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

  /// Valida se a placa normalizada corresponde ao padrão antigo ou Mercosul
  static bool isValidPlate(String plate) {
    final normalized = Formatters.normalizePlate(plate);
    return _plateRegex.hasMatch(normalized);
  }

  /// Valida se o formato da data é AAAA-MM-DD
  static bool isValidIsoDateFormat(String dateStr) {
    if (!_isoDateRegex.hasMatch(dateStr)) return false;
    final parts = dateStr.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    return true;
  }

  /// Verifica se a data ISO não está no futuro em relação ao dia de hoje
  static bool isNotFutureDate(String dateStr, [String? referenceToday]) {
    if (!isValidIsoDateFormat(dateStr)) return false;
    final today = referenceToday ?? Formatters.todayIsoDate();
    return dateStr.compareTo(today) <= 0;
  }

  /// Valida a data de venda (>= data de compra e <= hoje)
  static bool isValidSaleDate(String purchaseDate, String saleDate, [String? referenceToday]) {
    if (!isValidIsoDateFormat(purchaseDate) || !isValidIsoDateFormat(saleDate)) return false;
    if (!isNotFutureDate(saleDate, referenceToday)) return false;
    return saleDate.compareTo(purchaseDate) >= 0;
  }

  /// Valida a data de recebimento (>= data de venda e <= hoje)
  static bool isValidPaymentDate(String saleDate, String paymentDate, [String? referenceToday]) {
    if (!isValidIsoDateFormat(saleDate) || !isValidIsoDateFormat(paymentDate)) return false;
    if (!isNotFutureDate(paymentDate, referenceToday)) return false;
    return paymentDate.compareTo(saleDate) >= 0;
  }

  /// Valida RENAVAM: opcional, mas se fornecido deve ter exatamente 11 dígitos
  static bool isValidRenavam(String? renavam) {
    if (renavam == null || renavam.trim().isEmpty) return true;
    final clean = renavam.trim();
    return RegExp(r'^[0-9]{11}$').hasMatch(clean);
  }

  /// Valida ano de 4 dígitos opcional
  static bool isValidYear(int? year) {
    if (year == null) return true;
    return year >= 1900 && year <= 2100;
  }
}
