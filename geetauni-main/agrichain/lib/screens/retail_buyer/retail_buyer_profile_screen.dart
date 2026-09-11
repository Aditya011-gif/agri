import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../utils/translation_helper.dart';
import '../../widgets/language_switcher.dart';
import '../login_screen.dart';

class RetailBuyerProfileScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const RetailBuyerProfileScreen({super.key, this.onNavigateTab});

  @override
  State<RetailBuyerProfileScreen> createState() => _RetailBuyerProfileScreenState();
}

class _RetailBuyerProfileScreenState extends State<RetailBuyerProfileScreen> {
  bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('My Profile', 'मेरी प्रोफ़ाइल'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            Text(
              context.tr('Personal Details & Settings', 'व्यक्तिगत विवरण और सेटिंग्स'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // 1. User Info Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    child: Text(
                      (user?.name.isNotEmpty ?? false)
                          ? user!.name[0].toUpperCase()
                          : 'R',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.name ?? context.tr('Retail Buyer', 'खुदरा खरीदार'),
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkGreen,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: AppTheme.primaryGreen, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'buyer@agrichain.com',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('Verified Retail Customer', 'सत्यापित खुदरा ग्राहक'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Profile Options List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.person_outline,
                    title: context.tr('My Details', 'मेरा विवरण'),
                    subtitle: context.tr('Name, Phone number, Email address', 'नाम, फ़ोन नंबर, ईमेल पता'),
                    onTap: () => _showDetailsModal(context, user?.name, user?.email, user?.phone),
                  ),
                  _buildDivider(),
                  _buildProfileTile(
                    icon: Icons.location_on_outlined,
                    title: context.tr('My Delivery Address', 'मेरा डिलीवरी पता'),
                    subtitle: context.tr('Flat 402, Green Avenue, Delhi NCR', 'फ्लैट 402, ग्रीन एवेन्यू, दिल्ली एनसीआर'),
                    onTap: () => _showAddressModal(context),
                  ),
                  _buildDivider(),
                  _buildProfileTile(
                    icon: Icons.payment_outlined,
                    title: context.tr('Payment & UPI', 'भुगतान और यूपीआई'),
                    subtitle: context.tr('Google Pay, PhonePe, Cards, Net Banking', 'गूगल पे, फोनपे, कार्ड, नेट बैंकिंग'),
                    onTap: () => _showPaymentModal(context),
                  ),
                  _buildDivider(),
                  _buildProfileTile(
                    icon: Icons.shopping_bag_outlined,
                    title: context.tr('My Orders', 'मेरे ऑर्डर'),
                    subtitle: context.tr('View recent purchases and delivery status', 'हालिया खरीदारी और डिलीवरी स्थिति देखें'),
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Settings & Preferences
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined, color: AppTheme.primaryGreen),
                    title: Text(
                      context.tr('Notifications', 'सूचनाएं'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      context.tr('Harvest alerts and order tracking updates', 'फसल अलर्ट और ऑर्डर ट्रैकिंग अपडेट'),
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: _pushNotifications,
                    activeThumbColor: AppTheme.primaryGreen,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language, color: AppTheme.primaryGreen, size: 20),
                    ),
                    title: Text(
                      context.tr('Language / भाषा', 'भाषा / Language'),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
                    ),
                    subtitle: Text(
                      context.isHindi ? 'हिंदी (Hindi)' : 'English (EN)',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: const LanguageSwitcherPill(isDark: false),
                    onTap: () => LanguageSelectorSheet.show(context),
                  ),
                  _buildDivider(),
                  _buildProfileTile(
                    icon: Icons.headset_mic_outlined,
                    title: context.tr('Help & Customer Support', 'मदद और ग्राहक सहायता'),
                    subtitle: context.tr('24x7 Customer Helpline, FAQs, Dispute Resolution', '24x7 ग्राहक हेल्पलाइन, प्रश्न, विवाद समाधान'),
                    onTap: () => _showHelpModal(context),
                  ),
                  _buildDivider(),
                  _buildProfileTile(
                    icon: Icons.security_outlined,
                    title: context.tr('Privacy & Terms', 'गोपनीयता और शर्तें'),
                    subtitle: context.tr('AgriChain Direct Buyer Guarantee', 'एग्रीचेन प्रत्यक्ष खरीदार गारंटी'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('AgriChain Buyer Protection is 100% active.', 'एग्रीचेन खरीदार सुरक्षा 100% सक्रिय है।'))),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Provider.of<AppState>(context, listen: false).signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(
                  context.tr('Sign Out', 'लॉग आउट'),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkGreen),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100, indent: 60);

  void _showDetailsModal(BuildContext context, String? name, String? email, String? phone) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('My Details', 'मेरा विवरण'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildDetailRow(context.tr('Full Name', 'पूरा नाम'), name ?? context.tr('Retail Buyer', 'खुदरा खरीदार')),
                _buildDetailRow(context.tr('Email', 'ईमेल'), email ?? 'buyer@agrichain.com'),
                _buildDetailRow(context.tr('Phone', 'फ़ोन'), phone ?? '+91 98765 00000'),
                _buildDetailRow(context.tr('Account Type', 'खाता प्रकार'), context.tr('Direct Retail Customer', 'प्रत्यक्ष खुदरा ग्राहक')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('Close', 'बंद करें')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showAddressModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('My Delivery Address', 'मेरा डिलीवरी पता'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Home (Primary)', 'घर (प्राथमिक)'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          Text(
                            'Flat 402, Green Avenue, Sector 18, Delhi NCR - 110085',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Done', 'पूर्ण')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Payment Methods', 'भुगतान के तरीके'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryGreen),
                title: Text(context.tr('UPI ID (Google Pay / PhonePe)', 'यूपीआई आईडी (गूगल पे / फोनपे)')),
                subtitle: const Text('user@okhdfcbank'),
                trailing: const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.grey),
                title: Text(context.tr('HDFC Bank Visa Card', 'एचडीएफसी बैंक वीज़ा कार्ड')),
                subtitle: const Text('•••• •••• •••• 4092'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Done', 'पूर्ण')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Customer Support', 'ग्राहक सहायता'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.phone, color: AppTheme.primaryGreen),
                title: Text(context.tr('Toll Free Helpline', 'टोल फ्री हेल्पलाइन')),
                subtitle: const Text('1800-200-FARM (9 AM - 8 PM)'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('Calling toll-free helpline...', 'टोल-फ्री हेल्पलाइन पर कॉल किया जा रहा है...'))),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.email, color: AppTheme.primaryGreen),
                title: Text(context.tr('Email Support', 'ईमेल सहायता')),
                subtitle: const Text('support@agrichain.in'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Close', 'बंद करें')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
