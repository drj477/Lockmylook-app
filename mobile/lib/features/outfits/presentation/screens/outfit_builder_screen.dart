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
  final DraggableScrollableController _wardrobeSheetController =
      DraggableScrollableController();

  String _category = 'All';
  Profile? _profile;
  bool _tryingOn = false;

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

  @override
  void dispose() {
    _wardrobeSheetController.dispose();
    super.dispose();
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

  Future<void> _openWardrobe() async {
    if (!_wardrobeSheetController.isAttached) return;

    await _wardrobeSheetController.animateTo(
      0.72,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _collapseWardrobe() async {
    if (!_wardrobeSheetController.isAttached) return;

    await _wardrobeSheetController.animateTo(
      0.17,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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

    if (_profile?.avatarUrl == null || _profile!.avatarUrl!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a profile image first. Virtual Try-On uses your profile image.',
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
    final avatarUrl = _profile?.avatarUrl;

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
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(.16),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
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
                          child: avatarUrl != null &&
                                  avatarUrl.trim().isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_outline,
                                      size: 44,
                                      color: Color(0xFF7B8492),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person_outline,
                                  size: 44,
                                  color: Color(0xFF7B8492),
                                ),
                        ),
                        const SizedBox(height: 10),
                        const Icon(
                          Icons.checkroom_outlined,
                          size: 84,
                          color: Color(0xFFD6D9DE),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedItems.isEmpty
                              ? 'Select an outfit to try on'
                              : 'Your selected outfit is ready',
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
                border: Border.all(color: LockMyLookUi.border),
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
                    onPressed: _openWardrobe,
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
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                                  Expanded(child: _itemImage(item)),
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
                                          _categoryLabel(item.category.name),
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
                        onPressed: _openWardrobe,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add More'),
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
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _wardrobeSheet(List<WardrobeItem> allItems) {
    final categories = <String>{
      'All',
      ...allItems.map((item) => item.category.name),
    }.toList();

    final filtered = _category == 'All'
        ? allItems
        : allItems
            .where((item) => item.category.name == _category)
            .toList();

    return DraggableScrollableSheet(
      controller: _wardrobeSheetController,
      initialChildSize: 0.17,
      minChildSize: 0.17,
      maxChildSize: 0.72,
      snap: true,
      snapSizes: const [0.17, 0.72],
      builder: (context, scrollController) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            final nextSize = _wardrobeSheetController.size -
                (details.primaryDelta ?? 0) / screenHeight;

            _wardrobeSheetController.jumpTo(
              nextSize.clamp(0.17, 0.72),
            );
          },
          onVerticalDragEnd: (details) async {
            final velocity = details.primaryVelocity ?? 0;
            final current = _wardrobeSheetController.size;

            final target = velocity < -350
                ? 0.72
                : velocity > 350
                    ? 0.17
                    : current >= 0.45
                        ? 0.72
                        : 0.17;

            await _wardrobeSheetController.animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border.all(color: LockMyLookUi.border),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, -4),
                  color: Color(0x18000000),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 5),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _collapseWardrobe,
                        icon: const Icon(Icons.close),
                        tooltip: 'Collapse wardrobe',
                      ),
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
                        '${_selectedItems.length} selected',
                        style: const TextStyle(
                          color: LockMyLookUi.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (!_wardrobeSheetController.isAttached) return;

                    final expanded =
                        _wardrobeSheetController.size >= 0.45;

                    await _wardrobeSheetController.animateTo(
                      expanded ? 0.17 : 0.72,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5D9DE),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 82,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 4, 6, 12),
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 5),
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
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? LockMyLookUi.coralSoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? LockMyLookUi.coral.withAlpha(90)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _categoryIcon(category),
                                      size: 23,
                                      color: selected
                                          ? LockMyLookUi.coral
                                          : LockMyLookUi.muted,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            category == 'All'
                                                ? 'All'
                                                : _categoryLabel(category),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                                        if (count > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 3,
                                            ),
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
                                                '$count',
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
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(6, 4, 12, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9,
                            childAspectRatio: .76,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            final isSelected = _selectedItems.any(
                              (selected) => selected.id == item.id,
                            );

                            return GestureDetector(
                              onTap: () => _toggleItem(item),
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
                                              child: _itemImage(item),
                                            ),
                                            const SizedBox(height: 5),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                                          backgroundColor:
                                              LockMyLookUi.coral,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _itemImage(WardrobeItem item) {
    if (item.images.isNotEmpty) {
      return Image.network(
        item.images.first.thumbnailUrl,
        fit: BoxFit.cover,
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
