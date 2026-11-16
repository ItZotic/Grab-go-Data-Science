import 'package:flutter/material.dart';
import '../nav_requests.dart';
import 'prep.dart';
import 'verify.dart';
import 'menu.dart';
import 'stock.dart';
import 'sales.dart';

class StallShell extends StatefulWidget {
  const StallShell({super.key});

  @override
  State<StallShell> createState() => _StallShellState();
}

class _StallShellState extends State<StallShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          PrepListScreen(
            onOpenVerify: (orderNo) {
              setState(() => _index = 1);
              receiptScanRequest.value = orderNo;
            },
          ),
          ReceiptVerifyScreen(onGoToPrep: () => setState(() => _index = 0)),
          const StallMenuScreen(),
          const StockUpdateScreen(),
          const StallSalesReportScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.room_service_outlined), activeIcon: Icon(Icons.room_service_rounded), label: 'Prep'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Receipts'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_outlined), activeIcon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2_rounded), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'Sales'),
        ],
      ),
    );
  }
}
