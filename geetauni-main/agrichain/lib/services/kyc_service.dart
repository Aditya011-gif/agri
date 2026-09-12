import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'security_service.dart';
import 'digilocker_service.dart';

class KycResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final String? verificationId;

  KycResult({
    required this.success,
    this.message,
    this.data,
    this.verificationId,
  });
}

class DigiLockerDocument {
  final String docType;
  final String docId;
  final String name;
  final String dateOfBirth;
  final String address;
  final String? photo;
  final bool isVerified;

  DigiLockerDocument({
    required this.docType,
    required this.docId,
    required this.name,
    required this.dateOfBirth,
    required this.address,
    this.photo,
    required this.isVerified,
  });

  Map<String, dynamic> toJson() {
    return {
      'docType': docType,
      'docId': docId,
      'name': name,
      'dateOfBirth': dateOfBirth,
      'address': address,
      'photo': photo,
      'isVerified': isVerified ? 1 : 0,
    };
  }

  factory DigiLockerDocument.fromJson(Map<String, dynamic> json) {
    return DigiLockerDocument(
      docType: json['docType'],
      docId: json['docId'],
      name: json['name'],
      dateOfBirth: json['dateOfBirth'],
      address: json['address'],
      photo: json['photo'],
      isVerified: json['isVerified'] == 1 || json['isVerified'] == true,
    );
  }
}

class KycService {
  static final KycService _instance = KycService._internal();
  factory KycService() => _instance;
  KycService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final SecurityService _securityService = SecurityService();

  // API Configuration (These would be environment variables in production)
  static const String _digiLockerBaseUrl = 'https://api.digitallocker.gov.in';
  static const String _digiLockerClientId =
      'YOUR_CLIENT_ID'; // Replace with actual
  static const String _digiLockerClientSecret =
      'YOUR_CLIENT_SECRET'; // Replace with actual
  static const String _digiLockerRedirectUri = 'agrichain://kyc/callback';

  // Verification endpoints
  static const String _aadhaarVerificationUrl =
      'https://api.aadhaarapi.com/verify';
  static const String _panVerificationUrl = 'https://api.panapi.com/verify';

