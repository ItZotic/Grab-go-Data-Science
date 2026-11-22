import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart.dart';
import 'meal.dart';

class StallScreen extends StatefulWidget {
  const StallScreen({super.key, required this.stallId});
  final String stallId;

  @override
  State<StallScreen> createState() => _StallScreenState();
}

class _StallScreenState extends State<StallScreen> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = Database.stallById(widget.stallId);
    if (stall == null) {
      return const Scaffold(body: Center(child: Text('This stall is no longer available.')));
    }

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dishes = Database.dishes(state.requiredCampus.id, stallId: stall.id).where((d) => d.available).toList();
        final categories = stall.categories.toSet().toList();
        final filtered = _category == 'All' ? dishes : dishes.where((d) => d.category == _category).toList();

        final openSlots = Database.slots(campusId: state.requiredCampus.id, stallId: stall.id).where((s) => s.open && !s.full).toList();
        final nextSlot = openSlots.isEmpty ? null : openSlots.first;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 18, 0),
                  child: Row(
                    children: [
                      const BackLink(),
                      const Spacer(),
                      const Pill(label: 'Open now', color: AppColors.greenDark, soft: AppColors.greenSoft, icon: Icons.circle),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                    children: [
                      Row(
                        children: [
                          StallArtCircle(stall: stall, size: 76),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stall.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                                const SizedBox(height: 2),
                                Text(stall.categories.join(' · '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(stall.blurb, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45)),
                      const SizedBox(height: 14),

                      // Navy banner: next pickup window + slots left
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Next pickup window', style: TextStyle(color: Color(0xFFB9B7D6), fontSize: 11, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                    nextSlot?.label ?? 'No open windows',
                                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 42, color: Colors.white.withOpacity(0.15)),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Slots left', style: TextStyle(color: Color(0xFFB9B7D6), fontSize: 10, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(
                                  nextSlot == null ? '0' : '${nextSlot.remaining}',
                                  style: const TextStyle(color: AppColors.yellow, fontSize: 28, fontWeight: FontWeight.w900, height: 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category chips
                      Row(
                        children: [
                          SelectChip(label: 'All', selected: _category == 'All', onTap: () => setState(() => _category = 'All')),
                          const SizedBox(width: 8),
                          for (final c in categories) ...[
                            SelectChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (filtered.isEmpty)
                        const EmptyBox(icon: Icons.restaurant_menu_rounded, title: 'No dishes here yet', subtitle: 'The stall is still setting up its kitchen. Come back soon.')
                      else
                        for (final dish in filtered) _StallDishRow(dish: dish),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: CartBottomBar(onViewCart: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()))),
        );
      },
    );
  }
}

class _StallDishRow extends StatelessWidget {
  const _StallDishRow({required this.dish});
  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final soldOut = dish.servingsLeft <= 0;
    final low = dish.servingsLeft <= 5;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final qty = state.qtyInCart(dish.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailsScreen(dishId: dish.id))),
                child: DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 66, radius: 18, photo: dish.photo, soldOut: soldOut),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailsScreen(dishId: dish.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.1)),
                      const SizedBox(height: 1),
                      Text(peso(dish.price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                      const SizedBox(height: 3),
                      if (soldOut)
                        const Text('Sold out', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.redDark))
                      else if (low)
                        Text('Only ${dish.servingsLeft} left', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.redDark))
                      else
                        Text('${dish.servingsLeft} left', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (soldOut)
                const SizedBox(width: 40)
              else if (qty > 0)
                _MiniStepper(dish: dish, qty: qty)
              else
                GestureDetector(
                  onTap: () => addToSingleStallCart(context, dish),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33F5B301), blurRadius: 6, offset: Offset(0, 2))]),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_rounded, size: 22, color: AppColors.navy900),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.dish, required this.qty});
  final Dish dish;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => state.setLineQty(dish.id, qty - 1),
          child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: AppColors.pageSoft, shape: BoxShape.circle), alignment: Alignment.center, child: const Icon(Icons.remove_rounded, size: 16, color: AppColors.navy900)),
        ),
        SizedBox(width: 26, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
        GestureDetector(
          onTap: qty < dish.servingsLeft ? () => state.setLineQty(dish.id, qty + 1) : null,
          child: Container(width: 28, height: 28, decoration: BoxDecoration(color: qty < dish.servingsLeft ? AppColors.navy900 : AppColors.navySoft, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.add_rounded, size: 16, color: qty < dish.servingsLeft ? Colors.white : AppColors.muted)),
        ),
      ],
    );
  }
}
