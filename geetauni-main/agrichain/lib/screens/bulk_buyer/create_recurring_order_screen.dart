import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_order_model.dart';
import '../../models/crop_benchmark_model.dart';
import '../../providers/app_state.dart';
import '../../services/recurring_order_service.dart';
import '../../widgets/custom_app_bar.dart';

/// Screen: Create 12-Week Recurring Supply Order
/// Dedicated to Corporate Bulk Buyers to configure weekly procurement and compare candidate FPOs.
class CreateRecurringOrderScreen extends StatefulWidget {
  final String? preselectedCommodity;
  const CreateRecurringOrderScreen({super.key, this.preselectedCommodity});

  @override
  State<CreateRecurringOrderScreen> createState() =>
      _CreateRecurringOrderScreenState();
}

class _CreateRecurringOrderScreenState extends State<CreateRecurringOrderScreen> {
  final RecurringOrderService _orderService = RecurringOrderService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  int _currentStep = 0; // 0: Config, 1: Compare FPOs, 2: Review

  // Form selections
  late String _selectedCommodity;
  String _selectedVariety = 'PBW-502 Milling Grade';
  double _weeklyQuantityQtl = 100.0;
  final int _totalWeeks = 12;
  String _dispatchDay = 'Monday';
  final TextEditingController _destinationController = TextEditingController(
    text: 'Sonepat Processing Plant, Sector 38, HSIIDC, Haryana',
  );
  late final TextEditingController _quantityController;

  final List<String> _commodities = CropBenchmark.allCropNames;
  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  CropBenchmark? get _currentBenchmark => CropBenchmark.findByName(_selectedCommodity);

