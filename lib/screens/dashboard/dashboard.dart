import 'package:flutter/material.dart';
import 'package:afpflutter/services/authentication.dart';
import 'package:afpflutter/screens/authentication/login.dart';
import 'package:afpflutter/screens/qr/qr_scanner_page.dart'; // QR scanner screen

/// Landing screen design: header (profile + welcome + logout), SCAN QR, QR with L-brackets, IN/OUT buttons.
class _DashboardColors {
  static const Color scanQrText = Colors.black;
  static const Color inButtonGreen = Color(0xFF4CAF50);
  static const Color outButtonRed = Color(0xFFE53935);
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  Future<void> _scanForAction(BuildContext context, {required String actionLabel}) async {
    final accentColor = (actionLabel == 'IN') // Determine corner color
        ? _DashboardColors.inButtonGreen // IN -> green corners
        : _DashboardColors.outButtonRed; // OUT -> red corners

    // Open scanner and wait for a QR value to be returned. // Scan QR for IN/OUT
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => QrScannerPage(
          title: 'Scan QR ($actionLabel)', // Title indicates action
          accentColor: accentColor, // Pass IN/OUT color to corners
        ),
      ),
    );
    if (!context.mounted) return; // Ensure context is still valid
    if (scannedValue == null) return; // User backed out / no scan

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$actionLabel scanned: $scannedValue')), // Temporary feedback
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthenticationService();
    await authService.clearToken();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Responsive: constrain content width on tablets
    final maxContentWidth = (screenWidth * 0.85).clamp(320.0, 500.0);
    final horizontalPadding = (screenWidth * 0.09).clamp(24.0, 48.0);
    // QR size scales with screen
    final qrSize = (screenWidth * 0.6).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header area (custom app bar): light grey background, no bottom border
            Container(
              color: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Entire profile section (avatar + text) is tappable
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/profile-settings');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          ClipOval(
                            child: Image.asset(
                              'depositphotos_745925384-stock-photo-businessman-portrait-outdoor-smiling-mature.webp',
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.person, size: 28),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'James Andrews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => _handleLogout(context),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: screenHeight * 0.06),
                    Text(
                      'SCAN QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _DashboardColors.scanQrText,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Image.asset(
                        'QR-Example.png',
                        width: qrSize,
                        height: qrSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ScanActionButton(
                                label: 'IN',
                                filled: true,
                                color: _DashboardColors.inButtonGreen,
                                onPressed: () => _scanForAction(context, actionLabel: 'IN'), // Open QR scanner
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ScanActionButton(
                                label: 'OUT',
                                filled: false,
                                color: _DashboardColors.outButtonRed,
                                onPressed: () => _scanForAction(context, actionLabel: 'OUT'), // Open QR scanner
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IN (filled green) or OUT (white with red border) button.
class _ScanActionButton extends StatelessWidget {
  const _ScanActionButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : Colors.white,
          foregroundColor: filled ? Colors.white : color,
          side: filled ? null : BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
