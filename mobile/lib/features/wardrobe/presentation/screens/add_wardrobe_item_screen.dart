import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class AddWardrobeItemScreen extends ConsumerStatefulWidget {
  const AddWardrobeItemScreen({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<AddWardrobeItemScreen> createState() =>
      _AddWardrobeItemScreenState();
}

class _AddWardrobeItemScreenState extends ConsumerState<AddWardrobeItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _seasonController = TextEditingController();
  final _occasionController = TextEditingController();

  String? _categoryId;
  bool _loadingCategories = true;

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

    if (!mounted) {
      return;
    }

    final categories = ref.read(wardrobeControllerProvider).categories;

    setState(() {
      _loadingCategories = false;

      if (categories.isNotEmpty) {
        _categoryId = categories.first.id;
      }
    });
  }

  Future<void> _createItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final categoryId = _categoryId;

    if (categoryId == null || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
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

    final success = await ref
        .read(wardrobeControllerProvider.notifier)
        .createItem(profileId: widget.profileId, request: request);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = ref.read(wardrobeControllerProvider).errorMessage;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  String? _optionalValue(TextEditingController controller) {
    final value = controller.text.trim();

    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);
    final categories = state.categories;

    final creating = state.status == WardrobeStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Wardrobe Item')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: _loadingCategories || creating
                    ? null
                    : (value) {
                        setState(() {
                          _categoryId = value;
                        });
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a category';
                  }

                  return null;
                },
              ),
              if (_loadingCategories)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. White Oxford Shirt',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g. Uniqlo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primaryColorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Primary color',
                  hintText: 'e.g. White',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secondaryColorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Secondary color',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seasonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  hintText: 'e.g. Summer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _occasionController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Occasion',
                  hintText: 'e.g. Casual',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: creating || _loadingCategories
                      ? null
                      : _createItem,
                  child: creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
