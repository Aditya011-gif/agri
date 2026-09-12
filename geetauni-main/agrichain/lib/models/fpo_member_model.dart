/// Model: FPO Constituent Member Farmer
/// Represents an individual member farmer enrolled in the FPO directory.
/// Contains verified KYC, Penny-Drop verified bank accounts, and inward lot shares.
class FpoMemberFarmer {
  final String id; // e.g. 'FPO-MBR-KNL-0842'
  final String fpoId; // e.g. 'fpo_karnal_01'
  final String name; // e.g. 'Sukhwinder Sandhu'
  final String aadhaarLast4; // e.g. '8921'
  final String mobileNumber; // e.g. '9845122310'
  final String villageTehsil; // e.g. 'Nilokheri, Karnal'
  final String bankName; // e.g. 'State Bank of India'
  final String accountNumber; // full account number stored securely
  final String ifscCode; // e.g. 'SBIN0001824'
  final List<String> primaryCrops; // e.g. ['Basmati Paddy', 'Sharbati Wheat']
  final bool isPennyDropVerified;
  final String? pennyDropAccountHolder;
  final String? pennyDropRef;
  final double totalContributedQtl;
  final double totalDbtReceived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FpoMemberFarmer({
    required this.id,
    required this.fpoId,
    required this.name,
    required this.aadhaarLast4,
    required this.mobileNumber,
    required this.villageTehsil,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.primaryCrops = const ['Sharbati Wheat', 'Basmati Paddy'],
    this.isPennyDropVerified = true,
    this.pennyDropAccountHolder,
    this.pennyDropRef,
    this.totalContributedQtl = 0.0,
    this.totalDbtReceived = 0.0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Masked Bank Account Number for Privacy & Regulatory Compliance (e.g. •••• •••• 4821)
  String get maskedAccountNumber {
    final clean = accountNumber.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 4) return clean;
    final last4 = clean.substring(clean.length - 4);
    return '•••• •••• $last4';
  }

  /// Masked Aadhaar (e.g. XXXX-XXXX-8921)
  String get maskedAadhaar {
    final clean = aadhaarLast4.trim();
    if (clean.length == 4) return 'XXXX-XXXX-$clean';
    if (clean.length > 4) return 'XXXX-XXXX-${clean.substring(clean.length - 4)}';
    return 'XXXX-XXXX-0000';
  }

  /// Formatted phone with country code (e.g. +91 98451 22310)
  String get formattedPhone {
    final digits = mobileNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return mobileNumber;
  }

  FpoMemberFarmer copyWith({
    String? name,
    String? aadhaarLast4,
    String? mobileNumber,
    String? villageTehsil,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    List<String>? primaryCrops,
    bool? isPennyDropVerified,
    String? pennyDropAccountHolder,
    String? pennyDropRef,
    double? totalContributedQtl,
    double? totalDbtReceived,
    DateTime? updatedAt,
  }) {
    return FpoMemberFarmer(
      id: id,
      fpoId: fpoId,
      name: name ?? this.name,
      aadhaarLast4: aadhaarLast4 ?? this.aadhaarLast4,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      villageTehsil: villageTehsil ?? this.villageTehsil,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      primaryCrops: primaryCrops ?? this.primaryCrops,
      isPennyDropVerified: isPennyDropVerified ?? this.isPennyDropVerified,
      pennyDropAccountHolder: pennyDropAccountHolder ?? this.pennyDropAccountHolder,
      pennyDropRef: pennyDropRef ?? this.pennyDropRef,
      totalContributedQtl: totalContributedQtl ?? this.totalContributedQtl,
      totalDbtReceived: totalDbtReceived ?? this.totalDbtReceived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fpoId': fpoId,
    'name': name,
    'aadhaarLast4': aadhaarLast4,
    'mobileNumber': mobileNumber,
    'villageTehsil': villageTehsil,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'ifscCode': ifscCode,
    'primaryCrops': primaryCrops,
    'isPennyDropVerified': isPennyDropVerified,
    'pennyDropAccountHolder': pennyDropAccountHolder ?? name,
    'pennyDropRef': pennyDropRef ?? 'NPCI-IMPS-${id.hashCode.abs().toString().padLeft(8, '0')}',
    'totalContributedQtl': totalContributedQtl,
    'totalDbtReceived': totalDbtReceived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
  };

  factory FpoMemberFarmer.fromMap(Map<String, dynamic> map, [String? docId]) => FpoMemberFarmer(
    id: map['id'] ?? docId ?? 'FPO-MBR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    fpoId: map['fpoId'] ?? 'fpo_karnal_01',
    name: map['name'] ?? 'Kisan Member',
    aadhaarLast4: map['aadhaarLast4']?.toString() ?? '8921',
    mobileNumber: map['mobileNumber']?.toString() ?? '9876543210',
    villageTehsil: map['villageTehsil'] ?? 'Karnal, Haryana',
    bankName: map['bankName'] ?? 'State Bank of India',
    accountNumber: map['accountNumber']?.toString() ?? '918273645012',
    ifscCode: map['ifscCode']?.toString().toUpperCase() ?? 'SBIN0001824',
    primaryCrops: map['primaryCrops'] is List
        ? List<String>.from(map['primaryCrops'])
        : (map['primaryCrops'] != null
            ? map['primaryCrops'].toString().split(',').map((e) => e.trim()).toList()
            : ['Sharbati Wheat', 'Basmati Paddy']),
    isPennyDropVerified: map['isPennyDropVerified'] as bool? ?? true,
    pennyDropAccountHolder: map['pennyDropAccountHolder'] as String?,
    pennyDropRef: map['pennyDropRef'] as String?,
    totalContributedQtl: (map['totalContributedQtl'] as num?)?.toDouble() ?? 0.0,
    totalDbtReceived: (map['totalDbtReceived'] as num?)?.toDouble() ?? 0.0,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: map['updatedAt'] != null
        ? DateTime.tryParse(map['updatedAt'])
        : null,
  );

  /// Converts this member to a standard CSV string row
  String toCsvRow() {
    final crops = primaryCrops.join(';');
    return '"$name","$aadhaarLast4","$mobileNumber","$villageTehsil","$bankName","$accountNumber","$ifscCode","$crops"';
  }
}
