import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';

/// Screen 4: FPO Earnings & Confirmed Settlements Passbook
/// Clean, simple passbook matching the Farmer app, showing exactly how much
/// the FPO has made, what is confirmed, and what is in escrow.
class FpoSettlementScreen extends StatefulWidget {
  const FpoSettlementScreen({super.key});

  @override
  State<FpoSettlementScreen> createState() => _FpoSettlementScreenState();
}

class _FpoSettlementScreenState extends State<FpoSettlementScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFpoOrders(fpoId: fpoId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final List<Map<String, dynamic>> settlementRecords = [];

        for (final o in orders) {
          final isDelivered = (o['status'] == 'completed' || o['status'] == 'delivered');
          final isEscrow = !isDelivered;
          final gross = (o['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final freight = gross * 0.015;
          final cess = gross * 0.005;
          final fee = gross * 0.002;
          final net = gross - freight - cess - fee;

          settlementRecords.add({
            'orderId': o['orderId'] ?? o['id'] ?? 'ORD',
            'type': o['isMultiFpo'] == true ? 'Multi-FPO Shared Order' : 'Single FPO Direct Order',
            'buyer': o['buyerName'] ?? o['buyer'] ?? 'Institutional Buyer',
            'crop': o['cropName'] ?? o['crop'] ?? 'Produce',
            'yourShareMT': (((o['quantityQtl'] as num?)?.toDouble() ?? 0.0) / 10.0),
            'date': o['createdAt']?.toString().split('T').first ?? 'Recent',
            'grossAmount': gross,
            'freightDeduction': freight,
            'mandiCessDeduction': cess,
            'platformFee': fee,
            'netAmount': net > 0 ? net : gross,
            'status': isEscrow ? 'IN ESCROW' : 'CREDITED TO BANK',
            'statusColor': isEscrow ? const Color(0xFFD97706) : const Color(0xFF15803D),
            'utr': 'TXN-${o['id'] ?? '8910'}',
            'bank': 'State Bank of India •••• 2019',
            'isEscrow': isEscrow,
          });
        }

        // Calculate totals
        double totalConfirmedMade = 0.0;
        double totalInEscrow = 0.0;

        for (var r in settlementRecords) {
          if (r['isEscrow'] == true) {
            totalInEscrow += (r['netAmount'] as double);
          } else {
            totalConfirmedMade += (r['netAmount'] as double);
          }
        }

        final filteredList = settlementRecords.where((r) {
          if (_selectedFilter == 'Confirmed') return r['isEscrow'] == false;
          if (_selectedFilter == 'In Escrow') return r['isEscrow'] == true;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.backgroundGreen,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            foregroundColor: const Color(0xFF1B5E20),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Earnings & Settlements', 'आय व भुगतान (पेआउट)'),
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  context.tr(
                    'Direct Commercial Bank Credits • Smart Escrow Passbook',
                    'सीधा व्यावसायिक बैंक भुगतान • स्मार्ट एस्क्रो पासबुक',
                  ),
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
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Big Confirmed Earnings Banner Card (Matching Farmer Passbook)
                _buildEarningsSummaryCard(totalConfirmedMade, totalInEscrow),
                const SizedBox(height: 16),

                // 2. Linked Settlement Bank Account Card
                _buildSettlementBankCard(),
                const SizedBox(height: 20),

                // 3. Filter Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('Settlement Passbook', 'भुगतान पासबुक'),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      children: ['All', 'Confirmed', 'In Escrow'].map((filter) {
                        final isSel = _selectedFilter == filter;
                        final filterDisplay = filter == 'All'
                            ? context.tr('All', 'सभी')
                            : (filter == 'Confirmed'
                                ? context.tr('Confirmed', 'पुष्ट')
                                : context.tr('In Escrow', 'एस्क्रो में'));
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(filterDisplay),
                            selected: isSel,
                            selectedColor: const Color(0xFF2E7D32),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. List of Settlement Transaction Cards or Clean Empty State
                if (filteredList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 56,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('No Settlements Yet', 'कोई भुगतान रिकॉर्ड नहीं'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'Commercial payouts and escrow releases from completed bulk orders will credit your verified bank account and appear here.',
                            'पूर्ण थोक ऑर्डर से व्यावसायिक भुगतान व एस्क्रो रिलीज़ आपके सत्यापित बैंक खाते में जमा होकर यहां दिखाई देंगे।',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredList.map((record) => _buildSettlementCard(record)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEarningsSummaryCard(double confirmed, double inEscrow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Total Confirmed Earnings', 'कुल पुष्ट आय'),
                style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 12, color: Color(0xFF69F0AE)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('100% Tax-Exempt Sec 10(1)', '100% कर-मुक्त धारा 10(1)'),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${(confirmed / 100000).toStringAsFixed(2)} ${context.tr("Lakhs", "लाख")}',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '${context.tr("Exact", "वास्तविक")}: ₹${confirmed.toStringAsFixed(0)} ${context.tr("credited directly to bank account", "सीधे बैंक खाते में जमा")}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Divider(height: 24, color: Colors.white24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Active in Escrow', 'एस्क्रो में सक्रिय'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '₹${(inEscrow / 100000).toStringAsFixed(2)} ${context.tr("Lakhs", "लाख")}',
                      style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Settled Orders', 'संपन्न ऑर्डर'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('3 Orders Completed', '3 ऑर्डर संपन्न'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementBankCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance, color: Color(0xFF2E7D32), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('State Bank of India (Commercial A/C)', 'भारतीय स्टेट बैंक (व्यावसायिक खाता)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                ),
                Text(
                  '${context.tr("A/C", "खाता")}: •••• •••• •••• 2019 • IFSC: SBIN0001824',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  context.tr('Auto-credit via NACH / RTGS upon buyer delivery', 'खरीदार डिलीवरी पर NACH / RTGS द्वारा स्वतः जमा'),
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> item) {
    final isEscrow = item['isEscrow'] as bool;
    final netAmount = item['netAmount'] as double;
    final statusColor = item['statusColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showSettlementBreakdownModal(item),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: order id & status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['orderId'] as String,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['type'] == 'Multi-FPO Shared Order'
                            ? context.tr('Multi-FPO Shared Order', 'मल्टी-FPO साझा ऑर्डर')
                            : context.tr('Single FPO Direct Order', 'प्रत्यक्ष FPO ऑर्डर'),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      isEscrow
                          ? context.tr('IN ESCROW', 'एस्क्रो में')
                          : context.tr('CREDITED TO BANK', 'बैंक में जमा'),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Buyer, crop, and Net Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['crop'] as String,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${item['buyer']} • ${((item['yourShareMT'] as double) * 10).toStringAsFixed(0)} ${context.tr("Qtl", "क्विंटल")}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+ ₹${netAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isEscrow ? const Color(0xFFD97706) : const Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        isEscrow
                            ? context.tr('Awaiting Release', 'भुगतान प्रतीक्षारत')
                            : context.tr('Net Credited', 'शुद्ध जमा'),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),

              // Bottom details row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isEscrow ? Icons.lock_clock : Icons.receipt_long, size: 13, color: const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Ref: ${item['utr']}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(context.tr('View Slip', 'पर्ची देखें'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2E7D32)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettlementBreakdownModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Settlement Breakdown Slip', 'भुगतान विवरण पर्ची'),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                '${context.tr("Order", "ऑर्डर")}: ${item['orderId']} • ${context.tr("Buyer", "खरीदार")}: ${item['buyer']}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),

              _buildModalSlipRow(context.tr('Crop & Weight', 'फसल व वजन'), '${item['crop']} (${((item['yourShareMT'] as double) * 10).toStringAsFixed(0)} ${context.tr("Qtl", "क्विंटल")})'),
              _buildModalSlipRow(context.tr('Gross Agreed Value', 'सकल तय मूल्य'), '₹${(item['grossAmount'] as double).toStringAsFixed(0)}'),
              _buildModalSlipRow(context.tr('Freight Deduction', 'मालभाड़ा कटौती'), '- ₹${(item['freightDeduction'] as double).toStringAsFixed(0)}', isDeduction: true),
              _buildModalSlipRow(context.tr('Mandi Cess (0.5%)', 'मंडी उपकर (0.5%)'), '- ₹${(item['mandiCessDeduction'] as double).toStringAsFixed(0)}', isDeduction: true),
              _buildModalSlipRow(context.tr('Platform Tech Fee (0.2%)', 'प्लेटफ़ॉर्म तकनीकी शुल्क (0.2%)'), '- ₹${(item['platformFee'] as double).toStringAsFixed(0)}', isDeduction: true),
              const Divider(height: 16),
              _buildModalSlipRow(
                context.tr('Net Credited Payout', 'शुद्ध जमा भुगतान'),
                '₹${(item['netAmount'] as double).toStringAsFixed(0)}',
                isHighlight: true,
              ),
              const SizedBox(height: 10),
              _buildModalSlipRow(context.tr('Settled Into', 'जमा खाता'), item['bank'] as String),
              _buildModalSlipRow(context.tr('Banking UTR', 'बैंकिंग यूटीआर'), item['utr'] as String),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Tax-Exempt Settlement Slip downloaded (PDF).', 'कर-मुक्त भुगतान पर्ची PDF डाउनलोड हो गई।')),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(context.tr('Download Commercial Settlement Slip (PDF)', 'व्यावसायिक भुगतान पर्ची डाउनलोड करें (PDF)')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalSlipRow(String label, String value, {bool isDeduction = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 12,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? const Color(0xFF15803D)
                  : (isDeduction ? Colors.red.shade700 : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
