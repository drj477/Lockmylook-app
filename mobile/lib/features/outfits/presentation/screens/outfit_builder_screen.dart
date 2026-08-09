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
      0.17,
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

    final items = state.items;

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
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

  Widget _tryOnPreview() {
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
              child: Stack(
                children: [
                  Center(
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
                          _selectedItems.isEmpty
                              ? 'Select an outfit to try on'
                              : 'Your selected outfit',
                          style: const TextStyle(
                            color: LockMyLookUi.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedOutfit() {
    final selectedCount = _selectedItems.length;

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
              if (selectedCount > 0)
                TextButton(
                  onPressed: _clearSelection,
                  style: TextButton.styleFrom(
                    foregroundColor: LockMyLookUi.coral,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear'),
                ),
              const SizedBox(width: 4),
              Text(
                '$selectedCount ${selectedCount == 1 ? 'piece' : 'pieces'}',
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: LockMyLookUi.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.checkroom_outlined,
                    size: 28,
                    color: LockMyLookUi.muted,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Build your outfit',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LockMyLookUi.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick clothes from Your Wardrobe below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: LockMyLookUi.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (_wardrobeSheetController.isAttached) {
                        await _wardrobeSheetController.animateTo(
                          0.72,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Choose Items'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 2),
                    itemCount: _selectedItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final item = _selectedItems[index];

                      return SizedBox(
                        width: 108,
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
                                    padding: const EdgeInsets.fromLTRB(
                                      7,
                                      5,
                                      7,
                                      6,
                                    ),
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _categoryLabel(
                                            item.category.name,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: LockMyLookUi.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 1,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (_wardrobeSheetController.isAttached) {
                            await _wardrobeSheetController.animateTo(
                              0.72,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add More'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _selectedItems.isEmpty ? null : _tryOnOutfit,
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Try On'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _wardrobeSheet(List<WardrobeItem> items) {
    final categories = <String>{
      'All',
      ...items.map((item) => item.category.name),
    }.toList();

    final filteredItems = _category == 'All'
        ? items
        : items
            .where((item) => item.category.name == _category)
            .toList();

    return DraggableScrollableSheet(
      controller: _wardrobeSheetController,
      initialChildSize: 0.17,
      minChildSize: 0.17,
      maxChildSize: 0.72,
      snap: true,
      snapAnimationDuration: const Duration(milliseconds: 280),
      snapSizes: const [0.17, 0.72],
      expand: true,
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          elevation: 16,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (!_wardrobeSheetController.isAttached) {
                    return;
                  }

                  final screenHeight = MediaQuery.sizeOf(context).height;
                  final nextSize = _wardrobeSheetController.size -
                      (details.primaryDelta ?? 0) / screenHeight;

                  _wardrobeSheetController.jumpTo(
                    nextSize.clamp(0.17, 0.72),
                  );
                },
                onVerticalDragEnd: (details) {
                  if (!_wardrobeSheetController.isAttached) {
                    return;
                  }

                  final velocity = details.primaryVelocity ?? 0;
                  final current = _wardrobeSheetController.size;

                  final target = velocity < -350
                      ? 0.72
                      : velocity > 350
                          ? 0.17
                          : current >= 0.45
                              ? 0.72
                              : 0.17;

                  _wardrobeSheetController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                  child: Column(
                    children: [
                      Row(
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
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          if (!_wardrobeSheetController.isAttached) {
                            return;
                          }

                          _wardrobeSheetController.animateTo(
                            _wardrobeSheetController.size >= 0.45
                                ? 0.17
                                : 0.72,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5D8DD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 82,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFB),
                          border: Border(
                            right: BorderSide(
                              color: LockMyLookUi.border,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            top: 6,
                            bottom: 24,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final selected = _category == category;
                            final categorySelectionCount = category == 'All'
                                ? _selectedItems.length
                                : _selectedItems
                                    .where(
                                      (item) =>
                                          item.category.name == category,
                                    )
                                    .length;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _category = category;
                                });
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: selected
                                          ? LockMyLookUi.coral
                                          : Colors.transparent,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFFFFE7E4)
                                            : const Color(0xFFF1F2F4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _categoryIcon(category),
                                        size: 23,
                                        color: selected
                                            ? LockMyLookUi.coral
                                            : const Color(0xFF7D8490),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            category == 'All'
                                                ? 'All'
                                                : _categoryLabel(category),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.15,
                                              fontWeight: selected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: selected
                                                  ? LockMyLookUi.coral
                                                  : LockMyLookUi.ink,
                                            ),
                                          ),
                                        ),
                                        if (categorySelectionCount > 0)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 3),
                                            child: Container(
                                              constraints:
                                                  const BoxConstraints(
                                                minWidth: 15,
                                                minHeight: 15,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: LockMyLookUi.coral,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$categorySelectionCount',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (_error != null)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 4, 10, 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _error!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: LockMyLookUi.coral,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          if (_generating)
                            const LinearProgressIndicator(minHeight: 3),
                          Expanded(
                            child: filteredItems.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'No items in this category.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: LockMyLookUi.muted,
                                        ),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    controller: scrollController,
                                    physics:
                                        const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      12,
                                      28,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.76,
                                    ),
                                    itemCount: filteredItems.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      final selected = _selectedItems.any(
                                        (selectedItem) =>
                                            selectedItem.id == item.id,
                                      );

                                      return GestureDetector(
                                        onTap: () => _toggleItem(item),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            border: Border.all(
                                              color: selected
                                                  ? LockMyLookUi.coral
                                                  : LockMyLookUi.border,
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        11,
                                                      ),
                                                      child: _itemImage(item),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    _categoryLabel(
                                                      item.category.name,
                                                    ),
                                                    textAlign:
                                                        TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          LockMyLookUi.muted,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    item.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign:
                                                        TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: LockMyLookUi.ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                ],
                                              ),
                                              if (selected)
                                                Positioned(
                                                  top: 5,
                                                  right: 5,
                                                  child: Container(
                                                    width: 23,
                                                    height: 23,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          LockMyLookUi.coral,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 15,
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
                        ],
                      ),
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

  String _categoryLabel(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.auto_awesome;
      case 'tops':
      case 'top':
        return Icons.checkroom_outlined;
      case 'bottoms':
      case 'bottom':
        return Icons.straighten_outlined;
      case 'shoes':
      case 'footwear':
        return Icons.directions_walk_outlined;
      case 'accessories':
      case 'accessory':
        return Icons.watch_outlined;
      case 'outerwear':
      case 'jackets':
      case 'jacket':
        return Icons.layers_outlined;
      case 'dresses':
      case 'dress':
        return Icons.dry_cleaning_outlined;
      default:
        return Icons.checkroom_outlined;
    }
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
