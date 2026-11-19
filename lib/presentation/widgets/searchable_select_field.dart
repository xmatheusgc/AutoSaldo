import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchableSelectField extends StatelessWidget {
  final String label;
  final String? hintText;
  final String? manualHintText;
  final List<String> options;
  final List<String>? allOptions;
  final String? selectedValue;
  final bool isOtherMode;
  final bool canSwitchToSelect;
  final TextEditingController manualController;
  final bool isLoading;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onOtherSelected;
  final VoidCallback? onSwitchToSelect;

  const SearchableSelectField({
    super.key,
    required this.label,
    this.hintText,
    this.manualHintText,
    required this.options,
    this.allOptions,
    required this.selectedValue,
    required this.isOtherMode,
    this.canSwitchToSelect = true,
    required this.manualController,
    this.isLoading = false,
    this.enabled = true,
    this.validator,
    required this.onOptionSelected,
    required this.onOtherSelected,
    this.onSwitchToSelect,
  });

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || isLoading) return;

    final result = await showDialog<_PickerResult>(
      context: context,
      builder: (ctx) => _SearchablePickerDialog(
        title: label.replaceAll('*', '').trim(),
        options: options,
        allOptions: allOptions,
        selectedValue: selectedValue,
      ),
    );

    if (result == null) return;
    if (result.isOther) {
      onOtherSelected();
    } else if (result.value != null) {
      onOptionSelected(result.value!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isOtherMode) {
      return TextFormField(
        controller: manualController,
        enabled: enabled,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: manualHintText ?? hintText,
          suffixIcon: canSwitchToSelect && onSwitchToSelect != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton.icon(
                    onPressed: enabled ? onSwitchToSelect : null,
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 18),
                    label: const Text(
                      'Lista',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                )
              : null,
        ),
        validator: validator,
      );
    }

    return FormField<String>(
      key: ValueKey('select_${label}_$selectedValue'),
      initialValue: selectedValue,
      validator: (_) => validator?.call(selectedValue),
      builder: (state) {
        final displayText = (selectedValue != null && selectedValue!.isNotEmpty)
            ? selectedValue!
            : null;
        final hasDisplayText = displayText != null || isLoading;

        return InkWell(
          onTap: (enabled && !isLoading) ? () => _openPicker(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            isEmpty: !hasDisplayText,
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              enabled: enabled,
              errorText: state.errorText,
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.arrow_drop_down),
            ),
            child: hasDisplayText
                ? Text(
                    displayText ?? 'Carregando...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: displayText != null
                          ? (enabled ? AppTheme.textMain : AppTheme.textMuted)
                          : AppTheme.textMuted,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _PickerResult {
  final String? value;
  final bool isOther;

  const _PickerResult.selected(this.value) : isOther = false;
  const _PickerResult.other()
      : value = null,
        isOther = true;
}

class _SearchablePickerDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final List<String>? allOptions;
  final String? selectedValue;

  const _SearchablePickerDialog({
    required this.title,
    required this.options,
    this.allOptions,
    this.selectedValue,
  });

  @override
  State<_SearchablePickerDialog> createState() => _SearchablePickerDialogState();
}

class _SearchablePickerDialogState extends State<_SearchablePickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExtraOptions =
        widget.allOptions != null && widget.allOptions!.length > widget.options.length;
    final activeOptions = (_showAll && hasExtraOptions)
        ? widget.allOptions!
        : widget.options;

    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = normalizedQuery.isEmpty
        ? activeOptions
        : activeOptions
            .where((o) => o.toLowerCase().contains(normalizedQuery))
            .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum resultado encontrado.\nUse a opção "Outro" abaixo para digitar manualmente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final option = filtered[idx];
                        final isSelected = option == widget.selectedValue;
                        return ListTile(
                          dense: true,
                          title: Text(
                            option,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppTheme.primaryDark : AppTheme.textMain,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppTheme.primaryDark, size: 20)
                              : null,
                          onTap: () => Navigator.of(context).pop(_PickerResult.selected(option)),
                        );
                      },
                    ),
            ),
            if (hasExtraOptions) ...[
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: Icon(
                  _showAll ? Icons.filter_list : Icons.unfold_more,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                title: Text(
                  _showAll
                      ? 'Mostrar apenas marcas principais'
                      : 'Ver todas as marcas da FIPE (${widget.allOptions!.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                onTap: () => setState(() => _showAll = !_showAll),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.primaryDark),
              title: const Text(
                'Outro (digitar manualmente)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDark,
                ),
              ),
              onTap: () => Navigator.of(context).pop(const _PickerResult.other()),
            ),
          ],
        ),
      ),
    );
  }
}
