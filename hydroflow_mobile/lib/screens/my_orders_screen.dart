import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_detail_screen.dart';
import 'tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final orders = await ApiService.getMyOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
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
      case 'PENDING':
      case 'ASSIGNED': return Icons.schedule_rounded;
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
      final now = DateTime.now();
      final diff = now.difference(dt).inDays;
      if (diff == 0) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return 'Today · $h:$m';
      }
      if (diff == 1) return 'Yesterday';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} · $h:$m';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.bgPage,
      body: RefreshIndicator(
        onRefresh: _load,
        color: p.primary,
        backgroundColor: p.bgSurface,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: p.bgSurface,
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your orders',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loading
                          ? 'Loading...'
                          : '${_orders.length} order${_orders.length == 1 ? '' : 's'} · all time',
                      style: TextStyle(fontSize: 13, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              sliver: _loading
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: p.primary, strokeWidth: 2),
                        ),
                      ),
                    )
                  : _orders.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: p.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 48, color: p.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No orders yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your order history will appear here',
                                  style: TextStyle(
                                      fontSize: 13, color: p.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final o = _orders[i];
                              final status = o['status']?.toString() ?? 'PENDING';
                              final qty = '${o['quantity'] ?? 1} × ${o['volume_liters'] ?? 20}L';
                              final date = _formatDate(o['created_at']?.toString());
                              final amount = 'KSh ${o['amount_ksh'] ?? '-'}';
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderDetailScreen(
                                        orderId: o['id']?.toString() ?? ''),
                                  ),
                                ).then((_) => _load()),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 11),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: p.bgSurface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: p.border),
                                    boxShadow: isDark ? null : const [
                                      BoxShadow(
                                        color: Color(0x05101828),
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.15 : 0.1),
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.water_drop_rounded,
                                              color: Color(0xFF0077B6), size: 21),
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              qty,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: p.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              date,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: p.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            amount,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
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
                                                    size: 12,
                                                    color: _statusFg(status)),
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
                                          if (status == 'ASSIGNED' || status == 'IN_TRANSIT') ...[
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TrackingScreen(
                                                      orderId: o['id']?.toString() ?? ''),
                                                ),
                                              ).then((_) => _load()),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0077B6),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.navigation_rounded,
                                                        size: 11, color: Colors.white),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Track',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _orders.length,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
