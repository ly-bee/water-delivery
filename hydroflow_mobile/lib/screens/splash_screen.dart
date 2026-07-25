import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'onboarding_screen.dart';
import 'launcher_screen.dart';
import 'shell/resident_shell.dart';
import 'shell/driver_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    _float = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: -7.0));

    Future.delayed(const Duration(milliseconds: 2400), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    if (ApiService.isLoggedIn) {
      final user = ApiService.getUser();
      final role = user?['role'] ?? 'resident';
      _go(role == 'driver' ? const DriverShell() : const ResidentShell());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('hf_onboarded') ?? false;
    if (!mounted) return;
    _go(seen ? const LauncherScreen() : const OnboardingScreen());
  }

  void _go(Widget w) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _navigate,
        child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF0086C7), Color(0xFF0077B6), Color(0xFF024E78)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Ripple rings
            Center(
              child: SizedBox(
                width: 130, height: 130,
                child: Stack(
                  children: [
                    _RippleRing(delay: Duration.zero),
                    _RippleRing(delay: const Duration(milliseconds: 1400)),
                    // Floating icon
                    Center(
                      child: AnimatedBuilder(
                        animation: _float,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _float.value),
                          child: Container(
                            width: 74, height: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withValues(alpha: 0.16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(38, 38),
                                painter: _WaterDropPainter(fill: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Text
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 150),
                  const Text(
                    'HydroFlow',
                    style: TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Clean water, delivered.',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFFCAF0F8).withValues(alpha: 0.92),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom label
            Positioned(
              bottom: 54, left: 0, right: 0,
              child: Center(
                child: Text(
                  'TAP TO CONTINUE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11, letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _RippleRing extends StatefulWidget {
  final Duration delay;
  const _RippleRing({required this.delay});
  @override
  State<_RippleRing> createState() => _RippleRingState();
}

class _RippleRingState extends State<_RippleRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOut)
        .drive(Tween(begin: 0.4, end: 2.4));
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut)
        .drive(Tween(begin: 0.55, end: 0.0));

    Future.delayed(widget.delay, () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Center(
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFCAF0F8)
                    .withValues(alpha: _opacity.value),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterDropPainter extends CustomPainter {
  final Color fill;
  const _WaterDropPainter({required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..cubicTo(
        size.width * 0.2, size.height * 0.35,
        0, size.height * 0.55,
        size.width / 2, size.height,
      )
      ..cubicTo(
        size.width, size.height * 0.55,
        size.width * 0.8, size.height * 0.35,
        size.width / 2, 0,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
