import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class AddWardrobeItemScreen extends ConsumerStatefulWidget {
  const AddWardrobeItemScreen({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<AddWardrobeItemScreen> createState() => _AddWardrobeItemScreenState();
}

class _AddWardrobeItemScreenState extends ConsumerState<AddWardrobeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _seasonController = TextEditingController();
  final _occasionController = TextEditingController();

  String? _categoryId;
  bool _loadingCategories = true;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCategories);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _seasonController.dispose();
    _occasionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final controller = ref.read(wardrobeControllerProvider.notifier);
    await controller.loadCategories();
    if (!mounted) return;
    final categories = ref.read(wardrobeControllerProvider).categories;
    setState(() {
      _loadingCategories = false;
      if (categories.isNotEmpty) _categoryId = categories.first.id;
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Add item photo', style: TextStyle(color: LockMyLookUi.ink, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose how you want to add it.', style: TextStyle(color: LockMyLookUi.muted)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _sourceTile(context: sheetContext, icon: Icons.camera_alt_outlined, label: 'Camera', source: ImageSource.camera)),
                  const SizedBox(width: 12),
                  Expanded(child: _sourceTile(context: sheetContext, icon: Icons.photo_library_outlined, label: 'Gallery', source: ImageSource.gallery)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final picked = await _imagePicker.pickImage(source: source, imageQuality: 90, maxWidth: 1800, maxHeight: 1800);
      if (!mounted || picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not select image: $error')));
    }
  }

  Widget _sourceTile({required BuildContext context, required IconData icon, required String label, required ImageSource source}) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: LockMyLookUi.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: LockMyLookUi.border)),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: LockMyLookUi.coralSoft, shape: BoxShape.circle),
              child: Icon(icon, color: LockMyLookUi.coral),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: LockMyLookUi.ink)),
          ],
        ),
      ),
    );
  }

  Future<void> _createItem() async {
    if (!_formKey.currentState!.validate()) return;
    final image = _selectedImage;
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a photo of this item.')));
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
      return;
    }

    final request = WardrobeCreateRequest(
      categoryId: categoryId,
      name: _nameController.text.trim(),
      brand: _optionalValue(_brandController),
      primaryColor: _optionalValue(_primaryColorController),
      secondaryColor: _optionalValue(_secondaryColorController),
      season: _optionalValue(_seasonController),
      occasion: _optionalValue(_occasionController),
    );

    final success = await ref.read(wardrobeControllerProvider.notifier).createItemWithImage(
      profileId: widget.profileId,
      request: request,
      imageFile: image,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    final error = ref.read(wardrobeControllerProvider).errorMessage;
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String? _optionalValue(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  InputDecoration _fieldDecoration({required String label, required IconData icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: LockMyLookUi.muted),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LockMyLookUi.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LockMyLookUi.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: LockMyLookUi.coral, width: 1.5)),
      labelStyle: const TextStyle(color: LockMyLookUi.muted),
      hintStyle: const TextStyle(color: LockMyLookUi.muted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);
    final categories = state.categories;
    final creating = state.status == WardrobeStatus.loading;

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: LockMyLookUi.background,
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: LockMyLookUi.ink)),
        title: const Text('Add Wardrobe Item', style: TextStyle(color: LockMyLookUi.ink, fontSize: 19, fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              _heroIntro(),
              const SizedBox(height: 16),
              _imageSection(creating),
              const SizedBox(height: 20),
              _sectionHeader('Item details', 'Tell us about this piece'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: _fieldDecoration(label: 'Category', icon: Icons.category_outlined),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: categories.map((category) => DropdownMenuItem<String>(value: category.id, child: Text(category.name))).toList(),
                onChanged: _loadingCategories || creating ? null : (value) => setState(() => _categoryId = value),
                validator: (value) => value == null || value.isEmpty ? 'Select a category' : null,
              ),
              if (_loadingCategories) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration(label: 'Name', hint: 'e.g. White Oxford Shirt', icon: Icons.checkroom_outlined),
                validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _brandController, textInputAction: TextInputAction.next, decoration: _fieldDecoration(label: 'Brand', hint: 'e.g. Uniqlo', icon: Icons.sell_outlined)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _primaryColorController, textInputAction: TextInputAction.next, decoration: _fieldDecoration(label: 'Primary color', hint: 'White', icon: Icons.palette_outlined))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _secondaryColorController, textInputAction: TextInputAction.next, decoration: _fieldDecoration(label: 'Secondary', hint: 'Optional', icon: Icons.color_lens_outlined))),
                ],
              ),
              const SizedBox(height: 20),
              _sectionHeader('Style context', 'Help AI style it better'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _seasonController, textInputAction: TextInputAction.next, decoration: _fieldDecoration(label: 'Season', hint: 'Summer', icon: Icons.wb_sunny_outlined))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _occasionController, textInputAction: TextInputAction.done, decoration: _fieldDecoration(label: 'Occasion', hint: 'Casual', icon: Icons.auto_awesome_outlined))),
                ],
              ),
              const SizedBox(height: 22),
              _saveButton(creating),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroIntro() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF1EF), Color(0xFFF4F2FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E7E5)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 14, offset: Offset(0, 5), color: Color(0x12000000))]),
            child: const Icon(Icons.checkroom_outlined, color: LockMyLookUi.coral, size: 27),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Build your wardrobe', style: TextStyle(color: LockMyLookUi.ink, fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Add one piece and let LockMyLook make it style-ready.', style: TextStyle(color: LockMyLookUi.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: LockMyLookUi.ink, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: LockMyLookUi.muted, fontSize: 12)),
      ],
    );
  }

  Widget _imageSection(bool disabled) {
    final image = _selectedImage;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LockMyLookUi.border),
        boxShadow: const [BoxShadow(blurRadius: 20, offset: Offset(0, 7), color: Color(0x0D000000))],
      ),
      child: GestureDetector(
        onTap: disabled ? null : _pickImage,
        child: Container(
          height: 225,
          width: double.infinity,
          decoration: BoxDecoration(color: LockMyLookUi.background, borderRadius: BorderRadius.circular(17)),
          clipBehavior: Clip.antiAlias,
          child: image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 62, height: 62, decoration: const BoxDecoration(color: LockMyLookUi.coralSoft, shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_outlined, size: 31, color: LockMyLookUi.coral)),
                    const SizedBox(height: 12),
                    const Text('Add item photo', style: TextStyle(color: LockMyLookUi.ink, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Tap to use camera or gallery', style: TextStyle(color: LockMyLookUi.muted, fontSize: 12)),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(image, fit: BoxFit.contain),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(onPressed: disabled ? null : () => setState(() => _selectedImage = null), icon: const Icon(Icons.close, color: LockMyLookUi.ink), tooltip: 'Remove image'),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: ElevatedButton.icon(
                        onPressed: disabled ? null : _pickImage,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: LockMyLookUi.ink, elevation: 4, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _saveButton(bool creating) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [BoxShadow(color: LockMyLookUi.coral.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: creating || _loadingCategories ? null : _createItem,
          icon: creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_rounded, size: 21),
          label: Text(creating ? 'Adding to wardrobe...' : 'Add to Wardrobe', style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(backgroundColor: LockMyLookUi.coral, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
        ),
      ),
    );
  }
}
