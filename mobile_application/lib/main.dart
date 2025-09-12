import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const RespirationMonitorApp());
}

class RespirationMonitorApp extends StatelessWidget {
  const RespirationMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
      ],
      child: MaterialApp(
        title: 'Respiration Monitor',
        theme: ThemeData(
          // Material 3 theme configuration
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32), // Green theme for environmental monitoring
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
          cardTheme: const CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          // Accessibility improvements
          textTheme: const TextTheme(
            // Large, readable text for sensor values
            displayLarge: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
            displayMedium: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
            // Clear labels for UI elements
            labelLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const ScanScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
