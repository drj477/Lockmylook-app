import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/constants/api_constants.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/profiles/application/profile_controller.dart';
import 'package:mobile/features/profiles/application/profile_providers.dart';
import 'package:mobile/features/profiles/data/models/profile_models.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _selectedTryOnPhoto;
  String? _editingProfileId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileControllerProvider.notifier).loadProfiles());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTryOnPhoto({required ImageSource source}) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 92, maxWidth: 1800, maxHeight: 2400);
    if (!mounted || picked == null) return;
    setState(() => _selectedTryOnPhoto = File(picked.path));
  }

  Future<void> _showPhotoSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Choose Try-On Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: LockMyLookUi.ink))),
              const SizedBox(height: 12),
              ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take Photo'), onTap: () { Navigator.pop(sheetContext); _pickTryOnPhoto(source: ImageSource.camera); }),
              ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(sheetContext); _pickTryOnPhoto(source: ImageSource.gallery); }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    final photo = _selectedTryOnPhoto;
    if (name.isEmpty || photo == null) { _showMessage('Add a profile name and a Try-On photo.'); return; }
    final success = await ref.read(profileControllerProvider.notifier).createProfileWithTryOnPhoto(name: name, file: photo);
    if (!mounted) return;
    if (success) {
      _nameController.clear();
      setState(() => _selectedTryOnPhoto = null);
      FocusScope.of(context).unfocus();
      _showMessage('Profile and Try-On photo saved.');
    } else {
      _showMessage(ref.read(profileControllerProvider).errorMessage ?? 'Could not create the profile.');
    }
  }

  Future<void> _updateTryOnPhoto(String profileId) async {
    final photo = _selectedTryOnPhoto;
    if (photo == null) { _showMessage('Choose a Try-On photo first.'); return; }
    final success = await ref.read(profileControllerProvider.notifier).uploadTryOnPhoto(profileId: profileId, file: photo);
    if (!mounted) return;
    if (success) {
      setState(() { _selectedTryOnPhoto = null; _editingProfileId = null; });
      _showMessage('Try-On photo updated.');
    } else {
      _showMessage(ref.read(profileControllerProvider).errorMessage ?? 'Could not update the Try-On photo.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  void _nav(int index) {
    switch (index) {
      case 0: context.go(AppRoutes.home); return;
      case 1:
        final profiles = ref.read(profileControllerProvider).profiles;
        if (profiles.isNotEmpty) context.push(AppRoutes.wardrobe, extra: profiles.first.id);
        return;
      case 2:
        final profiles = ref.read(profileControllerProvider).profiles;
        if (profiles.isNotEmpty) context.push(AppRoutes.outfits, extra: profiles.first.id);
        return;
      case 3: return;
    }
  }

  String _imageUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) return rawUrl;
    final origin = ApiConstants.baseUrl.endsWith('/api/v1') ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - '/api/v1'.length) : ApiConstants.baseUrl;
    final path = rawUrl.startsWith('/') ? rawUrl.substring(1) : rawUrl;
    return '$origin/$path';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final isLoading = state.status == ProfileStatus.loading;
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            _profileHeader(),
            const SizedBox(height: 22),
            _createProfileCard(isLoading),
            const SizedBox(height: 24),
            LockMyLookUi.sectionTitle('Profiles', action: '${state.profiles.length} total'),
            const SizedBox(height: 10),
            if (state.status == ProfileStatus.loading && state.profiles.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (state.profiles.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No profiles yet.', style: TextStyle(color: LockMyLookUi.muted))))
            else ...state.profiles.map((profile) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _profileCard(profile, isLoading))),
          ],
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 3, onTap: _nav),
    );
  }

  Widget _profileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              child: IconButton(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                color: LockMyLookUi.ink,
                tooltip: 'Back',
              ),
            ),
            const SizedBox(width: 10),
            const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: LockMyLookUi.ink)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                LockMyLookUi.coralSoft.withValues(alpha: 0.34),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: LockMyLookUi.coral.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LockMyLookUi.coral,
                  boxShadow: [BoxShadow(color: LockMyLookUi.coral.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.people_alt_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Family Wardrobe', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: LockMyLookUi.ink, height: 1.05)),
                    SizedBox(height: 7),
                    Text('Everyone gets their own style space.', style: TextStyle(fontSize: 13, color: LockMyLookUi.muted, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _createProfileCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.055), blurRadius: 18, offset: const Offset(0, 7)),
          BoxShadow(color: LockMyLookUi.coral.withValues(alpha: 0.06), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: LockMyLookUi.coralSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome_rounded, color: LockMyLookUi.coral, size: 20),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create a new style profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: LockMyLookUi.ink)),
                    SizedBox(height: 2),
                    Text('Add a name and one full-body photo.', style: TextStyle(fontSize: 11.5, color: LockMyLookUi.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Profile name', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          _tryOnPhotoPicker(),
          const SizedBox(height: 9),
          const Text('Save one clear full-body photo. LockMyLook will reuse it automatically for Virtual Try-On.', style: TextStyle(fontSize: 11, color: LockMyLookUi.muted, height: 1.35)),
          const SizedBox(height: 13),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _createProfile,
              icon: isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded, size: 20),
              label: Text(isLoading ? 'Saving...' : 'Create Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LockMyLookUi.coral,
                foregroundColor: Colors.white,
                elevation: 5,
                shadowColor: LockMyLookUi.coral.withValues(alpha: 0.28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tryOnPhotoPicker() {
    final photo = _selectedTryOnPhoto;
    return InkWell(
      onTap: _showPhotoSourcePicker,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 210,
        decoration: BoxDecoration(color: LockMyLookUi.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: LockMyLookUi.border)),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 36, color: LockMyLookUi.coral), SizedBox(height: 10), Text('Add Try-On Photo', style: TextStyle(fontWeight: FontWeight.w800, color: LockMyLookUi.ink)), SizedBox(height: 4), Text('Camera or Gallery', style: TextStyle(fontSize: 12, color: LockMyLookUi.muted))])
            : Stack(fit: StackFit.expand, children: [Image.file(photo, fit: BoxFit.cover), Positioned(right: 10, top: 10, child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit, size: 18, color: Colors.white))))]),
      ),
    );
  }

  Widget _profileCard(Profile profile, bool isLoading) {
    final isEditing = _editingProfileId == profile.id;
    final hasPhoto = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: LockMyLookUi.cardDecoration(),
      child: Column(children: [
        Row(children: [
          _avatar(profile.name, profile.avatarUrl),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: LockMyLookUi.ink)), const SizedBox(height: 4), Text(hasPhoto ? 'Try-On photo ready' : 'Add a Try-On photo', style: const TextStyle(fontSize: 12, color: LockMyLookUi.muted))])),
          IconButton(onPressed: isLoading ? null : () => ref.read(profileControllerProvider.notifier).deleteProfile(profile.id), icon: const Icon(Icons.delete_outline, color: LockMyLookUi.muted)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _profileActionButton(icon: isEditing ? Icons.close_rounded : Icons.add_a_photo_outlined, label: isEditing ? 'Cancel' : 'Change Photo', onPressed: isLoading ? null : () { setState(() { _editingProfileId = isEditing ? null : profile.id; _selectedTryOnPhoto = null; }); }, primary: false)),
          const SizedBox(width: 10),
          Expanded(child: _profileActionButton(icon: Icons.checkroom_rounded, label: 'Wardrobe', onPressed: isLoading ? null : () => context.push(AppRoutes.wardrobe, extra: profile.id), primary: true)),
        ]),
        if (isEditing) ...[
          const SizedBox(height: 12),
          _tryOnPhotoPicker(),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isLoading || _selectedTryOnPhoto == null ? null : () => _updateTryOnPhoto(profile.id), icon: const Icon(Icons.save_outlined), label: const Text('Save Try-On Photo'))),
        ],
      ]),
    );
  }

  Widget _profileActionButton({required IconData icon, required String label, required VoidCallback? onPressed, required bool primary}) {
    final enabled = onPressed != null;
    final background = primary ? LockMyLookUi.coral : Colors.white;
    final foreground = primary ? Colors.white : LockMyLookUi.coral;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: primary ? null : Border.all(color: LockMyLookUi.coral.withValues(alpha: 0.22), width: 1),
              boxShadow: [
                BoxShadow(color: primary ? LockMyLookUi.coral.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 5)),
                if (!primary) BoxShadow(color: LockMyLookUi.coral.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: primary ? Colors.white.withValues(alpha: 0.16) : LockMyLookUi.coralSoft, shape: BoxShape.circle), child: Icon(icon, size: 16, color: foreground)),
              const SizedBox(width: 8),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: foreground, letterSpacing: 0.1))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return ClipOval(child: Image.network(_imageUrl(avatarUrl), width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initialAvatar(name)));
    }
    return _initialAvatar(name);
  }

  Widget _initialAvatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(width: 52, height: 52, decoration: const BoxDecoration(shape: BoxShape.circle, color: LockMyLookUi.coralSoft), alignment: Alignment.center, child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800, color: LockMyLookUi.coral, fontSize: 18)));
  }
}
