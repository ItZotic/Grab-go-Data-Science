import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

DateTime _startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String _periodLabel(String range) {
  final now = DateTime.now();
  if (range == 'Day') return 'Today · ${shortDateYear(now)}';
  if (range == 'Week') {
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    return '${_m(start.month)} ${start.day} – ${_m(end.month)} ${end.day}';
  }
  return '${_m(now.month)} ${now.year}';
}

String _m(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

(DateTime from, DateTime to) _periodRange(String range) {
  final now = DateTime.now();
  if (range == 'Day') {
    final d = _dayOf(now);
    return (d, d);
  }
  if (range == 'Week') {
    final start = _startOfWeek(now);
    return (start, start.add(const Duration(days: 6)));
  }
  return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
}

(DateTime from, DateTime to) _previousPeriodRange(String range) {
  final now = DateTime.now();
  if (range == 'Day') {
    final d = _dayOf(now).subtract(const Duration(days: 1));
    return (d, d);
  }
  if (range == 'Week') {
    final start = _startOfWeek(now).subtract(const Duration(days: 7));
    return (start, start.add(const Duration(days: 6)));
  }
  return (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
}

List<double> _weekBars(List<OrderRec> payments) {
  final bars = List<double>.filled(7, 0);
  for (final o in payments) {
    final idx = AppState.instance.revenueDateOf(o).weekday - 1; // 0 = Mon
    if (idx >= 0 && idx < 7) bars[idx] += o.total;
  }
  return bars;
}

List<double> _monthBars(List<OrderRec> payments, DateTime month) {
  final bars = List<double>.filled(4, 0);
  for (final o in payments) {
    final d = AppState.instance.revenueDateOf(o);
    final week = ((d.day - 1) ~/ 7).clamp(0, 3);
    bars[week] += o.total;
  }
  return bars;
}

// ===========================================================================
// 22 · SALES REPORT (stall POV)
// ===========================================================================
class StallSalesReportScreen extends StatefulWidget {
  const StallSalesReportScreen({super.key});

  @override
  State<StallSalesReportScreen> createState() => _StallSalesReportScreenState();
}

class _StallSalesReportScreenState extends State<StallSalesReportScreen> {
  String _range = 'Week';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      return Scaffold(appBar: AppBar(title: const Text('Sales report')), body: const Center(child: Text('This account is not assigned to a stall.')));
    }
    final (from, to) = _periodRange(_range);
    final (prevFrom, prevTo) = _previousPeriodRange(_range);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final orders = state.ordersBetween(stallId: stall.id, from: from, to: to);
        final payments = state.paymentsBetween(stallId: stall.id, from: from, to: to);
        final prevPayments = state.paymentsBetween(stallId: stall.id, from: prevFrom, to: prevTo);
        final gross = state.revenueOf(payments);
        final prevGross = state.revenueOf(prevPayments);
        final avg = payments.isEmpty ? 0.0 : gross / payments.length;
        final top = state.topDishesOf(orders, limit: 3);
        final topMax = top.isEmpty ? 1 : top.first.value;
        final delta = prevGross <= 0 ? null : ((gross - prevGross) / prevGross) * 100;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sales report', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Pill(label: stall.name, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            children: [
              Segmented(items: const ['Day', 'Week', 'Month'], selected: const ['Day', 'Week', 'Month'].indexOf(_range), darkSelected: true, onChanged: (i) => setState(() => _range = const ['Day', 'Week', 'Month'][i])),
              const SizedBox(height: 14),

              // Navy hero card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stall.name} · ${_periodLabel(_range)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB9B7D6))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: Text(peso(gross), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8))),
                        if (delta != null)
                          Pill(label: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs last week', color: const Color(0xFF86EFAC), soft: const Color(0x2234D399)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${payments.length} paid orders · average ${peso(avg)} each', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB9B7D6))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chart
              if (_range == 'Month') ...[
                const Text('Sales per week', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _monthChart(payments, DateTime.now()),
              ] else ...[
                Row(
                  children: [
                    const Text('Sales per day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (_bestDayIndex(payments) != null) Text('Best day: ${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][_bestDayIndex(payments)!]}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                DayBars(values: _weekBars(payments), bestDayIndex: _bestDayIndex(payments)),
              ],
              const SizedBox(height: 18),

              const Text('Top dishes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (top.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 4), child: Text('No orders yet in this period.', style: TextStyle(fontSize: 12, color: AppColors.muted)))
              else
                for (final t in top) ReportBar(label: t.key, valueLabel: '${t.value} sold', fraction: t.value / topMax),
              const SizedBox(height: 16),

              // Link to the earnings share breakdown (mockup #23)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StallEarningsScreen())),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: AppColors.navy900),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Earnings share report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text('How the 5% canteen share is computed', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GhostButton(label: 'Export summary', icon: Icons.ios_share_rounded, onPressed: () => showSnack(context, 'Summary exported (demo).')),
            ],
          ),
        );
      },
    );
  }

  int? _bestDayIndex(List<OrderRec> orders) {
    if (orders.isEmpty) return null;
    final bars = _weekBars(orders);
    var best = 0;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i] > bars[best]) best = i;
    }
    return bars[best] == 0 ? null : best;
  }

  Widget _monthChart(List<OrderRec> orders, DateTime month) {
    final bars = _monthBars(orders, month);
    final maxV = bars.fold<double>(1, (a, b) => b > a ? b : a);
    const labels = ['W1', 'W2', 'W3', 'W4'];
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 88,
                    child: LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 40,
                          height: bars[i] <= 0 ? 4 : (bars[i] / maxV) * c.maxHeight,
                          decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 23 · EARNINGS SHARE (stall POV)
// ===========================================================================
class StallEarningsScreen extends StatelessWidget {
  const StallEarningsScreen({super.key});

  DateTime _nextFriday(DateTime from) {
    var d = from.add(const Duration(days: 1));
    while (d.weekday != DateTime.friday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      return Scaffold(appBar: AppBar(title: const Text('Earnings share')), body: const Center(child: Text('This account is not assigned to a stall.')));
    }
    final campusId = state.requiredCampus.id;
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label = '${_m(weekStart.month)} ${weekStart.day} – ${_m(weekEnd.month)} ${weekEnd.day}';
    final payoutDate = _nextFriday(weekEnd);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final payments = state.paymentsBetween(stallId: stall.id, from: weekStart, to: weekEnd);
        final gross = state.revenueOf(payments);
        final counterCount = payments.where((o) => o.payment == PayMethod.counter).length;
        const rate = 0.05;
        final share = gross * rate;
        final net = gross - share;
        final payouts = Database.payouts(campusId, stallId: stall.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Earnings share', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Pill(label: stall.name, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            children: [
              // Navy hero
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your earnings · $label', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB9B7D6))),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: Text(peso(net), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.yellow, letterSpacing: -0.8))),
                        Pill(label: 'Payout ${_m(payoutDate.month)} ${payoutDate.day}', color: AppColors.navy900, soft: AppColors.yellow),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('After the 5% canteen share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB9B7D6))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // How it's computed
              const Text('How it’s computed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                child: Column(
                  children: [
                    _shareRow('Gross sales (${payments.length} paid orders, $counterCount counter)', peso(gross)),
                    const SizedBox(height: 6),
                    _shareRow('Canteen share · 5%', '−${peso(share)}', valueColor: AppColors.redDark),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Your earnings', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        Text(peso(net), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.greenDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Payout history
              const Text('Payout history', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (payouts.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No payouts yet — your first payout arrives after this week closes.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)))
              else
                for (final p in payouts) _payoutRow(p),
              const SizedBox(height: 10),
              const Text('The share rate is set by the canteen office.', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              GhostButton(label: 'Export earnings report', icon: Icons.ios_share_rounded, onPressed: () => showSnack(context, 'Earnings report exported (demo).')),
            ],
          ),
        );
      },
    );
  }

  Widget _shareRow(String label, String value, {Color? valueColor}) => Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink))),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.ink)),
        ],
      );

  Widget _payoutRow(Payout p) {
    final paid = p.status == PayoutStatus.paid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.periodLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text('Gross ${peso(p.gross)} · share −${peso(p.share)}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(peso(p.net), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Pill(label: paid ? 'Paid' : 'Pending', color: paid ? AppColors.greenDark : AppColors.yellowOnSoft, soft: paid ? AppColors.greenSoft : AppColors.yellowSoft),
        ],
      ),
    );
  }
}
