import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/contract_pdf_service.dart';
import '../services/contract_storage_service.dart';
import '../services/database_service.dart';
import 'payment_method_selector.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../models/firestore_models.dart';
import '../screens/farmer/land_analysis_screen.dart';
import '../screens/retail_buyer/farmer_public_profile_screen.dart';
import 'fpo_lot_details_modal.dart';
import '../utils/crop_image_helper.dart';

class CropCard extends StatefulWidget {
  final FirestoreCrop crop;
  final bool showPlaceOrder;
  final VoidCallback? onTap;

  const CropCard({
    super.key,
    required this.crop,
    this.showPlaceOrder = true,
    this.onTap,
  });

  @override
  State<CropCard> createState() => _CropCardState();
}

class _CropCardState extends State<CropCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap ?? () => _showCropDetails(context),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Area with Floating Badges
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image Placeholder / Gradient
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: _buildCropImage(),
                    ),

                    // Floating Glass Badges
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: [
                          if (widget.crop.isNFT)
                            _buildGlassBadge(
                              context,
                              'NFT',
                              Icons.verified,
                              AppTheme.secondaryColor,
                            ),
                          if (widget.crop.isNFT && widget.crop.isAuction)
                            const SizedBox(width: 8),
                          if (widget.crop.isAuction)
                            _buildAuctionBadge(context),
                        ],
                      ),
                    ),

                    // Agri-Score Trust Badge (top-right)
                    if (widget.crop.agriScore != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildAgriScoreBadge(widget.crop.agriScore!, widget.crop.riskTier ?? 'Bronze'),
                      ),
                  ],
                ),
              ),

              // 2. Content Area
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.crop.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  widget.crop.location,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Pricing & Certs
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPricingSection(context),
                          const SizedBox(height: 8),
                          if (widget.crop.certifications.isNotEmpty)
                            _buildCertificationDots(context)
                          else
                            Text(
                              _getTimeAgo(widget.crop.harvestDate),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppTheme.textDisabled),
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
    );
  }

  Widget _buildGlassBadge(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.white.withValues(alpha: 0.2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgriScoreBadge(double score, String tier) {
    Color tierColor;
    switch (tier) {
      case 'Platinum':
        tierColor = const Color(0xFF6C63FF);
        break;
      case 'Gold':
        tierColor = const Color(0xFFE6A817);
        break;
      case 'Silver':
        tierColor = const Color(0xFF78909C);
        break;
      default:
        tierColor = const Color(0xFFBF6D3A);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, size: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                '${score.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuctionBadge(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final auction = appState.getAuctionByCropId(widget.crop.id);
        if (auction == null) return const SizedBox.shrink();

        final isActive =
            auction.endTime.difference(DateTime.now()).inSeconds > 0;
        return _buildGlassBadge(
          context,
          isActive ? 'LIVE' : 'ENDED',
          Icons.gavel,
          isActive ? AppTheme.success : AppTheme.error,
        );
      },
    );
  }

  Widget _buildCropImage() {
    return CropImageHelper.buildCropImage(
      widget.crop.imageUrl,
      widget.crop.name,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }


  Widget _buildPricingSection(BuildContext context) {
    final theme = Theme.of(context);

    // Auction Pricing
    if (widget.crop.isAuction) {
      return Consumer<AppState>(
        builder: (context, appState, child) {
          final auction = appState.getAuctionByCropId(widget.crop.id);
          if (auction == null) return _buildDirectPricing(context);

          final bids = appState.getBidsForAuction(auction.id);
          final currentBid = bids.isNotEmpty
              ? (bids.last['amount'] as num).toDouble()
              : auction.startingPrice;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Bid', style: theme.textTheme.labelSmall),
              Text(
                '₹${currentBid.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
      );
    }

    // Direct Pricing
    return _buildDirectPricing(context);
  }

  Widget _buildDirectPricing(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '₹${widget.crop.price.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '/kg',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCertificationDots(BuildContext context) {
    return Row(
      children: widget.crop.certifications.take(3).map((cert) {
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: cert['type'] ?? 'Certified',
            child: CircleAvatar(
              radius: 4,
              backgroundColor: AppTheme.secondaryColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Now';
  }

  void _showCropDetails(BuildContext context) {
    if (widget.crop.isAuction) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _CropDetailsSheet(
          crop: widget.crop,
          showPlaceOrder: widget.showPlaceOrder,
        ),
      );
      return;
    }

    final double rawPrice = widget.crop.price;
    final double pricePerQtl = rawPrice > 300 ? rawPrice : (rawPrice * 100.0);
    final double pricePerMt = pricePerQtl * 10.0;

    double availableMt = 15.0;
    final qStr = widget.crop.quantity.toLowerCase();
    final numMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(qStr);
    if (numMatch != null) {
      final val = double.tryParse(numMatch.group(1)!) ?? 15.0;
      if (qStr.contains('kg')) {
        availableMt = (val / 1000.0).clamp(0.5, 500.0);
      } else if (qStr.contains('qtl') || qStr.contains('quintal')) {
        availableMt = (val / 10.0).clamp(0.5, 500.0);
      } else if (qStr.contains('mt') || qStr.contains('ton')) {
        availableMt = val.clamp(0.5, 500.0);
      }
    }
    final double totalMt = (availableMt * 1.25).clamp(availableMt, 1000.0);
    final double reservedMt = (totalMt - availableMt).clamp(0.0, totalMt);

    final appState = Provider.of<AppState>(context, listen: false);
    final userType = appState.currentUser?.userType;
    final bool isBulk = userType == UserType.buyer;
    final bool isRetail = !isBulk;

    FpoLotDetailsModal.show(
      context,
      cropName: widget.crop.name,
      variety: widget.crop.category?.name.toUpperCase() ?? 'Certified Hybrid',
      siloLocation: widget.crop.location.isNotEmpty
          ? widget.crop.location
          : 'Central Silo Complex 01, Karnal',
      totalMt: totalMt,
      availableMt: availableMt,
      reservedMt: reservedMt,
      pricePerQtl: pricePerQtl,
      pricePerMt: pricePerMt,
      qualityGrade: widget.crop.qualityGrade.name.toUpperCase(),
      moistureText: '10.8% (Optimal)',
      imageUrl: widget.crop.imageUrl,
      fpoName: widget.crop.farmerName.isNotEmpty
          ? widget.crop.farmerName
          : 'Direct Certified Farm Hub',
      fpoId: widget.crop.farmerId,
      inventoryItemId: widget.crop.id,
      isBuyer: true,
      isRetail: isRetail,
    );
  }
}

// Redesigned Detail Sheet
class _CropDetailsSheet extends StatelessWidget {
  final FirestoreCrop crop;
  final bool showPlaceOrder;

  const _CropDetailsSheet({required this.crop, this.showPlaceOrder = true});

  Widget _buildDetailImage() {
    if (crop.imageUrl.isEmpty || crop.imageUrl.startsWith('assets/')) {
      return const SizedBox.shrink();
    }

    Widget imageWidget;
    if (crop.imageUrl.startsWith('data:image')) {
      try {
        final base64String = crop.imageUrl.split(',').last;
        imageWidget = Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    } else if (crop.imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        crop.imageUrl,
        fit: BoxFit.cover,
      );
    } else {
      try {
        imageWidget = kIsWeb
            ? Image.network(crop.imageUrl, fit: BoxFit.cover)
            : Image.file(File(crop.imageUrl), fit: BoxFit.cover);
      } catch (e) {
        return const SizedBox.shrink();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textDisabled.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailImage(),
                        // Header
                        Text(
                          crop.name,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              crop.location,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            if (crop.isNFT)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.secondaryColor,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'NFT Verified',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Price & Stats
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStat(context, 'Price', '₹${crop.price.toStringAsFixed(0)} / kg'),
                              _buildStat(context, 'Quantity', '${crop.quantity.replaceAll(RegExp(r'[^0-9.]'), '')} kg'),
                              _buildStat(
                                context,
                                'Harvest',
                                DateFormat('MMM d').format(crop.harvestDate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Description
                        Text(
                          'About this crop',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          crop.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                        ),
                        const SizedBox(height: 24),

                        // Farmer Info
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              crop.farmerName.isNotEmpty ? crop.farmerName[0] : 'F',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          title: Text(crop.farmerName),
                          subtitle: const Text('Verified Farmer'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FarmerPublicProfileScreen(crop: crop),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Agri-Score Section
                        if (crop.agriScore != null) ...[
                          _buildAgriScoreSection(context),
                          const SizedBox(height: 16),
                        ],

                        // Analyze Land Button (for farmers viewing their own crops)
                        Consumer<AppState>(
                          builder: (context, appState, _) {
                            final isFarmer = appState.currentUser?.userType == UserType.farmer;
                            final isOwner = crop.farmerId == appState.currentUser?.id;
                            if (isFarmer && isOwner) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LandAnalysisScreen(crop: crop),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    crop.agriScore != null ? Icons.refresh : Icons.satellite_alt,
                                    size: 18,
                                  ),
                                  label: Text(
                                    crop.agriScore != null ? 'Re-Analyze Land' : '🛰️ Analyze Land Quality',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryGreen,
                                    side: const BorderSide(color: AppTheme.primaryGreen),
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(
                          height: 100,
                        ), // Spacing for sticky button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (showPlaceOrder)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _showOrderDialog(context),
                        child: const Text('Place Order'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAgriScoreSection(BuildContext context) {
    final score = crop.agriScore!;
    final tier = crop.riskTier ?? 'Bronze';
    Color tierColor;
    switch (tier) {
      case 'Platinum':
        tierColor = const Color(0xFF6C63FF);
        break;
      case 'Gold':
        tierColor = const Color(0xFFE6A817);
        break;
      case 'Silver':
        tierColor = const Color(0xFF78909C);
        break;
      default:
        tierColor = const Color(0xFFBF6D3A);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withValues(alpha: 0.1), tierColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: tierColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Agri-Trust Score',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tierColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$tier — ${score.toInt()}/1000',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 1000,
              minHeight: 8,
              backgroundColor: tierColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (crop.ndviValue != null) ...[
                Icon(Icons.satellite_alt, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'NDVI: ${crop.ndviValue!.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 16),
              ],
              if (crop.soilType != null) ...[
                Icon(Icons.terrain, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  crop.soilType!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showOrderDialog(BuildContext parentContext) {
    XFile? contractSignatureImage;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Confirm Order',
                          style: Theme.of(dialogContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),

                  // Order details and Payment
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Summary',
                            style: Theme.of(dialogContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailImage(),
                          _buildOrderDetailRow(
                            dialogContext,
                            'Crop',
                            crop.name,
                          ),
                          _buildOrderDetailRow(
                            dialogContext,
                            'Quantity',
                            crop.quantity,
                          ),
                          _buildOrderDetailRow(
                            dialogContext,
                            'Price',
                            '₹${crop.price.toStringAsFixed(0)}',
                          ),
                          _buildOrderDetailRow(
                            dialogContext,
                            'Location',
                            crop.location,
                          ),
                          _buildOrderDetailRow(
                            dialogContext,
                            'Farmer',
                            crop.farmerName,
                          ),
                          const Divider(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹${crop.price.toStringAsFixed(0)}',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Contract Signature Section
                          const Text(
                            'Contract Document Signature',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your specific signature for this purchase contract. (Optional - will fall back to account signature if not provided)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                if (contractSignatureImage != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.network(
                                            contractSignatureImage!.path,
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                          )
                                        : Image.file(
                                            File(contractSignatureImage!.path),
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker
                                          .pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 70,
                                            maxWidth: 1024,
                                          );
                                      if (image != null) {
                                        setState(() {
                                          contractSignatureImage = image;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error picking signature: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.draw),
                                  label: Text(
                                    contractSignatureImage == null
                                        ? 'Upload Contract Signature'
                                        : 'Change Signature',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Payment section
                          PaymentMethodSelector(
                            amount: crop.price,
                            description:
                                'Purchase ${crop.name} - ${crop.quantity}',
                            metadata: {
                              'cropId': crop.id,
                              'cropName': crop.name,
                              'farmerId': crop.farmerId,
                              'quantity': crop.quantity,
                            },
                            onPaymentSuccess: (paymentData) {
                              _processOrder(
                                dialogContext,
                                parentContext,
                                paymentData,
                                contractSignatureImage,
                              );
                            },
                            onPaymentFailure: (error) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderDetailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processOrder(
    BuildContext dialogContext,
    BuildContext parentContext,
    Map<String, dynamic> paymentData,
    XFile? contractSignatureImage,
  ) async {
    try {
      // Show loading
      showDialog(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing order...'),
                ],
              ),
            ),
          ),
        ),
      );

      final appState = Provider.of<AppState>(parentContext, listen: false);
      final currentUser = appState.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create order ID
      final orderId = const Uuid().v4();
      final orderData = {
        'id': orderId,
        'cropId': crop.id,
        'cropName': crop.name,
        'quantity': crop.quantity,
        'price': crop.price,
        'totalAmount': crop.price,
        'buyerId': currentUser.id,
        'buyerName': currentUser.name,
        'sellerId': crop.farmerId,
        'sellerName': crop.farmerName,
        'status': 'pending',
        'paymentMethod': paymentData['payment_method'] ?? 'unknown',
        'transactionId': paymentData['transaction_id'] ?? '',
        'deliveryLocation': crop.location,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Create order in Firebase
      final firebaseService = FirebaseService();
      await firebaseService.createOrder(orderId: orderId, orderData: orderData);

      // Fetch farmer details for signature
      String? farmerSignatureUrl = crop.signatureUrl;
      if (farmerSignatureUrl == null) {
        try {
          final farmerDoc = await DatabaseService().getUserById(crop.farmerId);
          if (farmerDoc != null) {
            farmerSignatureUrl = farmerDoc['signatureUrl'];
          }
        } catch (e) {
          debugPrint('Error fetching farmer signature: $e');
        }
      }

      String? buyerSignatureUrl = currentUser.signatureUrl;
      Uint8List? localSignatureBytes;

      // Convert contract signature to Base64 (bypasses Firebase Storage)
      if (contractSignatureImage != null) {
        localSignatureBytes = await contractSignatureImage.readAsBytes();
        try {
          final base64String = base64Encode(localSignatureBytes);
          buyerSignatureUrl = 'data:image/jpeg;base64,$base64String';
          debugPrint(
            '✅ Buyer signature converted to Base64 (${localSignatureBytes.length} bytes)',
          );
        } catch (e) {
          debugPrint('Error converting contract signature: $e');
        }
      }

      // Generate contract PDF
      final contractPdf = await ContractPdfService.generatePurchaseContract(
        contractId: orderId,
        farmerName: crop.farmerName,
        buyerName: currentUser.name,
        cropName: crop.name,
        quantity: double.tryParse(crop.quantity.split(' ')[0]) ?? 1.0,
        price: crop.price,
        deliveryDate: DateFormat('dd MMMM yyyy').format(crop.harvestDate),
        deliveryLocation: crop.location,
        paymentTerms: 'Paid via ${paymentData['payment_method']}',
        farmerSignatureUrl: farmerSignatureUrl,
        buyerSignatureUrl: buyerSignatureUrl,
        buyerSignatureBytes: localSignatureBytes,
      );

      // Upload contract to Firebase Storage
      await ContractStorageService.uploadContract(
        pdfBytes: contractPdf,
        orderId: orderId,
        contractType: 'purchase',
        buyerName: currentUser.name,
        sellerName: crop.farmerName,
        cropName: crop.name,
        totalAmount: crop.price,
      );

      // Close loading dialog
      Navigator.pop(dialogContext);
      // Close payment dialog
      Navigator.pop(dialogContext);
      // Close crop details
      Navigator.pop(parentContext);

      // Show success and offer to download contract
      showDialog(
        context: parentContext,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 32),
              const SizedBox(width: 12),
              const Text('Order Placed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your order has been placed successfully.'),
              const SizedBox(height: 12),
              Text(
                'Order ID: $orderId',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A contract has been generated. Would you like to download it?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Printing.layoutPdf(onLayout: (format) => contractPdf);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Contract'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close any open dialogs
      Navigator.pop(dialogContext); // Close loading

      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Order failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
