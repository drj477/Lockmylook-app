import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/outfits/application/outfit_providers.dart';
import 'package:mobile/features/outfits/application/virtual_try_on_providers.dart';
import 'package:mobile/features/outfits/data/models/outfit_models.dart';
import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';
import 'package:mobile/features/outfits/presentation/screens/virtual_try_on_result_screen.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';
import 'package:mobile/features/profiles/data/models/profile_models.dart';
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

  String _category = 'All';
  Profile? _profile;
  bool _tryingOn = false;
  bool _sidebarOpen = false;

  String _occasion = 'casual';
  String? _season;
  String? _mood;
  OutfitGenerateResponse? _generated;
  bool _generating = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await ref
          .read(wardrobeControllerProvider.notifier)
          .loadItems(widget.profileId);

      try {
        final profile = await ref
            .read(profileRepositoryProvider)
            .getProfile(widget.profileId);

        if (mounted) {
          setState(() => _profile = profile);
        }
      } catch (_) {
        // The wardrobe remains usable if profile loading fails.
      }
    });
  }

  void _toggleItem(WardrobeItem item) {
    setState(() {
      final index =
          _selectedItems.indexWhere((selected) => selected.id == item.id);

      if (index >= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedItems.clear());
  }

  Future<void> _tryOnOutfit() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one wardrobe item first.'),
        ),
      );
      return;
    }

    if (_profile?.vtoAssetUrl == null || _profile!.vtoAssetUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a profile image first. Virtual Try-On needs the processed VTO image.',
          ),
        ),
      );
      return;
    }

    if (_selectedItems.any((item) => item.images.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Every selected wardrobe item needs an image before try-on.',
          ),
        ),
      );
      return;
    }

    setState(() => _tryingOn = true);
    _showProcessingDialog();

    try {
      final result = await ref.read(virtualTryOnRepositoryProvider).generate(
            profileId: widget.profileId,
            request: VirtualTryOnRequest(
              itemIds: _selectedItems.map((item) => item.id).toList(),
            ),
          );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _tryingOn = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VirtualTryOnResultScreen(
            profileId: widget.profileId,
            result: result,
            selectedItems: List.unmodifiable(_selectedItems),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _tryingOn = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showProcessingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          contentPadding: EdgeInsets.fromLTRB(24, 24, 24, 22),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 20),
              Text(
                'Creating your try-on',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'We are putting your selected wardrobe pieces on your profile image.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: LockMyLookUi.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.contains('REPLICATE_API_TOKEN')) {
      return 'Virtual Try-On is not configured on the backend yet.';
    }

    if (message.contains('profile image')) {
      return 'Add a profile image before using Virtual Try-On.';
    }

    return 'Virtual Try-On could not be completed. Please try again.';
  }

  Future<void> _generateLooks() async {
    setState(() => _generating = true);

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

      await _showSuggestions();
    } catch (error) {
      if (!mounted) return;

      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate looks: $error')),
      );
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
        builder: (context, setModalState) {
          return Padding(
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
                  'Build a look from the wardrobe you already own.',
                  style: TextStyle(color: LockMyLookUi.muted),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _occasion,
                  decoration: const InputDecoration(labelText: 'Occasion'),
                  items: const [
                    DropdownMenuItem(
                      value: 'casual',
                      child: Text('Casual'),
                    ),
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
                          await _generateLooks();
                        },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate 5 Looks'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSuggestions() async {
    final generated = _generated;
    if (generated == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        if (generated.suggestions.isEmpty) {
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
            itemCount: generated.suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final suggestion = generated.suggestions[index];

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

  Future<void> _openWardrobePicker() async {
    final items = ref.read(wardrobeControllerProvider).items;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = <String>{
              'All',
              ...items.map((item) => item.category.name),
            }.toList();

            final filtered = _category == 'All'
                ? items
                : items
                    .where((item) => item.category.name == _category)
                    .toList();

            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .78,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your Wardrobe',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: LockMyLookUi.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${_selectedItems.length} selected',
                          style: const TextStyle(
                            color: LockMyLookUi.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final category = categories[index];
                        final selected = _category == category;
                        final count = category == 'All'
                            ? _selectedItems.length
                            : _selectedItems
                                .where(
                                  (item) =>
                                      item.category.name == category,
                                )
                                .length;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _category = category);
                            setModalState(() {});
                          },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 72),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? LockMyLookUi.coralSoft
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? LockMyLookUi.coral.withAlpha(90)
                                    : LockMyLookUi.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcon(category),
                                  size: 18,
                                  color: selected
                                      ? LockMyLookUi.coral
                                      : LockMyLookUi.muted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  category == 'All'
                                      ? 'All'
                                      : _categoryLabel(category),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? LockMyLookUi.coral
                                        : LockMyLookUi.ink,
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: LockMyLookUi.coral,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: .76,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        final isSelected = _selectedItems.any(
                          (selected) => selected.id == item.id,
                        );

                        return GestureDetector(
                          onTap: () {
                            _toggleItem(item);
                            setModalState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? LockMyLookUi.coral
                                    : LockMyLookUi.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: _itemImage(
                                            item,
                                            thumbnail: true,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Positioned(
                                    top: 7,
                                    right: 7,
                                    child: CircleAvatar(
                                      radius: 11,
                                      backgroundColor: LockMyLookUi.coral,
                                      child: Icon(
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                Expanded(child: _tryOnWorkspace()),
              ],
            ),
            _selectedOutfitSidebar(),
            if (_selectedItems.isNotEmpty && !_sidebarOpen)
              _collapsedSidebarTab(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
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

  Widget _tryOnWorkspace() {
    final vtoAssetUrl = _profile?.vtoAssetUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: LockMyLookUi.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: vtoAssetUrl != null &&
                              vtoAssetUrl.trim().isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  vtoAssetUrl,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, _, _) =>
                                      _profilePlaceholder(),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: _previewStatus(),
                                ),
                              ],
                            )
                          : _profilePlaceholder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _actionBar(),
        ],
      ),
    );
  }

  Widget _profilePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 46,
            color: Color(0xFF7B8492),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Add a profile image to start',
          style: TextStyle(
            color: LockMyLookUi.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _previewStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LockMyLookUi.border),
      ),
      child: Row(
        children: [
          Icon(
            _selectedItems.isEmpty
                ? Icons.checkroom_outlined
                : Icons.auto_awesome,
            size: 18,
            color: _selectedItems.isEmpty
                ? LockMyLookUi.muted
                : LockMyLookUi.coral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedItems.isEmpty
                  ? 'Select an outfit to try on'
                  : 'Your selected outfit is ready',
              style: const TextStyle(
                color: LockMyLookUi.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openWardrobePicker,
            icon: const Icon(Icons.checkroom_outlined, size: 18),
            label: const Text('Wardrobe'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _tryingOn ? null : _tryOnOutfit,
            icon: const Icon(Icons.person_outline),
            label: Text(_tryingOn ? 'Trying On...' : 'Try On'),
          ),
        ),
      ],
    );
  }

  Widget _collapsedSidebarTab() {
    return Positioned(
      right: 0,
      top: 120,
      child: Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(18),
        ),
        child: InkWell(
          onTap: () => setState(() => _sidebarOpen = true),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(18),
          ),
          child: Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              border: Border.all(color: LockMyLookUi.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: LockMyLookUi.ink,
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.checkroom_outlined,
                  size: 18,
                  color: LockMyLookUi.coral,
                ),
                const SizedBox(height: 5),
                Text(
                  '${_selectedItems.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedOutfitSidebar() {
    final width = MediaQuery.sizeOf(context).width * .46;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      top: 0,
      bottom: 0,
      right: _sidebarOpen ? 0 : -width - 8,
      width: width,
      child: Material(
        elevation: 12,
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Selected Outfit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LockMyLookUi.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${_selectedItems.length}',
                      style: const TextStyle(
                        color: LockMyLookUi.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _sidebarOpen = false),
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Collapse',
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5D9DE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _selectedItems.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'No items selected.\nOpen Wardrobe to add pieces.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: LockMyLookUi.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                        itemCount: _selectedItems.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = _selectedItems[index];

                          return Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6F7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: LockMyLookUi.coral.withAlpha(170),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: .82,
                                      child: _itemImage(
                                        item,
                                        thumbnail: false,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        7,
                                        8,
                                        9,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _categoryLabel(
                                              item.category.name,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: LockMyLookUi.muted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
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
                                  elevation: 2,
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
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.clear_all, size: 17),
                        label: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openWardrobePicker,
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add More'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemImage(
    WardrobeItem item, {
    required bool thumbnail,
  }) {
    if (item.images.isNotEmpty) {
      return Image.network(
        thumbnail
            ? item.images.first.thumbnailUrl
            : item.images.first.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            LockMyLookUi.imagePlaceholder(label: item.name),
      );
    }

    return LockMyLookUi.imagePlaceholder(label: item.category.name);
  }

  String _categoryLabel(String value) {
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
    final value = category.toLowerCase();

    if (value == 'all') return Icons.auto_awesome;
    if (value.contains('top') ||
        value.contains('shirt') ||
        value.contains('blouse')) {
      return Icons.checkroom;
    }
    if (value.contains('bottom') ||
        value.contains('pant') ||
        value.contains('jean') ||
        value.contains('skirt') ||
        value.contains('short')) {
      return Icons.dry_cleaning_outlined;
    }
    if (value.contains('shoe') ||
        value.contains('foot') ||
        value.contains('sneaker') ||
        value.contains('boot')) {
      return Icons.sports_soccer_outlined;
    }
    if (value.contains('access')) return Icons.watch_outlined;
    if (value.contains('outer') ||
        value.contains('jacket') ||
        value.contains('coat')) {
      return Icons.layers_outlined;
    }

    return Icons.checkroom_outlined;
  }
}
