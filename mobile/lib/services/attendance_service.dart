import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/attendance_payload.dart';
import '../utils/error_codes.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'ble_service.dart';
import 'gps_service.dart';
import 'wifi_service.dart';

/// Orchestrates the full 5-layer attendance verification gauntlet.
class AttendanceService {
  final GpsService gps;
  final WifiService wifi;
  final BleService ble;
  final BiometricService biometric;
  final AuthService auth;

  AttendanceService({
    GpsService? gps,
    WifiService? wifi,
    BleService? ble,
    BiometricService? biometric,
    AuthService? auth,
  })  : gps = gps ?? GpsService(),
        wifi = wifi ?? WifiService(),
        ble = ble ?? BleService(),
        biometric = biometric ?? BiometricService(),
        auth = auth ?? AuthService();

  /// Runs all verification steps end-to-end.
  /// Throws [AttendanceException] on any verification failure.
  Future<void> markAttendance(String qrPayload) async {
    // Layer 1: GPS location + mock detection
    await gps.verifyLocation();

    // Layer 2: Wi-Fi BSSID validation
    await wifi.verifyBssid();

    // Layer 3: BLE beacon proximity
    await ble.verifyBeacon();

    // Layer 4 + 5: Biometric hardware signature of TOTP payload
    final String signature = await biometric.signPayload(qrPayload);

    // Layer 6: Submit to intranet server
    await submitPayload(qrPayload, signature);
  }

  /// Submits the cryptographically signed payload to the university intranet API.
  Future<void> submitPayload(String qrPayload, String signature) async {
    final session = auth.currentSession;
    if (session == null && AppConstants.isSupabaseConfigured) {
      throw const AttendanceException(VerificationError.serverRejected);
    }

    final token = session?.accessToken ?? 'demo-token';

    final payload = AttendancePayload(
      qrPayload: qrPayload,
      signature: signature,
    );

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${AppConstants.localBackendUrl}/api/attendance/mark'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const AttendanceException(VerificationError.serverRejected);
    }

    if (response.statusCode != 200) {
      throw const AttendanceException(VerificationError.serverRejected);
    }
  }
}
