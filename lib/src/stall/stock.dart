import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

/// 21 · Update stock — steppers with a tap-to-type exact value.
class StockUpdateScreen extends StatelessWidget {
  const StockUpdateScreen({super.key});

  Future<void> _editExact(BuildContext context, Dish dish) async {
    final ctrl = TextEditingController(text: '${dish.servingsLeft}');
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Stock for ${dish.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Servings available', helperText: 'Whole number, 0 or higher.'),
            validator: (v) {
              final parsed = int.tryParse((v ?? '').trim());
              if (parsed == null) return 'Stock must be a whole number, 0 or higher.';
              if (parsed < 0) return 'Stock must be a whole number, 0 or higher.';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white),
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              AppState.instance.setServings(dish, int.parse(ctrl.text.trim()));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      return Scaffold(appBar: AppBar(title: const Text('Update stock')), body: const Center(child: Text('This account is not assigned to a stall.')));
    }
    final campusId = state.requiredCampus.id;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dishes = Database.dishes(campusId, stallId: stall.id);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Update stock', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Pill(label: stall.name, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
          ),
          body: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 2, 18, 6),
                child: Text('Changes go live immediately — customers see servings left in real time.', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: dishes.isEmpty
                    ? const EmptyBox(icon: Icons.inventory_2_outlined, title: 'Nothing to stock yet', subtitle: 'Add dishes first, then set how many servings you cook today.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
                        itemCount: dishes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _StockRow(dish: dishes[i], onEditExact: () => _editExact(context, dishes[i])),
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(context).padding.bottom + 14),
                child: PrimaryButton(label: 'Save stock', onPressed: () => showSnack(context, 'Stock updated — customers now see live counts.')),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.dish, required this.onEditExact});
  final Dish dish;
  final VoidCallback onEditExact;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final soldOut = dish.servingsLeft <= 0;
    final low = !soldOut && dish.servingsLeft <= 5;
    final ratio = dish.initialStock == 0 ? 0.0 : (dish.servingsLeft / dish.initialStock).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: low || soldOut ? AppColors.red.withValues(alpha: 0.4) : AppColors.line, width: low || soldOut ? 1.4 : 1),
      ),
      child: Row(
        children: [
          DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 56, radius: 14, photo: dish.photo, soldOut: soldOut),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: ratio, minHeight: 5, backgroundColor: AppColors.navySoft, valueColor: AlwaysStoppedAnimation(ratio <= 0.15 ? AppColors.red : (ratio <= 0.35 ? AppColors.orange : AppColors.green))),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: onEditExact,
                  child: Text(soldOut ? 'Sold out · tap to restock' : '${dish.servingsLeft} servings left · tap to set', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: soldOut ? AppColors.redDark : AppColors.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _step(Icons.remove_rounded, dish.servingsLeft > 0, () => state.adjustServings(dish, -1)),
              SizedBox(
                width: 34,
                child: Text('${dish.servingsLeft}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: soldOut ? AppColors.redDark : (low ? AppColors.orange : AppColors.ink))),
              ),
              _step(Icons.add_rounded, true, () => state.adjustServings(dish, 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: enabled ? AppColors.pageSoft : const Color(0xFFF0F0F5), shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: enabled ? AppColors.navy900 : AppColors.muted),
      ),
    );
  }
}
