import 'package:flutter/material.dart'; // Flutter UI toolkit
import 'package:mobile_scanner/mobile_scanner.dart'; // QR scanning via camera

/// Simple QR scanner screen that returns the scanned value via Navigator.pop(result). // Returns scan result
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({
    super.key,
    this.title = 'Scan QR', // Optional title
    this.accentColor = Colors.white, // Default corner color
  });

  final String title; // App bar title
  final Color accentColor; // Corner accents color (IN/OUT)

  @override
  State<QrScannerPage> createState() => _QrScannerPageState(); // Create state
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(); // Camera/scanner controller
  bool _didReturnResult = false; // Prevent duplicate pops

  @override
  void dispose() {
    _controller.dispose(); // Release camera resources
    super.dispose(); // Dispose base state
  }

  void _returnResult(String value) {
    if (_didReturnResult) return; // Guard against multiple detections
    _didReturnResult = true; // Mark as returned
    Navigator.of(context).pop(value); // Return scanned value
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width; // Screen width
    final scanWindowSize = (screenWidth * 0.70).clamp(220.0, 320.0); // Center square size

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title), // Screen title
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(), // Toggle flashlight
            icon: const Icon(Icons.flash_on), // Flash icon
            tooltip: 'Torch', // Accessibility tooltip
          ),
          IconButton(
            onPressed: () => _controller.switchCamera(), // Switch front/back camera
            icon: const Icon(Icons.cameraswitch), // Switch icon
            tooltip: 'Switch camera', // Accessibility tooltip
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand, // Fill available space
          children: [
            MobileScanner(
              controller: _controller, // Use our controller
              onDetect: (capture) {
                final barcodes = capture.barcodes; // Detected barcodes
                if (barcodes.isEmpty) return; // Nothing detected
                final rawValue = barcodes.first.rawValue; // Use first value
                if (rawValue == null || rawValue.trim().isEmpty) return; // Ignore empty
                _returnResult(rawValue.trim()); // Return to caller
              },
            ),
            IgnorePointer(
              ignoring: true, // Overlay is visual-only
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  cutOutSize: scanWindowSize, // Center cut-out square size
                  accentColor: widget.accentColor, // Accent color for corners
                ),
                child: const SizedBox.expand(), // Fill entire screen
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter, // Bottom overlay
              child: Container(
                color: Colors.black54, // Readable overlay background
                padding: const EdgeInsets.all(12), // Spacing
                child: const Text(
                  'Point your camera at a QR code', // Simple instruction
                  style: TextStyle(color: Colors.white), // White text on dark bg
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({required this.cutOutSize, required this.accentColor}); // Painter constructor

  final double cutOutSize; // Size of transparent square
  final Color accentColor; // Corner color (IN/OUT)

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65) // Darken background
      ..style = PaintingStyle.fill; // Solid fill

    final center = Offset(size.width / 2, size.height / 2); // Screen center
    final cutOutRect = Rect.fromCenter(
      center: center, // Centered cutout
      width: cutOutSize, // Cutout width
      height: cutOutSize, // Cutout height
    );

    // Darken everything except the cutout area. // Opaque background with clear square
    final fullScreenPath = Path()..addRect(Offset.zero & size); // Full screen path
    final cutOutPath = Path()..addRRect(RRect.fromRectXY(cutOutRect, 12, 12)); // Rounded square
    final overlayPath = Path.combine(
      PathOperation.difference, // Subtract cutout
      fullScreenPath, // From full screen
      cutOutPath, // Remove center cutout
    );
    canvas.drawPath(overlayPath, overlayPaint); // Draw overlay

    // Optional corner accents for better guidance. // Corner brackets
    final cornerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.95) // Corner color
      ..style = PaintingStyle.stroke // Lines only
      ..strokeWidth = 5 // Thicker corners
      ..strokeCap = StrokeCap.round; // Rounded ends

    final cornerLength = (cutOutSize * 0.13).clamp(18.0, 34.0); // Corner length
    final left = cutOutRect.left; // Left edge
    final right = cutOutRect.right; // Right edge
    final top = cutOutRect.top; // Top edge
    final bottom = cutOutRect.bottom; // Bottom edge

    // Top-left corner. // Corner lines
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint); // Horizontal
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), cornerPaint); // Vertical
    // Top-right corner. // Corner lines
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), cornerPaint); // Horizontal
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint); // Vertical
    // Bottom-left corner. // Corner lines
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint); // Horizontal
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), cornerPaint); // Vertical
    // Bottom-right corner. // Corner lines
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), cornerPaint); // Horizontal
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), cornerPaint); // Vertical
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.cutOutSize != cutOutSize || oldDelegate.accentColor != accentColor; // Repaint on change
  }
}
