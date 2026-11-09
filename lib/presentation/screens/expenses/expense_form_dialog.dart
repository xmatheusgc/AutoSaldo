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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pílula cinza iOS
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Topo com Título e Fechar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lançar Despesa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22, color: AppTheme.textMuted),
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
                          : const Text('Salvar Despesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
