import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/constants.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasSupabaseSession = AppConstants.isSupabaseConfigured &&
        Supabase.instance.client.auth.currentSession != null;

    return MaterialApp(
      title: 'Anti-Cheat Indoor Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Indigo 600
          brightness: Brightness.light,
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: hasSupabaseSession ? const HomeScreen() : const LoginScreen(),
    );
  }
}
