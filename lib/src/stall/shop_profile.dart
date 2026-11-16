import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

/// · Store profile — the stall owner uploads a photo of their storefront.
/// It shows up in the prep list header (and later, customer-facing stall cards).
class StallShopProfileScreen extends StatefulWidget {
  const StallShopProfileScreen({super.key});

  @override
  State<StallShopProfileScreen> createState() => _StallShopProfileScreenState();
}

class _StallShopProfileScreenState extends State<StallShopProfileScreen> {
  Uint8List? _photoBytes;
  bool _photoRemoved = false;
  bool _saving = false;

  late TimeOfDay _open;
  late TimeOfDay _close;
  late int _capacity;

  @override
  void initState() {
    super.initState();
    final stall = AppState.instance.myStall!;
    _open = TimeOfDay(hour: stall.openMin ~/ 60, minute: stall.openMin % 60);
    _close = TimeOfDay(hour: stall.closeMin ~/ 60, minute: stall.closeMin % 60);
    _capacity = stall.slotCapacity;
  }

  int get _openMin => _open.hour * 60 + _open.minute;
  int get _closeMin => _close.hour * 60 + _close.minute;

  static String _fmt(TimeOfDay t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  String? get _resolvedPhotoB64 {
    if (_photoRemoved) return null;
    if (_photoBytes != null) return base64Encode(_photoBytes!);
    return AppState.instance.myStall?.photo;
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 900, maxHeight: 900, imageQuality: 75);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() { _photoBytes = bytes; _photoRemoved = false; });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not pick a photo: ${e.toString().replaceAll('image_picker_', '')}');
    }
  }

  Future<void> _save() async {
    final stall = AppState.instance.myStall;
    if (stall == null) return;
    if (_closeMin <= _openMin + 20) {
      showSnack(context, 'Closing time must be at least 30 minutes after opening.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Partial updates — only the fields the stall-admin rules allow.
      await Database.updateStallPhoto(stallId: stall.id, photo: _resolvedPhotoB64);
      await Database.updateStallSchedule(stallId: stall.id, openMin: _openMin, closeMin: _closeMin, slotCapacity: _capacity);
      if (mounted) {
        showSnack(context, 'Store profile saved. Schedule applies to upcoming windows.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) showSnack(context, 'Could not save: ${e.toString().replaceAll('cloud_firestore/', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stall = AppState.instance.myStall!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store profile', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Pill(label: stall.name, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const SizedBox(height: 8),
          const Text('Storefront photo', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Shown on the prep list header next to your stall name so the canteen team sees this is your store. A clear shot of your counter or signage works best.', style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  StallAvatar(photo: _resolvedPhotoB64, label: stall.name, size: 150),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 3))),
                      alignment: Alignment.center,
                      child: const Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.navy900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(_resolvedPhotoB64 == null ? 'Tap the photo to add your storefront' : 'Tap to change it', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted))),
          if (_resolvedPhotoB64 != null)
            Center(
              child: TextButton(
                onPressed: () => setState(() { _photoBytes = null; _photoRemoved = true; }),
                child: const Text('Remove photo', style: TextStyle(color: AppColors.redDark, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          const SizedBox(height: 26),
          _infoRow('Stall', stall.name),
          _infoRow('Owner / manager', stall.personName),
          _infoRow('Email', stall.adminEmail),
          const SizedBox(height: 26),
          const Text('Pickup schedule', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Which windows your stall opens for orders, and how many orders fit in each 10-minute slot ("store limit"). Applies to upcoming windows — already-created windows keep today’s limits.', style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.45)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _timeField('Opens', _fmt(_open), () async {
                final t = await showTimePicker(context: context, initialTime: _open);
                if (t != null && mounted) setState(() => _open = t);
              })),
              const SizedBox(width: 10),
              Expanded(child: _timeField('Closes', _fmt(_close), () async {
                final t = await showTimePicker(context: context, initialTime: _close);
                if (t != null && mounted) setState(() => _close = t);
              })),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Orders per window', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const [10, 20, 30, 50])
                SelectChip(label: '$c', selected: _capacity == c, onTap: () => setState(() => _capacity = c)),
            ],
          ),
          const SizedBox(height: 26),
          PrimaryButton(label: 'Save store profile', icon: Icons.check_rounded, loading: _saving, onPressed: _saving ? null : _save),
        ],
      ),
    );
  }

  Widget _timeField(String label, String value, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1.1)),
                    const SizedBox(height: 2),
                    Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(width: 130, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1.2))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
