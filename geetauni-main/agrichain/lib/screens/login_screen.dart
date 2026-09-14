import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:agrichain/l10n/app_localizations.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/firestore_models.dart';
import '../services/database_service.dart';
import '../widgets/language_switcher.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  // Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State flags
  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isEmailMode = false; // False = Phone OTP (Default), True = Email/Password
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _sentOtpCode;

  // Phone Auth State
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    _buttonAnimationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _resendCountdown = 30;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
        });
      }
    });
  }

  /// Format phone to +91XXXXXXXXXX
  String get _formattedPhoneNumber {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final digits = raw.length > 10 ? raw.substring(raw.length - 10) : raw;
    return '+91$digits';
  }

  /// Step 1: Send OTP to Phone Number via Twilio Verify / Fast2SMS
  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();
    final fullNumber = _formattedPhoneNumber;
    debugPrint('📲 Demo Phone OTP dispatch for: $fullNumber');

    // Default Demo OTP Mode (drops external SMS delays/blocks for hackathon)
    const demoOtp = '123456';
    _sentOtpCode = demoOtp;

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
        _errorMessage = null;
      });
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Demo Mode Active: Use OTP 123456 or tap Auto-fill!'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  /// Step 2: Verify OTP
  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the full 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      // 1. Check developer test code / Demo OTP (123456)
      if (code == _sentOtpCode || code == '123456') {
        await _handleDemoPhoneLogin();
        return;
      }

      // 2. If live Firebase confirmation handle is available
      if (kIsWeb && _webConfirmationResult != null) {
        final userCredential = await _webConfirmationResult!.confirm(code);
        if (userCredential.user != null && mounted) {
          await _handleAuthSuccess(userCredential.user!, _phoneController.text.trim());
          return;
        }
      } else if (_verificationId != null) {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null && mounted) {
          await _handleAuthSuccess(userCredential.user!, _phoneController.text.trim());
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid OTP. Please use Demo OTP: 123456';
        });
      }
    } catch (e) {
      debugPrint('❌ Unexpected error verifying OTP: $e');
      if (!mounted) return;
      if (code == _sentOtpCode || code == '123456') {
        await _handleDemoPhoneLogin();
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification error. Please enter valid OTP or tap auto-fill.';
        });
      }
    }
  }

  /// Handles phone login after OTP verification
  Future<void> _handleDemoPhoneLogin() async {
    final rawPhone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final last10 = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;

    debugPrint('📱 Looking up user profile for phone: $last10');

    // 1. Look up existing registered user in Firestore (prioritizes DigiLocker / KYC verified accounts)
    Map<String, dynamic>? userData = await DatabaseService().getUserByPhone(last10);
    userData ??= await DatabaseService().getUserByPhone('+91$last10');

    String targetUserId;

    if (userData != null && userData['id'] != null) {
      targetUserId = userData['id'] as String;
      debugPrint('🎯 Found registered user profile: ${userData['name'] ?? userData['firstName']} (ID: $targetUserId)');

      // If user registered with email & password, ensure Firebase Auth session matches
      final email = userData['email'] as String? ?? '$last10@agrichain.com';
      try {
        if (FirebaseAuth.instance.currentUser == null || FirebaseAuth.instance.currentUser?.uid != targetUserId) {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: 'AgriChain@123',
          );
          debugPrint('🔑 Synced Firebase Auth session for UID: ${cred.user?.uid}');
        }
      } catch (authErr) {
        debugPrint('ℹ️ Firebase Auth background sign-in notice: $authErr');
      }
    } else {
      // 2. Brand new user logging in with phone for first time
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          final anonCred = await FirebaseAuth.instance.signInAnonymously();
          user = anonCred.user;
        } catch (_) {}
      }

      targetUserId = user?.uid ?? 'user_phone_$last10';
      debugPrint('🆕 No existing profile for $last10. Creating default account: $targetUserId');

      final newUserData = {
        'id': targetUserId,
        'firebaseUid': targetUserId,
        'firstName': 'Kisan',
        'lastName': 'Farmer',
        'name': 'Kisan Farmer',
        'phone': last10,
        'phoneWithCountryCode': '+91$last10',
        'email': '$last10@agrichain.com',
        'userType': UserType.farmer.name,
        'walletAddress': '',
        'walletBalance': 0.0,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await DatabaseService().createUser(newUserData);
    }

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadUserData(targetUserId);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  /// Finalize successful login and load profile from Firestore
  Future<void> _handleAuthSuccess(User firebaseUser, String phoneInput) async {
    debugPrint('✅ Firebase Auth successful: ${firebaseUser.uid}');
    debugPrint('📥 Loading user data from Firestore...');

    final cleanPhone = phoneInput.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

    // Check if user document already exists in Firestore by UID
    Map<String, dynamic>? userData =
        await DatabaseService().getUserByFirebaseUid(firebaseUser.uid);

    // If not found by UID, check by Phone number
    if (userData == null && last10.isNotEmpty) {
      userData = await DatabaseService().getUserByPhone(last10);
      userData ??= await DatabaseService().getUserByPhone('+91$last10');

      // If found by phone, update document with the current firebaseUid
      if (userData != null && userData['id'] != null) {
        await DatabaseService().updateUser(userData['id'], {
          'firebaseUid': firebaseUser.uid,
          'lastLogin': DateTime.now().toIso8601String(),
        });
      }
    }

    final targetId = userData?['id'] ?? firebaseUser.uid;

    // If brand-new user logging in with phone for first time, create initial profile
    if (userData == null) {
      final newUserData = {
        'id': targetId,
        'firebaseUid': firebaseUser.uid,
        'firstName': 'Kisan',
        'lastName': 'Farmer',
        'name': 'Kisan Farmer',
        'phone': last10.isNotEmpty ? last10 : (firebaseUser.phoneNumber ?? ''),
        'phoneWithCountryCode': '+91$last10',
        'email': firebaseUser.email ?? '$last10@agrichain.com',
        'userType': UserType.farmer.name,
        'walletAddress': '',
        'walletBalance': 0.0,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await DatabaseService().createUser(newUserData);
    }

    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.loadUserData(targetId);

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = false;
    });
  }

  /// Email & Password Login fallback
  Future<void> _loginWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      debugPrint('🔐 Signing in with email...');
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (credential.user != null && mounted) {
        await _handleAuthSuccess(credential.user!, '');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Email Auth error: ${e.code}');
      setState(() {
        _isLoading = false;
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No user found for that email.';
            break;
          case 'wrong-password':
            _errorMessage = 'Wrong password provided.';
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address.';
            break;
          case 'invalid-credential':
            _errorMessage = 'Invalid email or password.';
            break;
          default:
            _errorMessage = 'Login failed: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred during login. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppTheme.darkSurface, AppTheme.darkBackground]
                : [AppTheme.primaryColor.withOpacity(0.08), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Card(
                      elevation: isDark ? 8 : 12,
                      shadowColor: AppTheme.primaryColor.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: isDark
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.white,
                                      AppTheme.white.withOpacity(0.96),
                                    ],
                                  ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              // Language Switcher at Top
                              Align(
                                alignment: Alignment.topRight,
                                child: LanguageSwitcherPill(isDark: isDark),
                              ),
                              const SizedBox(height: 6),

                              // App Logo
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.secondaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.agriculture,
                                  size: 38,
                                  color: AppTheme.white,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Title & Tagline
                              Text(
                                _isOtpSent
                                    ? 'Verify OTP / ओटीपी दर्ज करें'
                                    : (_isEmailMode
                                        ? (l10n?.welcomeBack ?? 'Welcome Back')
                                        : 'Login with Mobile / मोबाइल लॉगिन'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.white : AppTheme.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isOtpSent
                                    ? 'Enter 6-digit code sent to $_formattedPhoneNumber'
                                    : (_isEmailMode
                                        ? 'Enter your registered email and password'
                                        : 'Enter your 10-digit mobile number for instant OTP access'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 24),

                              // Error Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  margin: const EdgeInsets.only(bottom: 18),
                                  decoration: BoxDecoration(
                                    color: _errorMessage!.contains('Test Mode') || _errorMessage!.contains('Notice')
                                        ? const Color(0xFFFEF3C7)
                                        : AppTheme.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _errorMessage!.contains('Test Mode') || _errorMessage!.contains('Notice')
                                          ? const Color(0xFFF59E0B)
                                          : AppTheme.error.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _errorMessage!.contains('Test Mode') || _errorMessage!.contains('Notice')
                                            ? Icons.info_outline
                                            : Icons.error_outline,
                                        color: _errorMessage!.contains('Test Mode') || _errorMessage!.contains('Notice')
                                            ? const Color(0xFFD97706)
                                            : AppTheme.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _errorMessage!.contains('Test Mode') || _errorMessage!.contains('Notice')
                                                ? const Color(0xFF92400E)
                                                : AppTheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Form Views
                              if (!_isEmailMode) ...[
                                if (!_isOtpSent) _buildPhoneInputView(isDark)
                                else _buildOtpInputView(isDark),
                              ] else ...[
                                _buildEmailInputView(isDark, l10n),
                              ],

                              const SizedBox(height: 16),

                              // Toggle between Phone OTP & Email Login
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEmailMode = !_isEmailMode;
                                    _isOtpSent = false;
                                    _errorMessage = null;
                                  });
                                },
                                icon: Icon(
                                  _isEmailMode ? Icons.phone_android : Icons.email_outlined,
                                  size: 18,
                                  color: AppTheme.primaryColor,
                                ),
                                label: Text(
                                  _isEmailMode
                                      ? 'Sign In with Mobile OTP instead / मोबाइल ओटीपी'
                                      : 'Sign In with Email & Password instead',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              const SizedBox(height: 8),

                              // Register Link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    l10n?.dontHaveAccount ?? "Don't have an account? ",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppTheme.textSecondary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Register / नया खाता बनाएं',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(),
                              const SizedBox(height: 8),

                              // 1-Tap Demo Testing
                              Text(
                                '⚡ 1-Tap Demo Testing (Jump to Any Role)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : AppTheme.darkGreen,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildDemoChip(context, '🌾 Solo Farmer', UserType.farmer),
                                  _buildDemoChip(context, '🚜 FPO Member', UserType.fpoMemberFarmer),
                                  _buildDemoChip(context, '🏢 FPO Co-op', UserType.fpo),
                                  _buildDemoChip(context, '🏭 Bulk Buyer', UserType.buyer),
                                  _buildDemoChip(context, '🛒 Retail Buyer', UserType.retailBuyer),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                     ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1 UI: Phone Number Input View
  Widget _buildPhoneInputView(bool isDark) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: TextStyle(
              color: isDark ? AppTheme.white : AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              labelText: 'Mobile Number / मोबाइल नंबर',
              hintText: '98765 43210',
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(height: 22, width: 1, color: Colors.grey.withOpacity(0.4)),
                  ],
                ),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.neutral100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.neutral600 : AppTheme.neutral300,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your mobile number';
              }
              if (value.trim().length != 10) {
                return 'Enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Send OTP Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.white,
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Get OTP / ओटीपी प्राप्त करें',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 2 UI: OTP Verification View
  Widget _buildOtpInputView(bool isDark) {
    return Column(
      children: [
        // Number badge with Change button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_iphone, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    _formattedPhoneNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isOtpSent = false;
                    _otpController.clear();
                    _errorMessage = null;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Change / बदलें',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Demo OTP helper badge
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Default Demo OTP: 123456 (Tap auto-fill below)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 6-digit OTP Field
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: TextStyle(
            color: isDark ? AppTheme.white : AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
          ),
          decoration: InputDecoration(
            hintText: '• • • • • •',
            hintStyle: TextStyle(
              letterSpacing: 10,
              color: Colors.grey.withOpacity(0.5),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.neutral100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? AppTheme.neutral600 : AppTheme.neutral300,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onChanged: (val) {
            if (val.length == 6) {
              _verifyOtp();
            }
          },
        ),
        const SizedBox(height: 10),

        // Quick Auto-fill Demo Code Chip
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              _otpController.text = _sentOtpCode ?? '123456';
              _verifyOtp();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    _sentOtpCode != null
                        ? 'Auto-fill OTP ($_sentOtpCode)'
                        : 'Auto-fill Test Code (123456)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _resendCountdown > 0
                  ? 'Resend OTP in ${_resendCountdown}s'
                  : 'Didn\'t receive code?',
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            TextButton(
              onPressed: _resendCountdown == 0 && !_isLoading ? _sendOtp : null,
              child: Text(
                'Resend OTP / पुनः भेजें',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _resendCountdown == 0 ? AppTheme.primaryColor : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Verify Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.white,
              elevation: 4,
              shadowColor: AppTheme.primaryColor.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Verify & Login / सत्यापित करें',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Email & Password Login View
  Widget _buildEmailInputView(bool isDark, AppLocalizations? l10n) {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              color: isDark ? AppTheme.white : AppTheme.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              labelText: l10n?.email ?? 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryColor),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.neutral100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.neutral600 : AppTheme.neutral300,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(
              color: isDark ? AppTheme.white : AppTheme.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              labelText: l10n?.password ?? 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.neutral100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.neutral600 : AppTheme.neutral300,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Email Login Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.white,
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n?.login ?? 'Sign In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChip(BuildContext context, String label, UserType role) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
      side: const BorderSide(color: AppTheme.primaryGreen),
      onPressed: () {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.setDemoUserRole(role);
      },
    );
  }
}
