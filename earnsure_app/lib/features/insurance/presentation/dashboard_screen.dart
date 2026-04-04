import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sensors/providers/anti_spoofing_provider.dart';
import '../../sensors/presentation/sensor_debug_view.dart';
import '../providers/insurance_provider.dart';
import 'claims_modal.dart';
import 'widgets/activation_slider.dart';
import 'widgets/risk_score_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final Animation<double>   _pageAnim;
  bool _showDebugView = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pageAnim = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // Watch for disruption alerts and auto-show claims modal
  void _watchAlerts(InsuranceState insurance) {
    if (insurance.activeAlert != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && insurance.activeAlert != null) {
          showClaimsModal(context, insurance.activeAlert!);
        }
      });
    }
  }

  Future<void> _handleActivation() async {
    final payload = await ref.read(antiSpoofingProvider.notifier)
        .validateAndPackage();
    await ref.read(insuranceProvider.notifier)
        .activatePolicy('882a1072b3fffff', payload);
  }

  @override
  Widget build(BuildContext context) {
    final insurance = ref.watch(insuranceProvider);
    final session   = ref.watch(authProvider).value;
    _watchAlerts(insurance);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Main scrollable content
          FadeTransition(
            opacity: _pageAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _AppBar(
                  session:        session,
                  onDebugToggle:  () => setState(() => _showDebugView = !_showDebugView),
                  debugActive:    _showDebugView,
                  onLogout:       () => ref.read(authProvider.notifier).logout(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Policy status strip ──────────────────────────────
                      _PolicyStatusBanner(insurance: insurance),
                      const SizedBox(height: 20),

                      // ── Risk Score Card ──────────────────────────────────
                      if (insurance.riskProfile != null)
                        RiskScoreCard(
                          riskScore:              insurance.riskProfile!.riskScore,
                          disruptionProbability:  insurance.riskProfile!.disruptionProbability,
                          zoneRisk:               insurance.riskProfile!.zoneRisk,
                          city:                   session?.city ?? 'Chennai',
                        ),
                      const SizedBox(height: 20),

                      // ── Premium Details Card ─────────────────────────────
                      if (insurance.riskProfile != null)
                        _PremiumCard(profile: insurance.riskProfile!),
                      const SizedBox(height: 24),

                      // ── Activation Slider ────────────────────────────────
                      _ActivationSection(
                        insurance:       insurance,
                        onActivate:      _handleActivation,
                      ),
                      const SizedBox(height: 24),

                      // ── Anti-Spoofing Status Strip ───────────────────────
                      const _AntiSpoofingStrip(),
                      const SizedBox(height: 20),

                      // ── Demo Controls (Hackathon) ────────────────────────
                      _DemoControls(insurance: insurance),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Floating debug view (draggable)
          if (_showDebugView)
            const SensorDebugView(),
        ],
      ),
    );
  }
}

// ── Custom SliverAppBar ───────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.session,
    required this.onDebugToggle,
    required this.debugActive,
    required this.onLogout,
  });

  final RiderSession? session;
  final VoidCallback  onDebugToggle;
  final bool          debugActive;
  final VoidCallback  onLogout;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned:          true,
      expandedHeight:  100,
      backgroundColor: AppTheme.backgroundDark,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, ${session?.name.split(' ').first ?? 'Rider'} 👋',
                  style: AppTheme.headingSmall.copyWith(fontSize: 16),
                ),
                Text(
                  session?.platform ?? 'Zomato',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            _DebugToggle(active: debugActive, onTap: onDebugToggle),
            const SizedBox(width: 8),
            _AvatarMenu(
              name:     session?.name ?? 'R',
              onLogout: onLogout,
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: AppTheme.borderSubtle),
      ),
    );
  }
}

class _DebugToggle extends StatelessWidget {
  const _DebugToggle({required this.active, required this.onTap});
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        (active ? AppTheme.neonEmerald : AppTheme.surfaceElevated)
              .withOpacity(active ? 0.15 : 1.0),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
            color: active ? AppTheme.neonEmerald.withOpacity(0.5) : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terminal_rounded,
              size:  13,
              color: active ? AppTheme.neonEmerald : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'DEBUG',
              style: AppTheme.labelMedium.copyWith(
                fontSize: 10,
                color: active ? AppTheme.neonEmerald : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.name, required this.onLogout});
  final String       name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color:        AppTheme.surfaceElevated,
      shape:        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected:   (v) { if (v == 'logout') onLogout(); },
      itemBuilder:  (_) => [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 16, color: AppTheme.neonRed),
              const SizedBox(width: 8),
              Text('Sign Out', style: AppTheme.bodyMedium.copyWith(color: AppTheme.neonRed)),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius:          18,
        backgroundColor: AppTheme.neonEmerald.withOpacity(0.15),
        child: Text(
          name[0].toUpperCase(),
          style: AppTheme.headingSmall.copyWith(
            fontSize: 14, color: AppTheme.neonEmerald,
          ),
        ),
      ),
    );
  }
}

// ── Policy Status Banner ──────────────────────────────────────────────────────

class _PolicyStatusBanner extends StatelessWidget {
  const _PolicyStatusBanner({required this.insurance});
  final InsuranceState insurance;

