import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/constants/api_constants.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_controller.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';
import 'package:mobile/features/wardrobe/presentation/screens/add_wardrobe_item_screen.dart';
import 'package:mobile/features/wardrobe/presentation/screens/edit_wardrobe_item_screen.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({required this.profileId, super.key});
  final String profileId;

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  String _filter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(wardrobeControllerProvider.notifier).loadItems(widget.profileId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(wardrobeControllerProvider.notifier).loadItems(widget.profileId);

  Future<void> _openAddItem() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddWardrobeItemScreen(profileId: widget.profileId)),
    );
    if (mounted && created == true) await _refresh();
  }

  Future<void> _openEditItem(WardrobeItem item) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditWardrobeItemScreen(profileId: widget.profileId, item: item)),
    );
    if (mounted && updated == true) await _refresh();
  }

  Future<void> _toggleFavorite(WardrobeItem item) => ref.read(wardrobeControllerProvider.notifier).toggleFavorite(profileId: widget.profileId, item: item);

  Future<void> _deleteItem(WardrobeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from this wardrobe?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(wardrobeControllerProvider.notifier).deleteItem(profileId: widget.profileId, itemId: item.id);
    }
  }

  void _nav(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        return;
      case 1:
        return;
      case 2:
        context.push(AppRoutes.outfits, extra: widget.profileId);
        return;
      case 3:
        context.push(AppRoutes.profiles);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);
    final filtered = state.items.where((item) {
      final query = _searchController.text.trim().toLowerCase();
      final matchesSearch = query.isEmpty || item.name.toLowerCase().contains(query) || (item.brand ?? '').toLowerCase().contains(query);
      final matchesFilter = _filter == 'All' || item.category.name.toLowerCase() == _filter.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: LockMyLookUi.coral,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: _header(state.items.length)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(child: _search()),
              ),
              SliverToBoxAdapter(child: _filters(state.items)),
              if (state.status == WardrobeStatus.loading && state.items.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                SliverFillRemaining(child: _empty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _itemCard(filtered[index]),
                      childCount: filtered.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                      childAspectRatio: .69,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _addFab(),
      bottomNavigationBar: LmlBottomNav(currentIndex: 1, onTap: _nav),
    );
  }

  Widget _header(int itemCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _roundIconButton(Icons.arrow_back_rounded, () => context.go(AppRoutes.home)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Wardrobe', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: LockMyLookUi.ink, letterSpacing: -.7)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: LockMyLookUi.coral, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$itemCount ${itemCount == 1 ? 'piece' : 'pieces'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LockMyLookUi.muted)),
                ],
              ),
            ],
          ),
        ),
        _roundIconButton(Icons.add_rounded, _openAddItem, filled: true),
      ],
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap, {bool filled = false}) {
    return Material(
      color: filled ? LockMyLookUi.ink : Colors.white,
      shape: const CircleBorder(),
      elevation: filled ? 4 : 0,
      shadowColor: LockMyLookUi.ink.withValues(alpha: .16),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 21, color: filled ? Colors.white : LockMyLookUi.ink),
        ),
      ),
    );
  }

  Widget _search() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: LockMyLookUi.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LockMyLookUi.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded, size: 22, color: LockMyLookUi.ink),
          hintText: 'Search your wardrobe',
          hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: LockMyLookUi.muted),
          suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.tune_rounded, size: 20, color: LockMyLookUi.muted)),
        ),
      ),
    );
  }

  Widget _filters(List<WardrobeItem> items) {
    final categories = <String>{'All', ...items.map((item) => item.category.name)}.toList();
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 9),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (_, index) {
          final category = categories[index];
          final selected = _filter == category;
          return GestureDetector(
            onTap: () => setState(() => _filter = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? LockMyLookUi.ink : Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: selected ? LockMyLookUi.ink : LockMyLookUi.border),
              ),
              child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : LockMyLookUi.ink)),
            ),
          );
        },
      ),
    );
  }

  Widget _itemCard(WardrobeItem item) {
    return GestureDetector(
      onTap: () => _openEditItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LockMyLookUi.border.withValues(alpha: .7)),
          boxShadow: [BoxShadow(color: LockMyLookUi.ink.withValues(alpha: .045), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                children: [
                  Positioned.fill(child: _itemImage(item)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        onTap: () => _toggleFavorite(item),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(item.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: item.favorite ? LockMyLookUi.coral : LockMyLookUi.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: LockMyLookUi.ink)),
                    const SizedBox(height: 4),
                    Text([item.category.name, if ((item.brand ?? '').isNotEmpty) item.brand!].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: LockMyLookUi.muted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      children: [
                        if ((item.primaryColor ?? '').isNotEmpty) ...[
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: _colorForName(item.primaryColor!), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                        ],
                        Expanded(child: Text(item.primaryColor ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: LockMyLookUi.muted))),
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 19,
                            onSelected: (value) {
                              if (value == 'delete') _deleteItem(item);
                              if (value == 'favorite') _toggleFavorite(item);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'favorite', child: Text(item.favorite ? 'Remove favorite' : 'Add favorite')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForName(String name) {
    final value = name.toLowerCase();
    if (value.contains('black')) return Colors.black87;
    if (value.contains('white') || value.contains('cream')) return const Color(0xFFE9E5DE);
    if (value.contains('blue')) return const Color(0xFF4777B8);
    if (value.contains('red')) return const Color(0xFFD95A5A);
    if (value.contains('green')) return const Color(0xFF4E8B68);
    if (value.contains('pink')) return const Color(0xFFE69AAE);
    if (value.contains('brown')) return const Color(0xFF8B654C);
    if (value.contains('yellow')) return const Color(0xFFE5BD48);
    return LockMyLookUi.muted;
  }

  Widget _itemImage(WardrobeItem item) {
    if (item.images.isNotEmpty) {
      final imageUrl = _resolveImageUrl(item.images.first.thumbnailUrl);
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Wardrobe image failed: $imageUrl');
          debugPrint('Image error: $error');
          return LockMyLookUi.imagePlaceholder(label: item.name);
        },
      );
    }
    return LockMyLookUi.imagePlaceholder(label: item.category.name);
  }

  String _resolveImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) return trimmed;
    var path = trimmed.replaceAll('\\', '/');
    if (path.startsWith('./')) path = path.substring(2);
    if (path.startsWith('/')) path = path.substring(1);
    final base = Uri.parse(ApiConstants.baseUrl);
    final origin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);
    return origin.resolve('/$path').toString();
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: LockMyLookUi.coralSoft, shape: BoxShape.circle, boxShadow: [BoxShadow(color: LockMyLookUi.coral.withValues(alpha: .16), blurRadius: 22)]),
              child: const Icon(Icons.checkroom_rounded, size: 38, color: LockMyLookUi.coral),
            ),
            const SizedBox(height: 18),
            const Text('Your wardrobe is waiting.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LockMyLookUi.ink)),
            const SizedBox(height: 7),
            const Text('Add your first piece and start building looks that feel like you.', textAlign: TextAlign.center, style: TextStyle(color: LockMyLookUi.muted, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _openAddItem, icon: const Icon(Icons.add_rounded), label: const Text('Add to Wardrobe')),
          ],
        ),
      ),
    );
  }

  Widget _addFab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [BoxShadow(color: LockMyLookUi.coral.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: FloatingActionButton.extended(
        onPressed: _openAddItem,
        backgroundColor: LockMyLookUi.coral,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
