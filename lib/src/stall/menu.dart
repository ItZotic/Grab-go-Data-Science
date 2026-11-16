import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../db.dart';
import '../theme.dart';
import '../widgets.dart';

/// 19 · Stall menu — dishes this stall sells today.
class StallMenuScreen extends StatelessWidget {
  const StallMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      return Scaffold(appBar: AppBar(title: const Text('Stall menu')), body: const Center(child: Text('This account is not assigned to a stall.')));
    }
    final campusId = state.requiredCampus.id;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dishes = Database.dishes(campusId, stallId: stall.id);
        final onSale = dishes.where((d) => d.available).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stall 2 menu', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DishFormScreen(dishId: null))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: AppColors.navy900),
                          SizedBox(width: 2),
                          Text('Add dish', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.navy900)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                child: Row(
                  children: [
                    Text('${dishes.length} dishes · $onSale on sale today', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ],
                ),
              ),
              Expanded(
                child: dishes.isEmpty
                    ? EmptyBox(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'No dishes yet',
                        subtitle: 'Add your first dish — students will see it on the customer home screen.',
                        action: PrimaryButton(label: 'Add your first dish', expand: false, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DishFormScreen(dishId: null)))),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        itemCount: dishes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _DishCard(dish: dishes[i], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DishFormScreen(dishId: dishes[i].id)))),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Text('Tap a dish to edit its price, stock, or visibility.', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish, required this.onTap});
  final Dish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soldOut = dish.servingsLeft <= 0;
    final Widget pill;
    if (!dish.available) {
      pill = const Pill(label: 'Off', color: AppColors.muted);
    } else if (soldOut) {
      pill = const Pill(label: 'Sold out', color: AppColors.redDark, soft: AppColors.redSoft);
    } else if (dish.isNew) {
      pill = const Pill(label: 'New', color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft);
    } else {
      pill = const Pill(label: 'On sale', color: AppColors.greenDark, soft: AppColors.greenSoft);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: dish.isNew ? AppColors.yellowDeep : AppColors.line, width: dish.isNew ? 1.8 : 1),
        ),
        child: Row(
          children: [
            DishArt(iconIndex: dish.iconIndex, colorIndex: dish.colorIndex, size: 62, photo: dish.photo, soldOut: soldOut),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: -0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${peso(dish.price)} · ${dish.servingsLeft} servings', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
                ],
              ),
            ),
            pill,
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 20 · ADD / EDIT DISH
// ===========================================================================
class DishFormScreen extends StatefulWidget {
  const DishFormScreen({super.key, required this.dishId});
  final String? dishId; // null = add new

  @override
  State<DishFormScreen> createState() => _DishFormScreenState();
}

