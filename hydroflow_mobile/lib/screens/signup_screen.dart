import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  final _nameFocus  = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool _showPass  = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _nameFocus.dispose(); _phoneFocus.dispose();
    _emailFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    final result = await ApiService.register(
      name: name, phone: phone, email: email, password: pass, role: 'resident',
    );
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result['success'] == true) {
      final aq = Aq.of(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: aq.bgElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Aq.driverAvailable.withOpacity(0.15),
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: Aq.driverAvailable, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Check your email',
              style: TextStyle(color: aq.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ]),
          content: Text(
            'We sent a verification link to $email.\nPlease verify before logging in.',
            style: TextStyle(color: aq.textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)..pop()..pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: aq.accentPositive,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Go to Login',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      setState(() => _error = result['message'] ?? 'Signup failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildForm(context),
          ],
        ),
      ),
    );
  }

  // Header is always dark (like login hero)
  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1E38), Color(0xFF14131A)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.water_drop_rounded, color: Aq.driverAvailable, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'HydroFlow',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Create an account to start ordering water',
                style: TextStyle(fontSize: 13, color: Color(0xFF8B8990)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final aq = Aq.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(aq, ctrl: _nameCtrl,  focus: _nameFocus,  label: 'Full Name',      hint: 'John Doe',        icon: Icons.person_rounded),
          const SizedBox(height: 18),
          _field(aq, ctrl: _phoneCtrl, focus: _phoneFocus, label: 'Phone Number',   hint: '0712 345 678',   icon: Icons.phone_rounded,   type: TextInputType.phone),
          const SizedBox(height: 18),
          _field(aq, ctrl: _emailCtrl, focus: _emailFocus, label: 'Email Address',  hint: 'john@example.com', icon: Icons.email_rounded,  type: TextInputType.emailAddress),
          const SizedBox(height: 18),
          _passField(aq),
          const SizedBox(height: 28),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: aq.accentNegative.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: aq.accentNegative.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: aq.accentNegative, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: TextStyle(color: aq.accentNegative, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          _gradientBtn(aq),
          const SizedBox(height: 22),

          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: aq.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(color: aq.accentPositive, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    AqPalette aq, {
    required TextEditingController ctrl,
    required FocusNode focus,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: aq.textSecondary, letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: focus,
          builder: (_, __) {
            final active = focus.hasFocus;
            return Container(
              decoration: BoxDecoration(
                color: aq.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? aq.accentPositive : aq.border,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [BoxShadow(color: aq.accentPositive.withOpacity(0.12), blurRadius: 12)]
                    : null,
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                keyboardType: type,
                style: TextStyle(color: aq.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: aq.textMuted, fontSize: 15),
                  prefixIcon: Icon(
                    icon,
                    color: active ? aq.accentPositive : aq.textMuted,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _passField(AqPalette aq) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: aq.textSecondary, letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _passFocus,
          builder: (_, __) {
            final active = _passFocus.hasFocus;
            return Container(
              decoration: BoxDecoration(
                color: aq.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? aq.accentPositive : aq.border,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: active
                    ? [BoxShadow(color: aq.accentPositive.withOpacity(0.12), blurRadius: 12)]
                    : null,
              ),
              child: TextField(
                controller: _passCtrl,
                focusNode: _passFocus,
                obscureText: !_showPass,
                style: TextStyle(color: aq.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Min 6 characters',
                  hintStyle: TextStyle(color: aq.textMuted, fontSize: 15),
                  prefixIcon: Icon(
                    Icons.lock_rounded,
                    color: active ? aq.accentPositive : aq.textMuted,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: aq.textMuted, size: 20,
                    ),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _gradientBtn(AqPalette aq) {
    return GestureDetector(
      onTap: _isLoading ? null : _signUp,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: _isLoading ? null : Aq.gradPrimary,
          color:    _isLoading ? aq.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? null
              : [BoxShadow(color: Aq.driverAvailable.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
        ),
      ),
    );
  }
}
