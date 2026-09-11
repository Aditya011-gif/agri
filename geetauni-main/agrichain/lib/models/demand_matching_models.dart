/// Represents an individual smallholder farmer's or cluster member's crop lot available for matching.
class FarmerCropLot {
  final String id;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String village;
  final String district;
  final String commodity;
  final String variety;
  final double quantityKg;
  final double minAcceptablePricePerKg; // Farmer's reserve price
  final String qualityGrade; // 'Grade A', 'Grade B', 'Fair Average Quality'
  final DateTime harvestDate;
  final int shelfLifeDays;
  final String packagingType; // 'Jute Bags 50kg', 'HDPE Sacks 50kg', 'Crates', 'Loose Bulk'
  final double latitude;
  final double longitude;
  final double reliabilityScore; // 0 to 100 based on past fulfillment
  final bool isAssayed;
  final String certificateUrl;
  final String? fpoAffiliation;

  const FarmerCropLot({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.village,
    required this.district,
    required this.commodity,
    required this.variety,
    required this.quantityKg,
    required this.minAcceptablePricePerKg,
    required this.qualityGrade,
    required this.harvestDate,
    required this.shelfLifeDays,
    required this.packagingType,
    required this.latitude,
    required this.longitude,
    this.reliabilityScore = 88.0,
    this.isAssayed = true,
    this.certificateUrl = '',
    this.fpoAffiliation,
  });

  int get remainingShelfLifeDays {
    final daysElapsed = DateTime.now().difference(harvestDate).inDays;
    final remaining = shelfLifeDays - daysElapsed;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'farmerPhone': farmerPhone,
      'village': village,
      'district': district,
      'commodity': commodity,
      'variety': variety,
      'quantityKg': quantityKg,
      'minAcceptablePricePerKg': minAcceptablePricePerKg,
      'qualityGrade': qualityGrade,
      'harvestDate': harvestDate.toIso8601String(),
      'shelfLifeDays': shelfLifeDays,
      'packagingType': packagingType,
      'latitude': latitude,
      'longitude': longitude,
      'reliabilityScore': reliabilityScore,
      'isAssayed': isAssayed,
      'certificateUrl': certificateUrl,
      'fpoAffiliation': fpoAffiliation,
    };
  }

  factory FarmerCropLot.fromMap(Map<String, dynamic> map) {
    return FarmerCropLot(
      id: map['id'] ?? '',
      farmerId: map['farmerId'] ?? '',
      farmerName: map['farmerName'] ?? '',
      farmerPhone: map['farmerPhone'] ?? '',
      village: map['village'] ?? '',
      district: map['district'] ?? '',
      commodity: map['commodity'] ?? '',
      variety: map['variety'] ?? '',
      quantityKg: (map['quantityKg'] as num?)?.toDouble() ?? 0.0,
      minAcceptablePricePerKg: (map['minAcceptablePricePerKg'] as num?)?.toDouble() ?? 0.0,
      qualityGrade: map['qualityGrade'] ?? 'Grade A',
      harvestDate: map['harvestDate'] != null ? DateTime.tryParse(map['harvestDate']) ?? DateTime.now() : DateTime.now(),
      shelfLifeDays: (map['shelfLifeDays'] as num?)?.toInt() ?? 90,
      packagingType: map['packagingType'] ?? 'Jute Bags 50kg',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 29.9695,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 76.8783,
      reliabilityScore: (map['reliabilityScore'] as num?)?.toDouble() ?? 85.0,
      isAssayed: map['isAssayed'] ?? true,
      certificateUrl: map['certificateUrl'] ?? '',
      fpoAffiliation: map['fpoAffiliation'],
    );
  }
}

/// A buyer's procurement demand requirement.
class BuyerDemandRequirement {
  final String id;
  final String buyerId;
  final String buyerName;
  final String companyName;
  final String commodity;
  final double targetQuantityKg;
  final double maxBudgetPricePerKg; // Buyer's maximum price
  final String requiredGrade;
  final String deliveryLocation;
  final double deliveryLat;
  final double deliveryLng;
  final DateTime earliestDeliveryDate;
  final DateTime latestDeliveryDate;
  final String requiredPackaging;
  final bool allowMultipleLots;
  final double minAcceptableReliabilityScore;

  const BuyerDemandRequirement({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.companyName,
    required this.commodity,
    required this.targetQuantityKg,
    required this.maxBudgetPricePerKg,
    this.requiredGrade = 'Grade A',
    this.deliveryLocation = 'Karnal Central Agro-Logistics Hub',
    this.deliveryLat = 29.6857,
    this.deliveryLng = 76.9905,
    required this.earliestDeliveryDate,
    required this.latestDeliveryDate,
    this.requiredPackaging = 'Jute Bags 50kg',
    this.allowMultipleLots = true,
    this.minAcceptableReliabilityScore = 75.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'companyName': companyName,
      'commodity': commodity,
      'targetQuantityKg': targetQuantityKg,
      'maxBudgetPricePerKg': maxBudgetPricePerKg,
      'requiredGrade': requiredGrade,
      'deliveryLocation': deliveryLocation,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'earliestDeliveryDate': earliestDeliveryDate.toIso8601String(),
      'latestDeliveryDate': latestDeliveryDate.toIso8601String(),
      'requiredPackaging': requiredPackaging,
      'allowMultipleLots': allowMultipleLots,
      'minAcceptableReliabilityScore': minAcceptableReliabilityScore,
    };
  }

