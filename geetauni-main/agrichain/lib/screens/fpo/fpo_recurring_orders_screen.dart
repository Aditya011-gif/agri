import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_order_model.dart';
import '../../providers/app_state.dart';
import '../../services/recurring_order_service.dart';
import '../../widgets/custom_app_bar.dart';

/// Screen: FPO Recurring Supply Agreements Management
/// Dedicated to FPOs to review incoming 12-week corporate buyer proposals, accept/decline,
/// and execute automated weekly Monday dispatches.
class FpoRecurringOrdersScreen extends StatefulWidget {
  const FpoRecurringOrdersScreen({super.key});

  @override
  State<FpoRecurringOrdersScreen> createState() =>
      _FpoRecurringOrdersScreenState();
}

class _FpoRecurringOrdersScreenState extends State<FpoRecurringOrdersScreen>
    with SingleTickerProviderStateMixin {
  final RecurringOrderService _orderService = RecurringOrderService();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final fpoId = user?.id.isNotEmpty == true ? user!.id : 'fpo_karnal_01';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CustomAppBar(
            title: 'Institutional Recurring Orders',
            subtitle: '12-Week Corporate Procurement Commitments',
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
        stream: _orderService.streamFpoOrders(fpoId),
        builder: (context, snapshot) {
          final orders = snapshot.data ?? [];
          final pending = orders.where((o) => o.status == 'pending_fpo_approval').toList();
          final active = orders.where((o) => o.status == 'active_contract' || o.status == 'completed').toList();

          return Column(
            children: [
              // Top Tab Bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF15803D),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF15803D),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Incoming Proposals'),
                          if (pending.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${pending.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(text: 'Active 12-W Contracts (${active.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Incoming Proposals
                    _buildPendingList(pending),
                    // Tab 2: Active Contracts
                    _buildActiveList(active),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  // TAB 1: Incoming Proposals
  Widget _buildPendingList(List<RecurringOrderModel> pendingList) {
    if (pendingList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text('No Pending Proposals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Corporate buyer recurring order proposals will appear here.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      itemBuilder: (context, index) {
        final order = pendingList[index];
        return _buildPendingProposalCard(order);
      },
    );
  }

  Widget _buildPendingProposalCard(RecurringOrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Buyer info & Pending tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.buyerCompany,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Buyer Contact: ${order.buyerName}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'REVIEW NEEDED',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Proposal specs
          _infoRow('Requested Crop:', '${order.commodity} (${order.variety})'),
          _infoRow('Quality Spec:', order.qualityGrade),
          _infoRow('Weekly Volume:', '${order.weeklyQuantityQtl.toInt()} Qtl (${(order.weeklyQuantityQtl / 10).toStringAsFixed(1)} MT)'),
          _infoRow('Contract Duration:', '12 Consecutive Weeks'),
          _infoRow('Delivery Day:', 'Every ${order.dispatchDay} (Farmgate / Factory Dispatch)'),
          _infoRow('Price Offered:', '${_currencyFormat.format(order.agreedPricePerQtl)} / Qtl'),
          _infoRow('Destination Factory:', order.deliveryDestination),
          const Divider(height: 20),

          // Total Payout Highlight
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total 12-Week Contract Payout:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                _currencyFormat.format(order.totalContractValue),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons: Accept or Decline
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmDecline(order),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept 12-Week Contract', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _acceptContract(order),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptContract(RecurringOrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ratify 12-Week Contract'),
        content: Text(
          'Do you confirm to supply ${order.weeklyQuantityQtl.toInt()} Quintals of ${order.commodity} every ${order.dispatchDay} for 12 weeks to ${order.buyerCompany} for a total payout of ${_currencyFormat.format(order.totalContractValue)}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Ratify'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _orderService.fpoAcceptProposal(order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 12-Week Master Contract ${order.recurringOrderNumber} Activated!'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
        _tabController.animateTo(1); // Switch to active contracts
      }
    }
  }

  Future<void> _confirmDecline(RecurringOrderModel order) async {
    final reasonController = TextEditingController(text: 'Capacity constraint in requested period');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Decline Proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for declining to notify the buyer:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline Proposal'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _orderService.fpoRejectProposal(order.id, reasonController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal declined')),
        );
      }
    }
  }

  // TAB 2: Active Contracts
  Widget _buildActiveList(List<RecurringOrderModel> activeList) {
    if (activeList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.assignment_turned_in_outlined, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text('No Active Contracts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Accept incoming proposals to begin weekly fulfillment cycles.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeList.length,
      itemBuilder: (context, index) {
        final order = activeList[index];
        return _buildActiveContractCard(order);
      },
    );
  }

  Widget _buildActiveContractCard(RecurringOrderModel order) {
    final nextTranche = order.nextUpcomingTranche;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handshake_outlined, color: Color(0xFF15803D), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.commodity} • ${order.buyerCompany}',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.weeklyQuantityQtl.toInt()} Qtl / week • Total ${_currencyFormat.format(order.totalContractValue)}',
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
                    '${order.completedTranchesCount} of 12 Weeks Fulfilled',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                  Text(
                    'Every ${order.dispatchDay}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
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
                // Next shipment action box
                if (nextTranche != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upcoming Week ${nextTranche.weekNumber} Dispatch',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF14532D)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('EEEE, dd MMM yyyy').format(nextTranche.scheduledDate)} • ${nextTranche.quantityQtl.toInt()} Quintals',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                        if (nextTranche.status != 'dispatched' && nextTranche.status != 'paid')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.local_shipping, size: 14),
                            label: const Text('Dispatch Truck', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _openDispatchModal(order, nextTranche),
                          )
                        else if (nextTranche.status == 'dispatched')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 14),
                            label: const Text('Mark Delivered', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _markDelivered(order, nextTranche),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 12-Tranche breakdown
                Text('12-Week Shipment Tranches', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...order.tranches.map((t) => _buildFpoTrancheRow(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpoTrancheRow(RecurringTranche t) {
    Color color = const Color(0xFF64748B);
    String text = 'Scheduled';
    if (t.status == 'paid' || t.status == 'delivered') {
      color = const Color(0xFF15803D);
      text = t.status == 'paid' ? 'Paid & Settled' : 'Delivered';
    } else if (t.status == 'dispatched') {
      color = const Color(0xFF2563EB);
      text = 'In-Transit (${t.vehicleNumber ?? 'Truck Assigned'})';
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Week ${t.weekNumber} • ${DateFormat('dd MMM (EEE)').format(t.scheduledDate)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _openDispatchModal(RecurringOrderModel order, RecurringTranche tranche) async {
    final vehicleCtrl = TextEditingController(text: 'HR-05-AB-${4000 + tranche.weekNumber}');
    final driverCtrl = TextEditingController(text: '+91 98765 43210');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Dispatch Week ${tranche.weekNumber} Consignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign vehicle for ${tranche.quantityQtl.toInt()} Quintals of ${order.commodity}:'),
            const SizedBox(height: 12),
            TextField(
              controller: vehicleCtrl,
              decoration: const InputDecoration(labelText: 'Truck / FASTag Vehicle No.', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: driverCtrl,
              decoration: const InputDecoration(labelText: 'Driver Contact Phone', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Dispatch'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _orderService.dispatchTranche(
        orderId: order.id,
        weekNumber: tranche.weekNumber,
        vehicleNumber: vehicleCtrl.text,
        driverPhone: driverCtrl.text,
      );
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚚 Week ${tranche.weekNumber} truck dispatched (${vehicleCtrl.text})! Live GPS tracking shared with buyer.'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    }
  }

  Future<void> _markDelivered(RecurringOrderModel order, RecurringTranche tranche) async {
    await _orderService.deliverTranche(
      orderId: order.id,
      weekNumber: tranche.weekNumber,
      dbtUtr: 'CMS982184918${tranche.weekNumber}',
    );
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Week ${tranche.weekNumber} delivered & pro-rata settlement confirmed!'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