  /// Link real verified DigiLocker profile directly to user KYC in Firestore
  Future<KycResult> verifyWithDigilockerProfile({
    required String userId,
    required DigilockerProfile profile,
    String? phone,
  }) async {
    try {
      final kycData = {
        'id': 'kyc_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        'userId': userId,
        'aadhaarNumber': profile.maskedAadhaar,
        'fullName': profile.fullName,
        'gender': profile.gender ?? '',
        'dob': profile.dob ?? '',
        'address': profile.address ?? '',
        'sessionId': profile.sessionId,
        'certificateId': profile.certificateId,
        'kycStatus': 'verified',
        'aadhaarVerified': 1,
        'panVerified': 0,
        'digiLockerVerified': 1,
        'phone': phone ?? '',
        'verifiedAt': profile.verifiedAt.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _databaseService.createKycData(kycData);

      await _databaseService.updateUser(userId, {
        'kycStatus': 'verified',
        'isKycVerified': 1,
        'isAadhaarVerified': true,
        'digiLockerVerified': true,
        'name': profile.fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return KycResult(
        success: true,
        message: 'DigiLocker e-KYC verified successfully!',
        data: profile.toJson(),
        verificationId: profile.certificateId,
      );
    } catch (e) {
      debugPrint('Error linking DigiLocker profile: $e');
      return KycResult(success: false, message: e.toString());
    }
  }

  /// Initialize KYC process with Digi Locker
  Future<KycResult> initializeDigiLockerKyc({
    required String userId,
    required String aadhaarNumber,
    required String panNumber,
  }) async {
    try {
      // Validate input
      if (!_validateAadhaarNumber(aadhaarNumber)) {
        return KycResult(
          success: false,
          message: 'Invalid Aadhaar number format',
        );
      }

      if (!_validatePanNumber(panNumber)) {
        return KycResult(success: false, message: 'Invalid PAN number format');
      }

      // Generate verification ID
      final verificationId = _generateVerificationId();

      // Create KYC record
      final kycData = {
        'id': verificationId,
        'userId': userId,
        'aadhaarVerified': 0,
        'panVerified': 0,
        'digiLockerVerified': 0,
        'kycStatus': 'initiated',
        'kycData': jsonEncode({
          'aadhaarNumber': aadhaarNumber,
          'panNumber': panNumber,
          'initiatedAt': DateTime.now().toIso8601String(),
        }),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final created = await _databaseService.createKycData(kycData);
      if (!created) {
        return KycResult(
          success: false,
          message: 'Failed to initialize KYC process',
        );
      }

      // Generate Digi Locker authorization URL
      final authUrl = _generateDigiLockerAuthUrl(verificationId);

      // Log KYC initiation
      await _securityService.logSecurityEvent(
        userId: userId,
        event: 'KYC_INITIATED',
        details: {
          'verificationId': verificationId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return KycResult(
        success: true,
        message: 'KYC process initiated successfully',
        verificationId: verificationId,
        data: {'authUrl': authUrl, 'verificationId': verificationId},
      );
    } catch (e) {
      debugPrint('Initialize Digi Locker KYC error: $e');
      return KycResult(
        success: false,
        message: 'An error occurred while initializing KYC',
      );
    }
  }

  /// Handle Digi Locker callback
  Future<KycResult> handleDigiLockerCallback({
    required String verificationId,
    required String authCode,
  }) async {
    try {
      // Get KYC data
      final kycData = await _databaseService.getKycDataByUserId(verificationId);
      if (kycData == null) {
        return KycResult(success: false, message: 'Invalid verification ID');
      }

      // Exchange auth code for access token
      final tokenResult = await _exchangeAuthCodeForToken(authCode);
      if (!tokenResult.success) {
        return tokenResult;
      }

      final accessToken = tokenResult.data!['access_token'];

      // Fetch documents from Digi Locker
      final documentsResult = await _fetchDigiLockerDocuments(accessToken);
      if (!documentsResult.success) {
        return documentsResult;
      }

      final documents =
          documentsResult.data!['documents'] as List<DigiLockerDocument>;

      // Verify documents
      final verificationResult = await _verifyDocuments(
        documents,
        kycData['userId'],
      );

      // Update KYC status
      await _updateKycStatus(kycData['userId'], verificationResult, documents);

      return verificationResult;
    } catch (e) {
      debugPrint('Handle Digi Locker callback error: $e');
      return KycResult(
        success: false,
        message: 'An error occurred while processing KYC callback',
      );
    }
  }

  /// Verify Aadhaar number independently
  Future<KycResult> verifyAadhaar({
    required String userId,
    required String aadhaarNumber,
    required String otp,
  }) async {
    try {
      if (!_validateAadhaarNumber(aadhaarNumber)) {
        return KycResult(
          success: false,
          message: 'Invalid Aadhaar number format',
        );
      }

      // Call Aadhaar verification API
      final response = await http.post(
        Uri.parse(_aadhaarVerificationUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY', // Replace with actual API key
          ..._securityService.getSecurityHeaders(),
        },
        body: jsonEncode({
          'aadhaar_number': aadhaarNumber,
          'otp': otp,
          'consent': 'Y',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // Update KYC data
          await _databaseService.updateKycData(userId, {
            'aadhaarVerified': 1,
            'kycStatus': 'aadhaar_verified',
          });

          // Log verification
          await _securityService.logSecurityEvent(
            userId: userId,
            event: 'AADHAAR_VERIFIED',
            details: {
              'aadhaarNumber':
                  '${aadhaarNumber.substring(0, 4)}XXXX${aadhaarNumber.substring(8)}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

          return KycResult(
            success: true,
            message: 'Aadhaar verified successfully',
            data: data['data'],
          );
        } else {
          return KycResult(
            success: false,
            message: data['message'] ?? 'Aadhaar verification failed',
          );
        }
      } else {
        return KycResult(
          success: false,
          message: 'Aadhaar verification service unavailable',
        );
      }
    } catch (e) {
      debugPrint('Verify Aadhaar error: $e');
      return KycResult(
        success: false,
        message: 'An error occurred during Aadhaar verification',
      );
    }
  }

  /// Verify PAN number
  Future<KycResult> verifyPan({
    required String userId,
    required String panNumber,
    required String name,
    required String dateOfBirth,
  }) async {
    try {
      if (!_validatePanNumber(panNumber)) {
        return KycResult(success: false, message: 'Invalid PAN number format');
      }

      // Call PAN verification API
      final response = await http.post(
        Uri.parse(_panVerificationUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY', // Replace with actual API key
          ..._securityService.getSecurityHeaders(),
        },
        body: jsonEncode({
          'pan_number': panNumber,
          'name': name,
          'date_of_birth': dateOfBirth,
          'consent': 'Y',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // Update KYC data
          await _databaseService.updateKycData(userId, {'panVerified': 1});

          // Log verification
          await _securityService.logSecurityEvent(
            userId: userId,
            event: 'PAN_VERIFIED',
            details: {
              'panNumber': panNumber,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

          return KycResult(
            success: true,
            message: 'PAN verified successfully',
            data: data['data'],
          );
        } else {
          return KycResult(
            success: false,
            message: data['message'] ?? 'PAN verification failed',
          );
        }
      } else {
        return KycResult(
          success: false,
          message: 'PAN verification service unavailable',
        );
      }
    } catch (e) {
      debugPrint('Verify PAN error: $e');
      return KycResult(
        success: false,
        message: 'An error occurred during PAN verification',
      );
    }
  }

  /// Get KYC status for user
  Future<Map<String, dynamic>?> getKycStatus(String userId) async {
    try {
      final kycData = await _databaseService.getKycDataByUserId(userId);
      if (kycData == null) return null;

      final data = jsonDecode(kycData['kycData'] ?? '{}');

      return {
        'status': kycData['kycStatus'],
        'aadhaarVerified': kycData['aadhaarVerified'] == 1,
        'panVerified': kycData['panVerified'] == 1,
        'digiLockerVerified': kycData['digiLockerVerified'] == 1,
        'verificationDate': kycData['verificationDate'],
        'expiryDate': kycData['expiryDate'],
        'data': data,
      };
    } catch (e) {
      debugPrint('Get KYC status error: $e');
      return null;
    }
  }

  /// Check if KYC is complete
  Future<bool> isKycComplete(String userId) async {
    try {
      final kycData = await _databaseService.getKycDataByUserId(userId);
      if (kycData == null) return false;

      return kycData['aadhaarVerified'] == 1 &&
          kycData['panVerified'] == 1 &&
          kycData['digiLockerVerified'] == 1 &&
          kycData['kycStatus'] == 'completed';
    } catch (e) {
      debugPrint('Check KYC complete error: $e');
      return false;
    }
  }

  // Private helper methods

  bool _validateAadhaarNumber(String aadhaar) {
    return RegExp(r'^\d{12}$').hasMatch(aadhaar);
  }

  bool _validatePanNumber(String pan) {
    return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan);
  }

  String _generateVerificationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'kyc_${timestamp}_$random';
  }

  String _generateDigiLockerAuthUrl(String verificationId) {
    final state = base64Url.encode(utf8.encode(verificationId));
    final params = {
      'response_type': 'code',
      'client_id': _digiLockerClientId,
      'redirect_uri': _digiLockerRedirectUri,
      'scope': 'openid profile aadhaar',
      'state': state,
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$_digiLockerBaseUrl/oauth2/authorize?$queryString';
  }

  Future<KycResult> _exchangeAuthCodeForToken(String authCode) async {
    try {
      final response = await http.post(
        Uri.parse('$_digiLockerBaseUrl/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          ..._securityService.getSecurityHeaders(),
        },
        body: {
          'grant_type': 'authorization_code',
          'client_id': _digiLockerClientId,
          'client_secret': _digiLockerClientSecret,
          'code': authCode,
          'redirect_uri': _digiLockerRedirectUri,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return KycResult(success: true, data: data);
      } else {
        return KycResult(
          success: false,
          message: 'Failed to exchange auth code for token',
        );
      }
    } catch (e) {
      debugPrint('Exchange auth code error: $e');
      return KycResult(success: false, message: 'Token exchange failed');
    }
  }

  Future<KycResult> _fetchDigiLockerDocuments(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$_digiLockerBaseUrl/api/v1/documents'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          ..._securityService.getSecurityHeaders(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final documents = (data['documents'] as List)
            .map((doc) => DigiLockerDocument.fromJson(doc))
            .toList();

        return KycResult(success: true, data: {'documents': documents});
      } else {
        return KycResult(
          success: false,
          message: 'Failed to fetch documents from Digi Locker',
        );
      }
    } catch (e) {
      debugPrint('Fetch Digi Locker documents error: $e');
      return KycResult(success: false, message: 'Document fetch failed');
    }
  }

  Future<KycResult> _verifyDocuments(
    List<DigiLockerDocument> documents,
    String userId,
  ) async {
    try {
      bool hasAadhaar = false;
      bool hasPan = false;

      for (final doc in documents) {
        if (doc.docType.toLowerCase().contains('aadhaar') && doc.isVerified) {
          hasAadhaar = true;
        }
        if (doc.docType.toLowerCase().contains('pan') && doc.isVerified) {
          hasPan = true;
        }
      }

      final isComplete = hasAadhaar && hasPan;

      // Log verification result
      await _securityService.logSecurityEvent(
        userId: userId,
        event: 'DIGILOCKER_VERIFICATION',
        details: {
          'hasAadhaar': hasAadhaar,
          'hasPan': hasPan,
          'isComplete': isComplete,
          'documentCount': documents.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return KycResult(
        success: isComplete,
        message: isComplete
            ? 'Documents verified successfully'
            : 'Required documents not found or not verified',
        data: {
          'hasAadhaar': hasAadhaar,
          'hasPan': hasPan,
          'documents': documents.map((d) => d.toJson()).toList(),
        },
      );
    } catch (e) {
      debugPrint('Verify documents error: $e');
      return KycResult(success: false, message: 'Document verification failed');
    }
  }

  Future<void> _updateKycStatus(
    String userId,
    KycResult verificationResult,
    List<DigiLockerDocument> documents,
  ) async {
    try {
      final updates = <String, dynamic>{
        'digiLockerVerified': verificationResult.success ? 1 : 0,
        'kycData': jsonEncode({
          'documents': documents.map((d) => d.toJson()).toList(),
          'verificationResult': verificationResult.data,
          'verifiedAt': DateTime.now().toIso8601String(),
        }),
      };

      if (verificationResult.success) {
        updates['kycStatus'] = 'completed';
        updates['verificationDate'] = DateTime.now().toIso8601String();
        updates['expiryDate'] = DateTime.now()
            .add(Duration(days: 365))
            .toIso8601String(); // KYC valid for 1 year
      } else {
        updates['kycStatus'] = 'failed';
      }

      await _databaseService.updateKycData(userId, updates);

      // Update user KYC status
      await _databaseService.updateUser(userId, {
        'isKycVerified': verificationResult.success ? 1 : 0,
      });
    } catch (e) {
      debugPrint('Update KYC status error: $e');
    }
  }

  /// Initialize DigiLocker service
  Future<bool> initializeDigiLocker() async {
    try {
      // Check if DigiLocker configuration is valid
      if (_digiLockerClientId == 'YOUR_CLIENT_ID' ||
          _digiLockerClientSecret == 'YOUR_CLIENT_SECRET') {
        if (kDebugMode) {
          print('DigiLocker not configured - using mock service');
        }
        return true; // Return true for development/testing
      }

      // Test DigiLocker API connectivity
      final response = await http
          .get(
            Uri.parse('$_digiLockerBaseUrl/public/oauth2/1/authorize'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 400) {
        // 400 is expected for GET without proper parameters
        if (kDebugMode) {
          print('DigiLocker service initialized successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('DigiLocker service unavailable: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('DigiLocker initialization error: $e');
      }
      // Return true for development to allow app to continue
      return true;
    }
  }
}
