import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, this.role = 'resident'});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '712 345 678');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(' ', '');
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.sendOtp(phone: phone, role: widget.role);
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone, role: widget.role),
        ),
      );
    } else {
      setState(() => _error = res['message'] ?? 'Failed to send OTP');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 74, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo mark
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00A8D6), Color(0xFF0077B6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0077B6).withValues(alpha: 0.7),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                          spreadRadius: -14,
                        ),
                      ],
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(27, 27),
                        painter: _WaterDropPainter(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Enter your number',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We'll send a 6-digit code to verify it's you.",
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFF6b7785),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Phone number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6b7785),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 9),
                  // Phone input
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFFfafbfc),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFe3e8ee), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Text('🇰🇪', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 7),
                              const Text(
                                '+254',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1.5, height: 34, color: const Color(0xFFe3e8ee)),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Color(0xFF1A1A2E),
                            ),
                            decoration: const InputDecoration(
                              hintText: '712 345 678',
                              hintStyle: TextStyle(
                                fontSize: 17,
                                color: Color(0xFF9aa6b2),
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 15, color: Color(0xFF9aa6b2)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Your number stays private. By continuing you agree to our Terms & Privacy Policy.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9aa6b2),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfbeaec),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFf2dadd)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFE63946), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Color(0xFFE63946), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
              child: GestureDetector(
                onTap: _loading ? null : _sendOtp,
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
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Send code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 19),
                            ],
                          ),
                  ),
                ),
              ),
            ),
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
  }

  @override
  bool shouldRepaint(_) => false;
}
