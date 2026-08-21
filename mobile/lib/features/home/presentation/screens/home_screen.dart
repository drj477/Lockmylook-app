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

    if (!mounted) return;

    final profiles = ref.read(profileControllerProvider).profiles;

    if (profiles.isEmpty) return;

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

    setState(() => _todayPickLoading = true);

    try {
      await ref
          .read(wardrobeControllerProvider.notifier)
          .loadItems(profileId);

      if (!mounted) return;

      await _loadCachedOrCreatePick(
        ref.read(wardrobeControllerProvider).items,
      );
    } finally {
      if (mounted) {
        setState(() => _todayPickLoading = false);
      }
    }
  }

  Future<void> _loadCachedOrCreatePick(
    List<WardrobeItem> items,
  ) async {
    if (items.isEmpty) {
      setState(() => _todayPick = []);
      return;
    }

    final cachedDate = await _storage.read(
      key: _todayPickDateKey,
    );

    final cachedIdsRaw = await _storage.read(
      key: _todayPickIdsKey,
    );

    if (
        cachedDate == _todayKey() &&
        cachedIdsRaw != null &&
        cachedIdsRaw.isNotEmpty) {
      final ids = cachedIdsRaw
          .split(',')
          .where((id) => id.isNotEmpty)
          .toSet();

      final cached = items
          .where((item) => ids.contains(item.id))
          .toList();

      if (cached.isNotEmpty) {
        setState(() => _todayPick = cached);
        return;
      }
    }

    await _createNewTodayPick(items);
  }

  Future<void> _createNewTodayPick(
    List<WardrobeItem> items,
  ) async {
    if (items.isEmpty) return;

    final selected = _buildLocalOutfit(
      items,
      Random(DateTime.now().millisecondsSinceEpoch),
    );

    if (selected.isEmpty) return;

    await _storage.write(
      key: _todayPickDateKey,
      value: _todayKey(),
    );

    await _storage.write(
      key: _todayPickIdsKey,
      value: selected.map((e) => e.id).join(','),
    );

    if (mounted) {
      setState(() => _todayPick = selected);
    }
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
      final c = item.category.name.toLowerCase();

      return c.contains('top') ||
          c.contains('shirt') ||
          c.contains('tee') ||
          c.contains('t-shirt') ||
          c.contains('hoodie') ||
          c.contains('sweater');
    }).toList();

    final bottoms = available.where((item) {
      final c = item.category.name.toLowerCase();

      return c.contains('bottom') ||
          c.contains('pant') ||
          c.contains('jean') ||
          c.contains('trouser') ||
          c.contains('short') ||
          c.contains('skirt');
    }).toList();

    final shoes = available.where((item) {
      final c = item.category.name.toLowerCase();

      return c.contains('shoe') ||
          c.contains('sneaker') ||
          c.contains('footwear');
    }).toList();

    final result = <WardrobeItem>[];

    void addRandom(List<WardrobeItem> source) {
      if (source.isEmpty) return;

      final item = source[random.nextInt(source.length)];

      if (!result.any((x) => x.id == item.id)) {
        result.add(item);
      }
    }

    addRandom(tops);
    addRandom(bottoms);
    addRandom(shoes);

    if (result.length < 3) {
      available.shuffle(random);

      for (final item in available) {
        if (!result.any((x) => x.id == item.id)) {
          result.add(item);
        }

        if (result.length == 3) break;
      }
    }

    return result;
  }

  Future<void> _restyle() async {
    final items = ref.read(wardrobeControllerProvider).items;

    if (items.isEmpty || _todayPickLoading) return;

    setState(() => _todayPickLoading = true);

    try {
      await _createNewTodayPick(items);
    } finally {
      if (mounted) {
        setState(() => _todayPickLoading = false);
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

    if (trimmed.isEmpty) return value;

    return '${trimmed[0].toUpperCase()}'
        '${trimmed.substring(1)}';
  }

  String? get _profileId {
    final profiles = ref.read(profileControllerProvider).profiles;

    return profiles.isEmpty ? null : profiles.first.id;
  }

  void _openWardrobe() {
    final id = _profileId;

    if (id == null) {
      context.push(AppRoutes.profiles);
    } else {
      context.push(
        AppRoutes.wardrobe,
        extra: id,
      );
    }
  }

  void _openOutfits() {
    final id = _profileId;

    if (id == null) {
      context.push(AppRoutes.profiles);
    } else {
      context.push(
        AppRoutes.outfits,
        extra: id,
      );
    }
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
    final state = ref.watch(profileControllerProvider);

    final selected = state.profiles.isEmpty
        ? null
        : state.profiles.first;

    final greeting = selected == null
        ? 'there'
        : _displayName(selected.name);

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(profileControllerProvider.notifier)
                .loadProfiles();

            if (!mounted) return;

            final profiles =
                ref.read(profileControllerProvider).profiles;

            if (profiles.isNotEmpty) {
              await _loadWardrobeAndPick(
                profiles.first.id,
              );
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              28,
            ),
            children: [
              _heroHeader(greeting),

              const SizedBox(height: 24),

              LockMyLookUi.sectionTitle(
                'My Profiles',
                action: 'Manage',
                onAction: () =>
                    context.push(AppRoutes.profiles),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 98,
                child: state.profiles.isEmpty
                    ? const Center(
                        child: Text(
                          'Create a profile to get started',
                          style: TextStyle(
                            color: LockMyLookUi.muted,
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            state.profiles.length + 1,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          if (index ==
                              state.profiles.length) {
                            return _profileBubble(
                              label: 'Add',
                              initial: '+',
                              icon: Icons.add,
                              selected: false,
                              onTap: () => context.push(
                                AppRoutes.profiles,
                              ),
                            );
                          }

                          final profile =
                              state.profiles[index];

                          return _profileBubble(
                            label:
                                _displayName(profile.name),
                            avatarUrl: profile.avatarUrl,
                            initial:
                                profile.name.trim().isEmpty
                                    ? '?'
                                    : profile.name
                                        .trim()[0]
                                        .toUpperCase(),
                            selected: index == 0,
                            onTap: () =>
                                _selectProfile(
                              profile.id,
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 22),

              _styleAiCard(),

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
                      icon:
                          Icons.auto_awesome_outlined,
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
      bottomNavigationBar: LmlBottomNav(
        currentIndex: 0,
        onTap: _nav,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------

  Widget _heroHeader(String greeting) {
    return Container(
      // Deliberately fixed. No Spacer() is used inside this card.
      // This prevents the search bar from being pushed outside the
      // bottom boundary on smaller devices.
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF071F35),
            Color(0xFF06283F),
            Color(0xFF10223A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF071F35).withAlpha(28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Coral glow.
          Positioned(
            right: -62,
            top: -78,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    LockMyLookUi.coral.withAlpha(105),
                    LockMyLookUi.coral.withAlpha(32),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Coral editorial panel.
          Positioned(
            right: -58,
            bottom: -54,
            child: Transform.rotate(
              angle: -.32,
              child: Container(
                width: 235,
                height: 118,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      LockMyLookUi.coral.withAlpha(0),
                      LockMyLookUi.coral.withAlpha(38),
                      LockMyLookUi.coral.withAlpha(82),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(70),
                ),
              ),
            ),
          ),

          // Subtle fashion lines.
          Positioned(
            right: 16,
            top: 8,
            child: Transform.rotate(
              angle: -.32,
              child: Container(
                width: 92,
                height: 1,
                color: Colors.white.withAlpha(16),
              ),
            ),
          ),

          Positioned(
            right: 4,
            top: 18,
            child: Transform.rotate(
              angle: -.32,
              child: Container(
                width: 122,
                height: 1,
                color: LockMyLookUi.coral.withAlpha(35),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // Top identity row.
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration:
                                const BoxDecoration(
                              color:
                                  LockMyLookUi.coral,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'YOUR PERSONAL STYLE',
                            style: TextStyle(
                              color: Colors.white
                                  .withAlpha(175),
                              fontSize: 9,
                              letterSpacing: 1.25,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _heroProfileButton(),
                  ],
                ),

                const SizedBox(height: 5),

                // Coral greeting.
                Text(
                  'Hello, $greeting',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LockMyLookUi.coral,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.15,
                  ),
                ),

                const SizedBox(height: 4),

                // Main title.
                const Text(
                  'Find your next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: .98,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),

                const Text(
                  'favorite look.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: .98,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -.7,
                  ),
                ),

                // IMPORTANT:
                // Fixed spacing instead of Spacer().
                const SizedBox(height: 11),

                _heroSearch(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroProfileButton() {
    return GestureDetector(
      onTap: () =>
          context.push(AppRoutes.profiles),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(15),
          border: Border.all(
            color: Colors.white.withAlpha(42),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  LockMyLookUi.coral.withAlpha(24),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: Colors.white,
          size: 21,
        ),
      ),
    );
  }

  Widget _heroSearch() {
    return SizedBox(
      height: 47,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withAlpha(25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),

            const Icon(
              Icons.search_rounded,
              size: 20,
              color: LockMyLookUi.ink,
            ),

            const SizedBox(width: 10),

            const Expanded(
              child: Text(
                'Search your wardrobe...',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: LockMyLookUi.muted,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),

            Container(
              width: 37,
              height: 37,
              margin:
                  const EdgeInsets.only(
                right: 5,
              ),
              decoration: BoxDecoration(
                color: LockMyLookUi.coral,
                borderRadius:
                    BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: LockMyLookUi.coral
                        .withAlpha(45),
                    blurRadius: 10,
                    offset:
                        const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI CARD
  // ---------------------------------------------------------------------------

  Widget _styleAiCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF1EF),
            Color(0xFFF3F0FF),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                LockMyLookUi.coral.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color:
                          LockMyLookUi.coral,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'AI OUTFIT SUGGESTIONS',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            LockMyLookUi.coral,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Let your wardrobe\ndo the styling.',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 18,
                    height: 1.05,
                    color:
                        LockMyLookUi.ink,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Get five looks made for you.',
                  style: TextStyle(
                    color:
                        LockMyLookUi.muted,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 13),

                ElevatedButton(
                  onPressed: _openOutfits,
                  style:
                      ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(0, 36),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Style me →',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 76,
            height: 108,
            decoration: BoxDecoration(
              color:
                  Colors.white.withAlpha(205),
              borderRadius:
                  BorderRadius.circular(23),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 16,
                  right: 15,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: LockMyLookUi
                        .coral
                        .withAlpha(150),
                  ),
                ),
                const Icon(
                  Icons.style_outlined,
                  size: 43,
                  color: LockMyLookUi.navy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROFILES
  // ---------------------------------------------------------------------------

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
        width: 76,
        child: Column(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!isAdd)
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              LockMyLookUi.coral,
                          width: 2.5,
                        ),
                      ),
                    ),

                  Container(
                    width:
                        selected ? 62 : 58,
                    height:
                        selected ? 62 : 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isAdd
                          ? Colors.white
                          : LockMyLookUi
                              .coralSoft,
                      border: isAdd
                          ? Border.all(
                              color:
                                  LockMyLookUi
                                      .border,
                              width: 3.5,
                            )
                          : null,
                    ),
                    child: ClipOval(
                      child: isAdd
                          ? Icon(
                              icon,
                              color:
                                  LockMyLookUi
                                      .navy,
                              size: 23,
                            )
                          : avatarUrl != null &&
                                  avatarUrl
                                      .isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (
                                    _,
                                    _,
                                    _,
                                  ) =>
                                          Center(
                                    child: Text(
                                      initial,
                                      style:
                                          const TextStyle(
                                        color:
                                            LockMyLookUi
                                                .coral,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initial,
                                    style:
                                        const TextStyle(
                                      color:
                                          LockMyLookUi
                                              .coral,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color:
                    LockMyLookUi.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TODAY'S PICK
  // ---------------------------------------------------------------------------

  Widget _todayPickCard() {
    if (_todayPickLoading &&
        _todayPick.isEmpty) {
      return Container(
        height: 260,
        decoration:
            LockMyLookUi.cardDecoration(),
        child: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_todayPick.isEmpty) {
      return Container(
        padding:
            const EdgeInsets.all(24),
        decoration:
            LockMyLookUi.cardDecoration(),
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
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    LockMyLookUi.muted,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton(
              onPressed: _openWardrobe,
              child:
                  const Text('Add Items'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withAlpha(12),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 230,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _wardrobeImage(
                    _todayPick[0],
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Expanded(
                        child:
                            _wardrobeImage(
                          _todayPick.length >
                                  1
                              ? _todayPick[1]
                              : _todayPick[0],
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Expanded(
                        child:
                            _wardrobeImage(
                          _todayPick.length >
                                  2
                              ? _todayPick[2]
                              : _todayPick[0],
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Look',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            LockMyLookUi.ink,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${_todayPick.length} wardrobe pieces',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            LockMyLookUi.muted,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.favorite_border,
                  color:
                      LockMyLookUi.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wardrobeImage(
    WardrobeItem item,
  ) {
    final url = item.images.isEmpty
        ? null
        : item.images.first.thumbnailUrl;

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color:
            LockMyLookUi.background,
        child: url == null ||
                url.isEmpty
            ? const Center(
                child: Icon(
                  Icons
                      .checkroom_outlined,
                  size: 38,
                  color:
                      LockMyLookUi.muted,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) =>
                        const Center(
                  child: Icon(
                    Icons
                        .broken_image_outlined,
                    size: 34,
                    color:
                        LockMyLookUi.muted,
                  ),
                ),
                loadingBuilder:
                    (
                  context,
                  child,
                  progress,
                ) =>
                        progress == null
                            ? child
                            : const Center(
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT ITEMS
  // ---------------------------------------------------------------------------

  Widget _recentItems() {
    final items =
        ref.watch(
          wardrobeControllerProvider,
        ).items;

    if (items.isEmpty) {
      return Container(
        height: 130,
        decoration:
            LockMyLookUi.cardDecoration(),
        child: const Center(
          child: Text(
            'No wardrobe items yet.',
            style: TextStyle(
              color:
                  LockMyLookUi.muted,
            ),
          ),
        ),
      );
    }

    final recent = [...items]
      ..sort(
        (a, b) =>
            b.createdAt.compareTo(
          a.createdAt,
        ),
      );

    final visible =
        recent.take(8).toList();

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item =
              visible[index];

          return Container(
            width: 112,
            padding:
                const EdgeInsets.all(8),
            decoration:
                LockMyLookUi
                    .cardDecoration(),
            child: Column(
              children: [
                Expanded(
                  child:
                      _recentItemImage(
                    item,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  item.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        LockMyLookUi.ink,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _recentItemImage(
    WardrobeItem item,
  ) {
    final url = item.images.isEmpty
        ? null
        : item.images.first.thumbnailUrl;

    if (url == null ||
        url.isEmpty) {
      return LockMyLookUi
          .imagePlaceholder(
        label: item.name,
        height: 78,
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) =>
                LockMyLookUi
                    .imagePlaceholder(
          label: item.name,
          height: 78,
        ),
        loadingBuilder:
            (
          context,
          child,
          progress,
        ) =>
                progress == null
                    ? child
                    : const Center(
                        child:
                            SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // QUICK ACTIONS
  // ---------------------------------------------------------------------------

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.all(15),
        decoration:
            LockMyLookUi.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    LockMyLookUi.coralSoft,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                icon,
                color:
                    LockMyLookUi.coral,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      color:
                          LockMyLookUi.ink,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          LockMyLookUi.muted,
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