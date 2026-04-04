import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

import 'widgets/segmented_toggle.dart';
import 'widgets/status_pill.dart';
import 'widgets/vertical_timeline_stepper.dart';
import 'live_claim_pipeline_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
//  ClaimHistoryScreen — Fintech light-mode design
//
//  Data: MOCK — real data comes from GET /v1/claims/history/{rider_id}
//  TODO: Replace _mockClaims() with a real Riverpod provider once the
//        /claims/history API endpoint is ready. See insurance_provider.dart
//        for the pattern to follow.
// ═══════════════════════════════════════════════════════════════════════════

class ClaimHistoryScreen extends ConsumerStatefulWidget {
  const ClaimHistoryScreen({super.key});

  @override
  ConsumerState<ClaimHistoryScreen> createState() => _ClaimHistoryScreenState();
}

class _ClaimHistoryScreenState extends ConsumerState<ClaimHistoryScreen> {
  int _selectedTab = 0; // 0=All, 1=Approved, 2=Paid

  // ── Mock claim list ────────────────────────────────────────────────────────
  // TODO: Replace with ref.watch(claimHistoryProvider) when API is ready
  List<_ClaimRecord> get _allClaims => _mockClaims();

  List<_ClaimRecord> get _filteredClaims => switch (_selectedTab) {
        1 => _allClaims.where((c) => c.status == _ClaimStatus.approved).toList(),
        2 => _allClaims.where((c) => c.status == _ClaimStatus.paid).toList(),
        _ => _allClaims,
      };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.ltBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Dark header ──────────────────────────────────────────────
            SliverAppBar(
              pinned:          true,
              backgroundColor: AppTheme.ltHeaderBlack,
              elevation:       0,
              title: Text(
                'Claim History',
                style: AppTheme.ltHeadingMedium.copyWith(
                  color:    Colors.white,
                  fontSize: 18,
                ),
              ),
              leading: IconButton(
                icon:    const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  color:   AppTheme.ltHeaderBlack,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      // SegmentedToggle — DRY: reusable widget
                      SegmentedToggle(
                        segments:      ['All', 'Approved', 'Paid'],
                        selectedIndex: _selectedTab,
                        onChanged:     (i) => setState(() => _selectedTab = i),
                        // Adapted colours for the dark header
                        activeColor:      AppTheme.ltPrimary,
                        inactiveColor:    Colors.white12,
                        activeTextColor:  Colors.white,
                        inactiveTextColor: Colors.white60,
                      ),
                      const Spacer(),
                      Text(
                        '${_filteredClaims.length} claim${_filteredClaims.length == 1 ? '' : 's'}',
                        style: AppTheme.ltBodySmall.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Claim cards list ─────────────────────────────────────────
            _filteredClaims.isEmpty
                ? SliverFillRemaining(child: _EmptyState())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _ClaimCard(claim: _filteredClaims[i]),
                        childCount: _filteredClaims.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── Claim Card ──────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});
  final _ClaimRecord claim;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.ltCard(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event icon
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color:        claim.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(claim.icon, color: claim.iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.title,
                      style: AppTheme.ltHeadingSmall.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      claim.dateLabel,
                      style: AppTheme.ltBodySmall,
                    ),
                  ],
                ),
              ),

              // Amount protected — large right-aligned text
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    claim.amountLabel,
                    style: AppTheme.ltNumberMedium.copyWith(
                      color:    claim.amountColor,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // StatusPill — DRY: reusable widget
                  StatusPill(
                    label:     claim.statusLabel,
                    bgColor:   claim.statusBg,
                    textColor: claim.statusColor,
                    fontSize:  10,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: AppTheme.ltBorder, height: 1),
          const SizedBox(height: 16),

          // ── VerticalTimelineStepper — DRY: reusable widget ──────────────
          VerticalTimelineStepper(
            steps:   claim.steps,
            compact: true,
          ),

          const SizedBox(height: 16),

          // ── UPI Payout button + View Pipeline ─────────────────────────
          if (claim.status == _ClaimStatus.pending ||
              claim.status == _ClaimStatus.approved) ...[  // show pipeline button for in-progress claims
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width:  double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveClaimPipelineScreen(
                        claimTitle:  claim.title,
                        amountLabel: claim.amountLabel,
                        dateLabel:   claim.dateLabel,
                        // TODO: Pass real eventType from claim model (from API)
                        eventType: claim.id.contains('monsoon') ? 'monsoon'
                            : claim.id.contains('heat')    ? 'heatwave'
                            : claim.id.contains('gridlock') ? 'traffic_gridlock'
                            : claim.id.contains('rain')    ? 'heavy_rain'
                            : 'platform_outage',
                      ),
                    ),
                  ),
                  icon:  Icon(Icons.account_tree_rounded, size: 15,
                      color: AppTheme.ltPrimary),
                  label: Text(
                    'View Live Pipeline',
                    style: AppTheme.ltHeadingSmall.copyWith(
                      fontSize: 13, color: AppTheme.ltPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:  BorderSide(color: AppTheme.ltPrimary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],  // end of conditional spread

          SizedBox(
            width:  double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              // TODO: wire up to POST /v1/payouts/initiate when UPI API ready
              onPressed: claim.status == _ClaimStatus.approved
                  ? () => _showPayoutDialog(context, claim)
                  : null,
              icon:  const Icon(Icons.account_balance_rounded, size: 16),
              label: Text(
                claim.status == _ClaimStatus.paid
                    ? 'Payout Completed'
                    : 'Process UPI Payout',
                style: AppTheme.ltHeadingSmall.copyWith(
                  fontSize:   14,
                  color:      Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: claim.status == _ClaimStatus.paid
                    ? AppTheme.ltSuccess
                    : claim.status == _ClaimStatus.approved
                        ? AppTheme.ltPrimary
                        : const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                elevation:       0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPayoutDialog(BuildContext context, _ClaimRecord claim) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.ltSurface,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Initiate UPI Payout',
          style: AppTheme.ltHeadingSmall,
        ),
        content: Text(
          // TODO: Replace with real UPI ID from rider profile API
          'Send ${claim.amountLabel} to registered UPI ID?\n\nUPI ID: ***@upi (mock)',
          style: AppTheme.ltBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTheme.ltBody.copyWith(color: AppTheme.ltTextMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payout initiated — TODO: call POST /payouts/initiate'),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  72,
            height: 72,
            decoration: BoxDecoration(
              color:  AppTheme.ltPrimaryLight,
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: AppTheme.ltPrimary, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No claims yet', style: AppTheme.ltHeadingSmall),
          const SizedBox(height: 6),
          Text(
            'Claims will appear here once a trigger event occurs.',
            style: AppTheme.ltBodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MOCK DATA MODELS & FACTORY
//  TODO: Delete this section once GET /v1/claims/history is integrated.
//        Replace with ClaimRecord model parsed from API JSON.
// ═══════════════════════════════════════════════════════════════════════════

enum _ClaimStatus { pending, approved, paid, flagged }

class _ClaimRecord {
  const _ClaimRecord({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.amountLabel,
    required this.amountColor,
    required this.status,
    required this.statusLabel,
    required this.statusBg,
    required this.statusColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.steps,
  });

  final String           id;
  final String           title;
  final String           dateLabel;
  final String           amountLabel;
  final Color            amountColor;
  final _ClaimStatus     status;
  final String           statusLabel;
  final Color            statusBg;
  final Color            statusColor;
  final IconData         icon;
  final Color            iconBg;
  final Color            iconColor;
  final List<TimelineStep> steps;
}

/// Factory that returns mock claim records.
// TODO: Remove and replace with insurance_provider.dart real claimsHistory
List<_ClaimRecord> _mockClaims() => [
      _ClaimRecord(
        id:          'evt-monsoon-2024-001',
        title:       'Monsoon Flooding',
        dateLabel:   '28 Mar 2026 · 09:14 AM',
        amountLabel: '₹450',
        amountColor: AppTheme.ltSuccess,
        status:      _ClaimStatus.approved,
        statusLabel: 'Approved',
        statusBg:    AppTheme.ltWarningLight,
        statusColor: AppTheme.ltWarning,
        icon:        Icons.flood_rounded,
        iconBg:      AppTheme.ltTealLight,
        iconColor:   AppTheme.ltTeal,
        steps: [
          TimelineStep(
            label:       'Event Detected',
            timestamp:   '09:12 AM',
            icon:        Icons.sensors_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Dual-Key Verified',
            timestamp:   '09:13 AM',
            icon:        Icons.lock_open_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Fraud Check',
            timestamp:   '09:13 AM',
            icon:        Icons.security_rounded,
            isCompleted: true,
            subItems: [
              'Accelerometer variance — PASS',
              'AC charging pattern — PASS',
              'GPS zone match — PASS',
            ],
          ),
          TimelineStep(
            label:     'UPI Payout Pending',
            timestamp: 'Now',
            icon:      Icons.account_balance_rounded,
            isActive:  true,
          ),
        ],
      ),

      _ClaimRecord(
        id:          'evt-heat-2024-002',
        title:       'Extreme Heat Wave',
        dateLabel:   '22 Mar 2026 · 02:30 PM',
        amountLabel: '₹320',
        amountColor: AppTheme.ltPrimary,
        status:      _ClaimStatus.paid,
        statusLabel: 'Paid',
        statusBg:    AppTheme.ltSuccessLight,
        statusColor: AppTheme.ltSuccess,
        icon:        Icons.wb_sunny_rounded,
        iconBg:      AppTheme.ltWarningLight,
        iconColor:   AppTheme.ltWarning,
        steps: [
          TimelineStep(
            label:       'Event Detected',
            timestamp:   '02:28 PM',
            icon:        Icons.sensors_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Dual-Key Verified',
            timestamp:   '02:29 PM',
            icon:        Icons.lock_open_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Fraud Check',
            timestamp:   '02:29 PM',
            icon:        Icons.security_rounded,
            isCompleted: true,
            subItems: [
              'Accelerometer variance — PASS',
              'GPS zone match — PASS',
            ],
          ),
          TimelineStep(
            label:       'UPI Payout Sent',
            timestamp:   '02:35 PM',
            icon:        Icons.check_circle_rounded,
            isCompleted: true,
          ),
        ],
      ),

      _ClaimRecord(
        id:          'evt-gridlock-2024-003',
        title:       'Traffic Gridlock',
        dateLabel:   '15 Mar 2026 · 06:00 PM',
        amountLabel: '₹180',
        amountColor: AppTheme.ltDanger,
        status:      _ClaimStatus.flagged,
        statusLabel: 'Soft Flagged',
        statusBg:    AppTheme.ltDangerLight,
        statusColor: AppTheme.ltDanger,
        icon:        Icons.traffic_rounded,
        iconBg:      AppTheme.ltDangerLight,
        iconColor:   AppTheme.ltDanger,
        steps: [
          TimelineStep(
            label:       'Event Detected',
            timestamp:   '05:58 PM',
            icon:        Icons.sensors_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:    'Fraud Check',
            timestamp: '06:01 PM',
            icon:     Icons.security_rounded,
            isFailed: true,
            subItems: [
              'Accelerometer variance — ANOMALY',
              'Complete 1 delivery to unlock payout',
            ],
          ),
          TimelineStep(
            label:     'Under Review',
            timestamp: 'Pending',
            icon:      Icons.hourglass_top_rounded,
            isActive:  false,
          ),
        ],
      ),

      _ClaimRecord(
        id:          'evt-rain-2024-004',
        title:       'Heavy Rain',
        dateLabel:   '05 Mar 2026 · 11:45 AM',
        amountLabel: '₹450',
        amountColor: AppTheme.ltSuccess,
        status:      _ClaimStatus.paid,
        statusLabel: 'Paid',
        statusBg:    AppTheme.ltSuccessLight,
        statusColor: AppTheme.ltSuccess,
        icon:        Icons.water_drop_rounded,
        iconBg:      AppTheme.ltPrimaryLight,
        iconColor:   AppTheme.ltPrimary,
        steps: [
          TimelineStep(
            label:       'Event Detected',
            timestamp:   '11:43 AM',
            icon:        Icons.sensors_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Dual-Key Verified',
            timestamp:   '11:44 AM',
            icon:        Icons.lock_open_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'Fraud Check — Passed',
            timestamp:   '11:44 AM',
            icon:        Icons.security_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:       'UPI Payout Sent',
            timestamp:   '11:50 AM',
            icon:        Icons.check_circle_rounded,
            isCompleted: true,
          ),
        ],
      ),

      _ClaimRecord(
        id:          'evt-outage-2024-005',
        title:       'Platform Outage',
        dateLabel:   '01 Mar 2026 · 03:20 PM',
        amountLabel: '₹225',
        amountColor: AppTheme.ltPurple,
        status:      _ClaimStatus.pending,
        statusLabel: 'Processing',
        statusBg:    AppTheme.ltPurpleLight,
        statusColor: AppTheme.ltPurple,
        icon:        Icons.cloud_off_rounded,
        iconBg:      AppTheme.ltPurpleLight,
        iconColor:   AppTheme.ltPurple,
        steps: [
          TimelineStep(
            label:       'Event Detected',
            timestamp:   '03:18 PM',
            icon:        Icons.sensors_rounded,
            isCompleted: true,
          ),
          TimelineStep(
            label:     'Awaiting Dual-Key',
            timestamp: 'Pending',
            icon:      Icons.lock_rounded,
            isActive:  true,
          ),
        ],
      ),
    ];
