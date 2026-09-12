import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/rating_widgets.dart';
import '../../utils/translation_helper.dart';
import '../../models/recurring_order_model.dart';
import '../../services/recurring_order_service.dart';
import 'fpo_recurring_orders_screen.dart';
import 'fpo_member_directory_screen.dart';
import '../login_screen.dart';

/// Screen 5: FPO Profile
/// Styled exactly like the Farmer profile: clean, friendly, warm green tones,
/// with editable settlement bank details, warehouse infrastructure, accreditations, and settings.
class FpoProfileScreen extends StatefulWidget {
  const FpoProfileScreen({super.key});

  @override
  State<FpoProfileScreen> createState() => _FpoProfileScreenState();
}

class _FpoProfileScreenState extends State<FpoProfileScreen> {
  bool _notificationsEnabled = true;

  // Editable settlement bank details
  final _bankAccController = TextEditingController(text: '918273645012');
  final _ifscController = TextEditingController(text: 'SBIN0001824');
  final _bankNameController = TextEditingController(text: 'State Bank of India');
  final _branchController = TextEditingController(text: 'Commercial Branch, GT Road, Karnal');

  @override
  void dispose() {
    _bankAccController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _showEditBankModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Institutional Escrow Bank Details',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Used for automated RTGS escrow releases and direct buyer disbursements.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bankAccController,
                decoration: const InputDecoration(
                  labelText: 'Current Account Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ifscController,
                decoration: const InputDecoration(
                  labelText: 'Bank IFSC Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: 'Branch Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settlement bank account details updated successfully!'),
                        backgroundColor: Color(0xFF2E7D32),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Bank Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';
    final fpoName = (user?.name.isNotEmpty == true && user?.name != 'Demo User')
        ? user!.name
        : 'Karnal Agri Producer Company Limited';
    final email = user?.email ?? 'operations@karnalagrifpo.org';
    final location = user?.location ?? 'Taraori, Karnal, Haryana';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: CustomScrollView(
        slivers: [
          CustomAppBar(
            title: context.tr('FPO Organization Profile', 'एफपीओ संस्था प्रोफ़ाइल'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: LanguageSwitcherPill(isDark: true)),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                children: [
                  // 1. Profile Header Card (Matching Farmer Profile Card)
                  _buildProfileHeaderCard(fpoName, email, location),
                  const SizedBox(height: 16),

                  // 2. Organization Stats Row
                  _buildStatsRow(),
                  const SizedBox(height: 16),

                  // 2a. Member Farmer Directory (Excel Onboarding & Pro-Rata DBT)
                  _buildMemberFarmerDirectoryCard(fpoId),
                  const SizedBox(height: 16),

                  // 2b. Institutional Contracts & Recurring Buyer Proposals Card
                  _buildRecurringOrdersCard(fpoId),
                  const SizedBox(height: 16),

                  // 2c. Institutional Reputation & Ratings Card
                  _buildReputationAndRatingsCard(),
                  const SizedBox(height: 16),

                  // 3. Bank Account Card (Matching Farmer Bank Card)
                  _buildBankAndSettlementCard(),
                  const SizedBox(height: 16),

                  // 4. Warehouse Infrastructure Card
                  _buildWarehouseInfrastructureCard(),
                  const SizedBox(height: 16),

                  // 5. Verification & Accreditations Card
                  _buildAccreditationsCard(),
                  const SizedBox(height: 16),

                  // 6. Settings & Preferences Card
                  _buildSettingsCard(appState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Profile Header Card (avatar, verified check, organization name)
  Widget _buildProfileHeaderCard(String name, String email, String location) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'K',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 18),
                  ],
                ),
                Text(
                  'CIN: U01111HR2023PTC109284 • Sec 378A Co.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 13, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3-Stat row: Warehouses, Capacity, Members
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSingleStat(context.tr('Silo Capacity', 'साइलो क्षमता'), '5,000 ${context.tr("Qtl", "क्विंटल")}', Icons.warehouse),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _buildSingleStat(context.tr('Current Stock', 'वर्तमान स्टॉक'), '4,300 ${context.tr("Qtl", "क्विंटल")}', Icons.inventory_2),
          Container(width: 1, height: 32, color: Colors.grey.shade200),
          _buildSingleStat(context.tr('Co-op Status', 'सहकारी स्थिति'), context.tr('Verified', 'सत्यापित'), Icons.verified_user),
        ],
      ),
    );
  }

  Widget _buildSingleStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ],
    );
  }

  /// Member Farmer Directory Card
  Widget _buildMemberFarmerDirectoryCard(String fpoId) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FpoMemberDirectoryScreen()),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.people_alt, color: Color(0xFF15803D), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.tr('Member Farmer Directory', 'सदस्य किसान प्रबंधन'),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DBT Ready',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Excel/CSV bulk onboarding, verified bank accounts & pro-rata DBT mapping',
                          'एक्सेल रोस्टर आयात, सत्यापित बैंक खाते और आनुपातिक डीबीटी प्रबंधन',
                        ),
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF15803D)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bank & Settlement Card with Edit button
  Widget _buildBankAndSettlementCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: Color(0xFF2E7D32), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('Direct Settlement Bank Account', 'सीधा भुगतान बैंक खाता'),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showEditBankModal,
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2E7D32)),
                tooltip: context.tr('Edit Bank Details', 'बैंक विवरण संपादित करें'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBankField(context.tr('Bank Name', 'बैंक का नाम'), _bankNameController.text),
          _buildBankField(context.tr('Current Account', 'चालू खाता'), '•••• •••• •••• ${_bankAccController.text.substring((_bankAccController.text.length - 4).clamp(0, _bankAccController.text.length))}'),
          _buildBankField(context.tr('IFSC Code', 'आईएफएससी कोड'), _ifscController.text),
          _buildBankField(context.tr('Branch', 'शाखा'), _branchController.text),
          _buildBankField(context.tr('Payout Method', 'भुगतान विधि'), context.tr('Direct RTGS / Escrow Auto-Release', 'सीधा RTGS / एस्क्रो ऑटो-रिलीज़')),
        ],
      ),
    );
  }

  Widget _buildBankField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  /// Warehouse Infrastructure Card
  Widget _buildWarehouseInfrastructureCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.domain, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('Warehouse & Silos Infrastructure', 'गोदाम व साइलो ढांचा'),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfrastructureTile(
            context.tr('Central Silo Complex 01', 'केंद्रीय साइलो परिसर 01'),
            context.tr('3 Steel Silos (5,000 Qtl) • NH-44 GT Road, Taraori', '3 स्टील साइलो (5,000 क्विंटल) • NH-44 जीटी रोड, तरावड़ी'),
            true,
          ),
          const SizedBox(height: 8),
          _buildInfrastructureTile(
            context.tr('60-Tonne Electronic Weighbridge', '60-टन इलेक्ट्रॉनिक धर्मकांटा'),
            context.tr('Calibrated by Legal Metrology Haryana • Fastag linked', 'हरियाणा विधिक माप विज्ञान द्वारा सत्यापित • फास्टैग संबद्ध'),
            true,
          ),
          const SizedBox(height: 8),
          _buildInfrastructureTile(
            context.tr('On-Site Quality Lab & Assaying', 'ऑन-साइट गुणवत्ता लैब व परीक्षण'),
            context.tr('NABL Certified Moisture Meters & Purity Analyzers', 'NABL प्रमाणित नमी मीटर और शुद्धता विश्लेषक'),
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfrastructureTile(String title, String subtitle, bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Accreditations & Tax IDs
  Widget _buildAccreditationsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_outlined, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('Statutory Accreditations & Licenses', 'वैधानिक मान्यताएं व लाइसेंस'),
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBadge('SFAC / NABARD', context.tr('Status: Active', 'स्थिति: सक्रिय'), const Color(0xFF15803D)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBadge('GSTIN', '06AABCK9928P1Z8', const Color(0xFF0284C7)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBadge(context.tr('FSSAI Central Lic.', 'FSSAI केंद्रीय लाइसेंस'), '1002302200192', const Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBadge(context.tr('Corporate PAN', 'कॉर्पोरेट पैन'), 'AABCK9928P', const Color(0xFF7C3AED)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  /// Settings & Logout
  Widget _buildSettingsCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Settings & Preferences', 'ऐप सेटिंग्स और प्राथमिकताएं'),
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate, color: Color(0xFF2E7D32), size: 20),
            title: Text(
              context.tr('Language / भाषा', 'भाषा / Language'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            trailing: const LanguageSwitcherPill(isDark: false),
          ),
          const Divider(height: 16),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Order & Dispatch Alerts', 'ऑर्डर व डिस्पैच सूचनाएं'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('Get instant notifications on buyer RFQs and payments', 'खरीदार पूछताछ और भुगतान पर तत्काल सूचनाएं प्राप्त करें'), style: const TextStyle(fontSize: 11)),
            value: _notificationsEnabled,
            activeThumbColor: const Color(0xFF2E7D32),
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          const Divider(height: 16),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: Color(0xFF2E7D32), size: 20),
            title: Text(context.tr('Help & FPO Co-op Support', 'सहायता व एफपीओ हेल्पडेस्क'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Connecting to AgriChain 24/7 FPO Desk: 1800-AGRI-FPO')),
              );
            },
          ),
          const Divider(height: 16),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red, size: 20),
            title: Text(context.tr('Logout', 'लॉग आउट'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              appState.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Institutional Contracts & Recurring Buyer Proposals Card
  Widget _buildRecurringOrdersCard(String fpoId) {
    return StreamBuilder<List<RecurringOrderModel>>(
      stream: RecurringOrderService().streamFpoOrders(fpoId),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final pending = orders.where((o) => o.status == 'pending_fpo_approval').toList();
        final active = orders.where((o) => o.status == 'active_contract').toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: pending.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
              width: pending.isNotEmpty ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.repeat, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('12-Week Supply Agreements', '12-सप्ताह आपूर्ति अनुबंध'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (pending.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pending.length} ${context.tr("NEW", "नया")}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                pending.isNotEmpty
                  ? context.tr(
                      'You have ${pending.length} incoming institutional procurement proposal(s) awaiting your acceptance.',
                      'आपके पास ${pending.length} नए संस्थागत खरीद प्रस्ताव स्वीकृति हेतु प्रतीक्षारत हैं।',
                    )
                  : context.tr(
                      'Manage automated weekly Monday grain dispatches and guaranteed corporate bulk buying contracts.',
                      'साप्ताहिक सोमवार अनाज प्रेषण और गारंटीकृत कॉर्पोरेट थोक खरीद अनुबंधों का प्रबंधन करें।',
                    ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Active Contracts', 'सक्रिय अनुबंध'), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            '${active.length} ${context.tr("Active", "सक्रिय")}',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Pending Requests', 'लंबित अनुरोध'), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(
                            '${pending.length} ${context.tr("Requests", "अनुरोध")}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: pending.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FpoRecurringOrdersScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                  label: Text(
                    pending.isNotEmpty
                        ? '${context.tr("Review Buyer Proposals", "खरीदार प्रस्ताव देखें")} (${pending.length})'
                        : context.tr('Open Recurring Agreements', 'आवर्ती अनुबंध खोलें'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pending.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF1B5E20),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Institutional Reputation & Ratings Card
  Widget _buildReputationAndRatingsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('FPO Trust & Quality Rating', 'एफपीओ प्रतिष्ठा व गुणवत्ता रेटिंग'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 12, color: Color(0xFF15803D)),
                    SizedBox(width: 3),
                    Text(
                      'TOP RATED FPO',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rating Score Header
          Row(
            children: [
              Text(
                '4.88',
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StarRatingDisplay(rating: 4.88, size: 18, activeColor: Colors.amber),
                  const SizedBox(height: 3),
                  const Text(
                    'Based on 42 Institutional & Wholesale Contracts',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Breakdown metrics
          _buildRatingMetricRow('Weighbridge & Assay Accuracy', 0.98, '4.9'),
          const SizedBox(height: 8),
          _buildRatingMetricRow('Dispatch Punctuality & Lead Time', 0.96, '4.8'),
          const SizedBox(height: 8),
          _buildRatingMetricRow('Constituent Traceability & Compliance', 1.0, '5.0'),
          const SizedBox(height: 16),

          // Verified Reviews Snippet
          Container(
            padding: const EdgeInsets.all(12),
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
                      'AgroFoods Milling India Pvt Ltd',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF0F172A)),
                    ),
                    const Text('⭐ 5.0 • 2 weeks ago', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '"Flawless 1200 Qtl Sharbati Wheat supply. Moisture tested accurately at 11.2% NABL standard. Highly recommend this FPO silo complex."',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingMetricRow(String label, double value, String score) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(score, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
