import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A compact metric card for the 3-column stats row on the Dashboard.
///
/// Usage:
///   StatsCard(
///     label:      'Premium',
///     value:      '₹98',
///     valueColor: AppTheme.ltPrimary,
///     icon:       Icons.account_balance_wallet_rounded,
///   )
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.subtitle,
  });

  final String   label;
  final String   value;
  final Color?   valueColor;
  final IconData? icon;
  final Color?   iconColor;
  final String?  subtitle;

  @override
  Widget build(BuildContext context) {
    final effectiveValueColor = valueColor ?? AppTheme.ltTextPrimary;
    final effectiveIconColor  = iconColor  ?? effectiveValueColor;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color:        AppTheme.ltSurface,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: AppTheme.ltBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color:      Color(0x08000000),
              blurRadius: 8,
              offset:     Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: effectiveIconColor),
              const SizedBox(height: 8),
            ],
            Text(
              value,
              style: AppTheme.ltNumberMedium.copyWith(
                color:    effectiveValueColor,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTheme.ltBodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTheme.ltLabel.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
