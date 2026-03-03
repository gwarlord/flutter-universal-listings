import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR code scanner
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController _controller;
  bool _isScanned = false;
  int _detectionCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 QRScannerScreen: Initializing camera...');
    _controller = MobileScannerController(
      // Try without format filter to enable all barcode types
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    
    debugPrint('✅ Camera controller created');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Table QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await _controller.toggleTorch();
              debugPrint('🔦 Torch toggled');
            },
          ),
          // Debug button to test callback
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Tooltip(
                message: 'Detection: $_detectionCount',
                child: Text(
                  _detectionCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              _detectionCount++;
              debugPrint('🔍 onDetect called! (count: $_detectionCount)');
              _onDetect(capture);
            },
            errorBuilder: (context, error) {
              debugPrint('❌ Scanner error: ${error.errorCode} - ${error.errorDetails?.message}');
              return ScannedFrameWidget(
                error: error,
              );
            },
          ),
          // Instructions overlay
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2, color: Colors.white, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Position the QR code inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detections: $_detectionCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detectionCount == 0 
                          ? 'Waiting for QR code...' 
                          : 'QR codes detected! Keep camera steady.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    debugPrint('🔍 Detected ${barcodes.length} barcodes');
    
    if (barcodes.isEmpty) {
      debugPrint('⚠️ No barcodes in capture');
      return;
    }
    
    for (final barcode in barcodes) {
      debugPrint('📱 Barcode Details:');
      debugPrint('   - Type: ${barcode.type}');
      debugPrint('   - Format: ${barcode.format}');
      debugPrint('   - Raw Value: "${barcode.rawValue}"');
      debugPrint('   - Display Value: "${barcode.displayValue}"');
      debugPrint('   - Value Bytes: ${barcode.rawBytes?.length ?? 0} bytes');
      
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        debugPrint('✅ QR Code detected and returning: "$rawValue"');
        _isScanned = true;
        _controller.stop();
        Navigator.of(context).pop(rawValue);
        return;
      } else {
        debugPrint('⚠️ Barcode has no raw value');
      }
    }
  }
}

class ScannedFrameWidget extends StatelessWidget {
  const ScannedFrameWidget({
    Key? key,
    required this.error,
  }) : super(key: key);

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              error.errorCode.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.errorDetails?.message ?? 'Unknown error',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
