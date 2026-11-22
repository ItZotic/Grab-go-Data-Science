import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

class StallsScreen extends StatefulWidget {
  const StallsScreen({super.key});

  @override
  State<StallsScreen> createState() => _StallsScreenState();
}

class _StallsScreenState extends State<StallsScreen> {
  int _tab = 0; // 0 = Active, 1 = Requests

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final campusId = state.requiredCampus.id;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final active = Database.stalls(campusId, status: StallStatus.active);
        final suspended = Database.stalls(campusId, status: StallStatus.suspended);
        final requests = Database.stalls(campusId, status: StallStatus.pending);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stalls', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddStallScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: AppColors.navy900),
                          SizedBox(width: 2),
                          Text('Add stall', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.navy900)),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                child: Segmented(
                  items: ['Active · ${active.length + suspended.length}', 'Requests · ${requests.length}'],
                  selected: _tab,
                  darkSelected: true,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: _tab == 0 ? _activeList(active, suspended) : _requestList(requests),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _activeList(List<Stall> active, List<Stall> suspended) {
    if (active.isEmpty && suspended.isEmpty) {
      return const EmptyBox(icon: Icons.storefront_outlined, title: 'No stalls yet', subtitle: 'Create the first stall — customers will see it on their home screen right away.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      children: [
        for (final s in active) _stallCard(s, suspended: false),
        for (final s in suspended) _stallCard(s, suspended: true),
      ],
    );
  }

  Widget _stallCard(Stall stall, {required bool suspended}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: suspended ? AppColors.red.withOpacity(0.35) : AppColors.line)),
        child: Row(
          children: [
            StallArtCircle(stall: stall, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(stall.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (suspended) const Pill(label: 'Suspended', color: AppColors.redDark, soft: AppColors.redSoft),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${stall.personName} · ${stall.categories.join(', ')}', style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallDetailsScreen(stallId: stall.id))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
                child: const Text('Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.navy900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestList(List<Stall> requests) {
    if (requests.isEmpty) {
      return const EmptyBox(icon: Icons.inbox_outlined, title: 'No pending requests', subtitle: 'When someone applies to open a stall, it lands here for your approval.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('People want to open a stall on campus. Approve to create their stall and login.', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45))),
        for (final s in requests) _requestCard(s),
      ],
    );
  }

  Widget _requestCard(Stall stall) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.yellowDeep, width: 1.4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.navy900, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(stall.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: -0.2))),
                Text(shortDate(stall.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${stall.personName} · ${stall.blurb}', style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Decline',
                    color: AppColors.navy900,
                    onPressed: () => _decline(stall),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GreenButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    onPressed: () => _approve(stall),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decline(Stall stall) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Decline “${stall.name}”?'),
        content: const Text('The request will be removed. The applicant can apply again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Decline')),
        ],
      ),
    );
    if (yes == true && mounted) {
      await AppState.instance.declineStallRequest(stall.id);
      if (mounted) showSnack(context, 'Request declined.');
    }
  }

  Future<void> _approve(Stall stall) async {
    final result = await AppState.instance.approveStallRequest(stall.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) {
        final credentials = result ?? '';
        final emailLine = credentials.contains('credentials: ') ? credentials.split('credentials: ')[1] : null;
        final alreadyExisted = emailLine == null;
        return AlertDialog(
          title: Row(children: const [Icon(Icons.verified_rounded, color: AppColors.green), SizedBox(width: 8), Text('Stall approved')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“${stall.name}” is now live. The stall admin can log in and start adding dishes.', style: const TextStyle(fontSize: 12.5, height: 1.45)),
              if (emailLine != null) ...[
                const SizedBox(height: 12),
                const Text('STALL ADMIN CREDENTIALS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.muted)),
                const SizedBox(height: 4),
                SelectableText(emailLine, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Share this once. The stall admin can change the password after logging in.', style: TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.4)),
              ] else if (alreadyExisted) ...[
                const SizedBox(height: 12),
                const Text('An account with that email already existed — its password was left unchanged.', style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4)),
              ],
            ],
          ),
          actions: [
            if (emailLine != null) TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: emailLine)); showSnack(context, 'Credentials copied.'); }, child: const Text('Copy')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        );
      },
    );
    if (mounted) setState(() {});
  }
}

// ===========================================================================
// 26 · ADD A STALL
// ===========================================================================
class AddStallScreen extends StatefulWidget {
  const AddStallScreen({super.key});

  @override
  State<AddStallScreen> createState() => _AddStallScreenState();
}

