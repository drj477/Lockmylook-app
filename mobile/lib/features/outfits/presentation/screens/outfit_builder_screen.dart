import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/outfits/application/outfit_providers.dart';
import 'package:mobile/features/outfits/data/models/outfit_models.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  final List<WardrobeItem> _selectedItems = [];
  String _occasion = 'casual';
  String? _season;
  String? _mood;
  OutfitGenerateResponse? _generated;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wardrobeControllerProvider.notifier).loadItems(widget.profileId);
    });
  }

  void _toggleItem(WardrobeItem item) {
    setState(() {
      final index = _selectedItems.indexWhere((selected) => selected.id == item.id);
      if (index >= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final result = await ref.read(outfitRepositoryProvider).generateOutfits(
            profileId: widget.profileId,
            request: OutfitGenerateRequest(
              occasion: _occasion,
              season: _season,
              mood: _mood,
            ),
          );

      if (!mounted) return;
      setState(() {
        _generated = result;
        _generating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = error.toString();
      });
    }
  }

  void _applySuggestion(OutfitSuggestion suggestion) {
    final wardrobe = ref.read(wardrobeControllerProvider).items;
    final selected = <WardrobeItem>[];

    for (final generatedItem in suggestion.items) {
      for (final item in wardrobe) {
        if (item.id == generatedItem.id) {
          selected.add(item);
          break;
        }
      }
    }

    setState(() {
      _selectedItems
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardrobeState = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Outfit Builder')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCanvas()),
            _buildBottomSheetPreview(wardrobeState),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    if (_selectedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Build an outfit by selecting items below, or generate a suggestion.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .85,
      ),
      itemCount: _selectedItems.length,
      itemBuilder: (context, index) {
        final item = _selectedItems[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _itemImage(item)),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetPreview(WardrobeState state) {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Wardrobe (${_selectedItems.length} selected)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _generating ? null : _showGenerator,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate'),
                  ),
                ],
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (state.status == WardrobeStatus.loading && state.items.isEmpty)
                const LinearProgressIndicator()
              else if (state.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No wardrobe items available.'),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final selected = _selectedItems.any((x) => x.id == item.id);
                      return _selectorItem(item, selected);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorItem(WardrobeItem item, bool selected) {
    return GestureDetector(
      onTap: () => _toggleItem(item),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(child: _itemImage(item)),
                  ),
                  if (selected)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: CircleAvatar(
                        radius: 11,
                        child: Icon(Icons.check, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _itemImage(WardrobeItem item) {
    if (item.images.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFEDEDED),
        child: Center(child: Icon(Icons.checkroom_outlined)),
      );
    }

    return Image.network(
      item.images.first.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFEDEDED),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }

  Future<void> _showGenerator() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Generate an Outfit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _occasion,
                  decoration: const InputDecoration(labelText: 'Occasion'),
                  items: const [
                    DropdownMenuItem(value: 'casual', child: Text('Casual')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                    DropdownMenuItem(value: 'party', child: Text('Party')),
                    DropdownMenuItem(value: 'date', child: Text('Date')),
                  ],
                  onChanged: (value) {
                    if (value != null) setModalState(() => _occasion = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _season,
                  decoration: const InputDecoration(labelText: 'Season'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any season')),
                    DropdownMenuItem(value: 'summer', child: Text('Summer')),
                    DropdownMenuItem(value: 'winter', child: Text('Winter')),
                    DropdownMenuItem(value: 'spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'autumn', child: Text('Autumn')),
                  ],
                  onChanged: (value) => setModalState(() => _season = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _mood,
                  decoration: const InputDecoration(labelText: 'Mood'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any mood')),
                    DropdownMenuItem(value: 'minimal', child: Text('Minimal')),
                    DropdownMenuItem(value: 'smart', child: Text('Smart')),
                    DropdownMenuItem(value: 'bold', child: Text('Bold')),
                  ],
                  onChanged: (value) => setModalState(() => _mood = value),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _generating
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _generate();
                        },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Outfits'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted || _generated == null) return;
    await _showSuggestions();
  }

  Future<void> _showSuggestions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (_generated!.suggestions.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching outfits were found.'),
            ),
          );
        }

        return SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _generated!.suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _generated!.suggestions[index];
              return Card(
                child: ListTile(
                  title: Text(
                    'Outfit ${index + 1} · ${suggestion.score.toStringAsFixed(0)}%',
                  ),
                  subtitle: Text(suggestion.reason),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _applySuggestion(suggestion);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
