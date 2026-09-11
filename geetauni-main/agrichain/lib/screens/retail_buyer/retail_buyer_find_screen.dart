import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../utils/crop_image_helper.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'retail_checkout_screen.dart';

class RetailBuyerFindScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const RetailBuyerFindScreen({super.key, this.onNavigateTab});

  @override
  State<RetailBuyerFindScreen> createState() => _RetailBuyerFindScreenState();
}

class _RetailBuyerFindScreenState extends State<RetailBuyerFindScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final MapController _findMapController = MapController();

  bool _isMapView = false;
  String _searchQuery = '';
  String _selectedCrop = 'All';
  String _selectedGrade = 'All';
  double _maxDistanceKm = 50.0;
  double _maxPrice = 10000.0;
  String _selectedDelivery = 'All';

  final Set<String> _savedCropIds = {};

  final List<String> _cropFilterOptions = [
    'All',
    'Wheat',
    'Rice',
    'Mustard',
    'Maize',
    'Chana',
    'Cotton',
    'Soybean',
    'Potato',
    'Tomato',
    'Onion',
    'Bajra',
    'Vegetables',
  ];

  static final List<Map<String, String>> _cropCatalogDetailed = [
    {'key': 'All', 'label': 'All Crops (सभी फसलें)', 'hindi': 'सभी', 'icon': '🌾'},
    {'key': 'Wheat', 'label': 'Wheat (गेहूं)', 'hindi': 'गेहूं', 'icon': '🌾'},
    {'key': 'Rice', 'label': 'Rice / Basmati (चावल)', 'hindi': 'चावल', 'icon': '🍚'},
    {'key': 'Mustard', 'label': 'Mustard / Sarson (सरसों)', 'hindi': 'सरसों', 'icon': '🟡'},
    {'key': 'Maize', 'label': 'Maize / Makka (मक्का)', 'hindi': 'मक्का', 'icon': '🌽'},
    {'key': 'Chana', 'label': 'Gram / Chana (चना)', 'hindi': 'चना', 'icon': '🟤'},
    {'key': 'Cotton', 'label': 'Cotton (कपास)', 'hindi': 'कपास', 'icon': '☁️'},
    {'key': 'Soybean', 'label': 'Soybean (सोयाबीन)', 'hindi': 'सोयाबीन', 'icon': '🌱'},
    {'key': 'Potato', 'label': 'Potato (आलू)', 'hindi': 'आलू', 'icon': '🥔'},
    {'key': 'Tomato', 'label': 'Tomato (टमाटर)', 'hindi': 'टमाटर', 'icon': '🍅'},
    {'key': 'Onion', 'label': 'Onion (प्याज़)', 'hindi': 'प्याज़', 'icon': '🧅'},
    {'key': 'Bajra', 'label': 'Pearl Millet / Bajra (बाजरा)', 'hindi': 'बाजरा', 'icon': '🥣'},
    {'key': 'Vegetables', 'label': 'Fresh Vegetables (हरी सब्जियां)', 'hindi': 'सब्जियां', 'icon': '🥗'},
  ];

  final List<String> _gradeOptions = [
    'All',
    'Grade A',
    'Grade 1',
    'Organic',
    'Standard',
  ];

  final List<String> _deliveryOptions = [
    'All',
    'Farmer Delivery',
    'AgriChain Express',
    'Self Pickup',
  ];

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().trim();
    final direct = double.tryParse(str);
    if (direct != null) return direct;
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(str);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Find Local Produce', 'स्थानीय फसलें खोजें'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Text(
              context.tr('Discover & Buy Directly from Farmers', 'सीधे किसानों से खोजें और खरीदें'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Center(child: LanguageSwitcherPill(isDark: false)),
          ),
          // View Switcher (List / Map)
          IconButton(
            icon: Icon(
              _isMapView ? Icons.view_list : Icons.map_outlined,
              color: AppTheme.primaryGreen,
            ),
            tooltip: _isMapView ? context.tr('Switch to List View', 'सूची देखें') : context.tr('Switch to Map View', 'मानचित्र देखें'),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar & Filter Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search crop, variety or farmer name...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                            icon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
                            border: InputBorder.none,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _showFiltersBottomSheet,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_selectedGrade != 'All' || _maxDistanceKm < 50 || _selectedDelivery != 'All')
                              ? AppTheme.primaryGreen
                              : const Color(0xFFF1F5F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.tune,
                          size: 22,
                          color: (_selectedGrade != 'All' || _maxDistanceKm < 50 || _selectedDelivery != 'All')
                              ? Colors.white
                              : AppTheme.darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Dedicated Crop Selection Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _cropFilterOptions.contains(_selectedCrop) ? _selectedCrop : 'All',
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            onChanged: (newVal) {
                              if (newVal != null) {
                                setState(() {
                                  _selectedCrop = newVal;
                                });
                              }
                            },
                            items: _cropCatalogDetailed.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['key'],
                                child: Row(
                                  children: [
                                    Text(c['icon'] ?? '🌾', style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c['label'] ?? c['key']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Horizontal Crop Quick Filter Chips
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cropFilterOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final crop = _cropFilterOptions[index];
                      final isSelected = _selectedCrop == crop;
                      return ChoiceChip(
                        label: Text(crop),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            _selectedCrop = crop;
                          });
                        },
                        selectedColor: AppTheme.primaryGreen,
                        backgroundColor: const Color(0xFFF8FAF7),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected ? Colors.white : AppTheme.darkGrey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 11.5,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Filters Indicator
          if (_selectedGrade != 'All' || _maxDistanceKm < 50 || _selectedDelivery != 'All')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 16, color: AppTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Filtered: ${_selectedGrade != 'All' ? '$_selectedGrade • ' : ''}${_maxDistanceKm < 50 ? '< ${_maxDistanceKm.toInt()} km • ' : ''}${_selectedDelivery != 'All' ? _selectedDelivery : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedGrade = 'All';
                        _maxDistanceKm = 50.0;
                        _selectedDelivery = 'All';
                        _maxPrice = 10000.0;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Farmer Produce Listings (List or Real Map View)
          Expanded(
            child: _buildFarmerListings(appState),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerListings(AppState appState) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamAllAvailableCrops(),
      builder: (context, snapshot) {
        final streamedCrops = snapshot.data ?? [];
        final localCrops = appState.crops.map((c) => c.toFirestore()).toList();
        final Set<String> seenIds = {};
        final List<Map<String, dynamic>> allListings = [];

        for (final c in [...streamedCrops, ...localCrops]) {
          final id = c['id']?.toString() ?? c['name']?.toString() ?? '';
          if (id.isEmpty || seenIds.add(id)) {
            final cropName = c['name'] ?? c['cropName'] ?? 'Crop';
            final variety = c['variety'] ?? 'Grade 1 Quality';
            final grade = c['qualityGrade'] ?? 'Grade A';
            double price = _toDouble(c['price']);
            if (price > 300) {
              price = (price / 100).roundToDouble();
            }
            final quantity = _toDouble(c['quantity']);
            const unit = 'kg';
            final farmerName = c['farmerName'] ?? 'Farmer';
            final location = c['location'] ?? 'Karnal Village, Haryana';
            final imageUrl = (c['imageUrl'] != null && c['imageUrl'].toString().isNotEmpty)
                ? c['imageUrl'].toString()
                : 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=500';

            allListings.add({
              'id': id,
              'cropName': cropName,
              'variety': variety,
              'grade': grade,
              'price': price,
              'quantity': quantity,
              'unit': unit,
              'farmerName': farmerName,
              'distanceKm': (c['distanceKm'] as num?)?.toDouble() ?? 6.5,
              'distance': c['distance'] ?? '6.5 km away',
              'location': location,
              'lat': (c['lat'] as num?)?.toDouble() ?? 29.6957,
              'lng': (c['lng'] as num?)?.toDouble() ?? 76.9805,
              'delivery': c['delivery'] ?? 'Farmer Delivery',
              'rating': (c['rating'] as num?)?.toDouble() ?? 4.8,
              'reviews': c['reviews'] ?? 24,
              'isOrganic': c['isOrganic'] ?? true,
              'image': imageUrl,
              'description': c['description'] ?? 'Pure verified produce harvested directly from farm.',
            });
          }
        }

    // Filter listings based on user selections
    final filtered = allListings.where((item) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesCrop = (item['cropName'] as String).toLowerCase().contains(q);
        final matchesVariety = (item['variety'] as String).toLowerCase().contains(q);
        final matchesFarmer = (item['farmerName'] as String).toLowerCase().contains(q);
        if (!matchesCrop && !matchesVariety && !matchesFarmer) return false;
      }

      if (_selectedCrop != 'All') {
        final cropName = (item['cropName'] as String).toLowerCase();
        if (!cropName.contains(_selectedCrop.toLowerCase())) return false;
      }

      if (_selectedGrade != 'All') {
        if (item['grade'] != _selectedGrade) return false;
      }

      if ((item['distanceKm'] as double) > _maxDistanceKm) return false;
      if ((item['price'] as double) > _maxPrice) return false;

      if (_selectedDelivery != 'All') {
        if (item['delivery'] != _selectedDelivery) return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No crops found matching your filters',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting the distance slider or removing filters',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Return Real OpenStreetMap View if toggled
    if (_isMapView) {
      return _buildRealOsmMapView(filtered);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final crop = filtered[index];
        final isSaved = _savedCropIds.contains(crop['id'] as String);

        return Container(
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
          child: InkWell(
            onTap: () => _showCropDetailsModal(context, crop),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Image & Badges
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: CropImageHelper.buildCropImage(
                      crop['image']?.toString(),
                      crop['cropName']?.toString() ?? 'Crop',
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${crop['rating']} (${crop['reviews']})',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: IconButton(
                        icon: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          color: isSaved ? Colors.red : Colors.grey.shade700,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isSaved) {
                              _savedCropIds.remove(crop['id']);
                            } else {
                              _savedCropIds.add(crop['id'] as String);
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSaved
                                    ? 'Removed ${crop['cropName']} from saved wishlist'
                                    : '❤️ Added ${crop['cropName']} to saved wishlist',
                              ),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (crop['isOrganic'] == true)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.eco, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Certified Organic',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content Details
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crop['cropName'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${crop['variety']} • ${crop['grade']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${(crop['price'] as double).toStringAsFixed(0)} / kg',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                            Text(
                              '${_toDouble(crop['quantity']).toStringAsFixed(0)} kg available',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Farmer and Distance Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin, size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${crop['farmerName']} • ${crop['location']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.darkGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            crop['distance'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showCropDetailsModal(context, crop),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.darkGreen,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'View Details',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showBuySheet(context, crop),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Buy Now',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
      },
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Produce',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _selectedGrade = 'All';
                                _maxDistanceKm = 50.0;
                                _selectedDelivery = 'All';
                                _maxPrice = 10000.0;
                              });
                              setState(() {});
                            },
                            child: Text(
                              'Reset All',
                              style: GoogleFonts.inter(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Distance Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Max Distance Radius',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Within ${_maxDistanceKm.toInt()} km',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _maxDistanceKm,
                        min: 5,
                        max: 50,
                        divisions: 9,
                        activeColor: AppTheme.primaryGreen,
                        onChanged: (val) {
                          setSheetState(() => _maxDistanceKm = val);
                          setState(() => _maxDistanceKm = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Quality Grade
                      Text(
                        'Quality Grade',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _gradeOptions.map((g) {
                          final isSelected = _selectedGrade == g;
                          return ChoiceChip(
                            label: Text(g),
                            selected: isSelected,
                            onSelected: (val) {
                              setSheetState(() => _selectedGrade = g);
                              setState(() => _selectedGrade = g);
                            },
                            selectedColor: AppTheme.primaryGreen,
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? Colors.white : AppTheme.darkGrey,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Delivery Mode
                      Text(
                        'Delivery Option',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _deliveryOptions.map((d) {
                          final isSelected = _selectedDelivery == d;
                          return ChoiceChip(
                            label: Text(d),
                            selected: isSelected,
                            onSelected: (val) {
                              setSheetState(() => _selectedDelivery = d);
                              setState(() => _selectedDelivery = d);
                            },
                            selectedColor: AppTheme.primaryGreen,
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? Colors.white : AppTheme.darkGrey,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCropDetailsModal(BuildContext context, Map<String, dynamic> crop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CropImageHelper.buildCropImage(
                      crop['image']?.toString(),
                      crop['cropName']?.toString() ?? 'Crop',
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        crop['cropName'] as String,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                      ),
                      Text(
                        '₹${(crop['price'] as double).toStringAsFixed(0)} / ${crop['unit']}',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                  Text(
                    '${crop['variety']} • ${crop['grade']}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    crop['description'] as String? ?? '',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.lightGreen,
                        child: Icon(Icons.person, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              crop['farmerName'] as String,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${crop['location']} • ${crop['distance']}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone, color: AppTheme.primaryGreen),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Contacting ${crop['farmerName']}...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showBuySheet(context, crop);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Proceed to Buy (₹${(crop['price'] as double).toStringAsFixed(0)} / ${crop['unit']})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBuySheet(BuildContext context, Map<String, dynamic> crop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetailCheckoutScreen(
          crop: crop,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }


  /// Real OpenStreetMap View for Retail Buyer
  Widget _buildRealOsmMapView(List<Map<String, dynamic>> filteredList) {
    const centerLocation = LatLng(29.6857, 76.9905); // Karnal Central Hub

    return Stack(
      children: [
        FlutterMap(
          mapController: _findMapController,
          options: const MapOptions(
            initialCenter: centerLocation,
            initialZoom: 10.2,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            // OpenStreetMap Real Tile Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.agrichain.app',
            ),

            // Distance Search Radius Circle
            CircleLayer(
              circles: [
                CircleMarker(
                  point: centerLocation,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  borderColor: AppTheme.primaryGreen,
                  borderStrokeWidth: 2.0,
                  useRadiusInMeter: true,
                  radius: _maxDistanceKm * 1000,
                ),
              ],
            ),

            // Buyer & Farmer Pins
            MarkerLayer(
              markers: [
                // Buyer Location Marker
                Marker(
                  point: centerLocation,
                  width: 44,
                  height: 44,
                  child: Tooltip(
                    message: 'Your Delivery Location (Karnal)',
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
                    ),
                  ),
                ),

                // Farmer Pins
                for (final crop in filteredList)
                  Marker(
                    point: LatLng(crop['lat'] as double? ?? 29.6857, crop['lng'] as double? ?? 76.9905),
                    width: 80,
                    height: 64,
                    child: GestureDetector(
                      onTap: () {
                        _showBuySheet(context, crop);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Text(
                              '₹${(crop['price'] as double).toStringAsFixed(0)}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Map Float Banner
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Row(
              children: [
                const Icon(Icons.nature_people, color: AppTheme.primaryGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing ${filteredList.length} verified farms on OpenStreetMap within ${_maxDistanceKm.toInt()} km. Tap pin to buy.',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
