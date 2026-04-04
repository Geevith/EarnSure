import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/status_pill.dart';
import 'widgets/vertical_timeline_stepper.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  LiveClaimPipelineScreen — Expanded VerticalTimelineStepper + fraud check
//
//  Data: MOCK — real data comes from GET /v1/claims/{claim_id}/pipeline
//  TODO: Replace _mockPipeline with ref.watch(claimPipelineProvider(claimId))
//        once the real pipeline WebSocket / polling endpoint is ready.
//        See insurance_provider.dart for the established Riverpod pattern.
// ═══════════════════════════════════════════════════════════════════════════

class LiveClaimPipelineScreen extends StatefulWidget {
  /// Pass the claim title and event type for the green banner.
  // TODO: Replace title/eventType/amount with a real ClaimRecord model from the API
  const LiveClaimPipelineScreen({
    super.key,
    this.claimTitle  = 'Monsoon Flooding',
    this.eventType   = 'monsoon',
    this.amountLabel = '₹450',
    this.dateLabel   = '28 Mar 2026 · 09:14 AM',
  });

  final String claimTitle;
  final String eventType;
  final String amountLabel;
  final String dateLabel;

  @override
  State<LiveClaimPipelineScreen> createState() =>
      _LiveClaimPipelineScreenState();
}

