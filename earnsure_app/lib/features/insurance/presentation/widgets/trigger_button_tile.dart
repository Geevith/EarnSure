import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A list tile for a disruption trigger event button.
///
/// Displays a colored icon pill on the left, the event label in the center,
/// and a play arrow chevron on the right.
///
/// Usage:
///   TriggerButtonTile(
///     label:   'Heavy Rain',
///     icon:    Icons.water_drop_rounded,
///     color:   AppTheme.ltPrimary,
///     bgColor: AppTheme.ltPrimaryLight,
///     onTap:   () => ...,
///   )
class TriggerButtonTile extends StatefulWidget {
  const TriggerButtonTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.subtitle,
  });

  final String     label;
  final IconData   icon;
  final Color      color;
  final Color      bgColor;
  final VoidCallback onTap;
  final String?    subtitle;

  @override
  State<TriggerButtonTile> createState() => _TriggerButtonTileState();
}

class _TriggerButtonTileState extends State<TriggerButtonTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _hovered = true),
      onTapUp:     (_) { setState(() => _hovered = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        _hovered
              ? widget.bgColor
              : AppTheme.ltSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? widget.color.withOpacity(0.35)
                : AppTheme.ltBorder,
            width: 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color:      widget.color.withOpacity(0.10),
                    blurRadius: 12,
                    offset:     const Offset(0, 4),
                  )
                ]
              : const [
                  BoxShadow(
                    color:      Color(0x0A000000),
                    blurRadius: 8,
                    offset:     Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            // ── Left icon pill ──────────────────────────────────────────────
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                color:        widget.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),

            const SizedBox(width: 14),

            // ── Label + subtitle ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: AppTheme.ltHeadingSmall.copyWith(fontSize: 14),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTheme.ltBodySmall,
                    ),
                  ],
                ],
              ),
            ),

            // ── Right arrow ─────────────────────────────────────────────────
            Container(
              width:  30,
              height: 30,
              decoration: BoxDecoration(
                color:        widget.bgColor,
                shape:        BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size:  16,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
