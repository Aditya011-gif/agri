import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Application configuration class containing all environment-specific settings
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  // Environment settings
  static const String environment = String.fromEnvironment('ENV', defaultValue: 'development');
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  // Database Configuration
  static const String databaseName = 'agrichain_secure.db';
  static const int databaseVersion = 1;
  static const int maxDatabaseConnections = 10;
  static const Duration databaseTimeout = Duration(seconds: 30);
  
  // Connection pool settings
  static const int connectionPoolSize = 5;
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration idleTimeout = Duration(minutes: 5);

  // Security Configuration
  static const String encryptionKey = String.fromEnvironment('ENCRYPTION_KEY', 
    defaultValue: 'dev-test-32-char-encryption-key1');
  static const String jwtSecret = String.fromEnvironment('JWT_SECRET', 
    defaultValue: 'dev-jwt-secret-key-minimum-32-chars');
  static const Duration sessionTimeout = Duration(hours: 24);
  static const Duration tokenRefreshThreshold = Duration(hours: 2);
  
  // Password policy
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int passwordHistoryCount = 5;
  static const Duration passwordExpiry = Duration(days: 90);
  
  // Account lockout settings
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 30);
  static const Duration loginAttemptWindow = Duration(minutes: 15);

  // Rate limiting configuration
  static const int maxRequestsPerMinute = 60;
  static const int maxRequestsPerHour = 1000;
  static const Duration rateLimitWindow = Duration(minutes: 1);
  
  // CSRF protection
  static const Duration csrfTokenExpiry = Duration(hours: 1);
  static const String csrfTokenHeader = 'X-CSRF-Token';
  
  // Security headers
  static const Map<String, String> securityHeaders = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
    'Referrer-Policy': 'strict-origin-when-cross-origin',
  };

  // API Configuration
  static const String baseApiUrl = String.fromEnvironment('API_BASE_URL', 
    defaultValue: 'https://api.agrichain.com');
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Digi Locker API Configuration (Sandbox for Hackathon)
  static const String digiLockerBaseUrl = String.fromEnvironment('DIGILOCKER_BASE_URL',
    defaultValue: 'https://api.digitallocker.gov.in'); // Sandbox base URL
  static const String digiLockerClientId = String.fromEnvironment('DIGILOCKER_CLIENT_ID',
    defaultValue: 'sandbox_client_id'); // Replace with your sandbox client ID
  static const String digiLockerClientSecret = String.fromEnvironment('DIGILOCKER_CLIENT_SECRET',
    defaultValue: 'sandbox_client_secret'); // Replace with your sandbox client secret
  static const String digiLockerRedirectUri = String.fromEnvironment('DIGILOCKER_REDIRECT_URI',
    defaultValue: 'https://yourapp.com/auth/digilocker/callback'); // Your app's callback URL
  static const Duration digiLockerTimeout = Duration(seconds: 45);
  
  // DigiLocker Sandbox OAuth URLs
  static const String digiLockerOAuthUrl = 'https://api.digitallocker.gov.in/public/oauth2/1/authorize';
  static const String digiLockerTokenUrl = 'https://api.digitallocker.gov.in/public/oauth2/1/token';
  static const String digiLockerApiUrl = 'https://api.digitallocker.gov.in/public/oauth2/2';

  // KYC Configuration
  static const Duration kycDataExpiry = Duration(days: 365);
  static const int maxKycAttempts = 3;
  static const Duration kycCooldownPeriod = Duration(hours: 24);
  
  // Supported KYC document types
  static const List<String> supportedKycDocuments = [
    'aadhaar',
    'pan',
    'driving_license',
    'passport',
    'voter_id',
  ];

  // File upload configuration
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedFileTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  ];
  static const List<String> allowedFileExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.pdf',
  ];

  // Logging Configuration
  static const bool enableLogging = true;
  static const String logLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');
  static const int maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxLogFiles = 5;
  static const Duration logRetentionPeriod = Duration(days: 30);

  // Cache Configuration
  static const Duration cacheExpiry = Duration(hours: 1);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration cacheCleanupInterval = Duration(hours: 6);

  // Notification Configuration
  static const bool enablePushNotifications = true;
  static const Duration notificationRetryInterval = Duration(minutes: 5);
  static const int maxNotificationRetries = 3;

  // Blockchain Configuration - Infura Integration
  // Replace 'YOUR_INFURA_PROJECT_ID' with your actual Infura Project ID
  static const String infuraProjectId = String.fromEnvironment('INFURA_PROJECT_ID',
    defaultValue: '1e023ded40e449298193fad266f512b7');
  
  // Replace 'YOUR_INFURA_PROJECT_SECRET' with your actual Infura Project Secret (optional)
  static const String infuraProjectSecret = String.fromEnvironment('INFURA_PROJECT_SECRET',
    defaultValue: 'GjiIfTQ/ZbbIUeJGb2Q7Sg3QXiB/FJoQe+wayl1dC94ws1MxJoCwfg');
  
  // Ethereum Networks via Infura
  static const String ethereumMainnetUrl = String.fromEnvironment('ETHEREUM_RPC_URL',
    defaultValue: 'https://mainnet.infura.io/v3/1e023ded40e449298193fad266f512b7');
  static const String ethereumSepoliaUrl = String.fromEnvironment('ETHEREUM_SEPOLIA_URL',
    defaultValue: 'https://sepolia.infura.io/v3/1e023ded40e449298193fad266f512b7');
  static const String ethereumGoerliUrl = String.fromEnvironment('ETHEREUM_GOERLI_URL',
    defaultValue: 'https://goerli.infura.io/v3/1e023ded40e449298193fad266f512b7');
  
  // Polygon Networks via Infura
  static const String polygonMainnetUrl = String.fromEnvironment('POLYGON_RPC_URL',
    defaultValue: 'https://polygon-mainnet.infura.io/v3/1e023ded40e449298193fad266f512b7');
  static const String polygonMumbaiUrl = String.fromEnvironment('POLYGON_MUMBAI_URL',
    defaultValue: 'https://polygon-mumbai.infura.io/v3/1e023ded40e449298193fad266f512b7');
  
  // Default RPC URLs (for backward compatibility)
  static const String ethereumRpcUrl = ethereumMainnetUrl;
  static const String polygonRpcUrl = polygonMainnetUrl;
  
  // Smart Contract Configuration
  static const String contractAddress = String.fromEnvironment('CONTRACT_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000');
  static const Duration blockchainTimeout = Duration(seconds: 60);
  
  // Network Configuration
  static const int ethereumChainId = 1; // Mainnet
  static const int polygonChainId = 137; // Polygon Mainnet
  static const int sepoliaChainId = 11155111; // Sepolia Testnet
  static const int mumbaiChainId = 80001; // Mumbai Testnet

  // Payment Configuration
  static const String razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID',
    defaultValue: 'your-razorpay-key-id');
  static const String razorpayKeySecret = String.fromEnvironment('RAZORPAY_KEY_SECRET',
    defaultValue: 'your-razorpay-key-secret');
  static const Duration paymentTimeout = Duration(minutes: 10);

  // Multimodal AI Configuration (Google Gemini 2.5 Flash)
  static String get geminiApiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42Skhnci14dU92ME9JX2xnamhYcklLZThESEI5OS1nSENsOVZOdEFDSVIyMHc='));
    } catch (_) {
      return '';
    }
  }

  // Fast2SMS API Configuration (Real Cellular SMS OTP Delivery)
  static const String fast2smsApiKey = String.fromEnvironment('FAST2SMS_API_KEY',
    defaultValue: '');

  // Twilio Verify API Configuration (Real Cellular SMS OTP Delivery)
  static const String twilioAccountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID',
    defaultValue: '');
  static const String twilioAuthToken = String.fromEnvironment('TWILIO_AUTH_TOKEN',
    defaultValue: '');
  static const String twilioVerifyServiceSid = String.fromEnvironment('TWILIO_VERIFY_SERVICE_SID',
    defaultValue: '');

  // Feature flags
  static const bool enableKycVerification = true;
  static const bool enableBiometricAuth = true;
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;

  // Development/Debug settings
  static const bool enableDebugMode = bool.fromEnvironment('DEBUG_MODE', defaultValue: true);
  static const bool enableMockData = bool.fromEnvironment('ENABLE_MOCK_DATA', defaultValue: true);
  static const bool skipKycInDev = bool.fromEnvironment('SKIP_KYC_IN_DEV', defaultValue: true);

  /// Get database path based on platform
  static Future<String> getDatabasePath() async {
    if (kIsWeb) {
      // Web platform uses IndexedDB through sqflite_common_ffi_web
      return databaseName;
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile platforms use app documents directory
      return databaseName;
    } else {
      // Desktop platforms use current directory
      return './$databaseName';
    }
  }

  /// Get API base URL based on environment
  static String getApiBaseUrl() {
    switch (environment) {
      case 'production':
        return 'https://api.agrichain.com';
      case 'staging':
        return 'https://staging-api.agrichain.com';
      case 'development':
      default:
        return 'https://dev-api.agrichain.com';
    }
  }

  /// Get log level based on environment
  static String getLogLevel() {
    if (isDevelopment) {
      return 'debug';
    } else if (isStaging) {
      return 'info';
    } else {
      return 'warning';
    }
  }

  /// Validate configuration on app startup
  static bool validateConfig() {
    try {
      // Check required environment variables
      if (isProduction) {
        if (encryptionKey == 'your-32-character-encryption-key-here') {
          throw Exception('Production encryption key not set');
        }
        if (jwtSecret == 'your-jwt-secret-key-here') {
          throw Exception('Production JWT secret not set');
        }
        if (digiLockerClientId == 'your-digilocker-client-id') {
          throw Exception('Production Digi Locker client ID not set');
        }
      }

      // Validate encryption key length
      if (encryptionKey.length != 32) {
        throw Exception('Encryption key must be exactly 32 characters');
      }

      // Validate JWT secret length
      if (jwtSecret.length < 32) {
        throw Exception('JWT secret must be at least 32 characters');
      }

      return true;
    } catch (e) {
      print('Configuration validation failed: $e');
      return false;
    }
  }

  /// Get configuration summary for debugging
  static Map<String, dynamic> getConfigSummary() {
    return {
      'environment': environment,
      'databaseName': databaseName,
      'databaseVersion': databaseVersion,
      'apiBaseUrl': getApiBaseUrl(),
      'enableKycVerification': enableKycVerification,
      'enableBiometricAuth': enableBiometricAuth,
      'enableOfflineMode': enableOfflineMode,
      'maxLoginAttempts': maxLoginAttempts,
      'sessionTimeout': sessionTimeout.inHours,
      'logLevel': getLogLevel(),
      'enableDebugMode': enableDebugMode,
    };
  }
}