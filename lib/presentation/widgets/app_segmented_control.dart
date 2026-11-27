import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSegmentedItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AppSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Controle segmentado padronizado com altura tátil >= 44px, centralização óptica
/// de ícone + texto e largura ergonômica em telas grandes.
class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentedItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double? maxDesktopWidth;
  final AlignmentGeometry desktopAlignment;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.maxDesktopWidth = 440,
    this.desktopAlignment = Alignment.center,
  });

  static const StrutStyle _labelStrut = StrutStyle(
    fontSize: 13,
    height: 1.15,
    forceStrutHeight: true,
  );

  static const TextHeightBehavior _heightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  @override
  Widget build(BuildContext context) {
    final control = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _buildSegment(items[i])),
          ],
        ],
      ),
    );

    if (maxDesktopWidth == null) return control;

    return Align(
      alignment: desktopAlignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDesktopWidth!),
        child: control,
      ),
    );
  }

  Widget _buildSegment(AppSegmentedItem<T> item) {
    final selected = item.value == selectedValue;
    final fgColor = selected ? Colors.white : AppTheme.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.primaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(item.value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 16, color: fgColor),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      strutStyle: _labelStrut,
                      textHeightBehavior: _heightBehavior,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pílula de filtro/ordenação reutilizável com altura mínima acessível e alinhamento uniforme.
class AppFilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const AppFilterPill({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppTheme.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.textMain;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? selectedColor : AppTheme.borderInteractive,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? Colors.white : AppTheme.textMuted),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  strutStyle: AppSegmentedControl._labelStrut,
                  textHeightBehavior: AppSegmentedControl._heightBehavior,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de abas limpa com linha inferior (estilo Uber Início / Material Primary Tabs).
/// Não adiciona `label` duplicado em `Semantics` para preservar acessibilidade e buscas por rótulo.
class AppUnderlineTabBar<T> extends StatelessWidget {
  final List<AppSegmentedItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;
  final bool showBottomBorder;

  const AppUnderlineTabBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: showBottomBorder
          ? const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
            )
          : const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _UnderlineTabButton<T>(
                item: items[i],
                selected: items[i].value == selectedValue,
                onTap: () => onChanged(items[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnderlineTabButton<T> extends StatelessWidget {
  final AppSegmentedItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  const _UnderlineTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.textMain : AppTheme.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppTheme.textMain : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 15, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                item.label,
                maxLines: 1,
                strutStyle: const StrutStyle(
                  fontSize: 13.5,
                  height: 1.2,
                  forceStrutHeight: true,
                ),
                textHeightBehavior: AppSegmentedControl._heightBehavior,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
