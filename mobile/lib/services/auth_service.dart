import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

/// Wraps Supabase authentication for Google OAuth sign-in / sign-out.
class AuthService {
  SupabaseClient? get _client =>
      AppConstants.isSupabaseConfigured ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;
  bool get isSignedIn => currentUser != null;

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
