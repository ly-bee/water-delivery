import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tracking_screen.dart';
import 'shell/resident_shell.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;
  final String eta;
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.eta,
  });
  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: -6.0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);

    return Scaffold(
      backgroundColor: p.bgSurface,
      body: Column(
        children: [
          // Hero area — always brand gradient
          SizedBox(
            width: double.infinity,
            height: 300,
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00A8D6), Color(0xFF0077B6)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
                Center(child: _RippleRing(delay: Duration.zero)),
                Center(child: _RippleRing(delay: const Duration(milliseconds: 1300))),
                Center(
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 14),
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.check_rounded,
                              color: Color(0xFF2DC653), size: 50),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 30),
              child: Column(
                children: [
                  Text(
                    'Order confirmed!',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your water is being prepared. We'll notify you when a driver is assigned.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: p.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.bgElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Order reference',
                          value: widget.orderId,
                          valueColor: const Color(0xFF0077B6),
                          mono: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: p.border, height: 1),
                        ),
                        _InfoRow(
                          label: 'Estimated delivery',
                          value: widget.eta,
                          valueColor: p.textPrimary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackingScreen(orderId: widget.orderId),
                      ),
                    ),
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Track my order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const ResidentShell()),
                      (_) => false,
                    ),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: p.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          'Back to home',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: p.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: p.textSecondary)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ],
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
  late final Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
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
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 150, height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: _opacity.value * 0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
