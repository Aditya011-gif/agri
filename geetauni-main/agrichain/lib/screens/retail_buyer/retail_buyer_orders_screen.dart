import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../services/smart_contract_service.dart';
import '../../services/smart_contract_pdf_service.dart';
import '../../utils/crop_image_helper.dart';
import '../../widgets/crop_tracking_map_sheet.dart';
import '../../models/firestore_models.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import 'rating_screen.dart';

class RetailBuyerOrdersScreen extends StatefulWidget {
  const RetailBuyerOrdersScreen({super.key});

  @override
  State<RetailBuyerOrdersScreen> createState() => _RetailBuyerOrdersScreenState();
}

class _RetailBuyerOrdersScreenState extends State<RetailBuyerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final buyerId = appState.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('My Purchases', 'मेरी खरीदारी'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Text(
              context.tr('Track Your Direct-from-Farmer Orders', 'किसानों से सीधे ऑर्डर ट्रैक करें'),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: const [
          LanguageSwitcherPill(isDark: false),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.primaryGreen,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: context.tr('Active', 'सक्रिय')),
            Tab(text: context.tr('In Transit', 'मार्ग में')),
            Tab(text: context.tr('Delivered', 'वितरित')),
            Tab(text: context.tr('All Orders', 'सभी ऑर्डर')),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dbService.streamRetailOrders(buyerId: buyerId.isNotEmpty ? buyerId : null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }

          final orders = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(orders.where((o) => (o['status'] == 'active' || o['status'] == 'pending')).toList()),
              _buildOrdersList(orders.where((o) => o['status'] == 'in_transit').toList()),
              _buildOrdersList(orders.where((o) => o['status'] == 'delivered').toList()),
              _buildOrdersList(orders),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              context.tr('No orders in this tab', 'इस टैब में कोई ऑर्डर नहीं है'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('Your direct farmer purchases will appear here', 'आपकी सीधी किसान खरीदारी यहाँ दिखाई देगी'),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = orders[index];
        final status = (order['status'] as String? ?? 'active').toLowerCase();
        final isDelivered = status == 'delivered';
        final isInTransit = status == 'in_transit';

        Color statusColor = Colors.orange;
        String statusLabel = context.tr('Order Placed', 'ऑर्डर दर्ज');
        if (isInTransit) {
          statusColor = Colors.blue;
          statusLabel = context.tr('In Transit', 'मार्ग में');
        } else if (isDelivered) {
          statusColor = Colors.green;
          statusLabel = context.tr('Delivered', 'वितरित');
        }

        final qty = (order['quantity'] as num?)?.toDouble() ?? 1.0;
        final unit = order['unit'] as String? ?? 'Qtl';
        final total = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['orderId'] as String? ?? 'RET-9921',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Crop Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CropImageHelper.buildCropImage(
                      order['imageUrl']?.toString() ?? '',
                      order['cropName']?.toString() ?? 'Produce',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['cropName'] as String? ?? 'Produce',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Qty', 'मात्रा')}: $qty $unit • ${context.tr('Total', 'कुल')}: ₹${total.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Farmer', 'किसान')}: ${order['farmerName'] ?? 'Rajesh Kumar'} (${order['farmerDistance'] ?? context.tr('Local', 'स्थानीय')})',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Delivery OTP Box (If active or in transit)
              if (order['deliveryOtp'] != null && !isDelivered) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3D1F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, color: Color(0xFF69F0AE), size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '${context.tr('Delivery OTP', 'डिलीवरी ओटीपी')}: ',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                      Text(
                        order['deliveryOtp'] as String,
                        style: GoogleFonts.spaceMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF69F0AE),
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: order['deliveryOtp'] as String));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('📋 Delivery OTP copied!', '📋 डिलीवरी ओटीपी कॉपी हो गया!'))),
                          );
                        },
                        child: const Icon(Icons.copy, color: Colors.white70, size: 14),
                      ),
                    ],
                  ),
                ),
              ],

              // On-chain Polygon Escrow badge
              if (order['txHash'] != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF15803D), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('Smart Escrow Anchored on Polygon (Gasless)', 'स्मार्ट एस्क्रो पॉलीगॉन पर सुरक्षित (गैस-मुक्त)'),
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF15803D)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // View Signed Smart Contract Button
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: () {
                    SmartContractPdfService.autoDownloadOrPreviewContract(
                      context: context,
                      order: order,
                      openDirectly: false,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF15803D)),
                  label: Text(
                    context.tr('View Signed Smart Contract (PDF)', 'हस्ताक्षरित अनुबंध देखें (PDF)'),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    backgroundColor: const Color(0xFFF0FDF4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showTrackingDetails(context, order),
                      icon: const Icon(Icons.timeline, size: 16),
                      label: Text(
                        context.tr('Track Order', 'ऑर्डर ट्रैक करें'),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.darkGreen,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isDelivered)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final farmerId = (order['farmerId'] ?? '').toString();
                          final farmerName = (order['farmerName'] ?? 'Verified Farmer').toString();
                          final orderId = (order['id'] ?? '').toString();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GiveRatingScreen(
                                toUserId: farmerId.isNotEmpty ? farmerId : 'farmer_demo',
                                toUserName: farmerName,
                                ratingType: RatingType.seller,
                                transactionId: orderId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star, size: 16),
                        label: Text(
                          context.tr('Rate Farmer', 'रेटिंग दें'),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showConfirmDeliveryOtpDialog(context, order),
                        icon: const Icon(Icons.verified, size: 16),
                        label: Text(
                          context.tr('Release Escrow', 'एस्क्रो जारी करें'),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConfirmDeliveryOtpDialog(BuildContext context, Map<String, dynamic> order) {
    final expectedOtp = order['deliveryOtp'] as String? ?? '123456';
    final otpController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    context.tr('Confirm Delivery & Release Escrow', 'डिलीवरी पुष्टि करें और एस्क्रो जारी करें'),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkGreen),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Enter your 6-digit Delivery Verification OTP to confirm quality and disburse ₹${(order['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'} from Smart Escrow to ${order['farmerName']}.',
                      'गुणवत्ता पुष्टि करने और स्मार्ट एस्क्रो से ₹${(order['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'} सीधे ${order['farmerName']} को जारी करने के लिए 6-अंकीय ओटीपी दर्ज करें।',
                    ),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  // Auto-fill convenience button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          otpController.text = expectedOtp;
                        });
                      },
                      icon: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryGreen),
                      label: Text(
                        context.tr('Auto-Fill My OTP ($expectedOtp)', 'ओटीपी स्वतः भरें ($expectedOtp)'),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),

                  // OTP Input field
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF8FAF7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final enteredOtp = otpController.text.trim();
                              if (enteredOtp != expectedOtp) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr('❌ Incorrect OTP. Please verify your 6-digit code.', '❌ गलत ओटीपी। कृपया अपना 6-अंकीय कोड सत्यापित करें।')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              // 1. Trigger smart contract confirmDelivery
                              final releaseRes = await SmartContractService.confirmDelivery(
                                contractId: order['contractId'] ?? 'CONTRACT_DEMO',
                                buyerAddress: '0xBuyer_${order['buyerPhone'] ?? '123'}',
                                qualityApproved: true,
                              );

                              // 2. Update Firestore Order Status
                              final orderId = order['orderId'] as String? ?? order['id'] as String;
                              await _dbService.updateRetailOrderStatus(
                                orderId,
                                'delivered',
                                extra: {
                                  'escrowStatus': 'RELEASED',
                                  'settlementTxHash': releaseRes['transactionHash'],
                                  'settledAt': DateTime.now().toIso8601String(),
                                },
                              );

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr(
                                      '✅ Escrow Released! ₹${(order['totalAmount'] as num?)?.toStringAsFixed(0)} settled to ${order['farmerName']} on Polygon block #${releaseRes['blockNumber']}',
                                      '✅ एस्क्रो जारी! ₹${(order['totalAmount'] as num?)?.toStringAsFixed(0)} पॉलीगॉन ब्लॉक #${releaseRes['blockNumber']} पर ${order['farmerName']} को वितरित',
                                    )),
                                    backgroundColor: AppTheme.primaryGreen,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(context.tr('Verify & Release Payment', 'सत्यापित करें और भुगतान जारी करें'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTrackingDetails(BuildContext context, Map<String, dynamic> order) {
    CropTrackingMapSheet.show(context, order, isFarmer: false);
  }
}
