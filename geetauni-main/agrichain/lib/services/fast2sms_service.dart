import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class Fast2SmsResult {
  final bool success;
  final String otp;
  final String? message;
  final String? error;
  final int? statusCode;

  const Fast2SmsResult({
    required this.success,
    required this.otp,
    this.message,
    this.error,
    this.statusCode,
  });
}

class Fast2SmsService {
  static final Fast2SmsService _instance = Fast2SmsService._internal();
  factory Fast2SmsService() => _instance;
  Fast2SmsService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  String get _apiKey => AppConfig.fast2smsApiKey;

  /// Generate a cryptographically random 6-digit OTP
  String generateOtp() {
    final random = Random();
    final code = 100000 + random.nextInt(900000);
    return code.toString();
  }

  /// Dispatch real cellular SMS with OTP to an Indian mobile number
  Future<Fast2SmsResult> sendOtp({
    required String phoneNumber,
    String? customOtp,
  }) async {
    final otp = customOtp ?? generateOtp();
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final number10 = cleanPhone.length > 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    if (number10.length != 10) {
      return Fast2SmsResult(
        success: false,
        otp: otp,
        error: 'Invalid 10-digit mobile number',
      );
    }

    if (_apiKey.isEmpty) {
      return Fast2SmsResult(
        success: false,
        otp: otp,
        error: 'Fast2SMS API key not configured in .env',
      );
    }

    debugPrint('📲 Fast2SMS: Sending real OTP to $number10...');

    // Method 1: Try GET request (standard for OTP route in Fast2SMS dev docs)
    try {
      final getResponse = await _dio.get(
        'https://www.fast2sms.com/dev/bulkV2',
        queryParameters: {
          'authorization': _apiKey,
          'route': 'otp',
          'variables_values': otp,
          'numbers': number10,
        },
      );

      debugPrint('📩 Fast2SMS GET Response: ${getResponse.statusCode} - ${getResponse.data}');

      if (getResponse.statusCode == 200 && getResponse.data != null) {
        final data = getResponse.data is Map ? getResponse.data as Map : {};
        if (data['return'] == true) {
          return Fast2SmsResult(
            success: true,
            otp: otp,
            message: 'SMS delivered successfully to $number10 via Fast2SMS!',
          );
        } else {
          final msg = data['message']?.toString() ?? 'SMS failed to dispatch';
          final code = data['status_code'] as int?;
          return Fast2SmsResult(
            success: false,
            otp: otp,
            error: msg,
            statusCode: code,
          );
        }
      }
    } on DioException catch (e) {
      debugPrint('⚠️ Fast2SMS GET failed, trying POST fallback: ${e.message}');
    } catch (e) {
      debugPrint('⚠️ Fast2SMS GET exception: $e');
    }

    // Method 2: Fallback to POST with JSON
    try {
      final response = await _dio.post(
        'https://www.fast2sms.com/dev/bulkV2',
        options: Options(
          headers: {
            'authorization': _apiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'route': 'otp',
          'variables_values': otp,
          'numbers': number10,
        },
      );

      debugPrint('📩 Fast2SMS POST Response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data as Map : {};
        if (data['return'] == true) {
          return Fast2SmsResult(
            success: true,
            otp: otp,
            message: 'SMS delivered successfully to $number10 via Fast2SMS!',
          );
        } else {
          final msg = data['message']?.toString() ?? 'SMS failed to dispatch';
          final code = data['status_code'] as int?;
          return Fast2SmsResult(
            success: false,
            otp: otp,
            error: msg,
            statusCode: code,
          );
        }
      }
    } on DioException catch (e) {
      debugPrint('❌ Fast2SMS Dio Error: ${e.response?.data ?? e.message}');
      if (e.response?.data != null && e.response?.data is Map) {
        final data = e.response!.data as Map;
        final msg = data['message']?.toString() ?? e.message;
        final code = data['status_code'] as int?;
        return Fast2SmsResult(
          success: false,
          otp: otp,
          error: msg,
          statusCode: code,
        );
      }
      return Fast2SmsResult(
        success: false,
        otp: otp,
        error: e.message ?? 'Network error connecting to Fast2SMS',
      );
    } catch (e) {
      debugPrint('❌ Fast2SMS Unknown Exception: $e');
      return Fast2SmsResult(
        success: false,
        otp: otp,
        error: e.toString(),
      );
    }

    return Fast2SmsResult(
      success: false,
      otp: otp,
      error: 'Unexpected response from Fast2SMS',
    );
  }

  /// Dispatch custom text SMS (e.g. DBT Payout alerts)
  static Future<Fast2SmsResult> sendCustomSms({
    required String mobileNumber,
    required String message,
  }) async {
    return _instance._sendCustomSmsInternal(
      mobileNumber: mobileNumber,
      message: message,
    );
  }

  Future<Fast2SmsResult> _sendCustomSmsInternal({
    required String mobileNumber,
    required String message,
  }) async {
    final cleanPhone = mobileNumber.replaceAll(RegExp(r'\D'), '');
    final number10 = cleanPhone.length > 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    if (number10.length != 10) {
      return const Fast2SmsResult(
        success: false,
        otp: '',
        error: 'Invalid 10-digit mobile number',
      );
    }

    if (_apiKey.isEmpty) {
      return const Fast2SmsResult(
        success: false,
        otp: '',
        error: 'Fast2SMS API key not configured',
      );
    }

    try {
      final response = await _dio.post(
        'https://www.fast2sms.com/dev/bulkV2',
        options: Options(
          headers: {
            'authorization': _apiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'route': 'q',
          'message': message,
          'language': 'english',
          'flash': 0,
          'numbers': number10,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map ? response.data as Map : {};
        if (data['return'] == true) {
          return Fast2SmsResult(
            success: true,
            otp: '',
            message: 'Custom SMS dispatched successfully to $number10',
          );
        }
      }
    } catch (e) {
      debugPrint('Fast2SMS custom SMS exception: $e');
    }

    return const Fast2SmsResult(
      success: false,
      otp: '',
      error: 'Fast2SMS delivery failed',
    );
  }
}
