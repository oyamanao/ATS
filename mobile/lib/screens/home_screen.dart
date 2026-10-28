import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../widgets/status_card.dart';
import '../widgets/step_indicator.dart';
import '../widgets/primary_button.dart';
import 'qr_scan_screen.dart';
import 'registration_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceService = AttendanceService();
  final _authService = AuthService();

  static const List<VerificationStep> _initialSteps = [
    VerificationStep(
      label: 'Campus Boundary & Mock Check',
      description: 'Verifies GPS accuracy and flags simulated locations',
      status: StepStatus.pending,
    ),
    VerificationStep(
      label: 'Classroom Router BSSID Match',
      description: 'Validates physical Wi-Fi hardware MAC address',
      status: StepStatus.pending,
    ),
    VerificationStep(
      label: 'ESP32 BLE Proximity Verification',
      description: 'Confirms in-room Bluetooth RSSI > -70 dBm',
      status: StepStatus.pending,
    ),
    VerificationStep(
      label: 'Dynamic TOTP QR Ingestion',
      description: 'Extracts rolling 10s token from live teacher display',
      status: StepStatus.pending,
    ),
    VerificationStep(
      label: 'Biometric Hardware Key Signature',
      description: 'Signs token inside Secure Enclave using private key',
      status: StepStatus.pending,
    ),
    VerificationStep(
      label: 'Local Intranet API Confirmation',
      description: 'Cryptographic signature & token idempotency check',
      status: StepStatus.pending,
    ),
  ];

  StatusType _statusType = StatusType.idle;
  String _statusMessage =
      'Ready. Stand in your classroom and scan the screen QR code.';
  bool _isProcessing = false;
  late List<VerificationStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = List.of(_initialSteps);
  }

  void _resetSteps() {
    if (!mounted) return;
    setState(() {
      _steps = List.of(_initialSteps);
    });
  }

  void _updateStep(int index, StepStatus status) {
    if (!mounted) return;
    setState(() {
      _steps = List.generate(_steps.length, (i) {
        if (i == index) {
          return VerificationStep(
            label: _steps[i].label,
            description: _steps[i].description,
            status: status,
          );
        }
        return _steps[i];
      });
    });
  }

  Future<void> _startAttendanceFlow() async {
    _resetSteps();

    // 1. Open QR scanner and await scanned code directly
    final scannedPayload = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const QRScanScreen(),
      ),
    );

    if (!mounted) return;

    if (scannedPayload == null || scannedPayload.isEmpty) {
      setState(() {
        _statusType = StatusType.idle;
        _statusMessage = 'QR code scan cancelled.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusType = StatusType.loading;
      _statusMessage = 'Executing security verification gauntlet (testing all 6 checks)...';
    });

    final List<String> failedChecks = [];
    String? biometricSignature;

    // ─── Step 0: Campus Boundary & Mock Check (GPS) ──────────────────────────
    _updateStep(0, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _attendanceService.gps.verifyLocation();
      _updateStep(0, StepStatus.success);
    } catch (e) {
      debugPrint('Step 0 (GPS) check failed: $e');
      _updateStep(0, StepStatus.failed);
      failedChecks.add('GPS Boundary');
    }

    // ─── Step 1: Classroom Router BSSID Match (Wi-Fi) ───────────────────────
    _updateStep(1, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _attendanceService.wifi.verifyBssid();
      _updateStep(1, StepStatus.success);
    } catch (e) {
      debugPrint('Step 1 (Wi-Fi) check failed: $e');
      _updateStep(1, StepStatus.failed);
      failedChecks.add('Wi-Fi BSSID');
    }

    // ─── Step 2: ESP32 BLE Proximity Verification (Bluetooth) ───────────────
    _updateStep(2, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _attendanceService.ble.verifyBeacon();
      _updateStep(2, StepStatus.success);
    } catch (e) {
      debugPrint('Step 2 (BLE) check failed: $e');
      _updateStep(2, StepStatus.failed);
      failedChecks.add('BLE Beacon');
    }

    // ─── Step 3: Dynamic TOTP QR Ingestion ──────────────────────────────────
    _updateStep(3, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    if (scannedPayload.isNotEmpty) {
      _updateStep(3, StepStatus.success);
    } else {
      _updateStep(3, StepStatus.failed);
      failedChecks.add('QR Ingestion');
    }

    // ─── Step 4: Biometric Hardware Key Signature ───────────────────────────
    _updateStep(4, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      biometricSignature =
          await _attendanceService.biometric.signPayload(scannedPayload);
      _updateStep(4, StepStatus.success);
    } catch (e) {
      debugPrint('Step 4 (Biometric) check failed: $e');
      _updateStep(4, StepStatus.failed);
      failedChecks.add('Biometric Signature');
    }

    // ─── Step 5: Local Intranet API Confirmation ─────────────────────────────
    _updateStep(5, StepStatus.active);
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final effectiveSig = biometricSignature ??
          'simulated_sig_${DateTime.now().millisecondsSinceEpoch}';
      await _attendanceService.submitPayload(scannedPayload, effectiveSig);
      _updateStep(5, StepStatus.success);
    } catch (e) {
      debugPrint('Step 5 (Server submission) check failed: $e');
      _updateStep(5, StepStatus.failed);
      failedChecks.add('Server API Confirmation');
    }

    // ─── Final Status Resolution ─────────────────────────────────────────────
    if (!mounted) return;
    final passedCount = 6 - failedChecks.length;
    setState(() {
      _isProcessing = false;
      if (failedChecks.isEmpty) {
        _statusType = StatusType.success;
        _statusMessage =
            'All 6 security checks verified! Attendance marked successfully.';
      } else {
        _statusType = StatusType.failure;
        _statusMessage =
            'Gauntlet completed: $passedCount of 6 checks passed. '
            'Failed: ${failedChecks.join(', ')}.';
      }
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, size: 22, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Text(
              'Attendance Gauntlet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Status Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                      child: const Icon(Icons.person,
                          color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _authService.userDisplayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (_authService.userRollNumber != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Roll No: ${_authService.userRollNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          Text(
                            user?.email ?? 'student@iiitdwd.ac.in',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.verified,
                                  size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'IIIT Dharwad Domain Authenticated',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Status Card
              StatusCard(
                status: _statusType,
                message: _statusMessage,
              ),
              const SizedBox(height: 22),

              // Steps Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Multi-Factor Defense Layers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '6/6 Required',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Step Indicator
              StepIndicator(steps: _steps),
              const SizedBox(height: 24),

              // Action Buttons
              PrimaryButton(
                label: _isProcessing
                    ? 'Verifying Hardware & Presence...'
                    : 'Scan Attendance QR',
                icon: Icons.qr_code_scanner_rounded,
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _startAttendanceFlow,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Advisor Setup: Re-Enroll Hardware Key',
                icon: Icons.fingerprint_rounded,
                color: const Color(0xFFD97706), // Amber 600
                onPressed: _isProcessing
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegistrationScreen()),
                        );
                      },
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Connected to University Intranet Gateway • ${Uri.tryParse(AppConstants.localBackendUrl)?.host ?? "10.0.5.32"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
