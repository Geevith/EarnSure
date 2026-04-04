import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/anti_spoofing_provider.dart';
import '../services/edge_sensor_service.dart';

/// Draggable, collapsible terminal-style debug widget.
/// Shows live accelerometer X/Y/Z, stdDev, battery state,
/// and real-time fraud risk level — for judges to interact with.
class SensorDebugView extends ConsumerStatefulWidget {
  const SensorDebugView({super.key});

  @override
  ConsumerState<SensorDebugView> createState() => _SensorDebugViewState();
}

class _SensorDebugViewState extends ConsumerState<SensorDebugView>
    with SingleTickerProviderStateMixin {
  Offset _position  = const Offset(16, 120);
  bool   _collapsed = true;

  late final AnimationController _expandCtrl;
  late final Animation<double>   _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    if (_collapsed) {
      _expandCtrl.reverse();
    } else {
      _expandCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accelAsync   = ref.watch(accelStreamProvider);
    final spoofState   = ref.watch(antiSpoofingProvider);
    final screenWidth  = MediaQuery.of(context).size.width;

    return Positioned(
      left: _position.dx,
      top:  _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _position = Offset(
              (_position.dx + d.delta.dx).clamp(0, screenWidth - 200),
              (_position.dy + d.delta.dy).clamp(0, 700),
            );
          });
        },
        child: _TerminalCard(
          collapsed:   _collapsed,
          expandAnim:  _expandAnim,
          onToggle:    _toggle,
          accelAsync:  accelAsync,
          spoofState:  spoofState,
        ),
      ),
    );
  }
}

// ── Terminal Card ─────────────────────────────────────────────────────────────

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({
    required this.collapsed,
    required this.expandAnim,
    required this.onToggle,
    required this.accelAsync,
    required this.spoofState,
  });

  final bool                        collapsed;
  final Animation<double>           expandAnim;
  final VoidCallback                onToggle;
  final AsyncValue<AccelerometerReading> accelAsync;
  final AntiSpoofingState           spoofState;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (spoofState.trustLevel) {
      'TRUSTED'    => AppTheme.neonEmerald,
      'MEDIUM'     => AppTheme.neonAmber,
      _            => AppTheme.neonRed,
    };

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: const Color(0xE6080C10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: riskColor.withOpacity(0.18), blurRadius: 18, spreadRadius: -2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(riskColor: riskColor, collapsed: collapsed, onToggle: onToggle),
          SizeTransition(
            sizeFactor: expandAnim,
            child: _Body(accelAsync: accelAsync, spoofState: spoofState, riskColor: riskColor),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.riskColor,
    required this.collapsed,
    required this.onToggle,
  });

  final Color    riskColor;
  final bool     collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: riskColor.withOpacity(0.06),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(
          children: [
            // Blinking indicator dot
            _BlinkingDot(color: riskColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'EDGE-AI SENSOR',
                style: AppTheme.monoSmall.copyWith(
                  fontSize: 9,
                  color: riskColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 14,
              color: riskColor.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.color});
  final Color color;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(0.3 + 0.7 * _ctrl.value),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.accelAsync,
    required this.spoofState,
    required this.riskColor,
  });

  final AsyncValue<AccelerometerReading> accelAsync;
  final AntiSpoofingState               spoofState;
  final Color                           riskColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 8),
          // Live accelerometer XYZ
          accelAsync.when(
            data:    (r) => _AccelRows(reading: r),
            loading: () => _monoRow('ACCEL', 'connecting…'),
            error:   (_, __) => _monoRow('ACCEL', 'ERROR'),
          ),
          const SizedBox(height: 6),
          // Computed signals
          _monoRow('STD_DEV', '${spoofState.stdDevHz.toStringAsFixed(3)} Hz'),
          _monoRow('FLAT_SENSOR', spoofState.isFlatSensor ? '⚠ TRUE' : 'false'),
          _monoRow('GYRO_ACTIVE', spoofState.gyroscopeActive ? 'true' : 'false'),
          _monoRow('CHARGING', spoofState.isCharging
              ? '${spoofState.chargingType.toUpperCase()} ${spoofState.batteryLevel}%'
              : 'false'),
          _monoRow('AC_ANOMALY', spoofState.isAcAnomaly ? '⚠ TRUE' : 'false'),
          _monoRow('SAMPLES', spoofState.samplesCollected.toString()),
          const SizedBox(height: 6),
          const Divider(height: 2),
          const SizedBox(height: 6),
          // Trust level badge
          Row(
            children: [
              Text('TRUST: ', style: AppTheme.monoSmall.copyWith(fontSize: 10, color: AppTheme.textMuted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border:       Border.all(color: riskColor.withOpacity(0.4)),
                ),
                child: Text(
                  spoofState.trustLevel,
                  style: AppTheme.monoBold.copyWith(fontSize: 10, color: riskColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'FRAUD_SCORE: ${(spoofState.fraudScore * 100).toStringAsFixed(0)}%',
            style: AppTheme.monoSmall.copyWith(
              fontSize: 10,
              color: riskColor.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$key: ',
              style: AppTheme.monoSmall.copyWith(fontSize: 10, color: AppTheme.textMuted),
            ),
            TextSpan(
              text: value,
              style: AppTheme.monoSmall.copyWith(
                fontSize: 10,
                color: value.contains('⚠') ? AppTheme.neonAmber : AppTheme.neonEmerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccelRows extends StatelessWidget {
  const _AccelRows({required this.reading});
  final AccelerometerReading reading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _accelLine('ACC_X', reading.x),
        _accelLine('ACC_Y', reading.y),
        _accelLine('ACC_Z', reading.z),
        _accelLine('MAG',   reading.magnitude),
      ],
    );
  }

  Widget _accelLine(String label, double val) {
    final isHigh = val.abs() > 2.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTheme.monoSmall.copyWith(fontSize: 10, color: AppTheme.textMuted),
            ),
            TextSpan(
              text: val.toStringAsFixed(3),
              style: AppTheme.monoSmall.copyWith(
                fontSize: 10,
                color: isHigh ? AppTheme.neonAmber : AppTheme.neonEmerald,
                fontWeight: isHigh ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}