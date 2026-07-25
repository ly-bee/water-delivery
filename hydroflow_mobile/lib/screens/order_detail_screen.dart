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
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      case 'IN_TRANSIT': return Icons.local_shipping_rounded;
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

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _order?['status']?.toString() ?? 'PENDING';
    final qty = '${_order?['quantity'] ?? 1} × ${_order?['volume_liters'] ?? 20}L';
    final amtRaw = int.tryParse(_order?['amount_ksh']?.toString() ?? '0') ?? 0;
    final subtotal = (amtRaw - 60).clamp(0, 99999);
    final date = _formatDate(_order?['created_at']?.toString());

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
                                const SizedBox(
                                  width: 44, height: 44,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'PO',
                                        style: TextStyle(
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
                                        'Peter Otieno',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'White Pickup · KCA 123X',
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
                                      '4.9',
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
                                  'Delivered at 8:52 AM',
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

                      // Reorder
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrderScreen()),
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
