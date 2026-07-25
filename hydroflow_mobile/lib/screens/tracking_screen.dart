import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});
  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _timer;
  Map<String, dynamic>? _tracking;
  bool _pollError = false;
  late final MapController _mapController;
  bool _mapReady = false;
  bool _initialFitDone = false;

  // Road-routing state
  List<LatLng> _routePoints = const [];
  double? _routeDistanceMeters;
  int? _routeDurationSecs;
  bool _routeFallback = false;
  bool _routeLoading = false;
  LatLng? _lastRouteOrigin;
  LatLng? _cachedDeliveryLatLng;

  // Nairobi CBD as default center before GPS data arrives
  static const LatLng _defaultCenter = LatLng(-1.286389, 36.817223);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  bool get _isTerminal {
    final st = _tracking?['status']?.toString();
    return st == 'DELIVERED' || st == 'COMPLETED' || st == 'CANCELLED';
  }

  Future<void> _poll() async {
    final res = await ApiService.getOrderTracking(widget.orderId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _tracking = res['tracking'] as Map<String, dynamic>?;
        _pollError = false;
      });
      _fitCamera();
      // Stop polling once the order reaches a terminal state
      if (_isTerminal) {
        _timer?.cancel();
        _timer = null;
      }
      _maybeUpdateRoute(); // fire-and-forget road route refresh
    } else if (_tracking == null) {
      // Only surface an error if we have never gotten data yet
      setState(() => _pollError = true);
    }
  }

  void _fitCamera() {
    if (!_mapReady || _initialFitDone) return;
    final dLat = _driverLat;
    final dLng = _driverLng;
    if (dLat == null || dLng == null) return;

    _initialFitDone = true;
    final delLat = _deliveryLat;
    final delLng = _deliveryLng;

    if (delLat != null && delLng != null) {
      final bounds = LatLngBounds.fromPoints([
        LatLng(dLat, dLng),
        LatLng(delLat, delLng),
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 340),
        ),
      );
    } else {
      _mapController.move(LatLng(dLat, dLng), 15.0);
    }
  }

  // ── Road routing ─────────────────────────────────────────────────────────

  void _maybeUpdateRoute() {
    final dLat = _driverLat;
    final dLng = _driverLng;
    if (dLat == null || dLng == null || _routeLoading) return;
    final driverPos = LatLng(dLat, dLng);
    if (!RoutingService.movedEnough(_lastRouteOrigin, driverPos)) return;
    _fetchRoute(driverPos);
  }

  Future<void> _fetchRoute(LatLng driverPos) async {
    setState(() => _routeLoading = true);

    // Resolve delivery LatLng: prefer explicit coords, else geocode address
    LatLng? dest = _cachedDeliveryLatLng;
    if (dest == null) {
      final rawLat = _deliveryLat;
      final rawLng = _deliveryLng;
      if (rawLat != null && rawLng != null) {
        dest = LatLng(rawLat, rawLng);
        _cachedDeliveryLatLng = dest;
      } else {
        final addr = _tracking?['delivery_address']?.toString() ?? '';
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

  // ── data accessors ────────────────────────────────────────────────────────

  Map<String, dynamic>? get _driver =>
      _tracking?['driver'] as Map<String, dynamic>?;

  String get _driverName => _driver?['name']?.toString() ?? 'Assigning driver…';

  String get _driverRating {
    final r = _driver?['rating'];
    if (r == null) return '—';
    return double.tryParse(r.toString())?.toStringAsFixed(1) ?? '—';
  }

  String get _driverVehicle {
    final info = _driver?['vehicle_info']?.toString();
    final plate = _driver?['vehicle_plate']?.toString();
    if (info != null && info.isNotEmpty) return info;
    if (plate != null && plate.isNotEmpty && plate != 'TBD') return plate;
    return '—';
  }

  String get _orderStatus => _tracking?['status']?.toString() ?? 'PENDING';

  double? get _driverLat {
    final v = _driver?['current_lat'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _driverLng {
    final v = _driver?['current_lng'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _deliveryLat {
    final v = _tracking?['delivery_lat'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _deliveryLng {
    final v = _tracking?['delivery_lng'];
    return v == null ? null : double.tryParse(v.toString());
  }

  double? get _distanceKm {
    final dLat = _driverLat;
    final dLng = _driverLng;
    final delLat = _deliveryLat;
    final delLng = _deliveryLng;
    if (dLat == null || dLng == null || delLat == null || delLng == null) {
      return null;
    }
    return _haversine(dLat, dLng, delLat, delLng);
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
    if (mins < 60) return '$mins min${mins == 1 ? '' : 's'}';
    return '${mins ~/ 60} hr ${mins % 60 == 0 ? '' : '${mins % 60} min'}';
  }

  // Road-based display values (fall back to Haversine when route not loaded)
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

  String get _statusLabel {
    switch (_orderStatus) {
      case 'PENDING': return 'Finding driver…';
      case 'ASSIGNED': return 'Driver assigned';
      case 'IN_TRANSIT': return 'On the way';
      case 'DELIVERED': return 'Delivered!';
      case 'COMPLETED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      default: return 'Processing…';
    }
  }

  Color get _statusDot {
    switch (_orderStatus) {
      case 'IN_TRANSIT': return const Color(0xFF2DC653);
      case 'DELIVERED':
      case 'COMPLETED': return const Color(0xFF2DC653);
      case 'CANCELLED': return const Color(0xFFE63946);
      default: return const Color(0xFFF4A261);
    }
  }

  List<Map<String, dynamic>> get _statusNodes {
    final st = _orderStatus;
    final isAssigned = ['ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'COMPLETED'].contains(st);
    final isInTransit = ['IN_TRANSIT', 'DELIVERED', 'COMPLETED'].contains(st);
    final isDelivered = ['DELIVERED', 'COMPLETED'].contains(st);
    final etaSub = _routeDurationSecs != null
        ? 'Arriving in ${RoutingService.formatDuration(_routeDurationSecs!)}'
        : (_distanceKm != null ? 'Est. $_etaText away' : 'Est. arrival soon');
    return [
      {'label': 'Order placed', 'sub': 'Confirmed', 'done': true, 'active': false, 'isLast': false},
      {'label': 'Picked up from depot', 'sub': isAssigned ? 'Driver assigned' : 'Waiting for driver', 'done': isAssigned, 'active': isAssigned && !isInTransit, 'isLast': false},
      {'label': 'On the way', 'sub': isInTransit ? 'Heading to you now · $_roadDistanceText' : '—', 'done': isInTransit, 'active': isInTransit && !isDelivered, 'isLast': false},
      {'label': 'Delivered', 'sub': isDelivered ? 'Completed ✓' : etaSub, 'done': isDelivered, 'active': false, 'isLast': true},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final driverLat = _driverLat;
    final driverLng = _driverLng;
    final deliveryLat = _deliveryLat;
    final deliveryLng = _deliveryLng;
    final km = _distanceKm;

    // Build markers
    final markers = <Marker>[];
    if (driverLat != null && driverLng != null) {
      markers.add(Marker(
        point: LatLng(driverLat, driverLng),
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0077B6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0077B6).withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.local_shipping_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ));
    }
    if (deliveryLat != null && deliveryLng != null) {
      markers.add(Marker(
        point: LatLng(deliveryLat, deliveryLng),
        width: 44,
        height: 52,
        alignment: const Alignment(0, -1),
        child: const Icon(Icons.location_on_rounded,
            color: Color(0xFFE63946), size: 44),
      ));
    }

    // Route line — use OSRM road polyline if available, else straight line
    final polylines = <Polyline>[];
    if (_routePoints.length >= 2) {
      polylines.add(Polyline(
        points: _routePoints,
        color: _routeFallback
            ? const Color(0xFF0077B6).withValues(alpha: 0.45)
            : const Color(0xFF0077B6),
        strokeWidth: _routeFallback ? 3.0 : 5.0,
      ));
    } else if (driverLat != null && driverLng != null &&
        deliveryLat != null && deliveryLng != null) {
      // Show a faint straight line while OSRM route is loading
      polylines.add(Polyline(
        points: [
          LatLng(driverLat, driverLng),
          LatLng(deliveryLat, deliveryLng),
        ],
        color: const Color(0xFF0077B6).withValues(alpha: 0.30),
        strokeWidth: 3.0,
      ));
    }

    return Scaffold(
      backgroundColor: isDark ? p.bgPage : const Color(0xFFE8EEF2),
      body: Stack(
        children: [
          // ── Real map ────────────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13.0,
                onMapReady: () {
                  setState(() => _mapReady = true);
                  _fitCamera();
                },
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
                if (polylines.isNotEmpty)
                  PolylineLayer(polylines: polylines),
                if (markers.isNotEmpty)
                  MarkerLayer(markers: markers),
              ],
            ),
          ),

          // ── Loading / error overlay when no data yet ───────────────────
          if (_tracking == null)
            Positioned.fill(
              child: Container(
                color: p.bgPage.withValues(alpha: 0.75),
                child: Center(
                  child: _pollError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.signal_wifi_off_rounded,
                                size: 40, color: p.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load tracking data',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: p.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check your connection and try again',
                              style: TextStyle(
                                  fontSize: 12, color: p.textMuted),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () {
                                setState(() => _pollError = false);
                                _poll();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0077B6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Retry',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        )
                      : CircularProgressIndicator(
                          color: const Color(0xFF0077B6),
                          backgroundColor: p.border,
                          strokeWidth: 2.5,
                        ),
                ),
              ),
            ),

          // ── Back button ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: p.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.45 : 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.arrow_back_rounded,
                      size: 19, color: p.textPrimary),
                ),
              ),
            ),
          ),

          // ── Status chip ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: p.textPrimary,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _statusDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.bgSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Distance + ETA card (hidden once delivered) ────────────────
          if ((km != null || _routeDurationSecs != null) && !_isTerminal)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: p.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _roadDistanceText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0077B6),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_routeLoading && _routePoints.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF0077B6),
                              ),
                            ),
                          ),
                        Text(
                          _roadEtaText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Recenter button (hidden once delivered) ─────────────────────
          if (driverLat != null && driverLng != null && !_isTerminal)
            Positioned(
              bottom: 300,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  if (deliveryLat != null && deliveryLng != null) {
                    final bounds = LatLngBounds.fromPoints([
                      LatLng(driverLat, driverLng!),
                      LatLng(deliveryLat, deliveryLng),
                    ]);
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.fromLTRB(60, 80, 60, 320),
                      ),
                    );
                  } else {
                    _mapController.move(
                        LatLng(driverLat, driverLng!), 15.0);
                  }
                },
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: p.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.4 : 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.my_location_rounded,
                        size: 20, color: const Color(0xFF0077B6)),
                  ),
                ),
              ),
            ),

          // ── Bottom sheet ────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: p.bgSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Driver info row
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Color(0xFF48CAE4),
                                  Color(0xFF0077B6)
                                ]),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _driverName.isNotEmpty
                                      ? _driverName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
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
                                    _driverName,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 13,
                                          color: Color(0xFFF4A261)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _driverRating,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        ' · $_driverVehicle',
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
                            _ActionBtn(
                              icon: Icons.phone_rounded,
                              bg: const Color(0xFFE9F8EE),
                              fg: const Color(0xFF2DC653),
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            _ActionBtn(
                              icon: Icons.chat_bubble_rounded,
                              bg: const Color(0xFFE6F6FC),
                              fg: const Color(0xFF0077B6),
                              onTap: () {},
                            ),
                          ],
                        ),
                        // ── Arriving in X mins (road ETA) ─────────────
                        if (_orderStatus == 'IN_TRANSIT' &&
                            _routeDurationSecs != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 14, color: Color(0xFF0077B6)),
                              const SizedBox(width: 6),
                              Text(
                                'Arriving in ${RoutingService.formatDuration(_routeDurationSecs!)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0077B6),
                                ),
                              ),
                              if (_routeFallback) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '(est.)',
                                  style: TextStyle(
                                      fontSize: 11, color: p.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: p.border, height: 1),
                        ),
                        // Status timeline
                        ..._statusNodes.map((n) => _StatusNode(
                              label: n['label']! as String,
                              sub: n['sub']! as String,
                              done: n['done'] as bool,
                              active: n['active'] as bool,
                              isLast: n['isLast'] as bool,
                            )),
                        // ── Delivered / Cancelled banner + Done button ───
                        if (_isTerminal) ...[
                          const SizedBox(height: 16),
                          Builder(builder: (context) {
                            final isCancelled = _orderStatus == 'CANCELLED';
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isCancelled
                                    ? const Color(0xFFfbeaec)
                                    : const Color(0xFFE9F8EE),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: isCancelled
                                          ? const Color(0xFFE63946)
                                          : const Color(0xFF2DC653),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCancelled
                                          ? Icons.close_rounded
                                          : Icons.check_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCancelled
                                              ? 'Order cancelled'
                                              : 'Order delivered!',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isCancelled
                                                ? const Color(0xFFE63946)
                                                : const Color(0xFF1E9E47),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isCancelled
                                              ? 'This order was cancelled.'
                                              : 'Your water has been delivered.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isCancelled
                                                ? const Color(0xFFE63946)
                                                    .withValues(alpha: 0.75)
                                                : const Color(0xFF2DC653)
                                                    .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0077B6),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Back to My Orders',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: bg.withValues(alpha: isDark ? 0.18 : 1.0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(child: Icon(icon, color: fg, size: 20)),
      ),
    );
  }
}

class _StatusNode extends StatelessWidget {
  final String label;
  final String sub;
  final bool done;
  final bool active;
  final bool isLast;
  const _StatusNode({
    required this.label,
    required this.sub,
    required this.done,
    required this.active,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    const blue = Color(0xFF0077B6);
    final grey = p.border;
    final dotColor = (done || active) ? blue : grey;
    final lineColor = done ? blue : grey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: blue.withValues(alpha: 0.4),
                          blurRadius: 0,
                          spreadRadius: 4,
                        )
                      ]
                    : null,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: lineColor),
          ],
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w600,
                    color: (done || active) ? p.textPrimary : p.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: active ? blue : p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
