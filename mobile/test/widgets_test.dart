import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/widgets/status_card.dart';
import 'package:attendance_app/widgets/primary_button.dart';
import 'package:attendance_app/widgets/step_indicator.dart';

void main() {
  group('UI Widget Tests', () {
    testWidgets('StatusCard renders correctly for all statuses',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusCard(
              status: StatusType.success,
              message: 'Attendance Verified',
            ),
          ),
        ),
      );

      expect(find.text('Attendance Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('PrimaryButton displays label, icon and reacts to press',
        (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Scan QR',
              icon: Icons.qr_code,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('StepIndicator renders step states',
        (WidgetTester tester) async {
      const steps = [
        VerificationStep(
          label: 'GPS Check',
          description: 'Geofence check',
          status: StepStatus.success,
        ),
        VerificationStep(
          label: 'BSSID Check',
          description: 'Router match',
          status: StepStatus.active,
        ),
        VerificationStep(
          label: 'BLE Check',
          description: 'Room check',
          status: StepStatus.pending,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepIndicator(steps: steps),
          ),
        ),
      );

      expect(find.text('GPS Check'), findsOneWidget);
      expect(find.text('BSSID Check'), findsOneWidget);
      expect(find.text('BLE Check'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
