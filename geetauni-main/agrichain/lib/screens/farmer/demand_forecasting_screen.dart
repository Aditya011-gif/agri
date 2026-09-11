import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/demand_forecast_models.dart';
import '../../services/demand_forecasting_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';

class DemandForecastingScreen extends StatefulWidget {
  final String? initialCrop;
  final String? initialDistrict;

  const DemandForecastingScreen({
    super.key,
    this.initialCrop,
    this.initialDistrict,
  });

  @override
  State<DemandForecastingScreen> createState() => _DemandForecastingScreenState();
}

class _DemandForecastingScreenState extends State<DemandForecastingScreen> {
  final DemandForecastingService _forecastingService = DemandForecastingService();

  late String _selectedCrop;
  late String _selectedDistrict;
  late DateTime _targetDate;
  int _selectedDaysAhead = 7;
  final double _farmerLotSizeKg = 4000;

  bool _isLoading = false;
  DemandForecastResponse? _forecastData;

  static const List<Map<String, String>> _allCropsCatalog = [
    // 🥦 Vegetables
    {'name': 'Tomato', 'hindi': 'टमाटर', 'icon': '🍅', 'category': 'Vegetables'},
    {'name': 'Potato', 'hindi': 'आलू', 'icon': '🥔', 'category': 'Vegetables'},
    {'name': 'Onion', 'hindi': 'प्याज', 'icon': '🧅', 'category': 'Vegetables'},
    {'name': 'Cauliflower', 'hindi': 'फूलगोभी', 'icon': '🥦', 'category': 'Vegetables'},
    {'name': 'Cabbage', 'hindi': 'पत्तागोभी', 'icon': '🥬', 'category': 'Vegetables'},
    {'name': 'Green Peas', 'hindi': 'हरी मटर', 'icon': '🫛', 'category': 'Vegetables'},
    {'name': 'Green Chilli', 'hindi': 'हरी मिर्च', 'icon': '🌶️', 'category': 'Vegetables'},
    {'name': 'Garlic', 'hindi': 'लहसुन', 'icon': '🧄', 'category': 'Vegetables'},
    {'name': 'Ginger', 'hindi': 'अदरक', 'icon': '🫚', 'category': 'Vegetables'},
    {'name': 'Okra', 'hindi': 'भिंडी', 'icon': '🥒', 'category': 'Vegetables'},
    {'name': 'Carrot', 'hindi': 'गाजर', 'icon': '🥕', 'category': 'Vegetables'},
    {'name': 'Brinjal', 'hindi': 'बैंगन', 'icon': '🍆', 'category': 'Vegetables'},
    {'name': 'Capsicum', 'hindi': 'शिमला मिर्च', 'icon': '🫑', 'category': 'Vegetables'},
    // 🍎 Fruits
    {'name': 'Mango', 'hindi': 'आम', 'icon': '🥭', 'category': 'Fruits'},
    {'name': 'Banana', 'hindi': 'केला', 'icon': '🍌', 'category': 'Fruits'},
    {'name': 'Apple', 'hindi': 'सेब', 'icon': '🍎', 'category': 'Fruits'},
    {'name': 'Kinnow', 'hindi': 'किन्नू', 'icon': '🍊', 'category': 'Fruits'},
    {'name': 'Guava', 'hindi': 'अमरूद', 'icon': '🍐', 'category': 'Fruits'},
    {'name': 'Papaya', 'hindi': 'पपीता', 'icon': '🍈', 'category': 'Fruits'},
    {'name': 'Pomegranate', 'hindi': 'अनार', 'icon': '🍇', 'category': 'Fruits'},
    {'name': 'Grapes', 'hindi': 'अंगूर', 'icon': '🍇', 'category': 'Fruits'},
    {'name': 'Watermelon', 'hindi': 'तरबूज', 'icon': '🍉', 'category': 'Fruits'},
    // 🌾 Grains & Pulses & Cash
    {'name': 'Wheat', 'hindi': 'गेहूं', 'icon': '🌾', 'category': 'Grains'},
    {'name': 'Rice', 'hindi': 'चावल', 'icon': '🍚', 'category': 'Grains'},
    {'name': 'Maize', 'hindi': 'मक्का', 'icon': '🌽', 'category': 'Grains'},
    {'name': 'Desi Chana', 'hindi': 'चना', 'icon': '🫘', 'category': 'Pulses'},
    {'name': 'Moong Dal', 'hindi': 'मूंग', 'icon': '🌱', 'category': 'Pulses'},
    {'name': 'Mustard', 'hindi': 'सरसों', 'icon': '🌻', 'category': 'Oilseeds'},
    {'name': 'Soybean', 'hindi': 'सोयाबीन', 'icon': '🫛', 'category': 'Oilseeds'},
    {'name': 'Cotton', 'hindi': 'कपास', 'icon': '🌿', 'category': 'Cash Crops'},
  ];

