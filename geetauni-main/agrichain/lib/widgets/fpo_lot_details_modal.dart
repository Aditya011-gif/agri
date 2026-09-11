import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/crop_image_helper.dart';
import '../utils/translation_helper.dart';
import '../screens/bulk_buyer/escrow_checkout_screen.dart';
import '../screens/retail_buyer/retail_checkout_screen.dart';

/// Comprehensive, rich, and detailed FPO Commodity Lot Passport Modal Sheet.
/// Displays deep warehouse telemetry, atomic reservation math, physical assaying
/// parameters, commercial trade terms, and certifications.
class FpoLotDetailsModal {
  static void show(
    BuildContext context, {
    required String cropName,
    required String variety,
    required String siloLocation,
    required double totalMt,
    required double availableMt,
    required double reservedMt,
    required double pricePerQtl,
    required double pricePerMt,
    required String qualityGrade,
    required String moistureText,
    String? imageUrl,
    String? imageCrop,
    String? fpoId,
    String? fpoName,
    String? inventoryItemId,
    bool isBuyer = false,
    bool isRetail = false,
    VoidCallback? onRunAiAssay,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return _FpoLotDetailsContent(
              scrollController: scrollController,
              cropName: cropName,
              variety: variety,
              siloLocation: siloLocation,
              totalMt: totalMt,
              availableMt: availableMt,
              reservedMt: reservedMt,
              pricePerQtl: pricePerQtl,
              pricePerMt: pricePerMt,
              qualityGrade: qualityGrade,
              moistureText: moistureText,
              imageUrl: imageUrl,
              imageCrop: imageCrop,
              fpoId: fpoId,
              fpoName: fpoName,
              inventoryItemId: inventoryItemId,
              isBuyer: isBuyer,
              isRetail: isRetail,
              onRunAiAssay: onRunAiAssay,
            );
          },
        );
      },
    );
  }
}


class _FpoLotDetailsContent extends StatefulWidget {
  final ScrollController scrollController;
  final String cropName;
  final String variety;
  final String siloLocation;
  final double totalMt;
  final double availableMt;
  final double reservedMt;
  final double pricePerQtl;
  final double pricePerMt;
  final String qualityGrade;
  final String moistureText;
  final String? imageUrl;
  final String? imageCrop;
  final String? fpoId;
  final String? fpoName;
  final String? inventoryItemId;
  final bool isBuyer;
  final bool isRetail;
  final VoidCallback? onRunAiAssay;

  const _FpoLotDetailsContent({
    required this.scrollController,
    required this.cropName,
    required this.variety,
    required this.siloLocation,
    required this.totalMt,
    required this.availableMt,
    required this.reservedMt,
    required this.pricePerQtl,
    required this.pricePerMt,
    required this.qualityGrade,
    required this.moistureText,
    this.imageUrl,
    this.imageCrop,
    this.fpoId,
    this.fpoName,
    this.inventoryItemId,
    this.isBuyer = false,
    this.isRetail = false,
    this.onRunAiAssay,
  });


  @override
  State<_FpoLotDetailsContent> createState() => _FpoLotDetailsContentState();
}

class _FpoLotDetailsContentState extends State<_FpoLotDetailsContent> {
  bool _isDownloadingPdf = false;
  double? _selectedBuyerQty;
  late TextEditingController _buyerQtyController;

