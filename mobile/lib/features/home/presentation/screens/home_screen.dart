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
    if (_loadedProfileId == profileId && _todayPick.isNotEmpty) return;
    _loadedProfileId = profileId;
    setState(() => _todayPickLoading = true);
    try {
      await ref.read(wardrobeControllerProvider.notifier).loadItems(profileId);
      if (!mounted) return;
      await _loadCachedOrCreatePick(ref.read(wardrobeControllerProvider).items);
    } finally {
      if (mounted) setState(() => _todayPickLoading = false);
    }
  }

  Future<void> _loadCachedOrCreatePick(List<WardrobeItem> items) async {
    if (items.isEmpty) {
      setState(() => _todayPick = []);
      return;
    }
    final cachedDate = await _storage.read(key: _todayPickDateKey);
    final cachedIdsRaw = await _storage.read(key: _todayPickIdsKey);
    if (cachedDate == _todayKey() && cachedIdsRaw != null && cachedIdsRaw.isNotEmpty) {
      final ids = cachedIdsRaw.split(',').where((id) => id.isNotEmpty).toSet();
      final cached = items.where((item) => ids.contains(item.id)).toList();
      if (cached.isNotEmpty) {
        setState(() => _todayPick = cached);
        return;
      }
    }
    await _createNewTodayPick(items);
  }

  Future<void> _createNewTodayPick(List<WardrobeItem> items) async {
    if (items.isEmpty) return;
    final selected = _buildLocalOutfit(items, Random(DateTime.now().millisecondsSinceEpoch));
    if (selected.isEmpty) return;
    await _storage.write(key: _todayPickDateKey, value: _todayKey());
    await _storage.write(key: _todayPickIdsKey, value: selected.map((e) => e.id).join(','));
    if (mounted) setState(() => _todayPick = selected);
  }

  List<WardrobeItem> _buildLocalOutfit(List<WardrobeItem> items, Random random) {
    final available = [...items];
    if (available.length <= 3) {
      available.shuffle(random);
      return available;
    }
    final tops = available.where((item) {
      final c = item.category.name.toLowerCase();
      return c.contains('top') || c.contains('shirt') || c.contains('tee') || c.contains('t-shirt') || c.contains('hoodie') || c.contains('sweater');
    }).toList();
    final bottoms = available.where((item) {
      final c = item.category.name.toLowerCase();
      return c.contains('bottom') || c.contains('pant') || c.contains('jean') || c.contains('trouser') || c.contains('short') || c.contains('skirt');
    }).toList();
    final shoes = available.where((item) {
      final c = item.category.name.toLowerCase();
      return c.contains('shoe') || c.contains('sneaker') || c.contains('footwear');
    }).toList();
    final result = <WardrobeItem>[];
    void addRandom(List<WardrobeItem> source) {
      if (source.isEmpty) return;
      final item = source[random.nextInt(source.length)];
      if (!result.any((x) => x.id == item.id)) result.add(item);
    }
    addRandom(tops);
    addRandom(bottoms);
    addRandom(shoes);
    if (result.length < 3) {
      available.shuffle(random);
      for (final item in available) {
        if (!result.any((x) => x.id == item.id)) result.add(item);
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
      if (mounted) setState(() => _todayPickLoading = false);
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _displayName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
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
      context.push(AppRoutes.wardrobe, extra: id);
    }
  }

  void _openOutfits() {
    final id = _profileId;
    if (id == null) {
      context.push(AppRoutes.profiles);
    } else {
      context.push(AppRoutes.outfits, extra: id);
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
    final selected = state.profiles.isEmpty ? null : state.profiles.first;
    final greeting = selected == null ? 'there' : _displayName(selected.name);

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(profileControllerProvider.notifier).loadProfiles();
            if (!mounted) return;
            final profiles = ref.read(profileControllerProvider).profiles;
            if (profiles.isNotEmpty) await _loadWardrobeAndPick(profiles.first.id);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _heroHeader(greeting),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _profilesSection(state),
                    const SizedBox(height: 22),
                    _categoryStrip(),
                    const SizedBox(height: 24),
                    _styleStudioCard(),
                    const SizedBox(height: 26),
                    _todaySection(),
                    const SizedBox(height: 26),
                    _recentSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 0, onTap: _nav),
    );
  }

  Widget _heroHeader(String greeting) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: LockMyLookUi.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, $greeting', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 7),
                    const Text('Find your next\nfavorite look.', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.04, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.profiles),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(24), shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(35))),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 23),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openWardrobe,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Row(
                children: [
                  Icon(Icons.search, color: LockMyLookUi.navy, size: 21),
                  SizedBox(width: 10),
                  Expanded(child: Text('Search your wardrobe...', style: TextStyle(color: LockMyLookUi.muted, fontSize: 14))),
                  Icon(Icons.tune, color: LockMyLookUi.coral, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profilesSection(dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Style for', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: LockMyLookUi.ink))),
            GestureDetector(onTap: () => context.push(AppRoutes.profiles), child: const Text('Manage', style: TextStyle(color: LockMyLookUi.coral, fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: state.profiles.isEmpty
              ? GestureDetector(
                  onTap: () => context.push(AppRoutes.profiles),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: LockMyLookUi.border)),
                    child: const Row(children: [Icon(Icons.add_circle_outline, color: LockMyLookUi.coral), SizedBox(width: 10), Text('Create your first profile', style: TextStyle(fontWeight: FontWeight.w700, color: LockMyLookUi.ink))]),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.profiles.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 15),
                  itemBuilder: (context, index) {
                    if (index == state.profiles.length) {
                      return _profileBubble(label: 'Add', initial: '+', icon: Icons.add, selected: false, onTap: () => context.push(AppRoutes.profiles));
                    }
                    final profile = state.profiles[index];
                    return _profileBubble(
                      label: _displayName(profile.name),
                      avatarUrl: profile.avatarUrl,
                      initial: profile.name.trim().isEmpty ? '?' : profile.name.trim()[0].toUpperCase(),
                      selected: index == 0,
                      onTap: () => _selectProfile(profile.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _categoryStrip() {
    final categories = [
      ('All', Icons.grid_view_rounded),
      ('Tops', Icons.checkroom_outlined),
      ('Bottoms', Icons.straighten_outlined),
      ('Shoes', Icons.directions_run_outlined),
      ('Bags', Icons.shopping_bag_outlined),
      ('More', Icons.more_horiz_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Explore your closet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: LockMyLookUi.ink)),
        const SizedBox(height: 12),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, index) {
              final item = categories[index];
              final active = index == 0;
              return GestureDetector(
                onTap: _openWardrobe,
                child: SizedBox(
                  width: 54,
                  child: Column(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? LockMyLookUi.navy : Colors.white,
                          border: Border.all(color: active ? LockMyLookUi.navy : LockMyLookUi.border),
                          boxShadow: active ? [BoxShadow(color: LockMyLookUi.navy.withAlpha(30), blurRadius: 12, offset: const Offset(0, 5))] : null,
                        ),
                        child: Icon(item.$2, color: active ? Colors.white : LockMyLookUi.ink, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: LockMyLookUi.ink)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _styleStudioCard() {
    return GestureDetector(
      onTap: _openOutfits,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE9E7), Color(0xFFF1F3FF)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
          boxShadow: [BoxShadow(color: LockMyLookUi.coral.withAlpha(16), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.auto_awesome, color: LockMyLookUi.coral, size: 18), const SizedBox(width: 7), const Text('STYLE AI', style: TextStyle(color: LockMyLookUi.coral, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2))]),
                const SizedBox(height: 8),
                const Text('Let your wardrobe\ndo the styling.', style: TextStyle(color: LockMyLookUi.ink, fontSize: 20, height: 1.12, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Get five looks made for you.', style: TextStyle(color: LockMyLookUi.muted, fontSize: 12.5)),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                  decoration: BoxDecoration(color: LockMyLookUi.coral, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: LockMyLookUi.coral.withAlpha(35), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: const Text('Style me  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Container(width: 78, height: 118, decoration: BoxDecoration(color: Colors.white.withAlpha(205), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.style_outlined, size: 42, color: LockMyLookUi.navy)),
          ],
        ),
      ),
    );
  }

  Widget _todaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Today\'s Pick', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: LockMyLookUi.ink))),
          GestureDetector(onTap: _restyle, child: const Row(children: [Icon(Icons.refresh_rounded, color: LockMyLookUi.coral, size: 17), SizedBox(width: 4), Text('Restyle', style: TextStyle(color: LockMyLookUi.coral, fontWeight: FontWeight.w800))])),
        ]),
        const SizedBox(height: 12),
        _todayPickCard(),
      ],
    );
  }

  Widget _todayPickCard() {
    if (_todayPickLoading && _todayPick.isEmpty) {
      return Container(height: 270, decoration: LockMyLookUi.cardDecoration(), child: const Center(child: CircularProgressIndicator()));
    }
    if (_todayPick.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: LockMyLookUi.cardDecoration(),
        child: Column(children: [
          const Icon(Icons.checkroom_outlined, size: 42, color: LockMyLookUi.muted),
          const SizedBox(height: 12),
          const Text('Add a few wardrobe pieces and we\'ll build your first look.', textAlign: TextAlign.center, style: TextStyle(color: LockMyLookUi.muted, height: 1.4)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _openWardrobe, child: const Text('Add Items')),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 250, child: Row(children: [
          Expanded(flex: 3, child: _wardrobeImage(_todayPick[0])),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Column(children: [
            Expanded(child: _wardrobeImage(_todayPick.length > 1 ? _todayPick[1] : _todayPick[0])),
            const SizedBox(height: 8),
            Expanded(child: _wardrobeImage(_todayPick.length > 2 ? _todayPick[2] : _todayPick[0])),
          ])),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 13, 4, 5),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Today\'s Look', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: LockMyLookUi.ink)),
              const SizedBox(height: 3),
              Text('${_todayPick.length} pieces from your wardrobe', style: const TextStyle(fontSize: 11.5, color: LockMyLookUi.muted)),
            ])),
            GestureDetector(onTap: _openOutfits, child: Container(width: 38, height: 38, decoration: BoxDecoration(color: LockMyLookUi.coralSoft, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: LockMyLookUi.coral, size: 20))),
          ]),
        ),
      ]),
    );
  }

  Widget _recentSection() {
    final items = ref.watch(wardrobeControllerProvider).items;
    final recent = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final visible = recent.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('Recently Added', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: LockMyLookUi.ink))),
          GestureDetector(onTap: _openWardrobe, child: const Text('View all', style: TextStyle(color: LockMyLookUi.coral, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ]),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Container(height: 120, decoration: LockMyLookUi.cardDecoration(), child: const Center(child: Text('Your newest wardrobe pieces will appear here.', style: TextStyle(color: LockMyLookUi.muted))))
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final item = visible[index];
                return GestureDetector(
                  onTap: _openWardrobe,
                  child: Container(
                    width: 128,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 14, offset: const Offset(0, 5))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _recentItemImage(item)),
                      const SizedBox(height: 7),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: LockMyLookUi.ink))),
                    ]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _wardrobeImage(WardrobeItem item) {
    final url = item.images.isEmpty ? null : item.images.first.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: LockMyLookUi.background,
        child: url == null || url.isEmpty
            ? const Center(child: Icon(Icons.checkroom_outlined, size: 38, color: LockMyLookUi.muted))
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 34, color: LockMyLookUi.muted)), loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _recentItemImage(WardrobeItem item) {
    final url = item.images.isEmpty ? null : item.images.first.thumbnailUrl;
    if (url == null || url.isEmpty) return LockMyLookUi.imagePlaceholder(label: item.name, height: 95);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => LockMyLookUi.imagePlaceholder(label: item.name, height: 95), loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
    );
  }

  Widget _profileBubble({required String label, required String initial, required bool selected, String? avatarUrl, IconData? icon, VoidCallback? onTap}) {
    final isAdd = icon != null;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(alignment: Alignment.center, children: [
              if (!isAdd) Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: LockMyLookUi.coral, width: selected ? 3 : 2))),
              Container(
                width: selected ? 60 : 58,
                height: selected ? 60 : 58,
                decoration: BoxDecoration(shape: BoxShape.circle, color: isAdd ? Colors.white : LockMyLookUi.coralSoft, border: isAdd ? Border.all(color: LockMyLookUi.border, width: 2) : null),
                child: ClipOval(
                  child: isAdd
                      ? Icon(icon, color: LockMyLookUi.navy, size: 23)
                      : avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initial(initial))
                          : _initial(initial),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: LockMyLookUi.ink, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _initial(String initial) => Center(child: Text(initial, style: const TextStyle(color: LockMyLookUi.coral, fontWeight: FontWeight.w900, fontSize: 18)));
}
