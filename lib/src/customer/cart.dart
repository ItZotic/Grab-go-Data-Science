import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'meal.dart';
import 'receipt.dart';

// ===========================================================================
// 7 · CART
// ===========================================================================
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final lines = List.of(state.cart);
        return Scaffold(
          appBar: AppBar(title: const Text('Your cart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
          body: lines.isEmpty
              ? EmptyBox(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  subtitle: 'Browse the stalls and pick up lunch in under a minute.',
                  action: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white),
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Browse stalls'),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                        children: [
                          for (final line in lines) _CartRow(line: line),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 10),
                          _billRow('Subtotal', peso(state.cartTotal)),
                          _billRow('Service fee', '₱0'),
                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                              const Spacer(),
                              Text(peso(state.cartTotal), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).padding.bottom + 16),
                      child: NavyButton(
                        label: 'Choose pickup window',
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SlotSelectScreen())),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _billRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final dish = line.dish;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailsScreen(dishId: dish.id))),
            child: DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 62, radius: 16, photo: dish.photo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.1)),
                const SizedBox(height: 2),
                Text('${peso(dish.price)} each', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => state.setLineQty(dish.id, line.qty - 1),
                      child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppColors.pageSoft, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.remove_rounded, size: 16, color: AppColors.navy900)),
                    ),
                    Container(
                      width: 34,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.all(Radius.circular(10))),
                      alignment: Alignment.center,
                      child: Text('${line.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                    GestureDetector(
                      onTap: line.qty < dish.servingsLeft ? () => state.setLineQty(dish.id, line.qty + 1) : null,
                      child: Container(width: 28, height: 28, decoration: BoxDecoration(color: line.qty < dish.servingsLeft ? AppColors.pageSoft : const Color(0xFFF0F0F5), shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.add_rounded, size: 16, color: line.qty < dish.servingsLeft ? AppColors.navy900 : AppColors.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(peso(line.total), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
        ],
      ),
    );
  }
}

// ===========================================================================
// 8 · PICKUP SLOT SELECTION
// ===========================================================================
class SlotSelectScreen extends StatefulWidget {
  const SlotSelectScreen({super.key});

  @override
  State<SlotSelectScreen> createState() => _SlotSelectScreenState();
}

class _SlotSelectScreenState extends State<SlotSelectScreen> {
  String? _selectedSlotId;
  bool _reloading = false;
  String? _slotError;

  Future<void> _reloadWindows(Stall stall) async {
    setState(() {
      _reloading = true;
      _slotError = null;
    });
    final error = await Database.ensureSlotsDetailed(campusId: AppState.instance.requiredCampus.id, stallId: stall.id);
    if (!mounted) return;
    setState(() {
      _reloading = false;
      _slotError = error;
    });
  }

  Widget _emptyState(Stall stall) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded, size: 44, color: AppColors.muted.withValues(alpha: 0.7)),
              const SizedBox(height: 14),
              const Text('No windows yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(stall.name.isEmpty ? 'The stall has no pickup windows for today yet — they are created automatically, or the stall may be closed for today.' : '${stall.name} has no pickup windows for today yet — they are created automatically, or the stall may be closed for today.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
              if (_slotError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
                  child: Text(_slotError!, style: const TextStyle(fontSize: 10.5, color: AppColors.redDark, height: 1.4)),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _reloading ? null : () => _reloadWindows(stall),
                icon: _reloading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy900)) : const Icon(Icons.refresh_rounded),
                label: Text(_reloading ? 'Reloading…' : 'Reload windows'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.navy900, side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.cart.isEmpty ? null : Database.stallById(state.cart.first.dish.stallId);
    if (stall == null) {
      return const Scaffold(body: Center(child: Text('Your cart is empty.')));
    }

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
        // Only windows that haven't started yet can be booked.
        final slots = Database.slots(campusId: state.requiredCampus.id, stallId: stall.id)
            .where((s) => s.startMin > nowMin)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pick your pickup window', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            actions: const [Padding(padding: EdgeInsets.only(right: 18), child: Center(child: Text('Step 2 of 3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted))))],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Text('Pick a 10-minute window. Unclaimed orders release after the grace period.', style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.yellowSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.yellowDeep.withValues(alpha: 0.35))),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: AppColors.yellowOnSoft),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: a window closes as soon as it begins. If you see "Closed", that window has already started — just pick the next open window instead.',
                          style: TextStyle(fontSize: 11, color: AppColors.yellowOnSoft, height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: slots.isEmpty
                    ? _emptyState(stall)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        children: [
                          for (final slot in slots) _SlotTile(slot: slot, selected: slot.id == _selectedSlotId, onTap: (slot.full || !slot.open || slot.startMin <= DateTime.now().hour * 60 + DateTime.now().minute) ? null : () => setState(() => _selectedSlotId = slot.id)),
                        ],
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).padding.bottom + 16),
                child: PrimaryButton(
                  label: 'Review order',
                  disabled: _selectedSlotId == null,
                  onPressed: _selectedSlotId == null
                      ? null
                      : () {
                          final slot = slots.firstWhere((s) => s.id == _selectedSlotId);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckoutScreen(slotId: slot.id)));
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.selected, required this.onTap});
  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
    final ended = slot.startMin <= nowMin;
    final closed = ended || !slot.open;
    final full = slot.full && !closed;
    final disabled = full || closed;
    final label = closed ? 'Closed' : (full ? 'Full' : null);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellowSoft : (disabled ? AppColors.pageSoft : AppColors.background),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.yellowDeep : AppColors.line, width: selected ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                slot.label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: disabled ? AppColors.muted : AppColors.ink),
              ),
            ),
            if (disabled)
              Text(label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted))
            else
              Text(
                '${slot.remaining} spots',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? AppColors.yellowOnSoft : (slot.remaining <= 3 ? AppColors.orange : AppColors.greenDark)),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 9 · CHECKOUT
