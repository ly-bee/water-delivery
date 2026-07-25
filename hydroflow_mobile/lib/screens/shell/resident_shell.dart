import 'package:flutter/material.dart';
import '../home_screen.dart';
import '../my_orders_screen.dart';
import '../resident_profile_screen.dart';
import '../../theme/app_theme.dart';

class ResidentShell extends StatefulWidget {
  const ResidentShell({super.key});
  @override
  State<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends State<ResidentShell> {
  int _index = 0;

  static const List<String> _labels = ['Home', 'Orders', 'Track', 'Profile'];
  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.navigation_rounded,
    Icons.person_rounded,
  ];

  Widget _screen(int i) {
    switch (i) {
      case 0: return const HomeScreen();
      case 1: return const MyOrdersScreen();
      case 2: return const _TrackPlaceholder();
      case 3: return const ResidentProfileScreen();
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                          color: selected ? p.primary : p.textMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? p.primary : p.textMuted,
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

class _TrackPlaceholder extends StatelessWidget {
  const _TrackPlaceholder();

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: p.bgPage,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0077B6).withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Icon(Icons.navigation_rounded,
                    color: Color(0xFF0077B6), size: 34),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No active delivery',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your live tracking will appear here',
              style: TextStyle(fontSize: 13, color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
