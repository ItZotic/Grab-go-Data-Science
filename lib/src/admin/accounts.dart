import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  int _tab = 0; // All, Customers, Stall admins, Main admins
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _roleFilters = [null, AccountRole.customer, AccountRole.stallAdmin, AccountRole.mainAdmin];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final campusId = state.requiredCampus.id;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final all = Database.accounts(campusId);
        final counts = [
          all.length,
          all.where((a) => a.role == AccountRole.customer).length,
          all.where((a) => a.role == AccountRole.stallAdmin).length,
          all.where((a) => a.role == AccountRole.mainAdmin).length,
        ];
        final filtered = all.where((a) {
          final roleFilter = _roleFilters[_tab];
          if (roleFilter != null && a.role != roleFilter) return false;
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return a.name.toLowerCase().contains(q) || a.email.toLowerCase().contains(q) || a.schoolId.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Accounts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showAddAccount(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: AppColors.navy900),
                          SizedBox(width: 2),
                          Text('Add account', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.navy900)),
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
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Search name, email, or school ID', prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Segmented(
                  items: ['All \u00B7 ${counts[0]}', 'Customers', 'Stall admins', 'Main admins'],
                  selected: _tab,
                  trackColor: AppColors.pageSoft,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyBox(icon: Icons.group_outlined, title: 'No accounts match', subtitle: 'Try a different search or filter.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _AccountRow(
                          account: filtered[i],
                          onReset: () => _resetPassword(context, filtered[i]),
                          onToggleActive: () => _toggleActive(context, filtered[i]),
                          onDelete: () => _deleteAccount(context, filtered[i]),
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Text('Tap an account to reset the password or deactivate it.', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetPassword(BuildContext context, Account account) async {
    // Firebase sends a real password-reset email to the user.
    final error = await AppState.instance.resetAccountPassword(account.id, '');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(error == null ? 'Reset email sent' : 'Could not send reset email'),
        content: Text(
          error ?? 'A password-reset link was emailed to ${account.email}. They can set a new password from that link — no temporary password is shared.',
          style: const TextStyle(fontSize: 12.5, height: 1.45),
        ),
        actions: [
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, Account account) async {
    final activate = !account.active;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(activate ? 'Reactivate “${account.name}”?' : 'Deactivate “${account.name}”?'),
        content: Text(activate ? 'They can sign in again immediately.' : 'They will not be able to sign in until reactivated. Historical orders are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: activate ? AppColors.green : AppColors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: Text(activate ? 'Reactivate' : 'Deactivate')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await AppState.instance.setAccountActive(account.id, activate);
      if (context.mounted) showSnack(context, activate ? '${account.name} reactivated.' : '${account.name} deactivated.');
    }
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text('“${account.name}” (${account.email}) will lose access immediately. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      final error = await AppState.instance.deleteAccount(account.id);
      if (context.mounted) showSnack(context, error ?? '“${account.name}” removed.');
    }
  }

  Future<void> _showAddAccount(BuildContext context, AppState state) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    var role = AccountRole.customer;
    String? nameError, emailError;

    final stalls = Database.stalls(state.requiredCampus.id, status: StallStatus.active);
    Stall? assignedStall = stalls.isEmpty ? null : stalls.first;

    final temp = 'Grab&Go#${DateTime.now().millisecondsSinceEpoch % 100000}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 14),
                  const Text('Add account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  const Text('A temporary password is generated and shown once.', style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                  const SizedBox(height: 14),
                  TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Full name', errorText: nameError)),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: InputDecoration(labelText: 'Email', hintText: 'name@batstate-u.edu.ph', errorText: emailError)),
                  const SizedBox(height: 10),
                  TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'School / employee ID', hintText: '23-12345')),
                  const SizedBox(height: 12),
                  Segmented(items: const ['Customer', 'Stall admin', 'Main admin'], selected: const [AccountRole.customer, AccountRole.stallAdmin, AccountRole.mainAdmin].indexOf(role), onChanged: (i) => setSheetState(() => role = const [AccountRole.customer, AccountRole.stallAdmin, AccountRole.mainAdmin][i])),
                  if (role == AccountRole.stallAdmin) ...[
                    const SizedBox(height: 12),
                    if (stalls.isEmpty)
                      const Text('No active stalls yet — create one on the Stalls tab first.', style: TextStyle(fontSize: 11.5, color: AppColors.redDark, fontWeight: FontWeight.w700))
                    else
                      DropdownButtonFormField<Stall>(
                        value: assignedStall,
                        decoration: const InputDecoration(labelText: 'Assign to stall'),
                        items: stalls.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (s) => assignedStall = s,
                      ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Create account',
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim().toLowerCase();
                      final emailRx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
                      setSheetState(() {
                        nameError = name.isEmpty ? 'Name is required.' : null;
                        emailError = emailRx.hasMatch(email) ? null : 'Enter a valid email.';
                      });
                      if (nameError != null || emailError != null) return;
                      if (Database.accountByEmail(email, campusId: state.requiredCampus.id) != null) {
                        setSheetState(() => emailError = 'This email is already registered.');
                        return;
                      }
                      if (role == AccountRole.stallAdmin && stalls.isEmpty) {
                        showSnack(context, 'Create a stall first, then assign a stall admin.');
                        return;
                      }
                      await Database.createAccount(campusId: state.requiredCampus.id, name: name, email: email, password: temp, role: role, type: role == AccountRole.customer ? AccountType.student : AccountType.employee, schoolId: idCtrl.text.trim().isEmpty ? '—' : idCtrl.text.trim(), stallId: role == AccountRole.stallAdmin ? assignedStall?.id : null);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (context.mounted) {
                        showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Account created'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Credentials for $email:', style: const TextStyle(fontSize: 12, height: 1.45)),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(12)),
                                  child: SelectableText('$email\n$temp', style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.6)),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: '$email / $temp')); showSnack(context, 'Credentials copied.'); }, child: const Text('Copy')),
                              FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text('Done')),
                            ],
                          ),
                        );
                      }
                      state.refresh();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.onReset, required this.onToggleActive, required this.onDelete});
  final Account account;
  final VoidCallback onReset;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rolePill = switch (account.role) {
      AccountRole.customer => const Pill(label: 'Customer', color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft),
      AccountRole.stallAdmin => const Pill(label: 'Stall admin', color: AppColors.greenDark, soft: AppColors.greenSoft),
      AccountRole.mainAdmin => const Pill(label: 'Main admin', color: AppColors.redDark, soft: AppColors.redSoft),
    };
    final inactive = !account.active;

    return PopupMenuButton<String>(
      tooltip: 'Manage account',
      onSelected: (v) => v == 'reset' ? onReset() : (v == 'toggle' ? onToggleActive() : onDelete()),
      offset: const Offset(0, 48),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.lock_reset_rounded, size: 18), SizedBox(width: 10), Text('Reset password')])),
        PopupMenuItem(value: 'toggle', child: Row(children: [Icon(account.active ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 18), SizedBox(width: 10), Text(account.active ? 'Deactivate' : 'Reactivate')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red), SizedBox(width: 10), Text('Remove account', style: TextStyle(color: AppColors.red))])),
      ],
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: inactive ? AppColors.pageSoft : AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: inactive ? AppColors.red.withOpacity(0.3) : AppColors.line)),
        child: Row(
          children: [
            AvatarCircle(name: account.name, size: 46, colorIndex: account.colorIndex),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(account.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (inactive) const Pill(label: 'Deactivated', color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(account.email, style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      rolePill,
                      const SizedBox(width: 6),
                      Text(account.schoolId, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
