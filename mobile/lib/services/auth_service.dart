import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

/// Wraps Supabase authentication for Email/Password and OAuth sign-in / sign-up.
class AuthService {
  SupabaseClient? get _client =>
      AppConstants.isSupabaseConfigured ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;
  bool get isSignedIn => currentUser != null;

  /// Retrieves user display metadata (full name, roll number, email).
  String get userDisplayName {
    final meta = currentUser?.userMetadata;
    final name = meta?['full_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return currentUser?.email ?? 'Student';
  }

  String? get userRollNumber {
    final meta = currentUser?.userMetadata;
    return meta?['roll_number'] as String?;
  }

  /// Sign in using Institute email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Supabase is not configured. Please supply ATS_SUPABASE_URL and ATS_SUPABASE_ANON_KEY.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.endsWith(AppConstants.allowedEmailDomain)) {
      throw Exception(
        'Access denied: Only ${AppConstants.allowedEmailDomain} accounts are permitted.',
      );
    }

    return await client.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  /// Register a new student account with Institute email, password, and metadata.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? rollNumber,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Supabase is not configured. Please supply ATS_SUPABASE_URL and ATS_SUPABASE_ANON_KEY.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (!normalizedEmail.endsWith(AppConstants.allowedEmailDomain)) {
      throw Exception(
        'Access denied: Only ${AppConstants.allowedEmailDomain} accounts are permitted.',
      );
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }

    final metadata = <String, dynamic>{};
    if (fullName != null && fullName.trim().isNotEmpty) {
      metadata['full_name'] = fullName.trim();
    }
    if (rollNumber != null && rollNumber.trim().isNotEmpty) {
      metadata['roll_number'] = rollNumber.trim().toUpperCase();
    }

    final response = await client.auth.signUp(
      email: normalizedEmail,
      password: password,
      data: metadata.isNotEmpty ? metadata : null,
    );

    // If session is immediately established (auto-confirmed), ensure profile table entry
    final user = response.user;
    if (user != null) {
      try {
        await client.from('profiles').upsert({
          'id': user.id,
          'email': normalizedEmail,
          'full_name': fullName?.trim(),
          'roll_number': rollNumber?.trim().toUpperCase(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Table trigger on backend handles it if direct client write is restricted
      }
    }

    return response;
  }

  /// Opens Google OAuth in-app browser. Requires self-hosted Supabase
  /// configured with `GOTRUE_EXTERNAL_GOOGLE_ENABLED=true`.
  Future<void> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw Exception(
        'Supabase is not configured. Please supply ATS_SUPABASE_URL and ATS_SUPABASE_ANON_KEY.',
      );
    }
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'attendanceapp://login-callback',
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  /// Persists the student's public key into the `student_devices` table.
  Future<void> registerPublicKey(String publicKey) async {
    final client = _client;
    if (client == null) {
      // In local demo mode, no remote Supabase instance to register with
      return;
    }
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    await client.from('student_devices').upsert({
      'user_id': user.id,
      'email': user.email,
      'public_key': publicKey,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
