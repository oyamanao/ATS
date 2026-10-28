import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QRScanScreen extends StatefulWidget {
  final Future<void> Function(String)? onScanned;

  const QRScanScreen({super.key, this.onScanned});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _hasDetected = false;
  bool _isCheckingPermission = true;
  bool _hasPermission = false;
  bool _isPermanentlyDenied = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
    );
    _checkAndRequestPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permission if user came back from Settings
      _recheckPermissionOnResume();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
    }
  }

  Future<void> _checkAndRequestPermission() async {
    setState(() {
      _isCheckingPermission = true;
      _errorMessage = null;
    });

    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (!mounted) return;
      setState(() {
        _hasPermission = true;
        _isCheckingPermission = false;
        _isPermanentlyDenied = false;
      });
      _startController();
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isCheckingPermission = false;
        _isPermanentlyDenied = true;
      });
    } else {
      // Prompt user for camera permission
      final result = await Permission.camera.request();
      if (!mounted) return;
      if (result.isGranted) {
        setState(() {
          _hasPermission = true;
          _isCheckingPermission = false;
          _isPermanentlyDenied = false;
        });
        _startController();
      } else {
        setState(() {
          _hasPermission = false;
          _isCheckingPermission = false;
          _isPermanentlyDenied = result.isPermanentlyDenied;
        });
      }
    }
  }

  Future<void> _recheckPermissionOnResume() async {
    final status = await Permission.camera.status;
    if (!mounted) return;

    if (status.isGranted) {
      final wasGranted = _hasPermission;
      setState(() {
        _hasPermission = true;
        _isPermanentlyDenied = false;
        _errorMessage = null;
      });
      if (!wasGranted || !_controller.value.isRunning) {
        _startController();
      }
    } else {
      setState(() {
        _hasPermission = false;
        _isPermanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  Future<void> _startController() async {
    try {
      if (!_controller.value.isRunning) {
        await _controller.start();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_hasDetected) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        if (!mounted) return;
        setState(() => _hasDetected = true);
        await _controller.stop();
        if (mounted) {
          Navigator.pop(context, code);
          await widget.onScanned?.call(code);
        }
        break;
      }
    }
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF818CF8).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                size: 56,
                color: Color(0xFF818CF8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isPermanentlyDenied
                  ? 'Camera permission has been permanently denied. Please enable camera access in App Settings to scan attendance QR codes.'
                  : 'ATS requires camera permission to scan dynamic QR codes on the classroom screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                if (_isPermanentlyDenied) {
                  openAppSettings();
                } else {
                  _checkAndRequestPermission();
                }
              },
              icon: Icon(
                _isPermanentlyDenied
                    ? Icons.settings_rounded
                    : Icons.camera_alt_rounded,
                size: 18,
              ),
              label: Text(
                _isPermanentlyDenied
                    ? 'Open App Settings'
                    : 'Grant Camera Access',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Initialization Error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _errorMessage = null);
                _startController();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerErrorView(MobileScannerException error) {
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return _buildPermissionDeniedView();
    }

    return _buildGenericErrorView(
      error.errorDetails?.message ?? error.errorCode.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Teacher Screen QR',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasPermission) ...[
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                if (!state.isInitialized) {
                  return const SizedBox.shrink();
                }
                final isTorchOn = state.torchState == TorchState.on;
                return IconButton(
                  icon: Icon(
                    isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  tooltip: isTorchOn ? 'Turn Off Flash' : 'Turn On Flash',
                  onPressed: () => _controller.toggleTorch(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              tooltip: 'Switch Camera',
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ],
      ),
      body: _isCheckingPermission
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF818CF8),
              ),
            )
          : !_hasPermission
              ? _buildPermissionDeniedView()
              : _errorMessage != null
                  ? _buildGenericErrorView(_errorMessage!)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          placeholderBuilder: (context, child) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF818CF8),
                            ),
                          ),
                          errorBuilder: (context, error, child) =>
                              _buildScannerErrorView(error),
                        ),
                        // Darkened overlay around viewfinder
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.55),
                            BlendMode.srcOut,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  backgroundBlendMode: BlendMode.dstOut,
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  height: 260,
                                  width: 260,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Viewfinder reticle borders
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 260,
                            width: 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF818CF8),
                                width: 3,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    width: 20,
                                    height: 4,
                                    color: Colors.white,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    width: 4,
                                    height: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    width: 20,
                                    height: 4,
                                    color: Colors.white,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    width: 4,
                                    height: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Guidance Text at bottom
                        Positioned(
                          bottom: 40,
                          left: 24,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Column(
                              children: [
                                Text(
                                  'Point camera at the live rolling QR code',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'QR changes every 10 seconds. Static photos will be rejected.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFA5B4FC),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
