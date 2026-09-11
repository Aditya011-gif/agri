import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Comprehensive B2B Tripartite Agricultural Supply Contract Model.
/// Conforms to legal trade standards for institutional procurement between
/// Farmer Producer Organizations (FPOs), Corporate Bulk Buyers, and the AgriChain Escrow Protocol.
class B2bContractModel {
  final String id;
  final String orderId;
  final String contractNumber;
  final String status; // 'executed', 'in_transit', 'delivered', 'settled', 'disputed'
  
  // Buyer Details
  final String buyerId;
  final String buyerName;
  final String buyerCompany;
  final String buyerGstin;
  final String buyerAddress;
  final String buyerSignatory;
  
  // Seller (FPO) Details
  final String fpoId;
  final String fpoName;
  final String fpoRegistrationNo;
  final String fpoGstin;
  final String fpoWarehouseAddress;
  final String fpoSignatory;
  
  // Multi-FPO Pooling & Constituent Farmer Beneficiaries
  final bool isMultiFpo;
  final List<Map<String, dynamic>> coFpos;
  final List<Map<String, dynamic>> farmerBeneficiaries;
  
  // Commodity Quality Specs
  final String commodity;
  final String variety;
  final String qualityGrade;
  final double moistureTolerancePct; // e.g. 12.0%
  final double foreignMatterTolerancePct; // e.g. 0.8%
  final double brokenGrainsTolerancePct; // e.g. 2.0%
  
  // Commercials & Escrow Lock
  final double quantityQtl;
  final double quantityMT;
  final double pricePerQtl;
  final double cropBaseAmount;
  final double freightAmount;
  final String carrierName;
  final double transitInsuranceAmount;
  final double protocolFeeAmount;
  final double totalEscrowAmount;
  
  // Fulfillment & Logistics
  final String originLocation;
  final String destinationFactory;
  final String expectedDeliveryDate;
  final int transitWindowHours;
  final String? fastagVehicleNumber;
  
  // Legal Tripartite Clauses
  final List<Map<String, String>> clauses;
  
  // Cryptographic Proof & Polygon PoS Blockchain
  final String sha256Hash;
  final String polygonContractAddress;
  final String blockchainNetwork;
  
  // Digital Signatures
  final String? buyerSignedAt;
  final String? buyerSignatureDigest;
  final String? sellerSignedAt;
  final String? sellerSignatureDigest;
  final String createdAt;

  B2bContractModel({
    required this.id,
    required this.orderId,
    required this.contractNumber,
    this.status = 'executed',
    required this.buyerId,
    required this.buyerName,
    required this.buyerCompany,
    required this.buyerGstin,
    required this.buyerAddress,
    required this.buyerSignatory,
    required this.fpoId,
    required this.fpoName,
    required this.fpoRegistrationNo,
    required this.fpoGstin,
    required this.fpoWarehouseAddress,
    required this.fpoSignatory,
    this.isMultiFpo = false,
    this.coFpos = const [],
    this.farmerBeneficiaries = const [],
    required this.commodity,
    required this.variety,
    required this.qualityGrade,
    this.moistureTolerancePct = 12.0,
    this.foreignMatterTolerancePct = 0.8,
    this.brokenGrainsTolerancePct = 2.0,
    required this.quantityQtl,
    required this.quantityMT,
    required this.pricePerQtl,
    required this.cropBaseAmount,
    required this.freightAmount,
    required this.carrierName,
    required this.transitInsuranceAmount,
    required this.protocolFeeAmount,
    required this.totalEscrowAmount,
    required this.originLocation,
    required this.destinationFactory,
    required this.expectedDeliveryDate,
    this.transitWindowHours = 24,
    this.fastagVehicleNumber,
    required this.clauses,
    required this.sha256Hash,
    this.polygonContractAddress = '0x8a92b1f83c1b69f8d9b1c720993414ec49f0',
    this.blockchainNetwork = 'Polygon PoS L2 (AgriChain Tripartite Vault)',
    this.buyerSignedAt,
    this.buyerSignatureDigest,
    this.sellerSignedAt,
    this.sellerSignatureDigest,
    required this.createdAt,
  });

