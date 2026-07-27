import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import 'driver_pod_screen.dart';

class DriverDeliveryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const DriverDeliveryDetailScreen({super.key, required this.order});
  @override
  State<DriverDeliveryDetailScreen> createState() =>
      _DriverDeliveryDetailScreenState();
}

class _DriverDeliveryDetailScreenState
    extends State<DriverDeliveryDetailScreen> {
  late Map<String, dynamic> _order;
  bool _updating = false;
  Timer? _locationTimer;
  double? _myLat;
  double? _myLng;

  // Road-routing state
  List<LatLng> _routePoints = const [];
  double? _routeDistanceMeters;
  int? _routeDurationSecs;
  bool _routeFallback = false;
  bool _routeLoading = false;
  LatLng? _lastRouteOrigin;
  LatLng? _cachedDeliveryLatLng;

  @override
  void initState() {
    super.initState();
    _order = Map.from(widget.order);
    if (_status == 'ASSIGNED' || _status == 'IN_TRANSIT') {
      _startLocationSharing();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  String get _status => _order['status']?.toString() ?? 'ASSIGNED';

  int get _stageIndex {
    switch (_status) {
      case 'ASSIGNED': return 0;
      case 'IN_TRANSIT': return 2;
      case 'DELIVERED':
      case 'COMPLETED': return 3;
      default: return 0;
    }
  }

  double? get _deliveryLat {
    final v = _order['delivery_lat'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _deliveryLng {
    final v = _order['delivery_lng'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _distanceKm {
    if (_myLat == null || _myLng == null) return null;
    final delLat = _deliveryLat;
    final delLng = _deliveryLng;
    if (delLat == null || delLng == null) return null;
    return _haversine(_myLat!, _myLng!, delLat, delLng);
  }

  static double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String get _distanceText {
    final km = _distanceKm;
    if (km == null) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  String get _etaText {
    final km = _distanceKm;
    if (km == null) return '—';
    final mins = (km / 25 * 60).ceil();
    if (mins <= 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  // Road-based display values — fall back to Haversine when route not ready
  String get _roadDistanceText {
    if (_routeDistanceMeters != null) {
      final km = _routeDistanceMeters! / 1000;
      if (km < 1) return '${_routeDistanceMeters!.round()} m';
      return '${km.toStringAsFixed(1)} km';
    }
    return _distanceText;
  }

  String get _roadEtaText {
    if (_routeDurationSecs != null) {
      return RoutingService.formatDuration(_routeDurationSecs!);
    }
    return _etaText;
  }

  // ── Road routing ──────────────────────────────────────────────────────────

  void _maybeUpdateRoute() {
    if (_myLat == null || _myLng == null || _routeLoading) return;
    final driverPos = LatLng(_myLat!, _myLng!);
    if (!RoutingService.movedEnough(_lastRouteOrigin, driverPos)) return;
    _fetchRoute(driverPos);
  }

  Future<void> _fetchRoute(LatLng driverPos) async {
    setState(() => _routeLoading = true);

    LatLng? dest = _cachedDeliveryLatLng;
    if (dest == null) {
      final rawLat = _deliveryLat;
      final rawLng = _deliveryLng;
      if (rawLat != null && rawLng != null) {
        dest = LatLng(rawLat, rawLng);
        _cachedDeliveryLatLng = dest;
      } else {
        final addr = _order['delivery_address']?.toString() ?? '';
        if (addr.isNotEmpty) {
          dest = await GeocodingService.getLatLng(addr);
          if (mounted) setState(() => _cachedDeliveryLatLng = dest);
        }
      }
    }

    if (dest == null || !mounted) {
      setState(() => _routeLoading = false);
      return;
    }

    final result = await RoutingService.getRoute(
        origin: driverPos, destination: dest);
    if (!mounted) return;
    setState(() {
      _routePoints = result.polylinePoints;
      _routeDistanceMeters = result.distanceMeters;
      _routeDurationSecs = result.durationSeconds;
      _routeFallback = result.isFallback;
      _routeLoading = false;
      _lastRouteOrigin = driverPos;
    });
  }

  void _recalculate() {
    // Force re-fetch regardless of movement threshold
    setState(() => _lastRouteOrigin = null);
    _maybeUpdateRoute();
  }

  // ── Open Google Maps navigation ──────────────────────────────────────────

  Future<void> _openNavigation() async {
    final delLat = _deliveryLat;
    final delLng = _deliveryLng;
    final Uri uri;
    if (delLat != null && delLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$delLat,$delLng&travelmode=driving',
      );
    } else {
      final addr = Uri.encodeComponent(
          _order['delivery_address']?.toString() ?? '');
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$addr&travelmode=driving',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open Maps'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── GPS sharing ──────────────────────────────────────────────────────────

  Future<void> _startLocationSharing() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) return;

    await _pushLocation();
    _locationTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pushLocation());
  }

  Future<void> _pushLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
      });
      await ApiService.pushDriverLocation(pos.latitude, pos.longitude);
      _maybeUpdateRoute(); // refresh road route if moved >50 m
    } catch (_) {}
  }

  // ── Status advancement ───────────────────────────────────────────────────

  Future<void> _advance() async {
    if (_updating) return;

    if (_status == 'ASSIGNED') {
      setState(() => _updating = true);
      final res = await ApiService.updateDriverDeliveryStatus(
          _order['id'].toString(), 'on_the_way');
      if (!mounted) return;
      setState(() => _updating = false);
      if (res['success'] == true) {
        setState(() => _order = {..._order, 'status': 'IN_TRANSIT'});
        // Start GPS sharing if not already running
        if (_locationTimer == null) _startLocationSharing();
      } else {
        _showError(res['message'] ?? 'Failed to update status');
      }
    } else if (_status == 'IN_TRANSIT') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DriverPodScreen(orderId: _order['id']?.toString() ?? ''),
        ),
      );
      if (result == true && mounted) {
        _locationTimer?.cancel();
        setState(() => _order = {..._order, 'status': 'DELIVERED'});
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE63946),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qty =
        '${_order['quantity'] ?? 1} × ${_order['volume_liters'] ?? 20}L Refill';
    final amount =
        int.tryParse(_order['amount_ksh']?.toString() ?? '0') ?? 0;
    final subtotal = (amount - 60).clamp(0, 99999);
    final customer = _order['customer_name'] ?? 'Customer';
    final phone = _order['customer_phone'] ?? '+254 700 000 000';
    final address = _order['delivery_address'] ?? '';
    final notes = _order['notes']?.toString();
    final delivLat = _deliveryLat;
    final delivLng = _deliveryLng;
    final km = _distanceKm;

    // Build map markers
    final markers = <Marker>[];
    if (_myLat != null && _myLng != null) {
      markers.add(Marker(
        point: LatLng(_myLat!, _myLng!),
        width: 42,
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E9E47),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E9E47).withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.two_wheeler_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ));
    }
    if (delivLat != null && delivLng != null) {
      markers.add(Marker(
        point: LatLng(delivLat, delivLng),
        width: 38,
        height: 46,
        alignment: const Alignment(0, -1),
        child: const Icon(Icons.location_on_rounded,
            color: Color(0xFFE63946), size: 40),
      ));
    }

    final mapCenter = _myLat != null
        ? LatLng(_myLat!, _myLng!)
        : delivLat != null
            ? LatLng(delivLat, delivLng!)
            : const LatLng(-1.286389, 36.817223);

    return Scaffold(
      backgroundColor: p.bgPage,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: p.bgSurface,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 18),
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
                        border:
                            Border.all(color: p.border, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_back_rounded,
                            size: 19, color: p.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Delivery #${(_order['id']?.toString() ?? '').substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      // Distance badge
                      if (km != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E9E47)
                                .withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_roadDistanceText · $_roadEtaText',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E9E47),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatusPills(activeIndex: _stageIndex),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Customer card ──────────────────────────────────────
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
                      _SectionLabel(label: 'CUSTOMER'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(
                            width: 46, height: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Color(0xFF48CAE4),
                                  Color(0xFF0077B6)
                                ]),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customer,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    )),
                                Text(phone,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.textSecondary,
                                    )),
                              ],
                            ),
                          ),
                          _ActionBtn(
                            icon: Icons.phone_rounded,
                            bg: const Color(0xFFE9F8EE)
                                .withValues(alpha: isDark ? 0.18 : 1.0),
                            fg: const Color(0xFF2DC653),
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionBtn(
                            icon: Icons.chat_bubble_rounded,
                            bg: const Color(0xFFE6F6FC)
                                .withValues(alpha: isDark ? 0.18 : 1.0),
                            fg: const Color(0xFF0077B6),
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 15, color: Color(0xFF0077B6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.textSecondary,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Empties notice ─────────────────────────────────────
                if (_order['return_empties'] == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3E7)
                          .withValues(alpha: isDark ? 0.18 : 1.0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFf5d8b5)
                              .withValues(alpha: isDark ? 0.3 : 1.0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.recycling_rounded,
                            color: Color(0xFFC9742B), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Customer has empties to return — collect on arrival',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC9742B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Items + price ──────────────────────────────────────
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
                      _SectionLabel(label: 'ITEMS'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.water_drop_rounded,
                              color: Color(0xFF0077B6), size: 16),
                          const SizedBox(width: 8),
                          Text(qty,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary,
                              )),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: p.border, height: 1),
                      ),
                      _PriceRow(
                          label: 'Subtotal', value: 'KSh $subtotal'),
                      const SizedBox(height: 6),
                      const _PriceRow(
                          label: 'Delivery fee', value: 'KSh 60'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: p.border, height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                )),
                          ),
                          Text(
                            'KSh $amount',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0077B6),
                            ),
                          ),
                        ],
                      ),
                      if (notes != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: p.border, height: 1),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 14, color: p.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(notes,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.textSecondary,
                                  )),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Mini map ───────────────────────────────────────────
                Container(
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      // Map tiles (non-interactive, embedded)
                      Positioned.fill(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: mapCenter,
                            initialZoom: 14.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.hydroflow.mobile',
                              maxNativeZoom: 19,
                            ),
                            if (isDark)
                              const ColorFiltered(
                                colorFilter: ColorFilter.matrix([
                                  0.58, 0, 0, 0, 0,
                                  0, 0.58, 0, 0, 0,
                                  0, 0, 0.65, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: SizedBox.expand(),
                              ),
                            if (_routePoints.length >= 2)
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: _routeFallback
                                      ? const Color(0xFF1E9E47)
                                          .withValues(alpha: 0.45)
                                      : const Color(0xFF1E9E47),
                                  strokeWidth:
                                      _routeFallback ? 3.0 : 4.5,
                                ),
                              ])
                            else if (_myLat != null &&
                                delivLat != null &&
                                delivLng != null)
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: [
                                    LatLng(_myLat!, _myLng!),
                                    LatLng(delivLat, delivLng),
                                  ],
                                  color: const Color(0xFF1E9E47)
                                      .withValues(alpha: 0.30),
                                  strokeWidth: 3.0,
                                ),
                              ]),
                            if (markers.isNotEmpty)
                              MarkerLayer(markers: markers),
                          ],
                        ),
                      ),
                      // GPS status indicator (top-left)
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: p.bgSurface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: _myLat != null
                                      ? const Color(0xFF2DC653)
                                      : const Color(0xFFF4A261),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _myLat != null
                                    ? 'GPS active'
                                    : 'Locating…',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Recalculate route button (top-right)
                      Positioned(
                        top: 10, right: 10,
                        child: GestureDetector(
                          onTap: _routeLoading ? null : _recalculate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: p.bgSurface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_routeLoading)
                                  const SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF1E9E47),
                                    ),
                                  )
                                else
                                  const Icon(Icons.refresh_rounded,
                                      size: 13,
                                      color: Color(0xFF1E9E47)),
                                const SizedBox(width: 5),
                                Text(
                                  'Recalculate',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Distance/ETA overlay (bottom-left)
                      if (km != null || _routeDurationSecs != null)
                        Positioned(
                          bottom: 10, left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: p.bgSurface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_roadDistanceText · $_roadEtaText',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E9E47),
                              ),
                            ),
                          ),
                        ),
                      // Start Navigation button (bottom-right) — opens Google Maps
                      Positioned(
                        bottom: 10, right: 10,
                        child: GestureDetector(
                          onTap: _openNavigation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: p.textPrimary,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.navigation_rounded,
                                    color: p.bgSurface, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  'Start Navigation',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.bgSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Status action button ───────────────────────────────
                if (_status == 'ASSIGNED' || _status == 'IN_TRANSIT')
                  GestureDetector(
                    onTap: _updating ? null : _advance,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _updating
                            ? p.textMuted
                            : const Color(0xFF1E9E47),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _updating
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF1E9E47)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 26,
                                  offset: const Offset(0, 12),
                                  spreadRadius: -10,
                                ),
                              ],
                      ),
                      child: Center(
                        child: _updating
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _status == 'ASSIGNED'
                                        ? Icons.two_wheeler_rounded
                                        : Icons.camera_alt_rounded,
                                    color: Colors.white, size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _status == 'ASSIGNED'
                                        ? 'Start delivery'
                                        : 'Confirm delivery',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                if (_status == 'DELIVERED' || _status == 'COMPLETED')
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F8EE)
                          .withValues(alpha: isDark ? 0.18 : 1.0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1E9E47), size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Delivery complete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E9E47),
                          ),
                        ),
                      ],
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

class _StatusPills extends StatelessWidget {
  final int activeIndex;
  const _StatusPills({required this.activeIndex});

  static const _stages = ['Accepted', 'Picked up', 'On the way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return Row(
      children: List.generate(_stages.length, (i) {
        final done = i <= activeIndex;
        final active = i == activeIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: done ? const Color(0xFF1E9E47) : p.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _stages[i],
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: done ? const Color(0xFF1E9E47) : p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < _stages.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: p.textMuted,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    return Row(
      children: [
        Expanded(
            child:
                Text(label, style: TextStyle(fontSize: 13, color: p.textSecondary))),
        Text(value, style: TextStyle(fontSize: 13, color: p.textSecondary)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Icon(icon, color: fg, size: 18)),
        ),
      );
}
