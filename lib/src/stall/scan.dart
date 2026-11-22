import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_code_dart_decoder/qr_code_dart_decoder.dart';

import '../app_state.dart';
import '../db.dart';
import '../theme.dart';

/// 17 · Scan receipt QR — viewfinder UI with camera and image scanning.
///
/// Decodes real receipt QR codes from the device camera or image gallery,
/// supports instant tap-to-scan for active ready orders, and provides a manual
/// order number entry fallback.
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  final _ctrl = TextEditingController();
  String? _error;
  bool _isScanning = false;
  String? _scannedOrder;
  bool _flashOn = false;

  /// Live camera controller — real-time QR detection + torch.
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void dispose() {
    _line.dispose();
    _ctrl.dispose();
    _camera.dispose();
    super.dispose();
  }

  /// One QR detection from the live camera. Guarded so one receipt can't pop twice.
  void _onDetect(BarcodeCapture capture) {
    if (_scannedOrder != null || _isScanning) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      _camera.stop();
      _handleSuccess(value);
      return;
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _camera.toggleTorch();
      if (mounted) setState(() => _flashOn = !_flashOn);
    } catch (_) {
      if (mounted) setState(() => _error = 'This device has no torch on the back camera.');
    }
  }

  void _submit() {
    final raw = _ctrl.text.trim().toUpperCase().replaceAll('#', '');
    final match = RegExp(r'(\d{1,5})').firstMatch(raw);
    if (match == null) {
      setState(() => _error = 'Enter the order number printed under the QR (e.g. GG-0001).');
      return;
    }
    _handleSuccess('GG-${match.group(1)!.padLeft(4, '0')}');
  }

  Future<void> _scanFromImageSource(ImageSource source) async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (file == null) {
        if (mounted) setState(() => _isScanning = false);
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final decoder = QrCodeDartDecoder();
      final ScanResult? result = await decoder.decodeFile(bytes);

      if (result == null || result.text.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _error = 'No QR code detected in the photo. Please align the QR within the frame and try again.';
          });
        }
        return;
      }

      _handleSuccess(result.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _error = 'Error scanning image: $e';
        });
      }
    }
  }

  void _handleSuccess(String raw) {
    final clean = raw.trim().toUpperCase().replaceAll('#', '');
    final match = RegExp(r'(\d{1,5})').firstMatch(clean);
    if (match == null) {
      setState(() {
        _isScanning = false;
        _error = 'QR code does not contain a valid order number.';
      });
      return;
    }

    final orderNo = 'GG-${match.group(1)!.padLeft(4, '0')}';
    setState(() {
      _isScanning = false;
      _scannedOrder = orderNo;
      _error = null;
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        Navigator.of(context).pop(orderNo);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stallId = state.currentUser?.stallId;
    final List<OrderRec> readyOrders;
    if (stallId != null && stallId.isNotEmpty) {
      readyOrders = state.stallOrders(stallId).where((o) => o.status == OrderStatus.ready || o.status == OrderStatus.preparing).toList();
    } else {
      final campusId = state.requiredCampus.id;
      readyOrders = Database.orders(campusId).where((o) => o.status == OrderStatus.ready || o.status == OrderStatus.preparing).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF11111F),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  GestureDetector(
                    onTap: _toggleFlash,
                    child: Row(
                      children: [
                        Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, size: 16, color: _flashOn ? AppColors.yellow : Colors.white54),
                        const SizedBox(width: 6),
                        Text(_flashOn ? 'Flash on' : 'Flash off', style: TextStyle(color: _flashOn ? AppColors.yellow : Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Scan receipt QR', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              const Text('Point camera, take photo, or upload receipt QR to verify.', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Real live camera feed with automatic QR detection.
                        MobileScanner(
                          controller: _camera,
                          onDetect: _onDetect,
                          errorBuilder: (context, error, _) => Container(
                            color: const Color(0xFF1D1D32),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Camera unavailable: ${error.errorCode}\nUse Upload photo or type the order number below.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ),
                        // Scan brackets on top of the feed.
                        ..._corners(280, 46),
                        AnimatedBuilder(
                          animation: _line,
                          builder: (context, _) {
                            final t = Curves.easeInOutSine.transform(_line.value);
                            return Positioned(
                              top: 40 + t * 200,
                              left: 28,
                              right: 28,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(colors: [Colors.transparent, AppColors.yellow, Colors.transparent]),
                                ),
                              ),
                            );
                          },
                        ),
                        if (_isScanning)
                          Container(
                            color: const Color(0x9911111F),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppColors.yellow, strokeWidth: 3),
                                SizedBox(height: 12),
                                Text('Reading QR code…', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )
                        else if (_scannedOrder != null)
                          Container(
                            color: const Color(0xCC11111F),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 54),
                                const SizedBox(height: 8),
                                Text('Scanned $_scannedOrder!', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Point the camera at the QR on the customer’s receipt — it scans automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Live camera scans automatically; this just resets after a scan/error.
                        setState(() {
                          _scannedOrder = null;
                          _error = null;
                          _isScanning = false;
                        });
                        _camera.start();
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Restart camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.navy900,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isScanning ? null : () => _scanFromImageSource(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Upload photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),

              if (readyOrders.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Orders ready for handout (tap to scan):',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: readyOrders.length,
                    separatorBuilder: (_, second) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final o = readyOrders[i];
                      return ActionChip(
                        backgroundColor: const Color(0xFF1D1D32),
                        side: const BorderSide(color: AppColors.yellow, width: 1.2),
                        avatar: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.yellow),
                        label: Text(
                          '${orderNoDisplay(o.orderNo)} · ${o.customerName}',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                        onPressed: _isScanning ? null : () => _handleSuccess(o.orderNo),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (v) => _ctrl.value = _ctrl.value.copyWith(
                        text: v.toUpperCase(),
                        selection: TextSelection.collapsed(offset: v.length),
                      ),
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
                  'Supports live camera capture, photo upload, and instant receipt verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10.5, fontWeight: FontWeight.w600),
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