// ===========================================================================
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.slotId});
  final String slotId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PayMethod _method = PayMethod.counter;
  bool _placing = false;
  final _mobileCtrl = TextEditingController();
  String? _mobileError;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  bool get _needsMobile => _method != PayMethod.counter;

  bool get _mobileValid {
    final digits = _mobileCtrl.text.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^09\d{9}$').hasMatch(digits);
  }

  Future<void> _place() async {
    setState(() {
      _mobileError = null;
      _placing = true;
    });

    if (_needsMobile && !_mobileValid) {
      setState(() {
        _mobileError = 'Enter an 11-digit number starting with 09.';
        _placing = false;
      });
      return;
    }

    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;

    final state = AppState.instance;
    try {
      final stall = Database.stallById(state.cart.first.dish.stallId)!;
      final slot = Database.slots(campusId: state.requiredCampus.id, stallId: stall.id).firstWhere((s) => s.id == widget.slotId);
      final digits = _mobileCtrl.text.replaceAll(RegExp(r'\s'), '');
      final payRef = _method == PayMethod.counter ? '' : '…${digits.substring(digits.length - 4)}';

      final order = await state.placeOrder(stall: stall, slot: slot, method: _method, payRef: payRef);
      if (!mounted) return;
      setState(() => _placing = false);
      if (order == null) {
        showSnack(context, 'Window just filled up — please pick another.');
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(orderId: order.id, celebrate: true)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      final msg = e.toString().replaceAll('cloud_firestore/', '').replaceAll('firebase_', '');
      showSnack(context, 'Could not place order: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.cart.isEmpty ? null : Database.stallById(state.cart.first.dish.stallId);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (stall == null) {
          return const Scaffold(body: Center(child: Text('Your cart is empty.')));
        }
        final slot = Database.slots(campusId: state.requiredCampus.id, stallId: stall.id).firstWhere((s) => s.id == widget.slotId, orElse: () => Slot(id: widget.slotId, campusId: state.requiredCampus.id, stallId: stall.id, startMin: 12 * 60 + 20, capacity: 20, booked: 0));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Checkout', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: const [Padding(padding: EdgeInsets.only(right: 18), child: Center(child: Text('Step 3 of 3', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted))))],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            children: [
              // Pickup window card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pickup · ${stall.name} express lane', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                          const SizedBox(height: 3),
                          Text(slot.label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.navy900, side: const BorderSide(color: AppColors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text('Mode of payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted)),
              const SizedBox(height: 8),
              _paymentOption(PayMethod.counter, Icons.point_of_sale_rounded, 'Pay at the counter', 'Cash at the express lane when you pick up'),
              if (kOnlinePaymentsEnabled) ...[
                const SizedBox(height: 8),
                _paymentOption(PayMethod.gcash, Icons.phone_android_rounded, 'GCash (simulated)', 'Enter your GCash number to scan-to-pay'),
                const SizedBox(height: 8),
                _paymentOption(PayMethod.qrph, Icons.qr_code_rounded, 'QRPh (simulated)', 'Pay with the PH QR standard'),
              ],
              if (!kOnlinePaymentsEnabled) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: AppColors.muted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GCash & QRPh are coming soon — for now, please settle your order in cash at the counter when you pick it up.',
                          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_needsMobile) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 13,
                  onChanged: (_) => setState(() => _mobileError = null),
                  decoration: InputDecoration(
                    labelText: _method == PayMethod.gcash ? 'GCash mobile number' : 'QRPh mobile number',
                    hintText: '0917 123 4567',
                    counterText: '',
                    errorText: _mobileError,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              Row(
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(peso(state.cartTotal), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
                ],
              ),
              const SizedBox(height: 4),
              Text(kOnlinePaymentsEnabled ? 'Pay in cash at the express lane when you pick up, or pay now with GCash/QRPh.' : 'Bring exact change if you can — payment happens at the express lane when you pick up.', style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Place order · ${peso(state.cartTotal)}',
                loading: _placing,
                onPressed: _placing ? null : _place,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentOption(PayMethod method, IconData icon, String title, String subtitle) {
    final selected = _method == method;
    return GestureDetector(
      onTap: () => setState(() {
        _method = method;
        _mobileError = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellowSoft : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.yellowDeep : AppColors.line, width: selected ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: selected ? AppColors.yellow : AppColors.pageSoft, borderRadius: const BorderRadius.all(Radius.circular(12))),
              alignment: Alignment.center,
              child: Icon(icon, size: 21, color: AppColors.navy900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.1)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.navy900 : Colors.transparent, border: Border.all(color: selected ? AppColors.navy900 : const Color(0xFFD4D4DE), width: 1.8)),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