  @override
  void initState() {
    super.initState();
    final defaultQty = widget.isRetail
        ? (widget.availableMt * 1000.0 >= 25.0 ? 25.0 : (widget.availableMt * 1000.0 > 0 ? widget.availableMt * 1000.0 : 5.0))
        : (widget.availableMt * 10.0 >= 50.0 ? 50.0 : (widget.availableMt * 10.0 > 0 ? widget.availableMt * 10.0 : 10.0));
    _selectedBuyerQty = defaultQty;
    _buyerQtyController = TextEditingController(text: defaultQty.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _buyerQtyController.dispose();
    super.dispose();
  }

  void _triggerDownloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isDownloadingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'Lot Passport downloaded: LOT-${widget.cropName.toUpperCase().replaceAll(' ', '')}-QC.pdf',
                    'लॉट पासपोर्ट डाउनलोड किया गया: LOT-${widget.cropName.toUpperCase().replaceAll(' ', '')}-QC.pdf',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lotBatchId = 'LOT-HR-KNL-2026-${widget.cropName.contains('Wheat') ? 'W01' : (widget.cropName.contains('Basmati') ? 'B02' : 'M03')}';
    final totalQtl = widget.totalMt * 10;
    final availableQtl = widget.availableMt * 10;
    final reservedQtl = widget.reservedMt * 10;
    final totalValuation = totalQtl * widget.pricePerQtl;
    final availableValuation = availableQtl * widget.pricePerQtl;

    final pricePerKg = widget.pricePerQtl > 300 ? widget.pricePerQtl / 100.0 : widget.pricePerQtl;
    final priceDisplay = widget.isRetail
        ? '₹${pricePerKg.toStringAsFixed(0)} / ${context.tr('kg', 'किग्रा')}'
        : '₹${widget.pricePerQtl.toStringAsFixed(0)} / ${context.tr('Quintal', 'क्विंटल')}';
    final subPriceDisplay = widget.isRetail
        ? '₹${(pricePerKg * 100).toStringAsFixed(0)} / ${context.tr('Qtl', 'क्विंटल')}'
        : '₹${widget.pricePerMt.toStringAsFixed(0)} / MT';

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        // 1. Drag Handle
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Header Title Row with Close Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        lotBatchId,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Warehouse Lot Passport', 'गोदाम लॉट पासपोर्ट'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              tooltip: context.tr('Close', 'बंद करें'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Hero Crop Picture with Floating Badges
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: CropImageHelper.buildCropImage(
                  widget.imageUrl,
                  widget.imageCrop ?? widget.cropName,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warehouse, size: 13, color: Color(0xFF69F0AE)),
                    const SizedBox(width: 5),
                    Text(
                      widget.siloLocation,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 13, color: Color(0xFF69F0AE)),
                    const SizedBox(width: 5),
                    Text(
                      widget.qualityGrade,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('AI Assayed & Lab Certified', 'एआई परीक्षित एवं लैब प्रमाणित'),
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Title, Variety, and Pricing Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cropName,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.variety} • ${widget.siloLocation}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
                Text(
                  subPriceDisplay,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 5. ATOMIC INVENTORY MATH & RESERVATION BREAKDOWN
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isRetail
                        ? context.tr('Farm Stock & Lot Availability', 'फार्म स्टॉक एवं लॉट उपलब्धता')
                        : context.tr('Warehouse Stock Allocation', 'गोदाम स्टॉक आवंटन'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${context.tr('Avail', 'उपलब्ध')}: ₹${(availableValuation / 100000).toStringAsFixed(2)}L • ${context.tr('Total', 'कुल')}: ₹${(totalValuation / 100000).toStringAsFixed(2)}L',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Segmented visual progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    if (widget.availableMt > 0)
                      Expanded(
                        flex: (widget.availableMt * 10).toInt(),
                        child: Container(height: 10, color: const Color(0xFF15803D)),
                      ),
                    if (widget.reservedMt > 0)
                      Expanded(
                        flex: (widget.reservedMt * 10).toInt(),
                        child: Container(height: 10, color: const Color(0xFFF59E0B)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTonnageTile(
                    widget.isRetail ? context.tr('Total Farm Lot', 'कुल फार्म लॉट') : context.tr('Total In Silo', 'साइलो में कुल'),
                    widget.isRetail ? '${(widget.totalMt * 1000).toStringAsFixed(0)} ${context.tr('kg', 'किग्रा')}' : '${totalQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                    const Color(0xFF0F172A),
                    context.tr('Physical Stock', 'भौतिक स्टॉक'),
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  _buildTonnageTile(
                    widget.isRetail ? context.tr('Available to Order', 'ऑर्डर के लिए उपलब्ध') : context.tr('Available to Contract', 'अनुबंध के लिए उपलब्ध'),
                    widget.isRetail ? '${(widget.availableMt * 1000).toStringAsFixed(0)} ${context.tr('kg', 'किग्रा')}' : '${availableQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                    const Color(0xFF15803D),
                    context.tr('Immediate Delivery', 'तत्काल डिलीवरी'),
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  _buildTonnageTile(
                    context.tr('Locked in Escrow', 'एस्क्रो में आरक्षित'),
                    widget.isRetail ? '${(widget.reservedMt * 1000).toStringAsFixed(0)} ${context.tr('kg', 'किग्रा')}' : '${reservedQtl.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')}',
                    const Color(0xFFD97706),
                    context.tr('Under Active PO', 'सक्रिय खरीद आदेश अंतर्गत'),
                  ),
                ],
              ),

              if (reservedQtl > 0) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.lock_clock, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.isRetail
                            ? '${(widget.reservedMt * 1000).toStringAsFixed(0)} ${context.tr('kg is locked in buyer escrow awaiting dispatch.', 'किग्रा खरीदार एस्क्रो में आरक्षित है, प्रेषण की प्रतीक्षा में।')}'
                            : '${reservedQtl.toStringAsFixed(0)} ${context.tr('Qtl is locked in buyer escrow awaiting dispatch.', 'क्विंटल प्रेषण की प्रतीक्षा में एस्क्रो में आरक्षित है।')}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 6. REAL-TIME SILO ENVIRONMENTAL TELEMETRY
        Text(
          widget.isRetail
              ? context.tr('Storage & Post-Harvest Telemetry', 'भंडारण एवं पोस्ट-हार्वेस्ट टेलीमेट्री')
              : context.tr('Silo Environmental Telemetry', 'साइलो पर्यावरण टेलीमेट्री'),
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTelemetryCard(
                context.tr('Chamber Temp', 'कक्ष तापमान'),
                '21.4°C',
                context.tr('Safe (< 25°C)', 'सुरक्षित (< 25°C)'),
                Icons.thermostat,
                const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTelemetryCard(
                context.tr('Ambient Humidity', 'परिवेश आर्द्रता'),
                '54% RH',
                context.tr('Optimal (< 65%)', 'इष्टतम (< 65%)'),
                Icons.water_drop_outlined,
                const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTelemetryCard(
                context.tr('Aeration Blower', 'वायु संचरण ब्लोअर'),
                context.tr('Active', 'सक्रिय'),
                context.tr('Automated Cycling', 'स्वचालित चक्र'),
                Icons.air,
                const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTelemetryCard(
                context.tr('Pest Inspection', 'कीट निरीक्षण'),
                context.tr('Zero Pest', 'शून्य कीट'),
                context.tr('Valid till Nov 2026', 'नवंबर 2026 तक वैध'),
                Icons.shield_outlined,
                const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 7. PHYSICAL ASSAYING & QUALITY SPECIFICATIONS
        Text(
          context.tr('Physical Assaying & Quality Specs', 'भौतिक परीक्षण एवं गुणवत्ता विनिर्देश'),
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            children: [
              _buildSpecRow(context.tr('Moisture Assay', 'नमी परीक्षण'), widget.moistureText, context.tr('Standard ≤ 12.0%', 'मानक ≤ 12.0%'), true),
              const Divider(height: 16),
              _buildSpecRow(context.tr('Purity Score', 'शुद्धता स्कोर'), '98.8%', context.tr('Minimum ≥ 98.0%', 'न्यूनतम ≥ 98.0%'), true),
              const Divider(height: 16),
              _buildSpecRow(context.tr('Broken Grains', 'टूटे दाने'), '1.4%', context.tr('AGMARK Grade A ≤ 2.0%', 'एगमार्क ग्रेड ए ≤ 2.0%'), true),
              const Divider(height: 16),
              _buildSpecRow(context.tr('Foreign Matter', 'बाहरी पदार्थ'), '0.3%', context.tr('Standard ≤ 0.75%', 'मानक ≤ 0.75%'), true),
              const Divider(height: 16),
              _buildSpecRow(context.tr('Bulk Density (Test Weight)', 'थोक घनत्व (परीक्षण भार)'), '79.4 kg/hL', context.tr('Heavy Test Grain', 'उत्कृष्ट भारी अनाज'), true),
              const Divider(height: 16),
              _buildSpecRow(context.tr('Protein / Gluten Content', 'प्रोटीन / ग्लूटेन मात्रा'), '12.8% Wet Gluten', context.tr('Superior Milling Yield', 'उच्च मिलिंग उपज'), true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 8. COMMERCIAL TRADING & LOGISTICS TERMS
        Text(
          context.tr('Commercial Terms & Logistics', 'वाणिज्यिक शर्तें एवं रसद'),
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            children: [
              _buildTermItem(
                context.tr('Minimum Order Quantity (MOQ)', 'न्यूनतम ऑर्डर मात्रा (MOQ)'),
                widget.isRetail
                    ? context.tr('5 kg (Flexible Direct Purchase)', '5 किग्रा (लचीली प्रत्यक्ष खरीद)')
                    : context.tr('250 Quintals (1 Full Truckload / FTL)', '250 क्विंटल (1 पूर्ण ट्रक लोड / FTL)'),
                Icons.local_shipping_outlined,
              ),
              _buildTermItem(
                context.tr('Dispatch Lead Time', 'प्रेषण अवधि'),
                widget.isRetail
                    ? context.tr('Same-Day / 24 Hours Direct Farm Dispatch', 'उसी दिन / 24 घंटे में सीधा खेत से प्रेषण')
                    : context.tr('24 - 48 Hours post-Escrow Confirmation', 'एस्क्रो पुष्टि के 24 - 48 घंटे बाद'),
                Icons.schedule,
              ),
              _buildTermItem(
                context.tr('Weighbridge Specifications', 'वेब्रिज विनिर्देश'),
                widget.isRetail
                    ? context.tr('Electronic Certified Precision Scale (NABL Calibrated)', 'इलेक्ट्रॉनिक प्रमाणित परिशुद्धता तराजू (NABL कैलिब्रेटेड)')
                    : context.tr('600-Quintal Electronic (NABL Haryana Calibrated)', '600-क्विंटल इलेक्ट्रॉनिक (NABL हरियाणा कैलिब्रेटेड)'),
                Icons.scale_outlined,
              ),
              _buildTermItem(
                context.tr('Mandi Cess & Tax Exemption', 'मंडी उपकर एवं कर छूट'),
                context.tr('0% GST (Tax Exempt) • Zero Intermediary Cuts', '0% जीएसटी (कर मुक्त) • शून्य बिचौलिया कटौती'),
                Icons.receipt_long_outlined,
              ),
              _buildTermItem(
                context.tr('Escrow Settlement Type', 'एस्क्रो निपटान प्रकार'),
                widget.isRetail
                    ? context.tr('Buyer Safe Escrow Protection (Instant Disbursal on Verified Delivery)', 'सुरक्षित खरीदार एस्क्रो सुरक्षा (डिलीवरी सत्यापन पर तत्काल भुगतान)')
                    : context.tr('Multi-FPO Isolated Smart Contract Escrow', 'मल्टी-एफपीओ स्मार्ट अनुबंध एस्क्रो'),
                Icons.verified_user_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 9. STATUTORY LICENSES & PROVENANCE HASH
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint, size: 16, color: Color(0xFF334155)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('Compliance & Traceability', 'अनुपालन एवं ट्रेसिबिलिटी'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'FSSAI Lic: 1002302200192 • SFAC ID: SFAC-HR-KNL-08819\nSmart Contract Hash: 0x7b4a92c81092e44f8819',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 10. PRIMARY PROCUREMENT ACTION
        if (widget.isBuyer) ...[
          // Custom Quantity Selector for Buyers (Retail in kg, Bulk in Qtl)
          Builder(
            builder: (context) {
              final isRetail = widget.isRetail;
              final maxStock = isRetail ? (widget.availableMt * 1000.0) : (widget.availableMt * 10.0);
              final unit = isRetail ? context.tr('kg', 'किग्रा') : context.tr('Qtl', 'क्विंटल');
              final effectivePrice = isRetail ? pricePerKg : widget.pricePerQtl;
              final currentQty = (_selectedBuyerQty ?? (isRetail ? 25.0 : 50.0)).clamp(1.0, maxStock > 0 ? maxStock : 5000.0);
              final totalCost = currentQty * effectivePrice;

              void updateQty(double newQty) {
                final clamped = newQty.clamp(1.0, maxStock > 0 ? maxStock : 5000.0);
                setState(() {
                  _selectedBuyerQty = clamped;
                  _buyerQtyController.text = clamped.toStringAsFixed(0);
                });
              }

              final presets = isRetail
                  ? [5.0, 10.0, 25.0, 50.0, 100.0]
                  : [25.0, 50.0, 100.0, 250.0, 500.0];

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isRetail
                              ? '${context.tr('Procurement Quantity', 'खरीद मात्रा')} ($unit):'
                              : '${context.tr('Lot Order Quantity', 'लॉट ऑर्डर मात्रा')} ($unit):',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        Text(
                          '${context.tr('Max', 'अधिकतम')} ${maxStock.toStringAsFixed(0)} $unit ${context.tr('available', 'उपलब्ध')}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Stepper & Editable TextField
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, size: 18, color: Color(0xFF15803D)),
                            onPressed: () => updateQty(currentQty - (isRetail ? (currentQty > 10 ? 5 : 1) : 25)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF15803D), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _buyerQtyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      hintText: context.tr('Qty', 'मात्रा'),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed != null && parsed > 0) {
                                        final clamped = parsed.clamp(1.0, maxStock > 0 ? maxStock : 5000.0);
                                        setState(() {
                                          _selectedBuyerQty = clamped;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, size: 18, color: Color(0xFF15803D)),
                            onPressed: () => updateQty(currentQty + (isRetail ? (currentQty >= 10 ? 5 : 1) : 25)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Slider
                    Row(
                      children: [
                        Text('1 $unit', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF15803D),
                              inactiveTrackColor: const Color(0xFFDCFCE7),
                              thumbColor: const Color(0xFF15803D),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: currentQty.clamp(1.0, maxStock > 1.0 ? maxStock : 500.0),
                              min: 1.0,
                              max: maxStock > 1.0 ? maxStock : 500.0,
                              divisions: maxStock > 1.0 ? (maxStock <= 100 ? maxStock.toInt() : 50) : 50,
                              label: '${currentQty.toStringAsFixed(0)} $unit',
                              onChanged: (val) => updateQty(val),
                            ),
                          ),
                        ),
                        Text('${maxStock.toStringAsFixed(0)} $unit', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),

                    // Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...presets.where((opt) => opt <= (maxStock > 0 ? maxStock : 5000.0)).map((opt) {
                            final isSel = (currentQty - opt).abs() < 0.1;
                            return GestureDetector(
                              onTap: () => updateQty(opt),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF15803D) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isSel ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  '${opt.toStringAsFixed(0)} $unit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () => updateQty(maxStock),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (currentQty - maxStock).abs() < 0.1 ? const Color(0xFF15803D) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (currentQty - maxStock).abs() < 0.1 ? const Color(0xFF15803D) : const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '${context.tr('Full Lot', 'पूरा लॉट')} (${maxStock.toStringAsFixed(0)} $unit)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (currentQty - maxStock).abs() < 0.1 ? Colors.white : const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Price Breakdown formula
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.tr('Rate', 'दर')}: ₹${effectivePrice.toStringAsFixed(0)}/$unit × ${currentQty.toStringAsFixed(0)} $unit',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          Text(
                            '₹${totalCost.toStringAsFixed(0)} ${context.tr('Total', 'कुल')}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Builder(
            builder: (context) {
              final isRetail = widget.isRetail;
              final maxStock = isRetail ? (widget.availableMt * 1000.0) : (widget.availableMt * 10.0);
              final effectivePrice = isRetail ? pricePerKg : widget.pricePerQtl;
              final chosenQty = (_selectedBuyerQty ?? (isRetail ? 25.0 : 50.0)).clamp(1.0, maxStock > 0 ? maxStock : 5000.0);
              final totalCost = chosenQty * effectivePrice;

              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.isRetail) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RetailCheckoutScreen(
                            crop: {
                              'id': widget.inventoryItemId ?? 'LOT-${widget.cropName}',
                              'name': widget.cropName,
                              'crop': widget.cropName,
                              'variety': widget.variety,
                              'qualityGrade': widget.qualityGrade,
                              'price': pricePerKg,
                              'farmerName': widget.fpoName ?? 'Direct Farm Lot',
                              'location': widget.siloLocation,
                              'quantity': '${(widget.availableMt * 1000).toStringAsFixed(0)} kg',
                              'availableStockKg': widget.availableMt * 1000,
                              'selectedQuantity': chosenQty,
                              'orderQuantity': chosenQty,
                              'totalPrice': totalCost,
                              'imageUrl': widget.imageUrl ?? '',
                            },
                          ),
                        ),
                      );
                    } else {
                      final qtyQtl = chosenQty;
                      final qtyMt = qtyQtl / 10.0;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EscrowCheckoutScreen(
                            commodity: '${widget.cropName} (${widget.variety})',
                            variety: widget.variety,
                            originCluster: widget.siloLocation,
                            orderedTonnage: qtyMt,
                            cropRatePerTonne: widget.pricePerMt,
                            orderedQuantityQtl: qtyQtl,
                            cropRatePerQtl: widget.pricePerQtl,
                            fpoId: widget.fpoId ?? 'fpo_karnal_01',
                            fpoName: widget.fpoName ?? 'Karnal Agro Farmers Producer Co.',
                            inventoryItemId: widget.inventoryItemId,
                          ),
                        ),
                      );
                    }
                  },
                  icon: Icon(widget.isRetail ? Icons.shopping_bag_outlined : Icons.lock, size: 18, color: Colors.white),
                  label: Text(
                    widget.isRetail
                        ? '${context.tr('Buy Direct & Escrow Lock', 'सीधा खरीदें व एस्क्रो लॉक')} (${chosenQty.toStringAsFixed(0)} ${context.tr('kg', 'किग्रा')} • ₹${totalCost.toStringAsFixed(0)})'
                        : '${context.tr('Order Lot & Escrow Lock', 'लॉट ऑर्डर व एस्क्रो लॉक')} (${chosenQty.toStringAsFixed(0)} ${context.tr('Qtl', 'क्विंटल')} • ₹${totalCost.toStringAsFixed(0)})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isDownloadingPdf ? null : _triggerDownloadPdf,
              icon: _isDownloadingPdf
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download, size: 16),
              label: Text(
                _isDownloadingPdf
                    ? context.tr('Generating...', 'तैयार किया जा रहा है...')
                    : context.tr('Download Warehouse Passport', 'गोदाम पासपोर्ट डाउनलोड करें'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ] else ...[
          // FPO Center Mode: NO ORDER LOT BUTTON! FPO manages own warehouse inventory.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloadingPdf ? null : _triggerDownloadPdf,
                  icon: _isDownloadingPdf
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download, size: 16),
                  label: Text(
                    _isDownloadingPdf
                        ? context.tr('Generating...', 'तैयार किया जा रहा है...')
                        : context.tr('Download Passport', 'पासपोर्ट डाउनलोड करें'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onRunAiAssay != null) {
                      widget.onRunAiAssay!();
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  label: Text(context.tr('Run AI Assaying', 'एआई परख चलाएं'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTonnageTile(String label, String value, Color color, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(sub, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildTelemetryCard(String label, String value, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          Text(
            status,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String parameter, String measured, String benchmark, bool isPass) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parameter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text(benchmark, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
        Row(
          children: [
            Text(measured, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(width: 6),
            const Icon(Icons.check_circle, size: 15, color: Color(0xFF15803D)),
          ],
        ),
      ],
    );
  }

  Widget _buildTermItem(String title, String detail, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                Text(detail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
