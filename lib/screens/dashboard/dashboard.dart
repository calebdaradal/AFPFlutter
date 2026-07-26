import 'package:flutter/material.dart';
import 'package:afpflutter/services/authentication.dart';
import 'package:afpflutter/services/record_service.dart';
import 'package:afpflutter/screens/authentication/login.dart';
import 'package:afpflutter/screens/qr/qr_scanner_page.dart'; // QR scanner screen
import 'package:afpflutter/screens/customer/customer_record_details_page.dart';
import 'package:afpflutter/shared/profile_avatar_image.dart';
import 'package:afpflutter/services/api_config.dart';
import 'package:afpflutter/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Landing screen design: header (profile + welcome + logout), SCAN QR, QR with L-brackets, IN/OUT buttons.
class _DashboardColors {
  static const Color scanQrText = Colors.black;
  static const Color inButtonGreen = Color(0xFF4CAF50);
  static const Color outButtonRed = Color(0xFFE53935);
}

class Dashboard extends StatefulWidget {
  const Dashboard({
    super.key,
    this.showOtpSetupPromptAfterLogin = false,
  });

  /// After password login: show one-time optional OTP enrollment modal.
  final bool showOtpSetupPromptAfterLogin;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final AuthenticationService _authService = AuthenticationService(); // Handles profile lookup
  final RecordService _recordService = RecordService(); // Handles scan -> record creation
  final LocationService _locationService = LocationService(); // Added: reads device coordinates before sending scan
  String _displayName = 'User'; // Default fallback name
  String _profileImageRef = ''; // API `image` field — empty uses default asset in [ProfileAvatarImage]
  bool _isProcessingScan = false; // Prevent duplicate scan submissions

  String _normalizePasscardIdFromQr(String raw) { // added: normalize QR payload into a passcard id
    final value = raw.trim(); // added: trim whitespace
    if (value.isEmpty) return ''; // added: empty guard
    final lower = value.toLowerCase(); // added: case-insensitive prefix match
    if (lower.startsWith('vpccode:')) { // changed: new QR format: vpccode:{raw passcard id}
      return value.substring(8).trim(); // changed: strip "vpccode:" and trim the remainder
    } // changed: end vpccode: handling
    return value; // added: backward-compatible fallback (raw id)
  } // added: end normalizer

