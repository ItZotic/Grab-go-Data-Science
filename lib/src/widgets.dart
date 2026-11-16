import 'dart:convert';

import 'package:flutter/material.dart';
import 'app_state.dart';
import 'db.dart';
import 'theme.dart';

// ------------------------------------------------------------------ brand
class GrabLogo extends StatelessWidget {
  const GrabLogo({super.key, this.size = 96, this.splash = false});
  final double size;
  final bool splash;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: splash ? -0.06 : 0,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: CustomPaint(painter: _BagLogoPainter(), size: Size(size, size)),
      ),
    );
  }
}

/// The Grab&Go bag mark — orange shopping bag with a black "goggle" GO band,
/// drawn in code so it stays crisp at every size (no image assets needed).
/// Canvas is 100×100 units, scaled to the widget.
class _BagLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100.0);

    const rect = Rect.fromLTWH(0, 0, 100, 100);

    // ---------- warm gradient backdrop ----------
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.55, -1),
        end: Alignment(0.55, 1.05),
        colors: [Color(0xFFFCF4CF), Color(0xFFF6C65C), Color(0xFFE09A33), Color(0xFFB96B1D), Color(0xFF421F0E)],
        stops: [0, 0.28, 0.55, 0.8, 1],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // faint sun rays radiating from upper-center
    canvas.save();
    canvas.translate(50, 32);
    // faint sun rays radiating from upper-center (low-alpha warm light)
    final ray = Paint()..color = const Color(0x14FFF8DC);
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * 6.283185;
      final path = Path()
        ..moveTo(0, 0)
        ..addArc(Rect.fromCircle(center: Offset.zero, radius: 200), a - 0.09, 0.18)
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.restore();

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..color = const Color(0xFF151009)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final inkFill = Paint()
      ..color = const Color(0xFF151009)
      ..style = PaintingStyle.fill;
    final inkFillBg = Paint()..color = const Color(0xFF151009);

    // ---------- handle (drawn before the body so the bag overlaps its ends) ----------
    final handleRect = Rect.fromCircle(center: const Offset(45, 26), radius: 13.6);
    canvas.drawArc(handleRect, 3.14159, 3.14159, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 6.6..color = const Color(0xFF151009));
    canvas.drawArc(handleRect, 3.14159, 3.14159, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.4..color = const Color(0xFFF4731F));

    // ---------- right 3D face of the bag ----------
    final side = Path()
      ..moveTo(66, 24.2)
      ..lineTo(83.5, 28.6)
      ..quadraticBezierTo(88.8, 29.6, 87.6, 38.6)
      ..lineTo(92.4, 73)
      ..quadraticBezierTo(93.3, 81.8, 84, 82.6)
      ..lineTo(73.2, 83.6)
      ..close();
    final sidePaint = Paint()
      ..shader = const LinearGradient(begin: Alignment(-0.4, -1), end: Alignment(0.7, 1), colors: [Color(0xFF9A3A0C), Color(0xFF5F1E04)]).createShader(const Rect.fromLTWH(66, 24, 28, 60));
    canvas.drawPath(side, sidePaint);
    canvas.drawPath(side, ink);

    // ---------- bag body (trapezoid, wider at top, slight lean) ----------
    final body = Path()
      ..moveTo(16, 33)
      ..quadraticBezierTo(15, 25.5, 22, 25.3)
      ..lineTo(64, 24)
      ..quadraticBezierTo(73.5, 23.8, 72.3, 31.5)
      ..lineTo(80.8, 74.5)
      ..quadraticBezierTo(82, 83.6, 73, 84.3)
      ..lineTo(23, 84.9)
      ..quadraticBezierTo(11.8, 84.4, 13, 74.8)
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4731F), Color(0xFFE8550F), Color(0xFFBC3A06)]).createShader(const Rect.fromLTWH(11, 24, 72, 61));
    canvas.drawPath(body, bodyPaint);
    canvas.drawPath(body, ink);

    // ---------- sunglasses band across the middle ----------
    canvas.drawCircle(const Offset(33, 56), 16.4, inkFill);
    canvas.drawCircle(const Offset(68, 56), 16.4, inkFill);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50.5, 57.6), width: 35, height: 17), inkFill);
    // lens inner rim highlight
    final rim = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x26FFFFFF);
    canvas.drawCircle(const Offset(33, 56), 14.4, rim);
    canvas.drawCircle(const Offset(68, 56), 14.4, rim);

    // ---------- "GO" letters ----------
    _drawLetter(canvas, 'G', const Offset(33, 57.2));
    _drawLetter(canvas, 'O', const Offset(68, 57.2));
    // O pupil
    canvas.drawCircle(const Offset(68, 57.2), 5.6, inkFillBg);

    // ---------- glossy highlights ----------
    final glossStrong = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.9..strokeCap = StrokeCap.round..color = const Color(0xD9FFFFFF);
    final glossSoft = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..strokeCap = StrokeCap.round..color = const Color(0x66FFFFFF);
    // left edge streak
    canvas.drawPath(Path()..moveTo(15.6, 39.5)..quadraticBezierTo(12.8, 55, 14.3, 69.5), glossStrong);
    // top gloss
    canvas.drawPath(Path()..moveTo(26.5, 28.3)..quadraticBezierTo(45, 26.5, 60.5, 26.1), glossSoft);
    // handle gloss
    canvas.drawArc(handleRect, 3.14159 + 0.55, 0.6, false, glossStrong..strokeWidth = 1.6);
  }

  void _drawLetter(Canvas canvas, String letter, Offset center) {
    final tp = TextPainter(
      text: TextSpan(text: letter, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: Color(0xFFF6EACB), letterSpacing: 0)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------------ stall avatar
class StallAvatar extends StatelessWidget {
  const StallAvatar({super.key, this.photo, required this.label, this.size = 26});
  final String? photo;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      try {
        final bytes = base64Decode(photo!);
        return ClipOval(child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, second, third) => Container(color: AppColors.navy900, alignment: Alignment.center, child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 14))));
      } catch (_) {}
    }
    final parts = label.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).toList();
    final initials = parts.isEmpty ? '?' : parts.map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.navy900, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w800)),
    );
  }
}

