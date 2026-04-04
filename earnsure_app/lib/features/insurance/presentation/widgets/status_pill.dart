import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A small pill-shaped container for displaying status labels.
///
/// Usage examples:
///   StatusPill(label: 'Approved', bgColor: AppTheme.ltWarningLight, textColor: AppTheme.ltWarning)
///   StatusPill(label: 'Trust: 8.7', bgColor: AppTheme.ltPrimaryLight, textColor: AppTheme.ltPrimary)
///   StatusPill(label: 'ACTIVE', bgColor: AppTheme.ltSuccessLight, textColor: AppTheme.ltSuccess)
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.icon,
    this.iconSize = 11,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w700,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String    label;
  final Color     bgColor;
  final Color     textColor;
  final IconData? icon;
  final double    iconSize;
  final double    fontSize;
  final FontWeight fontWeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(999), // true pill shape
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTheme.ltLabel.copyWith(
              color:      textColor,
              fontSize:   fontSize,
              fontWeight: fontWeight,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