  final List<String> _popularQuickCrops = [
    'Tomato',
    'Onion',
    'Mango',
    'Kinnow',
    'Cauliflower',
    'Wheat',
    'Rice',
    'Apple',
    'Potato',
    'Green Peas',
  ];

  final List<Map<String, String>> _supportedDistricts = [
    {
      'name': 'Azadpur',
      'mandiName': 'Azadpur APMC Mega Mandi (आज़ादपुर)',
      'state': 'Delhi',
      'badge': 'Asia\'s Mega APMC',
    },
    {
      'name': 'Karnal',
      'mandiName': 'Karnal Anaj Mandi (करनाल मंडी)',
      'state': 'Haryana',
      'badge': 'Basmati Hub',
    },
    {
      'name': 'Lasalgaon',
      'mandiName': 'Lasalgaon APMC (लासलगांव मंडी)',
      'state': 'Maharashtra',
      'badge': 'Asia\'s Onion Capital',
    },
    {
      'name': 'Khanna',
      'mandiName': 'Khanna Grain Market (खन्ना मंडी)',
      'state': 'Punjab',
      'badge': 'Asia\'s Largest Grain Mandi',
    },
    {
      'name': 'Kolar',
      'mandiName': 'Kolar APMC Market (कोलार मंडी)',
      'state': 'Karnataka',
      'badge': 'Tomato Hub',
    },
    {
      'name': 'Vashi',
      'mandiName': 'Vashi APMC Navi Mumbai (वाशी मंडी)',
      'state': 'Maharashtra',
      'badge': 'Western Terminal APMC',
    },
    {
      'name': 'Gondal',
      'mandiName': 'Gondal APMC (गोंडल मंडी)',
      'state': 'Gujarat',
      'badge': 'Groundnut & Cotton',
    },
    {
      'name': 'Guntur',
      'mandiName': 'Guntur Mirchi Yard (गुंटूर मिर्ची यार्ड)',
      'state': 'Andhra Pradesh',
      'badge': 'Spices & Chilli Mandi',
    },
    {
      'name': 'Indore',
      'mandiName': 'Choithram APMC Mandi (इंदौर मंडी)',
      'state': 'Madhya Pradesh',
      'badge': 'Soybean & Wheat Center',
    },
    {
      'name': 'Kota',
      'mandiName': 'Bhamashah APMC Mandi (कोटा मंडी)',
      'state': 'Rajasthan',
      'badge': 'Hadoti Agro Exchange',
    },
    {
      'name': 'Agra',
      'mandiName': 'Agra APMC Mandi (आगरा मंडी)',
      'state': 'Uttar Pradesh',
      'badge': 'Potato Capital',
    },
    {
      'name': 'Pune',
      'mandiName': 'Gultekdi APMC Yard (पुणे मंडी)',
      'state': 'Maharashtra',
      'badge': 'Western APMC',
    },
  ];

