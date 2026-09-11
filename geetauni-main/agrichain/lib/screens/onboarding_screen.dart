import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrichain/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/language_switcher.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<OnboardingData> _getOnboardingData(AppLocalizations? l10n) => [
    OnboardingData(
      title: l10n?.onboardingTitle1 ?? 'Direct Agricultural Marketplace',
      subtitle: l10n?.marketplaceSubtitle ?? 'Connect directly with buyers and sellers',
      description: l10n?.onboardingDesc1 ??
          'Experience the future of farming with blockchain technology that ensures every transaction is secure and verifiable.',
      icon: Icons.store,
      gradient: [AppTheme.primaryColor, AppTheme.primaryVariant],
      features: [
        'Direct Trading',
        'Transparent Pricing',
        'Quality Assurance',
      ],
    ),
    OnboardingData(
      title: l10n?.onboardingTitle2 ?? 'AI Land Intelligence & Agri-Score',
      subtitle: l10n?.landAnalysisDesc ?? 'Evaluate satellite vegetation, soil parameters, and ML yield predictions',
      description: l10n?.onboardingDesc2 ??
          'Leverage satellite NDVI, soil data, and machine learning to build instant trust with buyers.',
      icon: Icons.satellite_alt,
      gradient: [AppTheme.secondaryColor, AppTheme.secondaryVariant],
      features: ['Satellite NDVI', 'Soil Intelligence', 'Trust Score'],
    ),
    OnboardingData(
      title: l10n?.onboardingTitle3 ?? 'Instant DeFi Micro-Loans',
      subtitle: l10n?.loanSectionSubtitle ?? 'Get instant loans backed by crop & land collateral',
      description: l10n?.onboardingDesc3 ??
          'Unlock flexible financing against your listed crops with transparent smart contracts.',
      icon: Icons.account_balance_wallet,
      gradient: [AppTheme.info, const Color(0xFF1976D2)],
      features: [
        'Crop Micro-Loans',
        'Transparent Rates',
        'Fast Disbursal',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(int dataLength) {
    if (_currentPage < dataLength - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _navigateToLogin();
  }

  void _navigateToLogin() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onboardingData = _getOnboardingData(l10n);

    if (_currentPage >= onboardingData.length) {
      _currentPage = 0;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: onboardingData[_currentPage].gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Language Switcher and Skip
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const LanguageSwitcherPill(isDark: true),
                    Text(
                      l10n?.appTitle ?? 'AgriChain',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        l10n?.skip ?? 'Skip',
                        style: TextStyle(
                          color: AppTheme.white.withOpacity(0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    onboardingData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? AppTheme.white
                            : AppTheme.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _animationController.reset();
                    _animationController.forward();
                    HapticFeedback.lightImpact();
                  },
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildOnboardingPage(onboardingData[index]),
                      ),
                    );
                  },
                ),
              ),

              // Navigation Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Button
                    _currentPage > 0
                        ? TextButton.icon(
                            onPressed: _previousPage,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppTheme.white,
                            ),
                            label: Text(
                              l10n?.back ?? 'Previous',
                              style: const TextStyle(color: AppTheme.white),
                            ),
                          )
                        : const SizedBox(width: 100),

                    // Next/Get Started Button
                    ElevatedButton(
                      onPressed: () => _nextPage(onboardingData.length),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.white,
                        foregroundColor:
                            onboardingData[_currentPage].gradient[0],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == onboardingData.length - 1
                                ? (l10n?.getStarted ?? 'Get Started')
                                : (l10n?.next ?? 'Next'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == onboardingData.length - 1
                                ? Icons.rocket_launch
                                : Icons.arrow_forward,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingData data) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(
                color: AppTheme.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(data.icon, size: 60, color: AppTheme.white),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            data.subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Description
          Text(
            data.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.white.withOpacity(0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Features
          Column(
            children: data.features.map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.white, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      feature,
                      style: TextStyle(
                        color: AppTheme.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ),
  );
}
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.features,
  });
}
