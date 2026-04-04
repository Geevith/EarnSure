import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/status_pill.dart';
import 'widgets/stats_card.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ActuarialScreen — Risk & Actuarial Analytics (Underwriter View)
//
//  Data: MOCK — real data comes from GET /v1/actuarial/dashboard
//  TODO: Replace all _mock* variables with ref.watch(actuarialProvider)
//        once the analytics endpoint is wired up.
//        The pattern follows insurance_provider.dart StateNotifier approach.
// ═══════════════════════════════════════════════════════════════════════════

class ActuarialScreen extends StatelessWidget {
  const ActuarialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.ltBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Dark SliverAppBar ──────────────────────────────────────
            SliverAppBar(
              pinned:          true,
              backgroundColor: AppTheme.ltHeaderBlack,
              elevation:       0,
              title: Text(
                'Risk & Actuarial',
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
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: StatusPill(
                    label:     'LIVE DATA',
                    bgColor:   Colors.white12,
                    textColor: Colors.white54,
                    icon:      Icons.analytics_rounded,
                    iconSize:  10,
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: Colors.white12),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── [1] BCR Header Card (critical red metrics) ─────────
                  _BcrHeaderCard(),
                  const SizedBox(height: 16),

                  // ── [2] Loss Ratio stats row ───────────────────────────
                  _LossRatioRow(),
                  const SizedBox(height: 24),

                  // ── [3] Stress Scenario Card ───────────────────────────
                  _StressScenarioCard(),
                  const SizedBox(height: 16),

                  // ── [4] Premium Formula Dark Card ──────────────────────
                  _PremiumFormulaCard(),
                  const SizedBox(height: 16),

                  // ── [5] Risk Distribution Card ─────────────────────────
                  _RiskDistributionCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── [1] BCR Header Card ──────────────────────────────────────────────────────

class _BcrHeaderCard extends StatelessWidget {
  // TODO: Replace all hardcoded values with actuarialProvider state fields:
  //   actuarialState.currentBcr, actuarialState.lossRatio, actuarialState.combinedRatio
  static const double _mockCurrentBcr     = 47.3;
  static const double _mockTargetBcr      = 65.0;
  static const double _mockLossRatio      = 0.73;
  static const double _mockExpensesRatio  = 0.18;

  @override
  Widget build(BuildContext context) {
    final isCritical = _mockCurrentBcr < 50;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.ltCard(
        borderRadius: 24,
        borderColor:  isCritical
            ? AppTheme.ltDanger.withOpacity(0.3)
            : AppTheme.ltBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppTheme.ltDangerLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppTheme.ltDanger, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Break-even Claims Ratio',
                      style: AppTheme.ltHeadingSmall,
                    ),
                    Text(
                      'Target: ${_mockTargetBcr.toStringAsFixed(0)}% — Current Period',
                      style: AppTheme.ltBodySmall,
                    ),
                  ],
                ),
              ),
              // StatusPill — DRY reusable widget
              StatusPill(
                label:     isCritical ? 'CRITICAL' : 'HEALTHY',
                bgColor:   isCritical
                    ? AppTheme.ltDangerLight
                    : AppTheme.ltSuccessLight,
                textColor: isCritical ? AppTheme.ltDanger : AppTheme.ltSuccess,
                icon:      isCritical
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                iconSize:  10,
                fontSize:  10,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Giant BCR number in red
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                // TODO: Tween end value from actuarialProvider.currentBcr
                tween:    Tween(begin: 0, end: _mockCurrentBcr),
                duration: const Duration(milliseconds: 900),
                curve:    Curves.easeOutCubic,
                builder: (_, val, __) => Text(
                  '${val.toStringAsFixed(1)}%',
                  style: AppTheme.ltDisplayNumber.copyWith(
                    color:      AppTheme.ltDanger,
                    fontSize:   48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 8),
                child: Text(
                  'BCR',
                  style: AppTheme.ltLabel.copyWith(
                    color:     AppTheme.ltDanger,
                    fontSize:  14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              // Target vs current gauge
              _BcrGauge(current: _mockCurrentBcr, target: _mockTargetBcr),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Shortfall: ${(_mockTargetBcr - _mockCurrentBcr).toStringAsFixed(1)} pts below target',
            style: AppTheme.ltBodySmall.copyWith(color: AppTheme.ltDanger),
          ),

          const SizedBox(height: 18),
          Divider(color: AppTheme.ltBorder),
          const SizedBox(height: 14),

          // Sub-metrics row
          Row(
            children: [
              _MetricTile(
                label: 'Loss Ratio',
                value: _mockLossRatio.toStringAsFixed(2),
                color: AppTheme.ltDanger,
                isBad: true,
              ),
              _VertDivider(),
              _MetricTile(
                label: 'Expense Ratio',
                value: _mockExpensesRatio.toStringAsFixed(2),
                color: AppTheme.ltWarning,
                isBad: false,
              ),
              _VertDivider(),
              _MetricTile(
                label: 'Combined Ratio',
                value: '${(_mockLossRatio + _mockExpensesRatio).toStringAsFixed(2)}x',
                color: AppTheme.ltDanger,
                isBad: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BcrGauge extends StatelessWidget {
  const _BcrGauge({required this.current, required this.target});
  final double current;
  final double target;

  @override
  Widget build(BuildContext context) {
    final fraction = (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('vs target', style: AppTheme.ltLabel.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Container(
          width:  80,
          height: 8,
          decoration: BoxDecoration(
            color:        AppTheme.ltDangerLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color:        AppTheme.ltDanger,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(fraction * 100).toStringAsFixed(0)}% of target',
          style: AppTheme.ltLabel.copyWith(
            fontSize: 10, color: AppTheme.ltDanger,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.isBad,
  });
  final String label;
  final String value;
  final Color  color;
  final bool   isBad;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.ltNumberMedium.copyWith(
              color:    color,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTheme.ltLabel.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 36,
      color: AppTheme.ltBorder,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

// ─── [2] Loss Ratio Stats Row ─────────────────────────────────────────────────

class _LossRatioRow extends StatelessWidget {
  // TODO: Replace with actuarialProvider.lossRatioHistory list
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // StatsCard — DRY reusable widget
        StatsCard(
          label:      'Current Loss Ratio',
          value:      '0.73',
          valueColor: AppTheme.ltDanger,
          icon:       Icons.trending_up_rounded,
          iconColor:  AppTheme.ltDanger,
          subtitle:   'period average',
        ),
        const SizedBox(width: 10),
        StatsCard(
          label:      'Expected Loss Ratio',
          value:      '0.52',
          valueColor: AppTheme.ltSuccess,
          icon:       Icons.trending_flat_rounded,
          iconColor:  AppTheme.ltSuccess,
          subtitle:   'actuarial model',
        ),
        const SizedBox(width: 10),
        StatsCard(
          label:      'Variance',
          value:      '+0.21',
          valueColor: AppTheme.ltDanger,
          icon:       Icons.compare_arrows_rounded,
          iconColor:  AppTheme.ltDanger,
          subtitle:   'vs estimate',
        ),
      ],
    );
  }
}

// ─── [3] Stress Scenario Card ─────────────────────────────────────────────────

class _StressScenarioCard extends StatelessWidget {
  // TODO: Replace all key-value pairs with actuarialProvider.stressScenarios list
  static const _rows = [
    _KVRow('Scenario',         'Simultaneous Flood Events',      null),
    _KVRow('Affected Zones',   '847 H3 Hexagons',                null),
    _KVRow('Estimated Payout', '₹3,80,250',                      Color(0xFFDC2626)),
    _KVRow('Capital Reserve',  '₹12,00,000',                     null),
    _KVRow('Solvency Ratio',   '3.16x  ✅',                      Color(0xFF059669)),
    _KVRow('Reinsurance Kick', '> ₹5,00,000 (Munich Re layer)',  null),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(22),
      decoration: AppTheme.ltCard(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppTheme.ltWarningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.thunderstorm_rounded,
                  color: AppTheme.ltWarning, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stress Scenario', style: AppTheme.ltHeadingSmall),
                  Text(
                    'Chennai Monsoon — 1-in-50 event',
                    style: AppTheme.ltBodySmall,
                  ),
                ],
              ),
              const Spacer(),
              // StatusPill — DRY reusable widget
              StatusPill(
                label:     'SIMULATED',
                bgColor:   AppTheme.ltWarningLight,
                textColor: AppTheme.ltWarning,
                fontSize:  10,
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: AppTheme.ltBorder),
          const SizedBox(height: 14),

          // Key-value pairs
          ...List.generate(_rows.length, (i) {
            final row    = _rows[i];
            final isLast = i == _rows.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Text(
                        row.label,
                        style: AppTheme.ltBody.copyWith(
                          color: AppTheme.ltTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        row.value,
                        style: AppTheme.ltHeadingSmall.copyWith(
                          fontSize:   14,
                          color:      row.valueColor ?? AppTheme.ltTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) Divider(color: AppTheme.ltBorder, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _KVRow {
  const _KVRow(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color? valueColor;
}

// ─── [4] Premium Formula Dark Card ───────────────────────────────────────────

class _PremiumFormulaCard extends StatelessWidget {
  // TODO: Replace all hardcoded formula variables with actuarialProvider.premiumFormula
  //       fields: baseRate, zoneRiskMultiplier, historicalClaimsFactor, streakDiscount
  static const _variables = [
    _FormulaVar('P',   'Final weekly premium',              '₹98.00 / week'),
    _FormulaVar('R',   'Base rate (platform-calibrated)',   '₹115 / week'),
    _FormulaVar('Z',   'Zone risk multiplier (H3-level)',   '0.82'),
    _FormulaVar('H',   'Historical claims factor',          '1.05'),
    _FormulaVar('S_d', 'Streak discount (5-week loyalty)',  '−15%'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Dark-mode card on the light screen for visual contrast
        color:        AppTheme.ltHeaderDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppTheme.ltPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.functions_rounded,
                  color: AppTheme.ltPrimary.withOpacity(0.9),
                  size:  20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Pricing Formula',
                    style: AppTheme.ltHeadingSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Actuarial model v2.1 — parametric',
                    style: AppTheme.ltBodySmall.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Formula block — blue math text
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color:        Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  'P  =  R  ×  Z  ×  H  ×  (1 − S_d)',
                  style: AppTheme.ltHeadingMedium.copyWith(
                    color:      AppTheme.neonBlue,
                    fontSize:   20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontFamily: 'JetBrains Mono',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Result line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60, height: 1,
                      color: Colors.white12,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '= ₹115 × 0.82 × 1.05 × 0.85',
                        style: AppTheme.ltBodySmall.copyWith(
                          color:    Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Container(
                      width: 60, height: 1,
                      color: Colors.white12,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '≈  ₹98.00 / week',
                  style: AppTheme.ltHeadingMedium.copyWith(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Variable legend — gray bullet points
          Text(
            'VARIABLES',
            style: AppTheme.ltLabel.copyWith(
              color: Colors.white30, letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(_variables.length, (i) {
            final v = _variables[i];
            return _FormulaVarRow(variable: v);
          }),
        ],
      ),
    );
  }
}

class _FormulaVar {
  const _FormulaVar(this.symbol, this.description, this.value);
  final String symbol;
  final String description;
  final String value;
}

class _FormulaVarRow extends StatelessWidget {
  const _FormulaVarRow({required this.variable});
  final _FormulaVar variable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bullet dot
          Container(
            width:  6, height: 6,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(
              color:  Colors.white24,
              shape:  BoxShape.circle,
            ),
          ),
          // Symbol in blue mono
          Text(
            variable.symbol,
            style: AppTheme.ltHeadingSmall.copyWith(
              color:      AppTheme.neonBlue,
              fontSize:   13,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          const SizedBox(width: 8),
          // Gray description
          Expanded(
            child: Text(
              variable.description,
              style: AppTheme.ltBodySmall.copyWith(color: Colors.white38),
            ),
          ),
          // Right-aligned value
          Text(
            variable.value,
            style: AppTheme.ltHeadingSmall.copyWith(
              color:      Colors.white70,
              fontSize:   13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── [5] Risk Distribution Card ──────────────────────────────────────────────

class _RiskDistributionCard extends StatelessWidget {
  // TODO: Replace mock distribution with GET /v1/actuarial/zone-distribution
  static const _zones = [
    _ZoneBar('High Risk (BCR < 50%)',   0.28, AppTheme.ltDanger),
    _ZoneBar('Medium Risk (50–75%)',    0.51, AppTheme.ltWarning),
    _ZoneBar('Low Risk (BCR > 75%)',    0.21, AppTheme.ltSuccess),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(22),
      decoration: AppTheme.ltCard(borderRadius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        AppTheme.ltPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: AppTheme.ltPrimary, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zone Risk Distribution', style: AppTheme.ltHeadingSmall),
                  Text(
                    // TODO: Replace with actual H3 zone count from fleet data
                    '1,200 active zones · Chennai Metro',
                    style: AppTheme.ltBodySmall,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: _zones.map((z) {
                  return Expanded(
                    flex: (z.fraction * 100).round(),
                    child: Container(color: z.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          ..._zones.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width:  10, height: 10,
                      decoration: BoxDecoration(
                        color:  z.color,
                        shape:  BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(z.label, style: AppTheme.ltBody),
                    ),
                    Text(
                      '${(z.fraction * 100).toStringAsFixed(0)}%',
                      style: AppTheme.ltHeadingSmall.copyWith(
                        fontSize:   13,
                        color:      z.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ZoneBar {
  const _ZoneBar(this.label, this.fraction, this.color);
  final String label;
  final double fraction;
  final Color  color;
}