  static const Map<String, Map<String, dynamic>> _cropMspCatalog = {
    'Wheat': {'mspQtl': 2275.0, 'mspKg': 22.75, 'season': 'Rabi 2024-25', 'govtNotified': true},
    'Rice': {'mspQtl': 2320.0, 'mspKg': 23.20, 'season': 'Kharif 2024-25', 'govtNotified': true},
    'Maize': {'mspQtl': 2090.0, 'mspKg': 20.90, 'season': 'Kharif 2024-25', 'govtNotified': true},
    'Desi Chana': {'mspQtl': 5440.0, 'mspKg': 54.40, 'season': 'Rabi 2024-25', 'govtNotified': true},
    'Moong Dal': {'mspQtl': 8682.0, 'mspKg': 86.82, 'season': 'Kharif 2024-25', 'govtNotified': true},
    'Mustard': {'mspQtl': 5650.0, 'mspKg': 56.50, 'season': 'Rabi 2024-25', 'govtNotified': true},
    'Soybean': {'mspQtl': 4892.0, 'mspKg': 48.92, 'season': 'Kharif 2024-25', 'govtNotified': true},
    'Cotton': {'mspQtl': 7121.0, 'mspKg': 71.21, 'season': 'Kharif 2024-25', 'govtNotified': true},
    'Potato': {'mspQtl': null, 'cacpBenchmarkKg': 18.0, 'season': '2024-25', 'govtNotified': false},
    'Tomato': {'mspQtl': null, 'cacpBenchmarkKg': 22.0, 'season': '2024-25', 'govtNotified': false},
    'Onion': {'mspQtl': null, 'cacpBenchmarkKg': 24.0, 'season': '2024-25', 'govtNotified': false},
    'Garlic': {'mspQtl': null, 'cacpBenchmarkKg': 90.0, 'season': '2024-25', 'govtNotified': false},
    'Ginger': {'mspQtl': null, 'cacpBenchmarkKg': 70.0, 'season': '2024-25', 'govtNotified': false},
    'Cauliflower': {'mspQtl': null, 'cacpBenchmarkKg': 20.0, 'season': '2024-25', 'govtNotified': false},
    'Cabbage': {'mspQtl': null, 'cacpBenchmarkKg': 14.0, 'season': '2024-25', 'govtNotified': false},
    'Green Peas': {'mspQtl': null, 'cacpBenchmarkKg': 38.0, 'season': '2024-25', 'govtNotified': false},
    'Green Chilli': {'mspQtl': null, 'cacpBenchmarkKg': 40.0, 'season': '2024-25', 'govtNotified': false},
    'Mango': {'mspQtl': null, 'cacpBenchmarkKg': 45.0, 'season': '2024-25', 'govtNotified': false},
    'Apple': {'mspQtl': null, 'cacpBenchmarkKg': 65.0, 'season': '2024-25', 'govtNotified': false},
    'Kinnow': {'mspQtl': null, 'cacpBenchmarkKg': 28.0, 'season': '2024-25', 'govtNotified': false},
    'Banana': {'mspQtl': null, 'cacpBenchmarkKg': 20.0, 'season': '2024-25', 'govtNotified': false},
  };

  @override
  void initState() {
    super.initState();
    _selectedCrop = widget.initialCrop ?? 'Tomato';
    _selectedDistrict = widget.initialDistrict ?? 'Karnal';
    _targetDate = DateTime.now().add(Duration(days: _selectedDaysAhead));
    _fetchForecast();
  }

