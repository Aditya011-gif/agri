import 'dart:math' as Math;
import 'package:cloud_firestore/cloud_firestore.dart';

// Enums
enum CropCategory { grains, vegetables, fruits, pulses, spices, oilseeds }

enum CropType {
  wheat,
  rice,
  potato,
  tomato,
  onion,
  maize,
  mango,
  apple,
  banana,
  cotton,
  sugarcane,
  soybean,
}

enum CertificationType { organic, fssai, agmark, iso, gmp, haccp }

enum QualityGrade { premium, grade1, grade2, standard }

enum UserType { farmer, buyer, lender, admin, fpo, retailBuyer, fpoMemberFarmer }

enum RatingType { quality, delivery, communication, overall, buyer, seller }

enum LoanStatus { pending, active, completed, defaulted, overdue }

enum LoanRequestStatus { open, closed, funded }

enum LoanOfferStatus { pending, accepted, rejected, expired }

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

enum BiddingType { fixedPrice, auction }

enum AuctionStatus { active, ended, cancelled }

// Firestore-compatible User model
class FirestoreUser {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserType userType;
  final String? location;
  final String? walletAddress;
  final double walletBalance;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Map<String, dynamic> metadata;
  final String? signatureUrl;

  FirestoreUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.userType,
    this.location,
    this.walletAddress,
    this.walletBalance = 0.0,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.metadata = const {},
    this.signatureUrl,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType.name,
      'location': location,
      'walletAddress': walletAddress,
      'walletBalance': walletBalance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'metadata': metadata,
      'signatureUrl': signatureUrl,
    };
  }

  factory FirestoreUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      userType: UserType.values.firstWhere(
        (e) {
          final str = (data['userType'] ?? '').toString().toLowerCase();
          if (e == UserType.retailBuyer && (str == 'retailbuyer' || str == 'retail_buyer')) return true;
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
      location: data['location'],
      walletAddress: data['walletAddress'],
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      signatureUrl: data['signatureUrl'],
    );
  }

  FirestoreUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserType? userType,
    String? location,
    String? walletAddress,
    double? walletBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
    String? signatureUrl,
  }) {
    return FirestoreUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      location: location ?? this.location,
      walletAddress: walletAddress ?? this.walletAddress,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      signatureUrl: signatureUrl ?? this.signatureUrl,
    );
  }
}

// Firestore-compatible Crop model
class FirestoreCrop {
  final String id;
  final String name;
  final String farmerId;
  final String farmerName;
  final String location;
  final double price;
  final String quantity;
  final DateTime harvestDate;
  final String imageUrl;
  final String description;
  final bool isNFT;
  final String? nftTokenId;
  final BiddingType biddingType;
  final String? auctionId;
  final DateTime? auctionEndTime;
  final double? startingBid;
  final double? reservePrice;
  final CropType? cropType;
  final CropCategory? category;
  final List<Map<String, dynamic>> certifications;
  final QualityGrade qualityGrade;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final String? signatureUrl;

  // Agri-Score Analysis Fields
  final double? agriScore;
  final String? riskTier;
  final double? ndviValue;
  final String? soilType;
  final Map<String, dynamic>? mlPredictions;

  FirestoreCrop({
    required this.id,
    required this.name,
    required this.farmerId,
    required this.farmerName,
    required this.location,
    required this.price,
    required this.quantity,
    required this.harvestDate,
    required this.imageUrl,
    required this.description,
    this.isNFT = false,
    this.nftTokenId,
    this.biddingType = BiddingType.fixedPrice,
    this.auctionId,
    this.auctionEndTime,
    this.startingBid,
    this.reservePrice,
    this.cropType,
    this.category,
    this.certifications = const [],
    this.qualityGrade = QualityGrade.standard,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.signatureUrl,
    this.agriScore,
    this.riskTier,
    this.ndviValue,
    this.soilType,
    this.mlPredictions,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'location': location,
      'price': price,
      'quantity': quantity,
      'harvestDate': Timestamp.fromDate(harvestDate),
      'imageUrl': imageUrl,
      'description': description,
      'isNFT': isNFT,
      'nftTokenId': nftTokenId,
      'biddingType': biddingType.name,
      'auctionId': auctionId,
      'auctionEndTime': auctionEndTime != null
          ? Timestamp.fromDate(auctionEndTime!)
          : null,
      'startingBid': startingBid,
      'reservePrice': reservePrice,
      'cropType': cropType?.name,
      'category': category?.name,
      'certifications': certifications,
      'qualityGrade': qualityGrade.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'signatureUrl': signatureUrl,
      'agriScore': agriScore,
      'riskTier': riskTier,
      'ndviValue': ndviValue,
      'soilType': soilType,
      'mlPredictions': mlPredictions,
    };
  }

