import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_confirmation_screen.dart';

enum _PayState { initiating, waiting, timedOut, failed }

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
  static const _timeoutSeconds = 90;
  static const _pollInterval = Duration(seconds: 3);

  _PayState _state = _PayState.initiating;
  String? _errorMessage;
  Timer? _pollTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _pollTimer?.cancel();
    setState(() {
      _state = _PayState.initiating;
      _errorMessage = null;
      _elapsedSeconds = 0;
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

    setState(() => _state = _PayState.waiting);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    final res = await ApiService.checkPaymentStatus(orderId: widget.orderId);
    if (!mounted) return;

    // mpesa_receipt (not status) is the reliable "payment succeeded" signal — if a driver was
    // already auto-assigned before payment, the order stays ASSIGNED rather than becoming PAID.
    final receipt = res['data']?['mpesa_receipt'];
    if (receipt != null) {
      _pollTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: widget.orderId,
            eta: widget.eta,
          ),
        ),
      );
      return;
    }

    final next = _elapsedSeconds + _pollInterval.inSeconds;
    if (next >= _timeoutSeconds) {
      _pollTimer?.cancel();
      setState(() => _state = _PayState.timedOut);
    } else {
      setState(() => _elapsedSeconds = next);
    }
  }

  void _cancel() {
    _pollTimer?.cancel();
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_state == _PayState.initiating) ..._buildInitiating(p),
                  if (_state == _PayState.waiting) ..._buildWaiting(p),
                  if (_state == _PayState.timedOut) ..._buildTimedOut(p),
                  if (_state == _PayState.failed) ..._buildFailed(p),
                ],
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

  List<Widget> _buildWaiting(AqPalette p) => [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F8EE),
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
          'Enter your M-Pesa PIN on ${widget.phone} to pay KSh ${widget.amount} '
          'and complete your order.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(color: p.primary, strokeWidth: 2),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: _cancel,
          child: Text('Cancel',
              style: TextStyle(fontSize: 14, color: p.textSecondary)),
        ),
      ];

  List<Widget> _buildTimedOut(AqPalette p) => [
        Container(
          width: 84, height: 84,
          decoration: const BoxDecoration(
            color: Color(0xFFFEF3E7),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.schedule_rounded,
                color: Color(0xFFC9742B), size: 40),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Still waiting for confirmation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "This is taking longer than usual. You can keep waiting, or check "
          "back later — your order is saved and won't be lost.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: p.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _state = _PayState.waiting);
              _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0077B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Keep waiting',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _cancel,
          child: Text('Cancel and go back',
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
