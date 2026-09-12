import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/database_service.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';

/// Screen 10: Farmer Passbook & Payouts (Direct UPI & Tax-Free Agri Income Slip)
class FarmerPayoutHistoryScreen extends StatefulWidget {
  const FarmerPayoutHistoryScreen({super.key});

  @override
  State<FarmerPayoutHistoryScreen> createState() => _FarmerPayoutHistoryScreenState();
}

class _FarmerPayoutHistoryScreenState extends State<FarmerPayoutHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  final List<Map<String, dynamic>> _mockPayouts = [
    {
      'id': 'TXN-90281-UPI',
      'crop': 'Basmati Paddy 1121',
      'cropHi': 'बासमती धान 1121',
      'lotSize': '45 Quintals (2.25 MT)',
      'lotSizeHi': '45 क्विंटल (2.25 मी. टन)',
      'buyer': 'AgroFoods Milling India Pvt Ltd',
      'buyerHi': 'एग्रोफूड्स मिलिंग इंडिया प्रा. लि.',
      'date': '28 Aug 2026, 04:30 PM',
      'amount': 158500.0,
      'status': 'CREDITED',
      'bank': 'State Bank of India •••• 4821',
      'utr': 'UPI/428901829102/AGRI',
      'escrowTxHash': '0x8f7a29...4b91',
      'taxSection': 'Sec 10(1) IT Act (Tax Exempt)',
    },
    {
      'id': 'TXN-88190-UPI',
      'crop': 'Sharbati Wheat (Grade A)',
      'cropHi': 'शरबती गेहूं (ग्रेड ए)',
      'lotSize': '30 Quintals (1.5 MT)',
      'lotSizeHi': '30 क्विंटल (1.5 मी. टन)',
      'buyer': 'Karnal Farmers Producer Co.',
      'buyerHi': 'करनाल फार्मर्स प्रोड्यूसर कं.',
      'date': '19 Aug 2026, 11:15 AM',
      'amount': 84200.0,
      'status': 'CREDITED',
      'bank': 'State Bank of India •••• 4821',
      'utr': 'UPI/428190182736/AGRI',
      'escrowTxHash': '0x1c4d92...8e23',
      'taxSection': 'Sec 10(1) IT Act (Tax Exempt)',
    },
    {
      'id': 'TXN-84102-ESCROW',
      'crop': 'Hybrid Red Onion',
      'cropHi': 'हाइब्रिड लाल प्याज',
      'lotSize': '20 Quintals (1.0 MT)',
      'lotSizeHi': '20 क्विंटल (1.0 मी. टन)',
      'buyer': 'FreshMart Retail Hypermarket',
      'buyerHi': 'फ्रेशमार्ट रिटेल हाइपरमार्केट',
      'date': '12 Aug 2026, 06:45 PM',
      'amount': 54000.0,
      'status': 'CREDITED',
      'bank': 'State Bank of India •••• 4821',
      'utr': 'UPI/427901829441/AGRI',
      'escrowTxHash': '0x6e2b10...9f12',
      'taxSection': 'Sec 10(1) IT Act (Tax Exempt)',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final farmerId = user?.id.isNotEmpty == true ? user!.id : 'farmer_sukhwinder_02';
    final farmerName = user?.name.isNotEmpty == true
        ? user!.name
        : context.tr('Ramesh Kumar (Kisaan)', 'रमेश कुमार (किसान)');
    final location = user?.location ?? context.tr('Karnal, Haryana', 'करनाल, हरियाणा');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamFarmerDbtPayouts(farmerId, farmerPhone: user?.phone),
      builder: (context, snapshot) {
        final livePayouts = (snapshot.data ?? []).map((p) {
          final amt = (p['netDbtPayout'] as num?)?.toDouble() ?? 0.0;
          final qtl = (p['quantityQtl'] as num?)?.toDouble() ?? 0.0;
          final bank = (p['bankName'] ?? 'State Bank of India').toString();
          final mask = (p['maskedAccount'] ?? '•••• 4821').toString();
          final utr = (p['utrNumber'] ?? 'UPI/DBT/2026/AGRI').toString();

          return {
            'id': p['payoutId'] ?? 'DBT-$utr',
            'crop': p['cropName'] ?? 'Sharbati Wheat',
            'cropHi': p['cropName'] ?? 'शरबती गेहूं',
            'lotSize': '${qtl.toStringAsFixed(0)} Quintals',
            'lotSizeHi': '${qtl.toStringAsFixed(0)} क्विंटल',
            'buyer': p['buyerName'] ?? 'Bulk Agro Buyer',
            'buyerHi': p['buyerName'] ?? 'थोक कृषि क्रेता',
            'date': p['creditedAt']?.toString().split('.').first ?? 'Recent',
            'amount': amt,
            'status': 'CREDITED',
            'bank': '$bank $mask',
            'utr': utr,
            'escrowTxHash': '0x9a8f...4b21',
            'taxSection': 'Sec 10(1) IT Act (Tax Exempt)',
            'isDbtLive': true,
          };
        }).toList();

        final allPayouts = [...livePayouts, ..._mockPayouts];

        double totalSeasonRevenue = 0;
        for (var p in allPayouts) {
          totalSeasonRevenue += (p['amount'] as double);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAF7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            foregroundColor: const Color(0xFF1B5E20),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Kisaan Passbook & Payouts', 'किसान पासबुक व भुगतान'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  context.tr('Direct UPI Bank Credits • Polygon Smart Escrow', 'सीधा UPI बैंक भुगतान • पॉलीगॉन स्मार्ट एस्क्रो'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              const LanguageSwitcherPill(isDark: false),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF1B5E20)),
                tooltip: context.tr('Download Tax-Free Income Slip', 'कर-मुक्त आय पर्ची डाउनलोड करें'),
                onPressed: () => _showIncomeSlipDialog(context, farmerName, location, totalSeasonRevenue),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Season Revenue Header Card
              _buildRevenueHeaderCard(totalSeasonRevenue),
              const SizedBox(height: 16),

              // 2. Verified Bank & DBT Account Card
              _buildVerifiedBankCard(farmerName),
              const SizedBox(height: 20),

              // 3. Section Title & Download Slip CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Direct Settlement Ledger', 'प्रत्यक्ष भुगतान खाता (लेजर)'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showIncomeSlipDialog(context, farmerName, location, totalSeasonRevenue),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 14, color: Color(0xFF1B5E20)),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('Tax Exemption Slip', 'कर छूट पर्ची'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Payout Transaction Tiles
              ...allPayouts.map((txn) => _buildPayoutCard(txn)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueHeaderCard(double totalRevenue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Total Season Sales Revenue', 'सत्र की कुल बिक्री आय'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF69F0AE), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('100% Escrow Settled', '100% एस्क्रो भुगतान'),
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
          const SizedBox(height: 8),
          Text(
            '₹${totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCol(
                context.tr('Settled Lots', 'भुगतान किए गए लॉट'),
                context.tr('3 Harvests (4.75 MT)', '3 फसलें (4.75 मी. टन)'),
              ),
              _buildMetricCol(
                context.tr('Avg Realization', 'औसत प्राप्ति'),
                context.tr('₹3,520 / Qtl', '₹3,520 / क्विंटल'),
              ),
              _buildMetricCol(
                context.tr('Tax Liability', 'कर देयता'),
                context.tr('₹0 (Exempted)', '₹0 (पूर्णतः मुक्त)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildVerifiedBankCard(String farmerName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance, color: Color(0xFF1565C0), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('State Bank of India (SBI)', 'भारतीय स्टेट बैंक (SBI)'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.tr('Penny-Drop Verified', 'पेनी-ड्रॉप सत्यापित'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.tr("A/C", "खाता")}: ••••••••4821 | IFSC: SBIN0001290 | ${context.tr("Beneficiary", "लाभार्थी")}: $farmerName',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> txn) {
    final amount = txn['amount'] as double;
    final cropDisplayName = context.tr(txn['crop'].toString(), (txn['cropHi'] ?? txn['crop']).toString());
    final lotDisplayName = context.tr(txn['lotSize'].toString(), (txn['lotSizeHi'] ?? txn['lotSize']).toString());
    final buyerDisplayName = context.tr(txn['buyer'].toString(), (txn['buyerHi'] ?? txn['buyer']).toString());
    final statusText = txn['status'] == 'CREDITED'
        ? context.tr('CREDITED', 'खाते में जमा')
        : txn['status'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_downward, color: Color(0xFF00C853), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    cropDisplayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
              Text(
                '+₹${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${context.tr("Lot", "लॉट")}: $lotDisplayName • ${context.tr("Buyer", "खरीदार")}: $buyerDisplayName',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr("UTR", "यूटीआर")}: ${txn['utr']}',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.grey.shade600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIncomeSlipDialog(BuildContext context, String name, String location, double total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text(
              context.tr('Tax-Free Agri Income Slip', 'कर-मुक्त कृषि आय पर्ची'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                'GOVERNMENT OF INDIA • FORM 16-AGRI (PROVISIONAL)',
                'भारत सरकार • फॉर्म 16-कृषि (अनंतिम)',
              ),
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr("Farmer", "किसान")}: $name',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            Text(
              '${context.tr("Location", "स्थान")}: $location',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr("Total Direct Credit", "कुल प्रत्यक्ष जमा")}: ₹${total.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr(
                  'Statutory Exemption under Section 10(1) of the Income Tax Act, 1961. 100% Tax-Free Agricultural Proceeds.',
                  'आयकर अधिनियम 1961 की धारा 10(1) के तहत वैधानिक छूट। 100% कर-मुक्त कृषि आय।',
                ),
                style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade900),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Close', 'बंद करें')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.tr(
                      'Tax-Free Agriculture Income Slip PDF downloaded to device.',
                      'कर-मुक्त कृषि आय पर्ची PDF डिवाइस पर डाउनलोड हो गई।',
                    ),
                  ),
                  backgroundColor: const Color(0xFF1B5E20),
                ),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: Text(context.tr('Download Official PDF', 'आधिकारिक PDF डाउनलोड करें')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }
}