  factory FirestoreCrop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreCrop(
      id: doc.id,
      name: data['name'] ?? '',
      farmerId: data['farmerId'] ?? '',
      farmerName: data['farmerName'] ?? '',
      location: data['location'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      quantity: data['quantity']?.toString() ?? '',
      harvestDate: (data['harvestDate'] as Timestamp).toDate(),
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
          ? (data['auctionEndTime'] as Timestamp).toDate()
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      signatureUrl: data['signatureUrl'],
      agriScore: data['agriScore']?.toDouble(),
      riskTier: data['riskTier'],
      ndviValue: data['ndviValue']?.toDouble(),
      soilType: data['soilType'],
      mlPredictions: data['mlPredictions'] as Map<String, dynamic>?,
    );
  }

  bool get isAuction => biddingType == BiddingType.auction;

  bool get isAuctionActive {
    if (!isAuction || auctionEndTime == null) return false;
    return DateTime.now().isBefore(auctionEndTime!);
  }

  FirestoreCrop copyWith({
    String? id,
    String? name,
    String? farmerId,
    String? farmerName,
    String? location,
    double? price,
    String? quantity,
    DateTime? harvestDate,
    String? imageUrl,
    String? description,
    bool? isNFT,
    String? nftTokenId,
    BiddingType? biddingType,
    String? auctionId,
    DateTime? auctionEndTime,
    double? startingBid,
    double? reservePrice,
    CropType? cropType,
    CropCategory? category,
    List<Map<String, dynamic>>? certifications,
    QualityGrade? qualityGrade,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? signatureUrl,
    double? agriScore,
    String? riskTier,
    double? ndviValue,
    String? soilType,
    Map<String, dynamic>? mlPredictions,
  }) {
    return FirestoreCrop(
      id: id ?? this.id,
      name: name ?? this.name,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      location: location ?? this.location,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      harvestDate: harvestDate ?? this.harvestDate,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isNFT: isNFT ?? this.isNFT,
      nftTokenId: nftTokenId ?? this.nftTokenId,
      biddingType: biddingType ?? this.biddingType,
      auctionId: auctionId ?? this.auctionId,
      auctionEndTime: auctionEndTime ?? this.auctionEndTime,
      startingBid: startingBid ?? this.startingBid,
      reservePrice: reservePrice ?? this.reservePrice,
      cropType: cropType ?? this.cropType,
      category: category ?? this.category,
      certifications: certifications ?? this.certifications,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      agriScore: agriScore ?? this.agriScore,
      riskTier: riskTier ?? this.riskTier,
      ndviValue: ndviValue ?? this.ndviValue,
      soilType: soilType ?? this.soilType,
      mlPredictions: mlPredictions ?? this.mlPredictions,
    );
  }
}

