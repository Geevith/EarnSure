import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Data model for a single step in the vertical timeline.
class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.timestamp,
    required this.icon,
    this.isCompleted = false,
    this.isActive    = false,
    this.isFailed    = false,
    this.subItems,
  });

  final String        label;
  final String        timestamp;
  final IconData      icon;
  final bool          isCompleted;
  final bool          isActive;
  final bool          isFailed;
  /// Optional nested checklist items (e.g., Fraud Check sub-steps).
  final List<String>? subItems;
}

/// A vertical timeline stepper showing claim/pipeline progress.
///
/// Usage:
///   VerticalTimelineStepper(steps: mySteps)
///   VerticalTimelineStepper(steps: mySteps, compact: true)
class VerticalTimelineStepper extends StatelessWidget {
  const VerticalTimelineStepper({
    super.key,
    required this.steps,
    this.compact = false,
  });

  final List<TimelineStep> steps;

  /// Compact mode reduces spacing for use inside claim list cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final step    = steps[i];
        final isLast  = i == steps.length - 1;
        return _StepRow(
          step:    step,
          isLast:  isLast,
          compact: compact,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.compact,
  });

  final TimelineStep step;
  final bool         isLast;
  final bool         compact;

  Color get _iconBg {
    if (step.isFailed)   return AppTheme.ltDangerLight;
    if (step.isCompleted) return AppTheme.ltSuccessLight;
    if (step.isActive)   return AppTheme.ltPrimaryLight;
    return const Color(0xFFF1F5F9);
  }

  Color get _iconColor {
    if (step.isFailed)   return AppTheme.ltDanger;
    if (step.isCompleted) return AppTheme.ltSuccess;
    if (step.isActive)   return AppTheme.ltPrimary;
    return AppTheme.ltTextMuted;
  }

  Color get _lineColor {
    if (step.isCompleted) return AppTheme.ltSuccess;
    if (step.isActive)   return AppTheme.ltPrimary.withOpacity(0.4);
    return AppTheme.ltBorder;
  }

  @override
  Widget build(BuildContext context) {
    final iconSize    = compact ? 28.0 : 36.0;
    final iconInner  = compact ? 14.0 : 18.0;
    final vSpacing   = compact ? 6.0  : 10.0;
    final lineHeight = compact ? 24.0 : 32.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: icon + connector line ──────────────────────────────────────
        SizedBox(
          width: iconSize + 8,
          child: Column(
            children: [
              Container(
                width:  iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color:        _iconBg,
                  shape:        BoxShape.circle,
                  border: Border.all(
                    color: _iconColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(step.icon, size: iconInner, color: _iconColor),
              ),
              if (!isLast)
                Container(
                  width:  2,
                  height: lineHeight,
                  margin: EdgeInsets.symmetric(vertical: vSpacing / 2),
                  decoration: BoxDecoration(
                    color:        _lineColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ── Right: label + timestamp + optional sub-items ───────────────────
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: (iconSize - (compact ? 16.0 : 18.0)) / 2, // vertically center text with icon
              bottom: isLast ? 0 : (compact ? 18.0 : 28.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        step.label,
                        style: (compact ? AppTheme.ltBodySmall : AppTheme.ltBody).copyWith(
                          color:      step.isActive
                              ? AppTheme.ltPrimary
                              : step.isCompleted
                                  ? AppTheme.ltTextPrimary
                                  : AppTheme.ltTextMuted,
                          fontWeight: (step.isActive || step.isCompleted)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      step.timestamp,
                      style: AppTheme.ltLabel.copyWith(fontSize: 10),
                    ),
                  ],
                ),

                // Sub-items (e.g., fraud check checklist)
                if (step.subItems != null && step.subItems!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...step.subItems!.map(
                    (item) => _SubCheckItem(label: item, compact: compact),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SubCheckItem extends StatelessWidget {
  const _SubCheckItem({required this.label, required this.compact});
  final String label;
  final bool   compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width:  compact ? 14 : 16,
            height: compact ? 14 : 16,
            decoration: BoxDecoration(
              color:  AppTheme.ltSuccessLight,
              shape:  BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size:  compact ? 8 : 9,
              color: AppTheme.ltSuccess,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTheme.ltBodySmall.copyWith(
                color: AppTheme.ltTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
