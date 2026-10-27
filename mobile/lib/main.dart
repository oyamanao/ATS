import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/constants.dart';

/// Application entry point: initializes connection to the university's
/// self-hosted Supabase server with PKCE OAuth flow before mounting root widget.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConstants.supabaseLocalUrl,
      publishableKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } else {
    debugPrint(
        'Supabase is not configured; starting in local demo mode without remote auth.');
  }

  runApp(const AttendanceApp());
}