// Firestore-compatible Loan model
class FirestoreLoan {
  final String id;
  final String borrowerId;
  final String borrowerName;
  final double amount;
  final String collateralNFT;
  final double interestRate;
  final int duration;
  final LoanStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  FirestoreLoan({
    required this.id,
    required this.borrowerId,
    required this.borrowerName,
    required this.amount,
    required this.collateralNFT,
    required this.interestRate,
    required this.duration,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'borrowerId': borrowerId,
      'borrowerName': borrowerName,
      'amount': amount,
      'collateralNFT': collateralNFT,
      'interestRate': interestRate,
      'duration': duration,
      'status': status.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  factory FirestoreLoan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreLoan(
      id: doc.id,
      borrowerId: data['borrowerId'] ?? '',
      borrowerName: data['borrowerName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      collateralNFT: data['collateralNFT'] ?? '',
      interestRate: (data['interestRate'] ?? 0.0).toDouble(),
      duration: data['duration'] ?? 0,
      status: LoanStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => LoanStatus.pending,
      ),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  double calculateMonthlyPayment() {
    final monthlyRate = interestRate / 100 / 12;
    final numPayments = duration;
    return amount *
        (monthlyRate * Math.pow(1 + monthlyRate, numPayments)) /
        (Math.pow(1 + monthlyRate, numPayments) - 1);
  }
}

// Firestore-compatible Order model
class FirestoreOrder {
  final String id;
  final String cropId;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String quantity;
  final double totalAmount;
  final OrderStatus status;
  final DateTime orderDate;
  final DateTime? expectedDelivery;
  final DateTime? actualDelivery;
  final bool buyerRated;
  final bool sellerRated;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  FirestoreOrder({
    required this.id,
    required this.cropId,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    this.expectedDelivery,
    this.actualDelivery,
    this.buyerRated = false,
    this.sellerRated = false,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'cropId': cropId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'status': status.name,
      'orderDate': Timestamp.fromDate(orderDate),
      'expectedDelivery': expectedDelivery != null
          ? Timestamp.fromDate(expectedDelivery!)
          : null,
      'actualDelivery': actualDelivery != null
          ? Timestamp.fromDate(actualDelivery!)
          : null,
      'buyerRated': buyerRated,
      'sellerRated': sellerRated,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  factory FirestoreOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreOrder(
      id: doc.id,
      cropId: data['cropId']?.toString() ?? '',
      buyerId: data['buyerId']?.toString() ?? '',
      buyerName: data['buyerName']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      sellerName: data['sellerName']?.toString() ?? '',
      quantity: data['quantity']?.toString() ?? '',
      totalAmount: (data['totalAmount'] is num)
          ? (data['totalAmount'] as num).toDouble()
          : (double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      expectedDelivery: data['expectedDelivery'] != null
          ? (data['expectedDelivery'] as Timestamp).toDate()
          : null,
      actualDelivery: data['actualDelivery'] != null
          ? (data['actualDelivery'] as Timestamp).toDate()
          : null,
      buyerRated: data['buyerRated'] ?? false,
      sellerRated: data['sellerRated'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

// Firestore-compatible Auction model
class FirestoreAuction {
  final String id;
  final String cropId;
  final String sellerId;
  final String sellerName;
  final double startingPrice;
  final double? reservePrice;
  final DateTime startTime;
  final DateTime endTime;
  final AuctionStatus status;
  final List<Map<String, dynamic>> bids;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  FirestoreAuction({
    required this.id,
    required this.cropId,
    required this.sellerId,
    required this.sellerName,
    required this.startingPrice,
    this.reservePrice,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.bids = const [],
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'cropId': cropId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'startingPrice': startingPrice,
      'reservePrice': reservePrice,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'status': status.name,
      'bids': bids,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  factory FirestoreAuction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreAuction(
      id: doc.id,
      cropId: data['cropId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      startingPrice: (data['startingPrice'] ?? 0.0).toDouble(),
      reservePrice: data['reservePrice']?.toDouble(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: AuctionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AuctionStatus.active,
      ),
      bids: List<Map<String, dynamic>>.from(data['bids'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  double get currentHighestBid {
    if (bids.isEmpty) return startingPrice;
    return bids
        .map((bid) => (bid['amount'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  bool get isActive =>
      status == AuctionStatus.active && DateTime.now().isBefore(endTime);
}

// Security Log model for Firestore
class FirestoreSecurityLog {
  final String id;
  final String userId;
  final String event;
  final String ipAddress;
  final String userAgent;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  FirestoreSecurityLog({
    required this.id,
    required this.userId,
    required this.event,
    required this.ipAddress,
    required this.userAgent,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'event': event,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory FirestoreSecurityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreSecurityLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      event: data['event'] ?? '',
      ipAddress: data['ipAddress'] ?? '',
      userAgent: data['userAgent'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

// Session model for Firestore
class FirestoreSession {
  final String id;
  final String userId;
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String? deviceInfo;
  final String? ipAddress;

  FirestoreSession({
    required this.id,
    required this.userId,
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.deviceInfo,
    this.ipAddress,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'token': token,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'deviceInfo': deviceInfo,
      'ipAddress': ipAddress,
    };
  }

  factory FirestoreSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FirestoreSession(
      id: doc.id,
      userId: data['userId'] ?? '',
      token: data['token'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      deviceInfo: data['deviceInfo'],
      ipAddress: data['ipAddress'],
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// Firestore-compatible Rating model
class Rating {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double rating;
  final String? review;
  final RatingType? ratingType;
  final String? orderId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  Rating({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.rating,
    this.review,
    this.ratingType,
    this.orderId,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'rating': rating,
      'review': review,
      'ratingType': ratingType?.name,
      'orderId': orderId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }
}

// User Rating Statistics model
class UserRatingStats {
  final String userId;
  final double averageRating;
  final int totalRatings;
  final Map<RatingType, double> ratingsByType;
  final Map<RatingType, int> countsByType;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;
  final DateTime lastUpdated;

  UserRatingStats({
    required this.userId,
    required this.averageRating,
    required this.totalRatings,
    required this.ratingsByType,
    required this.countsByType,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
    required this.lastUpdated,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'ratingsByType': ratingsByType.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'countsByType': countsByType.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'fiveStarCount': fiveStarCount,
      'fourStarCount': fourStarCount,
      'threeStarCount': threeStarCount,
      'twoStarCount': twoStarCount,
      'oneStarCount': oneStarCount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory UserRatingStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRatingStats(
      userId: doc.id,
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
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  factory UserRatingStats.empty(String userId) {
    return UserRatingStats(
      userId: userId,
      averageRating: 0.0,
      totalRatings: 0,
      ratingsByType: {},
      countsByType: {},
      fiveStarCount: 0,
      fourStarCount: 0,
      threeStarCount: 0,
      twoStarCount: 0,
      oneStarCount: 0,
      lastUpdated: DateTime.now(),
    );
  }
}

// ----------------------------------------------------
// FPO Specific Domain Models
// ----------------------------------------------------

class FpoBulkLot {
  final String id;
  final String fpoId;
  final String lotNumber;
  final String cropName;
  final CropType cropType;
  final CropCategory category;
  final double totalQuantityKg;
  final double reservedQuantityKg;
  final double basePricePerKg;
  final QualityGrade qualityGrade;
  final List<CertificationType> certifications;
  final String warehouseLocation;
  final DateTime aggregatedDate;
  final bool isListed;
  final Map<String, dynamic> metadata;

  double get availableQuantityKg => totalQuantityKg - reservedQuantityKg;

  FpoBulkLot({
    required this.id,
    required this.fpoId,
    required this.lotNumber,
    required this.cropName,
    required this.cropType,
    required this.category,
    required this.totalQuantityKg,
    this.reservedQuantityKg = 0.0,
    required this.basePricePerKg,
    this.qualityGrade = QualityGrade.premium,
    this.certifications = const [],
    required this.warehouseLocation,
    required this.aggregatedDate,
    this.isListed = true,
    this.metadata = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fpoId': fpoId,
      'lotNumber': lotNumber,
      'cropName': cropName,
      'cropType': cropType.name,
      'category': category.name,
      'totalQuantityKg': totalQuantityKg,
      'reservedQuantityKg': reservedQuantityKg,
      'basePricePerKg': basePricePerKg,
      'qualityGrade': qualityGrade.name,
      'certifications': certifications.map((c) => c.name).toList(),
      'warehouseLocation': warehouseLocation,
      'aggregatedDate': Timestamp.fromDate(aggregatedDate),
      'isListed': isListed,
      'metadata': metadata,
    };
  }

  factory FpoBulkLot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FpoBulkLot(
      id: doc.id,
      fpoId: data['fpoId'] ?? '',
      lotNumber: data['lotNumber'] ?? '',
      cropName: data['cropName'] ?? '',
      cropType: CropType.values.firstWhere(
        (e) => e.name == data['cropType'],
        orElse: () => CropType.wheat,
      ),
      category: CropCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => CropCategory.grains,
      ),
      totalQuantityKg: (data['totalQuantityKg'] ?? 0.0).toDouble(),
      reservedQuantityKg: (data['reservedQuantityKg'] ?? 0.0).toDouble(),
      basePricePerKg: (data['basePricePerKg'] ?? 0.0).toDouble(),
      qualityGrade: QualityGrade.values.firstWhere(
        (e) => e.name == data['qualityGrade'],
        orElse: () => QualityGrade.grade1,
      ),
      certifications: (data['certifications'] as List<dynamic>? ?? [])
          .map((c) => CertificationType.values.firstWhere(
                (e) => e.name == c,
                orElse: () => CertificationType.organic,
              ))
          .toList(),
      warehouseLocation: data['warehouseLocation'] ?? '',
      aggregatedDate: (data['aggregatedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isListed: data['isListed'] ?? true,
      metadata: data['metadata'] ?? {},
    );
  }
}

class ProcurementOffer {
  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String village;
  final String cropName;
  final CropType cropType;
  final double estimatedQuantityKg;
  final double offeredPricePerKg;
  final QualityGrade qualityGrade;
  final DateTime harvestDate;
  final String status; // 'pending', 'accepted', 'collected', 'rejected'
  final DateTime createdAt;

  ProcurementOffer({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.village,
    required this.cropName,
    required this.cropType,
    required this.estimatedQuantityKg,
    required this.offeredPricePerKg,
    required this.qualityGrade,
    required this.harvestDate,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'village': village,
      'cropName': cropName,
      'cropType': cropType.name,
      'estimatedQuantityKg': estimatedQuantityKg,
      'offeredPricePerKg': offeredPricePerKg,
      'qualityGrade': qualityGrade.name,
      'harvestDate': Timestamp.fromDate(harvestDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class BulkRfq {
  final String id;
  final String buyerId;
  final String buyerName;
  final String companyName;
  final String cropName;
  final CropType cropType;
  final double requiredQuantityKg;
  final double targetPricePerKg;
  final String deliveryLocation;
  final DateTime deadline;
  final String status; // 'open', 'quoted', 'accepted', 'closed'
  final int quotesCount;
  final DateTime createdAt;

  BulkRfq({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.companyName,
    required this.cropName,
    required this.cropType,
    required this.requiredQuantityKg,
    required this.targetPricePerKg,
    required this.deliveryLocation,
    required this.deadline,
    this.status = 'open',
    this.quotesCount = 0,
    required this.createdAt,
  });
}

class FpoShipment {
  final String id;
  final String orderId;
  final String buyerName;
  final String destination;
  final String driverName;
  final String driverPhone;
  final String vehicleNumber;
  final String trackingStatus; // 'dispatched', 'in_transit', 'arrived', 'delivered'
  final double totalWeightKg;
  final DateTime dispatchTime;
  final DateTime estimatedArrival;
  final double currentLat;
  final double currentLng;
  final List<String> waypoints;

  FpoShipment({
    required this.id,
    required this.orderId,
    required this.buyerName,
    required this.destination,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleNumber,
    required this.trackingStatus,
    required this.totalWeightKg,
    required this.dispatchTime,
    required this.estimatedArrival,
    required this.currentLat,
    required this.currentLng,
    required this.waypoints,
  });
}