// ------------------------------------------------------------------ stall art
const List<IconData> kStallIcons = [
  Icons.ramen_dining_rounded,
  Icons.coffee_rounded,
  Icons.local_fire_department_rounded,
  Icons.icecream_rounded,
  Icons.lunch_dining_rounded,
  Icons.soup_kitchen_rounded,
];

const List<List<Color>> kStallGradients = [
  [Color(0xFFFFB86B), Color(0xFFF97316)],
  [Color(0xFF9BE3A9), Color(0xFF15803D)],
  [Color(0xFF7FDCF1), Color(0xFF0E7490)],
  [Color(0xFFFFD9A0), Color(0xFFF59E0B)],
  [Color(0xFFE3C5FF), Color(0xFF8B5CF6)],
  [Color(0xFFFBC9C9), Color(0xFFEF4444)],
];

/// Storefront avatar used everywhere a stall is shown — real photo when the
/// owner uploaded one in Store profile, otherwise the illustrated art.
class StallArtCircle extends StatelessWidget {
  const StallArtCircle({super.key, required this.stall, this.size = 56});
  final Stall stall;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = stall.photo;
    if (photo != null) {
      try {
        final bytes = base64Decode(photo);
        return ClipOval(child: Image.memory(bytes, key: ValueKey(photo), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, second, third) => Container(color: AppColors.navy900, alignment: Alignment.center, child: const Icon(Icons.broken_image_rounded, color: Colors.white, size: 22))));
      } catch (_) {
        // Decode failed (future work: surface this) — fall back to the art tile.
      }
    }
    final gradient = kStallGradients[stall.colorIndex % kStallGradients.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      alignment: Alignment.center,
      child: Icon(kStallIcons[stall.iconIndex % kStallIcons.length], color: Colors.white, size: size * 0.45),
    );
  }
}

// ------------------------------------------------------------------ dish art
const List<IconData> kDishIcons = [
  Icons.dinner_dining_rounded,
  Icons.ramen_dining_rounded,
  Icons.soup_kitchen_rounded,
  Icons.rice_bowl_rounded,
  Icons.set_meal_rounded,
  Icons.local_cafe_rounded,
  Icons.egg_alt_rounded,
  Icons.tapas_rounded,
];

const List<List<Color>> kDishGradients = [
  [Color(0xFFFFB86B), Color(0xFFF97316)], // sisig orange
  [Color(0xFF9BE3A9), Color(0xFF21B573)], // tofu green
  [Color(0xFF7FDCF1), Color(0xFF0E7490)], // sinigang teal
  [Color(0xFFFDE68A), Color(0xFFF5B301)], // garlic rice gold
  [Color(0xFFFBC9C9), Color(0xFFEF4444)], // caldereta red
  [Color(0xFFD8C7FF), Color(0xFF8B5CF6)], // drinks violet
  [Color(0xFFFFE29A), Color(0xFFEAB308)], // egg amber
  [Color(0xFFFFD8A8), Color(0xFFD97706)], // sautéed brown
];

class DishArt extends StatelessWidget {
  const DishArt({super.key, required this.iconIndex, required this.colorIndex, this.size = 64, this.radius = 16, this.soldOut = false, this.photo});
  final int iconIndex;
  final int colorIndex;
  final double size;
  final double radius;
  final bool soldOut;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      // Real dish photo wins over the illustrated tile.
      try {
        final bytes = base64Decode(photo!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, second, third) => const Icon(Icons.broken_image_rounded)),
                if (soldOut)
                if (soldOut)
                  Container(color: AppColors.navy900.withValues(alpha: 0.35), alignment: Alignment.center, child: const Icon(Icons.block_rounded, color: Colors.white, size: 22)),
              ],
            ),
          ),
        );
      } catch (_) {}
    }
    final gradient = kDishGradients[colorIndex % kDishGradients.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(right: -size * 0.25, top: -size * 0.25, child: Container(width: size * 0.75, height: size * 0.75, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)))),
            Center(child: Icon(kDishIcons[iconIndex % kDishIcons.length], color: Colors.white, size: size * 0.45)),
            if (soldOut)
              Container(color: AppColors.navy900.withValues(alpha: 0.35), alignment: Alignment.center, child: const Icon(Icons.block_rounded, color: Colors.white, size: 22)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ buttons
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.disabled = false, this.expand = true, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool disabled;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink))
        : Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)], Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.1))]);
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.yellow,
          disabledBackgroundColor: AppColors.navySoft,
          disabledForegroundColor: AppColors.muted,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        child: child,
      ),
    );
  }
}

