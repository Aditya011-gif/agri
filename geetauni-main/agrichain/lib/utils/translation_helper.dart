import 'package:flutter/material.dart';

/// Helper utility for translating dynamic database/ML values into localized strings.
class TranslationHelper {
  /// Translates Risk Tier / Category
  static String getRiskTier(BuildContext context, String? riskTier) {
    if (riskTier == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = riskTier.toLowerCase();

    if (lower.contains('platinum')) {
      return isHindi ? 'प्लैटिनम श्रेणी (उत्कृष्ट)' : 'Platinum Tier';
    } else if (lower.contains('gold')) {
      return isHindi ? 'स्वर्ण श्रेणी (उत्तम)' : 'Gold Tier';
    } else if (lower.contains('silver')) {
      return isHindi ? 'रजत श्रेणी (मध्यम)' : 'Silver Tier';
    } else if (lower.contains('bronze')) {
      return isHindi ? 'कांस्य श्रेणी (सामान्य)' : 'Bronze Tier';
    } else if (lower.contains('low')) {
      return isHindi ? 'कम जोखिम (Low Risk)' : 'Low Risk';
    } else if (lower.contains('medium') || lower.contains('moderate')) {
      return isHindi ? 'मध्यम जोखिम (Medium Risk)' : 'Medium Risk';
    } else if (lower.contains('high')) {
      return isHindi ? 'उच्च जोखिम (High Risk)' : 'High Risk';
    } else if (lower.contains('flagged')) {
      return isHindi ? 'समीक्षा हेतु चिह्नित (Flagged)' : 'Flagged';
    }
    return riskTier;
  }

  /// Translates Soil Type
  static String getSoilType(BuildContext context, String? soilType) {
    if (soilType == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = soilType.toLowerCase();

    if (lower.contains('alluvial')) {
      return isHindi ? 'जलोढ़ मिट्टी' : 'Alluvial Soil';
    } else if (lower.contains('black') || lower.contains('cotton')) {
      return isHindi ? 'काली कपास मिट्टी' : 'Black Cotton Soil';
    } else if (lower.contains('red')) {
      return isHindi ? 'लाल दोमट मिट्टी' : 'Red Soil';
    } else if (lower.contains('clay')) {
      return isHindi ? 'चिकनी मिट्टी' : 'Clayey Soil';
    } else if (lower.contains('concrete') || lower.contains('degraded')) {
      return isHindi ? 'शहरी / बंजर भूमि' : 'Concrete / Degraded';
    }
    return isHindi ? 'मिश्रित मिट्टी' : (soilType.isEmpty ? 'Mixed Soil' : soilType);
  }

  /// Translates Agricultural Season
  static String getSeason(BuildContext context, String? season) {
    if (season == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = season.toLowerCase();

    if (lower.contains('kharif')) {
      return isHindi ? 'खरीफ (मानसून)' : 'Kharif';
    } else if (lower.contains('rabi')) {
      return isHindi ? 'रबी (सर्दियां)' : 'Rabi';
    } else if (lower.contains('zaid')) {
      return isHindi ? 'जायद (गर्मी)' : 'Zaid';
    }
    return season;
  }

  /// Translates ML Predicted Crop Quality Grade
  static String getCropQuality(BuildContext context, String? quality) {
    if (quality == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = quality.toLowerCase();

    if (lower.contains('excellent') || lower.contains('grade a')) {
      return isHindi ? 'उत्कृष्ट (Grade A)' : 'Grade A (Excellent)';
    } else if (lower.contains('good') || lower.contains('grade b')) {
      return isHindi ? 'उत्तम (Grade B)' : 'Grade B (Good)';
    } else if (lower.contains('moderate') || lower.contains('grade c')) {
      return isHindi ? 'मध्यम (Grade C)' : 'Grade C (Moderate)';
    } else if (lower.contains('poor') || lower.contains('grade d')) {
      return isHindi ? 'सामान्य / कमजोर (Grade D)' : 'Grade D (Poor)';
    }
    return quality;
  }

  /// Translates NDVI Trend
  static String getNdviTrend(BuildContext context, String? trend) {
    if (trend == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = trend.toLowerCase();

    if (lower.contains('increase')) {
      return isHindi ? 'बढ़ने की संभावना (Increase)' : 'Increase';
    } else if (lower.contains('stable')) {
      return isHindi ? 'स्थिर (Stable)' : 'Stable';
    } else if (lower.contains('decrease')) {
      return isHindi ? 'घटने की संभावना (Decrease)' : 'Decrease';
    }
    return trend;
  }

  /// Translates Loan Status
  static String getLoanStatus(BuildContext context, String? status) {
    if (status == null) return 'N/A';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    final lower = status.toLowerCase();

    if (lower.contains('pending')) {
      return isHindi ? 'स्वीकृति लंबित' : 'Pending';
    } else if (lower.contains('active')) {
      return isHindi ? 'सक्रिय' : 'Active';
    } else if (lower.contains('completed') || lower.contains('repaid')) {
      return isHindi ? 'पूर्ण / चुकता' : 'Completed';
    } else if (lower.contains('defaulted')) {
      return isHindi ? 'डिफ़ॉल्ट' : 'Defaulted';
    } else if (lower.contains('overdue')) {
      return isHindi ? 'अतिदेय (Overdue)' : 'Overdue';
    }
    return status;
  }

  /// Translates Crop Name / Type
  static String getCropName(BuildContext context, String? cropName) {
    if (cropName == null) return '';
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';
    if (!isHindi) return cropName;
    final lower = cropName.toLowerCase();

    if (lower.contains('wheat')) {
      return cropName.replaceAll(RegExp('wheat', caseSensitive: false), 'गेहूं');
    } else if (lower.contains('rice') || lower.contains('basmati') || lower.contains('paddy')) {
      return cropName.replaceAll(RegExp('rice', caseSensitive: false), 'चावल').replaceAll(RegExp('basmati', caseSensitive: false), 'बासमती');
    } else if (lower.contains('maize') || lower.contains('corn')) {
      return cropName.replaceAll(RegExp('maize|corn', caseSensitive: false), 'मक्का');
    } else if (lower.contains('cotton')) {
      return cropName.replaceAll(RegExp('cotton', caseSensitive: false), 'कपास');
    } else if (lower.contains('sugarcane')) {
      return cropName.replaceAll(RegExp('sugarcane', caseSensitive: false), 'गन्ना');
    } else if (lower.contains('potato')) {
      return cropName.replaceAll(RegExp('potato', caseSensitive: false), 'आलू');
    } else if (lower.contains('tomato')) {
      return cropName.replaceAll(RegExp('tomato', caseSensitive: false), 'टमाटर');
    } else if (lower.contains('onion')) {
      return cropName.replaceAll(RegExp('onion', caseSensitive: false), 'प्याज');
    } else if (lower.contains('soybean')) {
      return cropName.replaceAll(RegExp('soybean', caseSensitive: false), 'सोयाबीन');
    } else if (lower.contains('mango')) {
      return cropName.replaceAll(RegExp('mango', caseSensitive: false), 'आम');
    } else if (lower.contains('banana')) {
      return cropName.replaceAll(RegExp('banana', caseSensitive: false), 'केला');
    }
    return cropName;
  }

  // Aliases for convenience
  static String translateCropType(BuildContext context, String? cropName) => getCropName(context, cropName);
  static String translateRiskTier(BuildContext context, String? riskTier) => getRiskTier(context, riskTier);
  static String translateLoanStatus(BuildContext context, String? status) => getLoanStatus(context, status);
  static String translateCropQuality(BuildContext context, String? quality) => getCropQuality(context, quality);

  /// Formats currency with INR symbol
  static String formatINR(double amount) {
    return '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  /// Direct bilingual string helper
  static String tr(BuildContext context, String en, String hi) {
    try {
      return Localizations.localeOf(context).languageCode == 'hi' ? hi : en;
    } catch (_) {
      return en;
    }
  }
}

/// Extension on BuildContext for quick and elegant localization access:
/// Example: `Text(context.tr('My Orders', 'मेरे ऑर्डर'))`
extension LocalizationExtension on BuildContext {
  bool get isHindi {
    try {
      return Localizations.localeOf(this).languageCode == 'hi';
    } catch (_) {
      return false;
    }
  }

  String tr(String en, String hi) => isHindi ? hi : en;
}
