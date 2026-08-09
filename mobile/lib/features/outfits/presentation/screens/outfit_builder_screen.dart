import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/outfits/application/outfit_providers.dart';
import 'package:mobile/features/outfits/data/models/outfit_models.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class OutfitBuilderScreen extends ConsumerStatefulWidget {
  const OutfitBuilderScreen({required this.profileId, super.key});
  final String profileId;
  @override
  ConsumerState<OutfitBuilderScreen> createState() =>
      _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends ConsumerState<OutfitBuilderScreen> {
  final List<WardrobeItem> _selectedItems = [];
  String _occasion = 'casual';
  String? _season;
  String? _mood;
  String _category = 'All';
  OutfitGenerateResponse? _generated;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(wardrobeControllerProvider.notifier)
          .loadItems(widget.profileId),
    );
  }

  void _toggleItem(WardrobeItem item) {
    setState(() {
      final index = _selectedItems.indexWhere(
        (selected) => selected.id == item.id,
      );
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
<<<<<<< Updated upstream
      final result = await ref.read(outfitRepositoryProvider).generateOutfits(profileId: widget.profileId, request: OutfitGenerateRequest(occasion: _occasion, season: _season, mood: _mood));
      if (!mounted) {
        return;
      }
=======
      final result = await ref
          .read(outfitRepositoryProvider)
          .generateOutfits(
            profileId: widget.profileId,
            request: OutfitGenerateRequest(
              occasion: _occasion,
              season: _season,
              mood: _mood,
            ),
          );
      if (!mounted) return;
>>>>>>> Stashed changes
      setState(() {
        _generated = result;
        _generating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    setState(
      () => _selectedItems
        ..clear()
        ..addAll(selected),
    );
  }

  void _showGenerator() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Style with AI',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: LockMyLookUi.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tell us the vibe and we will build looks from your wardrobe.',
                style: TextStyle(color: LockMyLookUi.muted),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _occasion,
                decoration: const InputDecoration(labelText: 'Occasion'),
<<<<<<< Updated upstream
                items: const [DropdownMenuItem(value: 'casual', child: Text('Casual')), DropdownMenuItem(value: 'work', child: Text('Work')), DropdownMenuItem(value: 'party', child: Text('Party')), DropdownMenuItem(value: 'date', child: Text('Dinner Date'))],
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => _occasion = value);
                  }
=======
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'party', child: Text('Party')),
                  DropdownMenuItem(value: 'date', child: Text('Dinner Date')),
                ],
                onChanged: (value) {
                  if (value != null) setModalState(() => _occasion = value);
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
              FilledButton.icon(onPressed: _generating ? null : () async { Navigator.pop(context); await _generate(); if (mounted && _generated != null) { await _showSuggestions(); } }, icon: const Icon(Icons.auto_awesome), label: const Text('Generate 5 Looks')),
=======
              FilledButton.icon(
                onPressed: _generating
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _generate();
                        if (mounted && _generated != null)
                          await _showSuggestions();
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate 5 Looks'),
              ),
>>>>>>> Stashed changes
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuggestions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        final suggestions = _generated!.suggestions;
<<<<<<< Updated upstream
        if (suggestions.isEmpty) {
          return const SafeArea(child: Padding(padding: EdgeInsets.all(24), child: Text('No matching outfits were found.')));
        }
=======
        if (suggestions.isEmpty)
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching outfits were found.'),
            ),
          );
>>>>>>> Stashed changes
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final suggestion = suggestions[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: LockMyLookUi.cardDecoration(),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: LockMyLookUi.coralSoft,
                    foregroundColor: LockMyLookUi.coral,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    'Look ${index + 1} · ${suggestion.score.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    suggestion.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                  onTap: () {
                    _applySuggestion(suggestion);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);
<<<<<<< Updated upstream
    final categories = <String>{'All', ...state.items.map((item) => item.category.name)}.toList();
    final items = state.items.where((item) => _category == 'All' || item.category.name == _category).toList();
=======
    final categories = <String>{
      'All',
      ...state.items.map((item) => item.category.name),
    }.toList();
    final items = state.items
        .where((item) => _category == 'All' || item.category.name == _category)
        .toList();

>>>>>>> Stashed changes
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Outfit',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: LockMyLookUi.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showGenerator,
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: LockMyLookUi.coral,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => GestureDetector(
                  onTap: () => setState(() => _category = categories[index]),
                  child: LockMyLookUi.pill(
                    categories[index],
                    selected: _category == categories[index],
                  ),
                ),
              ),
            ),
            Expanded(child: _canvas(items)),
            _selectionTray(state.items),
          ],
        ),
      ),
    );
  }

  Widget _canvas(List<WardrobeItem> items) {
    if (_selectedItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: LockMyLookUi.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: const BoxDecoration(
                color: LockMyLookUi.coralSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.style_outlined,
                size: 60,
                color: LockMyLookUi.coral,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Build your look',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: LockMyLookUi.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pick pieces from your wardrobe below, or let AI create a complete outfit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LockMyLookUi.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showGenerator,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Style with AI'),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LockMyLookUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Your Look',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: LockMyLookUi.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              itemCount: _selectedItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .88,
              ),
              itemBuilder: (_, index) {
                final item = _selectedItems[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox.expand(child: _itemImage(item)),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => _toggleItem(item),
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, size: 16),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(235),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedItems.clear()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showGenerator,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Improve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectionTray(List<WardrobeItem> items) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Color(0x14000000),
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wardrobe · ${_selectedItems.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ),
              if (_error != null)
                const Icon(Icons.error_outline, color: LockMyLookUi.coral),
              TextButton(
                onPressed: _showGenerator,
                child: const Text('AI Suggest'),
              ),
            ],
          ),
          if (_generating) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 8),
          SizedBox(
            height: 86,
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Add wardrobe items first.',
                      style: TextStyle(color: LockMyLookUi.muted),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final selected = _selectedItems.any(
                        (x) => x.id == item.id,
                      );
                      return GestureDetector(
                        onTap: () => _toggleItem(item),
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox.expand(
                                        child: _itemImage(item),
                                      ),
                                    ),
                                    if (selected)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          width: 21,
                                          height: 21,
                                          decoration: const BoxDecoration(
                                            color: LockMyLookUi.coral,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _itemImage(WardrobeItem item) {
<<<<<<< Updated upstream
    if (item.images.isEmpty) {
      return LockMyLookUi.imagePlaceholder(label: item.category.name);
    }
    return Image.network(item.images.first.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => LockMyLookUi.imagePlaceholder(label: item.category.name));
=======
    if (item.images.isEmpty)
      return LockMyLookUi.imagePlaceholder(label: item.category.name);
    return Image.network(
      item.images.first.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          LockMyLookUi.imagePlaceholder(label: item.category.name),
    );
>>>>>>> Stashed changes
  }
}
