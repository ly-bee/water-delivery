import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── HydroFlow design-system colors ──────────────────────────────────────────
class HfColors {
  static const blue       = Color(0xFF0077B6);
  static const blueDark   = Color(0xFF0353A0);
  static const blueLight  = Color(0xFF00A8D6);
  static const green      = Color(0xFF2DC653);
  static const orange     = Color(0xFFC9742B);
  static const red        = Color(0xFFE63946);
  static const bgPage     = Color(0xFFF4F6F8);
  static const bgSurface  = Color(0xFFFFFFFF);
  static const textPrime  = Color(0xFF1A1A2E);
  static const textSec    = Color(0xFF6b7785);
  static const textMuted  = Color(0xFF9aa6b2);
  static const border     = Color(0xFFeef1f4);

  // Dark mode — charcoal-purple (matches admin web app palette)
  static const darkBg      = Color(0xFF14131A);
  static const darkSurface = Color(0xFF1C1B21);
  static const darkElev    = Color(0xFF2B2A30);
  static const darkBorder  = Color(0xFF3A3840);
  static const darkText    = Color(0xFFFFFFFF);
  static const darkTextSec = Color(0xFF8B8990);
  static const darkTextMut = Color(0xFF5A5860);
}

// ─── Color palette (one per brightness mode) ──────────────────────────────────
class AqPalette {
  final Color bgPage, bgSurface, bgElevated, bgHero;
  final Color border;
  final Color textPrimary, textSecondary, textMuted;
  final Color accentPositive, accentNegative;
  final Color btnBg, btnText;
  final Color primary, primaryDark, primaryLight;

  const AqPalette({
    required this.bgPage,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgHero,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPositive,
    required this.accentNegative,
    required this.btnBg,
    required this.btnText,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
  });
}

// ─── Theme provider ───────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isSystem => _mode == ThemeMode.system;
  bool get isLight  => _mode == ThemeMode.light;
  bool get isDark   => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val   = prefs.getString('aqTheme') ?? 'system';
      _mode = val == 'light' ? ThemeMode.light
            : val == 'dark'  ? ThemeMode.dark
            : ThemeMode.system;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = mode == ThemeMode.light ? 'light'
                  : mode == ThemeMode.dark  ? 'dark'
                  : 'system';
      await prefs.setString('aqTheme', key);
    } catch (_) {}
  }
}

// ─── Aq — design-system access point ─────────────────────────────────────────
class Aq {
  Aq._();

  // ── Light palette ─────────────────────────────────────────────────────────
  static const light = AqPalette(
    bgPage:        HfColors.bgPage,
    bgSurface:     HfColors.bgSurface,
    bgElevated:    Color(0xFFF0F4F8),
    bgHero:        HfColors.blueDark,
    border:        HfColors.border,
    textPrimary:   HfColors.textPrime,
    textSecondary: HfColors.textSec,
    textMuted:     HfColors.textMuted,
    accentPositive: HfColors.green,
    accentNegative: HfColors.red,
    btnBg:         HfColors.blue,
    btnText:       Color(0xFFFFFFFF),
    primary:       HfColors.blue,
    primaryDark:   HfColors.blueDark,
    primaryLight:  HfColors.blueLight,
  );

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const dark = AqPalette(
    bgPage:        HfColors.darkBg,
    bgSurface:     HfColors.darkSurface,
    bgElevated:    HfColors.darkElev,
    bgHero:        HfColors.darkElev,
    border:        HfColors.darkBorder,
    textPrimary:   HfColors.darkText,
    textSecondary: HfColors.darkTextSec,
    textMuted:     HfColors.darkTextMut,
    accentPositive: HfColors.green,
    accentNegative: HfColors.red,
    btnBg:         HfColors.blue,
    btnText:       Color(0xFFFFFFFF),
    primary:       HfColors.blue,
    primaryDark:   HfColors.blueDark,
    primaryLight:  HfColors.blueLight,
  );

