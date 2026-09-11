import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recurring_order_model.dart';
import '../models/crop_benchmark_model.dart';

/// Service managing 12-Week Recurring Supply Agreements between Bulk Buyers & FPOs
class RecurringOrderService {
  static final RecurringOrderService _instance = RecurringOrderService._internal();
  factory RecurringOrderService() => _instance;
  RecurringOrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'recurring_orders';

  // In-memory cache for demo testing and fallback
  final List<RecurringOrderModel> _inMemoryOrders = [];
  final StreamController<List<RecurringOrderModel>> _streamController =
      StreamController<List<RecurringOrderModel>>.broadcast();

  bool _seeded = false;

  void ensureInitialSeed() {
    if (_seeded) return;
    _seeded = true;

    final now = DateTime.now();
    // Monday of next week
    final nextMonday = now.add(Duration(days: (8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7));

    // Seed Order 1: Active 12-Week Sharbati Wheat contract (Week 4 active)
    final tranches1 = List.generate(12, (index) {
      final weekNum = index + 1;
      final trancheDate = nextMonday.add(Duration(days: (weekNum - 1) * 7));
      String status = 'scheduled';
      String? vehicle;
      String? utr;
      if (weekNum <= 2) {
        status = 'paid';
        vehicle = 'HR-05-AB-4412';
        utr = 'CMS982184918$weekNum';
      } else if (weekNum == 3) {
        status = 'delivered';
        vehicle = 'HR-05-AB-4412';
      } else if (weekNum == 4) {
        status = 'dispatched';
        vehicle = 'HR-05-AB-4412';
      }
      return RecurringTranche(
        weekNumber: weekNum,
        scheduledDate: trancheDate,
        quantityQtl: 100.0,
        trancheAmount: 245000.0, // 100 Qtl @ ₹2,450
        status: status,
        vehicleNumber: vehicle,
        driverPhone: '+91 98765 12345',
        dbtUtr: utr,
      );
    });

    final order1 = RecurringOrderModel(
      id: 'REC-2025-0891',
      recurringOrderNumber: 'REC-2025-0891',
      buyerId: 'demo_buyer_001',
      buyerName: 'AgroFoods Milling India Pvt Ltd',
      buyerCompany: 'AgroFoods Milling Division',
      deliveryDestination: 'Sonepat Processing Plant, Sector 38, HSIIDC, Haryana',
      fpoId: 'fpo_karnal_01',
      fpoName: 'Karnal Agro Producer Co.',
      fpoCluster: 'Taraori Cluster, Karnal (24 km)',
      commodity: 'Sharbati Wheat',
      variety: 'PBW-502 Milling Grade',
      qualityGrade: 'Grade A (NABL Certified)',
      weeklyQuantityQtl: 100.0,
      totalWeeks: 12,
      agreedPricePerQtl: 2450.0,
      dispatchDay: 'Monday',
      startDate: nextMonday,
      endDate: nextMonday.add(const Duration(days: 84)),
      status: 'active_contract',
      totalContractValue: 2940000.0, // 1200 Qtl * 2450
      contractHash: RecurringOrderModel.generateContractHash('REC-2025-0891-WHEAT-12WEEKS'),
      tranches: tranches1,
      createdAt: now.subtract(const Duration(days: 21)),
    );

    // Seed Order 2: Pending FPO approval for Basmati Rice (120 Qtl/week)
    final tranches2 = List.generate(12, (index) {
      final weekNum = index + 1;
      final trancheDate = nextMonday.add(Duration(days: (weekNum - 1) * 7));
      return RecurringTranche(
        weekNumber: weekNum,
        scheduledDate: trancheDate,
        quantityQtl: 120.0,
        trancheAmount: 816000.0, // 120 Qtl @ ₹6,800
        status: 'scheduled',
      );
    });

    final order2 = RecurringOrderModel(
      id: 'REC-2025-0904',
      recurringOrderNumber: 'REC-2025-0904',
      buyerId: 'demo_buyer_001',
      buyerName: 'AgroFoods Milling India Pvt Ltd',
      buyerCompany: 'AgroFoods Milling Division',
      deliveryDestination: 'Karnal Export Hub, GT Road, Haryana',
      fpoId: 'fpo_karnal_01',
      fpoName: 'Karnal Agro Producer Co.',
      fpoCluster: 'Taraori Cluster, Karnal (24 km)',
      commodity: 'Basmati Rice',
      variety: '1121 Super Steam',
      qualityGrade: 'Export Grade Premium',
      weeklyQuantityQtl: 120.0,
      totalWeeks: 12,
      agreedPricePerQtl: 6800.0,
      dispatchDay: 'Monday',
      startDate: nextMonday,
      endDate: nextMonday.add(const Duration(days: 84)),
      status: 'pending_fpo_approval',
      totalContractValue: 9792000.0, // 1440 Qtl * 6800
      contractHash: RecurringOrderModel.generateContractHash('REC-2025-0904-RICE-12WEEKS'),
      tranches: tranches2,
      createdAt: now.subtract(const Duration(hours: 6)),
    );

    _inMemoryOrders.add(order1);
    _inMemoryOrders.add(order2);
    _streamController.add(List.from(_inMemoryOrders));
  }

  /// Get candidate FPOs for bulk buyer comparison across any commodity
  List<FpoSupplyCandidate> getCandidateFposForCrop(String cropName) {
    final benchmark = CropBenchmark.findByName(cropName);
    final basePrice = benchmark?.mandiAvgPrice ?? 2450.0;
    final lower = cropName.toLowerCase();

    if (lower.contains('onion') || lower.contains('pyaz') || lower.contains('प्याज')) {
      return [
        FpoSupplyCandidate(
          fpoId: 'fpo_nashik_01',
          fpoName: 'Godavari Agri Producers Co-op',
          clusterLocation: 'Lasalgaon, Nashik',
          distanceKm: 48.0,
          pricePerQtl: basePrice > 0 ? (basePrice * 0.98).roundToDouble() : 1920.0,
          estimatedTransitHours: 8,
          qualityGrade: 'Export Grade Pink/Red 55mm+',
          moisturePct: 10.5,
          availableCapacityQtl: 12000.0,
          reliabilityRating: 4.9,
          successfulContracts: 58,
        ),
        FpoSupplyCandidate(
          fpoId: 'fpo_karnal_01',
          fpoName: 'Karnal Agro Producer Co.',
          clusterLocation: 'Taraori Cluster, Karnal',
          distanceKm: 24.0,
          pricePerQtl: basePrice > 0 ? basePrice : 1950.0,
          estimatedTransitHours: 4,
          qualityGrade: 'Standard Medium Bulbs',
          moisturePct: 12.0,
          availableCapacityQtl: 4500.0,
          reliabilityRating: 4.8,
          successfulContracts: 26,
        ),
        FpoSupplyCandidate(
          fpoId: 'fpo_pune_01',
          fpoName: 'Sahyadri Agro Farmers Co-op',
          clusterLocation: 'Khed, Pune',
          distanceKm: 85.0,
          pricePerQtl: basePrice > 0 ? (basePrice * 0.95).roundToDouble() : 1800.0,
          estimatedTransitHours: 18,
          qualityGrade: 'Grade A Garwa Onion',
          moisturePct: 11.0,
          availableCapacityQtl: 15000.0,
          reliabilityRating: 4.95,
          successfulContracts: 62,
        ),
      ];
    }

    if (lower.contains('rice') || lower.contains('basmati') || lower.contains('paddy') || lower.contains('धान') || lower.contains('चावल')) {
      return [
        FpoSupplyCandidate(
          fpoId: 'fpo_karnal_01',
          fpoName: 'Karnal Agro Producer Co.',
          clusterLocation: 'Taraori Cluster, Karnal',
          distanceKm: 24.0,
          pricePerQtl: basePrice > 0 ? basePrice : 3800.0,
          estimatedTransitHours: 4,
          qualityGrade: 'Export Grade Premium 1121 Extra Long',
          moisturePct: 10.8,
          availableCapacityQtl: 18000.0,
          reliabilityRating: 4.9,
          successfulContracts: 45,
        ),
        FpoSupplyCandidate(
          fpoId: 'fpo_kurukshetra_01',
          fpoName: 'Dharmakshetra Organic FPO',
          clusterLocation: 'Pehowa, Kurukshetra',
          distanceKm: 52.0,
          pricePerQtl: basePrice > 0 ? (basePrice * 1.04).roundToDouble() : 3950.0,
          estimatedTransitHours: 6,
          qualityGrade: 'Traditional Organic Basmati',
          moisturePct: 10.4,
          availableCapacityQtl: 9500.0,
          reliabilityRating: 4.75,
          successfulContracts: 19,
        ),
        FpoSupplyCandidate(
          fpoId: 'fpo_amritsar_01',
          fpoName: 'Majha Grain Growers Co-operative',
          clusterLocation: 'Jandiala Guru, Amritsar',
          distanceKm: 180.0,
          pricePerQtl: basePrice > 0 ? (basePrice * 0.97).roundToDouble() : 3720.0,
          estimatedTransitHours: 14,
          qualityGrade: 'Pusa-1509 Extra Long Super Grain',
          moisturePct: 11.2,
          availableCapacityQtl: 25000.0,
          reliabilityRating: 4.85,
          successfulContracts: 54,
        ),
      ];
    }

    // Generic realistic candidates for any crop (Wheat, Pulses, Mustard, Soybean, Maize, Cotton, etc.)
    return [
      FpoSupplyCandidate(
        fpoId: 'fpo_karnal_01',
        fpoName: 'Karnal Agro Producer Co.',
        clusterLocation: 'Taraori Cluster, Karnal',
        distanceKm: 24.0,
        pricePerQtl: basePrice > 0 ? basePrice : 2450.0,
        estimatedTransitHours: 4,
        qualityGrade: 'Grade A (NABL Certified & Assayed)',
        moisturePct: 11.2,
        availableCapacityQtl: 20000.0,
        reliabilityRating: 4.9,
        successfulContracts: 48,
      ),
      FpoSupplyCandidate(
        fpoId: 'fpo_panipat_01',
        fpoName: 'Panipat Kisan Kalyan Samiti',
        clusterLocation: 'Samalkha, Panipat',
        distanceKm: 42.0,
        pricePerQtl: basePrice > 0 ? (basePrice * 0.98).roundToDouble() : 2420.0,
        estimatedTransitHours: 5,
        qualityGrade: 'High Bulk Commercial Grade',
        moisturePct: 11.8,
        availableCapacityQtl: 14000.0,
        reliabilityRating: 4.7,
        successfulContracts: 22,
      ),
      FpoSupplyCandidate(
        fpoId: 'fpo_sehore_01',
        fpoName: 'Malwa Golden Grain Producer Co.',
        clusterLocation: 'Ashta, Sehore (M.P.)',
        distanceKm: 450.0,
        pricePerQtl: basePrice > 0 ? (basePrice * 1.02).roundToDouble() : 2550.0,
        estimatedTransitHours: 24,
        qualityGrade: 'Certified Premium Export Lot',
        moisturePct: 10.5,
        availableCapacityQtl: 35000.0,
        reliabilityRating: 4.95,
        successfulContracts: 71,
      ),
    ];
  }

  /// Helper to calculate the next occurrence of a chosen weekday
  DateTime _getNextTargetWeekday(DateTime from, String dayName) {
    const dayMap = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final targetWeekday = dayMap[dayName.toLowerCase()] ?? DateTime.monday;
    int diff = targetWeekday - from.weekday;
    if (diff <= 0) {
      diff += 7;
    }
    return from.add(Duration(days: diff));
  }

  /// Create and submit 12-Week Recurring Order Proposal
  Future<RecurringOrderModel> createProposal({
    required String buyerId,
    required String buyerName,
    required String buyerCompany,
    required String deliveryDestination,
    required FpoSupplyCandidate selectedFpo,
    required String commodity,
    required String variety,
    required double weeklyQuantityQtl,
    String dispatchDay = 'Monday',
  }) async {
    ensureInitialSeed();

    final now = DateTime.now();
    final firstDispatchDate = _getNextTargetWeekday(now, dispatchDay);

    final totalWeeks = 12;
    final totalVal = weeklyQuantityQtl * selectedFpo.pricePerQtl * totalWeeks;
    final orderId = 'REC-${now.year}-${(1000 + _inMemoryOrders.length + 1)}';

    // Build 12 tranches
    final tranches = List.generate(totalWeeks, (index) {
      final weekNum = index + 1;
      final scheduledDate = firstDispatchDate.add(Duration(days: (weekNum - 1) * 7));
      return RecurringTranche(
        weekNumber: weekNum,
        scheduledDate: scheduledDate,
        quantityQtl: weeklyQuantityQtl,
        trancheAmount: weeklyQuantityQtl * selectedFpo.pricePerQtl,
        status: 'scheduled',
      );
    });

    final order = RecurringOrderModel(
      id: orderId,
      recurringOrderNumber: orderId,
      buyerId: buyerId,
      buyerName: buyerName,
      buyerCompany: buyerCompany,
      deliveryDestination: deliveryDestination,
      fpoId: selectedFpo.fpoId,
      fpoName: selectedFpo.fpoName,
      fpoCluster: '${selectedFpo.clusterLocation} (${selectedFpo.distanceKm.toInt()} km)',
      commodity: commodity,
      variety: variety,
      qualityGrade: selectedFpo.qualityGrade,
      weeklyQuantityQtl: weeklyQuantityQtl,
      totalWeeks: totalWeeks,
      agreedPricePerQtl: selectedFpo.pricePerQtl,
      dispatchDay: dispatchDay,
      startDate: firstDispatchDate,
      endDate: firstDispatchDate.add(const Duration(days: 84)),
      status: 'pending_fpo_approval',
      totalContractValue: totalVal,
      contractHash: RecurringOrderModel.generateContractHash(
        '$orderId-$commodity-${selectedFpo.fpoId}-$totalVal',
      ),
      tranches: tranches,
      createdAt: now,
    );

    _inMemoryOrders.insert(0, order);
    _streamController.add(List.from(_inMemoryOrders));

    try {
      await _firestore.collection(_collection).doc(order.id).set(order.toMap());
    } catch (e) {
      debugPrint('Firestore offline fallback for recurring order: $e');
    }

    return order;
  }

  /// Stream recurring orders for a Bulk Buyer
  Stream<List<RecurringOrderModel>> streamBuyerOrders(String buyerId) {
    ensureInitialSeed();
    return _streamController.stream.map((list) {
      return list.where((o) => o.buyerId == buyerId || buyerId.isEmpty).toList();
    });
  }

  /// Stream recurring orders for an FPO
  Stream<List<RecurringOrderModel>> streamFpoOrders(String fpoId) {
    ensureInitialSeed();
    return _streamController.stream.map((list) {
      return list.where((o) => o.fpoId == fpoId || fpoId.isEmpty || o.fpoId == 'fpo_karnal_01').toList();
    });
  }

  /// FPO Accepts 12-Week Supply Contract
  Future<bool> fpoAcceptProposal(String orderId) async {
    ensureInitialSeed();
    final idx = _inMemoryOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final existing = _inMemoryOrders[idx];
      final updated = RecurringOrderModel(
        id: existing.id,
        recurringOrderNumber: existing.recurringOrderNumber,
        buyerId: existing.buyerId,
        buyerName: existing.buyerName,
        buyerCompany: existing.buyerCompany,
        deliveryDestination: existing.deliveryDestination,
        fpoId: existing.fpoId,
        fpoName: existing.fpoName,
        fpoCluster: existing.fpoCluster,
        commodity: existing.commodity,
        variety: existing.variety,
        qualityGrade: existing.qualityGrade,
        weeklyQuantityQtl: existing.weeklyQuantityQtl,
        totalWeeks: existing.totalWeeks,
        agreedPricePerQtl: existing.agreedPricePerQtl,
        dispatchDay: existing.dispatchDay,
        startDate: existing.startDate,
        endDate: existing.endDate,
        status: 'active_contract',
        totalContractValue: existing.totalContractValue,
        contractHash: existing.contractHash,
        tranches: existing.tranches,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _inMemoryOrders[idx] = updated;
      _streamController.add(List.from(_inMemoryOrders));

      try {
        await _firestore.collection(_collection).doc(orderId).update({
          'status': 'active_contract',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// FPO Rejects 12-Week Supply Proposal
  Future<bool> fpoRejectProposal(String orderId, String reason) async {
    ensureInitialSeed();
    final idx = _inMemoryOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final existing = _inMemoryOrders[idx];
      final updated = RecurringOrderModel(
        id: existing.id,
        recurringOrderNumber: existing.recurringOrderNumber,
        buyerId: existing.buyerId,
        buyerName: existing.buyerName,
        buyerCompany: existing.buyerCompany,
        deliveryDestination: existing.deliveryDestination,
        fpoId: existing.fpoId,
        fpoName: existing.fpoName,
        fpoCluster: existing.fpoCluster,
        commodity: existing.commodity,
        variety: existing.variety,
        qualityGrade: existing.qualityGrade,
        weeklyQuantityQtl: existing.weeklyQuantityQtl,
        totalWeeks: existing.totalWeeks,
        agreedPricePerQtl: existing.agreedPricePerQtl,
        dispatchDay: existing.dispatchDay,
        startDate: existing.startDate,
        endDate: existing.endDate,
        status: 'rejected',
        rejectionReason: reason,
        totalContractValue: existing.totalContractValue,
        contractHash: existing.contractHash,
        tranches: existing.tranches,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _inMemoryOrders[idx] = updated;
      _streamController.add(List.from(_inMemoryOrders));

      try {
        await _firestore.collection(_collection).doc(orderId).update({
          'status': 'rejected',
          'rejectionReason': reason,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Trigger weekly Monday dispatch for a specific tranche
  Future<bool> dispatchTranche({
    required String orderId,
    required int weekNumber,
    required String vehicleNumber,
    required String driverPhone,
  }) async {
    ensureInitialSeed();
    final idx = _inMemoryOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final order = _inMemoryOrders[idx];
      final trancheIdx = order.tranches.indexWhere((t) => t.weekNumber == weekNumber);
      if (trancheIdx != -1) {
        order.tranches[trancheIdx].status = 'dispatched';
        order.tranches[trancheIdx].vehicleNumber = vehicleNumber;
        order.tranches[trancheIdx].driverPhone = driverPhone;
        order.tranches[trancheIdx].dispatchedAt = DateTime.now();
        _streamController.add(List.from(_inMemoryOrders));
        return true;
      }
    }
    return false;
  }

  /// Mark tranche as delivered and pro-rata settled
  Future<bool> deliverTranche({
    required String orderId,
    required int weekNumber,
    required String dbtUtr,
  }) async {
    ensureInitialSeed();
    final idx = _inMemoryOrders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final order = _inMemoryOrders[idx];
      final trancheIdx = order.tranches.indexWhere((t) => t.weekNumber == weekNumber);
      if (trancheIdx != -1) {
        order.tranches[trancheIdx].status = 'paid';
        order.tranches[trancheIdx].dbtUtr = dbtUtr;
        order.tranches[trancheIdx].deliveredAt = DateTime.now();

        // If all 12 tranches are paid, mark entire order completed
        final allDone = order.tranches.every((t) => t.status == 'paid' || t.status == 'delivered');
        if (allDone) {
          order.status = 'completed';
        }
        _streamController.add(List.from(_inMemoryOrders));
        return true;
      }
    }
    return false;
  }
}
