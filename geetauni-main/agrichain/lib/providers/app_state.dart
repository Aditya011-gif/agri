import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firestore_models.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/digilocker_service.dart';

class AppState extends ChangeNotifier {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  // Current user state
  FirestoreUser? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;

  // Language & Locale state
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  // Data collections
  List<FirestoreCrop> _crops = [];
  List<FirestoreLoan> _loans = [];
  List<FirestoreOrder> _orders = [];
  List<FirestoreAuction> _auctions = [];
  List<Rating> _ratings = [];
  UserRatingStats? _userRatingStats;

  // Getters
  FirestoreUser? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null && _currentUser != null;

  String get userName => _currentUser?.name ?? 'Guest';
  double get walletBalance => _currentUser?.walletBalance ?? 0.0;
  String? get userLocation => _currentUser?.location;
  bool get isDemoAccount =>
      _currentUser?.metadata['isDemoAccount'] == true ||
      (_currentUser?.id.startsWith('demo_') ?? false);

  List<FirestoreCrop> get crops => _crops;
  List<FirestoreLoan> get loans => _loans;
  List<FirestoreOrder> get orders => _orders;
  List<FirestoreAuction> get auctions => _auctions;
  List<Rating> get ratings => _ratings;
  UserRatingStats? get userRatingStats => _userRatingStats;

  // Filtered crop getters
  List<FirestoreCrop> get myCrops => _currentUser?.userType == UserType.farmer
      ? _crops.where((crop) => crop.farmerId == _currentUser!.id).toList()
      : [];

  List<FirestoreCrop> get availableCrops =>
      _currentUser?.userType != UserType.farmer
      ? _crops.where((crop) => crop.isActive).toList()
      : _crops;

  // Initialize app state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Load saved language preference
      await loadLocale();

      // Listen to auth state changes
      _auth.authStateChanges().listen(_onAuthStateChanged);

