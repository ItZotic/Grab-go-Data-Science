import 'package:flutter/material.dart';
import '../nav_requests.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scan.dart';

/// 16 · Verify receipt — order number or QR, then claim.
/// Everything on this screen re-resolves from the live Firestore-backed
/// order list, so a claimed receipt is never shown as "not claimed".
class ReceiptVerifyScreen extends StatefulWidget {
  const ReceiptVerifyScreen({super.key, this.onGoToPrep});
  final VoidCallback? onGoToPrep;

  @override
  State<ReceiptVerifyScreen> createState() => _ReceiptVerifyScreenState();
}

class _ReceiptVerifyScreenState extends State<ReceiptVerifyScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  // Lookup state — we keep ONLY the normalized number; the record comes from 
  // the live store on every rebuild.
  bool _searched = false;
  String? _searchedNo;

  @override
  void initState() {
    super.initState();
    receiptLookupRequest.addListener(_onRequestedLookup);
    receiptScanRequest.addListener(_onRequestedScan);
    _onRequestedLookup();
    _onRequestedScan();
  }

  void _onRequestedLookup() {
    final target = receiptLookupRequest.value;
    if (target != null && target.isNotEmpty) {
      _ctrl.text = target;
      _search(target);
      receiptLookupRequest.value = null;
    }
  }

  void _onRequestedScan() {
    final target = receiptScanRequest.value;
    if (target != null && target.isNotEmpty) {
      receiptScanRequest.value = null;
      _ctrl.text = target;
      _scanFor(target);
    }
  }

  static String? _normalize(String raw) {
    final match = RegExp(r'(\d{1,5})').firstMatch(raw.toUpperCase().replaceAll('#', ''));
    if (match == null) return null;
    return 'GG-${match.group(1)!.padLeft(4, '0')}';
  }

  /// Open the camera/scanner immediately for the tapped order. On a successful
  /// scan of the SAME order, jump straight into the claim confirmation.
  Future<void> _scanFor(String expectedNo) async {
    final expected = _normalize(expectedNo);
    if (expected == null) return;
    setState(() {
      _loading = false;
      _searched = false;
      _searchedNo = expected;
    });
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
    if (!mounted) return;
    if (result == null || result.isEmpty) {
      // Scan cancelled — show the tapped order's card so the staff can act manually.
      setState(() {
        _searched = true;
        _searchedNo = expected;
      });
      return;
    }
    final scanned = _normalize(result) ?? result;
    _ctrl.text = scanned;
    setState(() {
      _searched = true;
      _searchedNo = scanned;
    });
    final found = AppState.instance.findOrder(scanned);
    if (scanned == expected) {
      if (found != null && found.status == OrderStatus.ready) {
        await _claim(found); // opens the "Verify & claim?" dialog for the final handout check
      }
      // Otherwise the card already shows the live status (preparing/expired/claimed).
    } else {
      showSnack(context, found == null ? 'No order found for #$scanned.' : 'That QR is #$scanned — you tapped #$expected. Showing the scanned order instead.');
    }
  }

  @override
  void dispose() {
    receiptLookupRequest.removeListener(_onRequestedLookup);
    receiptScanRequest.removeListener(_onRequestedScan);
    _ctrl.dispose();
    super.dispose();
  }

  void _searchButton() {
    final normalized = _normalize(_ctrl.text);
    _search(normalized ?? 'GG-');
  }

  void _search(String normalized) {
    setState(() {
      _loading = true;
      _searched = true;
      _searchedNo = normalized.isEmpty || normalized == 'GG-' ? null : normalized;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  Future<void> _claim(OrderRec order) async {
    final stall = AppState.instance.myStall;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Verify & claim ${orderNoDisplay(order.orderNo)}?'),
        content: Text('Customer: ${order.customerName}\nSchool ID: ${order.customerSchoolId}\nWindow: ${order.slotLabel}\n\nMake sure the receipt matches before handing the order over. This locks the receipt permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Verify & claim')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final claimedBy = stall?.personName ?? AppState.instance.currentUser?.name ?? 'Stall admin';
    final result = await AppState.instance.claimOrder(order.orderNo, claimedBy: claimedBy);
    if (!mounted) return;
    if (result == ClaimResult.ok) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptClaimedScreen(orderId: order.id, claimedBy: claimedBy, onBackToPrep: widget.onGoToPrep)));
    } else {
      showSnack(context, switch (result) {
        ClaimResult.alreadyClaimed => 'That receipt was already claimed.',
        ClaimResult.released => 'Grace period lapsed — this order was released.',
        _ => 'Could not find order.',
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify receipt', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Center(child: Pill(label: 'Stall 2', color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => _ctrl.value = _ctrl.value.copyWith(text: v.toUpperCase(), selection: TextSelection.collapsed(offset: v.length)),
                  onSubmitted: (_) => _searchButton(),
                  decoration: const InputDecoration(
                    hintText: '#GG-0427',
                    prefixIcon: Icon(Icons.tag_rounded, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanReceiptScreen()));
                  if (result != null && result.isNotEmpty && mounted) {
                    _ctrl.text = result;
                    _searchButton();
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.navy900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(26), child: Center(child: CircularProgressIndicator(color: AppColors.navy900)))
          else
            ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                final normalized = _searchedNo;
                if (!_searched) return const SizedBox.shrink();
                if (normalized == null || normalized.isEmpty) {
                  return _errorCard('Enter an order number like GG-0427.');
                }
                final order = AppState.instance.findOrder(normalized);
                if (order == null) {
                  return _errorCard('No order found for #$normalized. Check the number and try again.');
                }
                return _resultCard(order);
              },
            ),
          const SizedBox(height: 18),
          _ClaimedSection(stallId: AppState.instance.currentUser?.stallId ?? ''),
        ],
      ),
    );
  }

  Widget _errorCard(String message) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.redDark),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.redDark, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4))),
          ],
        ),
      );

  Widget _resultCard(OrderRec order) {
    final claimed = order.status == OrderStatus.claimed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: claimed ? AppColors.pageSoft : AppColors.greenSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: claimed ? AppColors.line : AppColors.green.withValues(alpha: 0.4), width: 1.4),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      claimed
                          ? 'Already claimed'
                          : (order.status == OrderStatus.ready
                              ? 'Valid · not claimed'
                              : (order.status == OrderStatus.released ? 'Expired · released' : 'Still preparing')),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: claimed ? AppColors.muted : (order.status == OrderStatus.ready ? AppColors.greenDark : (order.status == OrderStatus.released ? AppColors.redDark : const Color(0xFFB45309)))),
                    ),
                  ),
                  Text(orderNoDisplay(order.orderNo), style: const TextStyle(fontFamily: 'monospace', fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 10),
              _row('Customer', '${order.customerName} · ${order.customerSchoolId}'),
              _row('Pickup', order.slotLabel),
              _row('Items', order.itemsSummary),
              _row('Payment', order.payment == PayMethod.counter ? 'Pay at counter' : 'Paid · ${payMethodLabel(order.payment)}'),
              if (claimed && order.claimedAt != null) ...[
                const SizedBox(height: 8),
                const Divider(color: AppColors.line),
                Text('Claimed at ${clockTime(order.claimedAt!)} — this receipt cannot be reused.', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted, height: 1.4)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!claimed && order.status == OrderStatus.ready) ...[
          const Divider(color: AppColors.line),
          const SizedBox(height: 4),
          const Text('Check the name or school ID against the receipt before handing over the order.', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 10),
        ],
        if (!claimed && order.status == OrderStatus.released)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('This order’s pickup window and 10-minute grace period lapsed, so it was released. It can no longer be claimed — the customer would need to re-order.', style: TextStyle(fontSize: 11, color: AppColors.redDark, fontWeight: FontWeight.w700, height: 1.4)),
          ),
        if (!claimed && order.status != OrderStatus.ready && order.status != OrderStatus.released)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text('This order is still being prepared — mark it ready first on the Prep list before claiming.', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 10),
        if (!claimed && order.status == OrderStatus.ready)
          GreenButton(label: 'Mark as claimed', icon: Icons.verified_rounded, onPressed: () => _claim(order)),
        if (!claimed && order.status != OrderStatus.ready && order.status != OrderStatus.released)
          GhostButton(label: 'Not ready yet — use Prep list', icon: Icons.hourglass_bottom_rounded, onPressed: null),
        if (order.status == OrderStatus.released)
          GhostButton(label: 'Released — cannot be claimed', icon: Icons.block_rounded, onPressed: null),
        const SizedBox(height: 8),
        GhostButton(label: 'Back to prep list', icon: Icons.arrow_back_rounded, onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onGoToPrep?.call();
        }),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 78, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1.1))),
            const SizedBox(width: 8),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35))),
          ],
        ),
      );
}