  static AqPalette of(BuildContext ctx) =>
    Theme.of(ctx).brightness == Brightness.dark ? dark : light;

  // ── Semantic colors ───────────────────────────────────────────────────────
  static const statusAmber  = Color(0xFFC9742B);
  static const statusBlue   = Color(0xFF0077B6);
  static const statusPurple = Color(0xFF7A5CB8);
  static const statusTeal   = Color(0xFF00A8D6);
  static const statusSage   = Color(0xFF2DC653);
  static const statusGray   = Color(0xFF8A888B);

  static const driverAvailable  = Color(0xFF2DC653);
  static const driverOnDelivery = Color(0xFFC9742B);
  static const driverOffline    = Color(0xFF8A888B);
  static const driverSuspended  = Color(0xFFE63946);

  static const green  = Color(0xFF2DC653);
  static const accent = Color(0xFF00A8D6);
  static const purple = Color(0xFF7A5CB8);
  static const blue   = Color(0xFF0077B6);

  static Color statusColor(String s) {
    switch (s) {
      case 'PENDING':    return statusAmber;
      case 'ASSIGNED':   return statusBlue;
      case 'IN_TRANSIT': return statusPurple;
      case 'DELIVERED':  return statusTeal;
      case 'COMPLETED':  return statusSage;
      case 'CANCELLED':  return const Color(0xFFE63946);
      default:           return statusGray;
    }
  }

  static IconData statusIcon(String s) {
    switch (s) {
      case 'PENDING':    return Icons.schedule_rounded;
      case 'ASSIGNED':   return Icons.person_pin_rounded;
      case 'IN_TRANSIT': return Icons.two_wheeler_rounded;
      case 'DELIVERED':  return Icons.check_circle_outline_rounded;
      case 'COMPLETED':  return Icons.verified_rounded;
      case 'CANCELLED':  return Icons.cancel_outlined;
      default:           return Icons.help_outline_rounded;
    }
  }

  static BoxDecoration cardDecor(
    AqPalette p, {
    double radius = 16,
    Color? borderColor,
    Color? bg,
  }) =>
    BoxDecoration(
      color: bg ?? p.bgSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? p.border),
    );

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [HfColors.blue, HfColors.blueDark],
  );
  static const gradSuccess = LinearGradient(
    begin: Alignment.centerLeft, end: Alignment.centerRight,
    colors: [Color(0xFF2DC653), Color(0xFF1A9E3A)],
  );
  static const gradDanger = LinearGradient(
    begin: Alignment.centerLeft, end: Alignment.centerRight,
    colors: [Color(0xFFE63946), Color(0xFFC0252E)],
  );
  static const gradPurple = LinearGradient(
    begin: Alignment.centerLeft, end: Alignment.centerRight,
    colors: [Color(0xFF7A5CB8), Color(0xFF5A3D98)],
  );
  static const gradHero = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF023E8A), Color(0xFF0077B6)],
  );

  // ── Flutter ThemeData builders ────────────────────────────────────────────
  static ThemeData lightTheme() => _build(light, Brightness.light);
  static ThemeData darkTheme()  => _build(dark,  Brightness.dark);

  static ThemeData _build(AqPalette p, Brightness b) => ThemeData(
    brightness: b,
    scaffoldBackgroundColor: p.bgPage,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme(
      brightness:   b,
      primary:      p.primary,
      onPrimary:    Colors.white,
      secondary:    p.primaryLight,
      onSecondary:  Colors.white,
      surface:      p.bgSurface,
      onSurface:    p.textPrimary,
      error:        p.accentNegative,
      onError:      Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor:  p.bgSurface,
      foregroundColor:  p.textPrimary,
      elevation:        0,
      shadowColor:      Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700,
        color: p.textPrimary, fontFamily: 'Roboto',
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
    ),
    dividerColor: p.border,
    cardColor:    p.bgSurface,
    dialogTheme:  DialogThemeData(backgroundColor: p.bgElevated),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
          ? p.primary.withOpacity(0.3)
          : p.border,
      ),
    ),
  );
}
