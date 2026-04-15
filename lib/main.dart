import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

// ── EcoSynth Firebase Configuration ──────────────────────────────────────
// Paste your values from Firebase Console → Project Settings → Web App.
const _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDSK_GC675obkfx-mlPf7eW-aAfn4gxJwY',
  appId: '1:786245430953:web:34e7143ebf39015e0f83b8',
  messagingSenderId: '786245430953',
  projectId: 'synthv1',
  databaseURL: 'https://synthv1-default-rtdb.asia-southeast1.firebasedatabase.app',
);
// ──────────────────────────────────────────────────────────────────────────

/// Global theme notifier — accessible from any widget tree via import.
final ValueNotifier<ThemeMode> themeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restore saved theme preference
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedDark = prefs.getBool('isDarkMode') ?? true;
    themeNotifier.value = savedDark ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {
    // Default to dark on failure
  }

  // Persist theme on change
  themeNotifier.addListener(() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'isDarkMode',
        themeNotifier.value == ThemeMode.dark,
      );
    } catch (_) {}
  });

  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: _firebaseOptions);
  } catch (e) {
    debugPrint('Firebase init error: $e');
    // App will show offline state — not a fatal crash.
  }

  runApp(const SmartGardenApp());
}

class SmartGardenApp extends StatelessWidget {
  const SmartGardenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'EcoSynth',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
