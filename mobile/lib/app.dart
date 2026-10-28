import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = AuthService.isLoggedIn;

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
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
