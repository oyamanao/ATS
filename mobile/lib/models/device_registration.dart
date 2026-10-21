/// Represents a student's registered hardware device in the Supabase database.
class DeviceRegistration {
  final String userId;
  final String email;
  final String publicKey;
  final DateTime updatedAt;

  const DeviceRegistration({
    required this.userId,
    required this.email,
    required this.publicKey,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'public_key': publicKey,
        'updated_at': updatedAt.toIso8601String(),
      };
}
