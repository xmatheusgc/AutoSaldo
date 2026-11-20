import 'package:flutter/services.dart';
import 'formatters.dart';

/// Base formatter para campos numéricos com máscara progressiva preservando o cursor.
class DigitsMaskInputFormatter extends TextInputFormatter {
  final int maxDigits;
  final String Function(String digits) formatDigits;

  const DigitsMaskInputFormatter({
    required this.maxDigits,
    required this.formatDigits,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = Formatters.digitsOnly(oldValue.text);
    var newDigits = Formatters.digitsOnly(newValue.text);

    final selectionIndex = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    var targetDigitCount = _countDigitsBefore(newValue.text, selectionIndex);

    // Quando o usuário pressiona backspace exatamente sobre um separador da máscara,
    // remove o dígito imediatamente anterior para não travar a edição.
    final deletedSingleChar = oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        newValue.text.length == oldValue.text.length - 1;
    if (deletedSingleChar &&
        oldDigits == newDigits &&
        targetDigitCount > 0 &&
        newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      final removeIndex = targetDigitCount - 1;
      newDigits = newDigits.substring(0, removeIndex) +
          newDigits.substring(removeIndex + 1);
      targetDigitCount--;
    }

    if (newDigits.length > maxDigits) {
      newDigits = newDigits.substring(0, maxDigits);
      if (targetDigitCount > maxDigits) {
        targetDigitCount = maxDigits;
      }
    }

    final formatted = formatDigits(newDigits);
    final cursorOffset = _offsetForDigitCount(formatted, targetDigitCount);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  static int _countDigitsBefore(String text, int offset) {
    var count = 0;
    for (var i = 0; i < offset && i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        count++;
      }
    }
    return count;
  }

  static int _offsetForDigitCount(String formatted, int targetDigits) {
    if (targetDigits <= 0) {
      // Coloca o cursor logo após o prefixo inicial (ex: '(' no telefone) se existir.
      for (var i = 0; i < formatted.length; i++) {
        final code = formatted.codeUnitAt(i);
        if (code >= 48 && code <= 57) return i;
      }
      return formatted.length;
    }

    var seenDigits = 0;
    for (var i = 0; i < formatted.length; i++) {
      final code = formatted.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        seenDigits++;
        if (seenDigits == targetDigits) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }
}

/// Máscara automática para telefone fixo (10 dígitos) e celular (11 dígitos).
class PhoneInputFormatter extends DigitsMaskInputFormatter {
  const PhoneInputFormatter()
      : super(
          maxDigits: 11,
          formatDigits: Formatters.formatPhone,
        );
}

/// Máscara automática para CPF (11 dígitos) e CNPJ (14 dígitos).
class CpfCnpjInputFormatter extends DigitsMaskInputFormatter {
  const CpfCnpjInputFormatter()
      : super(
          maxDigits: 14,
          formatDigits: Formatters.formatCpfCnpj,
        );
}
