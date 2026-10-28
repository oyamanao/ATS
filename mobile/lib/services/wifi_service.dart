import 'package:network_info_plus/network_info_plus.dart';
import '../config/constants.dart';
import '../utils/error_codes.dart';

/// Reads the connected router's BSSID and validates it against the allowlist.
class WifiService {
  final _networkInfo = NetworkInfo();

  /// Throws [AttendanceException] if the device is not on the classroom Wi-Fi.
  Future<void> verifyBssid() async {
    final String? bssid;
    try {
      bssid = await _networkInfo.getWifiBSSID();
    } catch (_) {
      throw const AttendanceException(VerificationError.wrongNetwork);
    }

    if (bssid == null) {
      throw const AttendanceException(VerificationError.wrongNetwork);
    }

    final normalizedBssid = bssid.toLowerCase().trim();
    final isAllowed = AppConstants.validClassroomBSSIDs
        .any((allowed) => allowed.toLowerCase().trim() == normalizedBssid);

    if (!isAllowed) {
      throw const AttendanceException(VerificationError.wrongNetwork);
    }
  }
}
