import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.init();
  });

  group('AuthService Hybrid Authentication & Password Verification', () {
    test('Rejects email that does not belong to @iiitdwd.ac.in', () async {
      final auth = AuthService();
      expect(
        () => auth.signInWithEmail(
          email: 'user@gmail.com',
          password: 'password123',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Only @iiitdwd.ac.in accounts are permitted'))),
      );
    });

    test('Rejects login when password is wrong', () async {
      final auth = AuthService();
      expect(
        () => auth.signInWithEmail(
          email: 'student@iiitdwd.ac.in',
          password: 'wrongpassword',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Invalid email or password') ||
            e.toString().contains('verify your password'))),
      );
    });

    test('Allows login with correct pre-seeded default student credentials',
        () async {
      final auth = AuthService();
      await auth.signInWithEmail(
        email: 'student@iiitdwd.ac.in',
        password: 'password123',
      );

      expect(AuthService.isLoggedIn, isTrue);
      expect(auth.userDisplayName, 'Student IIITDWD');
      expect(auth.userRollNumber, '23BCS001');
      expect(auth.userEmail, 'student@iiitdwd.ac.in');
      expect(auth.currentSession, isNotNull);
    });

    test('Rejects unregistered email in local mode', () async {
      final auth = AuthService();
      expect(
        () => auth.signInWithEmail(
          email: 'unknown.student@iiitdwd.ac.in',
          password: 'somepassword',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('not found') ||
            e.toString().contains('Create Account'))),
      );
    });

    test('Registers new student, persists credentials, and verifies password',
        () async {
      final auth = AuthService();

      // Sign up new student
      await auth.signUpWithEmail(
        email: 'aditya.sharma@iiitdwd.ac.in',
        password: 'mysecretpassword',
        fullName: 'Aditya Sharma',
        rollNumber: '23BCS045',
      );

      expect(AuthService.isLoggedIn, isTrue);
      expect(auth.userDisplayName, 'Aditya Sharma');
      expect(auth.userRollNumber, '23BCS045');

      // Sign out
      await auth.signOut();
      expect(AuthService.isLoggedIn, isFalse);

      // Attempt login with wrong password -> must fail
      expect(
        () => auth.signInWithEmail(
          email: 'aditya.sharma@iiitdwd.ac.in',
          password: 'incorrectpassword',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('Invalid email or password') ||
            e.toString().contains('verify your password'))),
      );

      // Attempt login with correct password -> must succeed
      await auth.signInWithEmail(
        email: 'aditya.sharma@iiitdwd.ac.in',
        password: 'mysecretpassword',
      );
      expect(AuthService.isLoggedIn, isTrue);
      expect(auth.userDisplayName, 'Aditya Sharma');
    });

    test('Sign out clears active user session', () async {
      final auth = AuthService();
      await auth.signInWithEmail(
        email: 'student@iiitdwd.ac.in',
        password: 'password123',
      );
      expect(AuthService.isLoggedIn, isTrue);

      await auth.signOut();
      expect(AuthService.isLoggedIn, isFalse);
    });
  });
}