  @override
  void initState() {
    super.initState();
    _loadProfileHeader(); // Fetch logged-in user name and profile photo
    if (widget.showOtpSetupPromptAfterLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOptionalOtpSetupDialog());
    }
  }

  /// Modal: Yes enables OTP + opens TOTP QR URL; No thanks snoozes until next periodic nudge.
  Future<void> _showOptionalOtpSetupDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add authenticator protection?'),
          content: const Text(
            'You can use an authenticator app for extra verification when we detect a risky login (new IP, repeated failures). '
            'You can also change this anytime in Profile.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await _authService.submitOtpSetupPromptAccepted(false);
                } catch (_) {}
              },
              child: const Text('No thanks'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final res = await _authService.submitOtpSetupPromptAccepted(true);
                  final path = res['setup_totp_path'] as String?;
                  if (path != null && path.isNotEmpty && mounted) {
                    final uri = Uri.parse('${ApiConfig.baseUrl}/$path');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scan the QR in your browser to finish authenticator setup.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not enable OTP: $e')),
                    );
                  }
                }
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadProfileHeader() async {
    try {
      final profile = await _authService.getProfile(); // Uses authenticated profile endpoint
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final fullName = [firstName, lastName]
          .where((part) => part.isNotEmpty)
          .join(' ');
      final image = (profile['image'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _displayName = fullName.isEmpty ? _displayName : fullName;
        _profileImageRef = image; // Same string shown on profile settings and here
      });
    } on OtpReverificationRequired catch (e) {
      if (!mounted) return;
      _goToLoginAfterOtpPolicy(e.message);
    } catch (_) {
      // Keep fallbacks if profile fetch fails.
    }
  }

  /// Session cleared server-side: show login with explanation (7-day OTP policy).
  void _goToLoginAfterOtpPolicy(String message) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(sessionExpiredMessage: message),
      ),
      (route) => false,
    );
  }

  Future<void> _showCenteredErrorModal(String message) async { // added: show a centered modal dialog for scan errors (e.g., invalid passcard)
    if (!mounted) return; // added: ensure widget is still mounted before showing dialog
    await showDialog<void>( // added: show a blocking dialog
      context: context, // added: use current context
      builder: (ctx) { // added: dialog builder
        return AlertDialog( // added: material modal centered on screen
          title: const Text('Error'), // added: dialog title
          content: Text(message), // added: dialog body message
          actions: [ // added: action buttons
            TextButton( // added: dismiss button
              onPressed: () => Navigator.of(ctx).pop(), // added: close dialog
              child: const Text('OK'), // added: button label
            ), // added: end button
          ], // added: end actions
        ); // added: end dialog
      }, // added: end builder
    ); // added: end showDialog
  } // added: end helper

  Future<void> _scanForAction(BuildContext context, {required String actionLabel}) async {
    if (_isProcessingScan) return;
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

    setState(() {
      _isProcessingScan = true;
    });
    try {
      final passcardId = _normalizePasscardIdFromQr(scannedValue); // added: parse vpc:{id} QR payload into raw passcard id
      final coordinates = await _locationService.getCurrentCoordinates(); // added: capture device coordinates before posting scan
      final response = await _recordService.createRecordFromScan(
        passcardId: passcardId, // changed: send normalized raw passcard id to backend
        type: actionLabel, // unchanged: IN or OUT
        longitude: coordinates.longitude, // added: send current device longitude
        latitude: coordinates.latitude, // added: send current device latitude
      );
      if (!mounted) return;
      final owner = response['owner'] as Map<String, dynamic>? ?? {}; // changed: owner details from new backend
      final passcard = response['passcard'] as Map<String, dynamic>? ?? {}; // added: passcard details for owner section labels
      Map<String, dynamic> vehicle = response['vehicle'] as Map<String, dynamic>? ?? {}; // changed: single vehicle tied to passcard
      final passcardStatus = response['passcard_status']?.toString() ?? ''; // added: passcard status to display at top of modal
      if (vehicle.isEmpty) { // added: backwards-compat in case API still returns `vehicles` list from older builds
        final vehicles = response['vehicles'] as List<dynamic>? ?? []; // added: read legacy vehicles list key
        if (vehicles.isNotEmpty && vehicles.first is Map) { // added: ensure first element is a map
          vehicle = Map<String, dynamic>.from(vehicles.first as Map); // added: use the first vehicle as the single vehicle
        } // added: end legacy fallback
      } // added: end vehicle fallback
      final imageProxyPath = vehicle['image_proxy_path']?.toString() ?? ''; // added: local API streaming fallback for image loading
      if (imageProxyPath.isNotEmpty) { // added: build full URL from ApiConfig
        vehicle['image_proxy_url'] = '${ApiConfig.baseUrl}/$imageProxyPath'; // added: store proxy URL into vehicle map
      } // added: end proxy URL
      final dOwnerProxyPath = vehicle['d_owner_image_proxy_path']?.toString() ?? ''; // changed: local API streaming fallback for d_owner image loading
      if (dOwnerProxyPath.isNotEmpty) { // changed: build full URL from ApiConfig for d_owner
        vehicle['d_owner_image_proxy_url'] = '${ApiConfig.baseUrl}/$dOwnerProxyPath'; // changed: store d_owner proxy URL into vehicle map
      } // changed: end d_owner proxy URL
      final record = response['record'] as Map<String, dynamic>? ?? {};
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CustomerRecordDetailsPage( // changed: page now shows owner + vehicles from passcard scan
            owner: owner, // changed: pass owner map
            vehicle: vehicle, // changed: pass vehicle map
            passcard: passcard, // added: pass passcard map
            record: record, // unchanged: scan metadata (type/date/time)
            passcardStatus: passcardStatus, // added: show passcard status above owner status
          ), // changed: end page constructor
        ),
      );
    } on OtpReverificationRequired catch (e) {
      if (!mounted) return;
      _goToLoginAfterOtpPolicy(e.message);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString(); // added: get error string
      final msg = raw.replaceFirst('Exception: ', '').trim(); // added: extract message from Exception formatting
      if (msg == 'Sorry invalid passcard') { // added: show invalid passcard as centered modal
        await _showCenteredErrorModal(msg); // added: modal for invalid passcard
        return; // added: stop further snackbar handling for this case
      } // added: end invalid passcard check
      ScaffoldMessenger.of(context).showSnackBar( // changed: keep snackbar for other errors
        SnackBar(content: Text('Scan failed: $msg')), // changed: show cleaned message
      ); // changed: end snackbar
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessingScan = false;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await _authService.clearToken();
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
                      onTap: () async {
                        await Navigator.pushNamed(context, '/profile-settings');
                        if (mounted) await _loadProfileHeader();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          ClipOval(
                            child: ProfileAvatarImage(
                              imageRef: _profileImageRef,
                              size: 52,
                              fit: BoxFit.cover,
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
                                _displayName,
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
                    onPressed: _isProcessingScan ? null : () => _handleLogout(context),
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
                                onPressed: _isProcessingScan
                                    ? null
                                    : () => _scanForAction(context, actionLabel: 'IN'), // Open QR scanner
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ScanActionButton(
                                label: 'OUT',
                                filled: false,
                                color: _DashboardColors.outButtonRed,
                                onPressed: _isProcessingScan
                                    ? null
                                    : () => _scanForAction(context, actionLabel: 'OUT'), // Open QR scanner
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isProcessingScan)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Center(child: CircularProgressIndicator()),
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
  final VoidCallback? onPressed;

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
