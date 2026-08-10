import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/outfits/application/virtual_try_on_providers.dart';
import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class VirtualTryOnResultScreen extends ConsumerStatefulWidget {
  const VirtualTryOnResultScreen({
    required this.profileId,
    required this.result,
    required this.selectedItems,
    super.key,
  });

  final String profileId;
  final VirtualTryOnResult result;
  final List<WardrobeItem> selectedItems;

  @override
  ConsumerState<VirtualTryOnResultScreen> createState() =>
      _VirtualTryOnResultScreenState();
}

class _VirtualTryOnResultScreenState
    extends ConsumerState<VirtualTryOnResultScreen> {
  late bool _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.result.saved;
  }

  Future<void> _toggleSaved() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final result = await ref.read(virtualTryOnRepositoryProvider).setSaved(
            profileId: widget.profileId,
            resultId: widget.result.id,
            saved: !_saved,
          );

      if (!mounted) return;

      setState(() {
        _saved = result.saved;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.saved
                ? 'Look saved.'
                : 'Look removed from saved looks.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update saved look: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      appBar: AppBar(
        backgroundColor: LockMyLookUi.background,
        title: const Text('Your Try-On'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
          children: [
            Container(
              height: MediaQuery.sizeOf(context).height * .68,
              constraints: const BoxConstraints(minHeight: 420),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: LockMyLookUi.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                widget.result.imageUrl,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (_, _, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'The try-on image could not be loaded.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Virtual Try-On',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: LockMyLookUi.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.selectedItems.length} '
              '${widget.selectedItems.length == 1 ? 'piece' : 'pieces'} '
              'from your wardrobe',
              style: const TextStyle(color: LockMyLookUi.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selectedItems
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: LockMyLookUi.coralSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _toggleSaved,
                    icon: Icon(
                      _saved ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(_saved ? 'Saved' : 'Save Look'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.checkroom_outlined),
                    label: const Text('Try Another'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
