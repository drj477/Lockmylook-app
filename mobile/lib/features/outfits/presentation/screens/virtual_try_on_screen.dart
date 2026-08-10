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

class VirtualTryOnScreen extends ConsumerStatefulWidget {
  const VirtualTryOnScreen({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends ConsumerState<VirtualTryOnScreen> {
  final List<WardrobeItem> _selectedItems = [];

  Profile? _profile;
  String _category = 'All';
  bool _sidebarOpen = false;
  bool _tryingOn = false;
  bool _generating = false;
  String _occasion = 'casual';
  String? _season;
  String? _mood;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    await ref.read(wardrobeControllerProvider.notifier).loadItems(widget.profileId);

    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile(widget.profileId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // The wardrobe can still be browsed if the profile request fails.
    }
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

  void _clearSelection() => setState(() => _selectedItems.clear());

  Future<void> _tryOn() async {
    if (_selectedItems.isEmpty) {
      _message('Select at least one wardrobe item first.');
      return;
    }

    if ((_profile?.avatarUrl ?? '').trim().isEmpty) {
      _message('Add a profile image before using Virtual Try-On.');
      return;
    }

    final missingImages = _selectedItems.where((item) => item.images.isEmpty).toList();
    if (missingImages.isNotEmpty) {
      _message('Every selected wardrobe item needs an image before try-on.');
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
      _message(_cleanError(error));
    }
  }

  String _cleanError(Object error) {
    final message = error.toString();
    if (message.contains('REPLICATE_API_TOKEN')) {
      return 'Virtual Try-On is not configured on the backend yet.';
    }
    if (message.contains('profile image')) {
      return 'Add a profile image before using Virtual Try-On.';
    }
    if (message.contains('wardrobe item')) {
      return message;
    }
    return 'Virtual Try-On could not be completed. Please try again.';
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showProcessingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 18),
            Text(
              'Creating your try-on',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 7),
            Text(
              'Applying your selected wardrobe pieces to your VTO profile asset.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LockMyLookUi.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWardrobe() async {
    final items = ref.read(wardrobeControllerProvider).items;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final categories = <String>{
            'All',
            ...items.map((item) => item.category.name),
          }.toList();
          final filtered = _category == 'All'
              ? items
              : items.where((item) => item.category.name == _category).toList();

          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Wardrobe',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
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
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final category = categories[index];
                      return ChoiceChip(
                        label: Text(category == 'All' ? 'All' : _categoryLabel(category)),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() => _category = category);
                          setSheetState(() {});
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: .78,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final selected = _selectedItems.any((value) => value.id == item.id);

                      return InkWell(
                        onTap: () {
                          _toggleItem(item);
                          setSheetState(() {});
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? LockMyLookUi.coral : LockMyLookUi.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _itemImage(item, thumbnail: true)),
                                      const SizedBox(height: 5),
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  top: 7,
                                  right: 7,
                                  child: CircleAvatar(
                                    radius: 11,
                                    backgroundColor: LockMyLookUi.coral,
                                    child: Icon(Icons.check, size: 14, color: Colors.white),
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
      ),
    );
  }

  Future<void> _showAiStylist() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
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
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'party', child: Text('Party')),
                  DropdownMenuItem(value: 'date', child: Text('Dinner Date')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => _occasion = value);
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
                onChanged: (value) => setSheetState(() => _season = value),
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
                onChanged: (value) => setSheetState(() => _mood = value),
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
        ),
      ),
    );
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
      setState(() => _generating = false);
      await _showSuggestions(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      _message('Could not generate looks: $error');
    }
  }

  Future<void> _showSuggestions(OutfitGenerateResponse generated) async {
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
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                leading: CircleAvatar(child: Text('${index + 1}')),
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
                  Navigator.pop(sheetContext);
                },
              );
            },
          ),
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
                Expanded(child: _workspace()),
              ],
            ),
            if (_selectedItems.isNotEmpty && !_sidebarOpen) _collapsedTab(),
            _sidebar(),
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
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: _showAiStylist,
            icon: const Icon(Icons.auto_awesome, color: LockMyLookUi.coral),
          ),
        ],
      ),
    );
  }

  Widget _workspace() {
    // VTO must use the dedicated transparent asset, never the original profile photo.
    final imageUrl = _profile?.vtoAssetUrl?.trim().isNotEmpty == true
        ? _profile!.vtoAssetUrl
        : _profile?.avatarUrl;

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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: LockMyLookUi.coralSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: LockMyLookUi.coral),
                              SizedBox(width: 5),
                              Text(
                                'Virtual Try-On',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
                        color: const Color(0xFFF1F2F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageUrl != null && imageUrl.trim().isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  errorBuilder: (_, _, _) => _placeholder(),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: _status(),
                                ),
                              ],
                            )
                          : _placeholder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openWardrobe,
                  icon: const Icon(Icons.checkroom_outlined, size: 18),
                  label: const Text('Wardrobe'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _tryingOn ? null : _tryOn,
                  icon: const Icon(Icons.person_outline),
                  label: Text(_tryingOn ? 'Trying On...' : 'Try On'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_outline, size: 64, color: Color(0xFF7B8492)),
        SizedBox(height: 12),
        Text(
          'Add a profile image to start',
          style: TextStyle(color: LockMyLookUi.muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _status() {
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
            _selectedItems.isEmpty ? Icons.checkroom_outlined : Icons.auto_awesome,
            size: 18,
            color: _selectedItems.isEmpty ? LockMyLookUi.muted : LockMyLookUi.coral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedItems.isEmpty ? 'Select an outfit to try on' : 'Your selected outfit is ready',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsedTab() {
    return Positioned(
      right: 0,
      top: 120,
      child: Material(
        color: Colors.white,
        elevation: 5,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
        child: InkWell(
          onTap: () => setState(() => _sidebarOpen = true),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
          child: Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(18)),
              border: Border.fromBorderSide(BorderSide(color: LockMyLookUi.border)),
            ),
            child: Column(
              children: [
                const Icon(Icons.chevron_left, size: 18),
                const SizedBox(height: 6),
                const Icon(Icons.checkroom_outlined, size: 18, color: LockMyLookUi.coral),
                const SizedBox(height: 5),
                Text('${_selectedItems.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    final width = MediaQuery.sizeOf(context).width * .44;

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
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
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
                      child: Text('Selected Outfit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Text('${_selectedItems.length}', style: const TextStyle(color: LockMyLookUi.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () => setState(() => _sidebarOpen = false),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _selectedItems.isEmpty
                    ? const Center(child: Text('No items selected.', style: TextStyle(color: LockMyLookUi.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                        itemCount: _selectedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = _selectedItems[index];
                          return Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6F7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: LockMyLookUi.coral.withAlpha(170)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(aspectRatio: .82, child: _itemImage(item, thumbnail: false)),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_categoryLabel(item.category.name), style: const TextStyle(fontSize: 9, color: LockMyLookUi.muted)),
                                          const SizedBox(height: 2),
                                          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
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
                        onPressed: _openWardrobe,
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

  Widget _itemImage(WardrobeItem item, {required bool thumbnail}) {
    if (item.images.isEmpty) {
      return LockMyLookUi.imagePlaceholder(label: item.category.name);
    }

    return Image.network(
      thumbnail ? item.images.first.thumbnailUrl : item.images.first.imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => LockMyLookUi.imagePlaceholder(label: item.name),
    );
  }

  String _categoryLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}
