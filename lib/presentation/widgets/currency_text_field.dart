import 'package:flutter/material.dart';
import '../../core/formatters.dart';

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
        ? Formatters.formatCurrency(widget.initialValueCents!).replaceAll('R\$', '').trim()
        : '';
    _controller = TextEditingController(text: initialStr);
  }

  @override
  void didUpdateWidget(covariant CurrencyTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValueCents != oldWidget.initialValueCents) {
      final currentCents = Formatters.parseCurrencyToCents(_controller.text);
      if (widget.initialValueCents != currentCents) {
        final initialStr = widget.initialValueCents != null && widget.initialValueCents! > 0
            ? Formatters.formatCurrency(widget.initialValueCents!).replaceAll('R\$', '').trim()
            : '';
        _controller.text = initialStr;
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: 'R\$ ',
        prefixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
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