  @override
  Widget build(BuildContext context) {
    if (insurance.isLoading) {
      return _LoadingSkeleton(height: 52, radius: 12);
    }

    final isActive = insurance.isPolicyActive;
    final color    = isActive ? AppTheme.neonEmerald : AppTheme.textMuted;
    final daysLeft = insurance.policy != null
        ? insurance.policy!.endDate.difference(DateTime.now()).inDays
        : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.shield_rounded : Icons.shield_outlined,
            color: color,
            size:  20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Policy Active' : 'No Active Policy',
                  style: AppTheme.headingSmall.copyWith(fontSize: 14, color: color),
                ),
                if (isActive && insurance.policy != null)
                  Text(
                    'Expires in $daysLeft days · ₹${insurance.policy!.weeklyPremiumInr.toStringAsFixed(0)}/week',
                    style: AppTheme.bodySmall.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
          if (isActive)
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonEmerald,
                boxShadow: AppTheme.neonGlow(AppTheme.neonEmerald, intensity: 1.2),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Premium Card ──────────────────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.profile});
  final RiskProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Weekly Premium', style: AppTheme.labelMedium),
              const Spacer(),
              if (profile.streakDiscountApplied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppTheme.neonEmerald.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: AppTheme.neonEmerald.withOpacity(0.25)),
                  ),
                  child: Text(
                    '−${profile.streakDiscountPct.toStringAsFixed(0)}% Streak',
                    style: AppTheme.labelMedium.copyWith(
                      fontSize: 10, color: AppTheme.neonEmerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween:    Tween(begin: 0, end: profile.weeklyPremiumInr),
                duration: const Duration(milliseconds: 800),
                curve:    Curves.easeOutCubic,
                builder: (_, val, __) => Text(
                  '₹ ${val.toStringAsFixed(0)}',
                  style: AppTheme.headingLarge.copyWith(
                    color: AppTheme.neonEmerald,
                    fontSize: 36,
                    shadows: [
                      Shadow(
                        color:      AppTheme.neonEmerald.withOpacity(0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text('/ week', style: AppTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              _PremiumStat(
                label: 'Max Payout',
                value: '₹450',
                icon:  Icons.account_balance_wallet_rounded,
                color: AppTheme.neonBlue,
              ),
              const SizedBox(width: 12),
              _PremiumStat(
                label: 'Coverage',
                value: '2 hrs/event',
                icon:  Icons.timer_rounded,
                color: AppTheme.neonAmber,
              ),
              const SizedBox(width: 12),
              _PremiumStat(
                label: 'Events',
                value: 'All types',
                icon:  Icons.bolt_rounded,
                color: AppTheme.neonEmerald,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumStat extends StatelessWidget {
  const _PremiumStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 5),
            Text(value, style: AppTheme.headingSmall.copyWith(fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.bodySmall.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Activation Section ────────────────────────────────────────────────────────

class _ActivationSection extends StatelessWidget {
  const _ActivationSection({
    required this.insurance,
    required this.onActivate,
  });

  final InsuranceState insurance;
  final VoidCallback   onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('SHIFT STATUS', style: AppTheme.labelMedium),
            const Spacer(),
            Icon(Icons.my_location_rounded, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text('Chennai · H3-882a…', style: AppTheme.bodySmall.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        ActivationSlider(
          isActive:  insurance.isPolicyActive,
          isLoading: insurance.isLoading,
          onActivate: onActivate,
        ),
        if (insurance.error != null) ...[
          const SizedBox(height: 10),
          Text(
            insurance.error!,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.neonRed, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

// ── Anti-Spoofing Strip ───────────────────────────────────────────────────────

class _AntiSpoofingStrip extends ConsumerWidget {
  const _AntiSpoofingStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spoof     = ref.watch(antiSpoofingProvider);
    final riskColor = switch (spoof.trustLevel) {
      'TRUSTED'    => AppTheme.neonEmerald,
      'MEDIUM'     => AppTheme.neonAmber,
      _            => AppTheme.neonRed,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        riskColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: riskColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: riskColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edge-AI Anti-Spoofing',
                  style: AppTheme.headingSmall.copyWith(fontSize: 13, color: riskColor),
                ),
                Text(
                  'StdDev: ${spoof.stdDevHz.toStringAsFixed(3)} Hz · ${spoof.trustLevel}',
                  style: AppTheme.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        riskColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: riskColor.withOpacity(0.3)),
            ),
            child: Text(
              '${(spoof.fraudScore * 100).toStringAsFixed(0)}% risk',
              style: AppTheme.monoBold.copyWith(fontSize: 11, color: riskColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Demo Controls (Hackathon helper) ─────────────────────────────────────────

class _DemoControls extends ConsumerWidget {
  const _DemoControls({required this.insurance});
  final InsuranceState insurance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HACKATHON DEMO',
          style: AppTheme.labelMedium.copyWith(color: AppTheme.neonAmber),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            await HapticUtils.heavy();
            ref.read(insuranceProvider.notifier).simulateDisruptionAlert();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color:        AppTheme.neonAmber.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: AppTheme.neonAmber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppTheme.neonAmber, size: 18),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Monsoon Alert',
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 14, color: AppTheme.neonAmber,
                      ),
                    ),
                    Text(
                      'Triggers claims modal with ₹450 payout',
                      style: AppTheme.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.neonAmber),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared Loading Skeleton ───────────────────────────────────────────────────

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton({required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: Color.lerp(
            AppTheme.surfaceCard,
            AppTheme.surfaceElevated,
            _ctrl.value,
          ),
        ),
      ),
    );
  }
}