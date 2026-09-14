import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_state.dart';
import '../models/firestore_models.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';
import 'retail_buyer/rating_screen.dart';
import 'debug_sample_users_screen.dart';
import 'profile_edit_screen.dart';
import 'wallet_connection_screen.dart';
import 'transaction_history_screen.dart';
import 'farmer/mint_land_nft_screen.dart';
import 'farmer/mint_crop_nft_screen.dart';
import '../config/app_config.dart';
import '../services/profile_service.dart';
import '../services/wallet_service.dart';
import '../services/whatsapp_kisan_service.dart';
import '../widgets/language_switcher.dart';
import 'package:agrichain/l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _biometricEnabled = false;
  Map<String, dynamic>? _profileData;
  bool _isLoadingProfile = true;
  final ProfileService _profileService = ProfileService();
  final WalletService _walletService = WalletService();
  bool _isWalletConnected = false;
  String? _walletAddress;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkWalletConnection();
  }

  Future<void> _loadProfileData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.currentUser?.id;

    if (userId != null) {
      try {
        final profileData = await _profileService.getUserProfile(userId);
        if (mounted) {
          setState(() {
            _profileData = profileData;
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
        debugPrint('Error loading profile data: $e');
      }
    } else {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _checkWalletConnection() async {
    try {
      final isConnected = WalletService.isConnected;
      if (isConnected) {
        final address = WalletService.connectedAddress;
        final balance = await WalletService.getWalletBalance();

        if (mounted) {
          setState(() {
            _isWalletConnected = true;
            _walletAddress = address;
            _walletBalance = balance;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking wallet connection: $e');
    }
  }

  Future<void> _connectWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WalletConnectionScreen()),
    );

    if (result == true) {
      await _checkWalletConnection();
    }
  }

  Future<void> _viewTransactionHistory() async {
    if (_isWalletConnected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TransactionHistoryScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            CustomAppBar(
              title: l10n?.profileTitle ?? 'Profile',
              actions: [
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(child: LanguageSwitcherPill(isDark: true)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editProfile(context),
                ),
              ],
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildWhatsAppConnectSection(),
              const SizedBox(height: 24),
              _buildProfileDetailsSection(),
              const SizedBox(height: 24),
              _buildWalletSection(),
              const SizedBox(height: 24),
              _buildMenuSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background Pattern
              Positioned(
                top: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.1,
                  child: Icon(
                    Icons.spa,
                    size: 200,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar and Info
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryGreen,
                                AppTheme.accentGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Guest User',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkGreen,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'No email provided',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.grey),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryGreen.withOpacity(
                                      0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: AppTheme.primaryGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      user?.userType == UserType.farmer
                                          ? (appState.locale.languageCode == 'hi' ? 'सत्यापित किसान' : 'Verified Farmer')
                                          : (appState.locale.languageCode == 'hi' ? 'सत्यापित खरीदार' : 'Verified Buyer'),
                                      style: const TextStyle(
                                        color: AppTheme.primaryGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildRatingSection(appState),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppConnectSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        if (user == null) return const SizedBox.shrink();

        final isHindi = appState.locale.languageCode == 'hi';
        final kisanService = WhatsAppKisanService();

        String roleDescription = isHindi
            ? '1-टैप ऑटो लॉगिन के लिए व्हाट्सएप कनेक्ट करें। आपके ऑर्डर्स, ट्रैकिंग और मार्केट अपडेट सीधे व्हाट्सएप पर मिलेंगे।'
            : 'Connect WhatsApp for 1-Tap Auto Login. Get real-time order tracking, live prices, and smart assistant updates directly on WhatsApp.';

        if (user.userType == UserType.retailBuyer) {
          roleDescription = isHindi
              ? 'व्हाट्सएप कनेक्ट करें: आपके रिटेल ऑर्डर्स की लाइव ट्रैकिंग, डिलीवरी स्थिति और ताज़ा मंडी भाव सीधे व्हाट्सएप पर मिलेंगे।'
              : 'Connect WhatsApp: Track your retail orders, delivery status, and discover fresh farm harvests directly on WhatsApp.';
        } else if (user.userType == UserType.fpo || user.userType == UserType.fpoMemberFarmer) {
          roleDescription = isHindi
              ? 'व्हाट्सएप कनेक्ट करें: FPO सामूहिक लॉट लिस्टिंग, बल्क खरीदार मांग और प्रोक्योरमेंट ऑर्डर्स की जानकारी प्राप्त करें।'
              : 'Connect WhatsApp: Manage FPO pooled stock, view bulk buyer demand, and track procurement orders via WhatsApp.';
        } else if (user.userType == UserType.buyer) {
          roleDescription = isHindi
              ? 'व्हाट्सएप कनेक्ट करें: आपके बल्क स्मार्ट कॉन्ट्रैक्ट्स, RFQ स्टेटस और एस्क्रो भुगतान की लाइव ट्रैकिंग WhatsApp पर पाएँ।'
              : 'Connect WhatsApp: Track your bulk smart contracts, RFQ updates, and escrow settlements directly on WhatsApp.';
        }

        return StreamBuilder<bool>(
          stream: kisanService.isWhatsAppLinkedStream(user.id),
          builder: (context, snapshot) {
            final isLinked = snapshot.data ?? (user.metadata['isWhatsAppLinked'] == true);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLinked ? const Color(0xFF25D366).withOpacity(0.4) : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLinked ? const Color(0xFF25D366) : Colors.black).withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? 'व्हाट्सएप असिस्टेंट (AgriChain Bot)' : 'AgriChain WhatsApp Assistant',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkGreen),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLinked
                                  ? (isHindi ? 'खाता सक्रिय रूप से जुड़ा हुआ है' : 'Account linked & active')
                                  : (isHindi ? '1-टैप में खाता लिंक करें' : 'Link account in 1-tap'),
                              style: TextStyle(fontSize: 12, color: isLinked ? const Color(0xFF15803D) : AppTheme.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLinked ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
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
                              isLinked
                                  ? (isHindi ? 'लिंक है' : 'Linked')
                                  : (isHindi ? 'अनलिंक्ड' : 'Not Linked'),
                              style: TextStyle(
                                color: isLinked ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    roleDescription,
                    style: const TextStyle(fontSize: 12, color: AppTheme.darkGrey, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final launched = await kisanService.launchConnectWhatsApp(user);
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isHindi
                                    ? '✅ कोड कॉपी हो गया! व्हाट्सएप चैट में पेस्ट करें।'
                                    : '✅ Code copied! Paste into WhatsApp chat to link.',
                              ),
                              backgroundColor: const Color(0xFF075E54),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link, size: 18),
                      label: Text(
                        isLinked
                            ? (isHindi ? 'व्हाट्सएप चैट खोलें' : 'Open WhatsApp Chat')
                            : (isHindi ? 'व्हाट्सएप कनेक्ट करें (Auto Link)' : 'Connect WhatsApp (Auto Link)'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
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
      },
    );
  }

  Widget _buildProfileDetailsSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (_isLoadingProfile) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_profileData == null) {
          return _buildEmptyProfileState();
        }

        // Parse profile data
        Map<String, dynamic> profileInfo = {};
        if (_profileData!['profileData'] is String) {
          try {
            profileInfo = Map<String, dynamic>.from(
              jsonDecode(_profileData!['profileData']),
            );
          } catch (e) {
            debugPrint('Error parsing profile data: $e');
          }
        } else if (_profileData!['profileData'] is Map) {
          profileInfo = Map<String, dynamic>.from(_profileData!['profileData']);
        }

        final userType = appState.currentUser?.userType;

        final isHindi = appState.locale.languageCode == 'hi';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    isHindi ? 'प्रोफ़ाइल विवरण' : 'Profile Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(isHindi ? 'संपादित करें' : 'Edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildProfileInfoGrid(profileInfo, userType),
          ],
        );
      },
    );
  }

  Widget _buildEmptyProfileState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: AppTheme.primaryGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete Your Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your details to unlock all features and build trust.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _editProfile(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoGrid(
    Map<String, dynamic> profileInfo,
    UserType? userType,
  ) {
    final List<Widget> infoCards = [];

    // Location Information
    if (profileInfo['address'] != null || profileInfo['city'] != null) {
      infoCards.add(
        _buildInfoCard(
          'Location',
          _buildLocationInfo(profileInfo),
          Icons.location_on_outlined,
          AppTheme.primaryGreen,
        ),
      );
    }

    // User Type Specific Information
    if (userType == UserType.farmer) {
      infoCards.addAll(_buildFarmerSpecificCards(profileInfo));
    } else if (userType == UserType.buyer) {
      infoCards.addAll(_buildBuyerSpecificCards(profileInfo));
    }

    // Additional Information
    if (profileInfo['bio'] != null &&
        profileInfo['bio'].toString().isNotEmpty) {
      infoCards.add(
        _buildInfoCard(
          'Bio',
          profileInfo['bio'].toString(),
          Icons.description_outlined,
          AppTheme.accentGreen,
        ),
      );
    }

    if (profileInfo['experience'] != null &&
        profileInfo['experience'].toString().isNotEmpty) {
      infoCards.add(
        _buildInfoCard(
          'Experience',
          '${profileInfo['experience']} years',
          Icons.work_outline,
          AppTheme.sunYellow,
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < infoCards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < infoCards.length ? 12 : 0),
            child: Row(
              children: [
                Expanded(child: infoCards[i]),
                if (i + 1 < infoCards.length) ...[
                  const SizedBox(width: 12),
                  Expanded(child: infoCards[i + 1]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _buildLocationInfo(Map<String, dynamic> profileInfo) {
    final parts = <String>[];
    if (profileInfo['city'] != null) parts.add(profileInfo['city'].toString());
    if (profileInfo['state'] != null)
      parts.add(profileInfo['state'].toString());
    if (profileInfo['pincode'] != null)
      parts.add(profileInfo['pincode'].toString());
    return parts.join(', ');
  }

  List<Widget> _buildFarmerSpecificCards(Map<String, dynamic> profileInfo) {
    final List<Widget> cards = [];

    if (profileInfo['farmSize'] != null &&
        profileInfo['farmSize'].toString().isNotEmpty) {
      cards.add(
        _buildInfoCard(
          'Farm Size',
          profileInfo['farmSize'].toString(),
          Icons.landscape_outlined,
          AppTheme.earthBrown,
        ),
      );
    }

    if (profileInfo['crops'] != null) {
      String cropsText = '';
      if (profileInfo['crops'] is List) {
        final cropsList = List<String>.from(profileInfo['crops']);
        cropsText = cropsList.take(3).join(', ');
        if (cropsList.length > 3) {
          cropsText += ' +${cropsList.length - 3} more';
        }
      } else {
        cropsText = profileInfo['crops'].toString();
      }

      if (cropsText.isNotEmpty) {
        cards.add(
          _buildInfoCard(
            'Crops',
            cropsText,
            Icons.grass_outlined,
            AppTheme.primaryGreen,
          ),
        );
      }
    }

    return cards;
  }

  List<Widget> _buildBuyerSpecificCards(Map<String, dynamic> profileInfo) {
    final List<Widget> cards = [];

    if (profileInfo['businessType'] != null &&
        profileInfo['businessType'].toString().isNotEmpty) {
      cards.add(
        _buildInfoCard(
          'Business Type',
          profileInfo['businessType'].toString(),
          Icons.business_outlined,
          AppTheme.primaryGreen,
        ),
      );
    }

    if (profileInfo['gstNumber'] != null &&
        profileInfo['gstNumber'].toString().isNotEmpty) {
      cards.add(
        _buildInfoCard(
          'GST Number',
          profileInfo['gstNumber'].toString(),
          Icons.receipt_outlined,
          AppTheme.sunYellow,
        ),
      );
    }

    if (profileInfo['services'] != null) {
      String servicesText = '';
      if (profileInfo['services'] is List) {
        final servicesList = List<String>.from(profileInfo['services']);
        servicesText = servicesList.take(2).join(', ');
        if (servicesList.length > 2) {
          servicesText += ' +${servicesList.length - 2} more';
        }
      } else {
        servicesText = profileInfo['services'].toString();
      }

      if (servicesText.isNotEmpty) {
        cards.add(
          _buildInfoCard(
            'Services',
            servicesText,
            Icons.handyman_outlined,
            AppTheme.accentGreen,
          ),
        );
      }
    }

    return cards;
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(AppState appState) {
    // Default rating stats since FirestoreUser doesn't have rating properties yet
    final buyerStats = _createDefaultRatingStats();
    final sellerStats = _createDefaultRatingStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRatingItem(
            'Buyer Rating',
            buyerStats.averageRating,
            buyerStats.totalRatings,
            RatingType.buyer,
          ),
          Container(height: 40, width: 1, color: AppTheme.inputBorder),
          _buildRatingItem(
            'Seller Rating',
            sellerStats.averageRating,
            sellerStats.totalRatings,
            RatingType.seller,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingItem(
    String label,
    double rating,
    int count,
    RatingType type,
  ) {
    return GestureDetector(
      onTap: () => _showRatings(type),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            ],
          ),
          Text(
            '$count Reviews',
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final l10n = AppLocalizations.of(context);
        final isHindi = appState.locale.languageCode == 'hi';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    l10n?.myWallet ?? 'Digital Wallet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showWalletDetails(context),
                    child: Text(isHindi ? 'इतिहास देखें' : 'View History'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildWalletBalanceCard(
                    context,
                    l10n?.availableBalance ?? 'Available Balance',
                    '₹${appState.currentUser?.walletBalance.toStringAsFixed(0) ?? '0'}',
                    Colors.white,
                    AppTheme.primaryGreen,
                    AppTheme.accentGreen,
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(width: 16),
                  _buildWalletBalanceCard(
                    context,
                    isHindi ? 'क्रिप्टो संपत्तियां' : 'Crypto Assets',
                    '${_walletBalance.toStringAsFixed(4)} ETH',
                    AppTheme.darkGreen,
                    Colors.white,
                    Colors.white.withOpacity(0.9),
                    Icons.currency_bitcoin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    l10n?.addMoney ?? 'Add Money',
                    Icons.add_circle_outline,
                    AppTheme.primaryGreen,
                    () => _addMoney(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context,
                    l10n?.withdraw ?? 'Withdraw',
                    Icons.arrow_circle_up,
                    AppTheme.darkGrey,
                    () => _withdrawMoney(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBlockchainStatusCard(),
          ],
        );
      },
    );
  }

  Widget _buildWalletBalanceCard(
    BuildContext context,
    String title,
    String amount,
    Color textColor,
    Color bgColor1,
    Color bgColor2,
    IconData icon,
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor1, bgColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: bgColor1.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: textColor, size: 24),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                amount,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildBlockchainStatusCard() {
    final l10n = AppLocalizations.of(context);
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isWalletConnected
            ? AppTheme.primaryGreen.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isWalletConnected
              ? AppTheme.primaryGreen.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isWalletConnected ? Icons.link : Icons.link_off,
            color: _isWalletConnected ? AppTheme.primaryGreen : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isWalletConnected
                      ? (isHindi ? 'वॉलेट कनेक्टेड' : 'Wallet Connected')
                      : (l10n?.walletDisconnected ?? 'Wallet Disconnected'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isWalletConnected
                        ? AppTheme.darkGreen
                        : Colors.grey[700],
                  ),
                ),
                if (_isWalletConnected && _walletAddress != null)
                  Text(
                    '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey),
                  ),
              ],
            ),
          ),
          if (!_isWalletConnected)
            TextButton(onPressed: _connectWallet, child: Text(l10n?.connectWallet ?? 'Connect'))
          else
            IconButton(
              icon: const Icon(Icons.logout, size: 20),
              color: Colors.red,
              onPressed: () async {
                final appState = Provider.of<AppState>(context, listen: false);
                await WalletService.disconnectWallet(
                  userId: appState.currentUser?.id,
                );
                await _checkWalletConnection();
              },
            ),
        ],
      ),
    );
  }

  // Helper method for wallet card was replaced by _buildWalletBalanceCard

  Widget _buildMenuSection() {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context);
    final isHindi = appState.locale.languageCode == 'hi';

    return Column(
      children: [
        _buildMenuGroup(l10n?.profileTitle ?? 'Account', [
          _MenuItemData(
            icon: Icons.person_outline,
            title: l10n?.personalInfo ?? 'Personal Information',
            subtitle: l10n?.personalInfoDesc ?? 'Update your profile details',
            onTap: () => _editProfile(context),
          ),
          _MenuItemData(
            icon: Icons.star_outline,
            title: l10n?.ratingsReviews ?? 'Ratings & Reviews',
            subtitle: l10n?.ratingsReviewsDesc ?? 'View your ratings and feedback',
            onTap: () => _showAllRatings(context),
          ),
          _MenuItemData(
            icon: Icons.security,
            title: l10n?.security ?? 'Security',
            subtitle: l10n?.securityDesc ?? 'Password, 2FA, biometric',
            onTap: () => _showSecuritySettings(context),
          ),
          _MenuItemData(
            icon: Icons.verified_user,
            title: l10n?.kycStatus ?? 'Verification',
            subtitle: isHindi ? 'केवाईसी और दस्तावेज़ सत्यापन' : 'KYC and document verification',
            onTap: () => _showVerificationStatus(context),
          ),
        ]),
        const SizedBox(height: 24),
        _buildMenuGroup(isHindi ? 'ब्लॉकचेन और एनएफटी' : 'Blockchain & NFTs', [
          _MenuItemData(
            icon: Icons.landscape,
            title: isHindi ? 'भूमि एनएफटी बनाएं' : 'Mint Land NFT',
            subtitle: isHindi ? 'अपनी भूमि का डिजिटल टोकन बनाएं' : 'Tokenize your land property',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MintLandNFTScreen(),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.agriculture,
            title: isHindi ? 'फसल एनएफटी बनाएं' : 'Mint Crop NFT',
            subtitle: isHindi ? 'अपनी फसल का डिजिटल टोकन बनाएं' : 'Tokenize your crop harvest',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MintCropNFTScreen(),
              ),
            ),
          ),
          _MenuItemData(
            icon: Icons.account_balance_wallet,
            title: isHindi ? 'ब्लॉकचेन वॉलेट' : 'Blockchain Wallet',
            subtitle: _isWalletConnected
                ? (isHindi ? 'कनेक्टेड' : 'Connected')
                : (isHindi ? 'कनेक्ट नहीं है' : 'Not connected'),
            onTap: _isWalletConnected
                ? _viewTransactionHistory
                : _connectWallet,
          ),
        ]),
        const SizedBox(height: 24),
        _buildMenuGroup(isHindi ? 'प्राथमिकताएं' : 'Preferences', [
          _MenuItemData(
            icon: Icons.notifications_outlined,
            title: isHindi ? 'सूचनाएं' : 'Notifications',
            subtitle: _notificationsEnabled
                ? (isHindi ? 'सक्रिय' : 'Enabled')
                : (isHindi ? 'निष्क्रिय' : 'Disabled'),
            onTap: () => _showNotificationSettings(context),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              activeThumbColor: AppTheme.primaryGreen,
            ),
          ),
          _MenuItemData(
            icon: Icons.language,
            title: l10n?.language ?? 'Language',
            subtitle: isHindi ? 'हिन्दी (Hindi)' : 'English',
            onTap: () => _showLanguageSettings(context),
          ),
          _MenuItemData(
            icon: Icons.fingerprint,
            title: isHindi ? 'बायोमेट्रिक लॉगिन' : 'Biometric Login',
            subtitle: _biometricEnabled
                ? (isHindi ? 'सक्रिय' : 'Enabled')
                : (isHindi ? 'निष्क्रिय' : 'Disabled'),
            onTap: () => _toggleBiometric(),
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: (value) => _toggleBiometric(),
              activeThumbColor: AppTheme.primaryGreen,
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _buildMenuGroup(isHindi ? 'खाता सेटिंग्स' : 'Account', [
          _MenuItemData(
            icon: Icons.logout,
            title: l10n?.logout ?? 'Logout',
            subtitle: isHindi ? 'अपने खाते से लॉग आउट करें' : 'Sign out of your account',
            onTap: () => _logout(context),
            textColor: Colors.red,
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuGroup(String title, List<_MenuItemData> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.darkGreen,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppTheme.inputBorder,
                    ),
                  _buildMenuItem(item),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItemData item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (item.textColor ?? AppTheme.primaryGreen).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          color: item.textColor ?? AppTheme.primaryGreen,
          size: 18,
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: item.textColor ?? AppTheme.darkGrey,
          fontSize: 14,
        ),
      ),
      subtitle: item.subtitle.isNotEmpty
          ? Text(
              item.subtitle,
              style: const TextStyle(color: AppTheme.grey, fontSize: 12),
            )
          : null,
      trailing:
          item.trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.grey, size: 20),
      onTap: item.onTap,
    );
  }

  void _editProfile(BuildContext context) async {
    if (_profileData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile data not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(profileData: _profileData),
      ),
    );

    // Refresh profile data if editing was successful
    if (result == true) {
      _loadProfileData();
    }
  }

  void _showWalletDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletDetailsSheet(),
    );
  }

  void _addMoney(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Money'),
        content: const Text(
          'Razorpay integration will be implemented for secure payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Add Money'),
          ),
        ],
      ),
    );
  }

  void _withdrawMoney(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Money'),
        content: const Text(
          'Bank transfer functionality will be implemented with UPI integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: const Text(
          'Security features including 2FA, password change, and biometric authentication will be implemented.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVerificationStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Status'),
        content: const Text(
          'KYC verification and document upload functionality will be implemented.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text(
          'Granular notification controls for orders, payments, and blockchain events will be implemented.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    LanguageSelectorSheet.show(context);
  }

  void _toggleBiometric() {
    setState(() {
      _biometricEnabled = !_biometricEnabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _biometricEnabled
              ? 'Biometric login enabled'
              : 'Biometric login disabled',
        ),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  void _navigateToDebugScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DebugSampleUsersScreen()),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                debugPrint('🔓 Starting logout process...');

                // Clear app state first
                final appState = Provider.of<AppState>(context, listen: false);
                appState.clearUser();
                debugPrint('✅ App state cleared');

                // Sign out from Firebase - StreamBuilder will handle navigation
                await FirebaseAuth.instance.signOut();
                debugPrint('✅ Firebase signout complete');

                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: AppTheme.primaryGreen,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ Logout error: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showRatings(RatingType ratingType) {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentUser = appState.currentUser;
    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewRatingsScreen(
          userId: currentUser.id,
          userName: currentUser.name,
          initialTab: ratingType == RatingType.buyer ? 0 : 1,
        ),
      ),
    );
  }

  void _showAllRatings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllRatingsScreen()),
    );
  }

  // Helper method to create default rating stats
  dynamic _createDefaultRatingStats() {
    return _DefaultRatingStats();
  }
}

// Temporary class to provide default rating stats
class _DefaultRatingStats {
  final double averageRating = 0.0;
  final int totalRatings = 0;
}

class _MenuItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? textColor;

  _MenuItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.textColor,
  });
}

class _WalletDetailsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTransactionItem(
                    'Crop Purchase',
                    '- ₹2,500',
                    DateTime.now().subtract(const Duration(hours: 2)),
                    Icons.shopping_cart,
                    Colors.red,
                  ),
                  _buildTransactionItem(
                    'Wallet Top-up',
                    '+ ₹5,000',
                    DateTime.now().subtract(const Duration(days: 1)),
                    Icons.add_circle,
                    AppTheme.primaryGreen,
                  ),
                  _buildTransactionItem(
                    'Loan Repayment',
                    '- ₹1,200',
                    DateTime.now().subtract(const Duration(days: 3)),
                    Icons.payment,
                    Colors.red,
                  ),
                  _buildTransactionItem(
                    'Crop Sale',
                    '+ ₹3,800',
                    DateTime.now().subtract(const Duration(days: 5)),
                    Icons.sell,
                    AppTheme.primaryGreen,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String title,
    String amount,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                  style: TextStyle(color: AppTheme.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
