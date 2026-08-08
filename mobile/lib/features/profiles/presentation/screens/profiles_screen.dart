import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/profiles/application/profile_controller.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _nameController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final success = await ref
        .read(profileControllerProvider.notifier)
        .createProfile(name: name);

    if (!mounted) {
      return;
    }

    if (success) {
      _nameController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _deleteProfile(String profileId) async {
    await ref.read(profileControllerProvider.notifier).deleteProfile(profileId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your Profiles',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create profiles to organize your wardrobe and outfits.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  hintText: 'e.g. Personal',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _createProfile(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: state.status == ProfileStatus.loading
                    ? null
                    : _createProfile,
                child: const Text('Create Profile'),
              ),
              const SizedBox(height: 24),
              if (state.status == ProfileStatus.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              if (state.errorMessage != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.errorMessage!)),
                        IconButton(
                          onPressed: () {
                            ref
                                .read(profileControllerProvider.notifier)
                                .clearError();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: _buildProfileList(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileList(ProfileState state) {
    if (state.status == ProfileStatus.loading && state.profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status != ProfileStatus.loading && state.profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles yet.\nCreate your first profile above.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: state.profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final profile = state.profiles[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(profile.id),
            trailing: IconButton(
              tooltip: 'Delete profile',
              icon: const Icon(Icons.delete_outline),
              onPressed: state.status == ProfileStatus.loading
                  ? null
                  : () => _deleteProfile(profile.id),
            ),
          ),
        );
      },
    );
  }
}
