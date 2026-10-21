import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/attendance_payload.dart';
import 'package:attendance_app/models/device_registration.dart';

void main() {
  group('Model Serialization Tests', () {
    test('AttendancePayload toJson serializes correctly', () {
      const payload = AttendancePayload(
        qrPayload: 'attendance://CS101/123456',
        signature: 'mock_base64_sig',
      );

      final json = payload.toJson();
      expect(json['qrPayload'], equals('attendance://CS101/123456'));
      expect(json['signature'], equals('mock_base64_sig'));
    });

    test('DeviceRegistration toJson serializes correctly', () {
      final now = DateTime.utc(2026, 10, 21, 12, 0, 0);
      final reg = DeviceRegistration(
        userId: 'user-1234',
        email: '21bcs001@iiitdwd.ac.in',
        publicKey: '-----BEGIN PUBLIC KEY-----...',
        updatedAt: now,
      );

      final json = reg.toJson();
      expect(json['user_id'], equals('user-1234'));
      expect(json['email'], equals('21bcs001@iiitdwd.ac.in'));
      expect(json['public_key'], equals('-----BEGIN PUBLIC KEY-----...'));
      expect(json['updated_at'], equals('2026-10-21T12:00:00.000Z'));
    });
  });
}