class _AddStallScreenState extends State<AddStallScreen> {
  final _nameCtrl = TextEditingController();
  final _personCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _blurbCtrl = TextEditingController();
  int _iconIndex = 0;
  int _colorIndex = 0;
  String _category = 'Rice meal';
  String? _nameError;
  String? _emailError;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _personCtrl.dispose();
    _emailCtrl.dispose();
    _blurbCtrl.dispose();
    super.dispose();
  }

  String _tempPassword() {
    final n = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'Stall#${n.toString().padLeft(5, '0')}';
  }

  Future<void> _create() async {
    final state = AppState.instance;
    final name = _nameCtrl.text.trim();
    final person = _personCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

    setState(() {
      _nameError = name.isEmpty ? 'Stall name is required.' : (Database.stallByName(name) != null ? 'A stall with this name already exists.' : null);
      _emailError = email.isEmpty ? 'Login email is required.' : (!emailRx.hasMatch(email) ? 'Enter a valid email.' : null);
    });
    if (_nameError != null || _emailError != null) return;

    setState(() => _saving = true);
    final temp = _tempPassword();
    final error = await state.createStallWithAdmin(name: name, blurb: _blurbCtrl.text.trim().isEmpty ? 'Home-cooked meals' : _blurbCtrl.text.trim(), categories: [_category], personName: person.isEmpty ? 'Stall admin' : person, adminEmail: email, tempPassword: temp);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _emailError = error);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stall created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“$name” is live. Share these credentials with the stall admin (shown once):', style: const TextStyle(fontSize: 12.5, height: 1.45)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(12)),
              child: SelectableText('$email\n$temp', style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w800, height: 1.6)),
            ),
            const SizedBox(height: 6),
            const Text('They can change the password after logging in.', style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: '$email / $temp')); showSnack(context, 'Credentials copied.'); }, child: const Text('Copy')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a stall', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
        children: [
          // Logo preview + pickers (replaces photo upload on this build)
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kStallGradients[_colorIndex], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              alignment: Alignment.center,
              child: Icon(kStallIcons[_iconIndex], size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          const Center(child: Text('Stall logo — shown on the customer home screen', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600))),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < kStallIcons.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _iconIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _iconIndex == i ? AppColors.yellow : AppColors.pageSoft, border: Border.all(color: _iconIndex == i ? AppColors.yellowDeep : Colors.transparent, width: 1.6)),
                      child: Icon(kStallIcons[i], size: 20, color: AppColors.navy900),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < kStallGradients.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kStallGradients[i]), border: Border.all(color: _colorIndex == i ? AppColors.navy900 : Colors.transparent, width: 2.4)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() => _nameError = null), decoration: InputDecoration(hintText: 'Stall name', errorText: _nameError)),
          const SizedBox(height: 10),
          TextField(controller: _personCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Person in charge')),
          const SizedBox(height: 10),
          TextField(controller: _blurbCtrl, decoration: const InputDecoration(hintText: 'What they sell, in one line (optional)')),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, autocorrect: false, onChanged: (_) => setState(() => _emailError = null), decoration: InputDecoration(hintText: 'Login email for the stall admin', errorText: _emailError)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Rice meal', 'Noodle', 'Drink', 'Snack', 'Breakfast'].map((c) => SelectChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c))).toList(),
          ),
          const SizedBox(height: 14),
          const Text('The stall admin can add their own dishes, update stock, and verify receipts.', style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Create stall', loading: _saving, onPressed: _saving ? null : _create),
        ],
      ),
    );
  }
}

// ===========================================================================
// 27 · STALL DETAILS
// ===========================================================================
class StallDetailsScreen extends StatelessWidget {
  const StallDetailsScreen({super.key, required this.stallId});
  final String stallId;

  Future<void> _toggleSuspend(BuildContext context, Stall stall, bool suspend) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(suspend ? 'Suspend “${stall.name}”?' : 'Reactivate “${stall.name}”?'),
        content: Text(suspend ? 'Customers will no longer see this stall or its dishes. The stall admin keeps their account.' : 'Customers will see this stall again immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: suspend ? AppColors.red : AppColors.green, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: Text(suspend ? 'Suspend' : 'Reactivate')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await AppState.instance.setStallSuspended(stall.id, suspend);
      if (context.mounted) showSnack(context, suspend ? '${stall.name} suspended.' : '${stall.name} reactivated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stall = Database.stallById(stallId);
        if (stall == null) {
          return const Scaffold(body: Center(child: Text('Stall not found.')));
        }
        final orders = state.ordersBetween(stallId: stall.id, from: weekStart, to: weekEnd);
        final payments = state.paymentsBetween(stallId: stall.id, from: weekStart, to: weekEnd);
        final gross = state.revenueOf(payments);
        final top = state.topDishesOf(orders, limit: 3);
        final topMax = top.isEmpty ? 1 : top.first.value;
        final bars = List<double>.filled(7, 0);
        for (final o in payments) {
          bars[state.revenueDateOf(o).weekday - 1] += o.total;
        }
        final bestDay = bars.isEmpty ? null : bars.indexOf(bars.reduce((a, b) => a > b ? a : b));

        final suspended = stall.status == StallStatus.suspended;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stall', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: Pill(label: suspended ? 'Suspended' : 'Active', color: suspended ? AppColors.redDark : AppColors.greenDark, soft: suspended ? AppColors.redSoft : AppColors.greenSoft)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Row(
                children: [
                  StallArtCircle(stall: stall, size: 84),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stall.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                        const SizedBox(height: 2),
                        Text('In charge: ${stall.personName}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
                        Text(stall.adminEmail, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: StatTile(label: 'Sales this week', value: peso(gross))),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'Orders', value: '${orders.length}')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Sales per day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('Nov ${weekStart.day} – ${weekEnd.day}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 8),
              DayBars(values: bars, bestDayIndex: bars.reduce((a, b) => a > b ? a : b) == 0 ? null : bestDay),
              const SizedBox(height: 16),
              const Text('Top dishes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (top.isEmpty)
                const Text('No orders yet this week.', style: TextStyle(fontSize: 12, color: AppColors.muted))
              else
                for (final t in top) ReportBar(label: t.key, valueLabel: '${t.value} sold', fraction: t.value / topMax),
              const SizedBox(height: 16),
              const Text('Dishes and stock are managed by this stall’s admin.', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              GhostButton(
                label: suspended ? 'Reactivate stall' : 'Suspend stall',
                color: suspended ? AppColors.greenDark : AppColors.red,
                icon: suspended ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                onPressed: () => _toggleSuspend(context, stall, !suspended),
              ),
            ],
          ),
        );
      },
    );
  }
}
