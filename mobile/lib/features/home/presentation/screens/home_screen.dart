import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/profiles/application/profile_controller.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).loadProfiles();
    });
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
      case 2:
        _openOutfits();
      case 3:
        context.push(AppRoutes.profiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final name = profileState.profiles.isEmpty ? 'there' : profileState.profiles.first.name;

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(profileControllerProvider.notifier).loadProfiles(),
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
                        Text('Hi, ${name == 'there' ? 'there' : name} 👋', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: LockMyLookUi.ink)),
                        const SizedBox(height: 4),
                        const Text('Ready to style your day?', style: TextStyle(color: LockMyLookUi.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: LockMyLookUi.navy, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.person_outline, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LockMyLookUi.sectionTitle('My Profiles', action: 'Manage', onAction: () => context.push(AppRoutes.profiles)),
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: profileState.profiles.isEmpty
                    ? const Center(child: Text('Create a profile to get started', style: TextStyle(color: LockMyLookUi.muted)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: profileState.profiles.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          if (index == profileState.profiles.length) {
                            return _profileBubble(label: 'Add', icon: Icons.add, onTap: () => context.push(AppRoutes.profiles));
                          }
                          final profile = profileState.profiles[index];
                          return _profileBubble(label: profile.name, initial: profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(), onTap: () => context.push(AppRoutes.wardrobe, extra: profile.id));
                        },
                      ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEDF2FF), Color(0xFFFFE9E6)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.auto_awesome, color: LockMyLookUi.coral, size: 19), SizedBox(width: 7), Text('AI Outfit Suggestions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LockMyLookUi.ink))]),
                          const SizedBox(height: 8),
                          const Text('Get 5 best outfit ideas for your occasion and mood.', style: TextStyle(color: LockMyLookUi.muted, height: 1.35)),
                          const SizedBox(height: 14),
                          ElevatedButton(onPressed: _openOutfits, child: const Text('Get Started')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 78, height: 105, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.style_outlined, size: 44, color: LockMyLookUi.navy)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _quickCard(icon: Icons.checkroom_outlined, title: 'My Wardrobe', value: 'Your items', onTap: _openWardrobe)),
                  const SizedBox(width: 12),
                  Expanded(child: _quickCard(icon: Icons.auto_awesome_outlined, title: 'Outfits', value: 'Style ideas', onTap: _openOutfits)),
                ],
              ),
              const SizedBox(height: 24),
              LockMyLookUi.sectionTitle('Recent Items', action: 'View All', onAction: _openWardrobe),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => Container(
                    width: 112,
                    padding: const EdgeInsets.all(8),
                    decoration: LockMyLookUi.cardDecoration(),
                    child: Column(
                      children: [
                        Expanded(child: LockMyLookUi.imagePlaceholder(label: ['Black Tee', 'White Hoodie', 'Denim', 'Linen', 'Sneakers'][index], height: 78)),
                        const SizedBox(height: 6),
                        Text(['Black Tee', 'White Hoodie', 'Denim', 'Linen', 'Sneakers'][index], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LockMyLookUi.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 0, onTap: _nav),
    );
  }

  Widget _profileBubble({required String label, String? initial, IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: initial == null ? Colors.white : LockMyLookUi.coralSoft, shape: BoxShape.circle, border: Border.all(color: initial == null ? LockMyLookUi.border : LockMyLookUi.coral, width: 1.5)), child: Center(child: Icon(icon, color: LockMyLookUi.navy, size: 23) ?? Text(initial!))),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: LockMyLookUi.ink)),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: LockMyLookUi.cardDecoration(),
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: LockMyLookUi.coralSoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: LockMyLookUi.coral)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: LockMyLookUi.ink)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 12, color: LockMyLookUi.muted))])),
          ],
        ),
      ),
    );
  }
}
