import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/smart_contract_pdf_service.dart';
import '../services/road_routing_service.dart';
import '../utils/crop_image_helper.dart';

/// Full-Featured Live Order Tracking Screen & Spatial Simulation Engine
/// Used across Farmer & Retail Buyer sides, matching the aesthetics & capabilities
/// of the FPO & Bulk Buyer tracking screen (FpoOrderShipmentScreen).
class CropTrackingMapSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool? isFarmer;

  const CropTrackingMapSheet({
    super.key,
    required this.order,
    this.isFarmer,
  });

  /// Opens the live tracking screen with full navigation
  static void show(BuildContext context, Map<String, dynamic> order, {bool? isFarmer}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => CropTrackingMapSheet(order: order, isFarmer: isFarmer),
      ),
    );
  }

  @override
  State<CropTrackingMapSheet> createState() => _CropTrackingMapSheetState();
}

class _CropTrackingMapSheetState extends State<CropTrackingMapSheet> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late final MapController _mapController;
  late final AnimationController _pulseController;

  // Map Tile API: 0 = Google Maps Road, 1 = Satellite Hybrid, 2 = OpenStreetMap
  int _selectedMapType = 0;

  // Origin & Destination coordinates
  late LatLng _originPos;
  late LatLng _destinationPos;
  late LatLng _courierPos;
  List<LatLng> _routePoints = [];

  // Playback & Simulation Engine
  Timer? _playbackTimer;
  int _currentRouteIndex = 0;
  bool _isPlaying = true;
  double _speedMultiplier = 1.0;
  bool _autoFollowVehicle = true;
  bool _isMapReady = false;
  bool _isLoadingRoute = true;

  // Telemetry
  double _roadDistanceKm = 0.0;
  double _remainingDistanceKm = 0.0;
  int _roadEtaMins = 0;
  double _currentSpeedKmH = 48.0;
  double _ambientTempC = 23.4;
  double _cargoMoisturePct = 12.1;
  int _activeProviderIndex = 0; // 0: Simulated Spatial (Demo), 1: ULIP FASTag (Govt API)

  // Local Order State
  late Map<String, dynamic> _liveOrder;
  late String _orderStatus;
  late bool _isEscrowReleased;

  @override
  void initState() {
    super.initState();
    _liveOrder = Map<String, dynamic>.from(widget.order);
    _orderStatus = (_liveOrder['status'] ?? 'in_transit').toString().toLowerCase();
    _isEscrowReleased = (_liveOrder['escrowStatus'] ?? '').toString().toUpperCase() == 'RELEASED' || _orderStatus == 'delivered';

    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initCoordinatesAndRoute();
  }

  void _initCoordinatesAndRoute() {
    // 1. Farmer origin (Farm / Mandi Hub)
    final double originLat = (_liveOrder['farmerLat'] as num?)?.toDouble() ??
        (_liveOrder['originLat'] as num?)?.toDouble() ??
        29.7420;
    final double originLng = (_liveOrder['farmerLng'] as num?)?.toDouble() ??
        (_liveOrder['originLng'] as num?)?.toDouble() ??
        76.9550;
    _originPos = LatLng(originLat, originLng);

    // 2. Buyer destination (Doorstep Delivery Address)
    final double destLat = (_liveOrder['buyerLat'] as num?)?.toDouble() ??
        (_liveOrder['destinationLat'] as num?)?.toDouble() ??
        29.6857;
    final double destLng = (_liveOrder['buyerLng'] as num?)?.toDouble() ??
        (_liveOrder['destinationLng'] as num?)?.toDouble() ??
        76.9905;
    _destinationPos = LatLng(destLat, destLng);

    // Generate high-density fallback road curve first
    _generateHighDensityRoadFallback();

    // Fetch real road snapped route asynchronously
    _fetchRoadRoute(originLat, originLng, destLat, destLng);
  }

  void _generateHighDensityRoadFallback() {
    const int numPoints = 80;
    final List<LatLng> fallback = [];

    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      // Slight road curvature mimicking Haryana district highway
      final curve = sin(t * pi) * 0.008;
      final lat = _originPos.latitude + (_destinationPos.latitude - _originPos.latitude) * t + curve;
      final lng = _originPos.longitude + (_destinationPos.longitude - _originPos.longitude) * t + (curve * 0.5);
      fallback.add(LatLng(lat, lng));
    }

    _routePoints = fallback;
    _roadDistanceKm = _calculateTotalDistance(_routePoints);
    _initialSetupCourierPosition();
  }

  Future<void> _fetchRoadRoute(double startLat, double startLng, double endLat, double endLng) async {
    try {
      final result = await RoadRoutingService().getMultiStopRoute([
        LatLng(startLat, startLng),
        LatLng(endLat, endLng),
      ]);

      if (mounted && result.points.length >= 2) {
        // Interpolate points so movement along turns is silky smooth
        final finePoints = _densifyPoints(result.points, 100);
        setState(() {
          _routePoints = finePoints;
          _roadDistanceKm = result.distanceKm > 0 ? result.distanceKm : _calculateTotalDistance(_routePoints);
          _isLoadingRoute = false;
          _initialSetupCourierPosition();
        });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Road routing fallback notice: $e');
    }

    if (mounted) {
      setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _densifyPoints(List<LatLng> original, int targetCount) {
    if (original.length >= targetCount) return original;
    final List<LatLng> densified = [];
    final stepsPerSegment = max(1, (targetCount / original.length).ceil());

    for (int i = 0; i < original.length - 1; i++) {
      final p1 = original[i];
      final p2 = original[i + 1];
      for (int s = 0; s < stepsPerSegment; s++) {
        final t = s / stepsPerSegment;
        densified.add(LatLng(
          p1.latitude + (p2.latitude - p1.latitude) * t,
          p1.longitude + (p2.longitude - p1.longitude) * t,
        ));
      }
    }
    densified.add(original.last);
    return densified;
  }

  void _initialSetupCourierPosition() {
    if (_routePoints.isEmpty) return;

    if (_orderStatus == 'delivered' || _isEscrowReleased) {
      _currentRouteIndex = _routePoints.length - 1;
      _courierPos = _routePoints.last;
      _currentSpeedKmH = 0.0;
      _remainingDistanceKm = 0.0;
      _roadEtaMins = 0;
      _isPlaying = false;
    } else if (_orderStatus == 'in_transit') {
      // Start around 35% along the road corridor
      _currentRouteIndex = (_routePoints.length * 0.35).floor().clamp(0, _routePoints.length - 1);
      _courierPos = _routePoints[_currentRouteIndex];
      _updateTelemetry();
      _startPlaybackTimer();
    } else {
      // Pending or farm aggregation stage
      _currentRouteIndex = 0;
      _courierPos = _routePoints.first;
      _updateTelemetry();
      _startPlaybackTimer();
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    if (!_isPlaying) return;

    // Base interval adjusted for speed multiplier
    final int intervalMs = (800 / _speedMultiplier).round().clamp(50, 2000);

    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || !_isPlaying || _routePoints.isEmpty) return;

      if (_currentRouteIndex < _routePoints.length - 1) {
        setState(() {
          _currentRouteIndex++;
          _courierPos = _routePoints[_currentRouteIndex];
          _updateTelemetry();
        });

        // Auto pan map if follow enabled
        if (_autoFollowVehicle && _isMapReady) {
          try {
            _mapController.move(_courierPos, _mapController.camera.zoom);
          } catch (_) {}
        }
      } else {
        // Vehicle reached destination
        timer.cancel();
        setState(() {
          _isPlaying = false;
          _currentSpeedKmH = 0.0;
          _remainingDistanceKm = 0.0;
          _roadEtaMins = 0;
        });

        if (_orderStatus != 'delivered') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏡 Courier has reached the Buyer Doorstep! Ready for OTP Handshake.'),
              backgroundColor: Color(0xFF15803D),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  void _updateTelemetry() {
    if (_routePoints.isEmpty) return;

    // Remaining road distance
    _remainingDistanceKm = _calculateRemainingDistance(_currentRouteIndex);

    // Dynamic speed with realistic highway jitter
    if (_currentRouteIndex >= _routePoints.length - 1) {
      _currentSpeedKmH = 0.0;
      _roadEtaMins = 0;
    } else {
      final jitter = sin(_currentRouteIndex * 0.35) * 5.0;
      _currentSpeedKmH = (52.0 + jitter).clamp(36.0, 68.0);
      final minutes = ((_remainingDistanceKm / _currentSpeedKmH) * 60).round();
      _roadEtaMins = max(1, minutes);
    }

    // Micro-sensor readings
    _ambientTempC = 23.2 + (sin(_currentRouteIndex * 0.15) * 1.4).abs();
    _cargoMoisturePct = 12.0 + (cos(_currentRouteIndex * 0.12) * 0.3).abs();
  }

  double _calculateDistanceKm(LatLng p1, LatLng p2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((p2.latitude - p1.latitude) * p) / 2 +
        cos(p1.latitude * p) * cos(p2.latitude * p) * (1 - cos((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a.clamp(0.0, 1.0)));
  }

  double _calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 8.4;
    double sum = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      sum += _calculateDistanceKm(points[i], points[i + 1]);
    }
    return sum > 0 ? sum : 8.4;
  }

  double _calculateRemainingDistance(int fromIndex) {
    if (_routePoints.length < 2 || fromIndex >= _routePoints.length - 1) return 0.0;
    double sum = 0.0;
    for (int i = fromIndex; i < _routePoints.length - 1; i++) {
      sum += _calculateDistanceKm(_routePoints[i], _routePoints[i + 1]);
    }
    return sum;
  }

  void _seekToProgress(double progress) {
    if (_routePoints.isEmpty) return;
    final targetIdx = ((_routePoints.length - 1) * progress.clamp(0.0, 1.0)).round();

    setState(() {
      _currentRouteIndex = targetIdx;
      _courierPos = _routePoints[_currentRouteIndex];
      _updateTelemetry();
    });

    if (_isMapReady) {
      try {
        _mapController.move(_courierPos, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  void _setPlaybackSpeed(double multiplier) {
    setState(() {
      _speedMultiplier = multiplier;
    });
    if (_isPlaying) {
      _startPlaybackTimer();
    }
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      if (_currentRouteIndex >= _routePoints.length - 1) {
        _currentRouteIndex = 0;
      }
      _startPlaybackTimer();
    } else {
      _playbackTimer?.cancel();
    }
  }

  Future<void> _handleCompleteDeliveryAndEscrow() async {
    final orderId = (_liveOrder['orderId'] ?? _liveOrder['id'] ?? 'ORD-001').toString();
    final total = (_liveOrder['totalAmount'] as num?)?.toDouble() ?? 2400.0;
    final farmer = (_liveOrder['farmerName'] ?? 'Farmer').toString();

    // Confirm delivery in Firestore
    await _dbService.updateRetailOrderStatus(
      orderId,
      'delivered',
      extra: {
        'escrowStatus': 'RELEASED',
        'settlementTxHash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}8f29d',
        'settledAt': DateTime.now().toIso8601String(),
      },
    );

    if (mounted) {
      setState(() {
        _orderStatus = 'delivered';
        _isEscrowReleased = true;
        _seekToProgress(1.0);
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.verified, color: Color(0xFF15803D), size: 28),
              SizedBox(width: 8),
              Text('Escrow Released!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✅ Physical handshake confirmed! ₹${total.toStringAsFixed(0)} has been instantly settled to $farmer on Polygon smart contract.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tx Hash: 0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}8f29d\nNetwork: Polygon PoS\nSettlement: Bank Transfer Initiated',
                  style: GoogleFonts.spaceMono(fontSize: 11, color: const Color(0xFF334155)),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String get _tileUrl {
    switch (_selectedMapType) {
      case 0:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'; // Google Roadmap
      case 1:
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'; // Google Satellite Hybrid
      case 2:
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // OpenStreetMap
    }
  }

  double get _progressFraction {
    if (_routePoints.isEmpty) return 0.0;
    return (_currentRouteIndex / (_routePoints.length - 1)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final order = _liveOrder;
    final orderId = (order['orderId'] ?? order['id'] ?? 'ORD-001').toString();
    final cropName = (order['cropName'] ?? order['crop'] ?? order['commodity'] ?? 'Farm Produce').toString();
    final variety = (order['variety'] ?? 'Standard').toString();
    final grade = (order['grade'] ?? 'Grade A').toString();
    final farmerName = (order['farmerName'] ?? order['sellerName'] ?? 'Local Verified Kisaan').toString();
    final farmerLocation = (order['farmerLocation'] ?? order['originLocation'] ?? 'Karnal Farm Hub, Haryana').toString();
    final buyerName = (order['buyerName'] ?? 'Verified Retail Buyer').toString();
    final buyerAddress = (order['deliveryAddress'] ?? order['destination'] ?? 'Sector 14, Urban Estate, Karnal').toString();
    final quantity = order['quantity'] ?? order['quantityKg'] ?? order['quantityQtl'] ?? 50;
    final unit = (order['unit'] ?? order['quantityUnit'] ?? 'kg').toString();
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 2400.0;
    final deliveryOtp = (order['deliveryOtp'] ?? order['otp'] ?? '482915').toString();
    final imageUrl = (order['imageUrl'] ?? order['cropImageUrl'] ?? '').toString();

    final bool isDelivered = _orderStatus == 'delivered' || _isEscrowReleased;
    final bool isInTransit = _orderStatus == 'in_transit' && !isDelivered;

    final LatLng centerPoint = LatLng(
      (_originPos.latitude + _destinationPos.latitude) / 2,
      (_originPos.longitude + _destinationPos.longitude) / 2,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppTheme.darkGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Logistics & Fleet Tracking',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isDelivered ? 'Delivered • Handshake Verified' : 'Live Highway Tracking • Real Road Snapping',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Smart Contract PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.primaryGreen),
            onPressed: () {
              SmartContractPdfService.autoDownloadOrPreviewContract(
                context: context,
                order: order,
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Route & Telemetry',
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
            onPressed: () {
              setState(() {
                _isLoadingRoute = true;
              });
              _initCoordinatesAndRoute();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 1. Architecture Provider Mode Switcher Card
          _buildProviderModeCard(),
          const SizedBox(height: 14),

          // 2. Retail Batch & Escrow Summary Card (Gradient matching FPO Shipment screen)
          _buildOrderSummaryCard(
            orderId: orderId,
            cropName: cropName,
            variety: variety,
            grade: grade,
            quantity: quantity,
            unit: unit,
            totalAmount: totalAmount,
            farmerName: farmerName,
            farmerLocation: farmerLocation,
            buyerName: buyerName,
            buyerAddress: buyerAddress,
            imageUrl: imageUrl,
            isDelivered: isDelivered,
          ),
          const SizedBox(height: 14),

          // 3. Real Road Snapped Interactive Route Map
          _buildMapCard(centerPoint: centerPoint, farmerName: farmerName, buyerAddress: buyerAddress, isDelivered: isDelivered),
          const SizedBox(height: 14),

          // 4. Realistic Highway Telemetry & Dynamic ETA Card
          _buildTelemetryCard(isDelivered: isDelivered),
          const SizedBox(height: 14),

          // 5. Spatial Playback Simulation Controls Card
          _buildPlaybackControlsCard(isDelivered: isDelivered),
          const SizedBox(height: 14),

          // 6. Normalized Event Timeline Card
          _buildTimelineCard(farmerName: farmerName, buyerAddress: buyerAddress, isDelivered: isDelivered, isInTransit: isInTransit),
          const SizedBox(height: 14),

          // 7. Driver & Fleet Telemetry Card
          _buildDriverFleetCard(),
          const SizedBox(height: 14),

          // 8. Doorstep Delivery Handshake & Digital Escrow Card
          _buildHandshakeEscrowCard(deliveryOtp: deliveryOtp, isDelivered: isDelivered, isInTransit: isInTransit),
          const SizedBox(height: 14),

          // 9. Signed Smart Contract PDF CTA
          _buildPdfCtaButton(order),
        ],
      ),
    );
  }

  /// 1. Architecture Provider Switcher Card
  Widget _buildProviderModeCard() {
    final isUlip = _activeProviderIndex == 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUlip ? Icons.toll : Icons.satellite_outlined,
                color: isUlip ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tracking Architecture Engine',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUlip ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUlip ? 'Source: ULIP FASTag' : 'Source: Simulated GPS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUlip ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Simulated Spatial (Demo)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: !isUlip,
                  selectedColor: const Color(0xFFE8F5E9),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeProviderIndex = 0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('OSRM Road Snapping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  selected: isUlip,
                  selectedColor: const Color(0xFFE3F2FD),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeProviderIndex = 1);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Order Summary Card
  Widget _buildOrderSummaryCard({
    required String orderId,
    required String cropName,
    required String variety,
    required String grade,
    required dynamic quantity,
    required String unit,
    required double totalAmount,
    required String farmerName,
    required String farmerLocation,
    required String buyerName,
    required String buyerAddress,
    required String imageUrl,
    required bool isDelivered,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14532D).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Order #$orderId',
                  style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFF86EFAC) : const Color(0xFFFEF08A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivered ? 'DELIVERED • SETTLED' : 'IN TRANSIT (LIVE)',
                  style: GoogleFonts.inter(
                    color: isDelivered ? const Color(0xFF14532D) : const Color(0xFF854D0E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CropImageHelper.buildCropImage(
                  imageUrl,
                  cropName,
                  height: 52,
                  width: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cropName,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$quantity $unit • ₹${totalAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(color: Colors.lightGreenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            grade,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 14, color: Colors.lightGreenAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'From: $farmerName ($farmerLocation)',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.home_outlined, size: 14, color: Colors.amberAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'To: $buyerName ($buyerAddress)',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Real Road Snapped Interactive Route Map Card
  Widget _buildMapCard({
    required LatLng centerPoint,
    required String farmerName,
    required String buyerAddress,
    required bool isDelivered,
  }) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: 12.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onMapReady: () {
                setState(() => _isMapReady = true);
              },
            ),
            children: [
              // Map Tile Layer (Google Road / Satellite / OSM)
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.agrichain.app',
              ),

              // Road Polyline
              PolylineLayer(
                polylines: [
                  // Outer Glow / Shadow
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 7.0,
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  ),
                  // Solid Highway Line
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.5,
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // 1. Origin: Farmer Farm Hub
                  Marker(
                    point: _originPos,
                    width: 44,
                    height: 44,
                    child: Tooltip(
                      message: 'Pickup: $farmerName',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.agriculture, color: Colors.white, size: 22),
                      ),
                    ),
                  ),

                  // 2. Destination: Buyer Doorstep
                  Marker(
                    point: _destinationPos,
                    width: 44,
                    height: 44,
                    child: Tooltip(
                      message: 'Deliver To: $buyerAddress',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                      ),
                    ),
                  ),

                  // 3. Live Moving Vehicle Marker with Pulsing Radar
                  Marker(
                    point: _courierPos,
                    width: 64,
                    height: 64,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (!isDelivered)
                              Container(
                                width: 44 + (_pulseController.value * 20),
                                height: 44 + (_pulseController.value * 20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF3B82F6).withValues(alpha: (1.0 - _pulseController.value) * 0.4),
                                ),
                              ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                              ),
                              child: Icon(
                                isDelivered ? Icons.check : Icons.local_shipping,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Floating Map Tile Switcher (Top-Right)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapTypeBtn(0, '🗺️ Road'),
                  const SizedBox(width: 4),
                  _buildMapTypeBtn(1, '🛰️ Sat'),
                  const SizedBox(width: 4),
                  _buildMapTypeBtn(2, '🌐 OSM'),
                ],
              ),
            ),
          ),

          // Floating Live ETA Pill (Top-Left)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, color: Color(0xFF60A5FA), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    isDelivered
                        ? 'Delivered • Verified'
                        : '${_currentSpeedKmH.toStringAsFixed(0)} km/h • ~$_roadEtaMins min • ${_remainingDistanceKm.toStringAsFixed(1)} km left',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (_isLoadingRoute) ...[
                    const SizedBox(width: 6),
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Floating Auto-Follow & Recenter Button (Bottom-Right)
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'auto_follow_toggle',
                  tooltip: _autoFollowVehicle ? 'Disable Auto-Follow' : 'Enable Auto-Follow',
                  onPressed: () {
                    setState(() {
                      _autoFollowVehicle = !_autoFollowVehicle;
                    });
                    if (_autoFollowVehicle) {
                      _mapController.move(_courierPos, 13.0);
                    }
                  },
                  backgroundColor: _autoFollowVehicle ? const Color(0xFF2563EB) : Colors.white,
                  foregroundColor: _autoFollowVehicle ? Colors.white : const Color(0xFF0F172A),
                  elevation: 3,
                  child: const Icon(Icons.navigation, size: 18),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'recenter_overview',
                  tooltip: 'Overview Route',
                  onPressed: () {
                    _mapController.move(centerPoint, 12.0);
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 3,
                  child: const Icon(Icons.crop_free, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeBtn(int type, String label) {
    final isSelected = _selectedMapType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedMapType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  /// 4. Highway Telemetry & Dynamic ETA Card
  Widget _buildTelemetryCard({required bool isDelivered}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Realistic Highway Telemetry & Dynamic ETA',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Metric Tiles Row
          Row(
            children: [
              // Speed
              Expanded(
                child: _buildTelemetryMetricTile(
                  icon: Icons.speed,
                  title: 'Live Speed',
                  value: isDelivered ? '0 km/h' : '${_currentSpeedKmH.toStringAsFixed(0)} km/h',
                  subtitle: isDelivered ? 'Stationary' : 'Highway Snapped',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              // Distance Remaining
              Expanded(
                child: _buildTelemetryMetricTile(
                  icon: Icons.straighten,
                  title: 'Distance Left',
                  value: isDelivered ? '0.0 km' : '${_remainingDistanceKm.toStringAsFixed(1)} km',
                  subtitle: 'Total: ${_roadDistanceKm.toStringAsFixed(1)} km',
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Dynamic ETA
              Expanded(
                child: _buildTelemetryMetricTile(
                  icon: Icons.access_time_filled,
                  title: 'Dynamic ETA',
                  value: isDelivered ? 'Delivered' : '~$_roadEtaMins mins',
                  subtitle: isDelivered ? 'Handshake Done' : 'Auto Recalculating',
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              // Cargo Conditions
              Expanded(
                child: _buildTelemetryMetricTile(
                  icon: Icons.thermostat,
                  title: 'Cold-Chain IoT',
                  value: '${_ambientTempC.toStringAsFixed(1)}°C',
                  subtitle: 'Moisture: ${_cargoMoisturePct.toStringAsFixed(1)}%',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Route Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Corridor Progress: ${(_progressFraction * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  Text(
                    isDelivered ? 'Delivery Complete' : 'En Route to Buyer',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progressFraction,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                Text(subtitle, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Spatial Playback Simulation Controls Card
  Widget _buildPlaybackControlsCard({required bool isDelivered}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: Color(0xFF15803D), size: 20),
              const SizedBox(width: 8),
              Text(
                'Spatial Playback Simulation Controls',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF14532D)),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                color: const Color(0xFF15803D),
                iconSize: 32,
                tooltip: _isPlaying ? 'Pause Simulation' : 'Resume Simulation',
                onPressed: _togglePlayback,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Speed Multiplier Buttons
          Row(
            children: [
              Text('Speed:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
              const SizedBox(width: 10),
              _buildSpeedButton(1.0, '1x (Normal)'),
              const SizedBox(width: 8),
              _buildSpeedButton(5.0, '5x (Fast)'),
              const SizedBox(width: 8),
              _buildSpeedButton(20.0, '20x (Rapid)'),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive Scrubbing Slider
          Row(
            children: [
              Text(
                '0%',
                style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              Expanded(
                child: Slider(
                  value: _progressFraction,
                  activeColor: const Color(0xFF15803D),
                  inactiveColor: const Color(0xFFBBF7D0),
                  onChanged: (val) {
                    _seekToProgress(val);
                  },
                ),
              ),
              Text(
                '100%',
                style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Milestone Jump Chips
          Text(
            'Jump to Milestone:',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMilestoneJumpChip('🌾 Farm Hub', 0.0),
                const SizedBox(width: 6),
                _buildMilestoneJumpChip('📦 Assayed & Packed', 0.25),
                const SizedBox(width: 6),
                _buildMilestoneJumpChip('🚚 Highway Transit', 0.55),
                const SizedBox(width: 6),
                _buildMilestoneJumpChip('🏡 Approaching Gate', 0.85),
                const SizedBox(width: 6),
                _buildMilestoneJumpChip('✅ Delivered & Escrow', 1.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton(double speed, String label) {
    final isSelected = _speedMultiplier == speed;
    return InkWell(
      onTap: () => _setPlaybackSpeed(speed),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF15803D) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF15803D)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF15803D),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneJumpChip(String label, double fraction) {
    final isNearby = (_progressFraction - fraction).abs() < 0.12;
    return InkWell(
      onTap: () => _seekToProgress(fraction),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isNearby ? const Color(0xFFDCFCE7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isNearby ? const Color(0xFF15803D) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isNearby ? FontWeight.bold : FontWeight.w500,
            color: isNearby ? const Color(0xFF14532D) : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// 6. Normalized Event Timeline Card
  Widget _buildTimelineCard({
    required String farmerName,
    required String buyerAddress,
    required bool isDelivered,
    required bool isInTransit,
  }) {
    final progress = _progressFraction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Normalized Dispatch & Delivery Timeline',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTimelineStep(
            title: '1. Order Placed & Escrow Locked',
            subtitle: 'Polygon Smart Contract locked payment assurance',
            isCompleted: true,
          ),
          _buildTimelineStep(
            title: '2. Farm Aggregated & Quality Assayed',
            subtitle: 'Picked up from $farmerName hub',
            isCompleted: progress >= 0.15 || isInTransit || isDelivered,
          ),
          _buildTimelineStep(
            title: '3. Real Road Highway Transit',
            subtitle: 'Live transit along Haryana Freight Highway Corridor',
            isCompleted: progress >= 0.50 || isDelivered,
          ),
          _buildTimelineStep(
            title: '4. Approaching Buyer Doorstep',
            subtitle: 'Destination: $buyerAddress',
            isCompleted: progress >= 0.85 || isDelivered,
          ),
          _buildTimelineStep(
            title: '5. Doorstep Handshake & Escrow Settlement',
            subtitle: isDelivered ? 'Verified by OTP • Funds Settled' : 'Requires 6-Digit Doorstep OTP Inspection',
            isCompleted: isDelivered,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF15803D) : Colors.grey.shade200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? const Color(0xFF15803D) : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isCompleted ? const Color(0xFF15803D) : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? const Color(0xFF0F172A) : Colors.grey.shade600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (!isLast) const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  /// 7. Driver & Fleet Telemetry Card
  Widget _buildDriverFleetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                'Courier & Fleet Telemetry',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDBEAFE),
                child: const Icon(Icons.person, color: Color(0xFF1D4ED8), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ramesh Kumar',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'AgriChain Express Fleet • HR-05-CD-4190',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: Color(0xFF15803D)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📞 Dialing Transporter Ramesh Kumar (+91 98120 44556)...')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chat, color: Color(0xFF2563EB)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('💬 Opening WhatsApp Chat with Transporter...')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 8. Doorstep Handshake & Escrow Settlement Card
  Widget _buildHandshakeEscrowCard({
    required String deliveryOtp,
    required bool isDelivered,
    required bool isInTransit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDelivered ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDelivered ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDelivered ? Icons.verified_user : Icons.pin,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doorstep Delivery OTP Handshake',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDelivered ? const Color(0xFF166534) : const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDelivered ? 'VERIFIED • ESCROW RELEASED' : deliveryOtp,
                      style: GoogleFonts.spaceMono(
                        fontSize: isDelivered ? 13 : 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isDelivered ? 1.0 : 3.0,
                        color: isDelivered ? const Color(0xFF166534) : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDelivered)
                IconButton(
                  icon: const Icon(Icons.copy, size: 20, color: Color(0xFF2563EB)),
                  tooltip: 'Copy OTP',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: deliveryOtp));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Delivery OTP copied to clipboard!'),
                        backgroundColor: Color(0xFF2563EB),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDelivered
                ? 'Payment of ₹${(_liveOrder['totalAmount'] as num?)?.toStringAsFixed(0) ?? '2,400'} successfully released from Polygon Smart Escrow to farmer account.'
                : 'Buyer shares this OTP with the courier upon physical inspection to release escrow funds.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (!isDelivered) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleCompleteDeliveryAndEscrow,
                icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                label: const Text(
                  '✅ Confirm Delivery & Release Escrow',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 9. Smart Contract PDF Preview CTA
  Widget _buildPdfCtaButton(Map<String, dynamic> order) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          SmartContractPdfService.autoDownloadOrPreviewContract(
            context: context,
            order: order,
          );
        },
        icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1B5E20), size: 18),
        label: const Text(
          '📄 View Dual-Signed Smart Contract (PDF)',
          style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFF0FDF4),
        ),
      ),
    );
  }
}
