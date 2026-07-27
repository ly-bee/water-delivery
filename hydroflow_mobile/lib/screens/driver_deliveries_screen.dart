import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'driver_delivery_detail_screen.dart';

class DriverDeliveriesScreen extends StatefulWidget {
  const DriverDeliveriesScreen({super.key});
  @override
  State<DriverDeliveriesScreen> createState() => _DriverDeliveriesScreenState();
}

class _DriverDeliveriesScreenState extends State<DriverDeliveriesScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  int _tab = 0; // 0=Today, 1=Upcoming, 2=Completed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final o = await ApiService.getDriverOrders();
    if (mounted) setState(() { _orders = o; _loading = false; });
  }

  List<dynamic> get _today {
    final now = DateTime.now();
    return _orders.where((o) {
      try {
        final d = DateTime.parse(o['created_at'].toString()).toLocal();
        return d.day == now.day && d.month == now.month && d.year == now.year;
      } catch (_) { return false; }
    }).toList();
  }

  List<dynamic> get _upcoming =>
      _orders.where((o) => ['PENDING', 'ASSIGNED'].contains(o['status'])).toList();

  List<dynamic> get _completed =>
      _orders.where((o) => ['DELIVERED', 'COMPLETED'].contains(o['status'])).toList();

  List<dynamic> get _current {
    switch (_tab) {
      case 0: return _today;
      case 1: return _upcoming;
      case 2: return _completed;
      default: return _today;
    }
  }

  Color _statusBg(String status, bool isDark) {
    final alpha = isDark ? 0.18 : 1.0;
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFFE9F8EE).withValues(alpha: alpha);
      case 'IN_TRANSIT': return const Color(0xFFE6F6FC).withValues(alpha: alpha);
      case 'ASSIGNED': return const Color(0xFFFEF3E7).withValues(alpha: alpha);
      default: return const Color(0xFFF0F4F8).withValues(alpha: alpha);
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFF1E9E47);
      case 'IN_TRANSIT': return const Color(0xFF0077B6);
      case 'ASSIGNED': return const Color(0xFFC9742B);
      default: return const Color(0xFF6b7785);
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return 'Delivered';
      case 'COMPLETED': return 'Completed';
      case 'IN_TRANSIT': return 'In transit';
      case 'ASSIGNED': return 'Assigned';
      case 'PENDING': return 'Pending';
      default: return status;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt).inDays;
      final h = dt.hour.toString().padLeft(2, '0');
      final m2 = dt.minute.toString().padLeft(2, '0');
      if (diff == 0) return 'Today · $h:$m2';
      if (diff == 1) return 'Yesterday · $h:$m2';
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month-1]} · $h:$m2';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = ['Today', 'Upcoming', 'Completed'];

    return Scaffold(
      backgroundColor: p.bgPage,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: p.bgSurface,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliveries',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(3, (i) {
                      final sel = _tab == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            height: 36,
                            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1E9E47)
                                  : p.bgElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                tabs[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : p.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            sliver: _loading
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: const Color(0xFF1E9E47), strokeWidth: 2),
                      ),
                    ),
                  )
                : _current.isEmpty
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
                              Icon(Icons.inbox_rounded,
                                  size: 44, color: p.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                'Nothing here',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final o = _current[i];
                            final status = o['status']?.toString() ?? 'PENDING';
                            final customer = o['customer_name'] ?? 'Customer';
                            final qty =
                                '${o['quantity'] ?? 1} × ${o['volume_liters'] ?? 20}L';
                            final amount = 'KSh ${o['delivery_fee'] ?? '-'}';
                            final date = _formatDate(o['created_at']?.toString());

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DriverDeliveryDetailScreen(
                                      order: Map<String, dynamic>.from(o)),
                                ),
                              ).then((_) => _load()),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 11),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: p.bgSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: _statusBg(status, isDark),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.two_wheeler_rounded,
                                          color: _statusFg(status),
                                          size: 21,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$qty · $date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: p.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          amount,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: p.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _statusBg(status, isDark),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: _statusFg(status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _current.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
