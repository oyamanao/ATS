import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/status_card.dart';
import '../widgets/primary_button.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _authService = AuthService();
  final _biometricService = BiometricService();

  StatusType _statusType = StatusType.idle;
  String _statusMessage =
      'This one-time binding must be executed in physical presence of your Faculty Advisor.';
  bool _isSuccess = false;

  Future<void> _registerDevice() async {
    setState(() {
      _statusType = StatusType.loading;
      _statusMessage =
          'Generating asymmetric 2048-bit RSA key pair in hardware Secure Enclave...';
    });

    try {
      final publicKey = await _biometricService.createHardwareKey();
      if (!mounted) return;

      setState(() {
        _statusMessage =
            'Binding public key to student account on local Supabase server...';
      });

      await _authService.registerPublicKey(publicKey);
      if (!mounted) return;

      setState(() {
        _statusType = StatusType.success;
        _statusMessage =
            'Device bound successfully! Your hardware key is securely pinned to your profile.';
        _isSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusType = StatusType.failure;
        _statusMessage =
            'Device binding failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text(
          'Device Registration',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Advisor Warning Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB), // Amber 50
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFFDE68A)), // Amber 200
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706), // Amber 600
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty Advisor Verification Required',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Execute this procedure strictly during office hours in the physical presence of your advisor. Once registered, this device is cryptographically pinned.',
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hardware Cryptography Pipeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                step: '1',
                title: 'Secure Enclave / Android KeyStore',
                desc:
                    'An RSA key pair is generated inside the tamper-resistant hardware chip. The private key never leaves the silicon.',
              ),
              const SizedBox(height: 10),
              _buildStepCard(
                step: '2',
                title: 'Biometric Invalidation Pinning',
                desc:
                    'Configured with setInvalidatedByBiometricEnrollment = true. Adding any new fingerprint or Face ID invalidates the key.',
              ),
              const SizedBox(height: 10),
              _buildStepCard(
                step: '3',
                title: 'Local Supabase Public Key Registry',
                desc:
                    'Only the public key is sent over the campus network to Supabase DB and linked to your @iiitdwd.ac.in account.',
              ),
              const SizedBox(height: 26),
              StatusCard(
                status: _statusType,
                message: _statusMessage,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSuccess
                    ? 'Registration Complete'
                    : 'Enroll Biometric Hardware Key',
                icon: _isSuccess
                    ? Icons.verified_rounded
                    : Icons.fingerprint_rounded,
                color: _isSuccess
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
                isLoading: _statusType == StatusType.loading,
                onPressed: _isSuccess ? null : _registerDevice,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Home'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
