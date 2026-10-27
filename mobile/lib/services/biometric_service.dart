import 'package:biometric_signature/biometric_signature.dart';
import '../utils/error_codes.dart';

/// Manages hardware key generation and cryptographic signing via the Secure Enclave.
class BiometricService {
  final _plugin = BiometricSignature();

  /// Generates an RSA key pair inside the device's hardware security chip.
  /// Returns the base64/PEM-encoded public key for upload to the server.
  /// Throws [AttendanceException] on failure.
  Future<String> createHardwareKey() async {
    try {
      final KeyCreationResult result = await _plugin.createKeys(
        promptMessage:
            'Authenticate to register your device key with the faculty advisor',
        config: CreateKeysConfig(
          enforceBiometric: true,
          setInvalidatedByBiometricEnrollment: true,
        ),
      );

      final publicKey = result.publicKey;
      if (publicKey == null || publicKey.isEmpty) {
        throw const AttendanceException(VerificationError.biometricFailed);
      }

      return publicKey;
    } on AttendanceException {
      rethrow;
    } catch (_) {
      throw const AttendanceException(VerificationError.biometricFailed);
    }
  }

  /// Signs [payload] using the hardware-bound private key.
  /// Returns base64-encoded signature.
  Future<String> signPayload(String payload) async {
    try {
      final SignatureResult result = await _plugin.createSignature(
        payload: payload,
        promptMessage:
            'Scan fingerprint to cryptographically sign your attendance',
      );

      final signature = result.signature;
      if (signature == null || signature.isEmpty) {
        throw const AttendanceException(VerificationError.biometricFailed);
      }

      return signature;
    } on AttendanceException {
      rethrow;
    } catch (_) {
      throw const AttendanceException(VerificationError.biometricFailed);
    }
  }
}