// ===========================================================================
// CLAIMED TODAY — all of this stall's claimed orders, so the team can see them.
// ===========================================================================
class _ClaimedSection extends StatelessWidget {
  const _ClaimedSection({required this.stallId});
  final String stallId;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final campusId = state.requiredCampus.id;
    final claimed = Database.orders(campusId, stallId: stallId).where((o) => o.status == OrderStatus.claimed).toList()
      ..sort((a, b) => (b.claimedAt ?? b.placedAt).compareTo(a.claimedAt ?? a.placedAt));

    if (claimed.isEmpty) return const SizedBox.shrink();

    final shown = claimed.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Claimed today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted)),
            const Spacer(),
            Text('${claimed.length} total', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.yellowDeep)),
          ],
        ),
        const SizedBox(height: 8),
        for (final order in shown) _claimedTile(context, order, state),
      ],
    );
  }

  Widget _claimedTile(BuildContext context, OrderRec order, AppState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_rounded, color: AppColors.greenDark, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(orderNoDisplay(order.orderNo), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900))),
                      Text(order.claimedAt != null ? clockTime(order.claimedAt!) : '', style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Text('${order.customerName} · ${order.itemsSummary}', style: const TextStyle(fontSize: 11.5, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// ORDER CLAIMED (success screen after claim)
// ===========================================================================
class ReceiptClaimedScreen extends StatelessWidget {
  const ReceiptClaimedScreen({super.key, required this.orderId, required this.claimedBy, this.onBackToPrep});
  final String orderId;
  final String claimedBy;
  final VoidCallback? onBackToPrep;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final order = Database.orderById(orderId, campusId: state.requiredCampus.id);
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found.')));
    }

    return Scaffold(
      backgroundColor: AppColors.greenSoft,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            BackLink(onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              onBackToPrep?.call();
            }),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            const Center(child: Text('Order claimed', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6))),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Hand over the order. This receipt can’t be used again.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted, height: 1.45)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6))]),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(orderNoDisplay(order.orderNo), style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const Spacer(),
                      Pill(label: 'Claimed · ${order.claimedAt != null ? clockTime(order.claimedAt!) : ''}', color: AppColors.greenDark, soft: AppColors.greenSoft),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  _row('Customer', '${order.customerName} · ${order.customerSchoolId}'),
                  _row('Items', order.itemsSummary),
                  _row('Pickup', order.slotLabel),
                  _row('Payment', order.payment == PayMethod.counter ? 'Pay at counter' : 'Paid · ${payMethodLabel(order.payment)}'),
                  _row('Claimed by', '$claimedBy · ${AppState.instance.myStall?.name ?? 'Stall'}'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Scan next receipt',
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                onBackToPrep?.call();
              },
            ),
            const SizedBox(height: 6),
            GhostButton(label: 'Back to prep list', icon: Icons.arrow_back_rounded, onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              onBackToPrep?.call();
            }),
          ],
        ),
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 88, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1.2))),
            const SizedBox(width: 8),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35))),
          ],
        ),
      );
}
