import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/formatters.dart';
import '../theme/app_theme.dart';

/// Máscara de entrada para valores monetários em Real (BRL) com preenchimento
/// da direita para a esquerda em centavos (ex: "9500000" -> "95.000,00").
class CurrencyInputFormatter extends TextInputFormatter {
  final int maxDigits;

  CurrencyInputFormatter({this.maxDigits = 12});

  static final NumberFormat _decimalFormat = NumberFormat('#,##0.00', 'pt_BR');

  /// Formata centavos inteiros para exibição no campo sem prefixo "R$" (ex: "95.000,00").
  static String formatCents(int cents) {
    if (cents <= 0) return '';
    return _decimalFormat.format(cents / 100.0);
  }

  static const _emptyValue = TextEditingValue(
    text: '',
    selection: TextSelection.collapsed(offset: 0),
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trimmedNew = newValue.text.trim();
    // Se colar um valor inteiro brasileiro com separador de milhar sem vírgula (ex: "45.000" ou "R$ 95.000"),
    // interpreta como reais inteiros (* 100 centavos) em vez de centavos.
    if (oldValue.text.isEmpty &&
        RegExp(r'^(?:R\$\s*)?\d{1,3}(?:\.\d{3})+$').hasMatch(trimmedNew)) {
      final rawDigits = trimmedNew.replaceAll(RegExp(r'[^0-9]'), '');
      final effectiveDigits =
          rawDigits.length + 2 <= maxDigits ? '${rawDigits}00' : rawDigits;
      final cents = int.tryParse(effectiveDigits) ?? 0;
      if (cents <= 0) return _emptyValue;
      final formatted = formatCents(cents);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return _emptyValue;
    }

    final oldDigits = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      if (oldDigits.length >= maxDigits && digits.length > oldDigits.length) {
        return oldValue;
      }
      final truncated = digits.substring(0, maxDigits);
      final cents = int.tryParse(truncated) ?? 0;
      if (cents <= 0) return _emptyValue;
      final formatted = formatCents(cents);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final cents = int.tryParse(digits) ?? 0;
    if (cents <= 0) {
      return _emptyValue;
    }

    final formatted = formatCents(cents);
    final cursorOffset = _calculateCursorOffset(newValue, formatted);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  int _calculateCursorOffset(TextEditingValue newValue, String formatted) {
    final selection = newValue.selection;
    if (!selection.isValid || selection.extentOffset < 0) {
      return formatted.length;
    }

    final extent = selection.extentOffset.clamp(0, newValue.text.length);
    final textAfterCursor = newValue.text.substring(extent);
    final digitsAfterCursor = textAfterCursor.replaceAll(RegExp(r'[^0-9]'), '').length;

    if (digitsAfterCursor == 0) {
      return formatted.length;
    }

    int digitCount = 0;
    for (int i = formatted.length - 1; i >= 0; i--) {
      final code = formatted.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        digitCount++;
        if (digitCount == digitsAfterCursor) {
          return i;
        }
      }
    }

    return 0;
  }
}

class CurrencyTextField extends StatefulWidget {
  final String label;
  final int? initialValueCents;
  final ValueChanged<int> onChanged;
  final String? Function(String?)? validator;
  final bool required;
  final String? helperText;

  const CurrencyTextField({
    super.key,
    required this.label,
    this.initialValueCents,
    required this.onChanged,
    this.validator,
    this.required = false,
    this.helperText,
  });

  @override
  State<CurrencyTextField> createState() => _CurrencyTextFieldState();
}

class _CurrencyTextFieldState extends State<CurrencyTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialStr = widget.initialValueCents != null && widget.initialValueCents! > 0
        ? CurrencyInputFormatter.formatCents(widget.initialValueCents!)
        : '';
    _controller = TextEditingController(text: initialStr);
  }

  @override
  void didUpdateWidget(covariant CurrencyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValueCents != oldWidget.initialValueCents) {
      final currentCents = Formatters.parseCurrencyToCents(_controller.text);
      if ((widget.initialValueCents ?? 0) != currentCents) {
        final initialStr = widget.initialValueCents != null && widget.initialValueCents! > 0
            ? CurrencyInputFormatter.formatCents(widget.initialValueCents!)
            : '';
        _controller.value = TextEditingValue(
          text: initialStr,
          selection: TextSelection.collapsed(offset: initialStr.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final cents = Formatters.parseCurrencyToCents(value);
    widget.onChanged(cents);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      style: const TextStyle(fontFeatures: AppTheme.tabularNumbers),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '0,00',
        prefixText: 'R\$ ',
        prefixStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textMain,
          fontFeatures: AppTheme.tabularNumbers,
        ),
        helperText: widget.helperText,
      ),
      onChanged: _handleChanged,
      validator: (val) {
        if (widget.required) {
          final cents = Formatters.parseCurrencyToCents(val ?? '');
          if (cents <= 0) {
            return 'Informe um valor válido maior que zero.';
          }
        }
        if (widget.validator != null) {
          return widget.validator!(val);
        }
        return null;
      },
    );
  }
}
