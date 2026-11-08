import 'package:flutter/material.dart';
import '../../core/formatters.dart';

class DatePickerField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final displayDate = isoDate.isNotEmpty ? Formatters.formatDate(isoDate) : '';

    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: displayDate),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        helperText: helperText,
      ),
      onTap: () async {
        DateTime initial = DateTime.tryParse(isoDate) ?? DateTime.now();
        final now = DateTime.now();
        if (initial.isAfter(now)) {
          initial = now;
        }

        DateTime firstDate = DateTime(2000, 1, 1);
        if (minIsoDate != null && minIsoDate!.isNotEmpty) {
          final parsedMin = DateTime.tryParse(minIsoDate!);
          if (parsedMin != null) {
            firstDate = parsedMin;
          }
        }

        DateTime lastDate = now;
        if (maxIsoDate != null && maxIsoDate!.isNotEmpty) {
          final parsedMax = DateTime.tryParse(maxIsoDate!);
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
          final newIso = Formatters.toIsoDate(picked);
          onDateSelected(newIso);
        }
      },
      validator: (val) {
        if (required && isoDate.isEmpty) {
          return 'Selecione uma data.';
        }
        return null;
      },
    );
  }
}

