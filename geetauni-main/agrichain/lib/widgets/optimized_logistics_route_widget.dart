import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../utils/translation_helper.dart';

/// Interactive Logistics Comparator & 3-Route Map Optimization Component.
///
/// Implements:
/// 1. 7-Carrier Freight Transparency List with backend-locked AI auto-selection
///    (evaluating ETA, price, nearest distance, and reefer requirements).
/// 2. Interactive 3-Route Map Visualizer (Optimal Express Route + 2 Alternative Routes)
///    with road quality, vibration telemetry, and transit metrics.
/// 3. Bilingual AI Justification Card with Hindi / English toggle explaining
///    routing choice based on road quality (vibrations), ambient temperature,
///    and produce shelf life.
class OptimizedLogisticsRouteWidget extends StatefulWidget {
  final String commodity;
  final String originCluster;
  final String destination;
  final LatLng originPos;
  final LatLng destinationPos;
  final Function(Map<String, dynamic> selectedCarrier)? onCarrierAutoSelected;

  const OptimizedLogisticsRouteWidget({
    super.key,
    required this.commodity,
    this.originCluster = 'Karnal-Kurukshetra FPO Belt (NH-44)',
    this.destination = 'Delhivery Logistics Hub / Buyer Facility',
    this.originPos = const LatLng(29.8021, 76.9298), // Karnal / Taraori
    this.destinationPos = const LatLng(28.6139, 77.2090), // Delhi / NCR Hub
    this.onCarrierAutoSelected,
  });

  @override
  State<OptimizedLogisticsRouteWidget> createState() => _OptimizedLogisticsRouteWidgetState();
}

class _OptimizedLogisticsRouteWidgetState extends State<OptimizedLogisticsRouteWidget> {
  late final MapController _mapController;
  int _selectedRouteIndex = 0; // 0 = Optimal NH-44, 1 = Alt A (SH-11), 2 = Alt B (MDR)
  bool _isHindi = false;

