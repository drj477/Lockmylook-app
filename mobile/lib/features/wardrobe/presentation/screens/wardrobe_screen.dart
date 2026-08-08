import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(wardrobeControllerProvider.notifier).loadItems(widget.profileId);
    });
  }

  Future<void> _refresh() {
    return ref
        .read(wardrobeControllerProvider.notifier)
        .loadItems(widget.profileId);
  }

  Future<void> _openAddItem() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddWardrobeItemScreen(profileId: widget.profileId),
      ),
    );

    if (!mounted || created != true) {
      return;
    }

    await _refresh();
  }

  Future<void> _openEditItem(WardrobeItem item) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditWardrobeItemScreen(profileId: widget.profileId, item: item),
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    // The controller already updates its local state after PATCH.
    // Refreshing here ensures the screen reflects the backend
    // as the source of truth.
    await _refresh();
  }

  Future<void> _toggleFavorite(WardrobeItem item) async {
    await ref
        .read(wardrobeControllerProvider.notifier)
        .toggleFavorite(profileId: widget.profileId, item: item);
  }

  Future<void> _deleteItem(WardrobeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Remove "${item.name}" from this wardrobe?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref
        .read(wardrobeControllerProvider.notifier)
        .deleteItem(profileId: widget.profileId, itemId: item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wardrobeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wardrobe'),
        actions: [
          IconButton(
            tooltip: 'Add item',
            icon: const Icon(Icons.add),
            onPressed: _openAddItem,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(state)),
    );
  }

  Widget _buildBody(WardrobeState state) {
    if (state.status == WardrobeStatus.error && state.items.isEmpty) {
      return _buildError(state);
    }

    if (state.status == WardrobeStatus.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'No wardrobe items yet.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = state.items[index];

          return Card(
            child: ListTile(
              onTap: () => _openEditItem(item),
              leading: CircleAvatar(
                child: Text(
                  item.name.isEmpty ? '?' : item.name[0].toUpperCase(),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                [
                  item.category.name,
                  if (item.brand != null && item.brand!.isNotEmpty) item.brand!,
                ].join(' • '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'favorite':
                      _toggleFavorite(item);
                    case 'delete':
                      _deleteItem(item);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      item.favorite ? 'Remove favorite' : 'Add favorite',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(WardrobeState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'Unable to load wardrobe.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _refresh, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