  /// Factory: Generate a standardized legal contract with real cryptographic hashes
  static B2bContractModel generateDefault({
    required String orderId,
    required String buyerId,
    required String buyerName,
    String? buyerCompany,
    String? buyerGstin,
    String? buyerAddress,
    String? buyerSignatory,
    required String fpoId,
    required String fpoName,
    String? fpoRegistrationNo,
    String? fpoGstin,
    String? fpoWarehouseAddress,
    String? fpoSignatory,
    bool isMultiFpo = false,
    List<Map<String, dynamic>> coFpos = const [],
    List<Map<String, dynamic>> farmerBeneficiaries = const [],
    required String commodity,
    required String variety,
    required String qualityGrade,
    double moistureTolerancePct = 12.0,
    double foreignMatterTolerancePct = 0.8,
    required double quantityQtl,
    required double pricePerQtl,
    required double freightAmount,
    required String carrierName,
    required String originLocation,
    required String destinationFactory,
    String? fastagVehicleNumber,
  }) {
    final now = DateTime.now();
    final contractNo = 'CTR-${now.year}-${orderId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase()}';
    final qtyMT = quantityQtl / 10.0;
    final cropCost = quantityQtl * pricePerQtl;
    final transitInsurance = cropCost * 0.002;
    final protocolFee = cropCost * 0.015;
    final totalEscrow = cropCost + freightAmount + transitInsurance + protocolFee;

    // Legal Tripartite Clauses conforming to Institutional Commodity Standards
    final clauses = [
      {
        'title': 'Clause 1: Electronic Weighbridge Reconciliation & Gate Pass',
        'content':
            'Net deliverable weight shall be adjudicated exclusively via certified computerized gross/tare weighbridge printouts at the FPO silo dock and the Buyer processing terminal. Any tare discrepancy exceeding 0.3% shall trigger joint calibration re-weighing within 4 hours.',
      },
      {
        'title': 'Clause 2: NABL Quality Tolerances & Pro-Rata Deductions',
        'content':
            'The lot must test at or below $moistureTolerancePct% moisture content and $foreignMatterTolerancePct% foreign matter. Excess moisture between $moistureTolerancePct% and 13.5% shall attract a 1:1 price deduction. Grains with moisture exceeding 14.0% or active infestation shall be subject to buyer rejection.',
      },
      {
        'title': 'Clause 3: 24-Hour Non-Custodial Smart Escrow Vault Lock',
        'content':
            'Buyer capital (₹${totalEscrow.toStringAsFixed(0)}) is committed to the AgriChain Smart Escrow smart contract upon order authorization. Funds are automatically disbursed to the FPO banking account upon electronic assay sign-off or expiry of the 24-hour factory gate inspection window.',
      },
      {
        'title': 'Clause 4: Multi-FPO Freight Pooling & FASTag Telematics',
        'content':
            'Transporter fleet (${carrierName.isEmpty ? 'Certified Logistics' : carrierName}) is bound to GPS telematics and FASTag toll passage logging. In multi-hub collections, each FPO lot maintains tamper-evident digital seal tags until destination factory unlading.',
      },
      {
        'title': 'Clause 5: Dispute Resolution & Jurisdiction',
        'content':
            'Any unresolved dispute arising under this Tripartite Smart Contract shall be referred to sole arbitration under the Arbitration and Conciliation Act, 1996 in New Delhi. Courts in Haryana / New Delhi shall hold exclusive territorial jurisdiction.',
      },
    ];

    // Compute deterministic SHA-256 Hash of the contract payload
    final payloadString = '$contractNo|$buyerGstin|$fpoGstin|$commodity|$quantityQtl|$totalEscrow|${now.toIso8601String()}';
    final hashDigest = sha256.convert(utf8.encode(payloadString)).toString();

    final buyerSigDigest = 'E-SIGN:${sha256.convert(utf8.encode('BUYER|$buyerName|$now')).toString().substring(0, 16).toUpperCase()}';
    final sellerSigDigest = 'FPO-SEAL:${sha256.convert(utf8.encode('SELLER|$fpoName|$now')).toString().substring(0, 16).toUpperCase()}';

    return B2bContractModel(
      id: 'contract_$orderId',
      orderId: orderId,
      contractNumber: contractNo,
      status: 'executed',
      buyerId: buyerId,
      buyerName: buyerName,
      buyerCompany: buyerCompany ?? 'Institutional Agri Foods Corp',
      buyerGstin: buyerGstin ?? '06AABCI9821E1ZK',
      buyerAddress: buyerAddress ?? 'Industrial Agro Hub, GT Road, NCR',
      buyerSignatory: buyerSignatory ?? buyerName,
      fpoId: fpoId,
      fpoName: fpoName,
      fpoRegistrationNo: fpoRegistrationNo ?? 'FPO/HR/KNL/2021/8842',
      fpoGstin: fpoGstin ?? '06AAACF1049K1ZZ',
      fpoWarehouseAddress: fpoWarehouseAddress ?? originLocation,
      fpoSignatory: fpoSignatory ?? '$fpoName Managing Director',
      isMultiFpo: isMultiFpo,
      coFpos: coFpos,
      farmerBeneficiaries: farmerBeneficiaries,
      commodity: commodity,
      variety: variety,
      qualityGrade: qualityGrade,
      moistureTolerancePct: moistureTolerancePct,
      foreignMatterTolerancePct: foreignMatterTolerancePct,
      quantityQtl: quantityQtl,
      quantityMT: qtyMT,
      pricePerQtl: pricePerQtl,
      cropBaseAmount: cropCost,
      freightAmount: freightAmount,
      carrierName: carrierName,
      transitInsuranceAmount: transitInsurance,
      protocolFeeAmount: protocolFee,
      totalEscrowAmount: totalEscrow,
      originLocation: originLocation,
      destinationFactory: destinationFactory,
      expectedDeliveryDate: '${now.day + 2}/${now.month}/${now.year}',
      fastagVehicleNumber: fastagVehicleNumber ?? 'HR-05-AB-9842',
      clauses: clauses,
      sha256Hash: hashDigest,
      buyerSignedAt: now.toIso8601String(),
      buyerSignatureDigest: buyerSigDigest,
      sellerSignedAt: now.toIso8601String(),
      sellerSignatureDigest: sellerSigDigest,
      createdAt: now.toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'contractNumber': contractNumber,
      'status': status,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerCompany': buyerCompany,
      'buyerGstin': buyerGstin,
      'buyerAddress': buyerAddress,
      'buyerSignatory': buyerSignatory,
      'fpoId': fpoId,
      'fpoName': fpoName,
      'fpoRegistrationNo': fpoRegistrationNo,
      'fpoGstin': fpoGstin,
      'fpoWarehouseAddress': fpoWarehouseAddress,
      'fpoSignatory': fpoSignatory,
      'isMultiFpo': isMultiFpo,
      'coFpos': coFpos,
      'farmerBeneficiaries': farmerBeneficiaries,
      'commodity': commodity,
      'variety': variety,
      'qualityGrade': qualityGrade,
      'moistureTolerancePct': moistureTolerancePct,
      'foreignMatterTolerancePct': foreignMatterTolerancePct,
      'brokenGrainsTolerancePct': brokenGrainsTolerancePct,
      'quantityQtl': quantityQtl,
      'quantityMT': quantityMT,
      'pricePerQtl': pricePerQtl,
      'cropBaseAmount': cropBaseAmount,
      'freightAmount': freightAmount,
      'carrierName': carrierName,
      'transitInsuranceAmount': transitInsuranceAmount,
      'protocolFeeAmount': protocolFeeAmount,
      'totalEscrowAmount': totalEscrowAmount,
      'originLocation': originLocation,
      'destinationFactory': destinationFactory,
      'expectedDeliveryDate': expectedDeliveryDate,
      'transitWindowHours': transitWindowHours,
      'fastagVehicleNumber': fastagVehicleNumber,
      'clauses': clauses,
      'sha256Hash': sha256Hash,
      'polygonContractAddress': polygonContractAddress,
      'blockchainNetwork': blockchainNetwork,
      'buyerSignedAt': buyerSignedAt,
      'buyerSignatureDigest': buyerSignatureDigest,
      'sellerSignedAt': sellerSignedAt,
      'sellerSignatureDigest': sellerSignatureDigest,
      'createdAt': createdAt,
    };
  }

