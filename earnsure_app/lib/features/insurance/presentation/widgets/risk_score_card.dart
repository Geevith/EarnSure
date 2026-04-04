import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class RiskScoreCard extends StatefulWidget {
  const RiskScoreCard({
    super.key,
    required this.riskScore,
    required this.disruptionProbability,
    required this.zoneRisk,
    required this.city,
  });

  final double riskScore;
  final double disruptionProbability;
  final double zoneRisk;
  final String city;

  @override
  State<RiskScoreCard> createState() => _RiskScoreCardState();
}

class _RiskScoreCardState extends State<RiskScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scoreAnim;
  late final Animation<double>   _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:     this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _scoreAnim = Tween<double>(begin: 0, end: widget.riskScore / 10.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic)),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _riskColor {
    if (widget.riskScore >= 8.0) return AppTheme.neonRed;
    if (widget.riskScore >= 6.0) return AppTheme.neonAmber;
    return AppTheme.neonEmerald;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final color = _riskColor;
        return Container(
          decoration: BoxDecoration(
            color:        AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border:       Border.all(color: color.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color:       color.withOpacity(0.18 * _glowAnim.value),
                blurRadius:  40,
                spreadRadius: -4,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeader(city: widget.city, color: color),
              const SizedBox(height: 24),
              _ArcGauge(
                progress: _scoreAnim.value,
                score:    widget.riskScore * _scoreAnim.value / (widget.riskScore / 10.0),
                color:    color,
              ),
              const SizedBox(height: 24),
              _MetricRow(
                metrics: [
                  _Metric(
                    label: 'Disruption Prob.',
                    value: '${(widget.disruptionProbability * 100).toStringAsFixed(0)}%',
                    color: color,
                  ),
                  _Metric(
                    label: 'Zone Risk',
                    value: '${(widget.zoneRisk * 100).toStringAsFixed(0)}%',
                    color: color,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.city, required this.color});
  final String city;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_rounded, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                'AI RISK PROFILE',
                style: AppTheme.labelMedium.copyWith(color: color, fontSize: 10),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppTheme.textMuted, size: 13),
            const SizedBox(width: 3),
            Text(city, style: AppTheme.bodySmall.copyWith(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _ArcGauge extends StatelessWidget {
  const _ArcGauge({
    required this.progress,
    required this.score,
    required this.color,
  });

  final double progress;
  final double score;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width:  160,
        height: 100,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CustomPaint(
              size: const Size(160, 100),
              painter: _ArcPainter(progress: progress, color: color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 1400),
                  curve:    Curves.easeOutCubic,
                  builder: (_, val, __) => Text(
                    val.toStringAsFixed(1),
                    style: AppTheme.headingLarge.copyWith(
                      fontSize: 40,
                      color:    color,
                      height:   1,
                      shadows: [
                        Shadow(color: color.withOpacity(0.5), blurRadius: 20),
                      ],
                    ),
                  ),
                ),
                Text(
                  'out of 10',
                  style: AppTheme.labelMedium.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height;
    final radius = size.width / 2 - 8;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track
    canvas.drawArc(
      rect,
      math.pi, math.pi,
      false,
      Paint()
        ..color       = AppTheme.borderBright
        ..strokeWidth = 8
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    // Progress
    final sweepAngle = math.pi * progress;
    
    // 🛠️ THE FIX: Only draw the gradient if the angle is greater than 0!
    if (sweepAngle > 0.001) {
      canvas.drawArc(
        rect,
        math.pi, sweepAngle,
        false,
        Paint()
          ..shader = SweepGradient(
              startAngle: math.pi,
              endAngle:   math.pi + sweepAngle,
              colors:     [color.withOpacity(0.4), color],
            ).createShader(rect)
          ..strokeWidth = 8
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );
    }

    // Glow on tip
    if (progress > 0.05) {
      final tipAngle = math.pi + sweepAngle;
      final tipX     = cx + radius * math.cos(tipAngle);
      final tipY     = cy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY), 5,
        Paint()
          ..color     = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(Offset(tipX, tipY), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: metrics
          .map(
            (m) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(
                  color:        m.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: m.color.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Text(
                      m.value,
                      style: AppTheme.headingSmall.copyWith(color: m.color, fontSize: 18),
                    ),
                    const SizedBox(height: 3),
                    Text(m.label, style: AppTheme.bodySmall.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color  color;
}