import 'package:attendance_app/config/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConstants uses safe local defaults instead of placeholder values',
      () {
    expect(AppConstants.localBackendUrl, isNot(contains('YOUR_')));
    expect(AppConstants.supabaseLocalUrl, isNot(contains('YOUR_')));
    expect(AppConstants.supabaseAnonKey, isNot(contains('YOUR_')));
    expect(AppConstants.targetBeaconUUID, isNotEmpty);
    expect(AppConstants.maxCampusRadiusMeters, equals(500.0));
  });
}
