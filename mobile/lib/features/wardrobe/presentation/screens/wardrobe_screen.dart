import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
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
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AddWardrobeItemScreen(profileId: widget.profileId)));
    if (mounted && created == true) {
      await _refresh();
    }
  }

  Future<void> _openEditItem(WardrobeItem item) async {
    final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EditWardrobeItemScreen(profileId: widget.profileId, item: item)));
    if (mounted && updated == true) {
      await _refresh();
    }
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
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), sliver: SliverToBoxAdapter(child: _header())),
              SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), sliver: SliverToBoxAdapter(child: _search())),
              SliverToBoxAdapter(child: _filters(state.items)),
              if (state.status == WardrobeStatus.loading && state.items.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                SliverFillRemaining(child: _empty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) => _itemCard(filtered[index]), childCount: filtered.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .72),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: LockMyLookUi.coral, foregroundColor: Colors.white, onPressed: _openAddItem, child: const Icon(Icons.add)),
      bottomNavigationBar: LmlBottomNav(currentIndex: 1, onTap: _nav),
    );
  }

  Widget _header() {
    return Row(children: [IconButton(onPressed: () => context.go(AppRoutes.home), icon: const Icon(Icons.arrow_back)), const Expanded(child: Text('My Wardrobe', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: LockMyLookUi.ink))), IconButton(onPressed: _openAddItem, icon: const Icon(Icons.add, color: LockMyLookUi.ink))]);
  }

  Widget _search() {
    return TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search items...', suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.tune))));
  }

  Widget _filters(List<WardrobeItem> items) {
    final categories = <String>{'All', ...items.map((item) => item.category.name)}.toList();
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = categories[index];
          return GestureDetector(onTap: () => setState(() => _filter = category), child: LockMyLookUi.pill(category, selected: _filter == category));
        },
      ),
    );
  }

  Widget _itemCard(WardrobeItem item) {
    return GestureDetector(
      onTap: () => _openEditItem(item),
      child: Container(
        decoration: LockMyLookUi.cardDecoration(),
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(13), child: SizedBox.expand(child: _itemImage(item))), Positioned(top: 7, right: 7, child: Material(color: Colors.white.withAlpha(235), shape: const CircleBorder(), child: InkWell(onTap: () => _toggleFavorite(item), customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(7), child: Icon(item.favorite ? Icons.favorite : Icons.favorite_border, size: 17, color: item.favorite ? LockMyLookUi.coral : LockMyLookUi.ink)))))])),
            const SizedBox(height: 9),
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: LockMyLookUi.ink)),
            const SizedBox(height: 3),
            Text([item.category.name, if ((item.brand ?? '').isNotEmpty) item.brand!].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: LockMyLookUi.muted)),
            const SizedBox(height: 4),
            Row(children: [Expanded(child: Text(item.primaryColor ?? '—', style: const TextStyle(fontSize: 11, color: LockMyLookUi.muted))), PopupMenuButton<String>(padding: EdgeInsets.zero, iconSize: 20, onSelected: (value) { if (value == 'delete') { _deleteItem(item); } if (value == 'favorite') { _toggleFavorite(item); } }, itemBuilder: (_) => [PopupMenuItem(value: 'favorite', child: Text(item.favorite ? 'Remove favorite' : 'Add favorite')), const PopupMenuItem(value: 'delete', child: Text('Delete'))])]),
          ],
        ),
      ),
    );
  }

  Widget _itemImage(WardrobeItem item) {
    if (item.images.isNotEmpty) {
      return Image.network(item.images.first.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => LockMyLookUi.imagePlaceholder(label: item.name));
    }
    return LockMyLookUi.imagePlaceholder(label: item.category.name);
  }

  Widget _empty() {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.checkroom_outlined, size: 54, color: LockMyLookUi.muted), const SizedBox(height: 14), const Text('Your wardrobe is waiting.', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: LockMyLookUi.ink)), const SizedBox(height: 6), const Text('Add your first item and start building looks.', textAlign: TextAlign.center, style: TextStyle(color: LockMyLookUi.muted)), const SizedBox(height: 18), ElevatedButton.icon(onPressed: _openAddItem, icon: const Icon(Icons.add), label: const Text('Add Item'))])));
  }
}
