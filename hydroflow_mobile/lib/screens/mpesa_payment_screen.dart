import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_confirmation_screen.dart';

enum _PayState { initiating, awaitingConfirmation, failed }

class MpesaPaymentScreen extends StatefulWidget {
  final String orderId;
  final String phone;
  final int amount;
  final String eta;
  const MpesaPaymentScreen({
    super.key,
    required this.orderId,
    required this.phone,
    required this.amount,
    required this.eta,
  });
  @override
  State<MpesaPaymentScreen> createState() => _MpesaPaymentScreenState();
}

class _MpesaPaymentScreenState extends State<MpesaPaymentScreen> {
  _PayState _state = _PayState.initiating;
  String? _errorMessage;
  bool _confirming = false;
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _state = _PayState.initiating;
      _errorMessage = null;
    });

    final res = await ApiService.initiatePayment(
      orderId: widget.orderId,
      phone: widget.phone,
    );
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() {
        _state = _PayState.failed;
        _errorMessage = res['message'] ?? 'Could not start the M-Pesa payment.';
      });
      return;
    }

    setState(() => _state = _PayState.awaitingConfirmation);
  }

  // Resident taps this after they've entered their PIN on their phone — we don't wait on
  // Safaricom's callback (it needs a public URL that isn't reliably available), the resident
  // self-reports instead.
  Future<void> _confirmPaid() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    final res = await ApiService.confirmPaymentManually(
      orderId: widget.orderId,
      mpesaCode: _codeCtrl.text,
    );
    if (!mounted) return;
    setState(() => _confirming = false);

    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: widget.orderId,
            eta: widget.eta,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Could not confirm payment'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: p.bgSurface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_state == _PayState.initiating) ..._buildInitiating(p),
                    if (_state == _PayState.awaitingConfirmation)
                      ..._buildAwaitingConfirmation(p),
                    if (_state == _PayState.failed) ..._buildFailed(p),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInitiating(AqPalette p) => [
        CircularProgressIndicator(color: p.primary, strokeWidth: 2.5),
        const SizedBox(height: 20),
        Text(
          'Sending payment request…',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
      ];

  List<Widget> _buildAwaitingConfirmation(AqPalette p) => [
        Container(
          width: 84, height: 84,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F8EE),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.phone_android_rounded,
                color: Color(0xFF1E9E47), size: 40),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Check your phone',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your M-Pesa PIN on ${widget.phone} to pay KSh ${widget.amount}, '
          'then come back and tap "I\'ve paid" below.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: p.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border, width: 1.5),
          ),
          child: TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'M-Pesa code (optional) e.g. TGH4XXXXXX',
              hintStyle: TextStyle(color: p.textMuted, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "From the M-Pesa SMS you received — helps us match your payment.",
              style: TextStyle(fontSize: 11.5, color: p.textMuted),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirming ? null : _confirmPaid,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E9E47),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _confirming
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text("I've paid",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _confirming ? null : _cancel,
          child: Text('Cancel',
              style: TextStyle(fontSize: 14, color: p.textSecondary)),
        ),
      ];

  List<Widget> _buildFailed(AqPalette p) => [
        Container(
          width: 84, height: 84,
          decoration: const BoxDecoration(
            color: Color(0xFFfbeaec),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE63946), size: 40),
        ),
        const SizedBox(height: 22),
        Text(
          "Couldn't start payment",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0077B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try again',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _cancel,
          child: Text('Cancel',
              style: TextStyle(fontSize: 14, color: p.textSecondary)),
        ),
      ];
}
