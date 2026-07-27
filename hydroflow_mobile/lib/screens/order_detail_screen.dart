import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _confirming = false;
  bool _submittingRating = false;
  int _selectedStars = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getOrderById(widget.orderId);
      if (mounted) setState(() {
        _order = res['success'] == true ? res['order'] as Map<String, dynamic>? : null;
        _loading = false;
        _selectedStars = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _existingRating =>
      int.tryParse(_order?['rating']?.toString() ?? '') ?? 0;

  Future<void> _confirmReceipt() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    final res = await ApiService.confirmDelivery(widget.orderId);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (res['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Could not confirm delivery'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _submitRating() async {
    if (_selectedStars == 0 || _submittingRating) return;
    setState(() => _submittingRating = true);
    final res = await ApiService.rateOrder(widget.orderId, _selectedStars);
    if (!mounted) return;
    setState(() => _submittingRating = false);
    if (res['success'] == true) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Could not submit rating'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Color _statusBg(String status, bool isDark) {
    final alpha = isDark ? 0.18 : 1.0;
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFFE9F8EE).withValues(alpha: alpha);
      case 'PENDING':
      case 'ASSIGNED':
      case 'IN_TRANSIT': return const Color(0xFFFEF3E7).withValues(alpha: alpha);
      case 'CANCELLED': return const Color(0xFFfbeaec).withValues(alpha: alpha);
      default: return const Color(0xFFF0F4F8).withValues(alpha: alpha);
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFF1E9E47);
      case 'PENDING':
      case 'ASSIGNED':
      case 'IN_TRANSIT': return const Color(0xFFC9742B);
      case 'CANCELLED': return const Color(0xFFE63946);
      default: return const Color(0xFF6b7785);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return Icons.check_rounded;
      case 'PENDING': return Icons.schedule_rounded;
      case 'IN_TRANSIT': return Icons.two_wheeler_rounded;
      case 'CANCELLED': return Icons.close_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return 'Delivered';
      case 'COMPLETED': return 'Completed';
      case 'PENDING': return 'Pending';
      case 'ASSIGNED': return 'Assigned';
      case 'IN_TRANSIT': return 'On the way';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Recent';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} · $h:$m ${dt.hour < 12 ? "AM" : "PM"}';
    } catch (_) {
      return 'Recent';
    }
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour < 12 ? "AM" : "PM"}';
    } catch (_) {
      return '';
    }
  }

  String? get _driverName {
    final n = _order?['driver_name']?.toString();
    return (n == null || n.isEmpty) ? null : n;
  }

  String get _driverInitials {
    final parts = (_driverName ?? '').split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  String get _driverVehicle {
    final info = _order?['driver_vehicle_info']?.toString();
    final plate = _order?['driver_vehicle_plate']?.toString();
    final hasInfo = info != null && info.isNotEmpty;
    final hasPlate = plate != null && plate.isNotEmpty && plate != 'TBD';
    if (hasInfo && hasPlate) return '$info · $plate';
    if (hasInfo) return info;
    if (hasPlate) return plate;
    return 'Motorbike details not set';
  }

  String get _driverRatingText {
    final r = double.tryParse(_order?['driver_rating']?.toString() ?? '');
    return (r == null || r <= 0) ? '—' : r.toStringAsFixed(1);
  }

  String? get _podPhotoUrl => _order?['pod_photo_url']?.toString();
  String? get _podSignatureUrl => _order?['pod_signature_url']?.toString();
  int get _podEmptyCollected =>
      int.tryParse(_order?['pod_empty_collected']?.toString() ?? '') ?? 0;
  bool get _hasProofOfDelivery =>
      (_podPhotoUrl != null && _podPhotoUrl!.isNotEmpty) ||
      (_podSignatureUrl != null && _podSignatureUrl!.isNotEmpty);

  Widget _buildProofOfDelivery(AqPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROOF OF DELIVERY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_podPhotoUrl != null && _podPhotoUrl!.isNotEmpty)
                Expanded(
                  child: _ProofThumb(label: 'Photo', imageUrl: _podPhotoUrl!, p: p),
                ),
              if (_podPhotoUrl != null &&
                  _podPhotoUrl!.isNotEmpty &&
                  _podSignatureUrl != null &&
                  _podSignatureUrl!.isNotEmpty)
                const SizedBox(width: 12),
              if (_podSignatureUrl != null && _podSignatureUrl!.isNotEmpty)
                Expanded(
                  child: _ProofThumb(
                      label: 'Signature', imageUrl: _podSignatureUrl!, p: p),
                ),
            ],
          ),
          if (_podEmptyCollected > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.recycling_rounded,
                    color: Color(0xFFC9742B), size: 16),
                const SizedBox(width: 8),
                Text(
                  '$_podEmptyCollected empt${_podEmptyCollected == 1 ? 'y' : 'ies'} collected',
                  style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmReceiptCard(AqPalette p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded,
                  color: Color(0xFF0077B6), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Received your order?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm receipt so you can rate your delivery.',
            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _confirming ? null : _confirmReceipt,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0077B6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _confirming
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Confirm delivery received',
                        style: TextStyle(
                          fontSize: 14,
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
  }

  Widget _buildRatingCard(AqPalette p) {
    final rated = _existingRating > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rated ? 'YOUR RATING' : 'RATE YOUR DELIVERY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled =
                  rated ? starIndex <= _existingRating : starIndex <= _selectedStars;
              return GestureDetector(
                onTap: (rated || _submittingRating)
                    ? null
                    : () => setState(() => _selectedStars = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: const Color(0xFFF4A261),
                  ),
                ),
              );
            }),
          ),
          if (!rated) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: (_selectedStars == 0 || _submittingRating)
                  ? null
                  : _submitRating,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _selectedStars == 0
                      ? p.bgElevated
                      : const Color(0xFF1E9E47),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _submittingRating
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          'Submit rating',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _selectedStars == 0
                                ? p.textMuted
                                : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Thanks for your feedback!',
                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _order?['status']?.toString() ?? 'PENDING';
    final qty = '${_order?['quantity'] ?? 1} × ${_order?['volume_liters'] ?? 20}L';
    final amtRaw = int.tryParse(_order?['amount_ksh']?.toString() ?? '0') ?? 0;
    final subtotal = (amtRaw - 60).clamp(0, 99999);
    final date = _formatDate(_order?['created_at']?.toString());
    final deliveredTime = _formatTime(_order?['completed_at']?.toString());

    return Scaffold(
      backgroundColor: p.bgPage,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: p.primary, strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: p.bgSurface,
                    padding: EdgeInsets.fromLTRB(
                        20, MediaQuery.of(context).padding.top + 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.orderId.isNotEmpty
                                        ? widget.orderId
                                        : 'AQ-0000',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    date,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusBg(status, isDark),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon(status),
                                      size: 12, color: _statusFg(status)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _statusFg(status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Items + pricing
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ITEMS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: p.textMuted,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              children: [
                                const Icon(Icons.water_drop_rounded,
                                    color: Color(0xFF0077B6), size: 17),
                                const SizedBox(width: 10),
                                Text(
                                  qty,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              child: Divider(color: p.border, height: 1),
                            ),
                            _SummaryRow(
                                label: 'Subtotal',
                                value: 'KSh $subtotal'),
                            const SizedBox(height: 7),
                            const _SummaryRow(
                                label: 'Delivery fee', value: 'KSh 60'),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              child: Divider(color: p.border, height: 1),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total paid',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'KSh $amtRaw',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0077B6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_driverName != null) ...[
                      const SizedBox(height: 14),

                      // Delivered by
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DELIVERED BY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: p.textMuted,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 44, height: 44,
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _driverInitials,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _driverName!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _driverVehicle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14, color: Color(0xFFF4A261)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _driverRatingText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 14, color: p.textSecondary),
                                const SizedBox(width: 7),
                                Text(
                                  deliveredTime.isNotEmpty
                                      ? 'Delivered at $deliveredTime'
                                      : 'Not yet delivered',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ],

                      // Proof of delivery
                      if (_hasProofOfDelivery) ...[
                        _buildProofOfDelivery(p),
                        const SizedBox(height: 14),
                      ],

                      // Confirm receipt (unlocks rating) / rate the order
                      if (status == 'DELIVERED') ...[
                        _buildConfirmReceiptCard(p),
                        const SizedBox(height: 14),
                      ] else if (status == 'COMPLETED') ...[
                        _buildRatingCard(p),
                        const SizedBox(height: 14),
                      ],

                      // Reorder
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderScreen(
                              initialVolumeLiters: int.tryParse(
                                  _order?['volume_liters']?.toString() ?? ''),
                              initialQuantity: int.tryParse(
                                  _order?['quantity']?.toString() ?? ''),
                              initialReturnEmpty:
                                  _order?['return_empties'] == true,
                            ),
                          ),
                        ),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0077B6),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0077B6)
                                    .withValues(alpha: 0.7),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                                spreadRadius: -12,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.replay_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Reorder',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag_outlined,
                                  size: 15, color: p.textSecondary),
                              const SizedBox(width: 7),
                              Text(
                                'Report an issue',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProofThumb extends StatelessWidget {
  final String label;
  final String imageUrl;
  final AqPalette p;
  const _ProofThumb({required this.label, required this.imageUrl, required this.p});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: Container(
                color: p.bgElevated,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: p.primary)),
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: p.textMuted, size: 22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: p.textSecondary)),
        ],
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
