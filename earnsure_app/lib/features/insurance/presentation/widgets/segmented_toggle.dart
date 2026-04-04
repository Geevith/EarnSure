import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A pill-shaped segmented toggle bar.
///
/// Usage:
///   SegmentedToggle(
///     segments: ['All', 'Approved', 'Paid'],
///     selectedIndex: _tab,
///     onChanged: (i) => setState(() => _tab = i),
///   )
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.activeTextColor,
    this.inactiveTextColor,
  });

  final List<String> segments;
  final int          selectedIndex;
  final ValueChanged<int> onChanged;

  // Optional overrides – defaults to fintech light palette
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;

  @override
  Widget build(BuildContext context) {
    final bgActive   = activeColor   ?? AppTheme.ltPrimary;
    final bgInactive = inactiveColor ?? const Color(0xFFE9EEF8);
    final fgActive   = activeTextColor   ?? Colors.white;
    final fgInactive = inactiveTextColor ?? AppTheme.ltTextSecondary;

    return Container(
      padding:     const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        bgInactive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(segments.length, (i) {
          final isSelected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? bgActive : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: bgActive.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                segments[i],
                style: AppTheme.ltLabel.copyWith(
                  color:      isSelected ? fgActive : fgInactive,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize:   12,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
