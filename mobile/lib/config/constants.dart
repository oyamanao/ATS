/// Central configuration — update these values for your deployment.
/// Runtime overrides can be passed via dart-define, for example:
/// flutter run --dart-define=ATS_BACKEND_URL=http://10.0.5.32:3000
class AppConstants {
  AppConstants._();

  // ─── Intranet Server ──────────────────────────────────────────────────────
  static const String localBackendUrl = String.fromEnvironment(
    'ATS_BACKEND_URL',
    defaultValue: 'http://10.0.5.32:3000',
  );
  static const String supabaseLocalUrl = String.fromEnvironment(
    'ATS_SUPABASE_URL',
    defaultValue: 'http://10.0.5.32:8000',
  );
  static const String defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIwNTAwMDAwMDB9.8iej_KelMbImwdSqAjKpH7b0s4P-ul6qvATIC3uOqKc';

  static const String supabaseAnonKey = String.fromEnvironment(
    'ATS_SUPABASE_ANON_KEY',
    defaultValue: defaultSupabaseAnonKey,
  );

  // ─── Campus GPS Boundary ──────────────────────────────────────────────────
  static const double campusLat = 15.3920;
  static const double campusLng = 75.0255;
  static const double maxCampusRadiusMeters = 500.0;

  // ─── BLE Beacon ───────────────────────────────────────────────────────────
  /// UUID programmed into the ESP32 classroom beacon
  static const String targetBeaconUUID = 'B9407F30-F5F8-466E-AFF9-25556B57FE6D';

  /// Minimum RSSI threshold — student must be inside the room
  static const int minBeaconRssi = -70;

  // ─── Wi-Fi BSSID Allowlist ────────────────────────────────────────────────
  /// MAC addresses of classroom routers (lowercase)
  static const List<String> validClassroomBSSIDs = [
    '00:14:22:01:23:45',
    '00:14:22:01:23:46',
    'd4:20:b0:99:a3:f1',
  ];

  // ─── Misc ─────────────────────────────────────────────────────────────────
  static const String allowedEmailDomain = '@iiitdwd.ac.in';
  static const String deepLinkScheme = 'attendanceapp';
  static const String deepLinkHost = 'login-callback';

  static bool get isSupabaseConfigured =>
      supabaseLocalUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('YOUR_');
}
