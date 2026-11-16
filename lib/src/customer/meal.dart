import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

class MealDetailsScreen extends StatefulWidget {
  const MealDetailsScreen({super.key, required this.dishId});
  final String dishId;

  @override
  State<MealDetailsScreen> createState() => _MealDetailsScreenState();
}

class _MealDetailsScreenState extends State<MealDetailsScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dish = Database.dishes(state.requiredCampus.id).firstWhere((d) => d.id == widget.dishId, orElse: () => Dish(id: '', campusId: '', stallId: '', name: '', description: '', price: 0, servingsLeft: 0, initialStock: 1));
        if (dish.id.isEmpty) {
          return const Scaffold(body: Center(child: Text('This dish is unavailable.')));
        }
        final stall = Database.stallById(dish.stallId);
        final soldOut = dish.servingsLeft <= 0;
        final maxQty = dish.servingsLeft < 1 ? 1 : dish.servingsLeft;
        if (_qty > maxQty) _qty = maxQty;
        final low = dish.servingsLeft <= 5;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 18, 0),
                  child: Row(
                    children: [
                      const BackLink(),
                      const Spacer(),
                      if (soldOut)
                        const Pill(label: 'Sold out', color: AppColors.muted)
                      else if (low)
                        Pill(label: 'Only ${dish.servingsLeft} left', color: AppColors.redDark, soft: AppColors.redSoft)
                      else
                        Pill(label: '${dish.servingsLeft} left', color: AppColors.greenDark, soft: AppColors.greenSoft),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    children: [
                      // Hero panel
                      Container(
                        height: 210,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [kDishGradients[dish.colorIndex % kDishGradients.length][0].withValues(alpha: 0.45), kDishGradients[dish.colorIndex % kDishGradients.length][1].withValues(alpha: 0.35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 148, radius: 30, photo: dish.photo, soldOut: soldOut),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(dish.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7, height: 1.15))),
                          const SizedBox(width: 12),
                          Text(peso(dish.price), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: -0.6)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (stall != null) Text(stall.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Text(
                        dish.description.isEmpty ? 'Fresh from the stall, plated the way you like it.' : dish.description,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      // Servings left
                      Row(
                        children: [
                          const Text('Servings left', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          const Spacer(),
                          Text('${dish.servingsLeft} / ${dish.initialStock}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: low ? AppColors.redDark : AppColors.greenDark)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: dish.initialStock == 0 ? 0 : dish.servingsLeft / dish.initialStock,
                          minHeight: 5,
                          backgroundColor: AppColors.navySoft,
                          valueColor: AlwaysStoppedAnimation(low ? AppColors.red : AppColors.green),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Quantity
                      Row(
                        children: [
                          const Expanded(child: Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                          Row(
                            children: [
                              _stepBtn(Icons.remove_rounded, _qty > 1, () => setState(() => _qty--)),
                              Container(
                                width: 46,
                                height: 38,
                                decoration: const BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.all(Radius.circular(12))),
                                alignment: Alignment.center,
                                child: Text('$_qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                              ),
                              _stepBtn(Icons.add_rounded, _qty < maxQty, () => setState(() => _qty++)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).padding.bottom + 14),
                  child: PrimaryButton(
                    label: soldOut ? 'Sold out' : 'Add to cart · ${peso(dish.price * _qty)}',
                    disabled: soldOut,
                    onPressed: () async {
                      final ok = await addToSingleStallCart(context, dish, qty: _qty);
                      if (!context.mounted) return;
                      if (ok) showSnack(context, 'Added $_qty × ${dish.name} to your cart.');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 38,
        alignment: Alignment.center,
        child: Icon(icon, color: enabled ? AppColors.navy900 : AppColors.muted, size: 22),
      ),
    );
  }
}
