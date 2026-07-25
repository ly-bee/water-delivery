import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await ApiService.loadSaved();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(HydroFlowApp(themeProvider: themeProvider));
}

class HydroFlowApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const HydroFlowApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, tp, __) => MaterialApp(
          title: 'HydroFlow',
          debugShowCheckedModeBanner: false,
          theme:     Aq.lightTheme(),
          darkTheme: Aq.darkTheme(),
          themeMode: tp.mode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
