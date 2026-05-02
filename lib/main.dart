import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() {
  runApp(const AudioUploaderApp());
}

class AudioUploaderApp extends StatelessWidget {
  const AudioUploaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Audio Uploader',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const LoginScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        foregroundColor:
            brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
    );
  }
}
