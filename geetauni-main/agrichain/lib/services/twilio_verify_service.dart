import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class TwilioVerifyResult {
  final bool success;
  final String? status;
  final String? message;
  final String? error;
  final int? statusCode;

  const TwilioVerifyResult({
    required this.success,
    this.status,
    this.message,
    this.error,
    this.statusCode,
  });
}

class TwilioVerifyService {
  static final TwilioVerifyService _instance = TwilioVerifyService._internal();
  factory TwilioVerifyService() => _instance;
  TwilioVerifyService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  String get _accountSid => AppConfig.twilioAccountSid;
  String get _authToken => AppConfig.twilioAuthToken;
  String get _serviceSid => AppConfig.twilioVerifyServiceSid;

  String get _authHeader {
    final bytes = utf8.encode('$_accountSid:$_authToken');
    return 'Basic ${base64Encode(bytes)}';
  }

  /// Format phone to international E.164 (e.g. +91XXXXXXXXXX)
  String formatPhoneNumber(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    final last10 = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return '+91$last10';
  }

  /// Dispatch real cellular SMS with OTP to mobile number via Twilio Verify API
  Future<TwilioVerifyResult> sendOtp({
    required String phoneNumber,
  }) async {
    final fullNumber = formatPhoneNumber(phoneNumber);

    if (_accountSid.isEmpty || _authToken.isEmpty || _serviceSid.isEmpty) {
      return const TwilioVerifyResult(
        success: false,
        error: 'Twilio credentials not configured in .env',
      );
    }

    debugPrint('📲 Twilio Verify: Dispatching real SMS OTP to $fullNumber...');

    try {
      final response = await _dio.post(
        'https://verify.twilio.com/v2/Services/$_serviceSid/Verifications',
        options: Options(
          headers: {
            'Authorization': _authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: {
          'To': fullNumber,
          'Channel': 'sms',
        },
      );

      debugPrint('📩 Twilio Verify Dispatch Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is Map ? response.data as Map : {};
        final status = data['status']?.toString();
        if (status == 'pending' || status == 'approved') {
          return TwilioVerifyResult(
            success: true,
            status: status,
            message: 'SMS delivered to $fullNumber via Twilio!',
          );
        }
      }
    } on DioException catch (e) {
      debugPrint('❌ Twilio Verify Dio Error: ${e.response?.data ?? e.message}');
      if (e.response?.data != null && e.response?.data is Map) {
        final data = e.response!.data as Map;
        final msg = data['message']?.toString() ?? e.message;
        final code = data['code'] as int?;
        return TwilioVerifyResult(
          success: false,
          error: msg,
          statusCode: code,
        );
      }
      return TwilioVerifyResult(
        success: false,
        error: e.message ?? 'Network error connecting to Twilio',
      );
    } catch (e) {
      debugPrint('❌ Twilio Verify Unknown Exception: $e');
      return TwilioVerifyResult(
        success: false,
        error: e.toString(),
      );
    }

    return const TwilioVerifyResult(
      success: false,
      error: 'Unexpected response from Twilio Verify',
    );
  }

  /// Verify entered OTP code with Twilio Verify API
  Future<TwilioVerifyResult> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final cleanCode = code.trim();
    final fullNumber = formatPhoneNumber(phoneNumber);

    // Fast-path developer fallback
    if (cleanCode == '123456') {
      return const TwilioVerifyResult(
        success: true,
        status: 'approved',
        message: 'Developer test code accepted',
      );
    }

    if (_accountSid.isEmpty || _authToken.isEmpty || _serviceSid.isEmpty) {
      return const TwilioVerifyResult(
        success: false,
        error: 'Twilio credentials not configured in .env',
      );
    }

    debugPrint('🔍 Twilio Verify: Checking code for $fullNumber...');

    try {
      final response = await _dio.post(
        'https://verify.twilio.com/v2/Services/$_serviceSid/VerificationCheck',
        options: Options(
          headers: {
            'Authorization': _authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: {
          'To': fullNumber,
          'Code': cleanCode,
        },
      );

      debugPrint('📩 Twilio Verify Check Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is Map ? response.data as Map : {};
        final status = data['status']?.toString();
        final valid = data['valid'] == true;

        if (status == 'approved' || valid) {
          return TwilioVerifyResult(
            success: true,
            status: 'approved',
            message: 'OTP verified successfully via Twilio!',
          );
        } else {
          return const TwilioVerifyResult(
            success: false,
            status: 'pending',
            error: 'Incorrect OTP code. Please check your SMS and try again.',
          );
        }
      }
    } on DioException catch (e) {
      debugPrint('❌ Twilio Verify Check Error: ${e.response?.data ?? e.message}');
      if (e.response?.data != null && e.response?.data is Map) {
        final data = e.response!.data as Map;
        final code = data['code'] as int?;
        String msg = data['message']?.toString() ?? (e.message ?? 'Verification failed');
        if (code == 20404 || msg.contains('was not found')) {
          msg = 'OTP expired or already used. Please tap "Resend OTP / पुनः भेजें" for a fresh code.';
        }
        return TwilioVerifyResult(
          success: false,
          error: msg,
          statusCode: code,
        );
      }
      return TwilioVerifyResult(
        success: false,
        error: e.message ?? 'Network error verifying code',
      );
    } catch (e) {
      debugPrint('❌ Twilio Verify Check Exception: $e');
      return TwilioVerifyResult(
        success: false,
        error: e.toString(),
      );
    }

    return const TwilioVerifyResult(
      success: false,
      error: 'Unable to verify code with Twilio',
    );
  }
}
