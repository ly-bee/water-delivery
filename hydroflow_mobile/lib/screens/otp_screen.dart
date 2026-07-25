import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'shell/resident_shell.dart';
import 'shell/driver_shell.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String role;
  const OtpScreen({super.key, required this.phone, required this.role});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  int _resendTimer = 28;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[0].requestFocus();
    });
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
        _startTimer();
      }
    });
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  void _onKeyChanged(int index, String val) {
    if (val.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _resend() async {
    if (_resending || _resendTimer > 0) return;
    setState(() => _resending = true);
    await ApiService.sendOtp(phone: widget.phone, role: widget.role);
    if (!mounted) return;
    setState(() { _resending = false; _resendTimer = 28; });
    _startTimer();
    for (final c in _ctrls) c.clear();
    _nodes[0].requestFocus();
  }

  Future<void> _verify() async {
    if (_loading) return;
    setState(() => _loading = true);
    final res = await ApiService.verifyOtp(phone: widget.phone, otp: _otp, role: widget.role);
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.role == 'driver'
              ? const DriverShell()
              : const ResidentShell(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Verification failed'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);

    return Scaffold(
      backgroundColor: p.bgSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 74, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: p.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_back_rounded,
                            size: 19, color: p.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify your number',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: p.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Enter the code sent to '),
                        TextSpan(
                          text: '+254 ${widget.phone}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // OTP boxes
                  Row(
                    children: List.generate(6, (i) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 5 ? 9 : 0),
                          child: AnimatedBuilder(
                            animation: _nodes[i],
                            builder: (_, __) {
                              final active = _nodes[i].hasFocus;
                              return Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: active ? p.primary.withValues(alpha: 0.07) : p.bgElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: active ? p.primary : p.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: TextField(
                                    controller: _ctrls[i],
                                    focusNode: _nodes[i],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (v) => _onKeyChanged(i, v),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: _resendTimer == 0 && !_resending ? _resend : null,
                    child: _resending
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: p.primary))
                        : Text(
                            _resendTimer > 0
                                ? 'Resend code in 0:${_resendTimer.toString().padLeft(2, '0')}'
                                : 'Resend code',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: _resendTimer > 0
                                  ? p.textSecondary
                                  : p.primary,
                              fontWeight: _resendTimer == 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
              child: GestureDetector(
                onTap: _otp.length == 6 && !_loading ? _verify : null,
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
                                'Verify & continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.check_rounded,
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
