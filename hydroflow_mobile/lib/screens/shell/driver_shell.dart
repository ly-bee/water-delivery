import 'package:flutter/material.dart';
import '../driver_orders_screen.dart';
import '../driver_deliveries_screen.dart';
import '../driver_earnings_screen.dart';
import '../driver_profile_screen.dart';
import '../../theme/app_theme.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  static const List<String> _labels = [
    'Dashboard', 'Deliveries', 'Earnings', 'Profile'
  ];
  static const List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.inventory_2_rounded,
    Icons.wallet_rounded,
    Icons.person_rounded,
  ];

  Widget _screen(int i) {
    switch (i) {
      case 0: return const DriverOrdersScreen();
      case 1: return const DriverDeliveriesScreen();
      case 2: return const DriverEarningsScreen();
      case 3: return const DriverProfileScreen();
      default: return const DriverOrdersScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = Color(0xFF1E9E47);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(4, _screen),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.bgSurface,
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0x0A101828),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(4, (i) {
                final selected = _index == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _icons[i],
                          size: 22,
                          color: selected ? activeColor : p.textMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? activeColor : p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
