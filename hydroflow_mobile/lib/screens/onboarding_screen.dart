import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'launcher_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  static const _slides = [
    _Slide(
      title: 'Order with ease',
      body: 'Fresh 20L jerricans delivered to your door in a few taps — refill or brand new.',
      illustrationType: 0,
    ),
    _Slide(
      title: 'Track your delivery live',
      body: 'Watch your driver approach in real time and know exactly when water arrives.',
      illustrationType: 1,
    ),
    _Slide(
      title: 'Pay your way',
      body: 'M-Pesa, card, or cash on delivery. Whatever works best for you.',
      illustrationType: 2,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hf_onboarded', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LauncherScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _next() {
    if (_page >= _slides.length - 1) {
      _finish();
    } else {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 62, 26, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6b7785),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration box
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _IllustrationBox(
                        key: ValueKey(_page),
                        type: slide.illustrationType,
                      ),
                    ),
                    const SizedBox(height: 38),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(_page),
                        children: [
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              color: Color(0xFF6b7785),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF0077B6)
                          : const Color(0xFFd4dde4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
              // CTA button
              GestureDetector(
                onTap: _next,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B6),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0077B6).withValues(alpha: 0.7),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _page >= _slides.length - 1 ? 'Get started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 19),
                    ],
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

class _Slide {
  final String title;
  final String body;
  final int illustrationType;
  const _Slide({
    required this.title,
    required this.body,
    required this.illustrationType,
  });
}

class _IllustrationBox extends StatefulWidget {
  final int type;
  const _IllustrationBox({super.key, required this.type});
  @override
  State<_IllustrationBox> createState() => _IllustrationBoxState();
}

class _IllustrationBoxState extends State<_IllustrationBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: -7.0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230, height: 230,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F6FC), Color(0xFFD2EEF8)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.hardEdge,
      child: widget.type == 0
          ? _JerricanIllustration(float: _float)
          : widget.type == 1
              ? _MapIllustration()
              : _PaymentIllustration(float: _float),
    );
  }
}

class _JerricanIllustration extends StatelessWidget {
  final Animation<double> float;
  const _JerricanIllustration({required this.float});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Water surface at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(height: 54, color: const Color(0xFFbfe6f2)),
        ),
        // Background building
        Positioned(
          bottom: 54, left: 36,
          child: Container(
            width: 58, height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -8,
                ),
              ],
            ),
          ),
        ),
        // Floating jerrican
        Center(
          child: AnimatedBuilder(
            animation: float,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, float.value),
              child: Container(
                width: 84, height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0077B6).withValues(alpha: 0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                      spreadRadius: -12,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Neck
                    Positioned(
                      top: -12,
                      left: 0, right: 0,
                      child: Center(
                        child: Container(
                          width: 26, height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0353A0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    // Handle
                    Positioned(
                      top: 20, right: -8,
                      child: Container(
                        width: 16, height: 30,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0353A0), width: 5,
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    // Highlight
                    Positioned(
                      top: 16, left: 14, right: 14, bottom: 14,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // Label
                    const Positioned(
                      bottom: 14, left: 12,
                      child: Text(
                        '20L',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapIllustration extends StatelessWidget {
  const _MapIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Map grid
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFeaf4ee),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),
        // Road decorations (static)
        Positioned(
          top: 48, left: -10,
          child: Transform.rotate(
            angle: 0.31,
            child: Container(
              width: 160, height: 14,
              color: const Color(0xFFcfe3d8),
            ),
          ),
        ),
        Positioned(
          bottom: 58, right: -10,
          child: Transform.rotate(
            angle: -0.21,
            child: Container(
              width: 150, height: 11,
              color: const Color(0xFFd7e9ff),
            ),
          ),
        ),
        // Start pin
        Positioned(
          bottom: 40, left: 32,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE63946),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
                bottomRight: Radius.circular(50),
                bottomLeft: Radius.circular(2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: -4,
                ),
              ],
            ),
          ),
        ),
        // Motorbike
        Center(
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0077B6),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0077B6).withValues(alpha: 0.7),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.two_wheeler_rounded,
                  color: Colors.white, size: 19),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFdfeee6)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PaymentIllustration extends StatelessWidget {
  final Animation<double> float;
  const _PaymentIllustration({required this.float});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Card
          AnimatedBuilder(
            animation: float,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, float.value),
              child: Container(
                width: 128, height: 78,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0077B6), Color(0xFF0353A0)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0077B6).withValues(alpha: 0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                      spreadRadius: -12,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 18, left: 0, right: 0,
                      child: Container(height: 13, color: const Color(0xFF012E55)),
                    ),
                    Positioned(
                      bottom: 14, left: 14,
                      child: Container(
                        width: 34, height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // M-Pesa badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: const Text(
              'M-PESA',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2DC653),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
