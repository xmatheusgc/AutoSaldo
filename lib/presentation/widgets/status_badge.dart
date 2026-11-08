import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.docStatus(String status) {
    switch (status) {
      case AppConstants.docStatusUpToDate:
        return const StatusBadge(
          label: 'Doc em dia',
          backgroundColor: AppTheme.successLight,
          textColor: AppTheme.successGreen,
          icon: Icons.check_circle_outline,
        );
      case AppConstants.docStatusWithIssue:
        return const StatusBadge(
          label: 'Doc c/ pendência',
          backgroundColor: AppTheme.dangerLight,
          textColor: AppTheme.dangerRed,
          icon: Icons.error_outline,
        );
      case AppConstants.docStatusPendingCheck:
      default:
        return const StatusBadge(
          label: 'Doc a verificar',
          backgroundColor: AppTheme.warningLight,
          textColor: AppTheme.warningOrange,
          icon: Icons.help_outline,
        );
    }
  }

  factory StatusBadge.stockStatus(bool isInStock) {
    if (isInStock) {
      return const StatusBadge(
        label: 'Em estoque',
        backgroundColor: Color(0xFFEFF6FF), // Blue 50
        textColor: AppTheme.accentBlue,
        icon: Icons.directions_car_filled_outlined,
      );
    } else {
      return const StatusBadge(
        label: 'Vendido',
        backgroundColor: AppTheme.successLight,
        textColor: AppTheme.successGreen,
        icon: Icons.verified_outlined,
      );
    }
  }

  factory StatusBadge.paymentStatus(String status) {
    switch (status) {
      case AppConstants.paymentStatusSettled:
        return const StatusBadge(
          label: 'Quitado',
          backgroundColor: AppTheme.successLight,
          textColor: AppTheme.successGreen,
          icon: Icons.check,
        );
      case AppConstants.paymentStatusPartial:
        return const StatusBadge(
          label: 'Parcial',
          backgroundColor: AppTheme.warningLight,
          textColor: AppTheme.warningOrange,
          icon: Icons.pie_chart_outline,
        );
      case AppConstants.paymentStatusOpen:
      default:
        return const StatusBadge(
          label: 'Em aberto',
          backgroundColor: AppTheme.dangerLight,
          textColor: AppTheme.dangerRed,
          icon: Icons.hourglass_top_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

