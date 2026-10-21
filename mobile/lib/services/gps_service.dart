import 'package:geolocator/geolocator.dart';
import '../config/constants.dart';
import '../utils/error_codes.dart';

/// Handles GPS verification: campus boundary check and mock location detection.
class GpsService {
  /// Requests location permission if not granted, then fetches current position.
  /// Throws [AttendanceException] on failure or spoofing detection.
  Future<Position> verifyLocation() async {
    final permission = await _ensurePermission();
    if (!permission) {
      throw const AttendanceException(VerificationError.gpsUnavailable);
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (position.isMocked) {
      throw const AttendanceException(VerificationError.mockLocationDetected);
    }

    final double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      AppConstants.campusLat,
      AppConstants.campusLng,
    );

    if (distance > AppConstants.maxCampusRadiusMeters) {
      throw const AttendanceException(VerificationError.outsideCampus);
    }

    return position;
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
