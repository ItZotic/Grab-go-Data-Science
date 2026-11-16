import 'package:flutter/material.dart';
import '../theme.dart';

/// 17 · Scan receipt QR — viewfinder UI.
///
/// The QR codes shown on Grab&Go receipts are real (standard QR encoding the
/// order number), so ANY phone camera can read them. The in-app camera
/// scanner requires the Android/iOS build; on this desktop/web build the
/// staff types the order number below instead.
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _line.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.trim().toUpperCase().replaceAll('#', '');
    final match = RegExp(r'(\d{3,5})').firstMatch(raw);
    if (match == null) {
      setState(() => _error = 'Enter the order number printed under the QR.');
      return;
    }
    Navigator.of(context).pop('GG-${match.group(1)!.padLeft(4, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11111F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Row(
                      children: [
                        Icon(Icons.chevron_left_rounded, color: Colors.white70),
                        SizedBox(width: 2),
                        Text('Back', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: const [
                      Icon(Icons.flash_off_rounded, size: 16, color: Colors.white54),
                      SizedBox(width: 6),
                      Text('Flash off', style: TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Scan receipt QR', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Point the camera at the customer’s QR code.', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 26),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final s = c.maxWidth;
                        const bracket = 46.0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // faint finder pattern hint
                            Container(
                              width: s * 0.72,
                              height: s * 0.72,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white.withValues(alpha: 0.04)),
                            ),
                            // corner brackets
                            ..._corners(s, bracket),
                            // scanning line
                            AnimatedBuilder(
                              animation: _line,
                              builder: (context, _) {
                                final t = Curves.easeInOutSine.transform(_line.value);
                                final y = (s * 0.14) + t * (s * 0.72 - s * 0.14);
                                return Positioned(
                                  top: y,
                                  left: s * 0.09,
                                  right: s * 0.09,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: const LinearGradient(colors: [Colors.transparent, AppColors.yellow, Colors.transparent])),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Scanning…', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.navy900, letterSpacing: 0.8)),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Hold steady. The order opens as soon as the code is read.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              // Working fallback: type the number instead.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) => _ctrl.value = _ctrl.value.copyWith(text: v.toUpperCase(), selection: TextSelection.collapsed(offset: v.length)),
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type order number, e.g. GG-0427',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.yellow, width: 1.6)),
                        errorText: _error,
                        errorStyle: const TextStyle(color: Color(0xFFFDA4AF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_forward_rounded, color: AppColors.navy900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Camera scanning requires the Android/iOS build.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _corners(double s, double b) {
    const yellow = AppColors.yellow;
    const thickness = 4.0;
    const radius = 14.0;
    Widget corner(Alignment alignment, bool flipH, bool flipV) => Align(
          alignment: alignment,
          child: SizedBox(
            width: b + 8,
            height: b + 8,
            child: CustomPaint(
              painter: _CornerPainter(color: yellow, strokeWidth: thickness, cornerRadius: radius, flipH: flipH, flipV: flipV),
            ),
          ),
        );
    return [
      corner(Alignment.topLeft, false, false),
      corner(Alignment.topRight, true, false),
      corner(Alignment.bottomLeft, false, true),
      corner(Alignment.bottomRight, true, true),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.color, required this.strokeWidth, required this.cornerRadius, required this.flipH, required this.flipV});
  final Color color;
  final double strokeWidth;
  final double cornerRadius;
  final bool flipH;
  final bool flipV;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path();
    final double x0 = flipH ? w : 0;
    final double sx = flipH ? -1 : 1;
    final double y0 = flipV ? h : 0;
    final double sy = flipV ? -1 : 1;
    path.moveTo(x0 + sx * (w * 0.62), y0);
    path.lineTo(x0 + sx * cornerRadius, y0);
    path.quadraticBezierTo(x0, y0, x0, y0 + sy * cornerRadius);
    path.lineTo(x0, y0 + sy * (h * 0.62));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
