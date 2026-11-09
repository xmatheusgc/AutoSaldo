import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../domain/models/expense.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';

class ExpenseFormDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final String userUid;
  final String? userEmail;
  final ExpenseRepository expenseRepository;

  const ExpenseFormDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.userUid,
    this.userEmail,
    required this.expenseRepository,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  int _amountCents = 0;
  String _date = Formatters.todayIsoDate();
  String _category = AppConstants.expenseCategoryWorkshop;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountCents <= 0) {
      setState(() {
        _error = 'O valor da despesa deve ser maior que zero.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final expense = Expense(
        id: '',
        vehicleId: widget.vehicleId,
        amountCents: _amountCents,
        date: _date,
        category: _category,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
        updatedAt: now,
        createdByUid: widget.userUid,
        updatedByUid: widget.userUid,
        createdByEmail: widget.userEmail,
      );

      await widget.expenseRepository.createExpense(
        widget.workspaceId,
        expense,
        widget.userUid,
        userEmail: widget.userEmail,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao salvar despesa: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lançar Despesa'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Lançar somente despesas pagas. Despesas válidas compõem o custo total do veículo.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                CurrencyTextField(
                  label: 'Valor da despesa *',
                  initialValueCents: _amountCents,
                  required: true,
                  onChanged: (val) {
                    _amountCents = val;
                  },
                ),
                const SizedBox(height: 14),

                DatePickerField(
                  label: 'Data do pagamento *',
                  isoDate: _date,
                  onDateSelected: (newDate) {
                    setState(() {
                      _date = newDate;
                    });
                  },
                  helperText: 'Despesas não aceitam datas futuras.',
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoria *'),
                  items: AppConstants.expenseCategoryLabels.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Ex: Troca de óleo e filtro',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Gravar'),
        ),
      ],
    );
  }
}
