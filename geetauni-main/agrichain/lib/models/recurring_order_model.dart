import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Single delivery tranche within a 12-Week Recurring Supply Order
class RecurringTranche {
  final int weekNumber; // 1 to 12
  final DateTime scheduledDate; // Scheduled shipment date (e.g., every Monday)
  final double quantityQtl;
  final double trancheAmount;
  String status; // 'scheduled', 'in_preparation', 'dispatched', 'delivered', 'paid'
  String? vehicleNumber;
  String? driverPhone;
  String? dbtUtr;
  DateTime? dispatchedAt;
  DateTime? deliveredAt;
  String? notes;

  RecurringTranche({
    required this.weekNumber,
    required this.scheduledDate,
    required this.quantityQtl,
    required this.trancheAmount,
    this.status = 'scheduled',
    this.vehicleNumber,
    this.driverPhone,
    this.dbtUtr,
    this.dispatchedAt,
    this.deliveredAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'weekNumber': weekNumber,
      'scheduledDate': scheduledDate.toIso8601String(),
      'quantityQtl': quantityQtl,
      'trancheAmount': trancheAmount,
      'status': status,
      'vehicleNumber': vehicleNumber,
      'driverPhone': driverPhone,
      'dbtUtr': dbtUtr,
      'dispatchedAt': dispatchedAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory RecurringTranche.fromMap(Map<String, dynamic> map) {
    return RecurringTranche(
      weekNumber: (map['weekNumber'] ?? 1) as int,
      scheduledDate: map['scheduledDate'] != null
          ? DateTime.parse(map['scheduledDate'] as String)
          : DateTime.now(),
      quantityQtl: (map['quantityQtl'] ?? 0.0).toDouble(),
      trancheAmount: (map['trancheAmount'] ?? 0.0).toDouble(),
      status: (map['status'] ?? 'scheduled') as String,
      vehicleNumber: map['vehicleNumber'] as String?,
      driverPhone: map['driverPhone'] as String?,
      dbtUtr: map['dbtUtr'] as String?,
      dispatchedAt: map['dispatchedAt'] != null
          ? DateTime.parse(map['dispatchedAt'] as String)
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.parse(map['deliveredAt'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }
}

/// FPO Candidate offering supply for comparison
class FpoSupplyCandidate {
  final String fpoId;
  final String fpoName;
  final String clusterLocation;
  final double distanceKm;
  final double pricePerQtl;
  final int estimatedTransitHours;
  final String qualityGrade;
  final double moisturePct;
  final double availableCapacityQtl;
  final double reliabilityRating;
  final int successfulContracts;

  const FpoSupplyCandidate({
    required this.fpoId,
    required this.fpoName,
    required this.clusterLocation,
    required this.distanceKm,
    required this.pricePerQtl,
    required this.estimatedTransitHours,
    required this.qualityGrade,
    required this.moisturePct,
    required this.availableCapacityQtl,
    required this.reliabilityRating,
    required this.successfulContracts,
  });
}

/// 12-Week Recurring Supply Order & Master Contract Model
/// Restricted exclusively to Corporate Bulk Buyers and Farmer Producer Organizations (FPOs)
class RecurringOrderModel {
  final String id;
  final String recurringOrderNumber; // e.g. REC-2025-0891
  final String buyerId;
  final String buyerName;
  final String buyerCompany;
  final String deliveryDestination; // Factory/Mill location
  final String fpoId;
  final String fpoName;
  final String fpoCluster;
  final String commodity;
  final String variety;
  final String qualityGrade;
  final double weeklyQuantityQtl;
  final int totalWeeks; // Default 12
  final double agreedPricePerQtl;
  final String dispatchDay; // e.g. "Monday"
  final DateTime startDate;
  final DateTime endDate;
  String status; // 'pending_fpo_approval', 'active_contract', 'completed', 'rejected', 'paused'
  String? rejectionReason;
  final double totalContractValue;
  final String contractHash;
  final List<RecurringTranche> tranches;
  final DateTime createdAt;
  DateTime? updatedAt;

  RecurringOrderModel({
    required this.id,
    required this.recurringOrderNumber,
    required this.buyerId,
    required this.buyerName,
    required this.buyerCompany,
    required this.deliveryDestination,
    required this.fpoId,
    required this.fpoName,
    required this.fpoCluster,
    required this.commodity,
    required this.variety,
    required this.qualityGrade,
    required this.weeklyQuantityQtl,
    this.totalWeeks = 12,
    required this.agreedPricePerQtl,
    this.dispatchDay = 'Monday',
    required this.startDate,
    required this.endDate,
    this.status = 'pending_fpo_approval',
    this.rejectionReason,
    required this.totalContractValue,
    required this.contractHash,
    required this.tranches,
    required this.createdAt,
    this.updatedAt,
  });

  double get totalQuantityQtl => weeklyQuantityQtl * totalWeeks;
  double get totalQuantityMT => totalQuantityQtl / 10.0;

  int get completedTranchesCount =>
      tranches.where((t) => t.status == 'delivered' || t.status == 'paid').length;

  int get inTransitTranchesCount =>
      tranches.where((t) => t.status == 'dispatched').length;

  double get fulfilledVolumeQtl =>
      completedTranchesCount * weeklyQuantityQtl;

  double get progressPercentage =>
      totalWeeks > 0 ? (completedTranchesCount / totalWeeks).clamp(0.0, 1.0) : 0.0;

  RecurringTranche? get nextUpcomingTranche {
    try {
      return tranches.firstWhere(
        (t) => t.status == 'scheduled' || t.status == 'in_preparation' || t.status == 'dispatched',
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurringOrderNumber': recurringOrderNumber,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerCompany': buyerCompany,
      'deliveryDestination': deliveryDestination,
      'fpoId': fpoId,
      'fpoName': fpoName,
      'fpoCluster': fpoCluster,
      'commodity': commodity,
      'variety': variety,
      'qualityGrade': qualityGrade,
      'weeklyQuantityQtl': weeklyQuantityQtl,
      'totalWeeks': totalWeeks,
      'agreedPricePerQtl': agreedPricePerQtl,
      'dispatchDay': dispatchDay,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
      'rejectionReason': rejectionReason,
      'totalContractValue': totalContractValue,
      'contractHash': contractHash,
      'tranches': tranches.map((t) => t.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory RecurringOrderModel.fromMap(Map<String, dynamic> map) {
    final tranchesList = (map['tranches'] as List<dynamic>? ?? [])
        .map((t) => RecurringTranche.fromMap(Map<String, dynamic>.from(t as Map)))
        .toList();

    return RecurringOrderModel(
      id: (map['id'] ?? '') as String,
      recurringOrderNumber: (map['recurringOrderNumber'] ?? '') as String,
      buyerId: (map['buyerId'] ?? '') as String,
      buyerName: (map['buyerName'] ?? '') as String,
      buyerCompany: (map['buyerCompany'] ?? '') as String,
      deliveryDestination: (map['deliveryDestination'] ?? '') as String,
      fpoId: (map['fpoId'] ?? '') as String,
      fpoName: (map['fpoName'] ?? '') as String,
      fpoCluster: (map['fpoCluster'] ?? '') as String,
      commodity: (map['commodity'] ?? '') as String,
      variety: (map['variety'] ?? '') as String,
      qualityGrade: (map['qualityGrade'] ?? 'Grade A (NABL Assayed)') as String,
      weeklyQuantityQtl: (map['weeklyQuantityQtl'] ?? 100.0).toDouble(),
      totalWeeks: (map['totalWeeks'] ?? 12) as int,
      agreedPricePerQtl: (map['agreedPricePerQtl'] ?? 0.0).toDouble(),
      dispatchDay: (map['dispatchDay'] ?? 'Monday') as String,
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : DateTime.now().add(const Duration(days: 84)),
      status: (map['status'] ?? 'pending_fpo_approval') as String,
      rejectionReason: map['rejectionReason'] as String?,
      totalContractValue: (map['totalContractValue'] ?? 0.0).toDouble(),
      contractHash: (map['contractHash'] ?? '') as String,
      tranches: tranchesList,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  static String generateContractHash(String raw) {
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
