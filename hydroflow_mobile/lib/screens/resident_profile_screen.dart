import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'launcher_screen.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});
  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  Map<String, dynamic>? _user;
  bool _notif = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _user = ApiService.getUser();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final res = await ApiService.getMe();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (res['success'] == true && res['user'] != null) {
        _user = res['user'] as Map<String, dynamic>;
      }
    });
  }

  String get _name => _user?['name']?.toString() ?? 'You';
  String get _phone {
    final raw = _user?['phone']?.toString() ?? '';
    if (raw.startsWith('0')) return '+254${raw.substring(1)}';
    if (raw.length == 9) return '+254$raw';
    return raw.isNotEmpty ? raw : '—';
  }

  String? get _email {
    final e = _user?['email']?.toString();
    return (e == null || e.isEmpty) ? null : e;
  }

  String get _initials {
    final parts = _name.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U';
  }

  String get _memberSince {
    final raw = _user?['created_at']?.toString();
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  bool get _emailMissing => _email == null;

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LauncherScreen()),
      (_) => false,
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: _user ?? {},
        isDriver: false,
        onSaved: (updated) => setState(() => _user = {...?_user, ...updated}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: p.bgPage,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: p.primary,
        backgroundColor: p.bgSurface,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHeader(
                initials: _initials,
                name: _name,
                sub: _phone,
                badge: 'Resident',
                badgeColor: p.primary,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0077B6), Color(0xFF0353A0)],
                ),
                isDark: isDark,
                onEdit: _showEditSheet,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Incomplete profile banner ────────────────────────
                  if (_emailMissing)
                    _IncompleteBanner(
                      message: 'Add your email to secure your account and receive order updates.',
                      onTap: _showEditSheet,
                      p: p,
                    ),
                  if (_emailMissing) const SizedBox(height: 16),

                  // ── Account info ─────────────────────────────────────
                  _SectionLabel('Account', p: p),
                  const SizedBox(height: 8),
                  _InfoCard(p: p, isDark: isDark, rows: [
                    _InfoRow(
                      icon: Icons.person_rounded,
                      iconBg: const Color(0xFFE6F6FC),
                      iconFg: const Color(0xFF0077B6),
                      label: 'Name',
                      value: _name,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF2DC653),
                      label: 'Phone',
                      value: _phone,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.email_rounded,
                      iconBg: _emailMissing ? const Color(0xFFFEF3E7) : const Color(0xFFE6F6FC),
                      iconFg: _emailMissing ? const Color(0xFFC9742B) : const Color(0xFF0077B6),
                      label: 'Email',
                      value: _email ?? 'Not added yet',
                      valueMuted: _emailMissing,
                      action: _emailMissing ? 'Add' : 'Change',
                      onAction: _showEditSheet,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'Member since',
                      value: _memberSince,
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Payment ──────────────────────────────────────────
                  _SectionLabel('Payment', p: p),
                  const SizedBox(height: 8),
                  _InfoCard(p: p, isDark: isDark, rows: [
                    _InfoRow(
                      icon: Icons.phone_android_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF2DC653),
                      label: 'M-Pesa',
                      value: _phone,
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Preferences ──────────────────────────────────────
                  _SectionLabel('Preferences', p: p),
                  const SizedBox(height: 8),
                  _SettingsCard(p: p, isDark: isDark, children: [
                    _SettingRow(
                      icon: Icons.notifications_rounded,
                      iconBg: const Color(0xFFFEF6E9),
                      iconFg: const Color(0xFFC9742B),
                      label: 'Notifications',
                      trailing: _Toggle(value: _notif, color: p.primary,
                          onTap: () => setState(() => _notif = !_notif)),
                      p: p,
                    ),
                    _AppearanceTile(p: p, isDark: isDark),
                  ]),
                  const SizedBox(height: 12),

                  // ── More ─────────────────────────────────────────────
                  _SettingsCard(p: p, isDark: isDark, children: [
                    _SettingRow(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'Help & Support',
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textMuted),
                      p: p,
                    ),
                    _SettingRow(
                      icon: Icons.star_border_rounded,
                      iconBg: const Color(0xFFFEF6E9),
                      iconFg: const Color(0xFFC9742B),
                      label: 'Rate HydroFlow',
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textMuted),
                      p: p,
                    ),
                    _SettingRow(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'App version',
                      trailing: Text('1.0.0',
                          style: TextStyle(fontSize: 12, color: p.textMuted)),
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Logout ───────────────────────────────────────────
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: p.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF4A2030)
                                : const Color(0xFFf2dadd)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded,
                              color: Color(0xFFE63946), size: 18),
                          const SizedBox(width: 9),
                          Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE63946),
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
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Driver profile screen
// ────────────────────────────────────────────────────────────────────────────

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _earnings;
  bool _notif = true;
  bool _togglingOnline = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _user = ApiService.getUser();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final results = await Future.wait([
      ApiService.getMe(),
      ApiService.getDriverEarnings(),
    ]);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      final userRes = results[0];
      if (userRes['success'] == true && userRes['user'] != null) {
        _user = userRes['user'] as Map<String, dynamic>;
      }
      final earningsRes = results[1];
      if (earningsRes['success'] == true) {
        _earnings = earningsRes['summary'] as Map<String, dynamic>?;
      }
    });
  }

  String get _name => _user?['name']?.toString() ?? 'Driver';
  String get _phone {
    final raw = _user?['phone']?.toString() ?? '';
    if (raw.startsWith('0')) return '+254${raw.substring(1)}';
    if (raw.length == 9) return '+254$raw';
    return raw.isNotEmpty ? raw : '—';
  }

  String? get _email {
    final e = _user?['email']?.toString();
    return (e == null || e.isEmpty) ? null : e;
  }

  String get _initials {
    final parts = _name.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : 'D';
  }

  String get _vehiclePlate {
    final p = _user?['vehicle_plate']?.toString() ?? '';
    return (p.isEmpty || p == 'TBD') ? 'Not set' : p;
  }

  String get _vehicleInfo {
    final v = _user?['vehicle_info']?.toString() ?? '';
    return v.isEmpty ? 'Not set' : v;
  }

  String get _memberSince {
    final raw = _user?['created_at']?.toString();
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return '—'; }
  }

  double get _rating {
    final r = _user?['driver_rating'];
    return double.tryParse(r?.toString() ?? '0') ?? 0.0;
  }

  bool get _isOnline =>
      (_user?['driver_status']?.toString() ?? 'offline') != 'offline';

  bool get _emailMissing => _email == null;
  bool get _vehicleMissing =>
      _vehiclePlate == 'Not set' || _vehicleInfo == 'Not set';

  Future<void> _toggleOnline() async {
    if (_togglingOnline) return;
    setState(() => _togglingOnline = true);
    final next = !_isOnline;
    final res = await ApiService.setDriverOnline(next);
    if (!mounted) return;
    setState(() {
      _togglingOnline = false;
      if (res['success'] == true) {
        _user = {...?_user, 'driver_status': next ? 'available' : 'offline'};
      }
    });
    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Cannot change status'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LauncherScreen()),
      (_) => false,
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: _user ?? {},
        isDriver: true,
        onSaved: (updated) => setState(() => _user = {...?_user, ...updated}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Earnings data
    final todayEarnings = _earnings?['today'] as num? ?? 0;
    final weekEarnings  = _earnings?['this_week'] as num? ?? 0;
    final totalDeliveries = _earnings?['total_deliveries'] as num? ?? 0;

    return Scaffold(
      backgroundColor: p.bgPage,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF1E9E47),
        backgroundColor: p.bgSurface,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHeader(
                initials: _initials,
                name: _name,
                sub: _rating > 0
                    ? '★ ${_rating.toStringAsFixed(1)}  ·  $_phone'
                    : _phone,
                badge: _isOnline ? 'Online' : 'Offline',
                badgeColor: _isOnline
                    ? const Color(0xFF1E9E47)
                    : const Color(0xFF8A888B),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E9E47), Color(0xFF157A35)],
                ),
                isDark: isDark,
                onEdit: _showEditSheet,
                extraWidget: GestureDetector(
                  onTap: _togglingOnline ? null : _toggleOnline,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isOnline
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1),
                    ),
                    child: _togglingOnline
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isOnline
                                      ? const Color(0xFF7EE8A0)
                                      : Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _isOnline ? 'Go offline' : 'Go online',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Incomplete profile banner ────────────────────────
                  if (_emailMissing || _vehicleMissing)
                    _IncompleteBanner(
                      message: _emailMissing
                          ? 'Add your email and vehicle details to complete your profile.'
                          : 'Add your vehicle details to start receiving deliveries.',
                      onTap: _showEditSheet,
                      p: p,
                      color: const Color(0xFF1E9E47),
                    ),
                  if (_emailMissing || _vehicleMissing) const SizedBox(height: 16),

                  // ── Earnings snapshot ─────────────────────────────────
                  _EarningsSnapshot(
                    today: todayEarnings.toDouble(),
                    week: weekEarnings.toDouble(),
                    deliveries: totalDeliveries.toInt(),
                    p: p,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // ── Account info ──────────────────────────────────────
                  _SectionLabel('Account', p: p),
                  const SizedBox(height: 8),
                  _InfoCard(p: p, isDark: isDark, rows: [
                    _InfoRow(
                      icon: Icons.person_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF1E9E47),
                      label: 'Name',
                      value: _name,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF2DC653),
                      label: 'Phone',
                      value: _phone,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.email_rounded,
                      iconBg: _emailMissing ? const Color(0xFFFEF3E7) : const Color(0xFFE9F8EE),
                      iconFg: _emailMissing ? const Color(0xFFC9742B) : const Color(0xFF1E9E47),
                      label: 'Email',
                      value: _email ?? 'Not added yet',
                      valueMuted: _emailMissing,
                      action: _emailMissing ? 'Add' : 'Change',
                      onAction: _showEditSheet,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'Member since',
                      value: _memberSince,
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Vehicle ──────────────────────────────────────────
                  _SectionLabel('Vehicle', p: p),
                  const SizedBox(height: 8),
                  _InfoCard(p: p, isDark: isDark, rows: [
                    _InfoRow(
                      icon: Icons.local_shipping_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF1E9E47),
                      label: 'Description',
                      value: _vehicleInfo,
                      valueMuted: _vehicleInfo == 'Not set',
                      action: 'Edit',
                      onAction: _showEditSheet,
                      p: p,
                    ),
                    _InfoRow(
                      icon: Icons.pin_rounded,
                      iconBg: const Color(0xFFE9F8EE),
                      iconFg: const Color(0xFF1E9E47),
                      label: 'Plate',
                      value: _vehiclePlate,
                      valueMuted: _vehiclePlate == 'Not set',
                      action: 'Edit',
                      onAction: _showEditSheet,
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Preferences ──────────────────────────────────────
                  _SectionLabel('Preferences', p: p),
                  const SizedBox(height: 8),
                  _SettingsCard(p: p, isDark: isDark, children: [
                    _SettingRow(
                      icon: Icons.notifications_rounded,
                      iconBg: const Color(0xFFFEF6E9),
                      iconFg: const Color(0xFFC9742B),
                      label: 'Notifications',
                      trailing: _Toggle(
                          value: _notif,
                          color: const Color(0xFF1E9E47),
                          onTap: () => setState(() => _notif = !_notif)),
                      p: p,
                    ),
                    _AppearanceTile(p: p, isDark: isDark),
                  ]),
                  const SizedBox(height: 12),

                  _SettingsCard(p: p, isDark: isDark, children: [
                    _SettingRow(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'Help & Support',
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: p.textMuted),
                      p: p,
                    ),
                    _SettingRow(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFFEEF1F4),
                      iconFg: const Color(0xFF6b7785),
                      label: 'App version',
                      trailing: Text('1.0.0',
                          style: TextStyle(fontSize: 12, color: p.textMuted)),
                      isLast: true,
                      p: p,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Logout ───────────────────────────────────────────
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: p.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF4A2030)
                                : const Color(0xFFf2dadd)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Color(0xFFE63946), size: 18),
                          SizedBox(width: 9),
                          Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE63946),
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
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ════════════════════════════════════════════════════════════════════════════

// ── Profile header ───────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String sub;
  final String badge;
  final Color badgeColor;
  final LinearGradient gradient;
  final bool isDark;
  final VoidCallback onEdit;
  final Widget? extraWidget;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.sub,
    required this.badge,
    required this.badgeColor,
    required this.gradient,
    required this.isDark,
    required this.onEdit,
    this.extraWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Top row — edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Edit profile',
                        style: TextStyle(
                          fontSize: 12.5,
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
          const SizedBox(height: 10),

          // Avatar
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45), width: 2.5),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),

          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),

          // Sub (phone / rating)
          Text(
            sub,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),

          // Role / status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // Optional extra widget (e.g. online toggle for driver)
          if (extraWidget != null) ...[
            const SizedBox(height: 10),
            extraWidget!,
          ],
        ],
      ),
    );
  }
}