  List<FpoSupplyCandidate> _fpoCandidates = [];
  FpoSupplyCandidate? _selectedFpo;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '100');
    _selectedCommodity = widget.preselectedCommodity ?? _commodities.first;
    _updateVarietyAndCandidates();
  }

  void _updateVarietyAndCandidates() {
    final bm = CropBenchmark.findByName(_selectedCommodity);
    if (bm != null) {
      _selectedVariety = bm.defaultVariety;
    } else {
      _selectedVariety = 'Commercial Milling Grade';
    }

    _fpoCandidates = _orderService.getCandidateFposForCrop(_selectedCommodity);
    if (_fpoCandidates.isNotEmpty) {
      _selectedFpo = _fpoCandidates.first;
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitProposal() async {
    if (_selectedFpo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an FPO supplier')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.currentUser;
    final buyerId = user?.id.isNotEmpty == true ? user!.id : 'demo_buyer_001';
    final buyerName = user?.name.isNotEmpty == true ? user!.name : 'AgroFoods Milling India Pvt Ltd';

    final created = await _orderService.createProposal(
      buyerId: buyerId,
      buyerName: buyerName,
      buyerCompany: 'AgroFoods Milling Division',
      deliveryDestination: _destinationController.text.trim(),
      selectedFpo: _selectedFpo!,
      commodity: _selectedCommodity,
      variety: _selectedVariety,
      weeklyQuantityQtl: _weeklyQuantityQtl,
      dispatchDay: _dispatchDay,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      _showSuccessDialog(created);
    }
  }

  void _showSuccessDialog(RecurringOrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              '12-Week Proposal Submitted!',
              style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sent to ${_selectedFpo?.fpoName}. The FPO will review the 12-week schedule and accept/decline the master agreement.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _dialogRow('Proposal ID:', order.recurringOrderNumber),
                  _dialogRow('Volume:', '${_weeklyQuantityQtl.toInt()} Qtl / week (1,200 Qtl total)'),
                  _dialogRow('Total Escrow Value:', _currencyFormat.format(order.totalContractValue)),
                  _dialogRow('Dispatch Schedule:', 'Every Monday (12 Tranches)'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('View My Recurring Orders'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomActionButtons(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const CustomAppBar(
            title: 'New 12-Week Supply Agreement',
            subtitle: 'Recurring Procurement for Institutional Buyers',
            showBackButton: true,
          ),
        ],
        body: Column(
          children: [
            // Step progress header
            _buildStepProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _buildProgressItem(0, '1. Requirements'),
          _buildProgressDivider(0),
          _buildProgressItem(1, '2. Compare FPOs'),
          _buildProgressDivider(1),
          _buildProgressItem(2, '3. Review Contract'),
        ],
      ),
    );
  }

  Widget _buildProgressItem(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isDone
              ? const Color(0xFF16A34A)
              : (isActive ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDivider(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Requirements();
      case 1:
        return _buildStep2CompareFpos();
      case 2:
      default:
        return _buildStep3Review();
    }
  }

  // STEP 1: Requirements Configurator
  Widget _buildStep1Requirements() {
    final bm = _currentBenchmark;
    final totalContractQtl = _weeklyQuantityQtl * _totalWeeks;
    final totalContractMt = totalContractQtl / 10.0;
    final mspRate = bm?.mspPerQtl ?? 2275.0;
    final estMspValuation = totalContractQtl * mspRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCallout(
          'Automated 12-Week Supply Contract',
          'Lock in steady raw material delivery directly from vetted FPO clusters with quality guarantees and pro-rata weekly payments.',
          Icons.repeat,
        ),
        const SizedBox(height: 16),

        // Commodity Selection
        _buildSectionTitle('Select Agricultural Commodity'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedCommodity,
              items: _commodities
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCommodity = val;
                    _updateVarietyAndCandidates();
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Official MSP & Market Benchmark Rate Card
        if (bm != null) _buildMspBenchmarkCard(bm),
        const SizedBox(height: 16),

        // Variety Specification
        _buildSectionTitle('Target Variety / Specification'),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(_selectedCommodity),
          initialValue: _selectedVariety,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (v) => _selectedVariety = v,
        ),
        const SizedBox(height: 20),

        // Weekly Volume (UNLIMITED, with numeric entry + quick presets)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Weekly Required Volume'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_weeklyQuantityQtl.toInt()} Quintals (${(_weeklyQuantityQtl / 10).toStringAsFixed(1)} MT / week)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Quick Preset Volume Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [100, 250, 500, 1000, 2500, 5000, 10000].map((preset) {
              final isSelected = _weeklyQuantityQtl.toInt() == preset;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    preset >= 1000 ? '${preset ~/ 10} MT ($preset Qtl)' : '$preset Qtl',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF15803D),
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _weeklyQuantityQtl = preset.toDouble();
                      _quantityController.text = preset.toString();
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Direct Custom Numeric Entry Field
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Custom Weekly Volume (Quintals)',
                  hintText: 'Enter any quantity (No max limit)',
                  filled: true,
                  fillColor: Colors.white,
                  suffixText: 'Qtl / week',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.fitness_center_outlined, color: Color(0xFF15803D)),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val.trim());
                  if (parsed != null && parsed > 0) {
                    setState(() {
                      _weeklyQuantityQtl = parsed;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Volume metric banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12-Week Total: ${totalContractQtl.toInt()} Qtl (${totalContractMt.toStringAsFixed(1)} MT)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'MSP Floor Est: ${_currencyFormat.format(estMspValuation)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Flexible Dispatch Weekday Selection
        _buildSectionTitle('Fulfillment Cadence & Dispatch Weekday'),
        const SizedBox(height: 4),
        const Text(
          'Select the preferred day of the week for recurring tranche dispatch from FPO godown:',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        // Weekday Selector Chips (Mon - Sun)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _weekDays.map((day) {
              final isSelected = _dispatchDay.toLowerCase() == day.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    day,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontSize: 12,
                    ),
                  ),
                  avatar: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : const Icon(Icons.calendar_today, size: 12, color: Color(0xFF64748B)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF15803D),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _dispatchDay = day);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Cadence info box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Contract Duration', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    SizedBox(height: 2),
                    Text('12 Weeks (Quarterly)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weekly Dispatch Day', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      'Every $_dispatchDay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Delivery Destination
        _buildSectionTitle('Factory / Delivery Destination'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _destinationController,
          maxLines: 2,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF15803D)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  /// Official Govt MSP & Mandi Benchmark Rate Card
  Widget _buildMspBenchmarkCard(CropBenchmark bm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF15803D).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, size: 16, color: Color(0xFF15803D)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Official Market Price Guidance • ${bm.hindiName}',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bm.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Govt MSP Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Govt. MSP (2024-25)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(bm.mspPerQtl),
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      const Text(
                        'Statutory floor rate / Qtl',
                        style: TextStyle(fontSize: 9.5, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Mandi Average Range Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mandi Modal Range',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_currencyFormat.format(bm.mandiMinPrice)} - ${_currencyFormat.format(bm.mandiMaxPrice)}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      Text(
                        'Avg: ${_currencyFormat.format(bm.mandiAvgPrice)} / Qtl',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Standard Spec: ${bm.standardMoisture} • Producing Hubs: ${bm.majorStates.join(", ")}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // STEP 2: Live FPO Comparison Matrix
  Widget _buildStep2CompareFpos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCallout(
          'FPO Comparison Matrix',
          'Compare active FPO clusters holding certified inventory for $_selectedCommodity. Select the FPO that fits your price, transit ETA, and quality requirements.',
          Icons.compare_arrows,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Available FPO Suppliers (${_fpoCandidates.length})'),
            const Text('Ranked by Reliability & Distance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),

        ..._fpoCandidates.map((fpo) => _buildFpoCandidateCard(fpo)),
      ],
    );
  }

  Widget _buildFpoCandidateCard(FpoSupplyCandidate fpo) {
    final isSelected = _selectedFpo?.fpoId == fpo.fpoId;
    final totalOrderValue = _weeklyQuantityQtl * fpo.pricePerQtl * _totalWeeks;

    return GestureDetector(
      onTap: () => setState(() => _selectedFpo = fpo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF15803D) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF15803D).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: FPO name, rating, selection radio
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fpo.fpoName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            '${fpo.clusterLocation} • ${fpo.distanceKm.toInt()} km away',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF15803D) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Comparison Metrics Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Price / Qtl', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(fpo.pricePerQtl),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Transit Time (ETA)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transit ETA', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              '${fpo.estimatedTransitHours} hrs',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Quality Grade
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quality & Moisture', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '${fpo.moisturePct}% Moist.',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Track Record & Total 12-Week Estimate
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text('${fpo.reliabilityRating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(' (${fpo.successfulContracts} contracts executed)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                Text(
                  '12-Week Total: ${_currencyFormat.format(totalOrderValue)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Review & Submit
  Widget _buildStep3Review() {
    if (_selectedFpo == null) {
      return const Center(child: Text('No FPO selected.'));
    }

    final totalValue = _weeklyQuantityQtl * _selectedFpo!.pricePerQtl * _totalWeeks;
    final totalVolume = _weeklyQuantityQtl * _totalWeeks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCallout(
          'Master Supply Agreement Preview',
          'Review the binding 12-week schedule. Submitting this proposal notifies ${_selectedFpo!.fpoName} for formal tripartite contract ratification.',
          Icons.gavel,
        ),
        const SizedBox(height: 16),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contract Commercials', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              _reviewRow('Commodity & Variety', '$_selectedCommodity ($_selectedVariety)'),
              _reviewRow('FPO Partner', _selectedFpo!.fpoName),
              _reviewRow('Cluster Location', _selectedFpo!.clusterLocation),
              _reviewRow('Weekly Intake Volume', '${_weeklyQuantityQtl.toInt()} Quintals (${(_weeklyQuantityQtl / 10).toStringAsFixed(1)} MT)'),
              _reviewRow('Total Contract Volume', '${totalVolume.toInt()} Quintals (${(totalVolume / 10).toStringAsFixed(1)} MT)'),
              _reviewRow('Contract Duration', '12 Weeks'),
              _reviewRow('Dispatch Cadence', 'Every $_dispatchDay'),
              _reviewRow('Price per Quintal', _currencyFormat.format(_selectedFpo!.pricePerQtl)),
              _reviewRow('Estimated Transit Window', '${_selectedFpo!.estimatedTransitHours} Hours'),
              _reviewRow('Quality Specification', _selectedFpo!.qualityGrade),
              _reviewRow('Delivery Destination', _destinationController.text),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total 12-Week Financial Commitment:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    _currencyFormat.format(totalValue),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Schedule breakdown preview
        Text('12-Week Delivery Tranches', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(3, (i) {
          final now = DateTime.now();
          final trancheDate = now.add(Duration(days: (i + 1) * 7));
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tranche ${i + 1}: ${DateFormat('dd MMM yyyy (EEE)').format(trancheDate)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${_weeklyQuantityQtl.toInt()} Qtl • ${_currencyFormat.format(_weeklyQuantityQtl * _selectedFpo!.pricePerQtl)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
        Center(
          child: Text(
            '+ 9 additional weekly Monday delivery tranches scheduled',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildInfoCallout(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF15803D), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF14532D))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep < 2) {
                        setState(() => _currentStep++);
                      } else {
                        _submitProposal();
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _currentStep == 2 ? 'Submit 12-Week Proposal to FPO' : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
