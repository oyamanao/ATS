import 'package:flutter/foundation.dart';
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

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }

    if (position == null) {
      throw const AttendanceException(VerificationError.gpsUnavailable);
    }

    if (position.isMocked) {
      throw const AttendanceException(VerificationError.mockLocationDetected);
    }

    final double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      AppConstants.campusLat,
      AppConstants.campusLng,
    );

    // Account for GPS horizontal uncertainty indoors (position.accuracy)
    final double effectiveDistance =
        (distance - position.accuracy).clamp(0.0, double.infinity);

    debugPrint(
      'ATS GPS Verification: lat=${position.latitude}, lng=${position.longitude}, '
      'rawDistance=${distance.toStringAsFixed(1)}m, accuracy=±${position.accuracy.toStringAsFixed(1)}m, '
      'effectiveDistance=${effectiveDistance.toStringAsFixed(1)}m, maxRadius=${AppConstants.maxCampusRadiusMeters}m',
    );

    if (effectiveDistance > AppConstants.maxCampusRadiusMeters &&
        distance > AppConstants.maxCampusRadiusMeters) {
      throw const AttendanceException(VerificationError.outsideCampus);
    }

    return position;
  }

  Future<bool> _ensurePermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }
}
