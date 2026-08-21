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
    final itemCount = widget.selectedItems.length;

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                children: [
                  _resultHero(),
                  const SizedBox(height: 12),
                  _resultSummary(itemCount),
                  const SizedBox(height: 12),
                  _actions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: LockMyLookUi.ink,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIRTUAL TRY-ON',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: LockMyLookUi.coral,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your Try-On',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ],
            ),
          ),
          _savedHeaderButton(),
        ],
      ),
    );
  }

  Widget _savedHeaderButton() {
    return Material(
      color: _saved ? LockMyLookUi.coralSoft : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _saving ? null : _toggleSaved,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            _saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _saved ? LockMyLookUi.coral : LockMyLookUi.ink,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _resultHero() {
    return Container(
      height: 570,
      decoration: BoxDecoration(
        color: const Color(0xFF12151D),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF191D27),
                    const Color(0xFF0F1218),
                    LockMyLookUi.coral.withAlpha(20),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _heroPill(
              icon: Icons.auto_awesome_rounded,
              label: 'AI GENERATED',
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _heroPill(
              icon: Icons.check_circle_rounded,
              label: 'READY',
              accent: true,
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 58, 10, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: const Color(0xFFFFFBF7),
                  child: Image.network(
                    widget.result.imageUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const Center(
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_not_supported_outlined,
                              size: 42,
                              color: LockMyLookUi.muted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'The try-on image could not be loaded.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LockMyLookUi.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    bool accent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent ? LockMyLookUi.coral : Colors.black.withAlpha(125),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent ? Colors.transparent : Colors.white.withAlpha(28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              letterSpacing: .7,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultSummary(int itemCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LockMyLookUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: LockMyLookUi.coralSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: LockMyLookUi.coral,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your look is ready',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: LockMyLookUi.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$itemCount ${itemCount == 1 ? 'piece' : 'pieces'} '
                  'styled from your wardrobe',
                  style: const TextStyle(
                    color: LockMyLookUi.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _toggleSaved,
              icon: Icon(
                _saved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 19,
              ),
              label: Text(
                _saving ? 'Saving...' : (_saved ? 'Saved' : 'Save Look'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    _saved ? LockMyLookUi.coral : LockMyLookUi.ink,
                backgroundColor:
                    _saved ? LockMyLookUi.coralSoft : Colors.white,
                side: BorderSide(
                  color: _saved
                      ? LockMyLookUi.coral.withAlpha(90)
                      : LockMyLookUi.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: const Text(
                'Try Another',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: LockMyLookUi.coral,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: LockMyLookUi.coral.withAlpha(75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
