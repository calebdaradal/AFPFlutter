import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:afpflutter/services/authentication.dart';
import 'package:afpflutter/screens/authentication/login.dart';
import 'package:afpflutter/services/api_config.dart';
import 'package:afpflutter/shared/profile_avatar_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _authService = AuthenticationService(); // Handles API calls for profile data
  final _fullNameController =
      TextEditingController(); // full name shown when name editing is off
  final _firstNameController =
      TextEditingController(); // controller used when editing first name
  final _lastNameController =
      TextEditingController(); // controller used when editing last name
  final _emailController = TextEditingController(); // email from backend
  final _phoneController =
      TextEditingController(); // phone from backend
  final _passwordController =
      TextEditingController(text: '********'); // hidden placeholder only

  bool _obscurePassword = true; // flag to show or hide password text
  bool _isEditingName =
      false; // flag that tells us if the name is currently being edited
  bool _isEditingPhone = false; // tells us if phone number is currently editable
  bool _isLoadingProfile = true; // true while initial profile data is loading
  bool _isSaving = false; // true while saving profile changes
  bool _isUploadingImage = false; // true while uploading a new profile photo
  String _profileImageRef = ''; // Mongo `image`: URL, data URI, or empty for default asset
  bool _otpEnabled = false; // Extra login protection when risk_engine marks session risky

  @override
  void initState() {
    super.initState();
    _loadProfile(); // fetch profile when screen opens
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true; // show loading state
    });
    try {
      final profile = await _authService.getProfile(); // GET /user/profile
      final firstName = (profile['first_name'] ?? '').toString();
      final lastName = (profile['last_name'] ?? '').toString();
      final fullName = [firstName, lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ');
      if (!mounted) return;
      setState(() {
        _firstNameController.text = firstName;
        _lastNameController.text = lastName;
        _fullNameController.text = fullName;
        _emailController.text = (profile['email'] ?? '').toString();
        _phoneController.text = (profile['phone_number'] ?? '').toString();
        _profileImageRef = (profile['image'] ?? '').toString().trim();
        _otpEnabled = profile['otp_enabled'] == true;
        _isLoadingProfile = false;
      });
    } on OtpReverificationRequired catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(sessionExpiredMessage: e.message),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name, last name, and phone are required.')),
      );
      return;
    }
    setState(() {
      _isSaving = true; // disable actions while saving
    });
    try {
      await _authService.updateProfile(
        firstName: firstName, // PUT /user/profile first name
        lastName: lastName, // PUT /user/profile last name
        phoneNumber: phone, // PUT /user/profile phone
        image: _profileImageRef, // Keep current photo when editing name/phone
        otpEnabled: _otpEnabled, // Keep 2FA preference in sync
      );
      final combinedName = [firstName, lastName].join(' ');
      if (!mounted) return;
      setState(() {
        _fullNameController.text = combinedName;
        _isEditingName = false;
        _isEditingPhone = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } on OtpReverificationRequired catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(sessionExpiredMessage: e.message),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  /// Pick an image from the gallery, compress, store as data URI in Mongo via PUT /user/profile.
  Future<void> _pickAndUploadProfileImage() async {
    if (_isSaving || _isUploadingImage) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    setState(() {
      _isUploadingImage = true;
    });
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large. Try another photo.')),
          );
        }
        return;
      }
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        image: dataUri,
        otpEnabled: _otpEnabled,
      );
      if (!mounted) return;
      setState(() {
        _profileImageRef = dataUri;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  /// Opens the API QR page so the user can scan the TOTP secret (public GET).
  Future<void> _openTotpSetupInBrowser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/user/setup-totp/${Uri.encodeComponent(email)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Profile switch: turn optional authenticator protection on or off.
  Future<void> _onOtpToggled(bool value) async {
    if (_isSaving || _isLoadingProfile) return;
    final prev = _otpEnabled;
    setState(() {
      _otpEnabled = value;
    });
    try {
      await _authService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        image: _profileImageRef,
        otpEnabled: value,
      );
      if (value && mounted) {
        await _openTotpSetupInBrowser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Scan the QR code in the browser to finish setup.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _otpEnabled = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update 2FA: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _firstNameController.dispose(); // dispose first name controller when widget is destroyed
    _lastNameController.dispose(); // dispose last name controller when widget is destroyed
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = (size.width * 0.08).clamp(16.0, 32.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // light grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator()) // show loader during fetch
            : SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Avatar + Edit button + ID
              const SizedBox(height: 8),
              Center(
                child: Stack(
                  clipBehavior: Clip.none, // allow edit pill to hang over edge
                  children: [
                    // Circular profile image
                    ClipOval(
                      child: ProfileAvatarImage(
                        imageRef: _profileImageRef,
                        size: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Small edit pill sitting on the bottom edge of the circle
                    Positioned(
                      bottom: -8, // negative so it sits on the edge
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadProfileImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.blueAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ID: 298120-34xj29a-239f',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  title: const Text('Authenticator (OTP)'),
                  subtitle: const Text(
                    'When on, suspicious logins require a code from your authenticator app.',
                  ),
                  value: _otpEnabled,
                  onChanged: _onOtpToggled,
                ),
              ),
              const SizedBox(height: 24),

              // Fields
              if (!_isEditingName)
                // when not editing the name, show a single full name field with an edit icon
                _ProfileField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: Colors.blue), // blue edit icon
                    onPressed: () {
                      // when the edit icon is tapped, split the existing full name into first and last name
                      final parts = _fullNameController.text
                          .trim()
                          .split(' '); // split name by space
                      _firstNameController.text =
                          parts.isNotEmpty ? parts.first : ''; // first name
                      _lastNameController.text = parts.length > 1
                          ? parts.sublist(1).join(' ')
                          : ''; // remaining text as last name
                      setState(() {
                        _isEditingName =
                            true; // switch to name editing mode so that the two fields appear
                      });
                    },
                  ),
                  readOnly: true, // full name field is display-only
                )
              else ...[
                // when editing the name, show separate first name and last name fields
                _ProfileField(
                  label: 'First Name',
                  controller: _firstNameController,
                ),
                const SizedBox(height: 16),
                _ProfileField(
                  label: 'Last Name',
                  controller: _lastNameController,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // center the action icons horizontally
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.red), // red X icon to cancel the edit
                      onPressed: () {
                        setState(() {
                          _isEditingName =
                              false; // leave the full name unchanged and exit edit mode
                        });
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.check,
                          color: Colors.green), // green check icon to save
                      onPressed: _isSaving ? null : _saveProfile, // save profile edits to backend
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _ProfileField(
                label: 'Email',
                controller: _emailController,
                readOnly: true, // email not editable in this screen
              ),
              const SizedBox(height: 16),
              _ProfileField(
                label: 'Phone Number',
                controller: _phoneController,
                trailing: IconButton(
                  icon: Icon(
                    _isEditingPhone ? Icons.check : Icons.edit, // edit/check icon state
                    size: 18,
                    color: _isEditingPhone ? Colors.green : Colors.blue,
                  ),
                  onPressed: () {
                    if (_isSaving) return; // block actions while saving
                    if (_isEditingPhone) {
                      _saveProfile(); // save phone together with current profile values
                      return;
                    }
                    setState(() {
                      _isEditingPhone = true; // enable phone editing mode
                    });
                  },
                ),
                readOnly: !_isEditingPhone, // phone editable only in edit mode
              ),
              const SizedBox(height: 16),
              _ProfileField(
                label: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                readOnly: true, // password editing is not handled here
                trailing: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One profile field: label on top, rounded white input with optional trailing icon.
class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.trailing,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? trailing;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ],
    );
  }
}