class NavyButton extends StatelessWidget {
  const NavyButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)], Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]);
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy900,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onPressed, this.color = AppColors.navy900, this.icon, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    );
  }
}

class GreenButton extends StatelessWidget {
  const GreenButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : (icon == null ? const SizedBox.shrink() : Icon(icon, size: 20)),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ pills & chips
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.soft, this.icon});
  final String label;
  final Color color;
  final Color? soft;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = soft ?? color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, this.onTap, this.dark = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (dark ? AppColors.navy900 : AppColors.navy900) : AppColors.pageSoft;
    final fg = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? AppColors.navy900 : AppColors.line)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}

// ------------------------------------------------------------------ segmented
/// Mockup segmented control: grey track, white (or navy) selected pill.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.selected, required this.onChanged, this.darkSelected = false, this.trackColor = AppColors.pageSoft});
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool darkSelected; // navy pill (like the Day/Week/Month switch)
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selected ? (darkSelected ? AppColors.navy900 : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == selected && !darkSelected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))] : null,
                  ),
                  child: Text(
                    items[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: i == selected ? (darkSelected ? Colors.white : AppColors.ink) : AppColors.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ layout bits
class SectionRow extends StatelessWidget {
  const SectionRow({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2))),
          ?trailing,
        ],
      ),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 40, this.colorIndex = 0});
  final String name;
  final double size;
  final int colorIndex;

  static const _palette = [Color(0xFFF97316), Color(0xFF21B573), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF14B8A6), Color(0xFFF5B301), Color(0xFF64748B)];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _palette[colorIndex % _palette.length], shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.36, letterSpacing: 0.5)),
    );
  }
}

class EmptyBox extends StatelessWidget {
  const EmptyBox({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 74, height: 74, decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 34, color: AppColors.muted)),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

/// "< Back" text button exactly like the mockups.
class BackLink extends StatelessWidget {
  const BackLink({super.key, this.onTap, this.label = 'Back'});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_left_rounded, size: 22, color: AppColors.muted),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ stat tile
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueColor, this.icon});
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.pageSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 22, color: AppColors.navy900), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AppColors.muted)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: valueColor ?? AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ bar chart (sales per day)
class DayBars extends StatelessWidget {
  const DayBars({super.key, required this.values, this.bestDayIndex, this.height = 96});
  final List<double> values; // 7 values Mon..Sun
  final int? bestDayIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (a, b) => b > a ? b : a);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: height,
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 26,
                        height: values[i] <= 0 ? 4 : (values[i] / maxV) * c.maxHeight,
                        decoration: BoxDecoration(color: bestDayIndex == i ? AppColors.yellowDeep : AppColors.yellow, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ horizontal report bar
class ReportBar extends StatelessWidget {
  const ReportBar({super.key, required this.label, required this.valueLabel, required this.fraction, this.color = AppColors.yellow, this.labelWidth = 128});
  final String label;
  final String valueLabel;
  final double fraction;
  final Color color;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: labelWidth, child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: fraction.clamp(0, 1), minHeight: 10, backgroundColor: AppColors.navySoft, valueColor: AlwaysStoppedAnimation(color)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 52, child: Text(valueLabel, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ cart bottom bar (customer)
class CartBottomBar extends StatelessWidget {
  const CartBottomBar({super.key, required this.onViewCart});
  final VoidCallback onViewCart;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        if (state.cartCount == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: AppColors.background),
          child: GestureDetector(
            onTap: onViewCart,
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x33F5B301), blurRadius: 14, offset: Offset(0, 4))]),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.navy900, borderRadius: BorderRadius.circular(10)),
                    child: Text('${state.cartCount} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('View cart', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                  Text(peso(state.cartTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A cart holds items from one stall only (matches single-stall pickup).
/// Returns true if the dish was added.
Future<bool> addToSingleStallCart(BuildContext context, Dish dish, {int qty = 1}) async {
  final state = AppState.instance;
  final cartDish = state.cart.isNotEmpty ? state.cart.first.dish : null;
  if (cartDish != null && cartDish.stallId != dish.stallId) {
    final swap = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start a new cart?'),
        content: Text('Your cart has items from another stall. Replace it with “${dish.name}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep cart')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.navy900, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
        ],
      ),
    );
    if (swap != true) return false;
    state.clearCart();
  }
  state.addToCart(dish, qty: qty);
  return true;
}

void showSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null ? SnackBarAction(label: actionLabel, textColor: AppColors.yellow, onPressed: onAction ?? () {}) : null,
      duration: const Duration(seconds: 3),
    ),
  );
}