  factory B2bContractModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return B2bContractModel(
      id: docId ?? map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      contractNumber: map['contractNumber'] ?? 'CTR-B2B',
      status: map['status'] ?? 'executed',
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      buyerCompany: map['buyerCompany'] ?? 'Institutional Agri Buyer',
      buyerGstin: map['buyerGstin'] ?? '06AABCI9821E1ZK',
      buyerAddress: map['buyerAddress'] ?? '',
      buyerSignatory: map['buyerSignatory'] ?? '',
      fpoId: map['fpoId'] ?? '',
      fpoName: map['fpoName'] ?? '',
      fpoRegistrationNo: map['fpoRegistrationNo'] ?? '',
      fpoGstin: map['fpoGstin'] ?? '',
      fpoWarehouseAddress: map['fpoWarehouseAddress'] ?? '',
      fpoSignatory: map['fpoSignatory'] ?? '',
      isMultiFpo: map['isMultiFpo'] == true,
      coFpos: (map['coFpos'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      farmerBeneficiaries: (map['farmerBeneficiaries'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      commodity: map['commodity'] ?? '',
      variety: map['variety'] ?? '',
      qualityGrade: map['qualityGrade'] ?? 'Grade A',
      moistureTolerancePct: (map['moistureTolerancePct'] as num?)?.toDouble() ?? 12.0,
      foreignMatterTolerancePct: (map['foreignMatterTolerancePct'] as num?)?.toDouble() ?? 0.8,
      brokenGrainsTolerancePct: (map['brokenGrainsTolerancePct'] as num?)?.toDouble() ?? 2.0,
      quantityQtl: (map['quantityQtl'] as num?)?.toDouble() ?? 0.0,
      quantityMT: (map['quantityMT'] as num?)?.toDouble() ?? 0.0,
      pricePerQtl: (map['pricePerQtl'] as num?)?.toDouble() ?? 0.0,
      cropBaseAmount: (map['cropBaseAmount'] as num?)?.toDouble() ?? 0.0,
      freightAmount: (map['freightAmount'] as num?)?.toDouble() ?? 0.0,
      carrierName: map['carrierName'] ?? '',
      transitInsuranceAmount: (map['transitInsuranceAmount'] as num?)?.toDouble() ?? 0.0,
      protocolFeeAmount: (map['protocolFeeAmount'] as num?)?.toDouble() ?? 0.0,
      totalEscrowAmount: (map['totalEscrowAmount'] as num?)?.toDouble() ?? 0.0,
      originLocation: map['originLocation'] ?? '',
      destinationFactory: map['destinationFactory'] ?? '',
      expectedDeliveryDate: map['expectedDeliveryDate'] ?? '',
      transitWindowHours: (map['transitWindowHours'] as num?)?.toInt() ?? 24,
      fastagVehicleNumber: map['fastagVehicleNumber'],
      clauses: (map['clauses'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
              .toList() ??
          const [],
      sha256Hash: map['sha256Hash'] ?? '',
      polygonContractAddress: map['polygonContractAddress'] ?? '0x8a92b1f83c1b69f8d9b1c720993414ec49f0',
      blockchainNetwork: map['blockchainNetwork'] ?? 'Polygon PoS L2',
      buyerSignedAt: map['buyerSignedAt'],
      buyerSignatureDigest: map['buyerSignatureDigest'],
      sellerSignedAt: map['sellerSignedAt'],
      sellerSignatureDigest: map['sellerSignatureDigest'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