class _LiveClaimPipelineScreenState extends State<LiveClaimPipelineScreen>
    with TickerProviderStateMixin {
  // Animate the pipeline steps in on mount
  late final AnimationController _entryCtrl;
  late final Animation<double>   _entryAnim;

  // Pulse the active step badge
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // TODO: Replace with live data from /v1/claims/{id}/pipeline endpoint.
  //       Each step should reflect server-authoritative status, not local mock.
  List<TimelineStep> get _pipelineSteps => [
        const TimelineStep(
          label:       'Step 1 — Event Detected',
          timestamp:   '09:12 AM',
          icon:        Icons.sensors_rounded,
          isCompleted: true,
        ),
        const TimelineStep(
          label:       'Step 2 — Dual-Key Verified',
          timestamp:   '09:13 AM',
          icon:        Icons.lock_open_rounded,
          isCompleted: true,
        ),
        TimelineStep(
          label:       'Step 3 — Fraud Check',
          timestamp:   '09:13 AM',
          icon:        Icons.security_rounded,
          isCompleted: true,
          // TODO: Replace subItems with actual fraud check results from backend response
          subItems: const [
            'Accelerometer variance — PASS',
            'AC charging pattern — PASS',
            'GPS zone match — PASS',
            'Historical claim rate — WITHIN LIMIT',
          ],
        ),
        const TimelineStep(
          label:     'Step 4 — UPI Payout Queued',
          timestamp: 'Now',
          icon:      Icons.account_balance_rounded,
          isActive:  true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.ltBackground,
        body: FadeTransition(
          opacity: _entryAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Dark SliverAppBar ─────────────────────────────────────
              SliverAppBar(
                pinned:          true,
                backgroundColor: AppTheme.ltHeaderBlack,
                elevation:       0,
                title: Text(
                  'Live Claim Pipeline',
                  style: AppTheme.ltHeadingMedium.copyWith(
                    color: Colors.white, fontSize: 18,
                  ),
                ),
                leading: IconButton(
                  icon:      const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  // Live pulse dot in the app bar
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width:  8, height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.ltSuccess,
                              boxShadow: [
                                BoxShadow(
                                  color:      AppTheme.ltSuccess
                                      .withOpacity(0.6 * _pulseAnim.value),
                                  blurRadius: 8 * _pulseAnim.value,
                                  spreadRadius: 2 * _pulseAnim.value,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: AppTheme.ltLabel.copyWith(
                              color: AppTheme.ltSuccess, fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: Colors.white12),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── [1] Solid Green Alert Banner ─────────────────────
                    _GreenAlertBanner(
                      title:       widget.claimTitle,
                      eventType:   widget.eventType,
                      amountLabel: widget.amountLabel,
                      dateLabel:   widget.dateLabel,
                      pulseAnim:   _pulseAnim,
                    ),
                    const SizedBox(height: 20),

                    // ── [2] Section label ────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'CLAIM PIPELINE',
                          style: AppTheme.ltLabel.copyWith(
                            letterSpacing: 1.2,
                            color: AppTheme.ltTextMuted,
                          ),
                        ),
                        const Spacer(),
                        StatusPill(
                          label:     'In Progress',
                          bgColor:   AppTheme.ltPrimaryLight,
                          textColor: AppTheme.ltPrimary,
                          icon:      Icons.timer_outlined,
                          iconSize:  10,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── [3] Large white pipeline card ────────────────────
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.ltCard(borderRadius: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header
                          Row(
                            children: [
                              Container(
                                width:  40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:        AppTheme.ltPrimaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.account_tree_rounded,
                                  color: AppTheme.ltPrimary,
                                  size:  20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Processing Pipeline',
                                    style: AppTheme.ltHeadingSmall,
                                  ),
                                  Text(
                                    // TODO: Replace with real claim ID from API
                                    'Claim ID: evt-monsoon-2026-001',
                                    style: AppTheme.ltBodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Divider(color: AppTheme.ltBorder, height: 1),
                          const SizedBox(height: 24),

                          // VerticalTimelineStepper — DRY reusable widget
                          // compact: false = expanded mode for full detail
                          VerticalTimelineStepper(
                            steps:   _pipelineSteps,
                            compact: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── [4] Explainer card ───────────────────────────────
                    _PipelineExplainerCard(),
                    const SizedBox(height: 24),

                    // ── [5] Full-width blue CTA button ───────────────────
                    SizedBox(
                      width:  double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        // TODO: Hook up to POST /v1/payouts/initiate
                        //       Pass claim ID and rider UPI handle from auth state
                        onPressed: () => _showPayoutConfirmation(context),
                        icon:  const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Claim Active — Track Payout',
                          style: AppTheme.ltHeadingSmall.copyWith(
                            color:    Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.ltPrimary,
                          foregroundColor: Colors.white,
                          elevation:       0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PayoutTrackSheet(
        amountLabel: widget.amountLabel,
        claimTitle:  widget.claimTitle,
      ),
    );
  }
}

// ─── Green Alert Banner ───────────────────────────────────────────────────────

class _GreenAlertBanner extends StatelessWidget {
  const _GreenAlertBanner({
    required this.title,
    required this.eventType,
    required this.amountLabel,
    required this.dateLabel,
    required this.pulseAnim,
  });
  final String            title;
  final String            eventType;
  final String            amountLabel;
  final String            dateLabel;
  final Animation<double> pulseAnim;

  IconData get _icon => switch (eventType) {
        'monsoon'          => Icons.flood_rounded,
        'heatwave'         => Icons.wb_sunny_rounded,
        'traffic_gridlock' => Icons.traffic_rounded,
        'platform_outage'  => Icons.cloud_off_rounded,
        'heavy_rain'       => Icons.water_drop_rounded,
        _                  => Icons.bolt_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      // No top padding — flush against the app bar
      margin:  const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF047857)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + badge + pulse
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // StatusPill — DRY reusable widget
                    StatusPill(
                      label:     '⚡  DISRUPTION DETECTED',
                      bgColor:   Colors.white.withOpacity(0.2),
                      textColor: Colors.white,
                      fontSize:  10,
                      fontWeight: FontWeight.w800,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: AppTheme.ltHeadingMedium.copyWith(
                        color: Colors.white, fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Animated payout amount
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: pulseAnim.value,
                  child: Text(
                    amountLabel,
                    style: AppTheme.ltNumberLarge.copyWith(
                      color:      Colors.white,
                      fontSize:   28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Bottom row: time + zone + trigger method
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BannerChip(icon: Icons.access_time_rounded, label: dateLabel),
                const SizedBox(width: 8),
                // TODO: Replace with real H3 zone from GPS/InsuranceState
                const _BannerChip(icon: Icons.grid_view_rounded,  label: 'Zone: 882a1072b3f…'),
                const SizedBox(width: 8),
                const _BannerChip(icon: Icons.bolt_rounded,       label: 'Dual-Key Trigger'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.icon, required this.label});
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
            style: AppTheme.ltLabel.copyWith(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Pipeline Explainer Card ──────────────────────────────────────────────────

class _PipelineExplainerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: AppTheme.ltCard(borderRadius: 18),
      child: Row(
        children: [
          Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        AppTheme.ltSuccessLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppTheme.ltSuccess, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payout of ₹450 is queued. Funds will reach your registered '
              'UPI handle within 30 minutes once the pipeline completes.',
              style: AppTheme.ltBodySmall.copyWith(
                color:  AppTheme.ltTextSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payout Tracking Bottom Sheet ────────────────────────────────────────────

class _PayoutTrackSheet extends StatelessWidget {
  const _PayoutTrackSheet({
    required this.amountLabel,
    required this.claimTitle,
  });
  final String amountLabel;
  final String claimTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 12, 24, 24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color:        Color(0xFF0F1620),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width:  40, height: 4,
            decoration: BoxDecoration(
              color:        Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width:  60, height: 60,
            decoration: BoxDecoration(
              color:  AppTheme.ltSuccess.withOpacity(0.15),
              shape:  BoxShape.circle,
              border: Border.all(
                color: AppTheme.ltSuccess.withOpacity(0.4), width: 1.5,
              ),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: AppTheme.ltSuccess, size: 28),
          ),
          const SizedBox(height: 16),

          Text(
            'Payout In Progress',
            style: AppTheme.ltHeadingMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'ll send $amountLabel directly to your registered UPI handle.',
            style: AppTheme.ltBody.copyWith(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Key-value row
          _SheetKV(label: 'Claim Event',   value: claimTitle),
          _SheetKV(label: 'Payout Amount', value: amountLabel),
          // TODO: Replace UPI handle with auth session's real UPI ID from profile
          const _SheetKV(label: 'UPI Handle', value: '98765xxxxx@upi (mock)'),
          const _SheetKV(label: 'Est. Time',  value: '≤ 30 minutes'),
          const SizedBox(height: 20),

          SizedBox(
            width:  double.infinity,
            height: 50,
            child: ElevatedButton(
              // TODO: call POST /v1/payouts/initiate with claim_id and rider_id
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ltSuccess,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Got it',
                style: AppTheme.ltHeadingSmall.copyWith(
                  color: Colors.white, fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetKV extends StatelessWidget {
  const _SheetKV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: AppTheme.ltBody.copyWith(color: Colors.white54)),
          const Spacer(),
          Text(value,
              style: AppTheme.ltBody.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
