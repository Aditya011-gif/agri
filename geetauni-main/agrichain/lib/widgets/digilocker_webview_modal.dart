import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/firestore_models.dart';
import '../providers/app_state.dart';
import '../services/digilocker_service.dart';

class DigilockerWebviewModal extends StatefulWidget {
  const DigilockerWebviewModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DigilockerWebviewModal(),
    );
  }

  @override
  State<DigilockerWebviewModal> createState() => _DigilockerWebviewModalState();
}

class _DigilockerWebviewModalState extends State<DigilockerWebviewModal> {
  bool _isLoading = true;
  String? _errorMessage;
  DigilockerSessionResponse? _session;
  DigilockerProfile? _verifiedProfile;
  String _liveStatus = 'created';
  bool _isCheckingStatus = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = await DigilockerService.initiateSession();
    if (!mounted) return;

    if (session != null) {
      setState(() {
        _session = session;
        _isLoading = false;
        _liveStatus = 'created';
      });
      _startStatusPolling();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to Sandbox.co.in gateway. Check network or proxy.';
      });
    }
  }

  void _startStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_session == null || _verifiedProfile != null) {
        timer.cancel();
        return;
      }
      await _checkStatus(silent: true);
    });
  }

  Future<void> _launchAuthUrl() async {
    if (_session == null) return;
    final uri = Uri.parse(_session!.authorizationUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external browser for DigiLocker.')),
        );
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _checkStatus({bool silent = false}) async {
    if (_session == null) return;
    if (!silent) {
      setState(() => _isCheckingStatus = true);
    }

    try {
      final status = await DigilockerService.checkSessionStatus(_session!.sessionId);
      if (!mounted) return;

      setState(() => _liveStatus = status);

      if (status == 'succeeded' || status == 'completed') {
        _pollingTimer?.cancel();
        final profile = await DigilockerService.fetchAadhaarDocument(_session!.sessionId);
        if (mounted && profile != null) {
          setState(() {
            _verifiedProfile = profile;
            _isCheckingStatus = false;
          });
        }
      } else {
        if (!silent && mounted) {
          setState(() => _isCheckingStatus = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Live Status: $status. Please complete verification in the opened DigiLocker tab.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  void _completeLoginWithRole(UserType role) {
    if (_verifiedProfile == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setDigilockerUserRole(role, _verifiedProfile!);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF15803D),
        content: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Signed in via Real DigiLocker: ${_verifiedProfile!.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Official Government Header
          _buildOfficialHeader(),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0284C7)),
                        SizedBox(height: 16),
                        Text('Connecting to Official Sandbox.co.in Gateway...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _startSession,
                                child: const Text('Retry Connection'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _verifiedProfile != null
                        ? _buildVerifiedProfileView()
                        : _buildLivePortalGatewayView(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('🇮🇳', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Meri',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    Text(
                      'Pehchaan',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE NSSO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'GOVERNMENT OF INDIA • DigiLocker e-KYC Verification',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePortalGatewayView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informational Alert
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF15803D), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real Government DigiLocker Verification',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'You will be redirected to the official MeriPehchaan (digilocker.meripehchaan.gov.in) portal to authenticate with your actual Aadhaar or Mobile OTP. Once approved, your real verified profile will automatically sync here.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF14532D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Session Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
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
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _liveStatus == 'succeeded'
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Sandbox Session: $_liveStatus',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Session ID: ${_session?.sessionId ?? ""}',
                  style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registered Sandbox Client: IW55C7A3B0',
                  style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF0284C7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Button: Open Official Government Portal
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _launchAuthUrl,
              icon: const Icon(Icons.open_in_browser, color: Colors.white, size: 22),
              label: Text(
                '🌐 Open Official DigiLocker Portal',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Check Status Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isCheckingStatus ? null : () => _checkStatus(silent: false),
              icon: _isCheckingStatus
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              label: Text(
                _isCheckingStatus ? 'Checking Verification Status...' : '🔄 Check Verification Status',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Instructions Steps Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Real DigiLocker Verification Works:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInstructionRow('1', 'Tap "Open Official DigiLocker Portal" above to open the government website.'),
                _buildInstructionRow('2', 'Enter your actual Mobile number or 12-digit Aadhaar number.'),
                _buildInstructionRow('3', 'Enter the real 6-digit OTP received from UIDAI on your phone.'),
                _buildInstructionRow('4', 'Click "Allow" on DigiLocker to grant consent.'),
                _buildInstructionRow('5', 'This screen automatically receives the webhook and pulls your official Aadhaar KYC record!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedProfileView() {
    final p = _verifiedProfile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aadhaar Card Visual
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                  blurRadius: 16,
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
                    Row(
                      children: [
                        const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          'Mera Aadhaar, Meri Pehchaan',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'OFFICIAL UIDAI VERIFIED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  p.fullName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DOB: ${p.dob ?? "Available"} • Gender: ${p.gender ?? "Male"}',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Text(
                  p.address ?? 'Government of India e-KYC Verified Address',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.maskedAadhaar,
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      p.certificateId,
                      style: GoogleFonts.robotoMono(color: Colors.white60, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Select Your AgriChain Role to Enter:',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          _buildRoleChoiceCard(
            title: '🌾 Farmer (Kisan Portal)',
            subtitle: 'List crops, access MSP forecasting & direct buyer pooling',
            role: UserType.farmer,
          ),
          _buildRoleChoiceCard(
            title: '🏢 FPO Cooperative Manager',
            subtitle: 'Manage warehouse inventory, silo lots & multi-farm contracts',
            role: UserType.fpo,
          ),
          _buildRoleChoiceCard(
            title: '🏭 Bulk Buyer / Processor',
            subtitle: 'Procure multi-ton lots, road-routing & escrow agreements',
            role: UserType.buyer,
          ),
          _buildRoleChoiceCard(
            title: '🛒 Retail Consumer',
            subtitle: 'Direct farm produce purchase, cluster pooling & escrow',
            role: UserType.retailBuyer,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChoiceCard({
    required String title,
    required String subtitle,
    required UserType role,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF0284C7)),
        onTap: () => _completeLoginWithRole(role),
      ),
    );
  }
}