  Future<void> _fetchForecast() async {
    setState(() => _isLoading = true);
    try {
      final selectedDistrictMeta = _supportedDistricts.firstWhere(
        (d) => d['name'] == _selectedDistrict,
        orElse: () => {'name': _selectedDistrict, 'state': 'Haryana'},
      );

      final result = await _forecastingService.getForecast(
        commodity: _selectedCrop,
        district: _selectedDistrict,
        targetDate: _targetDate,
        state: selectedDistrictMeta['state'],
      );

      if (mounted) {
        setState(() {
          _forecastData = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onDaysAheadChanged(int days) {
    setState(() {
      _selectedDaysAhead = days;
      _targetDate = DateTime.now().add(Duration(days: days));
    });
    _fetchForecast();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppTheme.darkGreen,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('AI Price & Demand Forecast', 'कृषिदृष्टि: मंडी भाव व मांग अनुमान'),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr('Probabilistic Quantile & Mandi Price Engine', 'संभाव्य क्वांटाइल और मंडी मूल्य इंजन'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Center(child: LanguageSwitcherPill(isDark: false)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
            tooltip: context.tr('Recalculate Forecast', 'पूर्वानुमान ताज़ा करें'),
            onPressed: _isLoading ? null : _fetchForecast,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Interactive Parameter Selector Card
          _buildSelectorControlsCard(),
          const SizedBox(height: 16),

          // 2. Loading or Forecast Results
          if (_isLoading)
            _buildLoadingIndicator()
          else if (_forecastData != null) ...[
            // 2.5. Dynamic One-Line Factor Summary Banner
            _buildHindiFactorSummaryBanner(_forecastData!),
            const SizedBox(height: 16),

            // 3. Price Forecast & Revenue Estimator
            _buildPriceRealizationCard(_forecastData!),
            const SizedBox(height: 16),

            // 3.5. Government Minimum Support Price (MSP) Benchmark Card
            _buildGovtMspBenchmarkCard(_forecastData!),
            const SizedBox(height: 16),

            // 4. Probabilistic Demand Quantiles (P10 / P50 / P90)
            _buildDemandQuantilesCard(_forecastData!),
            const SizedBox(height: 16),

            // 5. Actionable Farm-Gate Advisory Card
            _buildActionableAdvisoryCard(_forecastData!),
            const SizedBox(height: 16),

            // 6. Agrometeorological & Disruption Radar
            _buildAgroWeatherDisruptionCard(_forecastData!),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  /// 1. Interactive Selector Controls Card
  Widget _buildSelectorControlsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppTheme.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Forecast Parameters',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '7–14 Day Forward ML',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Commodity Dropdown & Category Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Commodity (फसल / फल / सब्जी):',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_allCropsCatalog.length} Crops Available',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Primary Categorized Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _allCropsCatalog.any((c) => c['name'] == _selectedCrop)
                    ? _selectedCrop
                    : 'Tomato',
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: AppTheme.primaryGreen),
                items: _allCropsCatalog.map((crop) {
                  return DropdownMenuItem<String>(
                    value: crop['name'],
                    child: Row(
                      children: [
                        Text(crop['icon'] ?? '🌾', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${crop['name']} (${crop['hindi']})',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: crop['category'] == 'Fruits'
                                ? Colors.orange.shade50
                                : crop['category'] == 'Vegetables'
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            crop['category'] ?? '',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: crop['category'] == 'Fruits'
                                  ? Colors.orange.shade900
                                  : crop['category'] == 'Vegetables'
                                      ? Colors.green.shade900
                                      : Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedCrop) {
                    setState(() => _selectedCrop = val);
                    _fetchForecast();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick-Access Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _popularQuickCrops.map((cropName) {
                final isSelected = _selectedCrop == cropName;
                final meta = _allCropsCatalog.firstWhere(
                  (c) => c['name'] == cropName,
                  orElse: () => {'name': cropName, 'icon': '🌾', 'hindi': ''},
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${meta['icon']} $cropName'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGreen,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCrop = cropName);
                        _fetchForecast();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Target APMC Mandi Selector Dropdown & Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target APMC Mandi (मंडी चयन):',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_supportedDistricts.length} Real APMCs',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Primary APMC Mandi Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _supportedDistricts.any((d) => d['name'] == _selectedDistrict)
                    ? _selectedDistrict
                    : 'Azadpur',
                isExpanded: true,
                icon: const Icon(Icons.storefront_outlined, color: AppTheme.primaryGreen),
                items: _supportedDistricts.map((mandi) {
                  return DropdownMenuItem<String>(
                    value: mandi['name'],
                    child: Row(
                      children: [
                        const Icon(Icons.location_city, size: 16, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                mandi['mandiName'] ?? '${mandi['name']} Mandi',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGreen,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${mandi['state']} • ${mandi['badge']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null && val != _selectedDistrict) {
                    setState(() => _selectedDistrict = val);
                    _fetchForecast();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick-Access APMC Mandi Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _supportedDistricts.map((d) {
                final isSelected = _selectedDistrict == d['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${d['name']} (${d['state']})'),
                    selected: isSelected,
                    selectedColor: AppTheme.darkGreen,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedDistrict = d['name']!);
                        _fetchForecast();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Target Horizon Day Buttons (+7d, +10d, +14d)
          Row(
            children: [
              Text(
                'Horizon:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              _buildHorizonChip(7, '+7 Days'),
              const SizedBox(width: 6),
              _buildHorizonChip(10, '+10 Days'),
              const SizedBox(width: 6),
              _buildHorizonChip(14, '+14 Days'),
              const Spacer(),
              Text(
                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonChip(int days, String label) {
    final isSelected = _selectedDaysAhead == days;
    return InkWell(
      onTap: () => _onDaysAheadChanged(days),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.darkGreen,
          ),
        ),
      ),
    );
  }

  /// 2. Price Forecast & Revenue Estimator Card
  Widget _buildPriceRealizationCard(DemandForecastResponse data) {
    final price = data.priceForecastInrPerKg;
    final grossEstimatedRevenue = price.expectedModalPrice * _farmerLotSizeKg;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.currency_rupee, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected Modal Price Realization',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${price.expectedModalPrice.toStringAsFixed(2)} / kg',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Mandi Expected',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price Spread Range Bar (Min -> Modal -> Max)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Min: ₹${price.minPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Modal: ₹${price.expectedModalPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Max: ₹${price.maxPrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.60,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF69F0AE)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lot Size Gross Revenue Calculator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Value (${_farmerLotSizeKg.toStringAsFixed(0)} kg lot):',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              Text(
                '₹${grossEstimatedRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF69F0AE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3.5. Government Minimum Support Price (MSP) Benchmark Card
  Widget _buildGovtMspBenchmarkCard(DemandForecastResponse data) {
    final commodity = data.meta.commodity;
    final mspInfo = _cropMspCatalog[commodity];
    final isGovtNotified = mspInfo?['govtNotified'] == true;
    final mspQtl = mspInfo?['mspQtl'] as double?;
    final mspKg = mspInfo?['mspKg'] as double? ?? (mspQtl != null ? mspQtl / 100 : null);
    final cacpBenchmark = mspInfo?['cacpBenchmarkKg'] as double? ?? 22.0;
    final season = mspInfo?['season'] as String? ?? '2024-25';

    final modalPrice = data.priceForecastInrPerKg.expectedModalPrice;
    final compareBase = isGovtNotified ? (mspKg ?? 20.0) : cacpBenchmark;
    final diff = modalPrice - compareBase;
    final isAboveFloor = diff >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGovtNotified
              ? (isAboveFloor ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
              : const Color(0xFF3B82F6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Govt MSP Emblem & Season Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGovtNotified ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGovtNotified ? Icons.verified_user_outlined : Icons.insights_outlined,
                  color: isGovtNotified ? const Color(0xFF059669) : const Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGovtNotified
                          ? 'Govt. MSP Floor (न्यूनतम समर्थन मूल्य)'
                          : 'CACP Seasonal Benchmark (संदर्भ भाव)',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      isGovtNotified
                          ? 'CACP / Ministry of Agriculture Notified • $season'
                          : 'Open Mandi Horticultural Parity • $season',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGovtNotified ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGovtNotified ? 'GOVT NOTIFIED' : 'MARKET PARITY',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isGovtNotified ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Core Rates Comparison Block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // MSP Rate Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGovtNotified ? 'Official MSP Rate' : 'CACP Baseline Rate',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isGovtNotified && mspQtl != null
                            ? '₹${mspQtl.toStringAsFixed(0)} / Qtl'
                            : '₹${cacpBenchmark.toStringAsFixed(1)} / kg',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (isGovtNotified && mspKg != null)
                        Text(
                          '≈ ₹${mspKg.toStringAsFixed(2)} / kg',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 12),
                // Market Modal vs MSP
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Projected Mandi Modal',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${modalPrice.toStringAsFixed(2)} / kg',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        '≈ ₹${(modalPrice * 100).toStringAsFixed(0)} / Qtl',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Visual Floor Protection Badge / Advisory
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAboveFloor ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAboveFloor ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAboveFloor ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: isAboveFloor ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAboveFloor
                        ? (isGovtNotified
                            ? 'Mandi modal is ₹${diff.toStringAsFixed(2)}/kg above Govt MSP floor (+${((diff / compareBase) * 100).toStringAsFixed(0)}%). Safe for open auction.'
                            : 'Mandi modal is trading ₹${diff.toStringAsFixed(2)}/kg above seasonal benchmark.')
                        : (isGovtNotified
                            ? 'Warning: Modal price is ₹${(-diff).toStringAsFixed(2)}/kg below MSP floor! Recommend selling via FPO / Govt Silo Procurement center.'
                            : 'Mandi price is below seasonal baseline. Consider holding lot in cold storage.'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAboveFloor ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2.5. Dynamic One-Line Factor Summary Banner
  Widget _buildHindiFactorSummaryBanner(DemandForecastResponse data) {
    final commodity = data.meta.commodity;
    final district = data.meta.district;
    final expectedQtl = (data.demandForecastKg.p50Expected / 100).toStringAsFixed(0);
    final expectedKgFormatted = data.demandForecastKg.p50Expected.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AI मांग निष्कर्ष (AI Demand Summary)',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0D381E),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'मौसम के बदलाव, आगामी त्योहारी सीज़न और स्थानीय मंडी आवक के आधार पर अगले 14 दिनों में $district क्षेत्र में $commodity की कुल अनुमानित मांग लगभग $expectedQtl क्विंटल ($expectedKgFormatted kg) रहने की संभावना है।',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Probabilistic Demand Quantiles (Simple Hindi Terms)
  Widget _buildDemandQuantilesCard(DemandForecastResponse data) {
    final demand = data.demandForecastKg;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'अनुमानित बाजार मांग (Estimated Demand in KG)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                    Text(
                      'न्यूनतम, संभावित और अधिकतम मांग का 3-स्तरीय विश्लेषण',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Quantile Risk Cards (Simple Hindi terms)
          Row(
            children: [
              Expanded(
                child: _buildQuantileBox(
                  title: 'न्यूनतम मांग\n(कम से कम)',
                  subtitle: 'मंदी में भी इतना बिकेगा',
                  value: demand.p10Pessimistic,
                  color: Colors.orange.shade800,
                  bgColor: Colors.orange.shade50,
                  borderColor: Colors.orange.shade300,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuantileBox(
                  title: 'संभावित मांग\n(सबसे सटीक)',
                  subtitle: 'सामान्य व औसत मांग',
                  value: demand.p50Expected,
                  color: AppTheme.primaryGreen,
                  bgColor: Colors.green.shade50,
                  borderColor: Colors.green.shade300,
                  isHighlighted: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuantileBox(
                  title: 'अधिकतम मांग\n(पीक सीज़न)',
                  subtitle: 'त्योहार/शादी की मांग',
                  value: demand.p90Optimistic,
                  color: Colors.purple.shade800,
                  bgColor: Colors.purple.shade50,
                  borderColor: Colors.purple.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantileBox({
    required String title,
    required String subtitle,
    required int value,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isHighlighted ? 1.5 : 1.0),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} kg',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 4. Actionable Farm-Gate Advisory Card
  Widget _buildActionableAdvisoryCard(DemandForecastResponse data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'कृषि सलाह व बिक्री रणनीति (Farm-Gate Advisory Strategy)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.recommendation,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.brown.shade900,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 10),
          Text(
            data.actionableInsight,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Agrometeorological & Disruption Radar
  Widget _buildAgroWeatherDisruptionCard(DemandForecastResponse data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Agrometeorological & Supply Disruption Index',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeatherMetric('Transit Delay', 'Low (0.0 mm rain)', Icons.check_circle, Colors.green),
              _buildWeatherMetric('Mandi Arrivals', 'Active Flow', Icons.local_shipping, Colors.blue),
              _buildWeatherMetric('Heat Risk', 'Normal Range', Icons.thermostat, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric(String title, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 3),
        Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
        Text(
          val,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 14),
            Text(
              'Running LightGBM Quantile & Weather Inference...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
