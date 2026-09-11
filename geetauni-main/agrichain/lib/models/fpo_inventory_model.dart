/// Model: FPO Warehouse Inventory & Commercial Bulk Crop Listings
/// Strictly enforces B2B wholesale operational source truth with atomic reservation states.

enum InventoryStatus {
  available,
  partiallyReserved,
  reserved,
  sold,
  unavailable,
}

enum ListingStatus {
  draft,
  published,
  paused,
  cancelled,
}

class FpoInventoryItem {
  final String id;
  final String fpoId;
  final String fpoName;
  final String cropName;
  final String variety;
  final double totalQuantityMT;
  final double reservedQuantityMT;
  final double soldQuantityMT;
  final String unit; // 'MT' standard
  final String qualityGrade; // 'Grade A (Milling)', 'Export Grade', etc.
  final double moisturePct;
  final double foreignMatterPct;
  final double? oilContentPct;
  final String warehouseId;
  final String warehouseName;
  final String storageLocation; // e.g. 'Silo Bay 04', 'Covered Dock A'
  final double pricePerMT;
  final double pricePerQtl;
  final InventoryStatus inventoryStatus;
  final ListingStatus listingStatus;
  final String? activeListingId;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FpoInventoryItem({
    required this.id,
    required this.fpoId,
    required this.fpoName,
    required this.cropName,
    required this.variety,
    required this.totalQuantityMT,
    this.reservedQuantityMT = 0.0,
    this.soldQuantityMT = 0.0,
    this.unit = 'MT',
    required this.qualityGrade,
    this.moisturePct = 11.2,
    this.foreignMatterPct = 0.8,
    this.oilContentPct,
    required this.warehouseId,
    required this.warehouseName,
    required this.storageLocation,
    required this.pricePerMT,
    required this.pricePerQtl,
    this.inventoryStatus = InventoryStatus.available,
    this.listingStatus = ListingStatus.published,
    this.activeListingId,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Available quantity is strictly computed: Total - Reserved - Sold
  double get availableQuantityMT =>
      (totalQuantityMT - reservedQuantityMT - soldQuantityMT).clamp(0.0, totalQuantityMT);

  /// Measurement in Quintals (1 MT = 10 Quintals / Qtl)
  double get totalQuantityQtl => totalQuantityMT * 10;
  double get availableQuantityQtl => availableQuantityMT * 10;
  double get reservedQuantityQtl => reservedQuantityMT * 10;
  double get soldQuantityQtl => soldQuantityMT * 10;

  /// Computes updated status based on current reservation
  InventoryStatus get computedStatus {
    if (availableQuantityMT <= 0.001) {
      if (soldQuantityMT >= totalQuantityMT) return InventoryStatus.sold;
      return InventoryStatus.reserved;
    }
    if (reservedQuantityMT > 0.0) {
      return InventoryStatus.partiallyReserved;
    }
    return InventoryStatus.available;
  }

  /// Reserve a portion of available inventory
  FpoInventoryItem reserve(double qtyToReserve) {
    if (qtyToReserve <= 0) return this;
    if (qtyToReserve > availableQuantityMT) {
      throw ArgumentError(
        'Cannot reserve $qtyToReserve MT. Only ${availableQuantityMT.toStringAsFixed(1)} MT available.',
      );
    }
    final newReserved = reservedQuantityMT + qtyToReserve;
    final newAvailable = (totalQuantityMT - newReserved - soldQuantityMT).clamp(0.0, totalQuantityMT);
    final newStatus = newAvailable <= 0 ? InventoryStatus.reserved : InventoryStatus.partiallyReserved;

    return copyWith(
      reservedQuantityMT: newReserved,
      inventoryStatus: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  /// Release a previous reservation back to available stock
  FpoInventoryItem releaseReservation(double qtyToRelease) {
    final newReserved = (reservedQuantityMT - qtyToRelease).clamp(0.0, totalQuantityMT);
    final newStatus = newReserved == 0 ? InventoryStatus.available : InventoryStatus.partiallyReserved;

    return copyWith(
      reservedQuantityMT: newReserved,
      inventoryStatus: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  /// Confirm delivery & convert reservation to sold quantity
  FpoInventoryItem confirmSale(double qtySold) {
    final newReserved = (reservedQuantityMT - qtySold).clamp(0.0, totalQuantityMT);
    final newSold = soldQuantityMT + qtySold;
    final newStatus = newSold >= totalQuantityMT ? InventoryStatus.sold : computedStatus;

    return copyWith(
      reservedQuantityMT: newReserved,
      soldQuantityMT: newSold,
      inventoryStatus: newStatus,
      updatedAt: DateTime.now(),
    );
  }

  FpoInventoryItem copyWith({
    double? totalQuantityMT,
    double? reservedQuantityMT,
    double? soldQuantityMT,
    double? pricePerMT,
    double? pricePerQtl,
    InventoryStatus? inventoryStatus,
    ListingStatus? listingStatus,
    String? activeListingId,
    DateTime? updatedAt,
  }) {
    return FpoInventoryItem(
      id: id,
      fpoId: fpoId,
      fpoName: fpoName,
      cropName: cropName,
      variety: variety,
      totalQuantityMT: totalQuantityMT ?? this.totalQuantityMT,
      reservedQuantityMT: reservedQuantityMT ?? this.reservedQuantityMT,
      soldQuantityMT: soldQuantityMT ?? this.soldQuantityMT,
      unit: unit,
      qualityGrade: qualityGrade,
      moisturePct: moisturePct,
      foreignMatterPct: foreignMatterPct,
      oilContentPct: oilContentPct,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      storageLocation: storageLocation,
      pricePerMT: pricePerMT ?? this.pricePerMT,
      pricePerQtl: pricePerQtl ?? this.pricePerQtl,
      inventoryStatus: inventoryStatus ?? this.inventoryStatus,
      listingStatus: listingStatus ?? this.listingStatus,
      activeListingId: activeListingId ?? this.activeListingId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fpoId': fpoId,
    'fpoName': fpoName,
    'cropName': cropName,
    'variety': variety,
    'totalQuantityMT': totalQuantityMT,
    'reservedQuantityMT': reservedQuantityMT,
    'soldQuantityMT': soldQuantityMT,
    'availableQuantityMT': availableQuantityMT,
    'unit': unit,
    'qualityGrade': qualityGrade,
    'moisturePct': moisturePct,
    'foreignMatterPct': foreignMatterPct,
    'oilContentPct': oilContentPct,
    'warehouseId': warehouseId,
    'warehouseName': warehouseName,
    'storageLocation': storageLocation,
    'pricePerMT': pricePerMT,
    'pricePerQtl': pricePerQtl,
    'inventoryStatus': inventoryStatus.name,
    'listingStatus': listingStatus.name,
    'activeListingId': activeListingId,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FpoInventoryItem.fromMap(Map<String, dynamic> map, String id) => FpoInventoryItem(
    id: id,
    fpoId: map['fpoId'] ?? '',
    fpoName: map['fpoName'] ?? '',
    cropName: map['cropName'] ?? map['commodity'] ?? 'Wheat',
    variety: map['variety'] ?? 'Standard Variety',
    totalQuantityMT: (map['totalQuantityMT'] as num?)?.toDouble() ??
        ((map['totalQuantityKg'] as num?)?.toDouble() ?? 0.0) / 1000.0,
    reservedQuantityMT: (map['reservedQuantityMT'] as num?)?.toDouble() ??
        ((map['reservedQuantityKg'] as num?)?.toDouble() ?? 0.0) / 1000.0,
    soldQuantityMT: (map['soldQuantityMT'] as num?)?.toDouble() ?? 0.0,
    unit: map['unit'] ?? 'MT',
    qualityGrade: map['qualityGrade'] ?? 'Milling Grade',
    moisturePct: (map['moisturePct'] as num?)?.toDouble() ?? 11.2,
    foreignMatterPct: (map['foreignMatterPct'] as num?)?.toDouble() ?? 0.8,
    oilContentPct: (map['oilContentPct'] as num?)?.toDouble(),
    warehouseId: map['warehouseId'] ?? 'WH-01',
    warehouseName: map['warehouseName'] ?? map['warehouseLocation'] ?? 'Central Silo 01',
    storageLocation: map['storageLocation'] ?? map['bayLocation'] ?? 'Bay A',
    pricePerMT: (map['pricePerMT'] as num?)?.toDouble() ??
        ((map['pricePerQtl'] as num?)?.toDouble() ?? 3500.0) * 10,
    pricePerQtl: (map['pricePerQtl'] as num?)?.toDouble() ?? 3500.0,
    inventoryStatus: InventoryStatus.values.firstWhere(
      (e) => e.name == map['inventoryStatus'],
      orElse: () => InventoryStatus.available,
    ),
    listingStatus: ListingStatus.values.firstWhere(
      (e) => e.name == map['listingStatus'],
      orElse: () => ListingStatus.published,
    ),
    activeListingId: map['activeListingId'],
    imageUrl: map['imageUrl'],
    createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) ?? DateTime.now() : DateTime.now(),
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now() : DateTime.now(),
  );
}

class BulkCropListing {
  final String id;
  final String inventoryItemId;
  final String fpoId;
  final String fpoName;
  final String cropName;
  final String variety;
  final double listedQuantityMT;
  final double minimumOrderQuantityMT;
  final double pricePerMT;
  final double pricePerQtl;
  final String qualityGrade;
  final double moisturePct;
  final String warehouseName;
  final double warehouseLat;
  final double warehouseLng;
  final List<String> deliveryOptions; // 'Ex-Warehouse (FOB)', 'Delivered (FOR)'
  final int dispatchLeadTimeDays;
  final bool isMultiFpoEligible; // Can be pooled with 7 km neighbors
  final ListingStatus status;
  final String? imageUrl;
  final List<FarmerInwardConsignment> farmerContributions;
  final DateTime publishedAt;
  final DateTime updatedAt;

  const BulkCropListing({
    required this.id,
    required this.inventoryItemId,
    required this.fpoId,
    required this.fpoName,
    required this.cropName,
    required this.variety,
    required this.listedQuantityMT,
    this.minimumOrderQuantityMT = 25.0, // 25 MT FTL standard
    required this.pricePerMT,
    required this.pricePerQtl,
    required this.qualityGrade,
    this.moisturePct = 11.2,
    required this.warehouseName,
    this.warehouseLat = 29.6857,
    this.warehouseLng = 76.9905,
    this.deliveryOptions = const ['Ex-Warehouse (FOB)', 'Delivered (FOR)'],
    this.dispatchLeadTimeDays = 2,
    this.isMultiFpoEligible = true,
    this.status = ListingStatus.published,
    this.imageUrl,
    this.farmerContributions = const [],
    required this.publishedAt,
    required this.updatedAt,
  });

  bool get isActive => status == ListingStatus.published && listedQuantityMT > 0;

  /// Measurement in Quintals (1 MT = 10 Quintals / Qtl)
  double get listedQuantityQtl => listedQuantityMT * 10;
  double get minimumOrderQuantityQtl => minimumOrderQuantityMT * 10;
  double get totalAllocatedFarmerQtl =>
      farmerContributions.fold<double>(0.0, (sum, f) => sum + f.quantityQtl);

  Map<String, dynamic> toMap() => {
    'id': id,
    'inventoryItemId': inventoryItemId,
    'fpoId': fpoId,
    'fpoName': fpoName,
    'cropName': cropName,
    'variety': variety,
    'listedQuantityMT': listedQuantityMT,
    'minimumOrderQuantityMT': minimumOrderQuantityMT,
    'pricePerMT': pricePerMT,
    'pricePerQtl': pricePerQtl,
    'qualityGrade': qualityGrade,
    'moisturePct': moisturePct,
    'warehouseName': warehouseName,
    'warehouseLat': warehouseLat,
    'warehouseLng': warehouseLng,
    'deliveryOptions': deliveryOptions,
    'dispatchLeadTimeDays': dispatchLeadTimeDays,
    'isMultiFpoEligible': isMultiFpoEligible,
    'status': status.name,
    'imageUrl': imageUrl,
    'farmerContributions': farmerContributions.map((f) => f.toMap()).toList(),
    'publishedAt': publishedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BulkCropListing.fromMap(Map<String, dynamic> map, String id) => BulkCropListing(
    id: id,
    inventoryItemId: map['inventoryItemId'] ?? '',
    fpoId: map['fpoId'] ?? '',
    fpoName: map['fpoName'] ?? '',
    cropName: map['cropName'] ?? 'Wheat',
    variety: map['variety'] ?? 'Milling 306',
    listedQuantityMT: (map['listedQuantityMT'] as num?)?.toDouble() ?? 100.0,
    minimumOrderQuantityMT: (map['minimumOrderQuantityMT'] as num?)?.toDouble() ?? 25.0,
    pricePerMT: (map['pricePerMT'] as num?)?.toDouble() ?? 35600.0,
    pricePerQtl: (map['pricePerQtl'] as num?)?.toDouble() ?? 3560.0,
    qualityGrade: map['qualityGrade'] ?? 'Grade A',
    moisturePct: (map['moisturePct'] as num?)?.toDouble() ?? 11.2,
    warehouseName: map['warehouseName'] ?? 'Central Silo 01',
    warehouseLat: (map['warehouseLat'] as num?)?.toDouble() ?? 29.6857,
    warehouseLng: (map['warehouseLng'] as num?)?.toDouble() ?? 76.9905,
    deliveryOptions: List<String>.from(map['deliveryOptions'] ?? ['Ex-Warehouse (FOB)']),
    dispatchLeadTimeDays: (map['dispatchLeadTimeDays'] as num?)?.toInt() ?? 2,
    isMultiFpoEligible: map['isMultiFpoEligible'] ?? true,
    status: ListingStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => ListingStatus.published,
    ),
    imageUrl: map['imageUrl'],
    farmerContributions: (map['farmerContributions'] as List<dynamic>?)
            ?.map((e) => FarmerInwardConsignment.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        const [],
    publishedAt: map['publishedAt'] != null ? DateTime.tryParse(map['publishedAt']) ?? DateTime.now() : DateTime.now(),
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now() : DateTime.now(),
  );
}

/// Model: Inward Farmer Consignment deposited with FPO
/// Enforces physical grain provenance, deposit receipts, and pro-rata B2B realizations.
class FarmerInwardConsignment {
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String village;
  final String commodity;
  final String variety;
  final double quantityQtl;
  final double procurementPricePerQtl;
  final DateTime depositDate;
  final double moisturePct;
  final String qualityGrade;
  final String receiptNumber;
  final String status; // 'deposited_at_godown', 'pooled_in_listing', 'contract_executed', 'in_transit', 'settled_dbt'
  final String? b2bOrderId;
  final String? buyerName;
  final double? finalSettlementPricePerQtl;
  final String? dbtUtrNumber;
  final String? labCertificateId;

  const FarmerInwardConsignment({
    required this.farmerId,
    required this.farmerName,
    this.farmerPhone = '+91 98765 43210',
    this.village = 'Karnal, Haryana',
    required this.commodity,
    this.variety = 'Sharbati 306',
    required this.quantityQtl,
    required this.procurementPricePerQtl,
    required this.depositDate,
    this.moisturePct = 11.2,
    this.qualityGrade = 'Grade A (Milling)',
    required this.receiptNumber,
    this.status = 'deposited_at_godown',
    this.b2bOrderId,
    this.buyerName,
    this.finalSettlementPricePerQtl,
    this.dbtUtrNumber,
    this.labCertificateId,
  });

  double get quantityMT => quantityQtl / 10.0;
  double get totalAgreedAmount => quantityQtl * procurementPricePerQtl;
  double get totalSettlementAmount =>
      quantityQtl * (finalSettlementPricePerQtl ?? procurementPricePerQtl);

  FarmerInwardConsignment copyWith({
    String? status,
    String? b2bOrderId,
    String? buyerName,
    double? finalSettlementPricePerQtl,
    String? dbtUtrNumber,
    String? labCertificateId,
  }) {
    return FarmerInwardConsignment(
      farmerId: farmerId,
      farmerName: farmerName,
      farmerPhone: farmerPhone,
      village: village,
      commodity: commodity,
      variety: variety,
      quantityQtl: quantityQtl,
      procurementPricePerQtl: procurementPricePerQtl,
      depositDate: depositDate,
      moisturePct: moisturePct,
      qualityGrade: qualityGrade,
      receiptNumber: receiptNumber,
      status: status ?? this.status,
      b2bOrderId: b2bOrderId ?? this.b2bOrderId,
      buyerName: buyerName ?? this.buyerName,
      finalSettlementPricePerQtl:
          finalSettlementPricePerQtl ?? this.finalSettlementPricePerQtl,
      dbtUtrNumber: dbtUtrNumber ?? this.dbtUtrNumber,
      labCertificateId: labCertificateId ?? this.labCertificateId,
    );
  }

  Map<String, dynamic> toMap() => {
    'farmerId': farmerId,
    'farmerName': farmerName,
    'farmerPhone': farmerPhone,
    'village': village,
    'commodity': commodity,
    'variety': variety,
    'quantityQtl': quantityQtl,
    'procurementPricePerQtl': procurementPricePerQtl,
    'depositDate': depositDate.toIso8601String(),
    'moisturePct': moisturePct,
    'qualityGrade': qualityGrade,
    'receiptNumber': receiptNumber,
    'status': status,
    'b2bOrderId': b2bOrderId,
    'buyerName': buyerName,
    'finalSettlementPricePerQtl': finalSettlementPricePerQtl,
    'dbtUtrNumber': dbtUtrNumber,
    'labCertificateId': labCertificateId,
  };

  factory FarmerInwardConsignment.fromMap(Map<String, dynamic> map) =>
      FarmerInwardConsignment(
        farmerId: map['farmerId'] ?? '',
        farmerName: map['farmerName'] ?? 'Member Farmer',
        farmerPhone: map['farmerPhone'] ?? '+91 98765 43210',
        village: map['village'] ?? 'Karnal, Haryana',
        commodity: map['commodity'] ?? 'Wheat',
        variety: map['variety'] ?? 'Standard Variety',
        quantityQtl: (map['quantityQtl'] as num?)?.toDouble() ?? 0.0,
        procurementPricePerQtl:
            (map['procurementPricePerQtl'] as num?)?.toDouble() ?? 3500.0,
        depositDate: map['depositDate'] != null
            ? DateTime.tryParse(map['depositDate']) ?? DateTime.now()
            : DateTime.now(),
        moisturePct: (map['moisturePct'] as num?)?.toDouble() ?? 11.2,
        qualityGrade: map['qualityGrade'] ?? 'Grade A (Milling)',
        receiptNumber: map['receiptNumber'] ??
            'FPO-REC-${DateTime.now().millisecondsSinceEpoch}',
        status: map['status'] ?? 'deposited_at_godown',
        b2bOrderId: map['b2bOrderId'],
        buyerName: map['buyerName'],
        finalSettlementPricePerQtl:
            (map['finalSettlementPricePerQtl'] as num?)?.toDouble(),
        dbtUtrNumber: map['dbtUtrNumber'],
        labCertificateId: map['labCertificateId'],
      );
}
