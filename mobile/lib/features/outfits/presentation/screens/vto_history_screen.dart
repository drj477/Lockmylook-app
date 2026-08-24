import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/outfits/application/virtual_try_on_providers.dart';
import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';

class VtoHistoryScreen extends ConsumerStatefulWidget {
  const VtoHistoryScreen({super.key});

  @override
  ConsumerState<VtoHistoryScreen> createState() => _VtoHistoryScreenState();
}

class _VtoHistoryScreenState extends ConsumerState<VtoHistoryScreen> {
  List<VirtualTryOnResult> _results = const [];
  String? _profileId;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    var profiles = ref.read(profileControllerProvider).profiles;

    if (profiles.isEmpty) {
      await ref.read(profileControllerProvider.notifier).loadProfiles();
      if (!mounted) return;
      profiles = ref.read(profileControllerProvider).profiles;
    }

    if (profiles.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final profileId = profiles.first.id;
    _profileId = profileId;

    try {
      final results = await ref.read(virtualTryOnRepositoryProvider).history(
            profileId: profileId,
          );
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Could not load VTO history: $error');
      }
    }
  }

  Future<void> _deleteOne(VirtualTryOnResult result) async {
    final confirmed = await _confirm(
      'Delete this generated look?',
      'This deletes the image and its shared cache entry. If you generate the same person and garments with another model later, it will generate again.',
    );
    if (!confirmed || _profileId == null) return;

    setState(() => _deleting = true);
    try {
      await ref.read(virtualTryOnRepositoryProvider).delete(
            profileId: _profileId!,
            resultId: result.id,
          );
      if (mounted) {
        setState(() {
          _results = _results.where((item) => item.id != result.id).toList();
        });
      }
    } catch (error) {
      _message('Could not delete this look: $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _clearAll() async {
    if (_results.isEmpty || _profileId == null) return;
    final confirmed = await _confirm(
      'Clear all cached looks?',
      'Every generated VTO result and its shared cache entry for the current profile will be deleted. Wardrobe and profile images are not affected.',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await ref.read(virtualTryOnRepositoryProvider).deleteAll(
            profileId: _profileId!,
          );
      if (mounted) setState(() => _results = const []);
    } catch (error) {
      _message('Could not clear VTO history: $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      appBar: AppBar(
        title: const Text(
          'VTO History & Cache',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              tooltip: 'Clear all cache',
              onPressed: _deleting ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _resultCard(_results[index]),
                  ),
                ),
    );
  }

  Widget _resultCard(VirtualTryOnResult result) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: double.infinity,
            child: Image.network(
              result.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: LockMyLookUi.coralSoft,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: LockMyLookUi.coralSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'SHARED CACHE',
                      style: TextStyle(
                        color: LockMyLookUi.coral,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Generated with ${_modelLabel(result.model)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LockMyLookUi.ink,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.itemIds.length} garment${result.itemIds.length == 1 ? '' : 's'} · reusable across models',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: LockMyLookUi.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _date(result.createdAt),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: LockMyLookUi.muted,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: TextButton.icon(
                      onPressed: _deleting ? null : () => _deleteOne(result),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      label: const Text('Delete cache'),
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

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: LockMyLookUi.coralSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_awesome_mosaic_outlined,
                  color: LockMyLookUi.coral,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No cached looks yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your generated try-on images appear here as shared cache entries. One generated image can be reused by every VTO model until you delete it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LockMyLookUi.muted, height: 1.4),
              ),
            ],
          ),
        ),
      );

  String _modelLabel(VirtualTryOnModel model) => switch (model) {
        VirtualTryOnModel.dTryon => 'D-Tryon',
        VirtualTryOnModel.gemini => 'Gemini',
        VirtualTryOnModel.geminiChat => 'Gemini Chat',
        VirtualTryOnModel.replicate => 'Replicate',
      };

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
