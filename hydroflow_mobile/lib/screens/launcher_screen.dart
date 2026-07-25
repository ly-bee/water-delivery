import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});
  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: -7.0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hf_user_role', role);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginScreen(role: role),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Launcher always uses the brand gradient regardless of theme —
    // it's a full-bleed identity screen.
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0, -0.8),
            end: Alignment.bottomCenter,
            colors: [Color(0xFF015E8E), Color(0xFF0077B6), Color(0xFF0353A0)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80, right: -60,
              child: Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF90E0EF).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 120, left: -70,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF023E5A).withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),
                    Center(
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _float,
                            builder: (_, __) => Transform.translate(
                              offset: Offset(0, _float.value),
                              child: Container(
                                width: 62, height: 62,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: CustomPaint(
                                    size: const Size(30, 30),
                                    painter: _WaterDropPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'HydroFlow',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Clean water, delivered.',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFFCAF0F8).withValues(alpha: 0.9),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 46),
                    Text(
                      'CHOOSE AN EXPERIENCE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                        color: const Color(0xFFCAF0F8).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 13),
                    _RoleCard(
                      onTap: () => _selectRole(context, 'resident'),
                      iconWidget: const Icon(Icons.home_rounded,
                          color: Color(0xFF0077B6), size: 23),
                      iconBg: const Color(0xFFE6F6FC),
                      title: 'Resident',
                      subtitle: 'Order water to my door',
                    ),
                    const SizedBox(height: 13),
                    _RoleCard(
                      onTap: () => _selectRole(context, 'driver'),
                      iconWidget: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFF2DC653), size: 23),
                      iconBg: const Color(0xFFE9F8EE),
                      title: 'Driver',
                      subtitle: 'Deliver orders on my route',
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget iconWidget;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _RoleCard({
    required this.onTap,
    required this.iconWidget,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.bgSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 18),
              spreadRadius: -20,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                color: p.textMuted, size: 19),
          ],
        ),
      ),
    );
  }
}

class _WaterDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..cubicTo(size.width * 0.2, size.height * 0.35, 0, size.height * 0.55,
          size.width / 2, size.height)
      ..cubicTo(size.width, size.height * 0.55, size.width * 0.8,
          size.height * 0.35, size.width / 2, 0);
    canvas.drawPath(path, paint);
    final lens = Paint()
      ..color = const Color(0xFF0077B6).withValues(alpha: 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.4, size.height * 0.6),
        width: size.width * 0.35,
        height: size.height * 0.5,
      ),
      lens,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
