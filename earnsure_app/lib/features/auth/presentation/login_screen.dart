import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../providers/auth_provider.dart';

// ── Page controller enum ─────────────────────────────────────────────────────
enum _LoginStep { phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  _LoginStep _step          = _LoginStep.phone;
  String     _phone         = '';
  bool       _sendingOtp    = false;

  late final AnimationController _fadeCtrl;
  late final AnimationController _shieldCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _shieldPulse;

  @override
  void initState() {
    super.initState();

    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shieldCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);

    _fadeAnim    = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _shieldPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _shieldCtrl, curve: Curves.easeInOut),
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _shieldCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPhoneSubmitted(String phone) async {
    setState(() { _sendingOtp = true; });
    await HapticUtils.medium();
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      _phone = phone;
      await _fadeCtrl.reverse();
      setState(() { _step = _LoginStep.otp; });
      await _fadeCtrl.forward();
    } finally {
      if (mounted) setState(() { _sendingOtp = false; });
    }
  }

  Future<void> _onOtpSubmitted(String otp) async {
    await HapticUtils.heavy();
    await ref.read(authProvider.notifier).verifyOtp(_phone, otp);
  }

  void _goBack() async {
    await _fadeCtrl.reverse();
    setState(() { _step = _LoginStep.phone; });
    await _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          _BackgroundGrid(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _LogoHeader(pulseAnim: _shieldPulse),
                    const SizedBox(height: 48),

                    if (_step == _LoginStep.phone) ...[
                      _PhoneInputCard(
                        isLoading: _sendingOtp || authState.isLoading,
                        onSubmit:  _onPhoneSubmitted,
                      ),
                    ] else ...[
                      _OtpInputCard(
                        phone:    _phone,
                        isLoading: authState.isLoading,
                        onSubmit:  _onOtpSubmitted,
                        onBack:    _goBack,
                      ),
                    ],

                    if (authState.hasError) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: authState.error.toString()),
                    ],

                    const SizedBox(height: 40),
                    _BottomDisclaimer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background animated grid ─────────────────────────────────────────────────
class _BackgroundGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderSubtle.withOpacity(0.4)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Radial fade overlay
    final gradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.4,
      colors: [
        AppTheme.backgroundDark.withOpacity(0),
        AppTheme.backgroundDark.withOpacity(0.85),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ── Logo header ───────────────────────────────────────────────────────────────
class _LogoHeader extends StatelessWidget {
  const _LogoHeader({required this.pulseAnim});
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) => Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              color:    AppTheme.surfaceDark,
              border:   Border.all(
                color: AppTheme.neonEmerald.withOpacity(pulseAnim.value),
                width: 1.5,
              ),
              boxShadow: AppTheme.neonGlow(
                AppTheme.neonEmerald,
                intensity: pulseAnim.value * 0.8,
              ),
            ),
            child: const Icon(Icons.shield_rounded, color: AppTheme.neonEmerald, size: 26),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EarnSure', style: AppTheme.headingMedium),
            Text('Rider Income Protection', style: AppTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

// ── Phone Input Card ──────────────────────────────────────────────────────────
class _PhoneInputCard extends StatefulWidget {
  const _PhoneInputCard({required this.isLoading, required this.onSubmit});
  final bool isLoading;
  final void Function(String phone) onSubmit;

  @override
  State<_PhoneInputCard> createState() => _PhoneInputCardState();
}

class _PhoneInputCardState extends State<_PhoneInputCard> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _valid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(borderColor: AppTheme.borderBright),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: AppTheme.headingLarge),
            const SizedBox(height: 6),
            Text(
              'Enter your registered phone number to continue.',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller:  _ctrl,
              keyboardType: TextInputType.phone,
              autofocus:   true,
              style:       AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('+91', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                ),
                hintText: '98765 43210',
              ),
              validator: (v) {
                if (v == null || v.length != 10) return 'Enter valid 10-digit number';
                return null;
              },
              onChanged: (v) => setState(() => _valid = v.length == 10),
            ),
            const SizedBox(height: 22),
            _GlowButton(
              label:     'Send OTP',
              isLoading: widget.isLoading,
              enabled:   _valid && !widget.isLoading,
              onTap: () {
                if (_form.currentState!.validate()) {
                  widget.onSubmit('+91${_ctrl.text}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP Input Card ────────────────────────────────────────────────────────────
class _OtpInputCard extends StatefulWidget {
  const _OtpInputCard({
    required this.phone,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
  });

  final String phone;
  final bool isLoading;
  final void Function(String otp) onSubmit;
  final VoidCallback onBack;

  @override
  State<_OtpInputCard> createState() => _OtpInputCardState();
}

class _OtpInputCardState extends State<_OtpInputCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(borderColor: AppTheme.borderBright),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppTheme.neonEmerald),
                const SizedBox(width: 4),
                Text('Back', style: AppTheme.bodySmall.copyWith(color: AppTheme.neonEmerald)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Verify OTP', style: AppTheme.headingLarge),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit code sent to ${widget.phone}',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          TextField(
            controller:  _ctrl,
            autofocus:   true,
            keyboardType: TextInputType.number,
            textAlign:   TextAlign.center,
            style: AppTheme.headingMedium.copyWith(
              letterSpacing: 12,
              color: AppTheme.neonEmerald,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: '· · · · · ·',
              hintStyle: TextStyle(
                color:         AppTheme.textMuted,
                fontSize:      22,
                letterSpacing: 12,
              ),
            ),
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: 22),
          _GlowButton(
            label:     'Verify & Sign In',
            isLoading: widget.isLoading,
            enabled:   _ctrl.text.length == 6 && !widget.isLoading,
            onTap:     () => widget.onSubmit(_ctrl.text),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              '(MVP: any 6 digits work)',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textMuted.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Glow Button ────────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  const _GlowButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled   = true,
  });

  final String   label;
  final VoidCallback onTap;
  final bool     isLoading;
  final bool     enabled;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 0.03,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) { if (widget.enabled) _pressCtrl.forward(); },
      onTapUp:     (_) { _pressCtrl.reverse(); },
      onTapCancel: ()  { _pressCtrl.reverse(); },
      onTap:       widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.enabled
                ? const LinearGradient(
                    colors: [Color(0xFF00E87A), Color(0xFF00C464)],
                  )
                : null,
            color: widget.enabled ? null : AppTheme.surfaceElevated,
            boxShadow: widget.enabled
                ? AppTheme.neonGlow(AppTheme.neonEmerald, intensity: 0.9)
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.backgroundDark,
                    ),
                  )
                : Text(
                    widget.label,
                    style: AppTheme.headingSmall.copyWith(
                      color:       widget.enabled ? AppTheme.backgroundDark : AppTheme.textMuted,
                      fontSize:    15,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        AppTheme.neonRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.neonRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.neonRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.replaceFirst('Exception: ', ''),
              style: AppTheme.bodySmall.copyWith(color: AppTheme.neonRed),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Disclaimer ─────────────────────────────────────────────────────────
class _BottomDisclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Powered by Dual-Key Oracle™ · Edge-AI Anti-Spoofing',
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textMuted.withOpacity(0.55),
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}