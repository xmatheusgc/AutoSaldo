import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/error_messages.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../domain/models/expense.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_text_field.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/responsive_layout.dart';

class ExpenseFormDialog extends StatefulWidget {
  final String workspaceId;
  final String vehicleId;
  final String userUid;
  final String? userEmail;
  final ExpenseRepository expenseRepository;
  final Expense? expenseToEdit;

  const ExpenseFormDialog({
    super.key,
    required this.workspaceId,
    required this.vehicleId,
    required this.userUid,
    this.userEmail,
    required this.expenseRepository,
    this.expenseToEdit,
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

  bool get _isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    if (e != null) {
      _amountCents = e.amountCents;
      _date = e.date;
      _category = AppConstants.expenseCategoryLabels.containsKey(e.category)
          ? e.category
          : AppConstants.expenseCategoryOther;
      _descController.text = e.description ?? '';
    }
  }

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
      final description =
          _descController.text.trim().isNotEmpty ? _descController.text.trim() : null;

      if (_isEditing) {
        final existing = widget.expenseToEdit!;
        final updated = Expense(
          id: existing.id,
          vehicleId: existing.vehicleId,
          amountCents: _amountCents,
          date: _date,
          category: _category,
          description: description,
          status: existing.status,
          createdAt: existing.createdAt,
          updatedAt: now,
          createdByUid: existing.createdByUid,
          updatedByUid: widget.userUid,
          createdByEmail: existing.createdByEmail,
          revertedAt: existing.revertedAt,
          revertedByUid: existing.revertedByUid,
        );

        await widget.expenseRepository.updateExpense(
          widget.workspaceId,
          updated,
          widget.userUid,
          userEmail: widget.userEmail,
        );
      } else {
        final expense = Expense(
          id: '',
          vehicleId: widget.vehicleId,
          amountCents: _amountCents,
          date: _date,
          category: _category,
          description: description,
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
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMessages.friendly(
            e,
            fallback: 'Não foi possível salvar a despesa. Tente novamente.',
          );
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
    return AdaptiveModalContainer(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

                    // Topo com Título e Fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isEditing ? 'Editar Despesa' : 'Lançar Despesa',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13, fontWeight: FontWeight.w600),
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
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
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
                        hintText: 'Ex: Troca de óleo, funilaria...',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botão Salvar
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEditing ? 'Salvar Alterações' : 'Salvar Despesa',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                    ),
          ],
        ),
      ),
    );
  }
}
