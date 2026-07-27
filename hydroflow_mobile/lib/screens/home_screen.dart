import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'order_screen.dart';
import 'tracking_screen.dart';
import 'my_orders_screen.dart';
import 'order_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _recentOrders = [];
  bool _loading = true;
  String _deliveryAddress = 'Set your location';

  @override
  void initState() {
    super.initState();
    ApiService.userNotifier.addListener(_onUserChanged);
    _load();
  }

  @override
  void dispose() {
    ApiService.userNotifier.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() => _user = ApiService.userNotifier.value);
  }

  Future<void> _load() async {
    _user = ApiService.getUser();
    // Load saved delivery address (SharedPrefs first, then profile fallback)
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('resident_delivery_address') ?? '';
    final profileAddr = _user?['delivery_address']?.toString() ?? '';
    if (saved.isNotEmpty) {
      setState(() => _deliveryAddress = saved);
    } else if (profileAddr.isNotEmpty) {
      setState(() => _deliveryAddress = profileAddr);
    }
    try {
      final orders = await ApiService.getMyOrders();
      if (mounted) {
        setState(() {
          _recentOrders = orders.take(3).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAddress(String addr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resident_delivery_address', addr);
    if (mounted) setState(() => _deliveryAddress = addr);
  }

  void _editLocation() {
    final p = Aq.of(context);
    final ctrl = TextEditingController(
        text: _deliveryAddress == 'Set your location' ? '' : _deliveryAddress);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery location',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Shown on your home screen and used for orders',
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.streetAddress,
              autofocus: true,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Apt 4B, Kilimani Heights, Nairobi',
                hintStyle: TextStyle(
                    color: p.textMuted, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.location_on_rounded,
                    color: Color(0xFF0077B6), size: 20),
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
                if (val.isNotEmpty) _saveAddress(val);
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
                    'Save location',
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
      ),
    );
  }

  String get _firstName {
    final name = _user?['name'] ?? 'James Mwangi';
    return name.toString().split(' ').first;
  }

  Color _statusBg(String status, bool isDark) {
    final alpha = isDark ? 0.18 : 1.0;
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFFE9F8EE).withValues(alpha: alpha);
      case 'PENDING':
      case 'ASSIGNED': return const Color(0xFFFEF3E7).withValues(alpha: alpha);
      case 'CANCELLED': return const Color(0xFFfbeaec).withValues(alpha: alpha);
      default: return const Color(0xFFF0F4F8).withValues(alpha: alpha);
    }
  }

  Color _statusFg(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFF1E9E47);
      case 'PENDING':
      case 'ASSIGNED': return const Color(0xFFC9742B);
      case 'CANCELLED': return const Color(0xFFE63946);
      default: return const Color(0xFF6b7785);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
      case 'COMPLETED': return Icons.check_rounded;
      case 'PENDING': return Icons.schedule_rounded;
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

  bool get _hasActiveOrder {
    return _recentOrders.any((o) {
      final s = (o['status'] ?? '').toString().toUpperCase();
      return s == 'PENDING' || s == 'ASSIGNED' || s == 'IN_TRANSIT';
    });
  }

  Map<String, dynamic>? get _activeOrder {
    try {
      return _recentOrders.firstWhere((o) {
        final s = (o['status'] ?? '').toString().toUpperCase();
        return s == 'PENDING' || s == 'ASSIGNED' || s == 'IN_TRANSIT';
      });
    } catch (_) {
      return null;
    }
  }

  // Most recently placed order (list is already sorted newest-first by the backend).
  Map<String, dynamic>? get _lastOrder =>
      _recentOrders.isNotEmpty ? _recentOrders.first : null;

  String _relativeTime(String? isoDate) {
    if (isoDate == null) return 'Recently';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt).inDays;
      if (diff <= 0) return 'today';
      if (diff == 1) return 'yesterday';
      if (diff < 7) return '$diff days ago';
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return 'on ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return 'Recently';
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
            // Header (always brand gradient)
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0077B6), Color(0xFF0353A0)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(26),
                    bottomRight: Radius.circular(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Good morning ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xCCCAF0F8),
                                    ),
                                  ),
                                  Text('👋', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _firstName,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          child: Center(
                            child: Text(
                              (_user?['name'] ?? 'JM')
                                  .toString()
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join()
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _editLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: Color(0xFFCAF0F8)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _deliveryAddress,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xB3FFFFFF)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Order hero
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OrderScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00A8D6), Color(0xFF0077B6)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0077B6).withValues(alpha: 0.7),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                            spreadRadius: -18,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -6, bottom: -14,
                            child: _WaterContainerImage(),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded,
                                        size: 13, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Fastest in Around Daystar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Order water',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Purified 10L & 20L water,\nat your door in under an hour.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Start an order',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0077B6),
                                      ),
                                    ),
                                    SizedBox(width: 7),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 17, color: Color(0xFF0077B6)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Active order banner
                  if (_hasActiveOrder) ...[
                    _ActiveOrderBanner(
                      order: _activeOrder!,
                      onTrack: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackingScreen(
                              orderId: _activeOrder!['id']?.toString() ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quick reorder — reflects the resident's actual last order
                  if (_lastOrder != null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick reorder',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: p.bgSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: p.border),
                            boxShadow: isDark ? null : const [
                              BoxShadow(
                                color: Color(0x08101828),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46, height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.15 : 0.1),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Center(
                                  child: Icon(Icons.water_drop_rounded,
                                      color: Color(0xFF0077B6), size: 23),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_lastOrder!['quantity'] ?? 1} × ${_lastOrder!['volume_liters'] ?? 20}L Refill',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Last ordered ${_relativeTime(_lastOrder!['created_at']?.toString())} · KSh ${_lastOrder!['amount_ksh'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderScreen(
                                      initialVolumeLiters: int.tryParse(
                                          _lastOrder!['volume_liters']?.toString() ?? ''),
                                      initialQuantity: int.tryParse(
                                          _lastOrder!['quantity']?.toString() ?? ''),
                                      initialReturnEmpty:
                                          _lastOrder!['return_empties'] == true,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.18 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Reorder',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0077B6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent orders
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent orders',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MyOrdersScreen()),
                            ),
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0077B6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      if (_loading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                color: p.primary, strokeWidth: 2),
                          ),
                        )
                      else if (_recentOrders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: p.bgSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.border),
                          ),
                          child: Center(
                            child: Text(
                              'No orders yet',
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _recentOrders.map((o) {
                            final status = o['status']?.toString() ?? 'PENDING';
                            final qty = '${o['volume_liters'] ?? 20}L';
                            final date = o['created_at'] != null
                                ? _formatDate(o['created_at'].toString())
                                : 'Recent';
                            final amount = 'KSh ${o['amount_ksh'] ?? '-'}';
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(
                                      orderId: o['id']?.toString() ?? ''),
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(13),
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
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: p.bgElevated,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(Icons.water_drop_rounded,
                                            color: p.textSecondary, size: 19),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            qty,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '$date · $amount',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: p.textSecondary,
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
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return 'Recent';
    }
  }
}

class _WaterContainerImage extends StatelessWidget {
  const _WaterContainerImage();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Image.asset(
          'lib/assets/water_bottle.jpeg',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.water_drop_rounded,
                color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderBanner extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTrack;

  const _ActiveOrderBanner({required this.order, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: p.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
        boxShadow: isDark ? null : const [
          BoxShadow(color: Color(0x08101828), blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x50101828), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -22),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Icon(Icons.two_wheeler_rounded,
                          color: Color(0xFF0077B6), size: 21),
                    ),
                  ),
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DC653),
                        shape: BoxShape.circle,
                        border: Border.all(color: p.bgSurface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver is on the way',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Peter O. · Arriving in ~12 min',
                      style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.66,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A8D6), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: onTrack,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0077B6),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 7),
                  Text(
                    'Track delivery',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