  factory BuyerDemandRequirement.fromMap(Map<String, dynamic> map) {
    return BuyerDemandRequirement(
      id: map['id'] ?? '',
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      companyName: map['companyName'] ?? '',
      commodity: map['commodity'] ?? '',
      targetQuantityKg: (map['targetQuantityKg'] as num?)?.toDouble() ?? 500.0,
      maxBudgetPricePerKg: (map['maxBudgetPricePerKg'] as num?)?.toDouble() ?? 35.0,
      requiredGrade: map['requiredGrade'] ?? 'Grade A',
      deliveryLocation: map['deliveryLocation'] ?? 'Karnal Central Hub',
      deliveryLat: (map['deliveryLat'] as num?)?.toDouble() ?? 29.6857,
      deliveryLng: (map['deliveryLng'] as num?)?.toDouble() ?? 76.9905,
      earliestDeliveryDate: map['earliestDeliveryDate'] != null ? DateTime.tryParse(map['earliestDeliveryDate']) ?? DateTime.now() : DateTime.now(),
      latestDeliveryDate: map['latestDeliveryDate'] != null ? DateTime.tryParse(map['latestDeliveryDate']) ?? DateTime.now().add(const Duration(days: 5)) : DateTime.now().add(const Duration(days: 5)),
      requiredPackaging: map['requiredPackaging'] ?? 'Jute Bags 50kg',
      allowMultipleLots: map['allowMultipleLots'] ?? true,
      minAcceptableReliabilityScore: (map['minAcceptableReliabilityScore'] as num?)?.toDouble() ?? 75.0,
    );
  }
}

/// An allocated contribution of a farmer's lot towards fulfilling a buyer demand.
class MatchedLotContribution {
  final FarmerCropLot lot;
  final double allocatedQuantityKg;
  final double agreedPricePerKg;
  final double distanceKm;
  final double estimatedTransitHours;
  final double farmerGrossEarnings;

  const MatchedLotContribution({
    required this.lot,
    required this.allocatedQuantityKg,
    required this.agreedPricePerKg,
    required this.distanceKm,
    required this.estimatedTransitHours,
    required this.farmerGrossEarnings,
  });

  Map<String, dynamic> toMap() {
    return {
      'lot': lot.toMap(),
      'allocatedQuantityKg': allocatedQuantityKg,
      'agreedPricePerKg': agreedPricePerKg,
      'distanceKm': distanceKm,
      'estimatedTransitHours': estimatedTransitHours,
      'farmerGrossEarnings': farmerGrossEarnings,
    };
  }

  factory MatchedLotContribution.fromMap(Map<String, dynamic> map) {
    return MatchedLotContribution(
      lot: FarmerCropLot.fromMap(Map<String, dynamic>.from(map['lot'] ?? {})),
      allocatedQuantityKg: (map['allocatedQuantityKg'] as num?)?.toDouble() ?? 0.0,
      agreedPricePerKg: (map['agreedPricePerKg'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedTransitHours: (map['estimatedTransitHours'] as num?)?.toDouble() ?? 0.0,
      farmerGrossEarnings: (map['farmerGrossEarnings'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full consolidated matching plan created by IntelligentMatchingEngine.
class DemandMatchPlan {
  final String planId;
  final BuyerDemandRequirement buyerRequirement;
  final List<MatchedLotContribution> matchedLots;
  final double totalFulfilledQuantityKg;
  final double totalCost;
  final double weightedAvgPricePerKg;
  final double fulfillmentPercentage;
  final int totalFarmerParticipants;
  final String recommendedVehicle; // 'Tata Ace (1.5T)', 'LCV 407 (4T)', etc.
  final double vehicleCapacityKg;
  final double vehicleCapacityUtilizationPct;
  final double estimatedLogisticsCost;
  final double co2SavedKg;
  final bool isOptimalMatch;
  final double compositeScore; // 0 to 100
  final List<String> matchNotes;
  final DateTime createdAt;

  const DemandMatchPlan({
    required this.planId,
    required this.buyerRequirement,
    required this.matchedLots,
    required this.totalFulfilledQuantityKg,
    required this.totalCost,
    required this.weightedAvgPricePerKg,
    required this.fulfillmentPercentage,
    required this.totalFarmerParticipants,
    required this.recommendedVehicle,
    required this.vehicleCapacityKg,
    required this.vehicleCapacityUtilizationPct,
    required this.estimatedLogisticsCost,
    required this.co2SavedKg,
    required this.isOptimalMatch,
    required this.compositeScore,
    required this.matchNotes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'buyerRequirement': buyerRequirement.toMap(),
      'matchedLots': matchedLots.map((m) => m.toMap()).toList(),
      'totalFulfilledQuantityKg': totalFulfilledQuantityKg,
      'totalCost': totalCost,
      'weightedAvgPricePerKg': weightedAvgPricePerKg,
      'fulfillmentPercentage': fulfillmentPercentage,
      'totalFarmerParticipants': totalFarmerParticipants,
      'recommendedVehicle': recommendedVehicle,
      'vehicleCapacityKg': vehicleCapacityKg,
      'vehicleCapacityUtilizationPct': vehicleCapacityUtilizationPct,
      'estimatedLogisticsCost': estimatedLogisticsCost,
      'co2SavedKg': co2SavedKg,
      'isOptimalMatch': isOptimalMatch,
      'compositeScore': compositeScore,
      'matchNotes': matchNotes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
