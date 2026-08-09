import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/profiles/application/profile_controller.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _nameController = TextEditingController();
  final _avatarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).loadProfiles(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    final avatarUrl = _avatarController.text.trim();

    if (name.isEmpty) return;

    final success = await ref
        .read(profileControllerProvider.notifier)
        .createProfile(
          name: name,
          avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
        );

    if (!mounted) return;

    if (success) {
      _nameController.clear();
      _avatarController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _nav(int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        return;
      case 1:
        final profiles = ref.read(profileControllerProvider).profiles;
        if (profiles.isNotEmpty) {
          context.push(AppRoutes.wardrobe, extra: profiles.first.id);
        }
        return;
      case 2:
        final profiles = ref.read(profileControllerProvider).profiles;
        if (profiles.isNotEmpty) {
          context.push(AppRoutes.outfits, extra: profiles.first.id);
        }
        return;
      case 3:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: LockMyLookUi.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Family Wardrobe',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: LockMyLookUi.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create profiles for everyone and keep each wardrobe separate.',
              style: TextStyle(color: LockMyLookUi.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: LockMyLookUi.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add New Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LockMyLookUi.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Profile name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _avatarController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Profile image URL (optional)',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                    onSubmitted: (_) => _createProfile(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This image is used automatically for Virtual Try-On. '
                    'You will not be asked for a photo every time.',
                    style: TextStyle(
                      fontSize: 11,
                      color: LockMyLookUi.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: state.status == ProfileStatus.loading
                        ? null
                        : _createProfile,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LockMyLookUi.sectionTitle(
              'Profiles',
              action: '${state.profiles.length} total',
            ),
            const SizedBox(height: 8),
            if (state.status == ProfileStatus.loading &&
                state.profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'No profiles yet.',
                    style: TextStyle(color: LockMyLookUi.muted),
                  ),
                ),
              )
            else
              ...state.profiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.wardrobe,
                      extra: profile.id,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: LockMyLookUi.cardDecoration(),
                      child: Row(
                        children: [
                          _avatar(profile.name, profile.avatarUrl),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: LockMyLookUi.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.avatarUrl == null ||
                                          profile.avatarUrl!.isEmpty
                                      ? 'Add a profile image for Virtual Try-On'
                                      : 'Profile image ready for Virtual Try-On',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: LockMyLookUi.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: state.status == ProfileStatus.loading
                                ? null
                                : () => ref
                                    .read(profileControllerProvider.notifier)
                                    .deleteProfile(profile.id),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: LockMyLookUi.muted,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: LockMyLookUi.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 3, onTap: _nav),
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialAvatar(name),
        ),
      );
    }

    return _initialAvatar(name);
  }

  Widget _initialAvatar(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: LockMyLookUi.coralSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            color: LockMyLookUi.coral,
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
      ),
    );
  }
}
