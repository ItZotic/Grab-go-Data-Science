import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.onOpenStalls, required this.onOpenAccounts, required this.onOpenReports});

  final VoidCallback onOpenStalls;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final campus = state.requiredCampus;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final ordersToday = state.ordersBetween(from: today, to: today);
        final salesToday = state.revenueOf(state.paymentsBetween(from: today, to: today));
        final claimed = ordersToday.where((o) => o.status == OrderStatus.claimed).length;
        final released = ordersToday.where((o) => o.status == OrderStatus.released).length;
        final noShow = ordersToday.isEmpty ? 0.0 : released / ordersToday.length * 100;

        final stalls = Database.stalls(campus.id, status: StallStatus.active);
        final salesByStall = <Stall, double>{};
        for (final s in stalls) {
          salesByStall[s] = state.revenueOf(state.paymentsBetween(stallId: s.id, from: today, to: today));
        }
        final maxSale = salesByStall.values.fold<double>(0, (a, b) => b > a ? b : a);
        final selling = salesByStall.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            actions: [
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => AppState.instance.signOut(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 22),
            children: [
              Text('Today · ${shortDateYear(now)}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // Stat grid
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 88, crossAxisSpacing: 10, mainAxisSpacing: 10),
                children: [
                  _statCard('ORDERS', '${ordersToday.length}', AppColors.ink),
                  _statCard('SALES', peso(salesToday), AppColors.ink),
                  _statCard('CLAIMED', '$claimed', AppColors.greenDark),
                  _statCard('NO-SHOWS', '${noShow.toStringAsFixed(0)}%', noShow > 0 ? AppColors.redDark : AppColors.ink),
                ],
              ),
              const SizedBox(height: 18),

              // Quick actions
              Row(
                children: [
                  _quickAction(Icons.storefront_outlined, 'Manage stalls', onOpenStalls),
                  const SizedBox(width: 8),
                  _quickAction(Icons.group_outlined, 'Accounts', onOpenAccounts),
                  const SizedBox(width: 8),
                  _quickAction(Icons.bar_chart_rounded, 'Reports', onOpenReports),
                ],
              ),
              const SizedBox(height: 18),

              // Sales today by stall
              const Text('Sales today by stall', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
              const SizedBox(height: 10),
              if (selling.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('No sales yet today.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)))
              else
                for (final e in selling) ReportBar(label: e.key.name, valueLabel: peso(e.value), fraction: e.value / (maxSale == 0 ? 1 : maxSale), labelWidth: 120),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.navy900, side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    );
  }

  Widget _statCard(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6, color: valueColor)),
        ],
      ),
    );
  }
}
