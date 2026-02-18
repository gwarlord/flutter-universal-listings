import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';

/// A text field widget with integrated barcode scanner
/// 
/// Features:
/// - Manual text input
/// - Scan barcode using device camera
/// - Clear button
/// - Respects loading state
/// - Automatic field population from barcode scan
class BarcodeTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool isLoading;
  final bool isDarkMode;
  final ValueChanged<String>? onChanged;

  const BarcodeTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.isLoading = false,
    required this.isDarkMode,
    this.onChanged,
  }) : super(key: key);

  @override
  State<BarcodeTextField> createState() => _BarcodeTextFieldState();
}

class _BarcodeTextFieldState extends State<BarcodeTextField> {
  late MobileScannerController _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      autoStart: false,
      formats: const [
        BarcodeFormat.codabar,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.code128,
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
        BarcodeFormat.pdf417,
      ],
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _openBarcodeScanner() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      builder: (context) => _BarcodeScannerModal(
        cameraController: _cameraController,
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        widget.controller.text = result;
      });
      widget.onChanged?.call(result);
      
      if (mounted) {
        showSnackBar(
          context,
          'Barcode scanned: $result'.tr(),
        );
      }
    }
  }

  void _clearField() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  labelText: widget.labelText,
                  labelStyle: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white70
                        : Colors.black54,
                  ),
                  hintText: widget.hintText ?? '',
                  hintStyle: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white38
                        : Colors.black26,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  filled: true,
                  fillColor: widget.isDarkMode
                      ? Colors.grey.shade800
                      : Colors.white,
                  enabled: !widget.isLoading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  suffixIcon: widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.isLoading ? null : _clearField,
                          color: Color(cfg.colorPrimary),
                        )
                      : null,
                ),
              ),
            ),
            // Barcode Scanner Button
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isDarkMode
                      ? Colors.grey.shade600
                      : Colors.grey.shade300,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                color: widget.isDarkMode
                    ? Colors.grey.shade800
                    : Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : _openBarcodeScanner,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Icon(
                        Icons.qr_code_2,
                        color: widget.isLoading
                            ? Colors.grey.shade400
                            : Color(cfg.colorPrimary),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'Tap the barcode icon to scan or type manually'.tr(),
            style: TextStyle(
              fontSize: 11,
              color: widget.isDarkMode
                  ? Colors.grey.shade500
                  : Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

/// Modal dialog for barcode scanning
class _BarcodeScannerModal extends StatefulWidget {
  final MobileScannerController cameraController;

  const _BarcodeScannerModal({
    Key? key,
    required this.cameraController,
  }) : super(key: key);

  @override
  State<_BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<_BarcodeScannerModal> {
  bool _isScanning = true;
  String? _scannedValue;

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  Future<void> _startScanning() async {
    try {
      await widget.cameraController.start();
      if (mounted) {
        setState(() => _isScanning = true);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Camera permission required'.tr());
        Navigator.pop(context);
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    // Get the first barcode detected
    final List<Barcode> barcodes = capture.barcodes;
    final Barcode barcode = barcodes.first;

    if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
      setState(() {
        _scannedValue = barcode.rawValue!;
        _isScanning = false;
      });

      // Show success dialog
      _showSuccessDialog(barcode.rawValue!);
    }
  }

  void _showSuccessDialog(String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context)
            ? Colors.grey.shade900
            : Colors.white,
        title: Text(
          'Barcode Scanned'.tr(),
          style: TextStyle(
            color: isDarkMode(context) ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Value:'.tr(),
              style: TextStyle(
                color: isDarkMode(context)
                    ? Colors.grey.shade300
                    : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              value,
              style: TextStyle(
                color: isDarkMode(context)
                    ? Colors.grey.shade200
                    : Colors.black,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: Text(
              'Scan Again'.tr(),
              style: TextStyle(color: Color(cfg.colorPrimary)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
            ),
            child: Text(
              'Use This'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _resumeScanning() {
    setState(() {
      _isScanning = true;
      _scannedValue = null;
    });
  }

  @override
  void dispose() {
    widget.cameraController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan Barcode'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: widget.cameraController,
                  onDetect: _onDetect,
                ),
                // Overlay frame
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Colors.greenAccent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Instructions
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 80,
              left: 16,
              right: 16,
            ),
            child: Column(
              children: [
                Text(
                  'Point your camera at the barcode'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supports 1D and 2D barcodes'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
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
