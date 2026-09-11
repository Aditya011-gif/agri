import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/buyer_plant_model.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import '../login_screen.dart';

class BulkBuyerProfileScreen extends StatefulWidget {
  const BulkBuyerProfileScreen({super.key});

  @override
  State<BulkBuyerProfileScreen> createState() => _BulkBuyerProfileScreenState();
}

class _BulkBuyerProfileScreenState extends State<BulkBuyerProfileScreen> {
  List<BuyerDeliveryPlant> _plants = [];
  bool _isLoadingPlants = true;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    final plants = await BuyerDeliveryPlant.loadSavedPlants();
    if (mounted) {
      setState(() {
        _plants = plants;
        _isLoadingPlants = false;
      });
    }
  }

  Future<void> _setPrimaryPlant(String id) async {
    final updated = await BuyerDeliveryPlant.setPrimary(id);
    if (mounted) {
      setState(() => _plants = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Primary delivery plant updated successfully!', 'प्राथमिक डिलीवरी संयंत्र सफलतापूर्वक अपडेट किया गया!'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final companyName = user?.name.isNotEmpty == true
        ? user!.name
        : 'AgroFoods Milling India Pvt Ltd';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('Company & KYC Profile', 'कंपनी और केवाईसी प्रोफ़ाइल'),
            actions: const [LanguageSwitcherPill(isDark: true)],
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Company Header Badge Card
            _buildCompanyCard(companyName, user?.location ?? 'Pune, Maharashtra'),

            const SizedBox(height: 16),

            // Statutory GSTIN & Corporate KYC
            _buildSectionHeader(context.tr('Statutory & Corporate KYC', 'वैधानिक और कॉर्पोरेट केवाईसी')),
            _buildInfoCard([
              _buildInfoRow('GSTIN', '06AAACA0000A1Z5', isVerified: true),
              _buildInfoRow('PAN', 'AAACA0000A', isVerified: true),
              _buildInfoRow('CIN', 'U01100MH2018PTC304912', isVerified: true),
              _buildInfoRow(
                context.tr('Enterprise Type', 'उद्यम प्रकार'),
                context.tr('Large Corporate / Agro Processor', 'बड़ा कॉर्पोरेट / कृषि प्रसंस्करणकर्ता'),
              ),
            ]),

            const SizedBox(height: 16),

            // Statutory Licenses & Certifications
            _buildSectionHeader(context.tr('Mandatory Licenses & Documents', 'अनिवार्य लाइसेंस और दस्तावेज़')),
            _buildInfoCard([
              _buildDocRow('FSSAI Central License', 'Lic #10019022009182', context.tr('Valid till Dec 2028', 'दिसंबर 2028 तक वैध'), true),
              _buildDocRow('APEDA Export Registration', 'Reg #APEDA/RCMC/7781', context.tr('Active', 'सक्रिय'), true),
              _buildDocRow('State Mandi Trading License', 'Lic #MND/PUN/8821', context.tr('Active', 'सक्रिय'), true),
            ]),

            const SizedBox(height: 16),

            // Corporate Escrow & Virtual Payment Account
            _buildSectionHeader(context.tr('Corporate Escrow & Payments', 'कॉर्पोरेट एस्क्रो और भुगतान')),
            _buildEscrowAccountCard(),

            const SizedBox(height: 16),

            // Saved Delivery Locations / Processing Plants
            _buildSectionHeader(context.tr('Saved Delivery Plants & Silos', 'सहेजे गए डिलीवरी संयंत्र व साइलो')),
            _buildSavedPlantsCard(),

            const SizedBox(height: 16),

            // Team & User Roles
            _buildSectionHeader(context.tr('Procurement Team & Authorizations', 'खरीद टीम और अनुमतियाँ')),
            _buildTeamCard(),

            const SizedBox(height: 24),

            // Account Settings & Sign Out
            _buildSettingsAndLogout(context, appState),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyCard(String companyName, String location) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.corporate_fare, color: Colors.white, size: 30),
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
                        companyName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 18),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${context.tr('Milling Capacity', 'मिलिंग क्षमता')}: 12,000 ${context.tr('Qtl', 'क्विंटल')} / ${context.tr('Day', 'दिन')}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isVerified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(String name, String id, String status, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(id, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrowAccountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: Color(0xFF1565C0), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('Dedicated Institutional Escrow Account', 'समर्पित संस्थागत एस्क्रो खाता'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.tr('Active', 'सक्रिय'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow(context.tr('Virtual Account No (VAN)', 'वर्चुअल खाता संख्या (VAN)'), 'AGRI990184920'),
          _buildInfoRow(context.tr('IFSC Code', 'आईएफएससी कोड'), 'UTIB0000001 (Axis Bank)'),
          _buildInfoRow(context.tr('Available Escrow Credit', 'उपलब्ध एस्क्रो क्रेडिट'), '₹2.50 ${context.tr('Crore', 'करोड़')}'),
          _buildInfoRow(context.tr('Settlement Mode', 'निपटान मोड'), context.tr('Instant RTGS on Weighbridge Pass', 'वेब्रिज पास पर तत्काल आरटीजीएस')),
        ],
      ),
    );
  }

  Widget _buildSavedPlantsCard() {
    if (_isLoadingPlants) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32), strokeWidth: 2)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < _plants.length; i++) ...[
            if (i > 0) const Divider(height: 18),
            _buildPlantItem(_plants[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPlantItem(BuyerDeliveryPlant plant) {
    return InkWell(
      onTap: () => _setPrimaryPlant(plant.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: plant.isPrimary ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.factory_outlined,
                color: plant.isPrimary ? const Color(0xFF2E7D32) : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plant.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (plant.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.tr('Primary Delivery Hub', 'प्राथमिक डिलीवरी हब'),
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => _setPrimaryPlant(plant.id),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(context.tr('Set Primary', 'प्राथमिक बनाएं'), style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(plant.address, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed, size: 10, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Text(
                              '${plant.latitude.toStringAsFixed(4)}° N, ${plant.longitude.toStringAsFixed(4)}° E',
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        plant.corridorName,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
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
  }

  Widget _buildTeamCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamMemberRow('Vikram Mehta', context.tr('VP — Global Procurement', 'उपाध्यक्ष — वैश्विक खरीद'), context.tr('Full Access (PO & Escrow)', 'पूर्ण पहुँच (पीओ व एस्क्रो)')),
          const Divider(height: 16),
          _buildTeamMemberRow('Sunil Rao', context.tr('Chief Quality Inspector', 'मुख्य गुणवत्ता निरीक्षक'), context.tr('Lab Clearance & Inspection', 'प्रयोगशाला क्लीयरेंस व निरीक्षण')),
          const Divider(height: 16),
          _buildTeamMemberRow('Pooja Nair', context.tr('Senior Accounts Manager', 'वरिष्ठ लेखा प्रबंधक'), context.tr('Tax Invoices & Reconciliation', 'कर चालान और मिलान')),
        ],
      ),
    );
  }

  Widget _buildTeamMemberRow(String name, String role, String access) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE8F5E9),
          child: Text(
            name.substring(0, 1),
            style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(role, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Text(access, style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSettingsAndLogout(BuildContext context, AppState appState) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.support_agent, color: Color(0xFF2E7D32)),
                title: Text(context.tr('24x7 Institutional Key Account Manager', '24x7 संस्थागत प्रमुख खाता प्रबंधक'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('+91 8000 442 990 • support@agrichain.in', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.security, color: Color(0xFF1565C0)),
                title: Text(context.tr('Enterprise Security & 2FA', 'एंटरप्राइज सुरक्षा और 2FA'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () async {
              await appState.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text(context.tr('Sign Out of Corporate Account', 'कॉर्पोरेट खाते से साइन आउट करें'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
