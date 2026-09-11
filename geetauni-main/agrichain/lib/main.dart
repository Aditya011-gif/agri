import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:agrichain/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
// Screens organized by role
import 'screens/farmer/farmer.dart';
import 'screens/bulk_buyer/bulk_buyer.dart';
import 'screens/retail_buyer/retail_buyer.dart';
import 'screens/fpo/fpo.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'providers/app_state.dart';
import 'config/app_initializer.dart';
import 'models/firestore_models.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AgriChainApp());
}

class AgriChainApp extends StatefulWidget {
  const AgriChainApp({super.key});

  @override
  State<AgriChainApp> createState() => _AgriChainAppState();
}

class _AgriChainAppState extends State<AgriChainApp> {
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String _errorMessage = '';
  bool _isFirstTime = true;
  bool _checkingFirstTime = true;
  final AppInitializer _appInitializer = AppInitializer();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if this is the first time opening the app
      await _checkFirstTimeUser();

      final success = await _appInitializer.initialize();
      setState(() {
        _isInitialized = success;
        _initializationFailed = !success;
        _checkingFirstTime = false;
        if (!success) {
          final results = _appInitializer.initializationResults;
          _errorMessage =
              results['error']?.toString() ?? 'Unknown initialization error';
        }
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _initializationFailed = true;
        _checkingFirstTime = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    setState(() {
      _isFirstTime = !hasSeenOnboarding;
    });
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    setState(() {
      _isFirstTime = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final appState = AppState();
            // Initialize AppState after creation to trigger mock data initialization
            appState.initialize();
            return appState;
          },
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'AgriChain',
            theme: AppTheme.lightTheme,
            locale: appState.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
              Locale('hi', ''),
            ],
            home: _buildHome(),
            debugShowCheckedModeBanner: false,
            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/add-crop':
        return MaterialPageRoute(
          builder: (context) => const AddCropScreen(),
          settings: settings,
        );
      default:
        return null;
    }
  }

  Widget _buildHome() {
    if (_initializationFailed) {
      return _buildErrorScreen();
    }

    if (!_isInitialized || _checkingFirstTime) {
      return _buildLoadingScreen();
    }

    // Show onboarding for first-time users
    if (_isFirstTime) {
      return OnboardingScreen(onComplete: _markOnboardingComplete);
    }

    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (appState.currentUser != null) {
          return const MainScreen();
        }
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (snapshot.hasData && snapshot.data != null) {
              return const MainScreen();
            } else {
              return const LoginScreen();
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppTheme.background),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 40),

              // App Name
              Text(
                'AgriChain',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Empowering Agriculture with Blockchain',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 60),

              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Loading Text
              const Text(
                'Initializing application...',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppTheme.background),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 40),

