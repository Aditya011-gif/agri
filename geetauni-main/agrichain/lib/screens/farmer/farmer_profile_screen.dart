import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/language_switcher.dart';
import '../../widgets/signature_pad_dialog.dart';
import '../../services/database_service.dart';
import '../../services/whatsapp_kisan_service.dart';
import '../../widgets/rating_widgets.dart';
import '../../utils/translation_helper.dart';
import '../login_screen.dart';
import 'mint_land_nft_screen.dart';
import 'land_analysis_screen.dart';

class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({super.key});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _notificationsEnabled = true;

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  // Editable Bank/UPI details
  final _bankAccController = TextEditingController(text: '918273645012');
  final _ifscController = TextEditingController(text: 'HDFC0001824');
  final _upiController = TextEditingController(text: 'ramesh.farmer@oksbi');
  final _khasraController = TextEditingController(text: 'Khasra #42/18, Acreage: 6.5 Acres');

  @override
  void dispose() {
    _bankAccController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    _khasraController.dispose();
    super.dispose();
  }

  void _showBankUpiModal() {
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
              Text(
                context.tr('Direct Settlement Bank & UPI Details', 'सीधा भुगतान बैंक व यूपीआई विवरण'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Used for instant IMPS and UPI payouts from retail buyers and FPO procurement.',
                  'खुदरा खरीदारों और एफपीओ खरीद से तत्काल आईएमपीएस और यूपीआई भुगतान के लिए उपयोग किया जाता है।',
                ),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bankAccController,
                decoration: InputDecoration(
                  labelText: context.tr('Bank Account Number', 'बैंक खाता संख्या'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ifscController,
                decoration: InputDecoration(
                  labelText: context.tr('Bank IFSC Code', 'बैंक आईएफएससी कोड'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.pin),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiController,
                decoration: InputDecoration(
                  labelText: context.tr('UPI ID (VPA)', 'यूपीआई आईडी (VPA)'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Bank and UPI payout details updated successfully!', 'बैंक और यूपीआई भुगतान विवरण सफलतापूर्वक अपडेट किया गया!')),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(context.tr('Save Payout Details', 'भुगतान विवरण सहेजें'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final farmerId = user?.id ?? '';
    final farmerName = (user != null && user.name.isNotEmpty) ? user.name : 'Member Farmer';
    final email = user?.email ?? 'farmer@agrichain.in';
    final location = (user?.location != null && user!.location!.isNotEmpty) ? user.location! : 'Karnal, Haryana';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGreen,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: context.tr('Farmer Profile', 'किसान प्रोफ़ाइल'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: LanguageSwitcherPill(isDark: true)),
              ),
            ],
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Farmer Header Card
            _buildProfileHeaderCard(farmerName, email, location),
            const SizedBox(height: 18),

            // Farmer Trust & Rating Card
            _buildFarmerReputationCard(),
            const SizedBox(height: 18),

            // WhatsApp Kisan Assistant (Auto-Connect & Status)
            _buildWhatsAppKisanAssistantCard(appState),
            const SizedBox(height: 18),

            // Land & GIS Verification Card
            _buildLandAndGisCard(),
            const SizedBox(height: 18),

            // Digital Signature & DigiLocker Card
            _buildDigitalSignatureAndDigiLockerCard(appState),
            const SizedBox(height: 18),

            // Bank & UPI Details Card
            _buildBankAndUpiCard(),
            const SizedBox(height: 18),

            // Payout History Card
            _buildPayoutHistoryCard(farmerId),
            const SizedBox(height: 18),

            // Farmer Documents & Certifications
            _buildDocumentsCard(),
            const SizedBox(height: 18),

            // Preferences & Settings
            _buildSettingsCard(appState),
          ],
        ),
      ),
    );
  }

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
            radius: 30,
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'F',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 24,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 18),
                  ],
                ),
                Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 13, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(location, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppKisanAssistantCard(AppState appState) {
    final user = appState.currentUser;
    final kisanService = WhatsAppKisanService();
    final userId = user?.id ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Color(0xFF075E54), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'WhatsApp कृषि-साथी AI',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF075E54),
                    ),
                  ),
                ],
              ),
              StreamBuilder<bool>(
                stream: kisanService.isWhatsAppLinkedStream(userId),
                builder: (context, snapshot) {
                  final isLinked = snapshot.data ?? false;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLinked ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLinked ? Icons.check_circle : Icons.link_off,
                          size: 13,
                          color: isLinked ? const Color(0xFF15803D) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLinked ? context.tr('Linked', 'जुड़ा हुआ') : context.tr('Not Linked', 'नहीं जुड़ा'),
                          style: TextStyle(
                            color: isLinked ? const Color(0xFF15803D) : const Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Connect WhatsApp for 1-Tap Auto Login. Any crops you send via voice note or text to WhatsApp will automatically be saved to your AgriChain account under "My Crops".',
              '1-टैप ऑटो लॉगिन के लिए व्हाट्सएप कनेक्ट करें। व्हाट्सएप पर वॉयस नोट या टेक्स्ट द्वारा भेजी गई कोई भी फसल "मेरी फसलें" के तहत स्वचालित रूप से सहेजी जाएगी।',
            ),
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('Please log in first to link your account', 'खाता लिंक करने के लिए पहले लॉग इन करें'))),
                      );
                      return;
                    }
                    final launched = await kisanService.launchConnectWhatsApp(user);
                    if (!launched && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('✅ Handshake code copied! Paste in WhatsApp chat to link.', '✅ हैंडशेक कोड कॉपी हो गया! लिंक करने के लिए व्हाट्सएप चैट में पेस्ट करें।')),
                          backgroundColor: const Color(0xFF075E54),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(context.tr('Connect WhatsApp (Auto Link)', 'व्हाट्सएप कनेक्ट करें (ऑटो लिंक)')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF075E54)),
                tooltip: 'Configure Bot Phone Number',
                onPressed: () => _showBotNumberConfigDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBotNumberConfigDialog() async {
    final kisanService = WhatsAppKisanService();
    final currentNumber = await kisanService.getBotNumber();
    final controller = TextEditingController(text: currentNumber);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Configure Bot Phone Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the phone number that scanned the QR code (with country code, e.g. 918307165924):',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Bot Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await kisanService.setBotNumber(controller.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Bot phone number updated!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF075E54)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLandAndGisCard() {
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
                  const Icon(Icons.satellite_alt, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 8),
                  Text(context.tr('Land Records & GIS Soil Health', 'भूमि रिकॉर्ड और जीआईएस मृदा स्वास्थ्य'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(context.tr('NFT Bound', 'NFT बाउंड'), style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _khasraController.text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Soil: Alluvial Sandy Loam • Moisture Index: Optimal (11.8%) • Nitrogen: High',
              'मृदा: जलोढ़ रेतीली दोमट • नमी सूचकांक: अनुकूल (11.8%) • नाइट्रोजन: उच्च',
            ),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LandAnalysisScreen()),
                    );
                  },
                  icon: const Icon(Icons.search, size: 16),
                  label: Text(context.tr('Land Scan', 'जमीन स्कैन'), style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MintLandNFTScreen()),
                    );
                  },
                  icon: const Icon(Icons.token, size: 16),
                  label: Text(context.tr('Mint Land NFT', 'भूमि NFT मिंट करें'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSignatureAndDigiLockerCard(AppState appState) {
    final signatureUrl = appState.currentUser?.signatureUrl;
    final hasSignature = signatureUrl != null && signatureUrl.isNotEmpty;

    Uint8List? sigBytes;
    if (hasSignature && signatureUrl.startsWith('data:image')) {
      try {
        final base64Part = signatureUrl.split(',').last;
        sigBytes = base64Decode(base64Part);
      } catch (_) {}
    }

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
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.draw, color: Color(0xFF15803D), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Digital Signature & DigiLocker', 'डिजिटल हस्ताक्षर और डिजिलॉकर'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        context.tr('Embedded onto dual-signed smart contracts', 'दोहरे हस्ताक्षरित स्मार्ट अनुबंधों में अंतर्निहित'),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasSignature ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSignature ? Icons.verified : Icons.warning_amber_rounded,
                      size: 13,
                      color: hasSignature ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasSignature ? context.tr('ACTIVE', 'सक्रिय') : context.tr('ACTION REQUIRED', 'कार्रवाई आवश्यक'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasSignature ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (hasSignature) ...[
            Container(
              width: double.infinity,
              height: 110,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
              ),
              child: sigBytes != null
                  ? Image.memory(sigBytes, fit: BoxFit.contain)
                  : Image.network(
                      signatureUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.verified, color: Color(0xFF15803D), size: 40),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Color(0xFF15803D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr(
                      'Official signature linked to your Aadhaar & e-Kisan profile.',
                      'आपके आधार और ई-किसान प्रोफाइल से जुड़ा आधिकारिक हस्ताक्षर।',
                    ),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final res = await SignaturePadDialog.show(
                      context,
                      signerName: appState.currentUser?.name ?? 'Farmer',
                      currentSignatureUrl: signatureUrl,
                      isFarmer: true,
                    );
                    if (res != null && res['signatureUrl'] != null) {
                      await appState.updateUserSignature(res['signatureUrl']);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('✅ Signature updated for smart contracts!', '✅ स्मार्ट अनुबंधों के लिए हस्ताक्षर अपडेट किए गए!')),
                            backgroundColor: const Color(0xFF15803D),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(context.tr('Update / Re-sign', 'हस्ताक्षर बदलें'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('No digital signature on file!', 'कोई डिजिटल हस्ताक्षर उपलब्ध नहीं!'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'Upload your signature, draw it directly, or verify via DigiLocker so the dual-signed smart contracts include your real signature.',
                      'अपना हस्ताक्षर अपलोड करें, सीधे ड्रा करें, या डिजिलॉकर के माध्यम से सत्यापित करें ताकि स्मार्ट अनुबंधों में आपका वास्तविक हस्ताक्षर शामिल हो सके।',
                    ),
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final res = await SignaturePadDialog.show(
                          context,
                          signerName: appState.currentUser?.name ?? 'Farmer',
                          isFarmer: true,
                        );
                        if (res != null && res['signatureUrl'] != null) {
                          await appState.updateUserSignature(res['signatureUrl']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr('✅ Digital signature saved to profile!', '✅ डिजिटल हस्ताक्षर प्रोफ़ाइल में सहेजा गया!')),
                                backgroundColor: const Color(0xFF15803D),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.draw, size: 16),
                      label: Text(
                        context.tr('Upload or Draw Signature / DigiLocker e-Sign', 'हस्ताक्षर अपलोड/ड्रा करें या डिजिलॉकर ई-साइन'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankAndUpiCard() {
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
                  const Icon(Icons.account_balance, color: Color(0xFF2E7D32), size: 22),
                  const SizedBox(width: 8),
                  Text(context.tr('Direct Payout Bank & UPI', 'सीधा भुगतान बैंक व यूपीआई'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF2E7D32)),
                onPressed: _showBankUpiModal,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildInfoRow(context.tr('Account Number', 'खाता संख्या'), _bankAccController.text),
          _buildInfoRow(context.tr('IFSC Code', 'आईएफएससी कोड'), _ifscController.text),
          _buildInfoRow(context.tr('UPI ID (VPA)', 'यूपीआई आईडी (VPA)'), _upiController.text),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildPayoutHistoryCard(String farmerId) {
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
              const Icon(Icons.receipt_long, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Text(context.tr('Recent Payout Settlements', 'हालिया भुगतान निपटान'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dbService.streamFarmerOrders(farmerId),
            builder: (context, snapshot) {
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(context.tr('No payout settlements yet.', 'अभी तक कोई भुगतान निपटान नहीं।'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                );
              }

              return Column(
                children: orders.take(3).map((o) {
                  final total = _toDouble(o['totalPrice']);
                  final date = o['createdAt'] != null ? o['createdAt'].toString().split('T').first : 'Recent';
                  final type = o['orderType'] == 'fpo_procurement'
                      ? context.tr('FPO Settlement', 'एफपीओ निपटान')
                      : context.tr('Retail Sale', 'खुदरा बिक्री');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$type ($date)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text('+₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D))),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
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
              const Icon(Icons.folder_shared, color: Color(0xFF475569), size: 22),
              const SizedBox(width: 8),
              Text(context.tr('Documents & Certifications', 'दस्तावेज़ और प्रमाण पत्र'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          _buildDocItem(context.tr('Aadhaar / Farmer Identity Card', 'आधार / किसान पहचान पत्र'), context.tr('Verified', 'सत्यापित'), const Color(0xFF15803D)),
          _buildDocItem(context.tr('Land Registry Deed (7/12 Extract)', 'भूमि रजिस्ट्री (7/12 नकल)'), context.tr('Verified', 'सत्यापित'), const Color(0xFF15803D)),
          _buildDocItem(context.tr('NPOP Organic Certification', 'NPOP जैविक प्रमाणीकरण'), context.tr('Active', 'सक्रिय'), const Color(0xFF2563EB)),
        ],
      ),
    );
  }

  Widget _buildDocItem(String name, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

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
          Text(context.tr('App Settings & Preferences', 'ऐप सेटिंग्स और प्राथमिकताएं'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate, color: Color(0xFF2E7D32)),
            title: Text(
              context.tr('Language / भाषा', 'भाषा / Language'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            trailing: const LanguageSwitcherPill(isDark: false),
          ),
          const Divider(height: 16),
          SwitchListTile(
            title: Text(context.tr('SMS & Push Notifications', 'एसएमएस और पुश सूचनाएं'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(context.tr('Order updates, FPO collection routes, MSP alerts', 'ऑर्डर अपडेट, एफपीओ संग्रह मार्ग, एमएसपी अलर्ट'), style: const TextStyle(fontSize: 11)),
            value: _notificationsEnabled,
            activeThumbColor: const Color(0xFF2E7D32),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, color: Color(0xFF475569)),
            title: Text(context.tr('Kisan Helpdesk & Agri Advisory', 'किसान हेल्पलाइन व कृषि सलाह'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kisan Toll-Free Helpdesk: 1800-180-1551 (Available 24x7)')),
              );
            },
          ),
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: Text(context.tr('Sign Out', 'लॉग आउट'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.error)),
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

  Widget _buildFarmerReputationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFFDE68A)),
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Farmer Trust & Ratings', 'किसान साख व रेटिंग'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        context.tr('Trust, Quality & Buyer Ratings', 'विश्वास, गुणवत्ता और खरीदार रेटिंग'),
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 12, color: Color(0xFF15803D)),
                    const SizedBox(width: 3),
                    Text(
                      context.tr('TOP RATED FARMER', 'शीर्ष रेटेड किसान'),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
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
                '4.92',
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
                  const StarRatingDisplay(rating: 4.92, size: 18, activeColor: Colors.amber),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('Based on 38 verified deliveries & harvests', '38 सत्यापित डिलीवरी और उपज पर आधारित'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Breakdown metrics
          _buildRatingMetricRow(context.tr('Produce Quality & Purity', 'फसल की गुणवत्ता व शुद्धता'), 0.98, '4.9'),
          const SizedBox(height: 8),
          _buildRatingMetricRow(context.tr('Weighment Accuracy', 'वजन व तौल की शुद्धता'), 1.0, '5.0'),
          const SizedBox(height: 8),
          _buildRatingMetricRow(context.tr('On-Time Farmgate Dispatch', 'समय पर फार्मगेट डिलीवरी'), 0.96, '4.8'),
          const SizedBox(height: 16),

          // Verified Buyer Reviews Snippet
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
                      'Amit Verma (Retail Buyer, Delhi NCR)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF0F172A)),
                    ),
                    const Text('⭐ 5.0 • 3 days ago', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '"Basmati 1121 is exceptionally clean, aromatic, and naturally farm-dried. Quick farmgate dispatch and smooth escrow release."',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                      'Karnal Kisan Samriddhi FPO',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF0F172A)),
                    ),
                    const Text('⭐ 5.0 • 1 week ago', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '"Excellent mustard lot inwarded at collection center. Moisture tested accurately at 7.8%. Instant DBT payout issued."',
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
