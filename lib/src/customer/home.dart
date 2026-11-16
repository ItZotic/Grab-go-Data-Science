import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart.dart';
import 'meal.dart';
import 'stall.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  String? _stallFilter; // null = all stalls
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Good morning,';
    if (h < 12) return 'Good noon,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String get _firstName => AppState.instance.currentUser?.name.trim().split(RegExp(r'\s+')).firstOrNull ?? '';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final user = state.currentUser!;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stalls = state.customerStalls();
        final query = _query.trim().toLowerCase();

        // Dishes the customer can see right now (available, live tray first).
        final dishes = <Dish>[];
        for (final stall in stalls) {
          dishes.addAll(Database.dishes(state.requiredCampus.id, stallId: stall.id).where((d) => d.available));
        }
        dishes.sort((a, b) => (b.isNew ? 1 : 0).compareTo(a.isNew ? 1 : 0));

        var filtered = dishes.where((d) {
          if (_stallFilter != null && d.stallId != _stallFilter) return false;
          if (query.isEmpty) return true;
          final stall = stalls.firstWhere((s) => s.id == d.stallId, orElse: () => stalls.first);
          return d.name.toLowerCase().contains(query) || d.category.toLowerCase().contains(query) || d.description.toLowerCase().contains(query) || stall.name.toLowerCase().contains(query);
        }).toList();

        final tray = state.trayCounterDishes().take(3).toList();
        String? nextSlot;
        for (final stall in stalls) {
          final open = Database.slots(campusId: state.requiredCampus.id, stallId: stall.id).where((s) => s.open && !s.full);
          if (open.isNotEmpty) {
            nextSlot = open.first.startLabel;
            break;
          }
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 10, 18, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_greeting $_firstName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                          const SizedBox(height: 1),
                          const Text('What’s for lunch?', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.05)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: AvatarCircle(name: user.name, size: 46, colorIndex: user.colorIndex),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(999)),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search stalls or dishes',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.muted), onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (stalls.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: EmptyBox(
                    icon: Icons.storefront_outlined,
                    title: 'No stalls open yet',
                    subtitle: 'The canteen office will open stalls here soon. Once they do, you can reserve meals and grab them at the express lane.',
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: SectionRow(
                    title: 'Stalls',
                    trailing: GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllStallsScreen())),
                      child: const Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy900)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _stallChip('ALL', null),
                      for (final stall in stalls) _stallChip(stall.name, stall.id),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Live tray counter (navy banner)
                if (tray.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Expanded(child: Text('Live tray counter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: -0.2))),
                              Pill(label: 'Live', color: AppColors.navy900, soft: AppColors.yellow),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tray.map((d) => '${d.name} ${d.servingsLeft} left').join(' · '),
                            style: const TextStyle(color: Color(0xFFC9C7E4), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: SectionRow(
                    title: 'Popular right now',
                    trailing: nextSlot == null ? null : Text('Next slot $nextSlot', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy900)),
                  ),
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Text('Nothing matches “$_query” yet.', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  )
                else
                  for (final dish in filtered) _DishRow(dish: dish, stall: stalls.firstWhere((s) => s.id == dish.stallId, orElse: () => stalls.first)),
              ],
            ],
          ),
          bottomNavigationBar: CartBottomBar(onViewCart: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()))),
        );
      },
    );
  }

  Widget _stallChip(String label, String? stallId) {
    final selected = _stallFilter == stallId;
    final isAll = stallId == null;
    final stall = isAll ? null : AppState.instance.customerStalls().firstWhere((s) => s.id == stallId);

    return GestureDetector(
      onTap: () => setState(() => _stallFilter = stallId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: selected ? Border.all(color: AppColors.navy900, width: 2.4) : null),
              child: isAll
                  ? const CircleAvatar(
                      backgroundColor: AppColors.navy900,
                      child: Text('ALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    )
                  : StallArtCircle(stall: stall!, size: 57),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: selected ? AppColors.navy900 : AppColors.muted, height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- dish row
class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.stall});
  final Dish dish;
  final Stall stall;

  @override
  Widget build(BuildContext context) {
    final low = dish.servingsLeft <= 5;
    final soldOut = dish.servingsLeft <= 0;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MealDetailsScreen(dishId: dish.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 64, photo: dish.photo, soldOut: soldOut),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${peso(dish.price)} · ${stall.name}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (soldOut)
              const Pill(label: 'Sold out', color: AppColors.muted)
            else if (low)
              Pill(label: 'Only ${dish.servingsLeft} left', color: AppColors.redDark, soft: AppColors.redSoft)
            else
              Pill(label: '${dish.servingsLeft} left', color: AppColors.greenDark, soft: AppColors.greenSoft),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// "See all stalls" grid
// ===========================================================================
class AllStallsScreen extends StatelessWidget {
  const AllStallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stalls = state.customerStalls();

    return Scaffold(
      appBar: AppBar(title: const Text('Stalls')),
      body: stalls.isEmpty
          ? const EmptyBox(icon: Icons.storefront_outlined, title: 'No stalls open yet')
          : GridView.builder(
              padding: const EdgeInsets.all(18),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 158, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: stalls.length,
              itemBuilder: (context, i) {
                final stall = stalls[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StallScreen(stallId: stall.id))),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StallArtCircle(stall: stall, size: 56),
                        const Spacer(),
                        Text(stall.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, letterSpacing: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(stall.categories.join(' · '), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
