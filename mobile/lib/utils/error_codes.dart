/// Maps internal verification failure stages to generic user-facing messages.
/// Intentionally vague to prevent reverse-engineering of which layer failed.
enum VerificationError {
  gpsUnavailable('0x00'),
  mockLocationDetected('0x01'),
  outsideCampus('0x02'),
  wrongNetwork('0x03'),
  beaconNotFound('0x04'),
  biometricFailed('0x05'),
  serverRejected('0x06'),
  unknown('0xFF');

  final String code;
  const VerificationError(this.code);

  String get userMessage => 'Attendance verification failed. Please ensure '
      'you are physically inside the classroom with location, '
      'Bluetooth, and Wi-Fi enabled. (Err: $code)';
}

class AttendanceException implements Exception {
  final VerificationError error;
  const AttendanceException(this.error);

  @override
  String toString() => error.userMessage;
}
