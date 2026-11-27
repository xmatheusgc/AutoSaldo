import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Barra superior padrão com título da seção e botão de conta (no mobile).
/// Garante posicionamento e proporções idênticas entre as telas principais.
class ScreenHeaderRow extends StatelessWidget {
  final String title;
  final String? userInitial;
  final VoidCallback? onOpenAccount;

  const ScreenHeaderRow({
    super.key,
    required this.title,
    this.userInitial,
    this.onOpenAccount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMain,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (onOpenAccount != null)
            Tooltip(
              message: 'Minha Conta',
              child: Semantics(
                button: true,
                label: 'Minha Conta',
                child: InkWell(
                  onTap: onOpenAccount,
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.sectionDivider,
                        child: Text(
                          userInitial ?? 'U',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