      // Check if user is already signed in
      _firebaseUser = _auth.currentUser;
      if (_firebaseUser != null) {
        await _loadUserData(_firebaseUser!.uid);
      }
    } catch (e) {
      _setError('Failed to initialize app: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Language management methods
  Future<void> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('selected_language_code');
      if (code != null && (code == 'en' || code == 'hi')) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved locale: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language_code', newLocale.languageCode);
    } catch (e) {
      debugPrint('Error saving locale preference: $e');
    }
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('hi'));
    } else {
      setLocale(const Locale('en'));
    }
  }

  // Auth state change handler
  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      await _loadUserData(user.uid);
    } else {
      // User signed out - clear all data and reset state
      _currentUser = null;
      _clearData();
      _setLoading(false); // Ensure loading state is reset
      _clearError(); // Clear any previous errors
    }
    notifyListeners();
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String firebaseUid) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint('🔍 Loading user data for Firebase UID: $firebaseUid');

      // Direct user data lookup from Firestore
      Map<String, dynamic>? userData = await _databaseService.getUserByFirebaseUid(firebaseUid);

      // Brief single retry only if brand new registration write is finishing
      if (userData == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        userData = await _databaseService.getUserByFirebaseUid(firebaseUid);
      }

      if (userData != null) {
        debugPrint('✅ User data loaded successfully: ${userData['email']}');
        final userTypeString = userData['userType'] as String? ?? 'farmer';
        _currentUser = FirestoreUser(
          id: userData['id'] ?? firebaseUid,
          name: ((userData['name'] as String?)?.trim().isNotEmpty == true)
              ? (userData['name'] as String).trim()
              : ('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}').trim(),
          email: userData['email'] ?? '',
          phone: userData['phone'],
          userType: UserType.values.firstWhere(
            (e) {
              final str = userTypeString.toLowerCase();
              if (e == UserType.retailBuyer &&
                  (str == 'retailbuyer' || str == 'retail_buyer' || str == 'retail')) return true;
              if (e == UserType.buyer && (str == 'buyer' || str == 'bulk_buyer' || str == 'bulkbuyer')) return true;
              if (e == UserType.fpoMemberFarmer &&
                  (str == 'fpomemberfarmer' ||
                      str == 'fpo_member_farmer' ||
                      str == 'fpomember' ||
                      str == 'fpo_member')) return true;
              return e.name.toLowerCase() == str;
            },
            orElse: () => UserType.farmer,
          ),
          location: userData['location'] ?? userData['address'] ?? 'Karnal, Haryana',
          walletAddress: userData['walletAddress'],
          walletBalance: (userData['walletBalance'] ?? 0.0).toDouble(),
          createdAt: userData['createdAt'] != null
              ? DateTime.parse(userData['createdAt'])
              : DateTime.now(),
          updatedAt: userData['updatedAt'] != null
              ? DateTime.parse(userData['updatedAt'])
              : null,
          isActive: userData['isActive'] ?? true,
          metadata: Map<String, dynamic>.from(userData['metadata'] ?? {}),
          signatureUrl: userData['signatureUrl'],
        );
        await _loadUserRelatedData();
        debugPrint(
          '✅ User profile loaded: ${_currentUser!.name} (${_currentUser!.userType.name})',
        );
      } else {
        debugPrint(
          '❌ User profile not found in Firestore for Firebase UID: $firebaseUid',
        );
        _setError('User profile not found. Please complete your registration.');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      _setError('Failed to load user data: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Instant 1-Tap Demo Role Login for Testing
  void setDemoUserRole(UserType role) {
    String name = 'Rajesh Kumar';
    String email = 'farmer@agrichain.com';
    double wallet = 45000.0;
    if (role == UserType.fpo) {
      name = 'Karnal Agro Producer Co.';
      email = 'fpo@agrichain.com';
      wallet = 1200000.0;
    } else if (role == UserType.buyer) {
      name = 'AgroFoods Milling India Pvt Ltd';
      email = 'buyer@agrichain.com';
      wallet = 15000000.0;
    } else if (role == UserType.retailBuyer) {
      name = 'Aryan Sharma';
      email = 'retail@agrichain.com';
      wallet = 25000.0;
    } else if (role == UserType.fpoMemberFarmer) {
      name = 'Rameshwar Singh';
      email = 'fpomember@agrichain.com';
      wallet = 82500.0;
    }

    _currentUser = FirestoreUser(
      id: role == UserType.fpoMemberFarmer ? 'farmer_ramesh_01' : 'demo_${role.name}_001',
      name: name,
      email: email,
      phone: '+91 98123 45678',
      userType: role,
      location: 'Taraori, Karnal',
      walletBalance: wallet,
      createdAt: DateTime.now(),
      isActive: true,
      metadata: {
        'isDemoAccount': true,
        'fpoName': 'Karnal Agro Producer Co-op',
        'fpoMemberId': 'FPO-MBR-KNL-0842',
      },
    );
    notifyListeners();
    debugPrint('⚡ Logged in as Demo Role: ${_currentUser!.name} (${role.name})');
  }

  /// Login via DigiLocker / MeriPehchaan Verified Citizen
  void setDigilockerUserRole(UserType role, DigilockerProfile profile) {
    double wallet = 75000.0;
    if (role == UserType.fpo) {
      wallet = 2500000.0;
    } else if (role == UserType.buyer) {
      wallet = 20000000.0;
    } else if (role == UserType.retailBuyer) {
      wallet = 50000.0;
    }

    _currentUser = FirestoreUser(
      id: 'digilocker_${role.name}_${profile.certificateId.replaceAll('-', '_')}',
      name: profile.fullName,
      email: '${profile.fullName.toLowerCase().replaceAll(' ', '.')}@digilocker.gov.in',
      phone: '+91 98124 56780',
      userType: role,
      location: profile.address ?? 'Karnal, Haryana',
      walletBalance: wallet,
      createdAt: DateTime.now(),
      isActive: true,
      metadata: {
        'isDigilockerVerified': true,
        'maskedAadhaar': profile.maskedAadhaar,
        'certificateId': profile.certificateId,
        'verifiedAt': profile.verifiedAt.toIso8601String(),
        'digilockerSessionId': profile.sessionId,
        'dob': profile.dob ?? '',
        'gender': profile.gender ?? '',
      },
    );
    notifyListeners();
    debugPrint('🇮🇳 DigiLocker Authenticated: ${_currentUser!.name} (${role.name}) [Cert: ${profile.certificateId}]');
  }


  // Load user-related data
  Future<void> _loadUserRelatedData() async {
    if (_currentUser == null) return;

    try {
      // Load crops based on user type
      final cropDataList = _currentUser!.userType == UserType.farmer
          ? await _databaseService.getCropsByFarmerId(_currentUser!.id)
          : await _databaseService.getAllAvailableCrops();

      _crops = cropDataList.map((data) => _mapToFirestoreCrop(data)).toList();

      // Load loans (placeholder - implement when loan methods are available)
      _loans = [];

      // Load orders for the current user
      await _loadOrders();

      // Load active auctions (placeholder - implement when auction methods are available)
      _auctions = [];

      notifyListeners();
    } catch (e) {
      _setError('Failed to load user data: $e');
    }
  }

  // Helper method to convert Map data to FirestoreCrop
  FirestoreCrop _mapToFirestoreCrop(Map<String, dynamic> data) {
    return FirestoreCrop(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      farmerId: data['farmerId'] ?? '',
      farmerName: data['farmerName'] ?? '',
      location: data['location'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      quantity: data['quantity']?.toString() ?? '',
      harvestDate: data['harvestDate'] is Timestamp
          ? (data['harvestDate'] as Timestamp).toDate()
          : DateTime.parse(
              data['harvestDate'] ?? DateTime.now().toIso8601String(),
            ),
      imageUrl: data['imageUrl'] ?? '',
      description: data['description'] ?? '',
      isNFT: data['isNFT'] ?? false,
      nftTokenId: data['nftTokenId'],
      biddingType: BiddingType.values.firstWhere(
        (e) => e.name == data['biddingType'],
        orElse: () => BiddingType.fixedPrice,
      ),
      auctionId: data['auctionId'],
      auctionEndTime: data['auctionEndTime'] != null
          ? (data['auctionEndTime'] is Timestamp
                ? (data['auctionEndTime'] as Timestamp).toDate()
                : DateTime.parse(data['auctionEndTime']))
          : null,
      startingBid: data['startingBid']?.toDouble(),
      reservePrice: data['reservePrice']?.toDouble(),
      cropType: data['cropType'] != null
          ? CropType.values.firstWhere(
              (e) => e.name == data['cropType'],
              orElse: () => CropType.wheat,
            )
          : null,
      category: data['category'] != null
          ? CropCategory.values.firstWhere(
              (e) => e.name == data['category'],
              orElse: () => CropCategory.grains,
            )
          : null,
      certifications: List<Map<String, dynamic>>.from(
        data['certifications'] ?? [],
      ),
      qualityGrade: QualityGrade.values.firstWhere(
        (e) => e.name == data['qualityGrade'],
        orElse: () => QualityGrade.standard,
      ),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
                ? (data['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(data['updatedAt']))
          : null,
      isActive: data['isActive'] ?? true,
      signatureUrl: data['signatureUrl'],
      agriScore: data['agriScore']?.toDouble(),
      riskTier: data['riskTier'],
      ndviValue: data['ndviValue']?.toDouble(),
      soilType: data['soilType'],
      mlPredictions: data['mlPredictions'] != null
          ? Map<String, dynamic>.from(data['mlPredictions'])
          : null,
    );
  }

  // Authentication methods
  Future<bool> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserType userType,
    required String phone,
    required String aadhaarNumber,
    required String panNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.signUp(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        userType: userType,
        phone: phone,
        aadhaarNumber: aadhaarNumber,
        panNumber: panNumber,
      );

      if (result.success) {
        // User data will be loaded automatically via auth state change
        return true;
      } else {
        _setError(result.message ?? 'Sign up failed');
        return false;
      }
    } catch (e) {
      _setError('Sign up failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _authService.signIn(
        email: email,
        password: password,
      );

      if (result.success) {
        // User data will be loaded automatically via auth state change
        return true;
      } else {
        _setError(result.message ?? 'Sign in failed');
        return false;
      }
    } catch (e) {
      _setError('Sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _currentUser = null;
    _firebaseUser = null;
    try {
      await _authService.signOut();
    } catch (e) {
      _setError('Sign out failed: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Crop management methods
  Future<bool> createCrop({
    required String name,
    required String location,
    required double price,
    required String quantity,
    required DateTime harvestDate,
    required String imageUrl,
    required String description,
    CropType? cropType,
    CropCategory? category,
    QualityGrade qualityGrade = QualityGrade.standard,
    bool isNFT = false,
    BiddingType biddingType = BiddingType.fixedPrice,
    String? signatureUrl,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    try {
      final docId = 'crop_${DateTime.now().millisecondsSinceEpoch}';
      final crop = FirestoreCrop(
        id: docId,
        name: name,
        farmerId: _currentUser!.id,
        farmerName: _currentUser!.name,
        location: location,
        price: price,
        quantity: quantity,
        harvestDate: harvestDate,
        imageUrl: imageUrl,
        description: description,
        isNFT: isNFT,
        biddingType: biddingType,
        cropType: cropType,
        category: category,
        qualityGrade: qualityGrade,
        createdAt: DateTime.now(),
        signatureUrl: signatureUrl,
      );

      // Instantly insert into local state
      _crops.insert(0, crop);
      notifyListeners();

      await _databaseService.createCrop(crop.toFirestore());
      await _loadUserRelatedData(); // Refresh data
      return true;
    } catch (e) {
      _setError('Failed to create crop: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Deduct purchased quantity from local in-memory crops
  void deductCropQuantity(String cropId, String? cropName, double purchasedQty) {
    if (purchasedQty <= 0) return;
    for (int i = 0; i < _crops.length; i++) {
      final c = _crops[i];
      final matchesId = cropId.isNotEmpty && c.id == cropId;
      final matchesName = cropName != null && cropName.isNotEmpty && (c.name.toLowerCase() == cropName.toLowerCase() || cropName.toLowerCase().contains(c.name.toLowerCase()));

      if (matchesId || matchesName) {
        final cleanStr = c.quantity.replaceAll(RegExp(r'[^0-9.]'), '');
        final currentQty = double.tryParse(cleanStr) ?? 0.0;
        final newQty = (currentQty - purchasedQty).clamp(0.0, double.infinity);

        _crops[i] = c.copyWith(
          quantity: '${newQty.toStringAsFixed(newQty.truncateToDouble() == newQty ? 0 : 1)} kg',
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        debugPrint('✅ AppState: Deducted $purchasedQty kg from crop ${c.name}. Remaining: $newQty kg');
        break;
      }
    }
  }

  // Wallet management
  Future<bool> updateWalletBalance(double newBalance) async {
    if (_currentUser == null) return false;

    try {
      final updates = {
        'walletBalance': newBalance,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _databaseService.updateUser(_currentUser!.id, updates);

      _currentUser = _currentUser!.copyWith(
        walletBalance: newBalance,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update wallet balance: $e');
      return false;
    }
  }

  /// Update user digital signature (Base64 or DigiLocker URL)
  Future<bool> updateUserSignature(String signatureUrl) async {
    if (_currentUser == null) return false;

    try {
      final updates = {
        'signatureUrl': signatureUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _databaseService.updateUser(_currentUser!.id, updates);

      _currentUser = _currentUser!.copyWith(
        signatureUrl: signatureUrl,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update signature: $e');
      return false;
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearData() {
    _crops.clear();
    _loans.clear();
    _orders.clear();
    _auctions.clear();
    _ratings.clear();
    _userRatingStats = null;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    _firebaseUser = null;
    _clearData();
    _setLoading(false);
    _clearError();
    notifyListeners();
  }

  Future<void> loadUserData(String firebaseUid) async {
    await _loadUserData(firebaseUid);
  }

  // Refresh data
  Future<void> refreshData() async {
    if (_currentUser != null) {
      await _loadUserRelatedData();
    }
  }

  // Search and filter methods
  List<FirestoreCrop> searchCrops(String query) {
    if (query.isEmpty) return _crops;

    return _crops.where((crop) {
      return crop.name.toLowerCase().contains(query.toLowerCase()) ||
          crop.farmerName.toLowerCase().contains(query.toLowerCase()) ||
          crop.location.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  List<FirestoreCrop> filterCropsByCategory(CropCategory category) {
    return _crops.where((crop) => crop.category == category).toList();
  }

  List<FirestoreCrop> filterCropsByType(CropType type) {
    return _crops.where((crop) => crop.cropType == type).toList();
  }

  // Agri-Score: Update a crop with land analysis results
  Future<void> updateCropAgriScore(String cropId, Map<String, dynamic> analysisResult) async {
    try {
      final updateData = {
        'agriScore': analysisResult['agri_score'],
        'riskTier': analysisResult['risk_category'],
        'ndviValue': analysisResult['ndvi_value'],
        'soilType': analysisResult['soil_type'],
        if (analysisResult['ml_predictions'] != null)
          'mlPredictions': analysisResult['ml_predictions'],
      };

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('crops')
          .doc(cropId)
          .update(updateData);

      // Update local state
      final index = _crops.indexWhere((c) => c.id == cropId);
      if (index != -1) {
        final old = _crops[index];
        _crops[index] = FirestoreCrop(
          id: old.id,
          name: old.name,
          farmerId: old.farmerId,
          farmerName: old.farmerName,
          location: old.location,
          price: old.price,
          quantity: old.quantity,
          harvestDate: old.harvestDate,
          imageUrl: old.imageUrl,
          description: old.description,
          isNFT: old.isNFT,
          nftTokenId: old.nftTokenId,
          biddingType: old.biddingType,
          auctionId: old.auctionId,
          auctionEndTime: old.auctionEndTime,
          startingBid: old.startingBid,
          reservePrice: old.reservePrice,
          cropType: old.cropType,
          category: old.category,
          certifications: old.certifications,
          qualityGrade: old.qualityGrade,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
          isActive: old.isActive,
          signatureUrl: old.signatureUrl,
          agriScore: (analysisResult['agri_score'] as num?)?.toDouble(),
          riskTier: analysisResult['risk_category'] as String?,
          ndviValue: (analysisResult['ndvi_value'] as num?)?.toDouble(),
          soilType: analysisResult['soil_type'] as String?,
          mlPredictions: analysisResult['ml_predictions'] as Map<String, dynamic>?,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating crop agri-score: $e');
      rethrow;
    }
  }

  // Auction methods
  FirestoreAuction? getAuctionByCropId(String cropId) {
    try {
      return _auctions.firstWhere((auction) => auction.cropId == cropId);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> getBidsForAuction(String auctionId) {
    try {
      final auction = _auctions.firstWhere(
        (auction) => auction.id == auctionId,
      );
      return auction.bids;
    } catch (e) {
      return [];
    }
  }

  // Place a bid on an auction
  Future<void> placeBid({
    required String auctionId,
    required double bidAmount,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find the auction
      final auctionIndex = _auctions.indexWhere(
        (auction) => auction.id == auctionId,
      );
      if (auctionIndex == -1) {
        throw Exception('Auction not found');
      }

      final auction = _auctions[auctionIndex];

      // Validate bid amount
      final currentBids = auction.bids;
      final currentHighestBid = currentBids.isNotEmpty
          ? (currentBids.last['amount'] as num).toDouble()
          : auction.startingPrice;

      if (bidAmount <= currentHighestBid) {
        throw Exception('Bid amount must be higher than current highest bid');
      }

      // Create new bid
      final newBid = {
        'bidderName': _currentUser!.name,
        'bidderId': _currentUser!.id,
        'amount': bidAmount,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Update auction with new bid
      final updatedBids = List<Map<String, dynamic>>.from(auction.bids)
        ..add(newBid);

      final updatedAuction = FirestoreAuction(
        id: auction.id,
        cropId: auction.cropId,
        sellerId: auction.sellerId,
        sellerName: auction.sellerName,
        startingPrice: auction.startingPrice,
        reservePrice: auction.reservePrice,
        startTime: auction.startTime,
        endTime: auction.endTime,
        status: auction.status,
        bids: updatedBids,
        createdAt: auction.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update local state
      _auctions[auctionIndex] = updatedAuction;

      // Update user's wallet balance
      _currentUser = _currentUser!.copyWith(
        walletBalance: _currentUser!.walletBalance - bidAmount,
      );

      notifyListeners();

      // TODO: Update Firestore with new bid and user balance
      // await _databaseService.updateAuction(updatedAuction);
      // await _databaseService.updateUserWalletBalance(_currentUser!.id, _currentUser!.walletBalance);
    } catch (e) {
      throw Exception('Failed to place bid: $e');
    }
  }

  // Add a new order
  Future<void> addOrder(FirestoreOrder order) async {
    try {
      // Add order to local state
      _orders.add(order);
      notifyListeners();

      // Reload orders from Firebase to get the updated list
      await _loadOrders();
    } catch (e) {
      throw Exception('Failed to add order: $e');
    }
  }

  // Load orders from Firebase
  Future<void> _loadOrders() async {
    if (_currentUser == null && _firebaseUser == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final ordersCollection = firestore.collection('orders');
      final currentUserId = _currentUser?.id ?? _firebaseUser?.uid ?? '';
      final firebaseUid = _firebaseUser?.uid ?? currentUserId;

      final Set<String> targetIds = {currentUserId, firebaseUid}..removeWhere((id) => id.isEmpty);

      final allOrderDocs = <String, QueryDocumentSnapshot>{};

      for (final id in targetIds) {
        // Query buyer orders
        final buyerOrders = await ordersCollection
            .where('buyerId', isEqualTo: id)
            .get();
        for (var doc in buyerOrders.docs) {
          allOrderDocs[doc.id] = doc;
        }

        // Also try to get seller orders if user is a farmer
        try {
          final sellerOrders = await ordersCollection
              .where('sellerId', isEqualTo: id)
              .get();
          for (var doc in sellerOrders.docs) {
            allOrderDocs[doc.id] = doc;
          }
        } catch (_) {
          // sellerId field may not exist on older orders
        }
      }

      // Convert to FirestoreOrder objects
      _orders = allOrderDocs.values.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return FirestoreOrder(
          id: data['id']?.toString() ?? doc.id,
          cropId: data['cropId']?.toString() ?? '',
          quantity: data['quantity']?.toString() ?? '',
          totalAmount: (data['totalAmount'] is num)
              ? (data['totalAmount'] as num).toDouble()
              : (double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0),
          buyerId: data['buyerId']?.toString() ?? '',
          buyerName: data['buyerName']?.toString() ?? '',
          sellerId: data['sellerId']?.toString() ?? '',
          sellerName: data['sellerName']?.toString() ?? '',
          status: OrderStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => OrderStatus.pending,
          ),
          orderDate: data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(
                  data['createdAt'] ?? DateTime.now().toIso8601String(),
                ),
          createdAt: data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(
                  data['createdAt'] ?? DateTime.now().toIso8601String(),
                ),
          updatedAt: data['updatedAt'] != null
              ? (data['updatedAt'] is Timestamp
                    ? (data['updatedAt'] as Timestamp).toDate()
                    : DateTime.parse(data['updatedAt']))
              : null,
          metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        );
      }).toList();

      // Sort by creation date (newest first)
      _orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      // Don't throw, just log the error
    }
  }

  // Rating management methods

  /// Add a new rating
  Future<bool> addRating({
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
    required RatingType ratingType,
    required double rating,
    String? review,
    String? transactionId,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    try {
      final ratingData = {
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'rating': rating,
        'review': review,
        'ratingType': ratingType.name,
        'orderId': transactionId,
        'metadata': <String, dynamic>{},
      };

      final success = await _databaseService.addRating(ratingData);

      if (success) {
        // Update local rating stats for the rated user
        await calculateRatingStats(toUserId);

        // Refresh ratings data
        await _loadRatingData();
      }

      return success;
    } catch (e) {
      _setError('Failed to add rating: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get ratings for a specific user
  Future<List<Rating>> getRatingsForUser(
    String userId, {
    RatingType? ratingType,
  }) async {
    try {
      final ratingsData = await _databaseService.getRatingsForUser(
        userId,
        ratingType: ratingType?.name,
      );

      return ratingsData.map((data) => _mapToRating(data)).toList();
    } catch (e) {
      _setError('Failed to get ratings for user: $e');
      return [];
    }
  }

  /// Calculate rating statistics for a user
  Future<UserRatingStats?> calculateRatingStats(String userId) async {
    try {
      await _databaseService.calculateRatingStats(userId);

      // Get the updated stats
      final statsData = await _databaseService.getUserRatingStats(userId);

      if (statsData != null) {
        return _mapToUserRatingStats(statsData);
      }

      return null;
    } catch (e) {
      _setError('Failed to calculate rating stats: $e');
      return null;
    }
  }

  /// Load rating data for the current user
  Future<void> _loadRatingData() async {
    if (_currentUser == null) return;

    try {
      // Load ratings for current user
      final ratingsData = await _databaseService.getRatingsForUser(
        _currentUser!.id,
      );
      _ratings = ratingsData.map((data) => _mapToRating(data)).toList();

      // Load rating stats for current user
      final statsData = await _databaseService.getUserRatingStats(
        _currentUser!.id,
      );
      if (statsData != null) {
        _userRatingStats = _mapToUserRatingStats(statsData);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load rating data: $e');
    }
  }

  /// Helper method to convert Map data to Rating
  Rating _mapToRating(Map<String, dynamic> data) {
    return Rating(
      id: data['id'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      review: data['review'],
      ratingType: data['ratingType'] != null
          ? RatingType.values.firstWhere(
              (e) => e.name == data['ratingType'],
              orElse: () => RatingType.overall,
            )
          : null,
      orderId: data['orderId'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] is Timestamp
                ? (data['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(data['updatedAt']))
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Helper method to convert Map data to UserRatingStats
  UserRatingStats _mapToUserRatingStats(Map<String, dynamic> data) {
    return UserRatingStats(
      userId: data['userId'] ?? '',
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      ratingsByType: Map<RatingType, double>.fromEntries(
        (data['ratingsByType'] as Map<String, dynamic>? ?? {}).entries.map(
          (entry) => MapEntry(
            RatingType.values.firstWhere((e) => e.name == entry.key),
            (entry.value as num).toDouble(),
          ),
        ),
      ),
      countsByType: Map<RatingType, int>.fromEntries(
        (data['countsByType'] as Map<String, dynamic>? ?? {}).entries.map(
          (entry) => MapEntry(
            RatingType.values.firstWhere((e) => e.name == entry.key),
            entry.value as int,
          ),
        ),
      ),
      fiveStarCount: data['fiveStarCount'] ?? 0,
      fourStarCount: data['fourStarCount'] ?? 0,
      threeStarCount: data['threeStarCount'] ?? 0,
      twoStarCount: data['twoStarCount'] ?? 0,
      oneStarCount: data['oneStarCount'] ?? 0,
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.parse(
              data['lastUpdated'] ?? DateTime.now().toIso8601String(),
            ),
    );
  }

  // Static data for backward compatibility (can be removed later)
  static final Map<CropType, Map<String, dynamic>> cropPricing = {
    CropType.wheat: {
      'msp': 2425.0,
      'marketPrice': 2500.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.rice: {
      'msp': 2300.0,
      'marketPrice': 2400.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.potato: {
      'msp': 0.0,
      'marketPrice': 1200.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.maize: {
      'msp': 1876.0,
      'marketPrice': 1950.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.tomato: {
      'msp': 800.0,
      'marketPrice': 1500.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.onion: {
      'msp': 1450.0,
      'marketPrice': 2200.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.cotton: {
      'msp': 7521.0,
      'marketPrice': 8025.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.sugarcane: {
      'msp': 340.0,
      'marketPrice': 355.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.soybean: {
      'msp': 4892.0,
      'marketPrice': 5175.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.apple: {
      'msp': 0.0,
      'marketPrice': 6500.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.banana: {
      'msp': 0.0,
      'marketPrice': 2100.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
    CropType.mango: {
      'msp': 0.0,
      'marketPrice': 4750.0,
      'unit': 'per quintal',
      'season': '2025-26',
    },
  };
}
