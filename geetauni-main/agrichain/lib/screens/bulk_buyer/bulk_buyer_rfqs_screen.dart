import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../models/crop_benchmark_model.dart';

class BulkBuyerRfqsScreen extends StatefulWidget {
  const BulkBuyerRfqsScreen({super.key});

  @override
  State<BulkBuyerRfqsScreen> createState() => _BulkBuyerRfqsScreenState();
}

class _BulkBuyerRfqsScreenState extends State<BulkBuyerRfqsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  final List<String> _tabs = [
    'Active',
    'Draft',
    'Responses',
    'Completed',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final buyerId = user?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRfqModal(context, buyerId, user?.name ?? 'AgroFoods India'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post Requirement', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const CustomAppBar(
            title: 'Manage Bulk RFQs',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  _buildRfqHeaderCard(),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: _tabs.map((t) => Tab(text: t)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRfqsList(statusFilter: 'open'),
            _buildRfqsList(statusFilter: 'draft'),
            _buildRfqsList(statusFilter: 'quoted'),
            _buildRfqsList(statusFilter: 'completed'),
            _buildRfqsList(statusFilter: 'expired'),
          ],
        ),
      ),
    );
  }

  Widget _buildRfqHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Institutional RFQ Engine',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Broadcast bulk requirements across 1,200+ FPOs with automatic 7 km cluster matching.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF388E3C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRfqsList({required String statusFilter}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dbService.streamBulkRfqs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRfqs = snapshot.data ?? [];
        final rfqs = allRfqs.where((r) {
          final status = (r['status'] ?? 'open').toString().toLowerCase();
          if (statusFilter == 'open') return status == 'open' || status == 'active';
          if (statusFilter == 'quoted') return status == 'quoted' || (r['quotesCount'] as int? ?? 0) > 0;
          return status == statusFilter;
        }).toList();

        if (rfqs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 60,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $statusFilter RFQs Found',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Post Requirement" below to broadcast a new procurement tender to FPOs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          itemCount: rfqs.length,
          itemBuilder: (context, index) {
            final rfq = rfqs[index];
            return _buildRfqCard(rfq);
          },
        );
      },
    );
  }

  Widget _buildRfqCard(Map<String, dynamic> rfq) {
    final title = rfq['title'] ?? '${rfq['commodity']} Requirement';
    final variety = rfq['variety'] ?? 'Standard';
    final qtyQtl = _toDouble(rfq['requiredQuantityQtl'] ?? (_toDouble(rfq['requiredQuantityMT']) * 10 > 0 ? _toDouble(rfq['requiredQuantityMT']) * 10 : (_toDouble(rfq['requiredQuantityKg']) / 100)));
    final maxPriceQtl = _toDouble(rfq['maxPricePerQtl'] ?? (_toDouble(rfq['maxPricePerKg']) * 100));
    final grade = rfq['qualityGrade'] ?? 'Grade A';
    final location = rfq['deliveryLocation'] ?? 'Processing Plant';
    final deadline = rfq['deliveryDeadline'] ?? 'Immediate';
    final matchedCount = (rfq['matchedFposCount'] as int?) ?? 24;
    final quotesCount = (rfq['quotesCount'] as int?) ?? 0;
    final status = rfq['status'] ?? 'open';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '$variety • $grade',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'open'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'open' ? 'ACTIVE' : status.toString().toUpperCase(),
                    style: TextStyle(
                      color: status == 'open'
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Spec Badges
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecPill(
                        label: 'Required Volume',
                        value: '${qtyQtl.toStringAsFixed(0)} Qtl',
                        icon: Icons.scale_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecPill(
                        label: 'Max Budget Rate',
                        value: '₹${maxPriceQtl.toStringAsFixed(0)}/Qtl',
                        icon: Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecPill(
                        label: 'Delivery Point',
                        value: location.split(',').first,
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecPill(
                        label: 'Target Window',
                        value: deadline,
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Match Status Alert Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC5E1A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hub, color: Color(0xFF2E7D32), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$matchedCount FPO matches found within 7 km clusters',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      if (quotesCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$quotesCount Quotes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _showResponsesDialog(rfq),
                        icon: const Icon(Icons.forum_outlined, size: 16),
                        label: Text(quotesCount > 0 ? 'View $quotesCount Responses' : 'View Responses'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _showEditRfqDialog(rfq),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _cancelRfq(rfq['id']),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                      tooltip: 'Cancel RFQ',
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

  Widget _buildSpecPill({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResponsesDialog(Map<String, dynamic> rfq) {
    final title = rfq['title'] ?? 'RFQ Responses';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FPO Responses & Quotes',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildQuoteTile(
                      fpoName: 'Karnal Agro Producer Co.',
                      quantityMT: 1200,
                      quotedRate: 3550,
                      qualityGrade: 'Grade A (Moisture 11.0%)',
                      location: 'Karnal Silo (6.2 km from hub)',
                      rating: 4.9,
                    ),
                    _buildQuoteTile(
                      fpoName: 'Taraori Kisan Producer Co.',
                      quantityMT: 1000,
                      quotedRate: 3560,
                      qualityGrade: 'Grade A (Moisture 11.3%)',
                      location: 'Taraori Yard (8.1 km from hub)',
                      rating: 4.8,
                    ),
                    _buildQuoteTile(
                      fpoName: 'Gharaunda Farmers Producer Co.',
                      quantityMT: 800,
                      quotedRate: 3580,
                      qualityGrade: 'Grade A (Moisture 10.9%)',
                      location: 'Gharaunda Silo (12 km from hub)',
                      rating: 4.7,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Accepted Combined Quotes! Consolidated PO Generated.'),
                        backgroundColor: Color(0xFF2E7D32),
                      ),
                    );
                  },
                  icon: const Icon(Icons.handshake),
                  label: const Text('Accept All 3 Clustered Quotes (3,000 Qtl Total)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuoteTile({
    required String fpoName,
    required double quantityMT,
    required double quotedRate,
    required String qualityGrade,
    required String location,
    required double rating,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  fpoName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Supply: ${quantityMT.toStringAsFixed(0)} Qtl',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              Text(
                '₹${quotedRate.toStringAsFixed(0)}/Qtl',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateRfqModal(BuildContext context, String buyerId, String buyerName) {
    final formKey = GlobalKey<FormState>();
    final commodityController = TextEditingController(text: 'Wheat');
    final varietyController = TextEditingController(text: 'Sharbati 306');
    final qtyController = TextEditingController(text: '3000');
    final maxPriceController = TextEditingController(text: '3600');
    final locationController = TextEditingController(text: 'Pune Processing Plant');
    final deadlineController = TextEditingController(text: 'Monday, 10:00 AM');
    String selectedGrade = 'Grade A (Milling Grade)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Post Bulk Requirement (RFQ)',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Broadcast your bulk demand across regional FPO clusters.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const Divider(height: 24),

                        // Categorized Commodity Dropdown Selector
                        Text(
                          'Select Commodity (फल / सब्जी / अनाज / दलहन) *',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: CropBenchmark.catalog.any((c) => c.name == commodityController.text)
                                  ? commodityController.text
                                  : CropBenchmark.catalog.first.name,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFF2E7D32)),
                              items: CropBenchmark.catalog.map((bench) {
                                String icon = '🌾';
                                if (bench.category == 'Fruits') icon = '🍎';
                                if (bench.category.contains('Vegetable')) icon = '🥦';
                                if (bench.category.contains('Oilseed')) icon = '🌻';
                                if (bench.category.contains('Pulse')) icon = '🫘';
                                if (bench.category.contains('Spice')) icon = '🌶️';

                                return DropdownMenuItem<String>(
                                  value: bench.name,
                                  child: Row(
                                    children: [
                                      Text(icon, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${bench.name} (${bench.hindiName})',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.darkGreen,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: bench.category == 'Fruits'
                                              ? Colors.orange.shade50
                                              : bench.category.contains('Vegetable')
                                                  ? Colors.green.shade50
                                                  : Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          bench.category,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: bench.category == 'Fruits'
                                                ? Colors.orange.shade900
                                                : bench.category.contains('Vegetable')
                                                    ? Colors.green.shade900
                                                    : Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (selectedName) {
                                if (selectedName != null) {
                                  final benchmark = CropBenchmark.catalog.firstWhere(
                                    (c) => c.name == selectedName,
                                    orElse: () => CropBenchmark.catalog.first,
                                  );
                                  setModalState(() {
                                    commodityController.text = benchmark.name;
                                    varietyController.text = benchmark.defaultVariety;
                                    maxPriceController.text = benchmark.mandiAvgPrice.toStringAsFixed(0);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Variety Input Field
                        TextFormField(
                          controller: varietyController,
                          decoration: const InputDecoration(
                            labelText: 'Variety / Specification *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.style),
                            helperText: 'Auto-suggested from Indian APMC standards',
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                    // Quantity (Qtl) & Max Price
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity (Quintals / Qtl) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.scale),
                              suffixText: 'Qtl',
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Target (₹/Qtl) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quality Grade Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Quality Grade',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified),
                      ),
                      items: [
                        'Grade A (Milling Grade)',
                        'Super Fine (Export)',
                        'FAQ (Fair Average Quality)',
                        'Standard Processing',
                      ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => selectedGrade = v ?? selectedGrade,
                    ),
                    const SizedBox(height: 12),

                    // Delivery Location & Deadline
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Destination *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: deadlineController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Window / Deadline *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_month),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final qtyQtl = double.tryParse(qtyController.text) ?? 3000.0;
                            final maxRate = double.tryParse(maxPriceController.text) ?? 3600.0;

                            await _dbService.createBulkRfq({
                              'title': '${qtyQtl.toStringAsFixed(0)} Qtl ${commodityController.text} (${varietyController.text})',
                              'commodity': commodityController.text,
                              'variety': varietyController.text,
                              'requiredQuantityQtl': qtyQtl,
                              'requiredQuantityMT': qtyQtl / 10,
                              'requiredQuantityKg': qtyQtl * 100,
                              'maxPricePerQtl': maxRate,
                              'maxPricePerKg': maxRate / 100,
                              'qualityGrade': selectedGrade,
                              'deliveryLocation': locationController.text,
                              'deliveryDeadline': deadlineController.text,
                              'buyerId': buyerId,
                              'buyerName': buyerName,
                              'status': 'open',
                              'matchedFposCount': 24,
                              'quotesCount': 0,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bulk RFQ broadcasted to FPOs successfully!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Broadcast Requirement to FPOs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
}

  void _showEditRfqDialog(Map<String, dynamic> rfq) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Editing RFQ specifications...')),
    );
  }

  void _cancelRfq(String? rfqId) {
    if (rfqId == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel RFQ?'),
        content: const Text('Are you sure you want to withdraw this requirement from FPOs?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Active')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('RFQ cancelled.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Cancel RFQ'),
          ),
        ],
      ),
    );
  }
}
