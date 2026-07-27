import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'driver_delivery_detail_screen.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});
  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _isOnline = false;
  bool _toggling = false;
  LatLng? _driverLatLng;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    ApiService.userNotifier.addListener(_onUserChanged);
    _load();
  }

  @override
  void dispose() {
    ApiService.userNotifier.removeListener(_onUserChanged);
    LocationService.stopTracking();
    _posStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final o = await ApiService.getDriverOrders();
    if (mounted) setState(() { _orders = o; _loading = false; });
  }

  Future<void> _toggle() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final goOnline = !_isOnline;
    if (goOnline) {
      final granted = await LocationService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() => _toggling = false);
        return;
      }
    }
    final result = await ApiService.updateDriverStatus(
        goOnline ? 'available' : 'offline');
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() { _isOnline = goOnline; _toggling = false; });
      if (goOnline) {
        LocationService.startTracking();
        _startMapTracking();
      } else {
        LocationService.stopTracking();
        _stopMapTracking();
      }
    } else {
      setState(() => _toggling = false);
    }
  }

  Future<void> _startMapTracking() async {
    // Snap to initial position immediately so map appears without delay
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() => _driverLatLng = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}

    // Keep marker live — update every 10 metres of movement
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() => _driverLatLng = latlng);
      // Follow the driver; ignore if map is not yet ready
      try {
        _mapController.move(latlng, _mapController.camera.zoom);
      } catch (_) {}
    });
  }

  void _stopMapTracking() {
    _posStream?.cancel();
    _posStream = null;
    if (mounted) setState(() => _driverLatLng = null);
  }

  List<dynamic> get _active =>
      _orders.where((o) => ['ASSIGNED', 'IN_TRANSIT'].contains(o['status'])).toList();
  List<dynamic> get _upcoming =>
      _orders.where((o) => o['status'] == 'PENDING').toList();
  List<dynamic> get _done =>
      _orders.where((o) => ['DELIVERED', 'COMPLETED'].contains(o['status'])).toList();

  double get _todayEarnings {
    final now = DateTime.now();
    return _done.where((o) {
      try {
        final d = DateTime.parse(o['created_at'].toString()).toLocal();
        return d.day == now.day && d.month == now.month && d.year == now.year;
      } catch (_) { return false; }
    }).fold(0.0, (s, o) => s + (double.tryParse(o['delivery_fee']?.toString() ?? '') ?? 0));
  }

  String get _driverName {
    final u = ApiService.getUser();
    return u?['name'] ?? 'Peter Otieno';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.bgPage,
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF2DC653),
        backgroundColor: p.bgSurface,
        child: CustomScrollView(
          slivers: [
            // Header (always green gradient)
            SliverToBoxAdapter(child: _buildHeader()),
            // Live location map — visible only while online and GPS ready
            if (_isOnline && _driverLatLng != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildLocationMap(),
                ),
              ),
            // Active delivery
            if (_active.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _ActiveCard(order: _active.first, onTap: () => _open(_active.first)),
                ),
              ),
            // Upcoming
            if (_upcoming.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Upcoming deliveries',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F8EE).withValues(alpha: isDark ? 0.18 : 1.0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_upcoming.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E9E47),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _DeliveryRow(
                      order: _upcoming[i],
                      onTap: () => _open(_upcoming[i]),
                    ),
                    childCount: _upcoming.length,
                  ),
                ),
              ),
            ],
            // Empty / loading
            if (_loading)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: CircularProgressIndicator(
                        color: const Color(0xFF2DC653), strokeWidth: 2),
                  ),
                ),
              )
            else if (_active.isEmpty && _upcoming.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: p.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F8EE).withValues(alpha: isDark ? 0.18 : 1.0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(Icons.two_wheeler_rounded,
                              color: Color(0xFF2DC653), size: 30),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No deliveries yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Go online to start receiving orders',
                        style: TextStyle(fontSize: 13, color: p.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _open(Map<String, dynamic> order) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DriverDeliveryDetailScreen(
          order: Map<String, dynamic>.from(order)),
    ),
  );

  Widget _buildLocationMap() {
    const green = Color(0xFF1E9E47);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverLatLng!,
                initialZoom: 15.5,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.hydroflow.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLatLng!,
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing halo
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: green.withValues(alpha: 0.18),
                            ),
                          ),
                          // Core dot
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: green,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: green.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // "You are here" pill at bottom-center
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded,
                          size: 13, color: green),
                      SizedBox(width: 5),
                      Text(
                        'You are here',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Recenter button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (_driverLatLng != null) {
                    try {
                      _mapController.move(
                          _driverLatLng!, _mapController.camera.zoom);
                    } catch (_) {}
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.gps_fixed_rounded,
                        size: 18, color: green),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final todayJobs = _active.length + _upcoming.length;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E9E47), Color(0xFF157A35)],
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
                    Text(
                      '$_greeting 👋',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _driverName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isOnline
                              ? const Color(0xFF1E9E47)
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _toggling ? '...' : (_isOnline ? 'Online' : 'Offline'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isOnline ? const Color(0xFF1E9E47) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatCard(
                label: "Today's jobs",
                value: '$todayJobs',
                icon: Icons.two_wheeler_rounded,
                iconBg: Colors.white.withValues(alpha: 0.18),
                iconFg: Colors.white,
                valueFg: Colors.white,
                labelFg: Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Completed',
                value: '${_done.length}',
                icon: Icons.check_circle_rounded,
                iconBg: Colors.white.withValues(alpha: 0.18),
                iconFg: Colors.white,
                valueFg: Colors.white,
                labelFg: Colors.white.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'KSh today',
                value: _todayEarnings.toStringAsFixed(0),
                icon: Icons.wallet_rounded,
                iconBg: Colors.white.withValues(alpha: 0.18),
                iconFg: Colors.white,
                valueFg: Colors.white,
                labelFg: Colors.white.withValues(alpha: 0.75),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final Color valueFg;
  final Color labelFg;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.valueFg,
    required this.labelFg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(icon, color: iconFg, size: 16)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueFg,
              ),
            ),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 10.5, color: labelFg)),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _ActiveCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = order['status']?.toString() ?? 'ASSIGNED';
    final isTransit = status == 'IN_TRANSIT';
    final customer = order['customer_name'] ?? 'Customer';
    final address = order['delivery_address'] ?? '';
    final qty = '${order['quantity'] ?? 1} × ${order['volume_liters'] ?? 20}L';

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: p.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTransit
              ? const Color(0xFF2DC653).withValues(alpha: 0.4)
              : const Color(0xFF0077B6).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: (isTransit
                ? const Color(0xFF2DC653)
                : const Color(0xFF0077B6)).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isTransit
                  ? const Color(0xFFE9F8EE).withValues(alpha: isDark ? 0.18 : 1.0)
                  : const Color(0xFFE6F6FC).withValues(alpha: isDark ? 0.18 : 1.0),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTransit
                        ? const Color(0xFF2DC653)
                        : const Color(0xFF0077B6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isTransit ? 'On the way' : 'Active delivery',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isTransit
                        ? const Color(0xFF1E9E47)
                        : const Color(0xFF0353A0),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          customer.isNotEmpty ? customer[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            qty,
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: p.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onTap,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E9E47),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E9E47).withValues(alpha: 0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.navigation_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 7),
                              Text(
                                'Navigate',
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
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: p.bgElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Center(
                          child: Text(
                            'View details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _DeliveryRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customer = order['customer_name'] ?? 'Customer';
    final address = order['delivery_address'] ?? '';
    final qty = '${order['quantity'] ?? 1} × ${order['volume_liters'] ?? 20}L';
    final amount = 'KSh ${order['delivery_fee'] ?? '-'}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                color: const Color(0xFFE9F8EE).withValues(alpha: isDark ? 0.18 : 1.0),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(
                child: Icon(Icons.two_wheeler_rounded,
                    color: Color(0xFF1E9E47), size: 21),
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
                  const SizedBox(height: 1),
                  Text(
                    '$qty · $address',
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E9E47),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: p.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
