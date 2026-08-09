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
  final DraggableScrollableController _wardrobeSheetController =
      DraggableScrollableController();

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

  @override
  void dispose() {
    _wardrobeSheetController.dispose();
    super.dispose();
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

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
    });
  }

  Future<void> _collapseWardrobe() async {
    if (!_wardrobeSheetController.isAttached) {
      return;
    }

    await _wardrobeSheetController.animateTo(
      0.19,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _tryOnOutfit() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one wardrobe item first.'),
        ),
      );
      return;
    }

    // The actual virtual try-on service will be connected separately.
    // This keeps the interaction ready without pretending an AI result exists.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your outfit is ready for Virtual Try-On.'),
      ),
    );
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

      if (!mounted) {
        return;
      }

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

    setState(() {
      _selectedItems
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _showGenerator() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
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
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'party', child: Text('Party')),
                  DropdownMenuItem(value: 'date', child: Text('Dinner Date')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => _occasion = value);
                  }
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
                  DropdownMenuItem(
                    value: 'minimal',
                    child: Text('Minimal'),
                  ),
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
                        Navigator.pop(sheetContext);
                        await _generate();

                        if (mounted && _generated != null) {
                          await _showSuggestions();
                        }
                      },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate 5 Looks'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuggestions() async {
    final generated = _generated;

    if (generated == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        final suggestions = generated.suggestions;

        if (suggestions.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching outfits were found.'),
            ),
          );
        }

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
                    'Look ${index + 1} · '
                    '${suggestion.score.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    suggestion.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                  ),
                  onTap: () {
                    _applySuggestion(suggestion);
                    Navigator.pop(sheetContext);
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

    final categories = <String>{
      'All',
      ...state.items.map((item) => item.category.name),
    }.toList();

    final items = state.items
        .where(
          (item) =>
              _category == 'All' || item.category.name == _category,
        )
        .toList();

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                _categoryBar(categories),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
                    children: [
                      _tryOnPreview(),
                      const SizedBox(height: 12),
                      _selectedOutfit(),
                    ],
                  ),
                ),
              ],
            ),
            _wardrobeSheet(items),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: Text(
              'Virtual Try-On',
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
    );
  }

  Widget _categoryBar(List<String> categories) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 6,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = categories[index];

          return GestureDetector(
            onTap: () => setState(() => _category = category),
            child: LockMyLookUi.pill(
              category,
              selected: _category == category,
            ),
          );
        },
      ),
    );
  }

  Widget _tryOnPreview() {
    final hasSelection = _selectedItems.isNotEmpty;

    return Container(
      height: 345,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LockMyLookUi.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LockMyLookUi.coralSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: LockMyLookUi.coral,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Virtual Try-On',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LockMyLookUi.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedItems.length} pieces',
                  style: const TextStyle(
                    color: LockMyLookUi.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 44,
                        color: Color(0xFF7B8492),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.checkroom_outlined,
                      size: 92,
                      color: Color(0xFFD6D9DE),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasSelection
                          ? 'Your selected outfit is ready'
                          : 'Select an outfit to try on',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: LockMyLookUi.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasSelection
                          ? 'Use Try On below your selected pieces.'
                          : 'Choose pieces from your wardrobe below.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: LockMyLookUi.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedOutfit() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LockMyLookUi.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Outfit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ),
              Text(
                '${_selectedItems.length} pieces',
                style: const TextStyle(
                  color: LockMyLookUi.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Select pieces from Your Wardrobe below.',
                style: TextStyle(color: LockMyLookUi.muted),
              ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedItems.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = _selectedItems[index];

                  return SizedBox(
                    width: 105,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2F4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: LockMyLookUi.coral.withAlpha(180),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: _itemImage(item),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 6,
                                ),
                                color: Colors.white,
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () => _toggleItem(item),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.close, size: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedItems.isEmpty
                      ? null
                      : _clearSelection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Start Over'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedItems.isEmpty ? null : _tryOnOutfit,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Try On'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wardrobeSheet(List<WardrobeItem> items) {
    return DraggableScrollableSheet(
      controller: _wardrobeSheetController,
      initialChildSize: 0.19,
      minChildSize: 0.19,
      maxChildSize: 0.62,
      snap: true,
      snapSizes: const [0.19, 0.62],
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          elevation: 14,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _collapseWardrobe,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Your Wardrobe',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: LockMyLookUi.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${items.length} items',
                      style: const TextStyle(
                        color: LockMyLookUi.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5D8DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Add wardrobe items first.',
                          style: TextStyle(color: LockMyLookUi.muted),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: LockMyLookUi.coral,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (_generating)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: LinearProgressIndicator(minHeight: 3),
                            ),
                          SizedBox(
                            height: 118,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, index) {
                                final item = items[index];
                                final selected = _selectedItems.any(
                                  (selectedItem) =>
                                      selectedItem.id == item.id,
                                );

                                return GestureDetector(
                                  onTap: () => _toggleItem(item),
                                  child: SizedBox(
                                    width: 96,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F2F4),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: selected
                                                  ? LockMyLookUi.coral
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: _itemImage(item),
                                              ),
                                              Container(
                                                width: double.infinity,
                                                color: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 6,
                                                ),
                                                child: Text(
                                                  item.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          Positioned(
                                            right: 6,
                                            top: 6,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration:
                                                  const BoxDecoration(
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
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _selectedItems.isEmpty
                                ? null
                                : _tryOnOutfit,
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Try On Selected Outfit'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showGenerator,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Style with AI'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _itemImage(WardrobeItem item) {
    if (item.images.isEmpty) {
      return LockMyLookUi.imagePlaceholder(
        label: item.category.name,
      );
    }

    return Image.network(
      item.images.first.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => LockMyLookUi.imagePlaceholder(
        label: item.category.name,
      ),
    );
  }
}
