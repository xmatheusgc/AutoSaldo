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

  /// Valida telefone brasileiro opcional (10 ou 11 dígitos quando preenchido).
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true;
    final d = Formatters.digitsOnly(phone);
    if (d.length != 10 && d.length != 11) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(d)) return false;
    final ddd = int.tryParse(d.substring(0, 2)) ?? 0;
    return ddd >= 11 && ddd <= 99;
  }

  /// Valida CPF ou CNPJ opcional com verificação de dígitos verificadores.
  static bool isValidCpfOrCnpj(String? doc) {
    if (doc == null || doc.trim().isEmpty) return true;
    final d = Formatters.digitsOnly(doc);
    if (d.length == 11) return isValidCpf(d);
    if (d.length == 14) return isValidCnpj(d);
    return false;
  }

  /// Valida CPF (11 dígitos numéricos).
  static bool isValidCpf(String digits) {
    if (digits.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(digits)) {
      return false;
    }
    return _checkMod11Digit(digits, 9, [10, 9, 8, 7, 6, 5, 4, 3, 2]) &&
        _checkMod11Digit(digits, 10, [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]);
  }

  /// Valida CNPJ (14 dígitos numéricos).
  static bool isValidCnpj(String digits) {
    if (digits.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(digits)) {
      return false;
    }
    return _checkMod11Digit(digits, 12, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) &&
        _checkMod11Digit(digits, 13, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  }

  static bool _checkMod11Digit(String digits, int targetIndex, List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += (digits.codeUnitAt(i) - 48) * weights[i];
    }
    final rem = sum % 11;
    final expected = rem < 2 ? 0 : 11 - rem;
    return (digits.codeUnitAt(targetIndex) - 48) == expected;
  }
}

