import 'package:flutter/material.dart';
import '../../core/formatters.dart';

class DatePickerField extends StatefulWidget {
  final String label;
  final String isoDate; // AAAA-MM-DD
  final ValueChanged<String> onDateSelected;
  final String? minIsoDate;
  final String? maxIsoDate;
  final bool required;
  final String? helperText;

  const DatePickerField({
    super.key,
    required this.label,
    required this.isoDate,
    required this.onDateSelected,
    this.minIsoDate,
    this.maxIsoDate,
    this.required = true,
    this.helperText,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late final TextEditingController _controller;

  String _formattedDisplay(String isoDate) =>
      isoDate.isNotEmpty ? Formatters.formatDate(isoDate) : '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formattedDisplay(widget.isoDate));
  }

  @override
  void didUpdateWidget(covariant DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isoDate != oldWidget.isoDate) {
      final nextText = _formattedDisplay(widget.isoDate);
      if (_controller.text != nextText) {
        _controller.text = nextText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.tryParse(widget.isoDate) ?? DateTime.now();
    final now = DateTime.now();
    if (initial.isAfter(now)) {
      initial = now;
    }

    DateTime firstDate = DateTime(2000, 1, 1);
    if (widget.minIsoDate != null && widget.minIsoDate!.isNotEmpty) {
      final parsedMin = DateTime.tryParse(widget.minIsoDate!);
      if (parsedMin != null) {
        firstDate = parsedMin;
      }
    }

    DateTime lastDate = now;
    if (widget.maxIsoDate != null && widget.maxIsoDate!.isNotEmpty) {
      final parsedMax = DateTime.tryParse(widget.maxIsoDate!);
      if (parsedMax != null) {
        lastDate = parsedMax;
      }
    }

    if (initial.isBefore(firstDate)) {
      initial = firstDate;
    }
    if (initial.isAfter(lastDate)) {
      initial = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('pt', 'BR'),
      helpText: 'SELECIONE A DATA',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (picked != null) {
      widget.onDateSelected(Formatters.toIsoDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        helperText: widget.helperText,
      ),
      onTap: _pickDate,
      validator: (val) {
        if (widget.required && widget.isoDate.isEmpty) {
          return 'Selecione uma data.';
        }
        return null;
      },
    );
  }
}

