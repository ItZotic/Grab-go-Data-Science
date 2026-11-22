import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../export.dart';
import '../theme.dart';
import '../widgets.dart';
import 'earnings.dart';

DateTime _startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _periodLabel(String range) {
  final now = DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (range == 'Day') return 'Today · ${months[now.month - 1]} ${now.day}';
  if (range == 'Week') {
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}';
  }
  return '${months[now.month - 1]} ${now.year}';
}

(DateTime, DateTime) periodRange(String range) {
  final now = DateTime.now();
  if (range == 'Day') {
    final d = DateTime(now.year, now.month, now.day);
    return (d, d);
  }
  if (range == 'Week') {
    final start = _startOfWeek(now);
    return (start, start.add(const Duration(days: 6)));
  }
  return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
}

(DateTime, DateTime) _prevRange(String range) {
  final now = DateTime.now();
  if (range == 'Day') {
    final d = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    return (d, d);
  }
  if (range == 'Week') {
    final start = _startOfWeek(now).subtract(const Duration(days: 7));
    return (start, start.add(const Duration(days: 6)));
  }
  return (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = 'Week';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final (from, to) = periodRange(_range);
    final (prevFrom, prevTo) = _prevRange(_range);
    const ranges = ['Day', 'Week', 'Month'];

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final orders = state.ordersBetween(from: from, to: to);
        final prevOrders = state.ordersBetween(from: prevFrom, to: prevTo);
        final dishes = state.topDishesOf(orders, limit: 5);
        final dishesMax = dishes.isEmpty ? 1 : dishes.first.value;

        final noShows = orders.where((o) => o.status == OrderStatus.released).length;
        final noShowRate = orders.isEmpty ? 0.0 : noShows / orders.length * 100;
        final prevNoShows = prevOrders.where((o) => o.status == OrderStatus.released).length;
        final prevRate = prevOrders.isEmpty ? 0.0 : prevNoShows / prevOrders.length * 100;
        final rateDelta = prevOrders.isEmpty ? null : noShowRate - prevRate;

        return Scaffold(
          appBar: AppBar(title: const Text('Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 22),
            children: [
              Segmented(items: ranges, selected: ranges.indexOf(_range), darkSelected: true, onChanged: (i) => setState(() => _range = ranges[i])),
              const SizedBox(height: 18),

              Text('Popular dishes · ${_periodLabel(_range)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (dishes.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No orders yet in this period.', style: TextStyle(fontSize: 12, color: AppColors.muted)))
              else
                for (var i = 0; i < dishes.length; i++)
                  ReportBar(label: '${i + 1} · ${dishes[i].key}', valueLabel: '${dishes[i].value}', fraction: dishes[i].value / dishesMax, labelWidth: 150),
              const SizedBox(height: 20),

              // No-show rate
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NO-SHOW RATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Text('${noShowRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1, color: noShowRate > 0 ? AppColors.redDark : AppColors.greenDark)),
                          const SizedBox(height: 2),
                          Text('$noShows of ${orders.length} released', style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (rateDelta != null)
                      Pill(
                        label: rateDelta <= 0 ? 'Down ${rateDelta.abs().toStringAsFixed(0)}%' : 'Up ${rateDelta.toStringAsFixed(0)}%',
                        color: rateDelta <= 0 ? AppColors.greenDark : AppColors.redDark,
                        soft: rateDelta <= 0 ? AppColors.greenSoft : AppColors.redSoft,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Link to the earnings share report (mockup #31)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarningsShareScreen())),
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
                            Text('What each stall receives after the 18% cut', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'Export summary',
                icon: Icons.ios_share_rounded,
                onPressed: () => exportCsv(
                  context: context,
                  fileName: 'grabgo_reports_${ymd(DateTime.now())}.csv',
                  title: 'Campus reports · ${_periodLabel(_range)}',
                  rows: [
                    ['Campus reports · ${_periodLabel(_range)}'],
                    const [],
                    ['Metric', 'Value'],
                    ['Orders placed', orders.length],
                    ['Orders last period', prevOrders.length],
                    ['No-shows', noShows],
                    ['No-show rate (%)', noShowRate.toStringAsFixed(1)],
                    ['Previous no-show rate (%)', prevRate.toStringAsFixed(1)],
                    ['No-show rate change (pp)', rateDelta?.toStringAsFixed(1) ?? 'n/a'],
                    const [],
                    ['Popular dishes', 'Units sold'],
                    for (final d in dishes) [d.key, d.value],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
