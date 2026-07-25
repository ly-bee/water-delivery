import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_confirmation_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  int _step = 1;
  int _volumeLiters = 20; // 10 or 20
  int _qty = 2;
  bool _returnEmpty = true;
  String _timing = 'asap'; // asap | schedule
  String _payment = 'mpesa'; // mpesa | card | cash
  bool _placing = false;
  bool _gettingLocation = false;
  double? _deliveryLat;
  double? _deliveryLng;
  String _mpesaPhone = '';
  late TextEditingController _addressCtrl;
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ApiService.getUser();
    final savedAddress = user?['delivery_address'] as String? ?? '';
    _addressCtrl = TextEditingController(text: savedAddress);
    // Default M-Pesa number from user profile phone
    final phone = user?['phone']?.toString() ?? '';
    _mpesaPhone = phone.isNotEmpty ? phone : '+254 7XX XXX XXX';
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _deliveryLat = pos.latitude;
        _deliveryLng = pos.longitude;
      });
      if (_addressCtrl.text.trim().isEmpty) {
        _addressCtrl.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('GPS location captured for delivery'),
        backgroundColor: Color(0xFF1E9E47),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not get location: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  void _editMpesaPhone() {
    final p = Aq.of(context);
    final ctrl = TextEditingController(text: _mpesaPhone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'M-Pesa number',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The STK push will be sent to this number',
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '+254 7XX XXX XXX',
                  hintStyle: TextStyle(color: p.textMuted),
                  filled: true,
                  fillColor: p.bgElevated,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFF0077B6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  final val = ctrl.text.trim();
                  if (val.isNotEmpty) {
                    setState(() => _mpesaPhone = val);
                  }
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int get _unitPrice => _volumeLiters == 10 ? 50 : 100;
  int get _subtotal => _unitPrice * _qty;
  int get _fee => 60;
  int get _total => _subtotal + _fee;

  String _ksh(int n) => 'KSh ${n.toLocaleString()}';

  Future<void> _placeOrder() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() => _step = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your delivery address'),
          backgroundColor: Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _placing = true);
    final res = await ApiService.createOrder(
      volumeLiters: _volumeLiters,
      amountKsh: _total.toDouble(),
      deliveryFee: _fee.toDouble(),
      deliveryAddress: address,
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
      quantity: _qty,
      returnEmpties: _returnEmpty,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    setState(() => _placing = false);
    if (!mounted) return;
    if (res['success'] == true || res['order'] != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: res['order']?['id']?.toString() ?? 'AQ-2061',
            eta: '10:48 AM (≈ 32 min)',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to place order'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _next() {
    if (_step >= 3) {
      _placeOrder();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step <= 1) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.bgPage,
      body: Column(
        children: [
          // Header
          Container(
            color: p.bgSurface,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        width: 40, height: 40,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Place order',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Step $_step of 3',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Progress bar
                Row(
                  children: List.generate(3, (i) {
                    final active = i + 1 <= _step;
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF0077B6)
                              : p.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
              child: _step == 1
                  ? _buildStep1(p, isDark)
                  : _step == 2
                      ? _buildStep2(p, isDark)
                      : _buildStep3(p, isDark),
            ),
          ),

          // Bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.bgPage.withValues(alpha: 0), p.bgPage],
                stops: const [0.0, 0.32],
              ),
            ),
            child: GestureDetector(
              onTap: _placing ? null : _next,
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
                  child: _placing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _step >= 3
                                  ? 'Confirm order · ${_ksh(_total)}'
                                  : 'Continue',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AqPalette p, bool isDark) {
    return Column(
      children: [
        // Product header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 60, height: 74,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -7, left: 0, right: 0,
                      child: Center(
                        child: Container(
                          width: 20, height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0353A0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 43,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_volumeLiters}L Refillable Jerrican',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Purified drinking water. Sealed & quality-checked.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: p.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Choose size
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Choose size',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _OptionCard(
              selected: _volumeLiters == 10,
              onTap: () => setState(() => _volumeLiters = 10),
              icon: Icons.water_drop_outlined,
              title: '10 L',
              subtitle: 'Small jerrican',
              price: 'KSh 50',
            )),
            const SizedBox(width: 11),
            Expanded(child: _OptionCard(
              selected: _volumeLiters == 20,
              onTap: () => setState(() => _volumeLiters = 20),
              icon: Icons.water_drop_rounded,
              title: '20 L',
              subtitle: 'Standard jerrican',
              price: 'KSh 100',
            )),
          ],
        ),
        const SizedBox(height: 18),

        // Quantity
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _qty = (_qty - 1).clamp(1, 20)),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: p.bgElevated,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: p.border, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(Icons.remove_rounded,
                            size: 18, color: p.textPrimary),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        '$_qty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _qty = (_qty + 1).clamp(1, 20)),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0077B6),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Return empties toggle
        GestureDetector(
          onTap: () => setState(() => _returnEmpty = !_returnEmpty),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF6E9).withValues(alpha: isDark ? 0.18 : 1.0),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Icon(Icons.recycling_rounded,
                        color: Color(0xFFC9742B), size: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collect my empty jerricans',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Driver picks up empties at delivery',
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                _Toggle(value: _returnEmpty),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(AqPalette p, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery address',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: p.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Icon(Icons.location_on_rounded,
                        color: Color(0xFF0077B6), size: 19),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _addressCtrl,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter delivery address…',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: p.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Use my location button
              GestureDetector(
                onTap: _gettingLocation ? null : _useMyLocation,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _gettingLocation
                      ? const SizedBox(
                          width: 17, height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0077B6),
                          ),
                        )
                      : Icon(
                          _deliveryLat != null
                              ? Icons.my_location_rounded
                              : Icons.gps_fixed_rounded,
                          size: 19,
                          color: _deliveryLat != null
                              ? const Color(0xFF0077B6)
                              : p.textMuted,
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_deliveryLat != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: Color(0xFF1E9E47)),
                const SizedBox(width: 5),
                Text(
                  'GPS coordinates saved for live tracking',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),

        // Map preview
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? p.bgElevated : const Color(0xFFE8EEF2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MapGridPainter(isDark: isDark))),
              Positioned(
                top: -10, left: 30,
                child: Transform.rotate(
                  angle: 0.42,
                  child: Container(
                    width: 18, height: 200,
                    color: isDark ? p.bgPage : Colors.white,
                  ),
                ),
              ),
              Positioned(
                top: 60, left: -20,
                child: Transform.rotate(
                  angle: -0.14,
                  child: Container(
                    width: 300, height: 14,
                    color: isDark ? p.bgPage : Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 20, right: 30,
                child: Container(
                  width: 90, height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2E1C) : const Color(0xFFd6e9d8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Center(
                child: Icon(Icons.home_rounded,
                    color: Color(0xFF0077B6), size: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Timing
        Text(
          'Delivery time',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: _PillButton(
              selected: _timing == 'asap',
              onTap: () => setState(() => _timing = 'asap'),
              icon: Icons.bolt_rounded,
              label: 'ASAP',
            )),
            const SizedBox(width: 11),
            Expanded(child: _PillButton(
              selected: _timing == 'schedule',
              onTap: () => setState(() => _timing = 'schedule'),
              icon: Icons.event_rounded,
              label: 'Schedule',
            )),
          ],
        ),
        if (_timing == 'schedule') ...[
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: p.bgSurface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: p.border, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: p.textMuted,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 3),
                      Text('Tomorrow',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: p.bgSurface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: p.border, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIME',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: p.textMuted,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 3),
                      Text('10:00 AM',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),

        // Instructions
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Special instructions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '· optional',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              decoration: BoxDecoration(
                color: p.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border, width: 1.5),
              ),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 13.5, color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Call me at the gate, blue door on the left…',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: p.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3(AqPalette p, bool isDark) {
    return Column(
      children: [
        // Order summary
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Order summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded,
                      color: Color(0xFF0077B6), size: 17),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '$_qty × ${_volumeLiters}L',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _ksh(_subtotal),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${_ksh(_unitPrice)} each',
                style: TextStyle(fontSize: 12, color: p.textMuted),
                textAlign: TextAlign.start,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Divider(color: p.border, height: 1),
              ),
              _SummaryRow(label: 'Subtotal', value: _ksh(_subtotal)),
              const SizedBox(height: 7),
              _SummaryRow(label: 'Delivery fee', value: _ksh(_fee)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Divider(color: p.border, height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _ksh(_total),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0077B6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Payment method
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Payment method',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PaymentRow(
          selected: _payment == 'mpesa',
          onTap: () => setState(() => _payment = 'mpesa'),
          icon: Icons.phone_android_rounded,
          iconBg: const Color(0xFFE9F8EE),
          iconFg: const Color(0xFF2DC653),
          iconText: 'M-P',
          title: 'M-Pesa',
          subtitle: 'STK push to your phone',
        ),
        if (_payment == 'mpesa') ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _editMpesaPhone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.bgElevated,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: p.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    _mpesaPhone,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'EDIT',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0077B6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _PaymentRow(
          selected: _payment == 'card',
          onTap: () => setState(() => _payment = 'card'),
          icon: Icons.credit_card_rounded,
          iconBg: const Color(0xFFE6F6FC),
          iconFg: const Color(0xFF0077B6),
          title: 'Card',
          subtitle: 'Visa, Mastercard',
        ),
        const SizedBox(height: 10),
        _PaymentRow(
          selected: _payment == 'cash',
          onTap: () => setState(() => _payment = 'cash'),
          icon: Icons.payments_rounded,
          iconBg: const Color(0xFFFEF6E9),
          iconFg: const Color(0xFFC9742B),
          title: 'Pay on delivery',
          subtitle: 'Cash or card on arrival',
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;

  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0077B6).withValues(alpha: 0.07)
              : p.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0077B6) : p.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF0077B6)),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF0077B6)),
              ],
            ),
            const SizedBox(height: 9),
            Text(title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                )),
            const SizedBox(height: 1),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: p.textSecondary,
                )),
            const SizedBox(height: 8),
            const Text(
              '', // price rendered below
              style: TextStyle(fontSize: 0),
            ),
            Text(price,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0077B6),
                )),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _PillButton({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0077B6) : p.bgSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? const Color(0xFF0077B6) : p.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: selected ? Colors.white : p.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  const _Toggle({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50, height: 30,
      decoration: BoxDecoration(
        color: value ? const Color(0xFF0077B6) : const Color(0xFFcdd6df),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13.5, color: p.textSecondary))),
        Text(value,
            style: TextStyle(fontSize: 13.5, color: p.textSecondary)),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String? iconText;
  final String title;
  final String subtitle;

  const _PaymentRow({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    this.iconText,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0077B6).withValues(alpha: 0.07)
              : p.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF0077B6) : p.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: isDark ? 0.18 : 1.0),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: iconText != null
                    ? Text(iconText!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: iconFg,
                        ))
                    : Icon(icon, size: 19, color: iconFg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textSecondary,
                      )),
                ],
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0077B6)
                      : p.border,
                  width: 2,
                ),
                color: selected ? const Color(0xFF0077B6) : p.bgSurface,
              ),
              child: selected
                  ? const Center(
                      child: SizedBox(
                        width: 8, height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDark;
  const _MapGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF2B2A30) : const Color(0xFFdbe3e9)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.isDark != isDark;
}

extension _Ints on int {
  String toLocaleString() {
    final s = toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
