import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.icon,
  });

  factory StatusBadge.docStatus(String status) {
    switch (status) {
      case AppConstants.docStatusUpToDate:
        return const StatusBadge(
          label: 'Doc em dia',
          backgroundColor: AppTheme.successLight,
          textColor: AppTheme.successGreen,
          borderColor: AppTheme.successBorder,
          icon: Icons.check_circle,
        );
      case AppConstants.docStatusWithIssue:
        return const StatusBadge(
          label: 'Doc c/ pendência',
          backgroundColor: AppTheme.dangerLight,
          textColor: AppTheme.dangerRed,
          borderColor: AppTheme.dangerBorder,
          icon: Icons.error,
        );
      case AppConstants.docStatusPendingCheck:
      default:
        return const StatusBadge(
          label: 'Doc a verificar',
          backgroundColor: AppTheme.warningLight,
          textColor: AppTheme.warningOrange,
          borderColor: AppTheme.warningBorder,
          icon: Icons.help_outline,
        );
    }
  }

  factory StatusBadge.stockStatus(bool isInStock) {
    if (isInStock) {
      return const StatusBadge(
        label: 'Em estoque',
        backgroundColor: AppTheme.accentSoft,
        textColor: AppTheme.accentBlue,
        borderColor: Color(0xFFBFDBFE),
        icon: Icons.directions_car,
      );
    } else {
      return const StatusBadge(
        label: 'Vendido',
        backgroundColor: AppTheme.successLight,
        textColor: AppTheme.successGreen,
        borderColor: AppTheme.successBorder,
        icon: Icons.verified,
      );
    }
  }

  factory StatusBadge.consigned() {
    return const StatusBadge(
      label: 'Consignado',
      backgroundColor: Color(0xFFEEF2FF),
      textColor: Color(0xFF3730A3),
      borderColor: Color(0xFFC7D2FE),
      icon: Icons.handshake_outlined,
    );
  }

  factory StatusBadge.returnedToOwner() {
    return const StatusBadge(
      label: 'Devolvido',
      backgroundColor: AppTheme.sectionDivider,
      textColor: AppTheme.textMuted,
      borderColor: AppTheme.borderSubtle,
      icon: Icons.assignment_return_outlined,
    );
  }

  factory StatusBadge.payoutStatus(int netPayoutCents, int paidCents) {
    if (netPayoutCents <= 0 || paidCents >= netPayoutCents) {
      return const StatusBadge(
        label: 'Repassado',
        backgroundColor: AppTheme.successLight,
        textColor: AppTheme.successGreen,
        borderColor: AppTheme.successBorder,
        icon: Icons.check,
      );
    }
    if (paidCents > 0) {
      return const StatusBadge(
        label: 'Parcial',
        backgroundColor: AppTheme.warningLight,
        textColor: AppTheme.warningOrange,
        borderColor: AppTheme.warningBorder,
        icon: Icons.pie_chart,
      );
    }
    return const StatusBadge(
      label: 'A repassar',
      backgroundColor: AppTheme.warningLight,
      textColor: AppTheme.warningOrange,
      borderColor: AppTheme.warningBorder,
      icon: Icons.hourglass_top,
    );
  }

  factory StatusBadge.paymentStatus(String status) {
    switch (status) {
      case AppConstants.paymentStatusSettled:
        return const StatusBadge(
          label: 'Quitado',
          backgroundColor: AppTheme.successLight,
          textColor: AppTheme.successGreen,
          borderColor: AppTheme.successBorder,
          icon: Icons.check,
        );
      case AppConstants.paymentStatusPartial:
        return const StatusBadge(
          label: 'Parcial',
          backgroundColor: AppTheme.warningLight,
          textColor: AppTheme.warningOrange,
          borderColor: AppTheme.warningBorder,
          icon: Icons.pie_chart,
        );
      case AppConstants.paymentStatusOpen:
      default:
        return const StatusBadge(
          label: 'Em aberto',
          backgroundColor: AppTheme.dangerLight,
          textColor: AppTheme.dangerRed,
          borderColor: AppTheme.dangerBorder,
          icon: Icons.hourglass_top,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
