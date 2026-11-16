import 'package:flutter/material.dart';
import '../app_state.dart';
import '../nav_requests.dart';
import '../theme.dart';
import 'home.dart';
import 'cart.dart';
import 'orders.dart';
import 'misc.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    customerTabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    customerTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final v = customerTabRequest.value;
    if (v == null) return;
    setState(() => _index = v);
    customerTabRequest.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenProfile: () => setState(() => _index = 3)),
          const CartScreen(),
          const MyOrdersScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final count = AppState.instance.cartCount;
          return BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: _CartBadgeIcon(count: count), label: 'Cart'),
              const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'My orders'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          );
        },
      ),
    );
  }
}

class _CartBadgeIcon extends StatelessWidget {
  const _CartBadgeIcon({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Icon(Icons.shopping_cart_rounded),
        if (count > 0)
          Positioned(
            right: -9,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.all(Radius.circular(9))),
              child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, height: 1.1)),
            ),
          ),
      ],
    );
  }
}