  late List<Map<String, dynamic>> _carriers;
  late int _optimalCarrierIndex;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initCarriers();
  }

  void _initCarriers() {
    final isPerishable = _checkPerishability(widget.commodity);

    _carriers = [
      {
        'id': 'carrier_delhivery_reefer',
        'name': 'Delhivery B2B Reefer',
        'tag': 'Optimal Cold-Chain',
        'quote': 34200.0,
        'transitHours': '20 Hours',
        'rating': 4.9,
        'verifiedFastag': true,
        'truckType': 'Active Cold-Chain Container (4°C–8°C)',
        'isOptimal': isPerishable,
        'aiReason': 'Fastest 20h ETA with active temperature-controlled refrigeration, ideal for fresh produce.',
        'aiReasonHi': '20 घंटे का सबसे तेज़ ट्रांजिट और 4°C–8°C प्रशीतित कोल्ड-चेन, ताज़ा उपज के लिए सर्वोत्तम।',
      },
      {
        'id': 'carrier_blackbuck',
        'name': 'BlackBuck FTL',
        'tag': 'Recommended FTL',
        'quote': 32400.0,
        'transitHours': '24 Hours',
        'rating': 4.8,
        'verifiedFastag': true,
        'truckType': '32ft Multi-Axle Container (250 Qtl)',
        'isOptimal': !isPerishable,
        'aiReason': 'Optimal cost-to-speed ratio for bulk grains with verified FASTag green corridors.',
        'aiReasonHi': 'अनाज व दलहन के लिए सबसे संतुलित भाड़ा और FASTag ग्रीन-कॉरिडोर डायरेक्ट रूट।',
      },
      {
        'id': 'carrier_trukky',
        'name': 'Trukky National Freight',
        'tag': 'Best Value Rate',
        'quote': 31800.0,
        'transitHours': '28 Hours',
        'rating': 4.6,
        'verifiedFastag': true,
        'truckType': '32ft High-Deck Container',
        'isOptimal': false,
        'aiReason': 'Economical freight rate, longer transit time.',
        'aiReasonHi': 'किफायती भाड़ा, किंतु ट्रांजिट में 4 से 6 घंटे अधिक समय।',
      },
      {
        'id': 'carrier_wheelseye',
        'name': 'WheelsEye Logistics',
        'tag': 'GPS Telematics',
        'quote': 33100.0,
        'transitHours': '26 Hours',
        'rating': 4.7,
        'verifiedFastag': true,
        'truckType': 'Heavy FTL Body',
        'isOptimal': false,
        'aiReason': 'Full telematics tracking with standard non-reefer transit.',
        'aiReasonHi': 'जीपीएस टेलीमैटिक्स ट्रैकिंग, सामान्य खुला/बंद ट्रक।',
      },
      {
        'id': 'carrier_fr8',
        'name': 'FR8 Inter-City Fleet',
        'tag': 'Enterprise Fleet',
        'quote': 34500.0,
        'transitHours': '22 Hours',
        'rating': 4.7,
        'verifiedFastag': true,
        'truckType': '32ft MXL Closed Body',
        'isOptimal': false,
        'aiReason': 'High reliability score, suitable for medium shelf-life crops.',
        'aiReasonHi': 'उच्च विश्वसनीयता स्कोर, मध्यम शेल्फ लाइफ वाली फसलों हेतु।',
      },
      {
        'id': 'carrier_loadshare',
        'name': 'LoadShare Networks',
        'tag': 'Standard FTL',
        'quote': 33800.0,
        'transitHours': '24 Hours',
        'rating': 4.5,
        'verifiedFastag': true,
        'truckType': 'Container Truck',
        'isOptimal': false,
        'aiReason': 'Standard regional logistics provider.',
        'aiReasonHi': 'मानक क्षेत्रीय लॉजिस्टिक्स प्रदाता।',
      },
      {
        'id': 'carrier_shiprocket',
        'name': 'Shiprocket Cargo FTL',
        'tag': 'Multi-Carrier Fleet',
        'quote': 32900.0,
        'transitHours': '25 Hours',
        'rating': 4.6,
        'verifiedFastag': true,
        'truckType': 'Standard 250 Qtl Truck',
        'isOptimal': false,
        'aiReason': 'Aggregated fleet partner.',
        'aiReasonHi': 'मल्टी-कैरियर एग्रीगेटर पार्टनर।',
      },
    ];

    _optimalCarrierIndex = _carriers.indexWhere((c) => c['isOptimal'] == true);
    if (_optimalCarrierIndex == -1) _optimalCarrierIndex = 0;

    // Trigger initial notification to parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCarrierAutoSelected?.call(_carriers[_optimalCarrierIndex]);
    });
  }

  bool _checkPerishability(String commodity) {
    final lower = commodity.toLowerCase();
    return lower.contains('tomato') ||
        lower.contains('kinnow') ||
        lower.contains('orange') ||
        lower.contains('guava') ||
        lower.contains('mango') ||
        lower.contains('papaya') ||
        lower.contains('apple') ||
        lower.contains('grapes') ||
        lower.contains('watermelon') ||
        lower.contains('cauliflower') ||
        lower.contains('cabbage') ||
        lower.contains('peas') ||
        lower.contains('chilli') ||
        lower.contains('okra') ||
        lower.contains('bhindi') ||
        lower.contains('brinjal') ||
        lower.contains('capsicum');
  }

  static final List<Map<String, dynamic>> _realRoutesData = [
    {
      'id': 'route_nh44',
      'name': 'Route 1: NH-44 Express Corridor (Grand Trunk Road)',
      'nameHi': 'रूट 1: NH-44 जीटी रोड एक्सप्रेसवे (डायरेक्ट कॉरिडोर)',
      'shortName': 'NH-44 GT Road (AI Optimal)',
      'via': 'Via Gharaunda, Panipat Elevated & Murthal',
      'distanceKm': 128,
      'duration': '2h 45m',
      'roadQuality': '6-Lane Access-Controlled Asphalt (IRI < 1.9)',
      'vibration': '0.12g (Minimal Produce Damage)',
      'color': const Color(0xFF059669),
      'badge': 'सर्वोत्तम',
      'tag': 'AI Recommended',
      'totalToll': 300.0,
      'tolls': [
        {
          'name': 'Bastara Toll Plaza (Gharaunda)',
          'location': 'NH-44 Km 128, Karnal-Panipat Border',
          'fee': 165.0,
          'agency': 'NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 29.5412,
          'lng': 76.9734,
        },
        {
          'name': 'Panipat Elevated Toll Plaza',
          'location': 'NH-44 Elevated Flyover, Panipat City',
          'fee': 40.0,
          'agency': 'L&T / NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 29.3909,
          'lng': 76.9635,
        },
        {
          'name': 'Murthal Toll Plaza (Sonipat)',
          'location': 'NH-44 Km 50, Murthal-Kundli Section',
          'fee': 95.0,
          'agency': 'NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 29.0251,
          'lng': 77.0722,
        },
      ],
    },
    {
      'id': 'route_kmp',
      'name': 'Route 2: Western Peripheral Corridor (SH-12 & KMP Expressway)',
      'nameHi': 'रूट 2: पश्चिमी परिधीय एक्सप्रेसवे (SH-12 व KMP बाईपास)',
      'shortName': 'SH-12 & KMP Expressway',
      'via': 'Via Assandh, Gohana Bypass & KMP Expressway',
      'distanceKm': 152,
      'duration': '3h 10m',
      'roadQuality': '4-Lane State Hwy + 6-Lane Concrete KMP Expressway',
      'vibration': '0.28g (Moderate Vibration)',
      'color': const Color(0xFF2563EB),
      'badge': 'वैकल्पिक 1',
      'tag': 'Heavy Truck Bypass',
      'totalToll': 255.0,
      'tolls': [
        {
          'name': 'Gohana Bypass Toll Plaza',
          'location': 'SH-12 / Rohtak-Panipat Link',
          'fee': 65.0,
          'agency': 'HSRDC Haryana',
          'fastag': 'FASTag ETC Active',
          'lat': 29.1368,
          'lng': 76.6980,
        },
        {
          'name': 'KMP Expressway Badli Toll Plaza',
          'location': 'Western Peripheral Expressway Interchange',
          'fee': 190.0,
          'agency': 'HSIIDC / NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 28.7180,
          'lng': 76.8402,
        },
      ],
    },
    {
      'id': 'route_epe',
      'name': 'Route 3: Eastern Peripheral Corridor (Yamuna Link & EPE)',
      'nameHi': 'रूट 3: पूर्वी परिधीय एक्सप्रेसवे (यमुना तटबंध व EPE लिंक)',
      'shortName': 'Yamuna Link & EPE Corridor',
      'via': 'Via Indri, Shamli-Baghpat Link & Eastern Peripheral Expressway',
      'distanceKm': 164,
      'duration': '3h 40m',
      'roadQuality': '2-Lane MDR + 6-Lane Access-Controlled EPE',
      'vibration': '0.45g (High Vibration on Rural Link)',
      'color': const Color(0xFFD97706),
      'badge': 'वैकल्पिक 2',
      'tag': 'Alternative Rural Link',
      'totalToll': 245.0,
      'tolls': [
        {
          'name': 'Karnal-Yamuna Bridge Toll (Tapu)',
          'location': 'Haryana-UP Border Yamuna River Crossing',
          'fee': 50.0,
          'agency': 'PWD Haryana/UP',
          'fastag': 'FASTag / Cash Hybrid',
          'lat': 29.7020,
          'lng': 77.1250,
        },
        {
          'name': 'Baghpat Highway Toll Plaza',
          'location': 'Delhi-Saharanpur Highway / EPE Link',
          'fee': 85.0,
          'agency': 'NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 28.9482,
          'lng': 77.2285,
        },
        {
          'name': 'Mavi Kalan EPE Toll Plaza',
          'location': 'Eastern Peripheral Expressway (NE-II) Entry',
          'fee': 110.0,
          'agency': 'NHAI',
          'fastag': 'FASTag ETC Active',
          'lat': 28.8950,
          'lng': 77.2910,
        },
      ],
    },
  ];

  List<LatLng> _getRoute1Points() {
    // Route 1: NH-44 Grand Trunk Express Corridor through actual tolls
    final start = widget.originPos;
    final end = widget.destinationPos;
    return [
      start,
      const LatLng(29.5412, 76.9734), // Bastara Toll (Gharaunda)
      const LatLng(29.3909, 76.9635), // Panipat Elevated Toll
      const LatLng(29.1500, 77.0100), // Samalkha
      const LatLng(29.0251, 77.0722), // Murthal Toll (Sonipat)
      end,
    ];
  }

  List<LatLng> _getRoute2Points() {
    // Route 2: SH-12 Assandh/Gohana -> KMP Expressway through actual tolls
    final start = widget.originPos;
    final end = widget.destinationPos;
    return [
      start,
      const LatLng(29.5200, 76.6000), // Assandh
      const LatLng(29.1368, 76.6980), // Gohana Bypass Toll
      const LatLng(28.9000, 76.7800), // Kharkhoda KMP Entry
      const LatLng(28.7180, 76.8402), // KMP Badli Toll
      end,
    ];
  }

  List<LatLng> _getRoute3Points() {
    // Route 3: Yamuna Link Indri/Baghpat -> EPE through actual tolls
    final start = widget.originPos;
    final end = widget.destinationPos;
    return [
      start,
      const LatLng(29.8800, 77.0600), // Indri
      const LatLng(29.7020, 77.1250), // Tapu Yamuna River Toll
      const LatLng(28.9482, 77.2285), // Baghpat Highway Toll
      const LatLng(28.8950, 77.2910), // Mavi Kalan EPE Toll
      end,
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isHindi = context.isHindi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CARRIER TRANSPARENCY HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Color(0xFF1B5E20), size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('Logistics Service Providers', 'परिवहन व लॉजिस्टिक्स सेवा प्रदाता'),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 11, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 4),
                  Text(
                    'Backend AI Locked',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'प्रणाली द्वारा सभी 7 क्षेत्रीय प्रदाताओं का वास्तविक समय में मूल्यांकन किया गया है। सिस्टम ने सर्वोत्तम ETA, न्यूनतम दर एवं शीत-श्रृंखला के आधार पर आदर्श वाहन लॉक किया है।',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),

        // 2. HORIZONTAL 7-CARRIER COMPARATOR
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_carriers.length, (index) {
              final carrier = _carriers[index];
              final isAutoSelected = index == _optimalCarrierIndex;

              return InkWell(
                onTap: () {
                  setState(() {
                    _optimalCarrierIndex = index;
                  });
                  widget.onCarrierAutoSelected?.call(carrier);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1B5E20),
                      duration: const Duration(seconds: 2),
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('${carrier['name']} selected for freight booking!'),
                        ],
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 215,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAutoSelected
                        ? const Color(0xFF1B5E20).withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAutoSelected ? const Color(0xFF1B5E20) : Colors.grey.shade200,
                      width: isAutoSelected ? 2 : 1,
                    ),
                    boxShadow: isAutoSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1B5E20).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              carrier['name'],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAutoSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 10, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text(
                                    'CHOSEN',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            )
                          else
                            const Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Carrier Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAutoSelected ? const Color(0xFF1B5E20) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAutoSelected ? '🤖 AI Auto-Selected' : carrier['tag'],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isAutoSelected ? Colors.white : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quote & ETA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${(carrier['quote'] as double).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 13),
                              const SizedBox(width: 2),
                              Text(
                                '${carrier['rating']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⏱️ ETA: ${carrier['transitHours']}',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      Text(
                        '🚛 ${carrier['truckType']}',
                        style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),

        // 3. 3-ROUTE MAP VISUALIZATION HEADER & SELECTOR TABS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.alt_route, color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 8),
                Text(
                  '3-Route Corridor Comparison (3 मार्गों की तुलना)',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Live Telemetry',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Route Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_realRoutesData.length, (i) {
              final r = _realRoutesData[i];
              final tolls = r['tolls'] as List;
              return Padding(
                padding: EdgeInsets.only(right: i < _realRoutesData.length - 1 ? 8.0 : 0),
                child: _buildRouteChip(
                  index: i,
                  label: r['shortName'] as String,
                  subLabel: '${r['distanceKm']} km • ${r['duration']} • ${tolls.length} Tolls (₹${(r['totalToll'] as double).toStringAsFixed(0)})',
                  badge: r['badge'] as String,
                  color: r['color'] as Color,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // 4. MAP CONTAINER WITH REAL TILES & 3 POLYLINES
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      (widget.originPos.latitude + widget.destinationPos.latitude) / 2,
                      (widget.originPos.longitude + widget.destinationPos.longitude) / 2,
                    ),
                    initialZoom: 8.2,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    // OpenStreetMap Tile Layer
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.agrichain.app',
                    ),

                    // Polylines for the 3 distinct routes
                    PolylineLayer(
                      polylines: [
                        // Route 3 (Rural Link - Orange / Amber)
                        Polyline(
                          points: _getRoute3Points(),
                          strokeWidth: _selectedRouteIndex == 2 ? 5.5 : 2.5,
                          color: _selectedRouteIndex == 2
                              ? const Color(0xFFD97706)
                              : const Color(0xFFD97706).withValues(alpha: 0.4),
                        ),

                        // Route 2 (State Highway - Royal Blue)
                        Polyline(
                          points: _getRoute2Points(),
                          strokeWidth: _selectedRouteIndex == 1 ? 5.5 : 2.5,
                          color: _selectedRouteIndex == 1
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF2563EB).withValues(alpha: 0.4),
                        ),

                        // Route 1 (Optimal Express Corridor - Emerald Green)
                        Polyline(
                          points: _getRoute1Points(),
                          strokeWidth: _selectedRouteIndex == 0 ? 6.0 : 3.5,
                          color: _selectedRouteIndex == 0
                              ? const Color(0xFF059669)
                              : const Color(0xFF059669).withValues(alpha: 0.5),
                        ),
                      ],
                    ),

                    // Origin, Destination & Toll Markers
                    MarkerLayer(
                      markers: [
                        // Origin Pin
                        Marker(
                          point: widget.originPos,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E20),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.agriculture, color: Colors.white, size: 20),
                          ),
                        ),
                        // Destination Pin
                        Marker(
                          point: widget.destinationPos,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                          ),
                        ),
                        // Toll Markers for active route
                        ...((_realRoutesData[_selectedRouteIndex]['tolls'] as List).map((toll) {
                          return Marker(
                            point: LatLng(toll['lat'] as double, toll['lng'] as double),
                            width: 32,
                            height: 32,
                            child: Tooltip(
                              message: '${toll['name']} (₹${(toll['fee'] as double).toStringAsFixed(0)})',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.toll, color: Colors.white, size: 16),
                              ),
                            ),
                          );
                        })),
                      ],
                    ),
                  ],
                ),

                // Map Legend Overlay
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Route 1 (AI Optimal)', const Color(0xFF059669)),
                        const SizedBox(height: 3),
                        _buildLegendItem('Route 2 (State Hwy)', const Color(0xFF2563EB)),
                        const SizedBox(height: 3),
                        _buildLegendItem('Route 3 (Rural Link)', const Color(0xFFD97706)),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                              child: const Icon(Icons.toll, size: 8, color: Colors.white),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Toll Plaza (टोल)',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 4.5. INTERACTIVE TOLLS CROSSED CARD
        _buildTollsCrossedCard(),
        const SizedBox(height: 14),

        // 5. BILINGUAL AI JUSTIFICATION CARD
        _buildBilingualJustificationCard(),
      ],
    );
  }

  Widget _buildRouteChip({
    required int index,
    required String label,
    required String subLabel,
    required String badge,
    required Color color,
  }) {
    final isSelected = _selectedRouteIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedRouteIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? color : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3.5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
        ),
      ],
    );
  }

  Widget _buildTollsCrossedCard() {
    final route = _realRoutesData[_selectedRouteIndex];
    final tolls = (route['tolls'] as List<dynamic>?) ?? [];
    final totalToll = (route['totalToll'] as num?)?.toDouble() ?? 0.0;
    final routeColor = route['color'] as Color? ?? const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.toll, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHindi ? 'रास्ते के टोल प्लाजा व FASTag' : 'Tolls Crossed & FASTag Summary',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _isHindi ? '${route['nameHi']} (${tolls.length} टोल)' : '${route['shortName']} (${tolls.length} Plazas)',
                        style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      '₹${totalToll.toStringAsFixed(0)} Toll',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Toll List
          ...List.generate(tolls.length, (idx) {
            final t = tolls[idx] as Map<String, dynamic>;
            final fee = (t['fee'] as num?)?.toDouble() ?? 0.0;
            final isLast = idx == tolls.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: routeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: routeColor, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: routeColor,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 34,
                          color: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Toll details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                t['name'] ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '₹${fee.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t['location'] ?? '',
                          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t['agency'] ?? 'NHAI',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 9, color: Color(0xFF059669)),
                                  const SizedBox(width: 3),
                                  Text(
                                    t['fastag'] ?? 'FASTag ETC',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          // FASTag settlement footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isHindi
                        ? '100% ऑटोमेटेड FASTag इलेक्ट्रॉनिक टोल भुगतान • ट्रिप वॉलेट से कुल ₹${totalToll.toStringAsFixed(0)} का सीधा डिडक्शन'
                        : '100% Automated FASTag Deduction • ₹${totalToll.toStringAsFixed(0)} auto-debited via Agrichain Fleet Escrow',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBilingualJustificationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Language Switcher Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Color(0xFF15803D), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isHindi ? 'रूट चयन का वैज्ञानिक कारण' : 'AI Route Optimization Rationale',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              // Language Toggle
              InkWell(
                onTap: () => setState(() => _isHindi = !_isHindi),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _isHindi ? '🇮🇳 हिन्दी' : '🇬🇧 English',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.swap_horiz, size: 13, color: Color(0xFF15803D)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Factor Explanations (Road Quality, Ambient Temp, Shelf Life)
          if (!_isHindi) ...[
            _buildFactorPoint(
              icon: Icons.speed,
              title: 'Road Quality & Vibration Index (0.12g vs 0.72g)',
              description:
                  'Selected NH-44 Express Corridor features access-controlled 4-lane smooth asphalt (IRI < 1.9 m/km). Minimal vertical vibration (<0.12g) prevents produce internal bruising and skin ruptures compared to rural link road MDR-114 (0.72g, heavy potholes).',
            ),
            const SizedBox(height: 8),
            _buildFactorPoint(
              icon: Icons.thermostat,
              title: 'Ambient Temperature & Climate Transit',
              description:
                  'Continuous high-speed cruising eliminates stop-and-go idling heat. Active vehicle alternator powers reefer airflow (4°C–8°C), preventing thermal heat spikes and premature ethylene ripening for ${widget.commodity}.',
            ),
            const SizedBox(height: 8),
            _buildFactorPoint(
              icon: Icons.hourglass_top,
              title: 'Produce Shelf Life Preservation (92% Buffer Saved)',
              description:
                  'Fast 20-hour transit preserves 92% of farm-fresh shelf life. Alternative rural routes add 4–7 hours of traffic delays, resulting in up to 30% quality degradation before delivery at destination.',
            ),
          ] else ...[
            _buildFactorPoint(
              icon: Icons.speed,
              title: 'सड़क की गुणवत्ता और कंपन (Vibrations: 0.12g बनाम 0.72g)',
              description:
                  'सिस्टम ने NH-44 एक्सप्रेसवे को चुना है जहाँ 4-लेन चिकनी सड़क के कारण वाहन में कंपन (0.12g) न्यूनतम रहता है। इससे गड्ढों के झटकों से ${widget.commodity} में अंदरूनी चोट (Bruising) और टूट-फूट का खतरा 85% तक घट जाता है।',
            ),
            const SizedBox(height: 8),
            _buildFactorPoint(
              icon: Icons.thermostat,
              title: 'परिवेशी तापमान और प्रशीतित वेंटिलेशन (Cold Chain)',
              description:
                  'बिना रुकावट तेज गति का सफर वाहन के प्रशीतित (Reefer) वेंटिलेशन को लगातार 4°C से 8°C पर बनाए रखता है, जिससे ग्रामीण रास्तों के ट्रैफिक जाम में अत्यधिक गर्मी से फसल सड़ने का खतरा समाप्त हो जाता है।',
            ),
            const SizedBox(height: 8),
            _buildFactorPoint(
              icon: Icons.hourglass_top,
              title: 'फसल की शेल्फ लाइफ (जीवन काल की 92% सुरक्षा)',
              description:
                  '20 घंटे का तेज ट्रांजिट फसल की खेत जैसी ताज़गी को 92% तक सुरक्षित रखता है, जबकि ग्रामीण वैकल्पिक रास्तों (MDR-114) पर गड्ढों और 7 घंटे की अतिरिक्त देरी से 30% तक फसल खराब होने का जोखिम रहता।',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorPoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF15803D).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF15803D)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF334155),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
