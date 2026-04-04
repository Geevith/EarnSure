import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/insurance/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation — designed for gig workers on the go
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar with light icons for the dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: EarnSureApp(),
    ),
  );
}

class EarnSureApp extends ConsumerWidget {
  const EarnSureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'EarnSure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.when(
        data: (rider) => rider != null
            ? const DashboardScreen()
            : const LoginScreen(),
        loading: () => const _SplashScreen(),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedLogo(),
            const SizedBox(height: 24),
            Text(
              'EARNSURE',
              style: AppTheme.headingLarge.copyWith(
                letterSpacing: 8,
                color: AppTheme.neonEmerald,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Income. Protected.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textMuted,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceDark,
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonEmerald.withOpacity(_pulse.value * 0.5),
              blurRadius: 24 * _pulse.value,
              spreadRadius: 4 * _pulse.value,
            ),
          ],
          border: Border.all(
            color: AppTheme.neonEmerald.withOpacity(_pulse.value),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.shield_rounded,
          color: AppTheme.neonEmerald,
          size: 36,
        ),
      ),
    );
  }
}