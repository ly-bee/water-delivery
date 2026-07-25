import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'otp_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});
  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final res = await ApiService.sendOtp(phone: phone);
    setState(() => _loading = false);

    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone, role: 'driver'),
        ),
      );
    } else {
      setState(() => _error = res['message'] ?? 'Failed to send OTP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aq = Aq.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                decoration: BoxDecoration(
                  gradient: Aq.gradSuccess,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Start Earning',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Deliver water and earn money',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PHONE NUMBER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: aq.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _phoneFocus,
                      builder: (_, __) {
                        final active = _phoneFocus.hasFocus;
                        return Container(
                          decoration: BoxDecoration(
                            color: aq.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? HfColors.green : aq.border,
                              width: active ? 1.5 : 1,
                            ),
                            boxShadow: active
                                ? [BoxShadow(color: HfColors.green.withOpacity(0.12), blurRadius: 12)]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '+254',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: aq.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocus,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(color: aq.textPrimary, fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: '712 345 678',
                                    hintStyle: TextStyle(color: aq.textMuted, fontSize: 15),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: aq.accentNegative.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: aq.accentNegative.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: aq.accentNegative, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(color: aq.accentNegative, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    GestureDetector(
                      onTap: _loading ? null : _sendOtp,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: _loading ? null : Aq.gradSuccess,
                          color: _loading ? aq.border : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _loading
                              ? null
                              : [BoxShadow(color: HfColors.green.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Send OTP',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
