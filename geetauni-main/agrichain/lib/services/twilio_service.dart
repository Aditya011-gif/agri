import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Twilio Programmable SMS service for direct transactional DBT disbursement alerts
class TwilioService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Dispatch real cellular SMS to an international phone number (e.g. +91XXXXXXXXXX)
  static Future<bool> sendSms({
    required String to,
    required String body,
  }) async {
    final accountSid = AppConfig.twilioAccountSid;
    final authToken = AppConfig.twilioAuthToken;
    const fromPhone = '+17372212163';

    if (accountSid.isEmpty || authToken.isEmpty) {
      debugPrint('⚠️ Twilio credentials missing in configuration.');
      return false;
    }

    final bytes = utf8.encode('$accountSid:$authToken');
    final authHeader = 'Basic ${base64Encode(bytes)}';

    final cleanPhone = to.trim().replaceAll(RegExp(r'[^\d+]'), '');
    final fullNumber = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';

    try {
      final response = await _dio.post(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
        options: Options(
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
        data: {
          'To': fullNumber,
          'From': fromPhone,
          'Body': body,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Twilio SMS dispatched successfully to $fullNumber');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Twilio SMS dispatch error: $e');
      return false;
    }
  }
}