                // Error Title
                Text(
                  'Initialization Failed',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Error Message
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                // Retry Button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isInitialized = false;
                      _initializationFailed = false;
                      _errorMessage = '';
                    });
                    _initializeApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Farmer/Seller screens (5 primary tabs matching specification)
  late final List<Widget> _farmerScreens = [
    HomeScreen(onNavigateTab: _onTabTapped),
    const MyCropsScreen(),
    const FarmerOrdersScreen(),
    const FarmerPayoutHistoryScreen(),
    const FarmerProfileScreen(),
  ];

  // Bulk Buyer screens (5 primary tabs)
  late final List<Widget> _bulkBuyerScreens = [
    BulkBuyerHomeScreen(onNavigateTab: _onTabTapped),
    const BulkBuyerSupplyScreen(),
    const BulkBuyerRfqsScreen(),
    const BulkBuyerOrdersScreen(),
    const BulkBuyerProfileScreen(),
  ];

  // Retail Buyer screens (5 primary tabs: Home, 7km Clusters, Orders, Saved, Profile)
  late final List<Widget> _retailBuyerScreens = [
    RetailBuyerHomeScreen(onNavigateTab: _onTabTapped),
    GroupBuyingScreen(onNavigateTab: _onTabTapped),
    const RetailBuyerOrdersScreen(),
    RetailBuyerSavedScreen(onNavigateTab: _onTabTapped),
    RetailBuyerProfileScreen(onNavigateTab: _onTabTapped),
  ];

  // FPO screens (5 primary tabs: Home, Inventory, Orders, Earnings, Profile)
  late final List<Widget> _fpoScreens = [
    FpoHomeScreen(onNavigateTab: _onTabTapped),
    const FpoInventoryScreen(),
    const FpoOrdersScreen(),
    const FpoSettlementScreen(),
    const FpoProfileScreen(),
  ];

  bool _isHi(AppLocalizations? l10n) => l10n?.localeName == 'hi';

  List<BottomNavigationBarItem> _getFpoNavItems(AppLocalizations? l10n) {
    final isHi = _isHi(l10n);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: isHi ? 'मुख्य पृष्ठ' : (l10n?.navHome ?? 'Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.inventory_2_outlined),
        activeIcon: const Icon(Icons.inventory_2),
        label: isHi ? 'गोदाम स्टॉक' : 'Inventory',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_bag_outlined),
        activeIcon: const Icon(Icons.shopping_bag),
        label: isHi ? 'ऑर्डर' : 'Orders',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        activeIcon: const Icon(Icons.account_balance_wallet),
        label: isHi ? 'आय / पेआउट' : 'Earnings',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: isHi ? 'प्रोफ़ाइल' : (l10n?.navProfile ?? 'Profile'),
      ),
    ];
  }

  List<BottomNavigationBarItem> _getFarmerNavItems(AppLocalizations? l10n) {
    final isHi = _isHi(l10n);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: isHi ? 'मुख्य पृष्ठ' : (l10n?.navHome ?? 'Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.agriculture_outlined),
        activeIcon: const Icon(Icons.agriculture),
        label: isHi ? 'मेरी फसलें' : (l10n?.navMyCrops ?? 'My Crops'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_bag_outlined),
        activeIcon: const Icon(Icons.shopping_bag),
        label: isHi ? 'ऑर्डर' : 'Orders',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt_long_outlined),
        activeIcon: const Icon(Icons.receipt_long),
        label: isHi ? 'पासबुक' : 'Passbook',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: isHi ? 'प्रोफ़ाइल' : (l10n?.navProfile ?? 'Profile'),
      ),
    ];
  }

  List<BottomNavigationBarItem> _getBulkBuyerNavItems(AppLocalizations? l10n) {
    final isHi = _isHi(l10n);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: isHi ? 'मुख्य पृष्ठ' : (l10n?.navHome ?? 'Home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.hub_outlined),
        activeIcon: const Icon(Icons.hub),
        label: isHi ? 'आपूर्ति' : 'Supply',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.assignment_outlined),
        activeIcon: const Icon(Icons.assignment),
        label: isHi ? 'मांगें (RFQs)' : 'RFQs',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.inventory_2_outlined),
        activeIcon: const Icon(Icons.inventory_2),
        label: isHi ? 'ऑर्डर' : 'Orders',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: isHi ? 'प्रोफ़ाइल' : (l10n?.navProfile ?? 'Profile'),
      ),
    ];
  }

  List<BottomNavigationBarItem> _getRetailBuyerNavItems(AppLocalizations? l10n) {
    final isHi = _isHi(l10n);
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: isHi ? 'मंडी बाज़ार' : 'Fresh Shop',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.hub_outlined),
        activeIcon: const Icon(Icons.hub),
        label: isHi ? '7km क्लस्टर' : '7km Clusters',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.shopping_bag_outlined),
        activeIcon: const Icon(Icons.shopping_bag),
        label: isHi ? 'खरीदारी' : 'Orders',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.favorite_border),
        activeIcon: const Icon(Icons.favorite),
        label: isHi ? 'पसंदीदा' : 'Saved',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: isHi ? 'प्रोफ़ाइल' : 'Profile',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        final firebaseUser = FirebaseAuth.instance.currentUser;

        // Show loading while user data is being loaded
        if (appState.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
          );
        }

        // If no user profile loaded yet, but Firebase user exists, load user profile
        if (user == null && firebaseUser != null) {
          if (!appState.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              appState.loadUserData(firebaseUser.uid);
            });
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.loading ?? 'Loading your profile...',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If no user at all, return LoginScreen
        if (user == null) {
          return const LoginScreen();
        }

        // Dedicated FPO Member Farmer experience (zero-marketplace, pure consignment & DBT dashboard)
        if (user.userType == UserType.fpoMemberFarmer) {
          return const FarmerFpoConsignmentDashboardScreen(isRootHome: true);
        }

        final isFpo = user.userType == UserType.fpo;
        final isBulkBuyer = user.userType == UserType.buyer;
        final isRetailBuyer = user.userType == UserType.retailBuyer;

        final screens = isFpo
            ? _fpoScreens
            : (isBulkBuyer
                ? _bulkBuyerScreens
                : (isRetailBuyer ? _retailBuyerScreens : _farmerScreens));

        final navItems = isFpo
            ? _getFpoNavItems(l10n)
            : (isBulkBuyer
                ? _getBulkBuyerNavItems(l10n)
                : (isRetailBuyer
                    ? _getRetailBuyerNavItems(l10n)
                    : _getFarmerNavItems(l10n)));

        // Ensure current index is within bounds
        if (_currentIndex >= screens.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: screens[_currentIndex],
            ),
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              boxShadow: AppTheme.floatingShadow,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onTabTapped,
                    items: navItems,
                    type: BottomNavigationBarType.fixed,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    selectedItemColor: AppTheme.primaryColor,
                    unselectedItemColor: AppTheme.textSecondary,
                    showSelectedLabels: true,
                    showUnselectedLabels: false,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      height: 1.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 10,
                    ),
                    iconSize: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
