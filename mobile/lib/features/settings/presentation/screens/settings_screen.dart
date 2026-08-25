import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/app/routes.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';
import 'package:mobile/features/credits/application/credit_providers.dart';
import 'package:mobile/features/credits/data/models/credit_models.dart';
import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  VirtualTryOnModel _defaultModel = VirtualTryOnModel.dTryon;

  @override
  Widget build(BuildContext context) {
    final creditState = ref.watch(creditBalanceProvider);
    final balance = creditState.valueOrNull;

    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          _accountCard(),
          const SizedBox(height: 24),
          _sectionLabel('AI & VIRTUAL TRY-ON'),
          const SizedBox(height: 10),
          _settingTile(
            icon: Icons.bolt_rounded,
            title: 'Credits',
            subtitle: _balanceSubtitle(creditState, balance),
            accent: true,
            onTap: _showCredits,
          ),
          _settingTile(
            icon: Icons.auto_awesome_mosaic_rounded,
            title: 'VTO History & Saved Looks',
            subtitle: 'View and delete generated results',
            onTap: () => context.push(AppRoutes.vtoHistory),
          ),
          _settingTile(
            icon: Icons.tune_rounded,
            title: 'Default Try-On Model',
            subtitle: _modelLabel(_defaultModel),
            onTap: _showDefaultModel,
          ),
          const SizedBox(height: 24),
          _sectionLabel('FAMILY'),
          const SizedBox(height: 10),
          _settingTile(
            icon: Icons.groups_rounded,
            title: 'Family Profiles',
            subtitle: 'Manage people and their wardrobes',
            onTap: () => context.push(AppRoutes.profiles),
          ),
          const SizedBox(height: 24),
          _sectionLabel('APP'),
          const SizedBox(height: 10),
          _settingTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Generation and credit alerts',
            onTap: () => _showInfo('Notifications', 'Notification controls will be connected here.'),
          ),
          _settingTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'System default',
            onTap: () => _showInfo('Appearance', 'Theme selection will be connected here.'),
          ),
          _settingTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English',
            onTap: () => _showInfo('Language', 'Language selection will be connected here.'),
          ),
          const SizedBox(height: 24),
          _sectionLabel('PRIVACY & SECURITY'),
          const SizedBox(height: 10),
          _settingTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & Data',
            subtitle: 'Manage your LockMyLook data',
            onTap: _showPrivacy,
          ),
          _settingTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Sign out of this device',
            onTap: _showSignOut,
          ),
          const SizedBox(height: 24),
          _sectionLabel('SUPPORT'),
          const SizedBox(height: 10),
          _settingTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get help with LockMyLook',
            onTap: () => _showInfo('Help & Support', 'Support tools will be connected here.'),
          ),
          _settingTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Problem',
            subtitle: 'Tell us what went wrong',
            onTap: () => _showInfo('Report a Problem', 'Problem reporting will be connected here.'),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'LockMyLook\nVersion 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LockMyLookUi.muted.withAlpha(180),
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _showDeleteAccount,
            child: const Text(
              'Delete Account',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _balanceSubtitle(
    AsyncValue<CreditBalance> state,
    CreditBalance? balance,
  ) {
    if (balance != null) {
      return '${_formatCredits(balance.balanceCredits)} credits available';
    }
    if (state.isLoading) return 'Loading balance...';
    return 'Unable to load balance';
  }

  String _formatCredits(double credits) {
    return credits == credits.roundToDouble()
        ? credits.toInt().toString()
        : credits.toStringAsFixed(1);
  }

  Widget _accountCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LockMyLookUi.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: LockMyLookUi.coral,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Account', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('Manage your LockMyLook account', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: LockMyLookUi.muted,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withAlpha(8)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent ? LockMyLookUi.coralSoft : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: accent ? LockMyLookUi.coral : LockMyLookUi.ink, size: 21),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LockMyLookUi.ink)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle, style: const TextStyle(fontSize: 10.5, color: LockMyLookUi.muted)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: LockMyLookUi.muted),
      ),
    );
  }

  String _modelLabel(VirtualTryOnModel model) => switch (model) {
        VirtualTryOnModel.dTryon => 'Quick Try-On · D-Tryon',
        VirtualTryOnModel.gemini => 'Premium Try-On · Gemini',
        VirtualTryOnModel.geminiChat => 'Gemini Chat',
        VirtualTryOnModel.replicate => 'Replicate',
      };

  void _showDefaultModel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Default Try-On Model',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose which model opens by default.',
                style: TextStyle(color: LockMyLookUi.muted),
              ),
            ),
            const SizedBox(height: 16),
            for (final model in [
              VirtualTryOnModel.dTryon,
              VirtualTryOnModel.gemini,
            ])
              _modelOption(model),
          ],
        ),
      ),
    );
  }

  Widget _modelOption(VirtualTryOnModel model) {
    final selected = _defaultModel == model;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? LockMyLookUi.coralSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? LockMyLookUi.coral : Colors.black.withAlpha(10),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _defaultModel = model);
          Navigator.pop(context);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? LockMyLookUi.coral : const Color(0xFFF3F4F6),
          ),
          child: Icon(
            selected ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? Colors.white : LockMyLookUi.muted,
            size: 19,
          ),
        ),
        title: Text(
          _modelLabel(model),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          model == VirtualTryOnModel.dTryon
              ? '2 credits per generation'
              : '2 credits per generation · Gemini 3.1 · 1K',
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: LockMyLookUi.coral)
            : null,
      ),
    );
  }

  Future<void> _showCredits() async {
    final balance = await _loadCreditBalance();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Credits', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              balance == null
                  ? 'Unable to load balance'
                  : '${_formatCredits(balance.balanceCredits)} credits available',
              style: const TextStyle(color: LockMyLookUi.muted),
            ),
            const SizedBox(height: 20),
            _creditRow('Paid generation · D-Tryon', '2 credits'),
            _creditRow('Paid generation · Gemini Image', '2 credits'),
            _creditRow('Gemini Chat', '1 credit'),
            _creditRow('Cached result', '0.5 credit'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showInfo(
                  'Buy Credits',
                  'Payment packages will be connected when billing is enabled.',
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buy Credits'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<CreditBalance?> _loadCreditBalance() async {
    try {
      final balance = await ref.read(creditApiProvider).getBalance();
      ref.invalidate(creditBalanceProvider);
      return balance;
    } catch (_) {
      return null;
    }
  }

  Widget _creditRow(String name, String cost) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text(
              cost,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: LockMyLookUi.coral,
              ),
            ),
          ],
        ),
      );

  void _showPrivacy() => _showInfo(
        'Privacy & Data',
        'Your wardrobe, profiles and generated looks are stored under your account. Data controls will be connected to the account API.',
      );

  void _showSignOut() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('You will need to sign in again on this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );

  void _showDeleteAccount() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This will permanently delete your account, profiles, wardrobe, generated looks and account data. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Delete Permanently',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  void _showInfo(String title, String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}