// ── Incomplete profile banner ────────────────────────────────────────────────
class _IncompleteBanner extends StatelessWidget {
  final String message;
  final VoidCallback onTap;
  final AqPalette p;
  final Color color;

  const _IncompleteBanner({
    required this.message,
    required this.onTap,
    required this.p,
    this.color = const Color(0xFF0077B6),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Icon(Icons.person_add_rounded, color: color, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your profile',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(fontSize: 12, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Earnings snapshot (driver only) ─────────────────────────────────────────
class _EarningsSnapshot extends StatelessWidget {
  final double today;
  final double week;
  final int deliveries;
  final AqPalette p;
  final bool isDark;

  const _EarningsSnapshot({
    required this.today,
    required this.week,
    required this.deliveries,
    required this.p,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E9E47), Color(0xFF157A35)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E9E47).withValues(alpha: isDark ? 0.2 : 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          _EarningsStat(
              label: "Today", value: 'KSh ${today.toStringAsFixed(0)}'),
          _divider(),
          _EarningsStat(
              label: 'This week', value: 'KSh ${week.toStringAsFixed(0)}'),
          _divider(),
          _EarningsStat(
              label: 'Deliveries', value: '$deliveries'),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1, height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _EarningsStat extends StatelessWidget {
  final String label;
  final String value;
  const _EarningsStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final AqPalette p;
  const _SectionLabel(this.text, {required this.p});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: p.textMuted,
          letterSpacing: 0.8,
        ),
      );
}

// ── Info card (account info rows) ────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final AqPalette p;
  final bool isDark;
  final List<Widget> rows;
  const _InfoCard({required this.p, required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: p.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: rows),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;
  final bool valueMuted;
  final String? action;
  final VoidCallback? onAction;
  final bool isLast;
  final AqPalette p;

  const _InfoRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.value,
    this.valueMuted = false,
    this.action,
    this.onAction,
    this.isLast = false,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: p.border.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconBg.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 1.0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Icon(icon, color: iconFg, size: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: p.textMuted,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueMuted ? p.textMuted : p.textPrimary,
                    fontStyle:
                        valueMuted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: iconFg.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.15
                          : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  action!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: iconFg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final AqPalette p;
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard(
      {required this.p, required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: p.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      );
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final Widget? trailing;
  final bool isLast;
  final AqPalette p;

  const _SettingRow({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.p,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: p.border.withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconBg.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.18
                        : 1.0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(icon, color: iconFg, size: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  )),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Appearance tile with 3-way theme picker ──────────────────────────────────
class _AppearanceTile extends StatelessWidget {
  final AqPalette p;
  final bool isDark;
  const _AppearanceTile({required this.p, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, tp, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF444466) : const Color(0xFFEEF1F4))
                    .withValues(
                        alpha: isDark ? 0.5 : 1.0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                tp.isDark
                    ? Icons.dark_mode_rounded
                    : tp.isLight
                        ? Icons.light_mode_rounded
                        : Icons.brightness_auto_rounded,
                color: isDark ? const Color(0xFFB0B8D8) : const Color(0xFF6b7785),
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Appearance',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  )),
            ),
            // 3-way pill switcher
            Container(
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: p.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemePill(
                      label: '☀️',
                      selected: tp.isLight,
                      onTap: () => tp.setMode(ThemeMode.light),
                      p: p),
                  _ThemePill(
                      label: '⚙️',
                      selected: tp.isSystem,
                      onTap: () => tp.setMode(ThemeMode.system),
                      p: p),
                  _ThemePill(
                      label: '🌙',
                      selected: tp.isDark,
                      onTap: () => tp.setMode(ThemeMode.dark),
                      p: p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AqPalette p;
  const _ThemePill(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.p});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 28,
          decoration: BoxDecoration(
            color: selected ? p.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
        ),
      );
}

// ── Toggle switch ─────────────────────────────────────────────────────────────
class _Toggle extends StatelessWidget {
  final bool value;
  final Color color;
  final VoidCallback onTap;
  const _Toggle({required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48, height: 28,
          decoration: BoxDecoration(
            color: value ? color : const Color(0xFFcdd6df),
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                width: 23, height: 23,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Edit profile bottom sheet ─────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDriver;
  final Function(Map<String, dynamic>) onSaved;

  const _EditProfileSheet({
    required this.user,
    required this.isDriver,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _vehicleInfoCtrl;
  late TextEditingController _vehiclePlateCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.user['name']?.toString() ?? '');
    _emailCtrl = TextEditingController(
        text: widget.user['email']?.toString() ?? '');
    _vehicleInfoCtrl = TextEditingController(
        text: widget.user['vehicle_info']?.toString() ?? '');
    final plate = widget.user['vehicle_plate']?.toString() ?? '';
    _vehiclePlateCtrl = TextEditingController(
        text: plate == 'TBD' ? '' : plate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleInfoCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final res = await ApiService.updateProfile(
      name: name,
      email: email.isNotEmpty ? email : null,
      vehicleInfo: widget.isDriver && _vehicleInfoCtrl.text.trim().isNotEmpty
          ? _vehicleInfoCtrl.text.trim()
          : null,
      vehiclePlate: widget.isDriver && _vehiclePlateCtrl.text.trim().isNotEmpty
          ? _vehiclePlateCtrl.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      widget.onSaved(res['user'] as Map<String, dynamic>? ?? {});
      Navigator.pop(context);
    } else {
      setState(() => _error = res['message'] ?? 'Failed to save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Aq.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.isDriver
        ? const Color(0xFF1E9E47)
        : const Color(0xFF0077B6);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: isDark ? HfColors.darkElev : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title + avatar
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isDriver
                          ? [const Color(0xFF1E9E47), const Color(0xFF157A35)]
                          : [const Color(0xFF0077B6), const Color(0xFF0353A0)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _nameCtrl.text.trim().isNotEmpty
                          ? _nameCtrl.text.trim()[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Changes save to your account',
                        style: TextStyle(
                            fontSize: 12.5, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF4A1520)
                      : const Color(0xFFfbeaec),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF7A2535)
                          : const Color(0xFFf2dadd)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE63946), size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFE63946), fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Name field
            _Field(
              label: 'Full name',
              controller: _nameCtrl,
              hint: 'e.g. James Mwangi',
              icon: Icons.person_rounded,
              accentColor: accentColor,
              p: p,
              isDark: isDark,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Email field
            _Field(
              label: 'Email address',
              controller: _emailCtrl,
              hint: 'e.g. james@example.com',
              icon: Icons.email_rounded,
              accentColor: accentColor,
              keyboardType: TextInputType.emailAddress,
              p: p,
              isDark: isDark,
            ),

            // Driver-only fields
            if (widget.isDriver) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Vehicle details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _Field(
                label: 'Vehicle description',
                controller: _vehicleInfoCtrl,
                hint: 'e.g. White Toyota Pickup',
                icon: Icons.local_shipping_rounded,
                accentColor: accentColor,
                p: p,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Plate number',
                controller: _vehiclePlateCtrl,
                hint: 'e.g. KCA 123X',
                icon: Icons.pin_rounded,
                accentColor: accentColor,
                textCapitalization: TextCapitalization.characters,
                p: p,
                isDark: isDark,
              ),
            ],

            const SizedBox(height: 28),

            // Save button
            GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 54,
                decoration: BoxDecoration(
                  color: _saving ? p.textMuted : accentColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _saving
                      ? null
                      : [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.45),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                            spreadRadius: -8,
                          )
                        ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Save changes',
                              style: TextStyle(
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
          ],
        ),
      ),
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final AqPalette p;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.p,
    required this.isDark,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? HfColors.darkBg : const Color(0xFFFAFBFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border, width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        TextStyle(fontSize: 14, color: p.textMuted, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }
}
