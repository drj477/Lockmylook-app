import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class EditWardrobeItemScreen extends ConsumerStatefulWidget {
  const EditWardrobeItemScreen({
    required this.profileId,
    required this.item,
    super.key,
  });

  final String profileId;
  final WardrobeItem item;

  @override
  ConsumerState<EditWardrobeItemScreen> createState() =>
      _EditWardrobeItemScreenState();
}

class _EditWardrobeItemScreenState
    extends ConsumerState<EditWardrobeItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _seasonController;
  late final TextEditingController _occasionController;

  late bool _favorite;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _nameController = TextEditingController(text: item.name);
    _brandController = TextEditingController(text: item.brand ?? '');
    _primaryColorController = TextEditingController(
      text: item.primaryColor ?? '',
    );
    _secondaryColorController = TextEditingController(
      text: item.secondaryColor ?? '',
    );
    _seasonController = TextEditingController(text: item.season ?? '');
    _occasionController = TextEditingController(text: item.occasion ?? '');

    _favorite = item.favorite;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = WardrobeUpdateRequest(
      name: _nameController.text.trim(),
      brand: _brandController.text.trim(),
      primaryColor: _primaryColorController.text.trim(),
      secondaryColor: _secondaryColorController.text.trim(),
      season: _seasonController.text.trim(),
      occasion: _occasionController.text.trim(),
      favorite: _favorite,
    );

    final success = await ref
        .read(wardrobeControllerProvider.notifier)
        .updateItem(
          profileId: widget.profileId,
          itemId: widget.item.id,
          request: request,
        );

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);

    final saving = state.status == WardrobeStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                child: Text(widget.item.category.name),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
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
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _primaryColorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Primary color',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secondaryColorController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Secondary color',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _seasonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _occasionController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Occasion',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Favorite'),
                subtitle: const Text('Keep this item in your favorites.'),
                value: _favorite,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          _favorite = value;
                        });
                      },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
