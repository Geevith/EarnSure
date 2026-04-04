import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptic_utils.dart';

/// Premium swipe-to-activate slider with pulsing background animation,
/// particle-like glow on completion, and heavy haptic feedback.
class ActivationSlider extends StatefulWidget {
  const ActivationSlider({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.onActivate,
  });

  final bool       isActive;
  final bool       isLoading;
  final VoidCallback onActivate;

  @override
  State<ActivationSlider> createState() => _ActivationSliderState();
}

class _ActivationSliderState extends State<ActivationSlider>
    with TickerProviderStateMixin {
  static const double _trackHeight = 68.0;
  static const double _thumbSize   = 54.0;
  static const double _padding     = 7.0;

  double _dragProgress = 0.0;   // 0.0 → 1.0
  bool   _isDragging   = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;
  late final AnimationController _labelCtrl;

  late final Animation<double> _pulseScale;
  late final Animation<double> _successScale;
  late final Animation<double> _labelOpacity;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _successCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );

    _labelCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _successScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0),  weight: 60),
    ]).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut));

    _labelOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _labelCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  double get _maxDrag {
    // Available drag distance = track width - thumb - both paddings
    final width = context.findRenderObject() != null
        ? (context.findRenderObject() as RenderBox).size.width
        : 320.0;
    return width - _thumbSize - _padding * 2;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.isActive || widget.isLoading) return;
    setState(() {
      _isDragging  = true;
      _dragProgress = (_dragProgress + d.delta.dx / _maxDrag).clamp(0.0, 1.0);
    });
    if (_dragProgress > 0.1) HapticUtils.tick();
  }

  Future<void> _onDragEnd(DragEndDetails _) async {
    if (_dragProgress >= 0.88) {
      await HapticUtils.success();
      await _successCtrl.forward(from: 0);
      widget.onActivate();
    } else {
      await HapticUtils.light();
    }
    setState(() {
      _dragProgress = 0.0;
      _isDragging   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _successCtrl]),
      builder: (_, __) {
        final scaleVal = widget.isActive
            ? _successScale.value
            : _pulseScale.value;

        return Transform.scale(
          scale: scaleVal,
          child: GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd:    _onDragEnd,
            child: _SliderTrack(
              progress:  widget.isActive ? 1.0 : _dragProgress,
              isActive:  widget.isActive,
              isLoading: widget.isLoading,
              isDragging: _isDragging,
              labelOpacity: _labelOpacity,
              pulseValue:  _pulseCtrl.value,
            ),
          ),
        );
      },
    );
  }
}

class _SliderTrack extends StatelessWidget {
  const _SliderTrack({
    required this.progress,
    required this.isActive,
    required this.isLoading,
    required this.isDragging,
    required this.labelOpacity,
    required this.pulseValue,
  });

  final double              progress;
  final bool                isActive;
  final bool                isLoading;
  final bool                isDragging;
  final Animation<double>   labelOpacity;
  final double              pulseValue;

  static const double _trackHeight = 68.0;
  static const double _thumbSize   = 54.0;
  static const double _padding     = 7.0;

  @override
  Widget build(BuildContext context) {
    final trackColor = isActive ? AppTheme.neonEmerald : AppTheme.surfaceElevated;
    final glowOpacity = isActive ? 0.4 : (0.15 + 0.15 * pulseValue);

    return LayoutBuilder(
      builder: (_, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxThumbX  = trackWidth - _thumbSize - _padding;
        final thumbX     = _padding + (maxThumbX - _padding) * progress;

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color:        AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border:       Border.all(
              color: (isActive ? AppTheme.neonEmerald : AppTheme.borderBright)
                  .withOpacity(isActive ? 0.6 : 0.4 + 0.3 * pulseValue),
            ),
            boxShadow: [
              BoxShadow(
                color:       AppTheme.neonEmerald.withOpacity(glowOpacity),
                blurRadius:  isActive ? 32 : 20,
                spreadRadius: isActive ? 0 : -4,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fill bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: thumbX + _thumbSize / 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.neonEmerald.withOpacity(0.12),
                      AppTheme.neonEmerald.withOpacity(0.06),
                    ],
                  ),
                ),
              ),

              // Label
              Center(
                child: FadeTransition(
                  opacity: labelOpacity,
                  child: Text(
                    isLoading
                        ? 'Activating…'
                        : isActive
                            ? '✓  Policy Active'
                            : 'Swipe to Go Online',
                    style: AppTheme.headingSmall.copyWith(
                      color:    isActive ? AppTheme.neonEmerald : AppTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // Thumb
              AnimatedPositioned(
                duration: isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve:    Curves.easeOutCubic,
                left:     thumbX,
                top:      (_trackHeight - _thumbSize) / 2,
                child: _Thumb(isActive: isActive, isLoading: isLoading),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.isActive, required this.isLoading});
  final bool isActive;
  final bool isLoading;

  static const double _thumbSize = 54.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF00E87A), Color(0xFF00A854)],
        ),
        boxShadow: AppTheme.neonGlow(AppTheme.neonEmerald, intensity: 1.0),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color:       AppTheme.backgroundDark,
                ),
              )
            : Icon(
                isActive ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: AppTheme.backgroundDark,
                size:  26,
              ),
      ),
    );
  }
}