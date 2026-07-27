import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});
  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  int _periodTab = 0; // 0=Week, 1=Month, 2=All time

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

  List<dynamic> get _completed =>
      _orders.where((o) => ['DELIVERED', 'COMPLETED'].contains(o['status'])).toList();

  List<dynamic> get _filtered {
    final now = DateTime.now();
    return _completed.where((o) {
      try {
        final d = DateTime.parse(o['created_at'].toString()).toLocal();
        if (_periodTab == 0) {
          final start = now.subtract(Duration(days: now.weekday - 1));
          return d.isAfter(DateTime(start.year, start.month, start.day));
        }
        if (_periodTab == 1) {
          return d.month == now.month && d.year == now.year;
        }
        return true;
      } catch (_) { return _periodTab == 2; }
    }).toList();
  }

  double get _total =>
      _filtered.fold(0.0, (s, o) => s + (double.tryParse(o['delivery_fee'].toString()) ?? 0));

  List<double> get _weekBars {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return _completed.where((o) {
        try {
          final d = DateTime.parse(o['created_at'].toString()).toLocal();
          return d.day == day.day && d.month == day.month && d.year == day.year;
        } catch (_) { return false; }
      }).fold(0.0, (s, o) => s + (double.tryParse(o['delivery_fee'].toString()) ?? 0));
    });
  }

  String _dayLabel(int i) {
    const days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final now = DateTime.now();
    final day = now.subtract(Duration(days: 6 - i));
    return days[day.weekday - 1];
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Recent';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${m[dt.month-1]} · $h:$mi';
    } catch (_) { return 'Recent'; }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bars = _weekBars;
    final maxBar = bars.fold<double>(1, (m, v) => v > m ? v : m);

    return Scaffold(
      backgroundColor: p.bgPage,
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF2DC653),
        backgroundColor: p.bgSurface,
        child: CustomScrollView(
          slivers: [
            // Header (always green gradient)
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 18, 20, 22),
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
                    const Text(
                      'Earnings',
                      style: TextStyle(fontSize: 13, color: Color(0xFFa8e6bd)),
                    ),
                    const SizedBox(height: 4),
                    _loading
                        ? const Text(
                            'Loading...',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'KSh ${_total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      '${_filtered.length} completed deliver${_filtered.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFa8e6bd)),
                    ),
                    const SizedBox(height: 18),
                    // Period tabs
                    Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: ['Week', 'Month', 'All time']
                            .asMap()
                            .entries
                            .map((e) {
                          final sel = _periodTab == e.key;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _periodTab = e.key),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: sel ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? const Color(0xFF1E9E47)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                  // Bar chart
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
                          'Last 7 days',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 90,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final pct = maxBar > 0 ? bars[i] / maxBar : 0.0;
                              final today = i == 6;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: pct.clamp(0.04, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: today
                                                    ? const Color(0xFF1E9E47)
                                                    : isDark
                                                        ? const Color(0xFF1E9E47).withValues(alpha: 0.3)
                                                        : const Color(0xFFB8E8CB),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(5),
                                                  topRight: Radius.circular(5),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _dayLabel(i),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: today
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: today
                                              ? const Color(0xFF1E9E47)
                                              : p.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payout notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F8EE).withValues(alpha: isDark ? 0.18 : 1.0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFc0e8d0).withValues(alpha: isDark ? 0.3 : 1.0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_rounded,
                            color: Color(0xFF1E9E47), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next payout',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF157A35),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Friday, ${_nextFriday()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E9E47),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'KSh ${_total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF157A35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Transactions header
                  Text(
                    'Completed deliveries',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_loading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: const Color(0xFF1E9E47), strokeWidth: 2),
                      ),
                    )
                  else if (_filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: p.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.wallet_rounded, size: 40, color: p.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            'No earnings yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete deliveries to earn',
                            style: TextStyle(fontSize: 12, color: p.textMuted),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_filtered.length, (i) {
                      final o = _filtered[i];
                      final amount = double.tryParse(o['delivery_fee'].toString()) ?? 0;
                      final id = (o['id'] as String?)
                              ?.substring(0, 8)
                              .toUpperCase() ??
                          '—';
                      final date = _formatDate(o['created_at']?.toString());
                      final vol = '${o['volume_liters'] ?? 20}L';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F8EE)
                                    .withValues(alpha: isDark ? 0.18 : 1.0),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Center(
                                child: Icon(Icons.arrow_downward_rounded,
                                    color: Color(0xFF1E9E47), size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #$id',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$vol · $date',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'KSh ${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E9E47),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextFriday() {
    final now = DateTime.now();
    final days = (5 - now.weekday + 7) % 7;
    final friday = now.add(Duration(days: days == 0 ? 7 : days));
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${friday.day} ${m[friday.month-1]}';
  }
}
