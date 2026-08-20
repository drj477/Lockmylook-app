import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';
import 'package:mobile/features/wardrobe/application/wardrobe_providers.dart';
import 'package:mobile/features/wardrobe/data/models/wardrobe_models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _storage = FlutterSecureStorage();
  static const _todayPickDateKey = 'home_today_pick_date';
  static const _todayPickIdsKey = 'home_today_pick_ids';

  List<WardrobeItem> _todayPick = [];
  String? _loadedProfileId;
  bool _todayPickLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHome);
  }

  Future<void> _loadHome() async {
    await ref.read(profileControllerProvider.notifier).loadProfiles();

    if (!mounted) {
      return;
    }

    final profiles = ref.read(profileControllerProvider).profiles;
    if (profiles.isEmpty) {
      return;
    }

    await _loadWardrobeAndPick(profiles.first.id);
  }

  Future<void> _selectProfile(String profileId) async {
    ref.read(profileControllerProvider.notifier).selectProfile(profileId);
    await _loadWardrobeAndPick(profileId);
  }

  Future<void> _loadWardrobeAndPick(String profileId) async {
    if (_loadedProfileId == profileId && _todayPick.isNotEmpty) {
      return;
    }

    _loadedProfileId = profileId;

    setState(() {
      _todayPickLoading = true;
    });

    try {
      await ref.read(wardrobeControllerProvider.notifier).loadItems(profileId);

      if (!mounted) {
        return;
      }

      final wardrobeState = ref.read(wardrobeControllerProvider);
      await _loadCachedOrCreatePick(wardrobeState.items);
    } finally {
      if (mounted) {
        setState(() {
          _todayPickLoading = false;
        });
      }
    }
  }

  Future<void> _loadCachedOrCreatePick(List<WardrobeItem> items) async {
    if (items.isEmpty) {
      setState(() {
        _todayPick = [];
      });
      return;
    }

    final today = _todayKey();
    final cachedDate = await _storage.read(key: _todayPickDateKey);
    final cachedIdsRaw = await _storage.read(key: _todayPickIdsKey);

    if (cachedDate == today &&
        cachedIdsRaw != null &&
        cachedIdsRaw.isNotEmpty) {
      final cachedIds = cachedIdsRaw
          .split(',')
          .where((id) => id.isNotEmpty)
          .toSet();
      final cachedItems = <WardrobeItem>[];

      for (final item in items) {
        if (cachedIds.contains(item.id)) {
          cachedItems.add(item);
        }
      }

      if (cachedItems.isNotEmpty) {
        setState(() {
          _todayPick = cachedItems;
        });
        return;
      }
    }

    await _createNewTodayPick(items);
  }

  Future<void> _createNewTodayPick(List<WardrobeItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final selected = _buildLocalOutfit(items, random);

    if (selected.isEmpty) {
      return;
    }

    await _storage.write(key: _todayPickDateKey, value: _todayKey());
    await _storage.write(
      key: _todayPickIdsKey,
      value: selected.map((item) => item.id).join(','),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _todayPick = selected;
    });
  }

  List<WardrobeItem> _buildLocalOutfit(
    List<WardrobeItem> items,
    Random random,
  ) {
    final available = [...items];

    if (available.length <= 3) {
      available.shuffle(random);
      return available;
    }

    final tops = available.where((item) {
      final category = item.category.name.toLowerCase();
      return category.contains('top') ||
          category.contains('shirt') ||
          category.contains('tee') ||
          category.contains('t-shirt') ||
          category.contains('hoodie') ||
          category.contains('sweater');
    }).toList();

    final bottoms = available.where((item) {
      final category = item.category.name.toLowerCase();
      return category.contains('bottom') ||
          category.contains('pant') ||
          category.contains('jean') ||
          category.contains('trouser') ||
          category.contains('short') ||
          category.contains('skirt');
    }).toList();

    final shoes = available.where((item) {
      final category = item.category.name.toLowerCase();
      return category.contains('shoe') ||
          category.contains('sneaker') ||
          category.contains('footwear');
    }).toList();

    final result = <WardrobeItem>[];

    void addRandomItem(List<WardrobeItem> source) {
      if (source.isEmpty) {
        return;
      }

      final item = source[random.nextInt(source.length)];
      if (!result.any((selected) => selected.id == item.id)) {
        result.add(item);
      }
    }

    addRandomItem(tops);
    addRandomItem(bottoms);
    addRandomItem(shoes);

    if (result.length < 3) {
      available.shuffle(random);
      for (final item in available) {
        if (!result.any((selected) => selected.id == item.id)) {
          result.add(item);
        }
        if (result.length == 3) {
          break;
        }
      }
    }

    return result;
  }

  Future<void> _restyle() async {
    final items = ref.read(wardrobeControllerProvider).items;

    if (items.isEmpty || _todayPickLoading) {
      return;
    }

    setState(() {
      _todayPickLoading = true;
    });

    try {
      await _createNewTodayPick(items);
    } finally {
      if (mounted) {
        setState(() {
          _todayPickLoading = false;
        });
      }
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _displayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return value;
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  String? get _profileId {
    final profiles = ref.read(profileControllerProvider).profiles;
    return profiles.isEmpty ? null : profiles.first.id;
  }

  void _openWardrobe() {
    final profileId = _profileId;
    if (profileId == null) {
      context.push(AppRoutes.profiles);
      return;
    }
    context.push(AppRoutes.wardrobe, extra: profileId);
  }

  void _openOutfits() {
    final profileId = _profileId;
    if (profileId == null) {
      context.push(AppRoutes.profiles);
      return;
    }
    context.push(AppRoutes.outfits, extra: profileId);
  }

  void _nav(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        _openWardrobe();
        return;
      case 2:
        _openOutfits();
        return;
      case 3:
        context.push(AppRoutes.profiles);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final selectedProfile = profileState.profiles.isEmpty
        ? null
        : profileState.profiles.first;
    final greetingName = selectedProfile == null
        ? 'there'
        : _displayName(selectedProfile.name);

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(profileControllerProvider.notifier).loadProfiles();
            if (!mounted) {
              return;
            }

            final profiles = ref.read(profileControllerProvider).profiles;
            if (profiles.isNotEmpty) {
              await _loadWardrobeAndPick(profiles.first.id);
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $greetingName 👋',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: LockMyLookUi.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ready to style your day?',
                          style: TextStyle(
                            color: LockMyLookUi.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: LockMyLookUi.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LockMyLookUi.sectionTitle(
                'My Profiles',
                action: 'Manage',
                onAction: () => context.push(AppRoutes.profiles),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 88,
                child: profileState.profiles.isEmpty
                    ? const Center(
                        child: Text(
                          'Create a profile to get started',
                          style: TextStyle(color: LockMyLookUi.muted),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: profileState.profiles.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          if (index == profileState.profiles.length) {
                            return _profileBubble(
                              label: 'Add',
                              initial: '+',
                              icon: Icons.add,
                              selected: false,
                              onTap: () => context.push(AppRoutes.profiles),
                            );
                          }

                          final profile = profileState.profiles[index];
                          final isSelected = index == 0;

                          return _profileBubble(
                            label: _displayName(profile.name),
                            avatarUrl: profile.avatarUrl,
                            initial: profile.name.trim().isEmpty
                                ? '?'
                                : profile.name.trim()[0].toUpperCase(),
                            selected: isSelected,
                            onTap: () => _selectProfile(profile.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEDF2FF), Color(0xFFFFE9E6)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: LockMyLookUi.coral,
                                size: 19,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'AI Outfit Suggestions',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: LockMyLookUi.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Get 5 best outfit ideas for your occasion and mood.',
                            style: TextStyle(
                              color: LockMyLookUi.muted,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _openOutfits,
                            child: const Text('Get Started'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 78,
                      height: 105,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(190),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.style_outlined,
                        size: 44,
                        color: LockMyLookUi.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LockMyLookUi.sectionTitle(
                'Today\'s Pick',
                action: 'Restyle ✨',
                onAction: _restyle,
              ),
              const SizedBox(height: 10),
              _todayPickCard(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _quickCard(
                      icon: Icons.checkroom_outlined,
                      title: 'My Wardrobe',
                      value: 'Your items',
                      onTap: _openWardrobe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _quickCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Outfits',
                      value: 'Style ideas',
                      onTap: _openOutfits,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LockMyLookUi.sectionTitle(
                'Recent Items',
                action: 'View All',
                onAction: _openWardrobe,
              ),
              const SizedBox(height: 10),
              _recentItems(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 0, onTap: _nav),
    );
  }

  Widget _todayPickCard() {
    if (_todayPickLoading && _todayPick.isEmpty) {
      return Container(
        height: 260,
        decoration: LockMyLookUi.cardDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_todayPick.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: LockMyLookUi.cardDecoration(),
        child: Column(
          children: [
            const Icon(
              Icons.checkroom_outlined,
              size: 44,
              color: LockMyLookUi.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Add a few wardrobe items to get your first daily pick.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LockMyLookUi.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _openWardrobe,
              child: const Text('Add Items'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 230,
            child: Row(
              children: [
                Expanded(flex: 3, child: _wardrobeImage(_todayPick[0])),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        child: _wardrobeImage(
                          _todayPick.length > 1 ? _todayPick[1] : _todayPick[0],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _wardrobeImage(
                          _todayPick.length > 2 ? _todayPick[2] : _todayPick[0],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Look',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: LockMyLookUi.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_todayPick.length} wardrobe pieces',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LockMyLookUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.favorite_border,
                  color: LockMyLookUi.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wardrobeImage(WardrobeItem item) {
    final imageUrl = item.images.isEmpty
        ? null
        : item.images.first.thumbnailUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: LockMyLookUi.background,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Center(
                child: Icon(
                  Icons.checkroom_outlined,
                  size: 38,
                  color: LockMyLookUi.muted,
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 34,
                      color: LockMyLookUi.muted,
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
      ),
    );
  }

  Widget _recentItems() {
    final items = ref.watch(wardrobeControllerProvider).items;

    if (items.isEmpty) {
      return Container(
        height: 130,
        decoration: LockMyLookUi.cardDecoration(),
        child: const Center(
          child: Text(
            'No wardrobe items yet.',
            style: TextStyle(color: LockMyLookUi.muted),
          ),
        ),
      );
    }

    final recent = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visibleItems = recent.take(8).toList();

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = visibleItems[index];
          return Container(
            width: 112,
            padding: const EdgeInsets.all(8),
            decoration: LockMyLookUi.cardDecoration(),
            child: Column(
              children: [
                Expanded(child: _recentItemImage(item)),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _recentItemImage(WardrobeItem item) {
    final imageUrl = item.images.isEmpty
        ? null
        : item.images.first.thumbnailUrl;

    if (imageUrl == null || imageUrl.isEmpty) {
      return LockMyLookUi.imagePlaceholder(label: item.name, height: 78);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return LockMyLookUi.imagePlaceholder(label: item.name, height: 78);
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  Widget _profileBubble({
    required String label,
    required String initial,
    required bool selected,
    String? avatarUrl,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final isAdd = icon != null;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 58,
              padding: EdgeInsets.all(selected ? 2.5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAdd
                      ? LockMyLookUi.border
                      : selected
                          ? LockMyLookUi.coral
                          : Colors.transparent,
                  width: selected ? 2.5 : 1.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAdd ? Colors.white : LockMyLookUi.coralSoft,
                  border: isAdd
                      ? null
                      : Border.all(
                          color: LockMyLookUi.border,
                          width: 1,
                        ),
                ),
                child: ClipOval(
                  child: isAdd
                      ? Icon(icon, color: LockMyLookUi.navy, size: 23)
                      : avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: LockMyLookUi.coral,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: LockMyLookUi.coral,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: LockMyLookUi.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: LockMyLookUi.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: LockMyLookUi.coralSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: LockMyLookUi.coral),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LockMyLookUi.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LockMyLookUi.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
