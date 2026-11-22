import 'dart:async';

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shop_profile.dart';

/// Stall admin: per-window prep queue.
class PrepListScreen extends StatefulWidget {
  const PrepListScreen({super.key, required this.onOpenVerify});
  final ValueChanged<String> onOpenVerify;

  @override
  State<PrepListScreen> createState() => _PrepListScreenState();
}

class _PrepListScreenState extends State<PrepListScreen> {
  String? _window; // slotId filter; null = all windows
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keep the list honest: expired orders vanish on their own once the window
    // and grace period lapse — even with no other app activity.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      return Scaffold(appBar: AppBar(title: const Text('Prep list')), body: const Center(child: Text('This account is not assigned to a stall.')));
    }
    final campusId = state.requiredCampus.id;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final orders = Database.orders(campusId, stallId: stall.id).where((o) => (o.status == OrderStatus.preparing || o.status == OrderStatus.ready) && !Database.isLapsed(o)).toList();
        final slots = Database.slots(campusId: campusId, stallId: stall.id);

        // Aggregate quantities per item for the selected window.
        final windowOrders = _window == null ? orders : orders.where((o) => o.slotId == _window).toList();
        final counts = <String, int>{};
        for (final o in windowOrders) {
          for (final i in o.items) {
            counts[i.name] = (counts[i.name] ?? 0) + i.qty;
          }
        }
        final topCounts = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        String windowLabel = 'All windows';
        if (_window != null) {
          final slot = slots.where((s) => s.id == _window).firstOrNull;
          if (slot != null) windowLabel = slot.label;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Prep list', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StallShopProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.yellowSoft, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          StallAvatar(photo: stall.photo, label: stall.name, size: 26),
                          const SizedBox(width: 8),
                          Text(stall.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.yellowOnSoft)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.yellowOnSoft),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  children: [
                    SelectChip(label: 'All', selected: _window == null, onTap: () => setState(() => _window = null)),
                    for (final s in slots.where((s) => s.startMin > DateTime.now().hour * 60 + DateTime.now().minute)) ...[
                      const SizedBox(width: 8),
                      SelectChip(label: s.startLabel, selected: _window == s.id, onTap: () => setState(() => _window = s.id)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('To prepare for $windowLabel', style: const TextStyle(color: Color(0xFFB9B7D6), fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            topCounts.isEmpty ? 'Nothing queued' : topCounts.take(3).map((e) => '${e.value} ${e.key}').join(' · '),
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: windowOrders.isEmpty
                    ? const EmptyBox(icon: Icons.soup_kitchen_outlined, title: 'Nothing to prepare', subtitle: 'Orders for this window will appear here the moment customers reserve.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: windowOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _PrepCard(order: windowOrders[i], onClaimTap: (orderNo) => widget.onOpenVerify(orderNo)),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.order, required this.onClaimTap});
  final OrderRec order;
  final ValueChanged<String> onClaimTap;

  Future<void> _markReady(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mark ${orderNoDisplay(order.orderNo)} ready?'),
        content: const Text('This pings the customer that their order is waiting at the express lane.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Mark ready')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      final error = await AppState.instance.markReady(order.id);
      if (context.mounted) showSnack(context, error ?? '${orderNoDisplay(order.orderNo)} marked ready. Customer notified.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = order.status == OrderStatus.ready;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ready ? AppColors.green.withOpacity(0.5) : AppColors.line, width: ready ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${orderNoDisplay(order.orderNo)} · ${order.customerName}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Pill(
                label: ready ? 'Ready' : 'Preparing',
                color: ready ? AppColors.greenDark : const Color(0xFFB45309),
                soft: ready ? AppColors.greenSoft : const Color(0xFFFEF3C7),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.itemsSummary, style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Pickup ${order.slotLabel}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.navy900)),
              const Spacer(),
              if (!ready)
                GestureDetector(
                  onTap: () => _markReady(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(14)),
                    child: const Text('Mark ready', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.navy900)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => onClaimTap(order.orderNo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(14)),
                    child: const Text('Verify & claim', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
