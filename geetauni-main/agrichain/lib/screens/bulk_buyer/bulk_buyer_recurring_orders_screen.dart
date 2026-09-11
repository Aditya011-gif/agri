import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/recurring_order_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'create_recurring_order_screen.dart';

/// Screen: Bulk Buyer 12-Week Recurring Supply Orders Overview
/// Allows institutional buyers to track ongoing recurring contracts, review weekly tranches, and create new proposals.
class BulkBuyerRecurringOrdersScreen extends StatefulWidget {
  const BulkBuyerRecurringOrdersScreen({super.key});

  @override
  State<BulkBuyerRecurringOrdersScreen> createState() =>
      _BulkBuyerRecurringOrdersScreenState();
}

class _BulkBuyerRecurringOrdersScreenState
    extends State<BulkBuyerRecurringOrdersScreen> {
  final RecurringOrderService _orderService = RecurringOrderService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  String _selectedFilter = 'all'; // 'all', 'active', 'pending'

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final buyerId = user?.id.isNotEmpty == true ? user!.id : 'demo_buyer_001';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New 12-Week Agreement', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateRecurringOrderScreen()),
          );
          if (res == true && mounted) {
            setState(() {});
          }
        },
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: 'Recurring Supply Agreements',
            subtitle: '12-Week Institutional Procurement Contracts',
            showBackButton: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: () => setState(() {}),
              ),
            ],
          ),
        ],
        body: StreamBuilder<List<RecurringOrderModel>>(
          stream: _orderService.streamBuyerOrders(buyerId),
          builder: (context, snapshot) {
          final orders = snapshot.data ?? [];
          final filtered = _applyFilter(orders);

          final totalContractVolume = orders.fold<double>(0.0, (sum, o) => sum + o.totalQuantityQtl);
          final activeAgreements = orders.where((o) => o.status == 'active_contract').length;
          final pendingProposals = orders.where((o) => o.status == 'pending_fpo_approval').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Summary KPI Grid
              _buildKpiBanner(
                activeCount: activeAgreements,
                pendingCount: pendingProposals,
                totalVolumeQtl: totalContractVolume,
              ),
              const SizedBox(height: 16),

              // Filter Chips
              _buildFilterRow(orders),
              const SizedBox(height: 16),

              // Orders List
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ...filtered.map((order) => _buildOrderCard(order)),
            ],
          );
        },
      ),
      ),
    );
  }

  List<RecurringOrderModel> _applyFilter(List<RecurringOrderModel> list) {
    if (_selectedFilter == 'active') {
      return list.where((o) => o.status == 'active_contract').toList();
    }
    if (_selectedFilter == 'pending') {
      return list.where((o) => o.status == 'pending_fpo_approval').toList();
    }
    return list;
  }

  Widget _buildKpiBanner({
    required int activeCount,
    required int pendingCount,
    required double totalVolumeQtl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 8),
              Text(
                'INSTITUTIONAL FPO SUPPLY PIPELINE',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpiItem(
                  'Active 12-W Contracts',
                  '$activeCount',
                  const Color(0xFF22C55E),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _kpiItem(
                  'Pending FPO Review',
                  '$pendingCount',
                  const Color(0xFFFBBF24),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _kpiItem(
                  'Total Sourced',
                  '${(totalVolumeQtl / 10).toStringAsFixed(0)} MT',
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildFilterRow(List<RecurringOrderModel> allOrders) {
    final activeCount = allOrders.where((o) => o.status == 'active_contract').length;
    final pendingCount = allOrders.where((o) => o.status == 'pending_fpo_approval').length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'All Contracts (${allOrders.length})'),
          const SizedBox(width: 8),
          _filterChip('active', 'Active Agreements ($activeCount)'),
          const SizedBox(width: 8),
          _filterChip('pending', 'Pending Approval ($pendingCount)'),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF64748B),
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildOrderCard(RecurringOrderModel order) {
    final isActive = order.status == 'active_contract';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isActive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.repeat, color: Color(0xFF0F172A), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.commodity,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Partner: ${order.fpoName}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commercial specs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.weeklyQuantityQtl.toInt()} Qtl / week • 12 Weeks',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _currencyFormat.format(order.totalContractValue),
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: order.progressPercentage,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF15803D)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.completedTranchesCount} of 12 Tranches Fulfilled',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Cadence: Every ${order.dispatchDay}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detailed Info Rows
                _detailRow('Agreement Number:', order.recurringOrderNumber),
                _detailRow('Cluster Location:', order.fpoCluster),
                _detailRow('Agreed Price / Qtl:', _currencyFormat.format(order.agreedPricePerQtl)),
                _detailRow('Quality Grade:', order.qualityGrade),
                _detailRow('Factory Destination:', order.deliveryDestination),
                _detailRow('Contract Hash:', '${order.contractHash.substring(0, 16)}... (Polygon Verified)'),
                const SizedBox(height: 14),

                // Tranche Schedule List
                Text('Weekly Tranche Breakdown (12 Weeks)',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...order.tranches.map((t) => _buildTrancheRow(t, order)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrancheRow(RecurringTranche t, RecurringOrderModel order) {
    Color statusColor = const Color(0xFF64748B);
    String statusText = 'Scheduled';
    IconData statusIcon = Icons.schedule;

    if (t.status == 'paid' || t.status == 'delivered') {
      statusColor = const Color(0xFF15803D);
      statusText = t.status == 'paid' ? 'Paid & Settled' : 'Delivered';
      statusIcon = Icons.check_circle;
    } else if (t.status == 'dispatched') {
      statusColor = const Color(0xFF2563EB);
      statusText = 'In-Transit (Dispatched)';
      statusIcon = Icons.local_shipping;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${t.weekNumber} • ${DateFormat('dd MMM (EEE)').format(t.scheduledDate)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (t.vehicleNumber != null)
                  Text('Truck: ${t.vehicleNumber}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.quantityQtl.toInt()} Qtl',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFB45309);
    String label = 'PENDING FPO';

    if (status == 'active_contract') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'ACTIVE 12-W';
    } else if (status == 'completed') {
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF4338CA);
      label = 'COMPLETED';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'DECLINED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.repeat, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text('No Recurring Supply Agreements Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Tap below to configure a 12-week contract with vetted FPOs.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
