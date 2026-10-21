import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/utils/error_codes.dart';

void main() {
  group('VerificationError & AttendanceException Tests', () {
    test(
        'all error codes should produce generic user messages masking internals',
        () {
      for (final err in VerificationError.values) {
        expect(err.code, isNotEmpty);
        expect(err.userMessage, contains('Attendance verification failed'));
        expect(err.userMessage, contains(err.code));
      }
    });

    test('AttendanceException toString should match error userMessage', () {
      const ex = AttendanceException(VerificationError.mockLocationDetected);
      expect(ex.toString(), contains('0x01'));
      expect(ex.toString(), contains('physically inside the classroom'));
    });
  });
}
