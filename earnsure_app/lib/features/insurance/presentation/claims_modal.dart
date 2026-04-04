import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../providers/insurance_provider.dart';

/// Shows the glassmorphism claims bottom sheet when a disruption alert is active.
void showClaimsModal(BuildContext context, DisruptionAlert alert) {
  HapticUtils.heavy();
  showModalBottomSheet(
    context:       context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:       (_) => _ClaimsSheet(alert: alert),
  );
}

class _ClaimsSheet extends ConsumerStatefulWidget {
  const _ClaimsSheet({required this.alert});
  final DisruptionAlert alert;

  @override
  ConsumerState<_ClaimsSheet> createState() => _ClaimsSheetState();
}

class _ClaimsSheetState extends ConsumerState<_ClaimsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _iconSpinAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);

    _iconSpinAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve:  const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: _SheetContent(
          alert:        widget.alert,
          iconSpinAnim: _iconSpinAnim,
          onDismiss: () {
            ref.read(insuranceProvider.notifier).dismissAlert();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({
    required this.alert,
    required this.iconSpinAnim,
    required this.onDismiss,
  });

  final DisruptionAlert   alert;
  final Animation<double> iconSpinAnim;
  final VoidCallback      onDismiss;

  Color get _statusColor => switch (alert.status) {
        DisruptionStatus.approved    => AppTheme.neonEmerald,
        DisruptionStatus.softFlagged => AppTheme.neonAmber,
        DisruptionStatus.pending     => AppTheme.neonBlue,
        _                            => AppTheme.textMuted,
      };

  String get _statusLabel => switch (alert.status) {
        DisruptionStatus.approved    => 'PAYOUT APPROVED',
        DisruptionStatus.softFlagged => 'SOFT FLAGGED',
        DisruptionStatus.pending     => 'PROCESSING',
        _                            => 'UNKNOWN',
      };

  IconData get _statusIcon => switch (alert.status) {
        DisruptionStatus.approved    => Icons.check_circle_rounded,
        DisruptionStatus.softFlagged => Icons.warning_amber_rounded,
        DisruptionStatus.pending     => Icons.hourglass_top_rounded,
        _                            => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Container(
      decoration: BoxDecoration(
        // Glassmorphism effect
        color:        AppTheme.surfaceDark.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border:       Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 48, spreadRadius: -8),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24, 12, 24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(color: color),
          const SizedBox(height: 24),
          _AlertHeader(
            alert:        alert,
            iconSpinAnim: iconSpinAnim,
            statusLabel:  _statusLabel,
            statusIcon:   _statusIcon,
            color:        color,
          ),
          const SizedBox(height: 28),
          _PayoutAmount(alert: alert, color: color),
          const SizedBox(height: 20),
          _EventDetails(alert: alert),
          const SizedBox(height: 28),
          if (alert.status == DisruptionStatus.softFlagged)
            _SoftFlagBanner(),
          const SizedBox(height: 8),
          _DismissButton(onDismiss: onDismiss, color: color),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  40, height: 4,
      decoration: BoxDecoration(
        color:        color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _AlertHeader extends StatelessWidget {
  const _AlertHeader({
    required this.alert,
    required this.iconSpinAnim,
    required this.statusLabel,
    required this.statusIcon,
    required this.color,
  });

  final DisruptionAlert   alert;
  final Animation<double> iconSpinAnim;
  final String            statusLabel;
  final IconData          statusIcon;
  final Color             color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RotationTransition(
          turns: Tween<double>(begin: 0, end: 0.0).animate(iconSpinAnim),
          child: ScaleTransition(
            scale: iconSpinAnim,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape:      BoxShape.circle,
                color:      color.withOpacity(0.12),
                border:     Border.all(color: color.withOpacity(0.35)),
                boxShadow: AppTheme.neonGlow(color, intensity: 0.7),
              ),
              child: Icon(statusIcon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                statusLabel,
                style: AppTheme.monoBold.copyWith(fontSize: 10, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _disruptionTitle(alert.disruption_type),
              style: AppTheme.headingSmall,
            ),
          ],
        ),
      ],
    );
  }

  String _disruptionTitle(String type) => switch (type) {
        'monsoon'          => 'Monsoon Flooding',
        'heatwave'         => 'Extreme Heatwave',
        'traffic_gridlock' => 'Traffic Gridlock',
        'platform_outage'  => 'Platform Outage',
        _                  => 'Disruption Alert',
      };
}

class _PayoutAmount extends StatelessWidget {
  const _PayoutAmount({required this.alert, required this.color});
  final DisruptionAlert alert;
  final Color           color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text('Payout Amount', style: AppTheme.labelMedium),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween:    Tween(begin: 0, end: alert.payoutAmountInr),
            duration: const Duration(milliseconds: 900),
            curve:    Curves.easeOutCubic,
            builder: (_, val, __) => Text(
              '₹ ${val.toStringAsFixed(0)}',
              style: AppTheme.headingLarge.copyWith(
                fontSize: 42,
                color:    color,
                shadows: [
                  Shadow(color: color.withOpacity(0.5), blurRadius: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '80% of 2hr estimated income',
            style: AppTheme.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.alert});
  final DisruptionAlert alert;

  @override
  Widget build(BuildContext context) {
    final minutesAgo = DateTime.now().difference(alert.triggeredAt).inMinutes;
    return Row(
      children: [
        _DetailChip(
          icon:  Icons.grid_view_rounded,
          label: 'Zone',
          value: alert.h3Index.substring(0, 10) + '…',
        ),
        const SizedBox(width: 10),
        _DetailChip(
          icon:  Icons.access_time_rounded,
          label: 'Triggered',
          value: '${minutesAgo}m ago',
        ),
        const SizedBox(width: 10),
        _DetailChip(
          icon:  Icons.bolt_rounded,
          label: 'Method',
          value: 'Dual-Key',
          color: AppTheme.neonBlue,
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color?   color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: AppTheme.glassCard(borderRadius: 12),
        child: Column(
          children: [
            Icon(icon, color: c, size: 16),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.bodySmall.copyWith(fontSize: 10)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.labelMedium.copyWith(
                color:    AppTheme.textPrimary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftFlagBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppTheme.neonAmber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.neonAmber.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.neonAmber, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sensor anomaly detected. Complete 1 delivery post-event to unlock full payout.',
              style: AppTheme.bodySmall.copyWith(
                color:  AppTheme.neonAmber.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onDismiss, required this.color});
  final VoidCallback onDismiss;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onDismiss,
        style: ElevatedButton.styleFrom(
          backgroundColor:  color,
          foregroundColor:  AppTheme.backgroundDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation:        0,
        ),
        child: Text(
          'Got it',
          style: AppTheme.headingSmall.copyWith(
            fontSize: 15,
            color:    AppTheme.backgroundDark,
          ),
        ),
      ),
    );
  }
}