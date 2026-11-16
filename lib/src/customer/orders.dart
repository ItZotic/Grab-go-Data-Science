import 'dart:async';

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'receipt.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  int _tab = 0; // 0 = Active, 1 = History
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Minute-by-minute refresh so pickup countdowns and expiry flips happen while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final orders = state.myOrders();
        // Show the UI correctly even before the background sweep writes 'released' to Firestore.
        bool isLive(OrderRec o) => o.status == OrderStatus.preparing || o.status == OrderStatus.ready;
        final active = orders.where((o) => isLive(o) && !Database.isLapsed(o)).toList();
        final history = orders.where((o) => o.status == OrderStatus.claimed || o.status == OrderStatus.released || (isLive(o) && Database.isLapsed(o))).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('My orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Segmented(items: const ['Active', 'History'], selected: _tab, onChanged: (i) => setState(() => _tab = i)),
              ),
              Expanded(
                child: _tab == 0 ? _activeList(active) : _historyList(history),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _activeList(List<OrderRec> active) {
    if (active.isEmpty) {
      return const EmptyBox(icon: Icons.receipt_long_outlined, title: 'No active orders', subtitle: 'Your pre-ordered meals will show up here.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        for (final o in active) _activeCard(o),
      ],
    );
  }

  Widget _activeCard(OrderRec o) {
    final ready = o.status == OrderStatus.ready;
    final now = DateTime.now();
    final startsAt = Database.slotStartFor(o);
    String badge;
    if (ready) {
      badge = 'Ready for pickup';
    } else if (startsAt != null && now.isBefore(startsAt)) {
      final mins = startsAt.difference(now).inMinutes + 1;
      badge = mins <= 1 ? 'Pickup soon' : 'Pickup in $mins min';
    } else {
      badge = startsAt != null ? 'Window open · pick up now' : 'Preparing';
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(orderId: o.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.yellowDeep, width: 1.8),
          boxShadow: const [BoxShadow(color: Color(0x1AF5B301), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(orderNoDisplay(o.orderNo), style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8))),
                Pill(label: badge, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pickup ${o.slotLabel}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy900)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${o.items.length} item${o.items.length == 1 ? '' : 's'} · ${peso(o.total)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const Spacer(),
                const Text('View receipt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.navy900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyList(List<OrderRec> history) {
    if (history.isEmpty) {
      return const EmptyBox(icon: Icons.history_rounded, title: 'Nothing here yet', subtitle: 'Claimed and expired orders land in History.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Earlier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
        for (final o in history) _historyRow(o),
      ],
    );
  }

  Widget _historyRow(OrderRec o) {
    final claimed = o.status == OrderStatus.claimed;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(orderId: o.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orderNoDisplay(o.orderNo), style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('${shortDate(o.placedAt)} · ${clockTime(o.placedAt)} · ${peso(o.total)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
                ],
              ),
            ),
            Pill(label: claimed ? 'Claimed' : 'Expired', color: claimed ? AppColors.greenDark : AppColors.redDark, soft: claimed ? AppColors.greenSoft : AppColors.redSoft),
          ],
        ),
      ),
    );
  }
}
