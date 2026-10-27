import 'package:flutter_beacon/flutter_beacon.dart';
import '../config/constants.dart';
import '../utils/error_codes.dart';

/// Scans for the classroom ESP32 iBeacon and validates signal strength.
class BleService {
  /// Scans for [durationSeconds] and resolves true if the beacon is within range.
  /// Throws [AttendanceException] if the beacon is not found or RSSI is too low.
  Future<void> verifyBeacon({int durationSeconds = 4}) async {
    try {
      await flutterBeacon.initializeScanning;
    } catch (_) {
      throw const AttendanceException(VerificationError.beaconNotFound);
    }

    final regions = <Region>[
      Region(
        identifier: 'ClassroomBeacon',
        proximityUUID: AppConstants.targetBeaconUUID,
      )
    ];

    bool beaconFound = false;

    try {
      final stream =
          flutterBeacon.ranging(regions).listen((RangingResult result) {
        for (final Beacon beacon in result.beacons) {
          if (beacon.rssi != 0 && beacon.rssi > AppConstants.minBeaconRssi) {
            beaconFound = true;
          }
        }
      });

      final stopWatch = Stopwatch()..start();
      while (!beaconFound && stopWatch.elapsed.inSeconds < durationSeconds) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      await stream.cancel();
    } catch (_) {
      throw const AttendanceException(VerificationError.beaconNotFound);
    } finally {
      try {
        await flutterBeacon.close;
      } catch (_) {
        // Ignore native cleanup errors
      }
    }

    if (!beaconFound) {
      throw const AttendanceException(VerificationError.beaconNotFound);
    }
  }
}
