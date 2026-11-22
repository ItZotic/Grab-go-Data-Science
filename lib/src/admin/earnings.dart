import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../export.dart';
import '../theme.dart';
import '../widgets.dart';
// StallArtCircle now lives in widgets.dart
import 'stalls.dart';

DateTime _startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _periodLabel(String range) {
  final now = DateTime.now();
  if (range == 'Week') {
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    return '${_months[start.month - 1]} ${start.day} – ${_months[end.month - 1]} ${end.day}';
  }
  return '${_months[now.month - 1]} ${now.year}';
}

(DateTime, DateTime) periodRange(String range) {
  final now = DateTime.now();
  if (range == 'Week') {
    final start = _startOfWeek(now);
    return (start, start.add(const Duration(days: 6)));
  }
  return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
}

/// 31 · Earnings share — the canteen's 5% cut and what each stall receives.
class EarningsShareScreen extends StatefulWidget {
  const EarningsShareScreen({super.key});

  @override
  State<EarningsShareScreen> createState() => _EarningsShareScreenState();
}

class _EarningsShareScreenState extends State<EarningsShareScreen> {
  String _range = 'Week';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final campusId = state.requiredCampus.id;
    final (from, to) = periodRange(_range);
    final label = _periodLabel(_range);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stalls = Database.stalls(campusId, status: StallStatus.active);
        var gross = 0.0;
        final perStall = <Stall, double>{};
        for (final s in stalls) {
          final sum = state.revenueOf(state.paymentsBetween(stallId: s.id, from: from, to: to));
          perStall[s] = sum;
          gross += sum;
        }
        const rate = 0.05;
        final share = gross * rate;
        final net = gross - share;

        // Pending/paid state per stall for this exact period label.
        final payouts = Database.payouts(campusId);
        Payout? payoutFor(String stallId) {
          for (final p in payouts) {
            if (p.stallId == stallId && p.periodLabel == label) return p;
          }
          return null;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Earnings share', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Period',
                onSelected: (v) => setState(() => _range = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Week', child: Text('This week')),
                  PopupMenuItem(value: 'Month', child: Text('This month')),
                ],
                child: Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_range, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted)),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            children: [
              // Navy summary hero
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$label · Gross sales ${peso(gross)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFB9B7D6))),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('STALLS RECEIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: Color(0xFF8B89B3))),
                              const SizedBox(height: 3),
                              Text(peso(net), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.yellow, letterSpacing: -0.7)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 46, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CANTEEN SHARE · 5%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: Color(0xFF8B89B3))),
                              const SizedBox(height: 3),
                              Text(peso(share), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.7)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Per-stall breakdown
              for (final s in stalls)
                _EarningRow(
                  stall: s,
                  gross: perStall[s] ?? 0,
                  rate: rate,
                  payout: payoutFor(s.id),
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallDetailsScreen(stallId: s.id))),
                ),
              if (stalls.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Text('No active stalls yet.', style: TextStyle(fontSize: 12.5, color: AppColors.muted))),
              const SizedBox(height: 8),
              const Text('Each stall sees only its own earnings. Rate: 5% per order.', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Mark pending as paid out',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () => _markAllPaid(context, stalls, perStall, rate, label),
              ),
              const SizedBox(height: 8),
              GhostButton(
                label: 'Export payout report',
                icon: Icons.ios_share_rounded,
                onPressed: () => exportCsv(
                  context: context,
                  fileName: 'grabgo_payouts_${ymd(DateTime.now())}.csv',
                  title: 'Canteen payout report · $label',
                  rows: csvReport('Canteen payout report · $label', ['Stall', 'Gross (PHP)', 'Share 5% (PHP)', 'Net (PHP)', 'Status'], [
                    for (final s in stalls)
                      [s.name, perStall[s]!.toStringAsFixed(2), (perStall[s]! * rate).toStringAsFixed(2), (perStall[s]! * (1 - rate)).toStringAsFixed(2), payoutFor(s.id)?.status.name ?? 'not created'],
                  ])
                    ..addAll([
                      const [],
                      ['Campus total gross (PHP)', gross.toStringAsFixed(2)],
                      ['Canteen share 5% (PHP)', share.toStringAsFixed(2)],
                      ['Total net to stalls (PHP)', net.toStringAsFixed(2)],
                    ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markAllPaid(BuildContext context, List<Stall> stalls, Map<Stall, double> perStall, double rate, String label) async {
    final state = AppState.instance;
    final campusId = state.requiredCampus.id;
    final existing = Database.payouts(campusId);
    var updated = 0;

    for (final s in stalls) {
      final gross = perStall[s] ?? 0;

      Payout? found;
      for (final p in existing) {
        if (p.stallId == s.id && p.periodLabel == label) {
          found = p;
          break;
        }
      }
      if (found != null) {
        if (found.status != PayoutStatus.paid) {
          found.status = PayoutStatus.paid;
          found.paidAt = DateTime.now();
          await Database.updatePayout(found);
          updated++;
        }
      } else {
        final payout = await Database.createPayout(campusId: campusId, stall: s, periodLabel: label, gross: gross);
        payout.status = PayoutStatus.paid;
        payout.paidAt = DateTime.now();
        await Database.updatePayout(payout);
        updated++;
      }
    }

    if (context.mounted) {
      showSnack(context, updated == 0 ? 'All payouts for $label are already marked paid.' : 'Marked $updated payout${updated == 1 ? '' : 's'} as paid out.');
    }
    state.refresh();
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.stall, required this.gross, required this.rate, required this.payout, required this.onOpen});
  final Stall stall;
  final double gross;
  final double rate;
  final Payout? payout;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final share = gross * rate;
    final net = gross - share;
    final paid = payout?.status == PayoutStatus.paid;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            StallArtCircle(stall: stall, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stall.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text('Gross ${peso(gross)} · share −${peso(share)}', style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(peso(net), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Pill(label: paid ? 'Paid out' : 'Pending', color: paid ? AppColors.greenDark : AppColors.yellowOnSoft, soft: paid ? AppColors.greenSoft : AppColors.yellowSoft),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
