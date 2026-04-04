import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sensors/providers/anti_spoofing_provider.dart';
import '../providers/insurance_provider.dart';
import 'claims_modal.dart';
import 'widgets/activation_slider.dart';
import 'widgets/custom_bottom_nav_bar.dart';
import 'widgets/stats_card.dart';
import 'widgets/status_pill.dart';
import 'widgets/trigger_button_tile.dart';
import 'claim_history_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
//  DashboardScreen — Fintech light-mode redesign
//  ▸ All providers & logic calls are PRESERVED unchanged.
//  ▸ Only the UI layer (Widget tree) has been refactored.
// ═══════════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ── Preserved animation controller ────────────────────────────────────────
  late final AnimationController _pageCtrl;
  late final Animation<double>   _pageAnim;

  /// Guards against the modal stacking bug: ref.listen only fires when
  /// activeAlert transitions null→non-null, but this bool ensures we never
  /// open a second sheet while one is already showing (e.g. rapid taps).
  bool _modalOpen = false;

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

  // ── Preserved activation handler ───────────────────────────────────────────
  Future<void> _handleActivation() async {
    final payload = await ref
        .read(antiSpoofingProvider.notifier)
        .validateAndPackage();
    await ref
        .read(insuranceProvider.notifier)
        .activatePolicy('882a1072b3fffff', payload);
  }

  void _goToClaimHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClaimHistoryScreen()),
    );
  }

  // ── Trigger buttons config — maps each event to simulateDisruptionAlert() ──
  List<_TriggerConfig> get _triggers => [
        _TriggerConfig(
          label:    'Heavy Rain',
          subtitle: 'Rainfall > 50 mm/hr detected',
          icon:     Icons.water_drop_rounded,
          color:    AppTheme.ltPrimary,
          bgColor:  AppTheme.ltPrimaryLight,
        ),
        _TriggerConfig(
          label:    'Extreme Heat',
          subtitle: 'Temperature > 42°C in zone',
          icon:     Icons.wb_sunny_rounded,
          color:    AppTheme.ltWarning,
          bgColor:  AppTheme.ltWarningLight,
        ),
        _TriggerConfig(
          label:    'Traffic Gridlock',
          subtitle: 'Speed < 5 km/h for 30+ min',
          icon:     Icons.traffic_rounded,
          color:    AppTheme.ltDanger,
          bgColor:  AppTheme.ltDangerLight,
        ),
        _TriggerConfig(
          label:    'Platform Outage',
          subtitle: 'App offline > 45 min',
          icon:     Icons.cloud_off_rounded,
          color:    AppTheme.ltPurple,
          bgColor:  AppTheme.ltPurpleLight,
        ),
        _TriggerConfig(
          label:    'Monsoon Flood',
          subtitle: 'H3 zone flagged by IMD',
          icon:     Icons.flood_rounded,
          color:    AppTheme.ltTeal,
          bgColor:  AppTheme.ltTealLight,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    // ── KEY FIX: use ref.listen instead of calling a method in build().
    //    ref.listen fires only when the value actually changes, preventing
    //    the addPostFrameCallback stacking that caused repeated modal opens.
    ref.listen<InsuranceState>(insuranceProvider, (prev, next) {
      if (next.activeAlert != null &&
          next.activeAlert != prev?.activeAlert &&
          !_modalOpen &&
          mounted) {
        _modalOpen = true;
        showClaimsModal(context, next.activeAlert!).then((_) {
          if (mounted) setState(() => _modalOpen = false);
          ref.read(insuranceProvider.notifier).dismissAlert();
        });
      }
    });

    // ── Watch providers (logic UNCHANGED) ─────────────────────────────────
    final insurance = ref.watch(insuranceProvider);
    final session   = ref.watch(authProvider).value;
    final spoof     = ref.watch(antiSpoofingProvider);

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.ltBackground,
        body: FadeTransition(
          opacity: _pageAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Dark Header AppBar ─────────────────────────────────
              _FintechAppBar(
                session:  session,
                spoof:    spoof,
                onLogout: () =>
                    ref.read(authProvider.notifier).logout(),
              ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // ── [1] Active Policy Card (green) ───────────────
                        _ActivePolicyCard(insurance: insurance, session: session),
                        const SizedBox(height: 16),

                        // ── [2] Stats Row ────────────────────────────────
                        _StatsRow(insurance: insurance),
                        const SizedBox(height: 24),

                        // ── [3] Trigger Buttons section ──────────────────
                        _SectionHeader(
                          title:    'TRIGGER EVENTS',
                          subtitle: 'Tap to simulate a disruption claim',
                        ),
                        const SizedBox(height: 12),

                        // ── [4] 5 Trigger Buttons ────────────────────────
                        ..._triggers.map((t) => TriggerButtonTile(
                              label:    t.label,
                              subtitle: t.subtitle,
                              icon:     t.icon,
                              color:    t.color,
                              bgColor:  t.bgColor,
                              onTap: () async {
                                await HapticUtils.heavy();
                                ref
                                    .read(insuranceProvider.notifier)
                                    .simulateDisruptionAlert();
                              },
                            )),
                        const SizedBox(height: 24),

                        // ── [5] Anti-Spoofing strip (restyled) ───────────
                        _LightAntiSpoofingStrip(spoof: spoof),
                        const SizedBox(height: 16),

                        // ── [6] Activation Section (logic PRESERVED) ─────
                        _ActivationSection(
                          insurance:  insurance,
                          onActivate: _handleActivation,
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Removed debug view for production ──────────────────────────
          ],
        ),

        // ── Sticky bottom nav ─────────────────────────────────────────────
        bottomNavigationBar: CustomBottomNavBar(
          items: [
            BottomNavItem(
              label: 'Claim History',
              icon:  Icons.history_rounded,
              onTap: _goToClaimHistory,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internal trigger config data class ─────────────────────────────────────

class _TriggerConfig {
  const _TriggerConfig({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
  final String   label;
  final String   subtitle;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION WIDGETS (all private to this file — DRY via shared reusable set)
// ════════════════════════════════════════════════════════════════════════════

// ── Fintech App Bar ──────────────────────────────────────────────────────────

class _FintechAppBar extends StatelessWidget {
  const _FintechAppBar({
    required this.session,
    required this.spoof,
    required this.onLogout,
  });

  final RiderSession?        session;
  final AntiSpoofingState    spoof;
  final VoidCallback         onLogout;

  @override
  Widget build(BuildContext context) {
    final firstName = session?.name.split(' ').first ?? 'Rider';
    // Map session.trustScore → TrustPill color range
    final trust      = session?.trustScore ?? 0.0;
    final trustColor = trust >= 8.0
        ? AppTheme.ltSuccess
        : trust >= 5.0
            ? AppTheme.ltWarning
            : AppTheme.ltDanger;
    final trustBg = trust >= 8.0
        ? const Color(0xFF052E16) // dark emerald
        : trust >= 5.0
            ? const Color(0xFF431407)
            : const Color(0xFF450A0A);

    return SliverAppBar(
      pinned:          true,
      expandedHeight:  130,
      backgroundColor: AppTheme.ltHeaderBlack,
      elevation:       0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Greeting column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $firstName 👋',
                    style: AppTheme.ltHeadingSmall.copyWith(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    session?.platform ?? 'EarnSure',
                    style: AppTheme.ltBodySmall.copyWith(
                      color:    Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Trust Score pill — maps session.trustScore
            StatusPill(
              label:     'Trust: ${trust.toStringAsFixed(1)}',
              bgColor:   trustBg,
              textColor: trustColor,
              icon:      Icons.verified_rounded,
              iconSize:  10,
              fontSize:  11,
            ),

            const SizedBox(width: 8),

            // Avatar / logout popup (styled for modern fintech)
            _AvatarMenu(
              name:     session?.name ?? 'R',
              onLogout: onLogout,
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white12),
      ),
    );
  }
}

// ── Avatar / Logout menu (logic PRESERVED, restyled) ─────────────────────────

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({required this.name, required this.onLogout});
  final String       name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color:       AppTheme.ltSurface,
      elevation:   8,
      offset:      const Offset(0, 48),
      shape:       RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected:  (v) { if (v == 'logout') onLogout(); },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AppTheme.ltDanger),
              const SizedBox(width: 12),
              Text('Sign Out',
                  style: AppTheme.ltHeadingSmall.copyWith(color: AppTheme.ltDanger, fontSize: 14)),
            ],
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white.withOpacity(0.15),
          child: Text(
            name[0].toUpperCase(),
            style: AppTheme.ltHeadingSmall.copyWith(
              fontSize: 14,
              color:    Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Active Policy Card ────────────────────────────────────────────────────────

class _ActivePolicyCard extends StatelessWidget {
  const _ActivePolicyCard({required this.insurance, required this.session});
  final InsuranceState insurance;
  final RiderSession?  session;

  @override
  Widget build(BuildContext context) {
    if (insurance.isLoading) return _LightSkeleton(height: 160, radius: 20);

    final isActive = insurance.isPolicyActive;
    final policy   = insurance.policy;
    final daysLeft = policy != null
        ? policy.endDate.difference(DateTime.now()).inDays
        : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width:   double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: isActive
          ? AppTheme.ltSuccessCard(borderRadius: 24)
          : BoxDecoration(
              color:        const Color(0xFF1A2535),
              borderRadius: BorderRadius.circular(24),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Standard Plan' : 'No Active Policy',
                      style: AppTheme.ltHeadingSmall.copyWith(
                        color:    Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      isActive
                          ? '${session?.city ?? policy?.city ?? 'Chennai'} · ${session?.platform ?? 'Zomato'}'
                          : 'Activate a plan to get covered',
                      style: AppTheme.ltBodySmall.copyWith(
                        color:    Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Active pulse dot or status pill
              if (isActive)
                StatusPill(
                  label:     'ACTIVE',
                  bgColor:   Colors.white.withOpacity(0.2),
                  textColor: Colors.white,
                  icon:      Icons.circle,
                  iconSize:  6,
                  fontSize:  10,
                )
              else
                StatusPill(
                  label:     'INACTIVE',
                  bgColor:   Colors.white12,
                  textColor: Colors.white54,
                  fontSize:  10,
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Coverage amount
          Text(
            'Coverage',
            style: AppTheme.ltLabel.copyWith(color: Colors.white60, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            // maps insurance.policy.maxPayoutInr
            policy != null ? '₹${policy.maxPayoutInr.toStringAsFixed(0)}' : '₹—',
            style: AppTheme.ltNumberLarge.copyWith(
              color:    Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 16),

          // Footer row — expiry + premium
          Row(
            children: [
              _PolicyChip(
                icon:  Icons.calendar_today_rounded,
                label: isActive ? 'Expires in $daysLeft days' : 'No expiry',
              ),
              const SizedBox(width: 8),
              _PolicyChip(
                icon:  Icons.payments_rounded,
                // maps insurance.policy.weeklyPremiumInr
                label: policy != null
                    ? '₹${policy.weeklyPremiumInr.toStringAsFixed(0)}/week'
                    : '₹—/week',
              ),
              if (policy?.streakDiscountApplied == true) ...[
                const SizedBox(width: 8),
                _PolicyChip(
                  icon:  Icons.local_fire_department_rounded,
                  label: '${policy!.consecutiveWeeks}wk streak',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicyChip extends StatelessWidget {
  const _PolicyChip({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.ltLabel.copyWith(
              color:    Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.insurance});
  final InsuranceState insurance;

  @override
  Widget build(BuildContext context) {
    if (insurance.isLoading) {
      return Row(
        children: [
          Expanded(child: _LightSkeleton(height: 88, radius: 18)),
          const SizedBox(width: 10),
          Expanded(child: _LightSkeleton(height: 88, radius: 18)),
          const SizedBox(width: 10),
          Expanded(child: _LightSkeleton(height: 88, radius: 18)),
        ],
      );
    }

    final policy = insurance.policy;
    return Row(
      children: [
        StatsCard(
          label:      'Premium',
          // maps insurance.policy.weeklyPremiumInr
          value:      policy != null
              ? '₹${policy.weeklyPremiumInr.toStringAsFixed(0)}'
              : '₹—',
          valueColor: AppTheme.ltPrimary,
          icon:       Icons.account_balance_wallet_rounded,
          subtitle:   'per week',
        ),
        const SizedBox(width: 10),
        StatsCard(
          label:      'Protected',
          // maps insurance.policy.maxPayoutInr
          value:      policy != null
              ? '₹${policy.maxPayoutInr.toStringAsFixed(0)}'
              : '₹—',
          valueColor: AppTheme.ltSuccess,
          icon:       Icons.shield_rounded,
          subtitle:   'max payout',
        ),
        const SizedBox(width: 10),
        StatsCard(
          label:  'Claims',
          value:  '0', // TODO: hook up to GET /claims/history API
          icon:   Icons.history_rounded,
          subtitle: 'this month',
        ),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String  title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.ltLabel.copyWith(
            color:       AppTheme.ltTextMuted,
            fontSize:    11,
            letterSpacing: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: AppTheme.ltBodySmall),
        ],
      ],
    );
  }
}

// ── Light Anti-Spoofing Strip (restyled for light bg, logic UNCHANGED) ────────

class _LightAntiSpoofingStrip extends StatelessWidget {
  const _LightAntiSpoofingStrip({required this.spoof});
  // maps antiSpoofingProvider state: trustLevel, stdDevHz, fraudScore
  final AntiSpoofingState spoof;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bgColor;
    final Color borderColor;
    switch (spoof.trustLevel) {
      case 'TRUSTED':
        color       = AppTheme.ltSuccess;
        bgColor     = AppTheme.ltSuccessLight;
        borderColor = AppTheme.ltSuccess.withOpacity(0.3);
        break;
      case 'MEDIUM':
        color       = AppTheme.ltWarning;
        bgColor     = AppTheme.ltWarningLight;
        borderColor = AppTheme.ltWarning.withOpacity(0.3);
        break;
      default:
        color       = AppTheme.ltDanger;
        bgColor     = AppTheme.ltDangerLight;
        borderColor = AppTheme.ltDanger.withOpacity(0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:  color.withOpacity(0.15),
              shape:  BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edge-AI Anti-Spoofing',
                  style: AppTheme.ltHeadingSmall.copyWith(
                    color:    color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  // maps spoof.stdDevHz, spoof.trustLevel
                  'StdDev: ${spoof.stdDevHz.toStringAsFixed(3)} Hz · ${spoof.trustLevel}',
                  style: AppTheme.ltBodySmall,
                ),
              ],
            ),
          ),
          // maps spoof.fraudScore
          StatusPill(
            label:     '${(spoof.fraudScore * 100).toStringAsFixed(0)}% risk',
            bgColor:   color.withOpacity(0.15),
            textColor: color,
            fontSize:  11,
          ),
        ],
      ),
    );
  }
}

// ── Activation Section (logic PRESERVED, restyled) ───────────────────────────

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
            Text(
              'SHIFT STATUS',
              style: AppTheme.ltLabel.copyWith(letterSpacing: 1.2),
            ),
            const Spacer(),
            Icon(Icons.my_location_rounded,
                size: 12, color: AppTheme.ltTextMuted),
            const SizedBox(width: 4),
            Text(
              'Chennai · H3-882a…',
              style: AppTheme.ltBodySmall.copyWith(fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ActivationSlider: LOGIC PRESERVED — only wrapped in a light-bg container
        Container(
          padding:    const EdgeInsets.all(16),
          decoration: AppTheme.ltCard(borderRadius: 18),
          child: ActivationSlider(
            isActive:   insurance.isPolicyActive,
            isLoading:  insurance.isLoading,
            onActivate: onActivate,
          ),
        ),

        if (insurance.error != null) ...[
          const SizedBox(height: 8),
          Text(
            insurance.error!,
            style: AppTheme.ltBodySmall.copyWith(color: AppTheme.ltDanger),
          ),
        ],
      ],
    );
  }
}

// ── Light-mode Loading Skeleton ───────────────────────────────────────────────

class _LightSkeleton extends StatefulWidget {
  const _LightSkeleton({required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  State<_LightSkeleton> createState() => _LightSkeletonState();
}

class _LightSkeletonState extends State<_LightSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
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
            const Color(0xFFE2E8F0),
            const Color(0xFFF1F5F9),
            _ctrl.value,
          ),
        ),
      ),
    );
  }
}