class _DishFormScreenState extends State<DishFormScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Rice meal';
  bool _liveTray = true;
  int _iconIndex = 0;
  int _colorIndex = 0;
  Uint8List? _photoBytes;
  bool _photoRemoved = false;
  String? _nameError;
  String? _priceError;
  String? _servingsError;
  bool _saving = false;

  Dish? get _existing => widget.dishId == null ? null : Database.dishById(widget.dishId!);

  /// Photo shown in the preview — pending new bytes, otherwise the saved one (unless removed).
  String? get _resolvedPhotoB64 => _photoRemoved ? null : (_photoBytes != null ? base64Encode(_photoBytes!) : _existing?.photo);

  bool get _isNew => widget.dishId == null;

  @override
  void initState() {
    super.initState();
    final d = _existing;
    if (d != null) {
      _nameCtrl.text = d.name;
      _priceCtrl.text = d.price.toStringAsFixed(2);
      _servingsCtrl.text = '${d.servingsLeft}';
      _descCtrl.text = d.description;
      _category = d.category;
      _liveTray = d.liveTray;
      _iconIndex = d.iconIndex;
      _colorIndex = d.colorIndex;
    } else {
      _servingsCtrl.text = '30';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _servingsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
      final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 70);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() { _photoBytes = bytes; _photoRemoved = false; });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not pick a photo: ${e.toString().replaceAll('image_picker_', '')}');
    }
  }

  void _removePhoto() => setState(() { _photoBytes = null; _photoRemoved = true; });

  Future<void> _save() async {
    final state = AppState.instance;
    final stall = state.myStall;
    if (stall == null) {
      if (mounted) setState(() { _nameError = 'This account is not assigned to a stall. Contact the canteen office.'; });
      return;
    }
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final servings = int.tryParse(_servingsCtrl.text.trim());

    setState(() {
      _nameError = name.isEmpty
          ? 'Dish name is required.'
          : (Database.dishByName(name, stallId: stall.id, exceptId: widget.dishId) != null ? 'A dish with this name is already on the menu.' : null);
      _priceError = price == null || price <= 0 ? 'Price must be a number above 0.' : (price > 10000 ? 'That price looks too high.' : null);
      _servingsError = servings == null || servings < 0 ? 'Stock must be a whole number, 0 or higher.' : null;
    });
    if (_nameError != null || _priceError != null || _servingsError != null) return;

    setState(() => _saving = true);
    try {
      if (_isNew) {
        final error = await state.createDish(stallId: stall.id, name: name, description: _descCtrl.text.trim(), price: price!, servings: servings!, category: _category, liveTray: _liveTray, iconIndex: _iconIndex, colorIndex: _colorIndex, photo: _resolvedPhotoB64);
        if (error != null) {
          if (mounted) setState(() { _nameError = error; _saving = false; });
          return;
        }
      } else {
        final d = _existing!;
        final withEdits = d.copyWith(name: name, description: _descCtrl.text.trim(), price: price!, servingsLeft: servings!, category: _category, liveTray: _liveTray, iconIndex: _iconIndex, colorIndex: _colorIndex, isNew: false);
        // Force-set the photo (null clears it) so removals persist.
        await state.updateDish(withEdits.withPhoto(_resolvedPhotoB64));
      }
      if (mounted) {
        Navigator.of(context).pop();
        showSnack(context, _isNew ? '“$name” added to the menu.' : '“$name” updated.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _nameError = 'Could not save: ${e.toString().replaceAll('cloud_firestore/', '')}';
        });
      }
    }
  }

  Future<void> _delete() async {
    final d = _existing!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove dish?'),
        content: Text('“${d.name}” will disappear from the customer menu immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true && mounted) {
      try {
        await AppState.instance.deleteDish(d.id);
        if (mounted) {
          Navigator.of(context).pop();
          showSnack(context, '“${d.name}” removed.');
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Could not remove: ${e.toString().replaceAll('cloud_firestore/', '')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final stall = state.myStall!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add a dish' : 'Edit dish', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Pill(label: stall.name, color: AppColors.yellowOnSoft, soft: AppColors.yellowSoft)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          // Live preview + pickers — tap the tile to add/change the dish photo.
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      DishArt(iconIndex: _iconIndex, colorIndex: _colorIndex, size: 96, radius: 24, photo: _resolvedPhotoB64),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
                          alignment: Alignment.center,
                          child: const Icon(Icons.photo_camera_rounded, size: 15, color: AppColors.navy900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Text(_resolvedPhotoB64 == null ? 'Tap to add a dish photo' : 'Tap to change the photo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ),
                if (_resolvedPhotoB64 != null)
                  GestureDetector(
                    onTap: _removePhoto,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Remove photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.redDark)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < kDishIcons.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _iconIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _iconIndex == i ? AppColors.yellow : AppColors.pageSoft, border: Border.all(color: _iconIndex == i ? AppColors.yellowDeep : Colors.transparent, width: 1.6)),
                      child: Icon(kDishIcons[i], size: 20, color: AppColors.navy900),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < kDishGradients.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kDishGradients[i]), border: Border.all(color: _colorIndex == i ? AppColors.navy900 : Colors.transparent, width: 2.4)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: 'Dish name', errorText: _nameError),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(hintText: 'Description (optional)'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Rice meal', 'Snack', 'Drink'].map((c) => SelectChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c))).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: InputDecoration(hintText: '80', prefixText: '₱ ', errorText: _priceError),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _servingsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(hintText: '30', prefixText: 'Servings  ', errorText: _servingsError),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _liveTray,
            activeTrackColor: AppColors.yellow,
            activeThumbColor: AppColors.navy900,
            onChanged: (v) => setState(() => _liveTray = v),
            title: const Text('Show on Live Tray Counter', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            subtitle: const Text('Customers see how many servings are left in real time.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Save dish', loading: _saving, onPressed: _saving ? null : _save),
          if (!_isNew) ...[
            const SizedBox(height: 8),
            GhostButton(label: 'Remove dish', color: AppColors.red, onPressed: _delete),
          ],
        ],
      ),
    );
  }
}
