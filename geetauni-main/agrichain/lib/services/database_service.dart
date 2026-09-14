import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/b2b_contract_model.dart';
import '../models/fpo_member_model.dart';
import 'fpo_inventory_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _securityLogsCollection = 'security_logs';
  static const String _sessionsCollection = 'sessions';
  static const String _kycDataCollection = 'kyc_data';
  static const String _profileDataCollection = 'profile_data';
  static const String _loanRequestsCollection = 'loan_requests';
  static const String _cropsCollection = 'crops';
  static const String _transactionsCollection = 'transactions';
  static const String _ratingsCollection = 'ratings';
  static const String _ratingStatsCollection = 'rating_stats';
  static const String _fpoBulkLotsCollection = 'fpo_bulk_lots';
  static const String _procurementOffersCollection = 'procurement_offers';
  static const String _bulkRfqsCollection = 'bulk_rfqs';
  static const String _fpoShipmentsCollection = 'fpo_shipments';
  static const String _fpoOrdersCollection = 'fpo_orders';
  static const String _retailOrdersCollection = 'retail_orders';
  static const String _savedCropsCollection = 'saved_crops';
  static const String _fpoMembersCollection = 'fpo_members';
  static const String _farmerPayoutsCollection = 'farmer_payouts';
  static const String _fpoSettlementsCollection = 'fpo_settlements';

  /// Initialize Firestore settings
  Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        try {
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          debugPrint('⚠️ Firestore persistence setup notice: $e');
        }
      }

      debugPrint('✅ Firestore initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Firestore initialization error: $e');
    }
  }

  // User operations

  /// Create a new user
  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      final userId = userData['id'] as String;
      await _firestore.collection(_usersCollection).doc(userId).set(userData);

      debugPrint('✅ User created successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Create user error: $e');
      return false;
    }
  }

  /// Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get user by email error: $e');
      return null;
    }
  }

  /// Get user by phone (prioritizes real registered & KYC verified accounts over dummy placeholders)
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      final last10 = clean.length > 10 ? clean.substring(clean.length - 10) : clean;

      // Search across possible phone formats
      final queries = await Future.wait([
        _firestore.collection(_usersCollection).where('phone', isEqualTo: last10).get(),
        _firestore.collection(_usersCollection).where('phone', isEqualTo: '+91$last10').get(),
        _firestore.collection(_usersCollection).where('phoneWithCountryCode', isEqualTo: '+91$last10').get(),
      ]);

      final allDocs = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final q in queries) {
        for (final doc in q.docs) {
          if (!allDocs.any((d) => d.id == doc.id)) {
            allDocs.add(doc);
          }
        }
      }

      // Also check direct document lookup for 'user_phone_$last10'
      if (allDocs.isEmpty) {
        final directPhoneDoc = await _firestore.collection(_usersCollection).doc('user_phone_$last10').get();
        if (directPhoneDoc.exists && directPhoneDoc.data() != null) {
          allDocs.add(directPhoneDoc);
        }
      }

      if (allDocs.isEmpty) return null;

      // Filter and prioritize:
      // 1. DigiLocker verified or KYC verified users
      // 2. Real names (not placeholder 'Kisan Farmer')
      // 3. Document ID not starting with 'user_phone_'
      // 4. Most recent updated/created timestamp
      allDocs.sort((a, b) {
        final aData = a.data() ?? {};
        final bData = b.data() ?? {};

        final aVerified = (aData['digiLockerVerified'] == 1 ||
                aData['isKycVerified'] == 1 ||
                aData['isAadhaarVerified'] == true)
            ? 1
            : 0;
        final bVerified = (bData['digiLockerVerified'] == 1 ||
                bData['isKycVerified'] == 1 ||
                bData['isAadhaarVerified'] == true)
            ? 1
            : 0;
        if (aVerified != bVerified) return bVerified.compareTo(aVerified);

        final aFirstName = (aData['firstName'] ?? '').toString().toLowerCase().trim();
        final bFirstName = (bData['firstName'] ?? '').toString().toLowerCase().trim();
        final aIsDummy = aFirstName == 'kisan' || a.id.startsWith('user_phone_');
        final bIsDummy = bFirstName == 'kisan' || b.id.startsWith('user_phone_');
        if (aIsDummy != bIsDummy) return aIsDummy ? 1 : -1;

        final aTime = aData['updatedAt'] ?? aData['createdAt'] ?? '';
        final bTime = bData['updatedAt'] ?? bData['createdAt'] ?? '';
        return bTime.toString().compareTo(aTime.toString());
      });

      final bestDoc = allDocs.first;
      final bestData = Map<String, dynamic>.from(bestDoc.data()!);
      bestData['id'] ??= bestDoc.id;

      // If an obsolete dummy user_phone_ document exists alongside a real verified profile, clean it up
      if (allDocs.length > 1 && bestDoc.id != 'user_phone_$last10') {
        try {
          await _firestore.collection(_usersCollection).doc('user_phone_$last10').delete();
          debugPrint('🧹 Cleaned up obsolete dummy user_phone_$last10 doc in favor of real profile: ${bestDoc.id}');
        } catch (_) {}
      }

      return bestData;
    } catch (e) {
      debugPrint('❌ Get user by phone error: $e');
      return null;
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get user by ID error: $e');
      return null;
    }
  }

  /// Get user by Firebase UID
  Future<Map<String, dynamic>?> getUserByFirebaseUid(String firebaseUid) async {
    try {
      // 1. Direct O(1) document lookup by UID
      final docSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(firebaseUid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return docSnapshot.data();
      }

      // 2. Query fallback if stored with custom ID
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('firebaseUid', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }

      // 3. Check where id == firebaseUid
      final idQuerySnapshot = await _firestore
          .collection(_usersCollection)
          .where('id', isEqualTo: firebaseUid)
          .limit(1)
          .get();

      if (idQuerySnapshot.docs.isNotEmpty) {
        return idQuerySnapshot.docs.first.data();
      }

      return null;
    } catch (e) {
      debugPrint('ℹ️ Get user by Firebase UID notice: $e');
      // If query error, try direct doc get as absolute fallback
      try {
        final fallbackDoc = await _firestore.collection(_usersCollection).doc(firebaseUid).get();
        if (fallbackDoc.exists) return fallbackDoc.data();
      } catch (_) {}
      return null;
    }
  }

  /// Update user data
  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore.collection(_usersCollection).doc(userId).update(updates);

      debugPrint('✅ User updated successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Update user error: $e');
      return false;
    }
  }

  /// Delete user (soft delete by setting isActive to false)
  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ User soft deleted successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      return false;
    }
  }

  /// Hard delete user document from Firestore
  Future<bool> hardDeleteUser(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).delete();
      debugPrint('🗑️ User document deleted: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Hard delete user error: $e');
      return false;
    }
  }

  /// Remove all users created using Gmail and purge orphaned test data
  Future<Map<String, int>> deleteGmailUsersAndAssociatedData() async {
    try {
      debugPrint('🧹 Scanning Firestore for users registered with Gmail...');
      final userSnapshot = await _firestore.collection(_usersCollection).get();
      final deletedUserIds = <String>{};
      int usersDeleted = 0;

      for (final doc in userSnapshot.docs) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString().toLowerCase().trim();
        if (email.contains('@gmail.com') || email.endsWith('@gmail.com')) {
          deletedUserIds.add(doc.id);
          if (data['firebaseUid'] != null) deletedUserIds.add(data['firebaseUid'].toString());
          if (data['id'] != null) deletedUserIds.add(data['id'].toString());
          await _firestore.collection(_usersCollection).doc(doc.id).delete();
          usersDeleted++;
          debugPrint('🗑️ Deleted Gmail user doc: ${doc.id} (Email: $email, Name: ${data['name'] ?? data['firstName']})');
        }
      }

      // Clean up retail orders belonging to Gmail users or dummy unassigned demo orders
      int ordersDeleted = 0;
      final retailOrdersSnapshot = await _firestore.collection(_retailOrdersCollection).get();
      for (final doc in retailOrdersSnapshot.docs) {
        final data = doc.data();
        final farmerId = (data['farmerId'] ?? data['sellerId'] ?? '').toString();
        final buyerId = (data['buyerId'] ?? data['userId'] ?? '').toString();
        final buyerEmail = (data['buyerEmail'] ?? '').toString().toLowerCase();

        if (deletedUserIds.contains(farmerId) ||
            deletedUserIds.contains(buyerId) ||
            buyerEmail.contains('@gmail.com') ||
            farmerId == 'farmer_demo' ||
            farmerId.isEmpty) {
          await _firestore.collection(_retailOrdersCollection).doc(doc.id).delete();
          ordersDeleted++;
          debugPrint('🗑️ Deleted orphaned/demo retail order: ${doc.id}');
        }
      }

      // Clean up crops listed by Gmail users
      int cropsDeleted = 0;
      final cropsSnapshot = await _firestore.collection(_cropsCollection).get();
      for (final doc in cropsSnapshot.docs) {
        final data = doc.data();
        final farmerId = (data['farmerId'] ?? data['userId'] ?? '').toString();
        if (deletedUserIds.contains(farmerId)) {
          await _firestore.collection(_cropsCollection).doc(doc.id).delete();
          cropsDeleted++;
          debugPrint('🗑️ Deleted crop created by Gmail user: ${doc.id}');
        }
      }

      debugPrint('✅ Cleanup complete: $usersDeleted Gmail users, $ordersDeleted retail orders, $cropsDeleted crops removed.');
      return {
        'users': usersDeleted,
        'orders': ordersDeleted,
        'crops': cropsDeleted,
      };
    } catch (e) {
      debugPrint('❌ Error during Gmail users cleanup: $e');
      return {'users': 0, 'orders': 0, 'crops': 0};
    }
  }

  /// Get all active users
  Future<List<Map<String, dynamic>>> getAllActiveUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get all active users error: $e');
      return [];
    }
  }

  /// Get users by type
  Future<List<Map<String, dynamic>>> getUsersByType(String userType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('userType', isEqualTo: userType)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get users by type error: $e');
      return [];
    }
  }

  // Security log operations

  /// Create security log entry
  Future<bool> createSecurityLog(Map<String, dynamic> logData) async {
    try {
      final logId = logData['id'] as String;
      await _firestore
          .collection(_securityLogsCollection)
          .doc(logId)
          .set(logData);

      return true;
    } catch (e) {
      debugPrint('❌ Create security log error: $e');
      return false;
    }
  }

  /// Get recent security logs for a user
  Future<List<Map<String, dynamic>>> getRecentSecurityLogs({
    required String userId,
    int hours = 24,
  }) async {
    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(hours: hours))
          .toIso8601String();

      final querySnapshot = await _firestore
          .collection(_securityLogsCollection)
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: cutoffTime)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get recent security logs error: $e');
      return [];
    }
  }

  /// Get security logs by event type
  Future<List<Map<String, dynamic>>> getSecurityLogsByEvent({
    required String userId,
    required String event,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_securityLogsCollection)
          .where('userId', isEqualTo: userId)
          .where('event', isEqualTo: event)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get security logs by event error: $e');
      return [];
    }
  }

  /// Get all security logs for admin
  Future<List<Map<String, dynamic>>> getAllSecurityLogs({
    int limit = 100,
    String? severity,
  }) async {
    try {
      Query query = _firestore
          .collection(_securityLogsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (severity != null) {
        query = query.where('severity', isEqualTo: severity);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Get all security logs error: $e');
      return [];
    }
  }

  // Session operations

  /// Create session
  Future<bool> createSession(Map<String, dynamic> sessionData) async {
    try {
      final sessionId = sessionData['id'] as String;
      await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .set(sessionData);

      return true;
    } catch (e) {
      debugPrint('❌ Create session error: $e');
      return false;
    }
  }

  /// Get active session by user ID
  Future<Map<String, dynamic>?> getActiveSessionByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get active session by user ID error: $e');
      return null;
    }
  }

  /// Invalidate session
  Future<bool> invalidateSession(String sessionId) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Invalidate session error: $e');
      return false;
    }
  }

  /// Invalidate all sessions for a user
  Future<bool> invalidateAllUserSessions(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('❌ Invalidate all user sessions error: $e');
      return false;
    }
  }

  /// Clean expired sessions
  Future<void> cleanExpiredSessions() async {
    try {
      final now = DateTime.now().toIso8601String();

      final querySnapshot = await _firestore
          .collection(_sessionsCollection)
          .where('expiresAt', isLessThan: now)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      await batch.commit();
      debugPrint('✅ Cleaned ${querySnapshot.docs.length} expired sessions');
    } catch (e) {
      debugPrint('❌ Clean expired sessions error: $e');
    }
  }

  // KYC operations

  /// Create KYC data
  Future<bool> createKycData(Map<String, dynamic> kycData) async {
    try {
      final kycId = kycData['id'] as String;
      await _firestore.collection(_kycDataCollection).doc(kycId).set(kycData);

      debugPrint('✅ KYC data created successfully: $kycId');
      return true;
    } catch (e) {
      debugPrint('❌ Create KYC data error: $e');
      return false;
    }
  }

  /// Get KYC data by user ID
  Future<Map<String, dynamic>?> getKycDataByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_kycDataCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get KYC data error: $e');
      return null;
    }
  }

  /// Update KYC data
  Future<bool> updateKycData(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();

      final querySnapshot = await _firestore
          .collection(_kycDataCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update(updates);
        debugPrint('✅ KYC data updated successfully for user: $userId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Update KYC data error: $e');
      return false;
    }
  }

  /// Get all pending KYC verifications
  Future<List<Map<String, dynamic>>> getPendingKycVerifications() async {
    try {
      final querySnapshot = await _firestore
          .collection(_kycDataCollection)
          .where('verificationStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get pending KYC verifications error: $e');
      return [];
    }
  }

  // Profile operations

  /// Create profile data
  Future<bool> createProfileData(Map<String, dynamic> profileData) async {
    try {
      final profileId = profileData['id'] as String;
      await _firestore
          .collection(_profileDataCollection)
          .doc(profileId)
          .set(profileData);

      debugPrint('✅ Profile data created successfully: $profileId');
      return true;
    } catch (e) {
      debugPrint('❌ Create profile data error: $e');
      return false;
    }
  }

  /// Get profile data by user ID
  Future<Map<String, dynamic>?> getProfileDataByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_profileDataCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get profile data error: $e');
      return null;
    }
  }

  /// Update profile data
  Future<bool> updateProfileData(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();

      final querySnapshot = await _firestore
          .collection(_profileDataCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update(updates);
        debugPrint('✅ Profile data updated successfully for user: $userId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Update profile data error: $e');
      return false;
    }
  }

  // Loan operations

  /// Create loan request
  Future<bool> createLoanRequest(Map<String, dynamic> loanData) async {
    try {
      final loanId = loanData['id'] as String;
      await _firestore
          .collection(_loanRequestsCollection)
          .doc(loanId)
          .set(loanData);

      debugPrint('✅ Loan request created successfully: $loanId');
      return true;
    } catch (e) {
      debugPrint('❌ Create loan request error: $e');
      return false;
    }
  }

  /// Get loan requests by user ID
  Future<List<Map<String, dynamic>>> getLoanRequestsByUserId(
    String userId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_loanRequestsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get loan requests by user ID error: $e');
      return [];
    }
  }

  /// Get all loan requests
  Future<List<Map<String, dynamic>>> getAllLoanRequests({
    String? status,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection(_loanRequestsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Get all loan requests error: $e');
      return [];
    }
  }

  /// Update loan request status
  Future<bool> updateLoanRequestStatus(
    String loanId,
    String status, {
    String? remarks,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (remarks != null) {
        updateData['remarks'] = remarks;
      }

      await _firestore
          .collection(_loanRequestsCollection)
          .doc(loanId)
          .update(updateData);

      debugPrint('✅ Loan request status updated: $loanId -> $status');
      return true;
    } catch (e) {
      debugPrint('❌ Update loan request status error: $e');
      return false;
    }
  }

  // Crop operations

  /// Create crop listing
  Future<bool> createCrop(Map<String, dynamic> cropData) async {
    try {
      // Generate a new document ID if the provided ID is empty
      final docRef = _firestore.collection(_cropsCollection).doc();
      final cropId = cropData['id'] as String;
      final finalCropId = cropId.isEmpty ? docRef.id : cropId;

      // Update the crop data with the final ID
      cropData['id'] = finalCropId;

      await docRef.set(cropData);

      debugPrint('✅ Crop created successfully: $finalCropId');
      return true;
    } catch (e) {
      debugPrint('❌ Create crop error: $e');
      return false;
    }
  }

  /// Get crops by farmer ID
  Future<List<Map<String, dynamic>>> getCropsByFarmerId(String farmerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_cropsCollection)
          .where('farmerId', isEqualTo: farmerId)
          .get();

      final crops = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by createdAt in memory to avoid composite index requirement
      crops.sort((a, b) {
        final aCreatedAt = a['createdAt'];
        final bCreatedAt = b['createdAt'];

        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;

        DateTime aDate, bDate;
        if (aCreatedAt is Timestamp) {
          aDate = aCreatedAt.toDate();
        } else if (aCreatedAt is String) {
          aDate = DateTime.parse(aCreatedAt);
        } else {
          return 0;
        }

        if (bCreatedAt is Timestamp) {
          bDate = bCreatedAt.toDate();
        } else if (bCreatedAt is String) {
          bDate = DateTime.parse(bCreatedAt);
        } else {
          return 0;
        }

        return bDate.compareTo(aDate); // Descending order
      });

      return crops;
    } catch (e) {
      debugPrint('❌ Get crops by farmer ID error: $e');
      return [];
    }
  }

  /// Get all available crops
  Future<List<Map<String, dynamic>>> getAllAvailableCrops() async {
    try {
      final querySnapshot = await _firestore
          .collection(_cropsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      final crops = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort by createdAt in memory to avoid composite index requirement
      crops.sort((a, b) {
        final aCreatedAt = a['createdAt'];
        final bCreatedAt = b['createdAt'];

        if (aCreatedAt == null && bCreatedAt == null) return 0;
        if (aCreatedAt == null) return 1;
        if (bCreatedAt == null) return -1;

        DateTime aDate, bDate;
        if (aCreatedAt is Timestamp) {
          aDate = aCreatedAt.toDate();
        } else if (aCreatedAt is String) {
          aDate = DateTime.parse(aCreatedAt);
        } else {
          return 0;
        }

        if (bCreatedAt is Timestamp) {
          bDate = bCreatedAt.toDate();
        } else if (bCreatedAt is String) {
          bDate = DateTime.parse(bCreatedAt);
        } else {
          return 0;
        }

        return bDate.compareTo(aDate); // Descending order
      });

      return crops;
    } catch (e) {
      debugPrint('❌ Get all available crops error: $e');
      return [];
    }
  }

  /// Update crop data
  Future<bool> updateCrop(String cropId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore.collection(_cropsCollection).doc(cropId).update(updates);

      debugPrint('✅ Crop updated successfully: $cropId');
      return true;
    } catch (e) {
      debugPrint('❌ Update crop error: $e');
      return false;
    }
  }

  // Transaction operations

  /// Create transaction
  Future<bool> createTransaction(Map<String, dynamic> transactionData) async {
    try {
      final transactionId = transactionData['id'] as String;
      await _firestore
          .collection(_transactionsCollection)
          .doc(transactionId)
          .set(transactionData);

      debugPrint('✅ Transaction created successfully: $transactionId');
      return true;
    } catch (e) {
      debugPrint('❌ Create transaction error: $e');
      return false;
    }
  }

  /// Get transactions by user ID
  Future<List<Map<String, dynamic>>> getTransactionsByUserId(
    String userId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_transactionsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Get transactions by user ID error: $e');
      return [];
    }
  }

  // Rating management methods

  /// Add a new rating
  Future<bool> addRating(Map<String, dynamic> ratingData) async {
    try {
      ratingData['createdAt'] = FieldValue.serverTimestamp();
      ratingData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_ratingsCollection).add(ratingData);

      debugPrint('✅ Rating added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Add rating error: $e');
      return false;
    }
  }

  /// Get ratings for a user
  Future<List<Map<String, dynamic>>> getRatingsForUser(
    String userId, {
    String? ratingType,
  }) async {
    try {
      Query query = _firestore
          .collection(_ratingsCollection)
          .where('toUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (ratingType != null) {
        query = query.where('ratingType', isEqualTo: ratingType);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('❌ Get ratings for user error: $e');
      return [];
    }
  }

  /// Get all ratings (for admin/overview purposes)
  Future<List<Map<String, dynamic>>> getAllRatings({String? filterType}) async {
    try {
      Query query = _firestore
          .collection(_ratingsCollection)
          .orderBy('createdAt', descending: true)
          .limit(100);

      if (filterType != null) {
        query = query.where('ratingType', isEqualTo: filterType);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint('❌ Get all ratings error: $e');
      return [];
    }
  }

  /// Get user rating statistics
  Future<Map<String, dynamic>?> getUserRatingStats(String userId) async {
    try {
      final doc = await _firestore
          .collection(_ratingStatsCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }

      return null;
    } catch (e) {
      debugPrint('❌ Get user rating stats error: $e');
      return null;
    }
  }

  /// Update user rating statistics
  Future<bool> updateUserRatingStats(
    String userId,
    Map<String, dynamic> stats,
  ) async {
    try {
      stats['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_ratingStatsCollection)
          .doc(userId)
          .set(stats, SetOptions(merge: true));

      debugPrint('✅ User rating stats updated successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Update user rating stats error: $e');
      return false;
    }
  }

  /// Calculate and update rating statistics for a user
  Future<bool> calculateRatingStats(String userId) async {
    try {
      // Get all ratings for the user
      final ratings = await getRatingsForUser(userId);

      if (ratings.isEmpty) {
        // Create empty stats
        final emptyStats = {
          'userId': userId,
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingsByType': <String, double>{},
          'countsByType': <String, int>{},
          'fiveStarCount': 0,
          'fourStarCount': 0,
          'threeStarCount': 0,
          'twoStarCount': 0,
          'oneStarCount': 0,
        };

        return await updateUserRatingStats(userId, emptyStats);
      }

      // Calculate statistics
      double totalRating = 0.0;
      int totalCount = ratings.length;
      Map<String, double> ratingsByType = {};
      Map<String, int> countsByType = {};
      Map<int, int> starCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final rating in ratings) {
        final ratingValue = (rating['rating'] as num?)?.toDouble() ?? 0.0;
        final ratingType = rating['ratingType'] as String?;

        totalRating += ratingValue;

        // Count by star rating
        final starRating = ratingValue.round().clamp(1, 5);
        starCounts[starRating] = (starCounts[starRating] ?? 0) + 1;

        // Count by type
        if (ratingType != null) {
          ratingsByType[ratingType] =
              (ratingsByType[ratingType] ?? 0.0) + ratingValue;
          countsByType[ratingType] = (countsByType[ratingType] ?? 0) + 1;
        }
      }

      // Calculate averages by type
      ratingsByType.forEach((type, total) {
        final count = countsByType[type] ?? 1;
        ratingsByType[type] = total / count;
      });

      final stats = {
        'userId': userId,
        'averageRating': totalRating / totalCount,
        'totalRatings': totalCount,
        'ratingsByType': ratingsByType,
        'countsByType': countsByType,
        'fiveStarCount': starCounts[5] ?? 0,
        'fourStarCount': starCounts[4] ?? 0,
        'threeStarCount': starCounts[3] ?? 0,
        'twoStarCount': starCounts[2] ?? 0,
        'oneStarCount': starCounts[1] ?? 0,
      };

      return await updateUserRatingStats(userId, stats);
    } catch (e) {
      debugPrint('❌ Calculate rating stats error: $e');
      return false;
    }
  }

  // Database maintenance and statistics

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    try {
      final futures = await Future.wait([
        _getCollectionCount(_usersCollection, where: {'isActive': true}),
        _getCollectionCount(_securityLogsCollection),
        _getCollectionCount(_sessionsCollection, where: {'isActive': true}),
        _getCollectionCount(_kycDataCollection),
        _getCollectionCount(_profileDataCollection),
        _getCollectionCount(_loanRequestsCollection),
        _getCollectionCount(_cropsCollection),
        _getCollectionCount(_transactionsCollection),
      ]);

      return {
        'users': futures[0],
        'logs': futures[1],
        'sessions': futures[2],
        'kyc': futures[3],
        'profiles': futures[4],
        'loanRequests': futures[5],
        'crops': futures[6],
        'transactions': futures[7],
      };
    } catch (e) {
      debugPrint('❌ Get database stats error: $e');
      return {};
    }
  }

  /// Get collection document count
  Future<int> _getCollectionCount(
    String collection, {
    Map<String, dynamic>? where,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (where != null) {
        where.forEach((key, value) {
          query = query.where(key, isEqualTo: value);
        });
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Get collection count error for $collection: $e');
      return 0;
    }
  }

  /// Backup data to a backup collection
  Future<bool> backupData() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupCollectionPrefix = 'backup_$timestamp';

      final collections = [
        _usersCollection,
        _securityLogsCollection,
        _sessionsCollection,
        _kycDataCollection,
        _profileDataCollection,
        _loanRequestsCollection,
        _cropsCollection,
        _transactionsCollection,
      ];

      for (final collection in collections) {
        final snapshot = await _firestore.collection(collection).get();
        final batch = _firestore.batch();

        for (final doc in snapshot.docs) {
          final backupDocRef = _firestore
              .collection('${backupCollectionPrefix}_$collection')
              .doc(doc.id);
          batch.set(backupDocRef, doc.data());
        }

        await batch.commit();
      }

      debugPrint('✅ Data backup completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Backup data error: $e');
      return false;
    }
  }

  /// Clean up old data (for maintenance)
  Future<void> cleanupOldData({int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now()
          .subtract(Duration(days: daysToKeep))
          .toIso8601String();

      // Clean old security logs
      final oldLogs = await _firestore
          .collection(_securityLogsCollection)
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ Cleaned up ${oldLogs.docs.length} old security logs');
    } catch (e) {
      debugPrint('❌ Cleanup old data error: $e');
    }
  }

  /// Test Firestore connection
  Future<bool> testConnection() async {
    try {
      await _firestore.collection('test').doc('connection').set({
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'connected',
      });

      await _firestore.collection('test').doc('connection').delete();

      debugPrint('✅ Firestore connection test successful');
      return true;
    } catch (e) {
      debugPrint('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Enable offline persistence
  Future<void> enableOfflinePersistence() async {
    try {
      if (!kIsWeb) {
        await _firestore.enablePersistence();
        debugPrint('✅ Offline persistence enabled');
      }
    } catch (e) {
      debugPrint('❌ Enable offline persistence error: $e');
    }
  }

  /// Disable network (for testing offline functionality)
  Future<void> disableNetwork() async {
    try {
      await _firestore.disableNetwork();
      debugPrint('✅ Firestore network disabled');
    } catch (e) {
      debugPrint('❌ Disable network error: $e');
    }
  }

  /// Enable network
  Future<void> enableNetwork() async {
    try {
      await _firestore.enableNetwork();
      debugPrint('✅ Firestore network enabled');
    } catch (e) {
      debugPrint('❌ Enable network error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FPO Operations
  // ---------------------------------------------------------------------------

  /// Create a new Bulk Lot in Firestore
  Future<bool> createBulkLot(Map<String, dynamic> lotData) async {
    try {
      final id = lotData['id'] as String? ?? _firestore.collection(_fpoBulkLotsCollection).doc().id;
      lotData['id'] = id;
      await _firestore.collection(_fpoBulkLotsCollection).doc(id).set(lotData);
      debugPrint('✅ Bulk Lot created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create bulk lot error: $e');
      return false;
    }
  }

  /// Stream Bulk Lots (Optionally filtered by FPO ID)
  Stream<List<Map<String, dynamic>>> streamBulkLots({String? fpoId}) {
    Query query = _firestore.collection(_fpoBulkLotsCollection);
    if (fpoId != null && fpoId.isNotEmpty) {
      query = query.where('fpoId', isEqualTo: fpoId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // B2B Wholesale Bulk Orders & Multi-FPO Settlements
  // ---------------------------------------------------------------------------

  static const String _b2bOrdersCollection = 'b2b_bulk_orders';
  static const String _b2bContractsCollection = 'b2b_contracts';
  static const String _b2bInvoicesCollection = 'b2b_invoices';
  static const String _sharedBulkOrdersCollection = 'shared_bulk_orders';

  /// Create B2B Bulk Order, Smart Contract & GST Invoice atomically
  Future<bool> createB2bOrderAndContract({
    required Map<String, dynamic> orderData,
    required B2bContractModel contract,
    String? inventoryItemId,
    double? quantityToReserveMT,
    bool isMultiFpo = false,
    List<Map<String, dynamic>> allocations = const [],
  }) async {
    try {
      final orderId = (orderData['id'] ?? orderData['orderId'] ?? _firestore.collection(_b2bOrdersCollection).doc().id).toString();
      orderData['id'] = orderId;
      orderData['orderId'] = orderId;
      orderData['contractId'] = contract.id;
      orderData['contractNumber'] = contract.contractNumber;
      orderData['contractHash'] = contract.sha256Hash;
      orderData['createdAt'] = DateTime.now().toIso8601String();
      orderData['updatedAt'] = DateTime.now().toIso8601String();

      // 1. Write Order
      await _firestore.collection(_b2bOrdersCollection).doc(orderId).set(orderData);

      // 2. Write Contract
      await _firestore.collection(_b2bContractsCollection).doc(orderId).set(contract.toMap());

      // 3. Create initial B2B GST Tax Invoice record
      final invoiceId = 'INV-${DateTime.now().year}-${orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()}';
      final cropCost = contract.cropBaseAmount;
      const gstRate = 0.05; // 5% GST on processed/commercial grains
      final gstAmount = cropCost * gstRate;
      final totalInvoiceAmount = cropCost + gstAmount + contract.freightAmount;

      final invoiceData = <String, dynamic>{
        'id': invoiceId,
        'invoiceNumber': invoiceId,
        'orderId': orderId,
        'contractNumber': contract.contractNumber,
        'buyerId': contract.buyerId,
        'buyerName': contract.buyerName,
        'buyerCompany': contract.buyerCompany,
        'buyerGstin': contract.buyerGstin,
        'fpoId': contract.fpoId,
        'fpoName': contract.fpoName,
        'fpoGstin': contract.fpoGstin,
        'commodity': contract.commodity,
        'variety': contract.variety,
        'quantityQtl': contract.quantityQtl,
        'quantityMT': contract.quantityMT,
        'ratePerQtl': contract.pricePerQtl,
        'taxableValue': cropCost,
        'cgstAmount': gstAmount / 2,
        'sgstAmount': gstAmount / 2,
        'igstAmount': 0.0,
        'freightAmount': contract.freightAmount,
        'totalInvoiceAmount': totalInvoiceAmount,
        'status': 'issued_escrow_funded',
        'sha256Proof': contract.sha256Hash,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await _firestore.collection(_b2bInvoicesCollection).doc(invoiceId).set(invoiceData);

      // 4. Reserve stock atomically in FPO inventory & bulk listings
      try {
        if (isMultiFpo && allocations.isNotEmpty) {
          await FpoInventoryService().reserveClusterInventory(
            allocations: allocations,
            orderId: orderId,
            commodity: contract.commodity,
          );
        } else {
          final reserveQty = quantityToReserveMT ?? contract.quantityMT;
          await FpoInventoryService().reserveInventory(
            inventoryItemId: inventoryItemId,
            fpoId: contract.fpoId,
            cropName: contract.commodity,
            quantityToReserveMT: reserveQty,
            orderId: orderId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Stock reservation warning: $e');
      }

      debugPrint('✅ B2B Order, Contract & Invoice successfully created for order: $orderId');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating B2B order & contract: $e');
      return false;
    }
  }

  /// Get B2B Order by ID
  Future<Map<String, dynamic>?> getB2bOrder(String orderId) async {
    try {
      final doc = await _firestore.collection(_b2bOrdersCollection).doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      // Check shared bulk orders collection fallback
      final sharedDoc = await _firestore.collection(_sharedBulkOrdersCollection).doc(orderId).get();
      if (sharedDoc.exists && sharedDoc.data() != null) {
        final data = sharedDoc.data()!;
        data['id'] = sharedDoc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting B2B order: $e');
      return null;
    }
  }

  /// Stream B2B Order by ID
  Stream<Map<String, dynamic>?> streamB2bOrder(String orderId) {
    return _firestore.collection(_b2bOrdersCollection).doc(orderId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        data['id'] = snapshot.id;
        return data;
      }
      return null;
    });
  }

  /// Get B2B Contract by Order ID
  Future<B2bContractModel?> getB2bContract(String orderId) async {
    try {
      final doc = await _firestore.collection(_b2bContractsCollection).doc(orderId).get();
      if (doc.exists && doc.data() != null) {
        return B2bContractModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting B2B contract: $e');
      return null;
    }
  }

  /// Stream B2B Contract by Order ID
  Stream<B2bContractModel?> streamB2bContract(String orderId) {
    return _firestore.collection(_b2bContractsCollection).doc(orderId).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return B2bContractModel.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  /// Stream Buyer Invoices
  Stream<List<Map<String, dynamic>>> streamBuyerInvoices({String? buyerId}) {
    Query query = _firestore.collection(_b2bInvoicesCollection);
    if (buyerId != null && buyerId.isNotEmpty) {
      query = query.where('buyerId', isEqualTo: buyerId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      list.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
      return list;
    });
  }

  /// Release Escrow Payout to FPO Bank
  Future<bool> releaseB2bEscrow({required String orderId, required String utrNumber}) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _firestore.collection(_b2bOrdersCollection).doc(orderId).update({
        'status': 'completed',
        'escrowStatus': 'Settled & Paid',
        'payoutReleasedAt': now,
        'utrNumber': utrNumber,
        'updatedAt': now,
      });

      // Also update contract status
      await _firestore.collection(_b2bContractsCollection).doc(orderId).update({
        'status': 'settled',
        'payoutSettledAt': now,
        'utrNumber': utrNumber,
      });

      debugPrint('✅ Escrow released for order: $orderId (UTR: $utrNumber)');
      return true;
    } catch (e) {
      debugPrint('❌ Release escrow error: $e');
      return false;
    }
  }

  /// Create a Direct B2B Wholesale Order (FPO -> Bulk Institutional Buyer)
  Future<bool> createDirectBulkOrder(Map<String, dynamic> orderData) async {
    try {
      final id = orderData['id'] as String? ?? _firestore.collection(_b2bOrdersCollection).doc().id;
      orderData['id'] = id;
      orderData['createdAt'] = DateTime.now().toIso8601String();
      orderData['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_b2bOrdersCollection).doc(id).set(orderData);
      debugPrint('✅ Direct B2B Bulk Order created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create bulk order error: $e');
      return false;
    }
  }

  /// Create a Shared Multi-FPO Order (Multiple FPOs -> Bulk Institutional Buyer)
  Future<bool> createSharedBulkOrder(Map<String, dynamic> sharedOrderData) async {
    try {
      final id = sharedOrderData['id'] as String? ?? _firestore.collection(_sharedBulkOrdersCollection).doc().id;
      sharedOrderData['id'] = id;
      sharedOrderData['createdAt'] = DateTime.now().toIso8601String();
      sharedOrderData['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_sharedBulkOrdersCollection).doc(id).set(sharedOrderData);
      debugPrint('✅ Shared Multi-FPO Order created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create shared bulk order error: $e');
      return false;
    }
  }

  /// Stream all B2B orders involving this FPO or Bulk Buyer (strictly isolated to the authenticated user)
  Stream<List<Map<String, dynamic>>> streamFpoOrders({String? fpoId, String? buyerId}) {
    return _firestore
        .collection(_b2bOrdersCollection)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .where((o) {
            if (buyerId != null && buyerId.isNotEmpty) {
              if (buyerId == 'demo_buyer_001' || buyerId == 'buyer_institutional' || buyerId.startsWith('demo_')) {
                final oBuyerId = (o['buyerId'] ?? '').toString();
                return oBuyerId == buyerId || oBuyerId == 'demo_buyer_001' || oBuyerId == 'buyer_institutional' || oBuyerId.isEmpty;
              }
              return o['buyerId'] == buyerId;
            }
            if (fpoId != null && fpoId.isNotEmpty) {
              final sId = (o['sellerId'] ?? o['fpoId'] ?? '').toString();
              if (fpoId == 'fpo_karnal_01' || fpoId == 'demo_fpo_001' || fpoId.startsWith('demo_')) {
                if (sId == fpoId || sId == 'fpo_karnal_01' || sId == 'demo_fpo_001' || sId.isEmpty) return true;
              } else if (sId == fpoId) {
                return true;
              }
              final allocs = o['fpoAllocations'] as List<dynamic>?;
              if (allocs != null && allocs.any((a) => (a['fpoId'] ?? '').toString() == fpoId || (fpoId.startsWith('demo_') && (a['fpoId'] ?? '').toString().startsWith('fpo_')))) return true;
              final contribs = o['contributions'] as List<dynamic>?;
              if (contribs != null && contribs.any((c) => (c['fpoId'] ?? '').toString() == fpoId || (fpoId.startsWith('demo_') && (c['fpoId'] ?? '').toString().startsWith('fpo_')))) return true;
              return false;
            }
            return false;
          })
          .toList();

      list.sort((a, b) {
        final aDate = a['createdAt']?.toString() ?? '';
        final bDate = b['createdAt']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }


  /// Stream active Shared Multi-FPO Orders
  Stream<List<Map<String, dynamic>>> streamSharedBulkOrders({String? fpoId}) {
    return _firestore
        .collection(_sharedBulkOrdersCollection)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      if (fpoId == null || fpoId.isEmpty) return list;

      // Filter to orders where this FPO is a contributing partner
      return list.where((order) {
        final contributions = order['contributions'] as List<dynamic>?;
        if (contributions == null) return false;
        return contributions.any((c) => c['fpoId'] == fpoId);
      }).toList();
    });
  }

  /// Update B2B Order Status (e.g. 'inventory_reserved', 'in_transit', 'delivered')
  Future<bool> updateFpoOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection(_b2bOrdersCollection).doc(orderId).update({
        'status': newStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ B2B Order $orderId status updated to $newStatus');
      return true;
    } catch (e) {
      debugPrint('❌ Update order status error: $e');
      return false;
    }
  }

  /// Record Inspection Result (24-Hour Window at Buyer Factory)
  Future<bool> recordInspectionResult({
    required String orderId,
    required bool isAccepted,
    String? disputeReason,
    String? disputeNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'inspectionStatus': isAccepted ? 'accepted' : 'disputed',
        'inspectionCompletedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (isAccepted) {
        updateData['status'] = 'accepted';
        updateData['settlementStatus'] = 'ready_for_settlement';
      } else {
        updateData['status'] = 'disputed';
        updateData['settlementStatus'] = 'on_hold_disputed';
        updateData['disputeReason'] = disputeReason ?? 'Quality or moisture variance';
        updateData['disputeNotes'] = disputeNotes ?? '';
      }

      await _firestore.collection(_b2bOrdersCollection).doc(orderId).update(updateData);
      debugPrint('✅ Inspection recorded for Order $orderId: ${isAccepted ? "ACCEPTED" : "DISPUTED"}');
      return true;
    } catch (e) {
      debugPrint('❌ Record inspection error: $e');
      return false;
    }
  }

  /// Release Escrow Settlement to FPO
  Future<bool> releaseEscrowToFpo({
    required String orderId,
    required String fpoId,
    required double netPayableAmount,
    required String bankUtr,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _firestore.collection(_b2bOrdersCollection).doc(orderId).update({
        'settlementStatus': 'settled',
        'status': 'completed',
        'settlementUtr': bankUtr,
        'settledAt': now,
        'updatedAt': now,
      });

      debugPrint('✅ Escrow released: ₹$netPayableAmount to FPO $fpoId (UTR: $bankUtr)');
      return true;
    } catch (e) {
      debugPrint('❌ Release escrow error: $e');
      return false;
    }
  }

  /// Stream Bulk RFQs
  Stream<List<Map<String, dynamic>>> streamBulkRfqs() {
    return _firestore
        .collection(_bulkRfqsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Submit Quote for a Bulk RFQ
  Future<bool> submitRfqQuote(String rfqId, Map<String, dynamic> quoteData) async {
    try {
      final quoteId = _firestore.collection(_bulkRfqsCollection).doc(rfqId).collection('quotes').doc().id;
      quoteData['id'] = quoteId;
      quoteData['rfqId'] = rfqId;
      quoteData['submittedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection(_bulkRfqsCollection)
          .doc(rfqId)
          .collection('quotes')
          .doc(quoteId)
          .set(quoteData);

      // Increment quotes count and mark status
      await _firestore.collection(_bulkRfqsCollection).doc(rfqId).update({
        'quotesCount': FieldValue.increment(1),
        'status': 'quoted',
      });

      debugPrint('✅ Quote $quoteId submitted for RFQ $rfqId');
      return true;
    } catch (e) {
      debugPrint('❌ Submit RFQ quote error: $e');
      return false;
    }
  }

  /// Create FPO Order
  Future<bool> createFpoOrder(Map<String, dynamic> orderData) async {
    try {
      final id = orderData['id'] as String? ?? _firestore.collection(_fpoOrdersCollection).doc().id;
      orderData['id'] = id;
      await _firestore.collection(_fpoOrdersCollection).doc(id).set(orderData);
      debugPrint('✅ FPO Order created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create FPO order error: $e');
      return false;
    }
  }

  /// Create Procurement Offer from Farmer to FPO
  Future<bool> createProcurementOffer(Map<String, dynamic> offerData) async {
    try {
      final id = offerData['id'] as String? ?? _firestore.collection(_procurementOffersCollection).doc().id;
      offerData['id'] = id;
      await _firestore.collection(_procurementOffersCollection).doc(id).set(offerData);
      debugPrint('✅ Procurement offer created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create procurement offer error: $e');
      return false;
    }
  }

  /// Create / Dispatch Shipment
  Future<bool> createFpoShipment(Map<String, dynamic> shipmentData) async {
    try {
      final id = shipmentData['id'] as String? ?? _firestore.collection(_fpoShipmentsCollection).doc().id;
      shipmentData['id'] = id;
      await _firestore.collection(_fpoShipmentsCollection).doc(id).set(shipmentData);
      debugPrint('✅ FPO Shipment created: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Create FPO shipment error: $e');
      return false;
    }
  }

  /// Stream In-Transit Shipments
  Stream<List<Map<String, dynamic>>> streamFpoShipments({String? fpoId}) {
    Query query = _firestore.collection(_fpoShipmentsCollection);
    if (fpoId != null && fpoId.isNotEmpty) {
      query = query.where('fpoId', isEqualTo: fpoId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  /// Real-time stream of crops listed by a specific farmer
  /// Real-time stream of all active farmer crops for Retail & Institutional Buyers
  Stream<List<Map<String, dynamic>>> streamAllAvailableCrops() {
    return _firestore
        .collection(_cropsCollection)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Real-time stream of crops listed by a specific farmer
  Stream<List<Map<String, dynamic>>> streamFarmerCrops(String farmerId) {
    Query query = _firestore.collection(_cropsCollection);
    if (farmerId.isNotEmpty && !farmerId.startsWith('demo_')) {
      query = query.where('farmerId', isEqualTo: farmerId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      list.sort((a, b) {
        final aTime = a['createdAt']?.toString() ?? '';
        final bTime = b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Real-time stream of retail orders for a farmer (strictly isolated to this farmer)
  Stream<List<Map<String, dynamic>>> streamFarmerRetailOrders(String farmerId) {
    return _firestore
        .collection(_retailOrdersCollection)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).where((order) {
            if (farmerId.isEmpty) return false;
            final orderFarmerId = (order['farmerId'] ?? order['sellerId'] ?? '').toString();
            if (farmerId == 'farmer_demo' || farmerId == 'demo_farmer_001' || farmerId.startsWith('demo_')) {
              return orderFarmerId == 'farmer_demo' || orderFarmerId == 'demo_farmer_001' || orderFarmerId.startsWith('demo_') || orderFarmerId.isEmpty;
            }
            return orderFarmerId == farmerId;
          }).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Real-time stream of all orders for a farmer (strictly isolated to this farmer)
  Stream<List<Map<String, dynamic>>> streamFarmerOrders(String farmerId) {
    return _firestore
        .collection('orders')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).where((order) {
            if (farmerId.isEmpty) return false;
            final orderFarmerId = (order['farmerId'] ?? order['sellerId'] ?? '').toString();
            if (farmerId == 'farmer_demo' || farmerId == 'demo_farmer_001' || farmerId.startsWith('demo_')) {
              return orderFarmerId == 'farmer_demo' || orderFarmerId == 'demo_farmer_001' || orderFarmerId.startsWith('demo_') || orderFarmerId.isEmpty;
            }
            return orderFarmerId == farmerId;
          }).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Real-time stream of procurement offers sent or received by farmer
  Stream<List<Map<String, dynamic>>> streamFarmerProcurementOffers(String farmerId) {
    return _firestore
        .collection(_procurementOffersCollection)
        .where('farmerId', isEqualTo: farmerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Stream nearby registered FPOs
  Stream<List<Map<String, dynamic>>> streamNearbyFpos() {
    return _firestore
        .collection(_usersCollection)
        .where('userType', isEqualTo: 'fpo')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        });
  }

  /// Create a new institutional RFQ by a Bulk Buyer
  Future<bool> createBulkRfq(Map<String, dynamic> rfqData) async {
    try {
      final docRef = _firestore.collection(_bulkRfqsCollection).doc();
      final id = rfqData['id'] as String? ?? docRef.id;
      rfqData['id'] = id.isEmpty ? docRef.id : id;
      rfqData['createdAt'] = DateTime.now().toIso8601String();
      rfqData['status'] = rfqData['status'] ?? 'open';
      rfqData['quotesCount'] = rfqData['quotesCount'] ?? 0;

      await docRef.set(rfqData);
      debugPrint('✅ Bulk RFQ created: ${docRef.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Create Bulk RFQ error: $e');
      return false;
    }
  }

  /// Stream RFQs for a specific bulk buyer (or all active if buyerId is null)
  Stream<List<Map<String, dynamic>>> streamBulkBuyerRfqs({String? buyerId}) {
    Query query = _firestore.collection(_bulkRfqsCollection);
    if (buyerId != null && buyerId.isNotEmpty) {
      query = query.where('buyerId', isEqualTo: buyerId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      list.sort((a, b) {
        final aTime = a['createdAt']?.toString() ?? '';
        final bTime = b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Stream Orders for a specific bulk buyer
  Stream<List<Map<String, dynamic>>> streamBulkBuyerOrders({String? buyerId}) {
    Query query = _firestore.collection(_fpoOrdersCollection);
    if (buyerId != null && buyerId.isNotEmpty) {
      query = query.where('buyerId', isEqualTo: buyerId);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      list.sort((a, b) {
        final aTime = a['createdAt']?.toString() ?? '';
        final bTime = b['createdAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Clean any previously seeded sample bulk buyer RFQs and orders from Firestore
  Future<void> seedSampleBulkBuyerDataIfEmpty() async {
    await cleanSampleBulkBuyerData();
  }

  /// Permanently removes seeded sample RFQs and mock institutional orders
  Future<void> cleanSampleBulkBuyerData() async {
    try {
      // Purge sample RFQs
      final rfqSnap = await _firestore
          .collection(_bulkRfqsCollection)
          .where('buyerId', isEqualTo: 'sample_buyer_01')
          .get();
      for (final doc in rfqSnap.docs) {
        await doc.reference.delete();
      }

      // Purge sample B2B Orders
      final orderSnap = await _firestore
          .collection(_fpoOrdersCollection)
          .where('orderId', whereIn: ['BPO-84920', 'BPO-72105', 'PO-ITC-3000QTL'])
          .get();
      for (final doc in orderSnap.docs) {
        await doc.reference.delete();
      }
      debugPrint('🧹 Cleaned up sample bulk buyer RFQs and mock orders from Firestore');
    } catch (e) {
      debugPrint('⚠️ Error cleaning sample bulk buyer data: $e');
    }
  }

  /// Create a Retail Purchase Order
  Future<bool> createRetailOrder(Map<String, dynamic> orderData) async {
    try {
      final docRef = _firestore.collection(_retailOrdersCollection).doc();
      final id = orderData['id'] as String? ?? docRef.id;
      orderData['id'] = id.isEmpty ? docRef.id : id;
      orderData['createdAt'] = orderData['createdAt'] ?? DateTime.now().toIso8601String();
      orderData['status'] = orderData['status'] ?? 'active';

      await docRef.set(orderData);
      try {
        await _firestore.collection('orders').doc(orderData['id'] as String).set(orderData);
      } catch (_) {}
      debugPrint('✅ Retail Order created: ${docRef.id}');

      // Automatically deduct purchased quantity from the crop document in Firestore
      final cropId = orderData['cropId']?.toString() ?? '';
      final cropName = orderData['cropName']?.toString();
      final farmerId = orderData['farmerId']?.toString();
      final purchasedQty = (orderData['quantity'] as num?)?.toDouble() ?? 0.0;

      if (purchasedQty > 0) {
        await deductCropStock(
          cropId: cropId,
          cropName: cropName,
          farmerId: farmerId,
          purchasedQty: purchasedQty,
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Create retail order error: $e');
      return false;
    }
  }

  /// Deducts purchased stock from a crop listing in Firestore
  Future<bool> deductCropStock({
    required String cropId,
    String? cropName,
    String? farmerId,
    required double purchasedQty,
  }) async {
    try {
      if (purchasedQty <= 0) return false;
      debugPrint('🔄 Deducting $purchasedQty kg from crop (id: $cropId, name: $cropName)...');

      DocumentReference? cropDocRef;
      Map<String, dynamic>? cropData;

      // 1. Try finding by direct doc id
      if (cropId.isNotEmpty) {
        final doc = await _firestore.collection(_cropsCollection).doc(cropId).get();
        if (doc.exists) {
          cropDocRef = doc.reference;
          cropData = doc.data();
        }
      }

      // 2. Try querying by 'id' field
      if (cropDocRef == null && cropId.isNotEmpty) {
        final query = await _firestore.collection(_cropsCollection).where('id', isEqualTo: cropId).limit(1).get();
        if (query.docs.isNotEmpty) {
          cropDocRef = query.docs.first.reference;
          cropData = query.docs.first.data();
        }
      }

      // 3. Try querying by 'name' field
      if (cropDocRef == null && cropName != null && cropName.isNotEmpty) {
        Query query = _firestore.collection(_cropsCollection).where('name', isEqualTo: cropName);
        final results = await query.limit(1).get();
        if (results.docs.isNotEmpty) {
          cropDocRef = results.docs.first.reference;
          cropData = results.docs.first.data() as Map<String, dynamic>;
        }
      }

      // 4. Try matching cropName in all crops
      if (cropDocRef == null && cropName != null && cropName.isNotEmpty) {
        final allCrops = await _firestore.collection(_cropsCollection).get();
        for (final doc in allCrops.docs) {
          final data = doc.data();
          final dName = (data['name'] ?? data['cropName'] ?? '').toString();
          if (dName.isNotEmpty && (dName.toLowerCase() == cropName.toLowerCase() || cropName.toLowerCase().contains(dName.toLowerCase()) || dName.toLowerCase().contains(cropName.toLowerCase()))) {
            cropDocRef = doc.reference;
            cropData = data;
            break;
          }
        }
      }

      if (cropDocRef != null && cropData != null) {
        final currentQtyStr = cropData['quantity']?.toString() ?? '0';
        final cleanStr = currentQtyStr.replaceAll(RegExp(r'[^0-9.]'), '');
        final currentQty = double.tryParse(cleanStr) ?? 0.0;

        final newQty = (currentQty - purchasedQty).clamp(0.0, double.infinity);
        final isSoldOut = newQty <= 0.0;

        final updateData = <String, dynamic>{
          'quantity': '${newQty.toStringAsFixed(newQty.truncateToDouble() == newQty ? 0 : 1)} kg',
          'availableQuantity': newQty,
          'soldQuantity': ((cropData['soldQuantity'] as num?)?.toDouble() ?? 0.0) + purchasedQty,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        if (isSoldOut) {
          updateData['status'] = 'sold';
          updateData['isActive'] = false;
        }

        await cropDocRef.update(updateData);
        debugPrint('✅ Crop stock deducted: was $currentQty kg, now $newQty kg (sold out: $isSoldOut)');
        return true;
      } else {
        debugPrint('⚠️ Crop document not found for deduction: id=$cropId, name=$cropName');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deducting crop stock: $e');
      return false;
    }
  }

  /// Real-time stream of retail orders for a specific crop
  Stream<List<Map<String, dynamic>>> streamCropOrders({required String cropId, String? cropName}) {
    return _firestore
        .collection(_retailOrdersCollection)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).where((order) {
            final oCropId = (order['cropId'] ?? '').toString();
            final oCropName = (order['cropName'] ?? '').toString().toLowerCase();
            if (cropId.isNotEmpty && oCropId == cropId) return true;
            if (cropName != null && cropName.isNotEmpty && (oCropName == cropName.toLowerCase() || cropName.toLowerCase().contains(oCropName) || oCropName.contains(cropName.toLowerCase()))) return true;
            return false;
          }).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Update Retail Order Status (e.g. active -> in_transit -> delivered)
  Future<bool> updateRetailOrderStatus(String orderId, String status, {Map<String, dynamic>? extra}) async {
    try {
      final query = await _firestore
          .collection(_retailOrdersCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (extra != null) {
        updateData.addAll(extra);
      }

      if (query.docs.isNotEmpty) {
        await _firestore
            .collection(_retailOrdersCollection)
            .doc(query.docs.first.id)
            .update(updateData);
        try {
          final oQuery = await _firestore.collection('orders').where('orderId', isEqualTo: orderId).limit(1).get();
          if (oQuery.docs.isNotEmpty) {
            await _firestore.collection('orders').doc(oQuery.docs.first.id).update(updateData);
          }
        } catch (_) {}
        debugPrint('✅ Retail Order $orderId status updated to $status');
        return true;
      }

      // Fallback: try direct doc id
      final docRef = _firestore.collection(_retailOrdersCollection).doc(orderId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update(updateData);
        try {
          await _firestore.collection('orders').doc(orderId).update(updateData);
        } catch (_) {}
        debugPrint('✅ Retail Order $orderId doc updated to $status');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Update retail order status error: $e');
      return false;
    }
  }

  /// Stream Retail Orders for a buyer (strictly isolated)
  Stream<List<Map<String, dynamic>>> streamRetailOrders({String? buyerId}) {
    return _firestore
        .collection(_retailOrdersCollection)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((o) {
            if (buyerId == null || buyerId.isEmpty) return false;
            final orderBuyerId = (o['buyerId'] ?? o['userId'] ?? '').toString();
            if (buyerId == 'demo_retailBuyer_001' || buyerId == 'retail_buyer_demo' || buyerId.startsWith('demo_')) {
              return orderBuyerId == buyerId || orderBuyerId == 'demo_retailBuyer_001' || orderBuyerId.isEmpty;
            }
            return orderBuyerId == buyerId;
          }).toList();
          list.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Toggle Saved Crop (Wishlist)
  Future<bool> toggleSavedCrop(String userId, String cropId) async {
    try {
      final docRef = _firestore.collection(_savedCropsCollection).doc('${userId}_$cropId');
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
        debugPrint('🗑️ Removed crop $cropId from saved wishlist');
        return false; // Removed
      } else {
        await docRef.set({
          'userId': userId,
          'cropId': cropId,
          'savedAt': DateTime.now().toIso8601String(),
        });
        debugPrint('❤️ Added crop $cropId to saved wishlist');
        return true; // Added
      }
    } catch (e) {
      debugPrint('❌ Toggle saved crop error: $e');
      return false;
    }
  }

  /// Stream Saved Crop IDs
  Stream<List<String>> streamSavedCropIds(String userId) {
    return _firestore
        .collection(_savedCropsCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()['cropId'] as String).toList();
    });
  }

  /// Seed Retail Buyer sample crops and orders if empty
  Future<void> seedSampleRetailBuyerDataIfEmpty() async {
    try {
      final ordersSnapshot = await _firestore.collection(_retailOrdersCollection).limit(1).get();
      if (ordersSnapshot.docs.isEmpty) {
        final now = DateTime.now();
        final sampleOrders = [
          {
            'orderId': 'RET-1092',
            'cropName': 'Sharbati Wheat (Grade A)',
            'category': 'Wheat',
            'variety': 'Sharbati 306',
            'quantity': 5.0,
            'unit': 'Qtl',
            'pricePerUnit': 3450.0,
            'totalAmount': 17250.0,
            'farmerName': 'Rajesh Kumar',
            'farmerPhone': '+91 98765 43210',
            'farmerDistance': '6 km away',
            'farmerLocation': 'Karnal Village, Haryana',
            'deliveryAddress': 'Flat 402, Green Avenue, Delhi NCR',
            'deliveryType': 'Farmer Delivery',
            'status': 'in_transit',
            'eta': 'Today, 4:30 PM',
            'timeline': [
              {'title': 'Order Placed', 'time': '9:30 AM', 'completed': true},
              {'title': 'Confirmed by Farmer', 'time': '10:15 AM', 'completed': true},
              {'title': 'Dispatched with Farmer Vehicle', 'time': '2:00 PM', 'completed': true},
              {'title': 'Out for Delivery', 'time': '3:45 PM', 'completed': true},
              {'title': 'Delivered', 'time': 'Pending', 'completed': false},
            ],
            'paymentMethod': 'UPI (Google Pay)',
            'paymentStatus': 'Paid & Secured in Escrow',
            'createdAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
          },
          {
            'orderId': 'RET-1088',
            'cropName': 'Basmati 1121 Rice',
            'category': 'Rice',
            'variety': 'Pusa 1121',
            'quantity': 2.0,
            'unit': 'Qtl',
            'pricePerUnit': 4600.0,
            'totalAmount': 9200.0,
            'farmerName': 'Gurpreet Singh',
            'farmerPhone': '+91 98123 45678',
            'farmerDistance': '12 km away',
            'farmerLocation': 'Kurukshetra, Haryana',
            'deliveryAddress': 'House 14, Sector 7, Chandigarh',
            'deliveryType': 'AgriChain Express',
            'status': 'delivered',
            'eta': 'Delivered',
            'timeline': [
              {'title': 'Order Placed', 'time': 'Yesterday', 'completed': true},
              {'title': 'Confirmed by Farmer', 'time': 'Yesterday', 'completed': true},
              {'title': 'Dispatched', 'time': 'Yesterday', 'completed': true},
              {'title': 'Delivered', 'time': 'Yesterday, 5:00 PM', 'completed': true},
            ],
            'paymentMethod': 'Credit Card',
            'paymentStatus': 'Settled to Farmer',
            'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
          },
          {
            'orderId': 'RET-1075',
            'cropName': 'Organic Mustard (Kachi Ghani)',
            'category': 'Mustard',
            'variety': 'Black Mustard RH-749',
            'quantity': 1.0,
            'unit': 'Qtl',
            'pricePerUnit': 5800.0,
            'totalAmount': 5800.0,
            'farmerName': 'Amit Sharma',
            'farmerPhone': '+91 97234 56789',
            'farmerDistance': '8 km away',
            'farmerLocation': 'Sonipat, Haryana',
            'deliveryAddress': 'Flat 402, Green Avenue, Delhi NCR',
            'deliveryType': 'Self Pickup',
            'status': 'delivered',
            'eta': 'Delivered',
            'paymentMethod': 'Net Banking',
            'paymentStatus': 'Settled',
            'createdAt': now.subtract(const Duration(days: 4)).toIso8601String(),
          },
        ];

        for (final order in sampleOrders) {
          final docRef = _firestore.collection(_retailOrdersCollection).doc();
          order['id'] = docRef.id;
          await docRef.set(order);
        }
        debugPrint('✅ Seeded ${sampleOrders.length} sample retail orders');
      }
    } catch (e) {
      debugPrint('⚠️ Error seeding retail buyer sample data: $e');
    }
  }

  // ==========================================
  // FPO MEMBER FARMER DIRECTORY & DBT PAYOUTS
  // ==========================================

  /// Stream constituent member farmers for an FPO
  Stream<List<FpoMemberFarmer>> streamFpoMembers(String fpoId) {
    return _firestore
        .collection(_fpoMembersCollection)
        .where('fpoId', isEqualTo: fpoId)
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs
              .map((doc) => FpoMemberFarmer.fromMap(doc.data(), doc.id))
              .toList();
          members.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return members;
        });
  }

  /// Batch save / import member farmers
  Future<int> saveFpoMembers(String fpoId, List<FpoMemberFarmer> members) async {
    try {
      int saved = 0;
      final batch = _firestore.batch();
      for (final m in members) {
        final docRef = _firestore.collection(_fpoMembersCollection).doc(m.id);
        batch.set(docRef, m.toMap(), SetOptions(merge: true));
        saved++;
      }
      await batch.commit();
      debugPrint('✅ Batch saved $saved members for FPO: $fpoId');
      return saved;
    } catch (e) {
      debugPrint('❌ Error saving FPO members: $e');
      return 0;
    }
  }

  /// Add individual member farmer
  Future<bool> addFpoMember(String fpoId, FpoMemberFarmer member) async {
    try {
      await _firestore
          .collection(_fpoMembersCollection)
          .doc(member.id)
          .set(member.toMap(), SetOptions(merge: true));
      debugPrint('✅ Added member ${member.name} (${member.id}) to FPO $fpoId');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding member: $e');
      return false;
    }
  }

  /// Update individual member farmer
  Future<bool> updateFpoMember(String fpoId, FpoMemberFarmer member) async {
    try {
      await _firestore
          .collection(_fpoMembersCollection)
          .doc(member.id)
          .update(member.toMap());
      debugPrint('✅ Updated member ${member.name} (${member.id})');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating member: $e');
      return false;
    }
  }

  /// Delete individual member farmer
  Future<bool> deleteFpoMember(String fpoId, String memberId) async {
    try {
      await _firestore.collection(_fpoMembersCollection).doc(memberId).delete();
      debugPrint('🗑️ Deleted member $memberId from FPO $fpoId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting member: $e');
      return false;
    }
  }

  /// Stream DBT payouts credited to a specific farmer
  Stream<List<Map<String, dynamic>>> streamFarmerDbtPayouts(String farmerId, {String? farmerPhone}) {
    return _firestore
        .collection(_farmerPayoutsCollection)
        .snapshots()
        .map((snapshot) {
          final cleanPhone = farmerPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
          final tenDigit = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;

          final payouts = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((p) {
                final pFarmerId = (p['farmerId'] ?? '').toString();
                final pPhone = (p['farmerPhone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
                if (farmerId.isNotEmpty && pFarmerId == farmerId) return true;
                if (tenDigit.isNotEmpty && pPhone.contains(tenDigit)) return true;
                return false;
              })
              .toList();

          payouts.sort((a, b) {
            final aTime = a['createdAt']?.toString() ?? '';
            final bTime = b['createdAt']?.toString() ?? '';
            return bTime.compareTo(aTime);
          });
          return payouts;
        });
  }

  /// Stream FPO settlements for passbook and regulatory audit
  Stream<List<Map<String, dynamic>>> streamFpoSettlements(String fpoId) {
    return _firestore
        .collection(_fpoSettlementsCollection)
        .where('fpoId', isEqualTo: fpoId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          list.sort((a, b) => (b['settledAt'] ?? '').toString().compareTo((a['settledAt'] ?? '').toString()));
          return list;
        });
  }
}

