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
  final _createKey = GlobalKey();

  File? _selectedTryOnPhoto;
  String? _editingProfileId;

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

  Future<void> _pickTryOnPhoto({required ImageSource source}) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1800,
      maxHeight: 2400,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedTryOnPhoto = File(picked.path));
  }

  Future<void> _showPhotoSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Try-On Photo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: LockMyLookUi.ink,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose how you want to add the profile photo.',
                  style: TextStyle(fontSize: 12, color: LockMyLookUi.muted),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _sourceTile(
                      Icons.camera_alt_rounded,
                      'Camera',
                      () {
                        Navigator.pop(sheetContext);
                        _pickTryOnPhoto(source: ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceTile(
                      Icons.photo_library_rounded,
                      'Gallery',
                      () {
                        Navigator.pop(sheetContext);
                        _pickTryOnPhoto(source: ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: LockMyLookUi.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: LockMyLookUi.coralSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: LockMyLookUi.coral, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: LockMyLookUi.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    final photo = _selectedTryOnPhoto;
    if (name.isEmpty || photo == null) {
      _showMessage('Add a profile name and a Try-On photo.');
      return;
    }

    final success = await ref
        .read(profileControllerProvider.notifier)
        .createProfileWithTryOnPhoto(name: name, file: photo);

    if (!mounted) return;
    if (success) {
      _nameController.clear();
      setState(() => _selectedTryOnPhoto = null);
      FocusScope.of(context).unfocus();
      _showMessage('Profile and Try-On photo saved.');
    } else {
      _showMessage(
        ref.read(profileControllerProvider).errorMessage ??
            'Could not create the profile.',
      );
    }
  }

  Future<void> _updateTryOnPhoto(String profileId) async {
    final photo = _selectedTryOnPhoto;
    if (photo == null) {
      _showMessage('Choose a Try-On photo first.');
      return;
    }

    final success = await ref
        .read(profileControllerProvider.notifier)
        .uploadTryOnPhoto(profileId: profileId, file: photo);

    if (!mounted) return;
    if (success) {
      setState(() {
        _selectedTryOnPhoto = null;
        _editingProfileId = null;
      });
      _showMessage('Try-On photo updated.');
    } else {
      _showMessage(
        ref.read(profileControllerProvider).errorMessage ??
            'Could not update the Try-On photo.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  String _imageUrl(String rawUrl) {
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final origin = ApiConstants.baseUrl.endsWith('/api/v1')
        ? ApiConstants.baseUrl.substring(
            0,
            ApiConstants.baseUrl.length - '/api/v1'.length,
          )
        : ApiConstants.baseUrl;
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _topHeader(),
            const SizedBox(height: 16),
            _heroBanner(state.profiles.length),
            const SizedBox(height: 16),
            _createProfileCard(isLoading),
            const SizedBox(height: 24),
            _profilesHeader(state.profiles.length),
            const SizedBox(height: 10),
            if (state.status == ProfileStatus.loading && state.profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.profiles.isEmpty)
              _emptyProfiles()
            else
              ...state.profiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _profileCard(profile, isLoading),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: LmlBottomNav(currentIndex: 3, onTap: _nav),
    );
  }

  Widget _topHeader() {
    return Row(
      children: [
        _circleButton(
          Icons.arrow_back_rounded,
          () => context.go(AppRoutes.home),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR STYLE SPACE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w900,
                  color: LockMyLookUi.coral,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Profiles',
                style: TextStyle(
                  fontSize: 25,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: LockMyLookUi.ink,
                ),
              ),
            ],
          ),
        ),
        _circleButton(
          Icons.auto_awesome_rounded,
          () => Scrollable.ensureVisible(
            _createKey.currentContext!,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          ),
          accent: true,
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {bool accent = false}) {
    return Material(
      color: accent ? LockMyLookUi.coral : Colors.white,
      elevation: accent ? 4 : 2,
      shadowColor: accent
          ? LockMyLookUi.coral.withValues(alpha: .22)
          : Colors.black.withValues(alpha: .07),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 20,
            color: accent ? Colors.white : LockMyLookUi.ink,
          ),
        ),
      ),
    );
  }

  Widget _heroBanner(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF141522),
            const Color(0xFF1D1D2B),
            LockMyLookUi.coral.withValues(alpha: .86),
          ],
          stops: const [0, .58, 1],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -38,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  _darkPill(
                    '$count ${count == 1 ? 'profile' : 'profiles'}',
                  ),
                ],
              ),
              const SizedBox(height: 17),
              const Text(
                'Everyone gets\ntheir own style.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.03,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep photos, wardrobes and Virtual Try-On looks separate.',
                style: TextStyle(
                  color: Color(0xFFD5D7E0),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _createProfileCard(bool isLoading) {
    return Container(
      key: _createKey,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: LockMyLookUi.coralSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: LockMyLookUi.coral,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a new profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: LockMyLookUi.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'One photo is all you need to get started.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: LockMyLookUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Profile name',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              filled: true,
              fillColor: LockMyLookUi.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: LockMyLookUi.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: LockMyLookUi.coral,
                  width: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tryOnPhotoPicker(compact: true),
          const SizedBox(height: 9),
          const Text(
            'Use a clear full-body photo for the best Virtual Try-On results.',
            style: TextStyle(
              fontSize: 10.5,
              color: LockMyLookUi.muted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 51,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _createProfile,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 19),
              label: Text(isLoading ? 'Saving...' : 'Create Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LockMyLookUi.coral,
                foregroundColor: Colors.white,
                elevation: 5,
                shadowColor: LockMyLookUi.coral.withValues(alpha: .28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tryOnPhotoPicker({bool compact = false}) {
    final photo = _selectedTryOnPhoto;

    return InkWell(
      onTap: _showPhotoSourcePicker,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: compact ? 168 : 205,
        decoration: BoxDecoration(
          color: LockMyLookUi.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LockMyLookUi.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Stack(
                children: [
                  Positioned(
                    right: 13,
                    top: 13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: LockMyLookUi.coralSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          color: LockMyLookUi.coral,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 34,
                          color: LockMyLookUi.coral,
                        ),
                        SizedBox(height: 9),
                        Text(
                          'Add Try-On Photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: LockMyLookUi.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Camera or Gallery',
                          style: TextStyle(
                            fontSize: 11,
                            color: LockMyLookUi.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(photo, fit: BoxFit.cover),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Photo selected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: .60),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _showPhotoSourcePicker,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(9),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _profilesHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Your profiles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LockMyLookUi.ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LockMyLookUi.border),
          ),
          child: Text(
            '$count total',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: LockMyLookUi.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyProfiles() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: LockMyLookUi.cardDecoration(),
      child: const Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 40,
            color: LockMyLookUi.muted,
          ),
          SizedBox(height: 10),
          Text(
            'No profiles yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: LockMyLookUi.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Create the first profile above.',
            style: TextStyle(fontSize: 12, color: LockMyLookUi.muted),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(Profile profile, bool isLoading) {
    final isEditing = _editingProfileId == profile.id;
    final hasPhoto =
        profile.avatarUrl != null && profile.avatarUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(profile.name, profile.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: LockMyLookUi.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: hasPhoto
                                ? const Color(0xFF36B37E)
                                : LockMyLookUi.coral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasPhoto ? 'Try-On ready' : 'Photo needed',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: LockMyLookUi.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _deleteButton(
                isLoading
                    ? null
                    : () => ref
                        .read(profileControllerProvider.notifier)
                        .deleteProfile(profile.id),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _profileActionButton(
                  icon: isEditing
                      ? Icons.close_rounded
                      : Icons.add_a_photo_outlined,
                  label: isEditing ? 'Cancel' : 'Change Photo',
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            _editingProfileId =
                                isEditing ? null : profile.id;
                            _selectedTryOnPhoto = null;
                          });
                        },
                  primary: false,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _profileActionButton(
                  icon: Icons.checkroom_rounded,
                  label: 'Wardrobe',
                  onPressed: isLoading
                      ? null
                      : () => context.push(
                            AppRoutes.wardrobe,
                            extra: profile.id,
                          ),
                  primary: true,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            _tryOnPhotoPicker(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    isLoading || _selectedTryOnPhoto == null
                        ? null
                        : () => _updateTryOnPhoto(profile.id),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Save Try-On Photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deleteButton(VoidCallback? onPressed) {
    return Material(
      color: LockMyLookUi.background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            Icons.delete_outline_rounded,
            size: 19,
            color: LockMyLookUi.muted,
          ),
        ),
      ),
    );
  }

  Widget _profileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool primary,
  }) {
    final enabled = onPressed != null;
    final foreground = primary ? Colors.white : LockMyLookUi.ink;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .45,
      child: Material(
        color: primary ? LockMyLookUi.coral : Colors.white,
        elevation: primary ? 4 : 0,
        shadowColor: LockMyLookUi.coral.withValues(alpha: .24),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: primary
                  ? null
                  : Border.all(color: LockMyLookUi.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: foreground),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return Container(
        width: 58,
        height: 58,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [LockMyLookUi.coral, LockMyLookUi.coralSoft],
          ),
        ),
        child: ClipOval(
          child: Image.network(
            _imageUrl(avatarUrl),
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _initialAvatar(name),
          ),
        ),
      );
    }
    return _initialAvatar(name);
  }

  Widget _initialAvatar(String name) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LockMyLookUi.coralSoft,
        border: Border.all(
          color: LockMyLookUi.coral.withValues(alpha: .18),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: LockMyLookUi.coral,
          fontSize: 19,
        ),
      ),
    );
  }
}
