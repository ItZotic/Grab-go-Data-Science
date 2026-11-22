import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import '../nav_requests.dart';

// ===========================================================================
// NOTIFICATIONS
// ===========================================================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pickupReminders = true;

  @override
  void initState() {
    super.initState();
    // Preferences are stored per-user in Firestore (campus shared doc, user-keyed field).
    final user = AppState.instance.currentUser;
    if (user != null) {
      Database.appFirestore.collection('meta').doc(user.id).get().then((snap) {
        if (mounted) setState(() => _pickupReminders = snap.data()?['pickupReminders'] ?? true);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final user = state.currentUser!;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final notes = state.notesFor(user.id);
        final today = notes.where((n) => _isSameDay(n.at, DateTime.now())).toList();
        final yesterday = notes.where((n) => _isSameDay(n.at, DateTime.now().subtract(const Duration(days: 1)))).toList();
        final earlier = notes.where((n) => !_isSameDay(n.at, DateTime.now()) && !_isSameDay(n.at, DateTime.now().subtract(const Duration(days: 1)))).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            actions: [
              TextButton(onPressed: state.markAllNotesRead, child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          body: notes.isEmpty
              ? const EmptyBox(icon: Icons.notifications_none_rounded, title: 'Nothing yet', subtitle: 'Order updates, slot alerts, and promos will show up here.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  children: [
                    if (today.isNotEmpty) _group('Today', today),
                    if (yesterday.isNotEmpty) _group('Yesterday', yesterday),
                    if (earlier.isNotEmpty) _group('Earlier', earlier),
                  ],
                ),
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.line))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Pickup reminders', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                      Text('Notify me before my window opens', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Switch(
                  value: _pickupReminders,
                  activeTrackColor: AppColors.yellow,
                  activeColor: AppColors.navy900,
                  onChanged: (v) {
                    setState(() => _pickupReminders = v);
                    Database.appFirestore.collection('meta').doc(user.id).set({'pickupReminders': v}, SetOptions(merge: true));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _group(String title, List<Note> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted))),
        for (final n in notes) _noteCard(n),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _noteCard(Note n) {
    final (IconData icon, Color tint) = switch (n.kind) {
      'success' => (Icons.check_circle_rounded, AppColors.green),
      'warning' => (Icons.schedule_rounded, AppColors.orange),
      'danger' => (Icons.local_fire_department_rounded, AppColors.red),
      _ => (Icons.notifications_rounded, AppColors.blue),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: n.read ? AppColors.background : AppColors.yellowSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: tint.withOpacity(0.16), shape: BoxShape.circle), child: Icon(icon, size: 19, color: tint)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(n.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
                    Text(clockTime(n.at), style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(n.body, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

// ===========================================================================
// PROFILE
// ===========================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                const Text('Change password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                const SizedBox(height: 14),
                TextField(controller: currentCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Current password', errorText: error)),
                const SizedBox(height: 10),
                TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password', hintText: 'Minimum 8 characters')),
                const SizedBox(height: 10),
                TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save password',
                  onPressed: () async {
                    final authUser = Database.appAuth.currentUser;
                    if (authUser == null || authUser.email == null) {
                      setSheetState(() => error = 'Session expired. Sign out and sign in again.');
                      return;
                    }
                    try {
                      final cred = EmailAuthProvider.credential(email: authUser.email!, password: currentCtrl.text);
                      await authUser.reauthenticateWithCredential(cred);
                    } on FirebaseAuthException catch (e) {
                      setSheetState(() => error = e.code == 'wrong-password' ? 'Current password is incorrect.' : 'Could not verify current password (${e.code}).');
                      return;
                    }
                    if (newCtrl.text.length < 8) {
                      setSheetState(() => error = 'New password must be at least 8 characters.');
                      return;
                    }
                    if (confirmCtrl.text != newCtrl.text) {
                      setSheetState(() => error = 'Passwords don’t match.');
                      return;
                    }
                    try {
                      await authUser.updatePassword(newCtrl.text);
                    } on FirebaseAuthException catch (e) {
                      setSheetState(() => error = 'Could not change password (${e.code}).');
                      return;
                    }
                    if (context.mounted) {
                      Navigator.of(sheetContext).pop();
                      showSnack(context, 'Password updated.');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in anytime with your school account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (yes == true && mounted) AppState.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final user = state.currentUser!;
    final orders = state.myOrders();
    final claimed = orders.where((o) => o.status == OrderStatus.claimed).length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
              const SizedBox(height: 20),
              Center(child: AvatarCircle(name: user.name, size: 96, colorIndex: user.colorIndex)),
              const SizedBox(height: 14),
              Center(child: Text(user.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
              Center(child: Text('${user.schoolId} · ${typeLabelOf(user.type)}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600))),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(child: StatTile(label: 'Orders', value: '${orders.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'Claimed', value: '$claimed')),
                ],
              ),
              const SizedBox(height: 18),

              _rowTile(Icons.receipt_long_rounded, 'My orders', onTap: () => customerTabRequest.value = 2),
              _rowTile(Icons.notifications_none_rounded, 'Notifications', trailing: Text(state.unreadCount > 0 ? '${state.unreadCount} new' : 'On', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted, fontSize: 12.5)), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              _rowTile(Icons.lock_outline_rounded, 'Change password', onTap: _changePassword),
              _rowTile(Icons.help_outline_rounded, 'Help and feedback', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()))),
              const SizedBox(height: 18),
              GhostButton(label: 'Log out', icon: Icons.logout_rounded, onPressed: _logout),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowTile(IconData icon, String label, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.navy900, size: 23),
        title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }
}

// ===========================================================================
// HELP & FEEDBACK
// ===========================================================================
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    ('How do pickup slots work?', 'Pick a 10-minute window like 12:20 – 12:30 PM when you order. We fire the order so it’s ready the moment you arrive at the express lane.'),
    ('What do I show at the lane?', 'Your digital receipt — the screen with the QR and order number. Staff scan or type the order number, check your name and ID, then hand over the meal.'),
    ('What if I’m late?', 'You get a 10-minute grace period. After that the order is released (marked Expired) and may not be refundable.'),
    ('Can someone else claim my order?', 'No. Staff verify the order number together with the name and school ID on the receipt.'),
    ('Why is my slot full?', 'Each window is capped at 20 orders. If yours shows Full, pick the next one — windows are first come, first served.'),
    ('How do I pay?', 'Pay at the counter (cash) when you pick up your order — your receipt is marked “Pay at counter”. GCash and QRPh are coming soon.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help and feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (final (q, a) in _faqs)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: const Icon(Icons.help_outline_rounded, color: AppColors.navy900),
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
                children: [Text(a, style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.ink))],
              ),
            ),
          const SizedBox(height: 6),
          const Center(child: Text('Questions? Visit the canteen office during lunch hours.', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
