/// Central configuration — update these values for your deployment.
/// Runtime overrides can be passed via dart-define, for example:
/// flutter run --dart-define=ATS_BACKEND_URL=http://192.168.10.50:3000
class AppConstants {
  AppConstants._();

  // ─── Intranet Server ──────────────────────────────────────────────────────
  static const String localBackendUrl = String.fromEnvironment(
    'ATS_BACKEND_URL',
    defaultValue: 'http://192.168.10.50:3000',
  );
  static const String supabaseLocalUrl = String.fromEnvironment(
    'ATS_SUPABASE_URL',
    defaultValue: 'http://192.168.10.50:8000',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'ATS_SUPABASE_ANON_KEY',
    defaultValue: 'local-dev-anon-key',
  );

  // ─── Campus GPS Boundary ──────────────────────────────────────────────────
  static const double campusLat = 15.3920;
  static const double campusLng = 75.0255;
  static const double maxCampusRadiusMeters = 150.0;

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
  ];

  // ─── Misc ─────────────────────────────────────────────────────────────────
  static const String allowedEmailDomain = '@iiitdwd.ac.in';
  static const String deepLinkScheme = 'attendanceapp';
  static const String deepLinkHost = 'login-callback';

  static bool get isSupabaseConfigured =>
      supabaseLocalUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('YOUR_') &&
      !supabaseAnonKey.contains('local-dev-anon-key');
}
