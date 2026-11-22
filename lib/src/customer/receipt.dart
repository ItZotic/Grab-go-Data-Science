import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_state.dart';
import '../db.dart';
import '../nav_requests.dart';
import '../theme.dart';
import '../widgets.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.orderId, this.celebrate = false});
  final String orderId;
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final order = Database.orderById(orderId, campusId: state.requiredCampus.id);
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Receipt not found.')));
    }

    final paid = order.payment != PayMethod.counter;
    final itemsLine = order.items.map((i) => '${i.qty} ${i.name}').join(', ');

    return Scaffold(
      backgroundColor: AppColors.greenSoft,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (celebrate) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 52, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              const Center(child: Text('Order placed', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.6))),
              const SizedBox(height: 2),
              const Center(child: Text('Show this receipt at the express lane', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted))),
              const SizedBox(height: 20),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const BackLink(),
                    const Spacer(),
                    Pill(
                      label: Database.isLapsed(order)
                          ? 'Expired'
                          : switch (order.status) {
                              OrderStatus.preparing => 'Preparing',
                              OrderStatus.ready => 'Ready for pickup',
                              OrderStatus.claimed => 'Claimed',
                              OrderStatus.released => 'Expired',
                            },
                      color: Database.isLapsed(order)
                          ? AppColors.muted
                          : switch (order.status) {
                              OrderStatus.preparing => const Color(0xFFB45309),
                              OrderStatus.ready => const Color(0xFF1D4ED8),
                              OrderStatus.claimed => AppColors.greenDark,
                              OrderStatus.released => AppColors.muted,
                            },
                      soft: Database.isLapsed(order)
                          ? AppColors.pageSoft
                          : switch (order.status) {
                              OrderStatus.preparing => const Color(0xFFFEF3C7),
                              OrderStatus.ready => AppColors.blueSoft,
                              OrderStatus.claimed => AppColors.greenSoft,
                              OrderStatus.released => AppColors.pageSoft,
                            },
                    ),
                  ],
                ),
              ),
            ],

            // ---------------- receipt card ----------------
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Column(
                children: [
                  const GrabLogo(size: 48),
                  const SizedBox(height: 12),
                  const Text('Order no.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  SelectableText(
                    orderNoDisplay(order.orderNo),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Real QR — any phone camera can read this.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: orderNoDisplay(order.orderNo),
                      version: QrVersions.auto,
                      size: 158,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.navy900),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.navy900),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  _row('Name', order.customerName),
                  _row('Items', itemsLine),
                  _row('Pickup', order.slotLabel),
                  _row('Mode', paid ? '${payMethodLabel(order.payment)}${order.payRef.isNotEmpty ? ' · ${order.payRef}' : ''}' : 'Pay at the counter'),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 92, child: Text('Payment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.4))),
                        const Spacer(),
                        Pill(label: paid ? 'Paid' : 'Pay at pickup', color: paid ? AppColors.greenDark : const Color(0xFFB45309), soft: paid ? AppColors.greenSoft : const Color(0xFFFEF3C7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            NavyButton(
              label: 'View my orders',
              onPressed: () {
                customerTabRequest.value = 2;
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to home', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 92, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1))),
            const SizedBox(width: 8),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35))),
          ],
        ),
      );
}
