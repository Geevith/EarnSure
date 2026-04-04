import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Data model for a single item in the CustomBottomNavBar.
class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String     label;
  final IconData   icon;
  final VoidCallback onTap;
}

/// A sticky flat-gray footer nav bar spanning the full screen width.
///
/// Usage:
///   CustomBottomNavBar(
///     items: [
///       BottomNavItem(label: 'Claim History', icon: Icons.history_rounded, onTap: ...),
///       BottomNavItem(label: 'Change Plan',   icon: Icons.tune_rounded,    onTap: ...),
///     ],
///   )
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key, required this.items});

  final List<BottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      width:   double.infinity,
      padding: EdgeInsets.only(
        top:    14,
        bottom: bottomPad > 0 ? bottomPad : 14,
        left:   12,
        right:  12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.ltSurface,
        border: Border(
          top: BorderSide(color: AppTheme.ltBorder, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: _NavButton(item: item),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavButton extends StatefulWidget {
  const _NavButton({required this.item});
  final BottomNavItem item;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.item.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color:        _pressed
              ? const Color(0xFFEFF3FA)
              : const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: _pressed
                ? AppTheme.ltPrimary.withOpacity(0.25)
                : AppTheme.ltBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.icon,
              size:  16,
              color: _pressed ? AppTheme.ltPrimary : AppTheme.ltTextSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.item.label,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.ltLabel.copyWith(
                  color:      _pressed ? AppTheme.ltPrimary : AppTheme.ltTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize:   12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
