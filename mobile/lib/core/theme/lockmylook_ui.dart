import 'package:flutter/material.dart';

import 'package:mobile/app/routes.dart';

abstract final class LockMyLookUi {
  const LockMyLookUi._();

  static const navy = Color(0xFF0B1B35);
  static const navy2 = Color(0xFF132A4A);
  static const coral = Color(0xFFFF6F61);
  static const coralSoft = Color(0xFFFFE7E3);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF697386);
  static const background = Color(0xFFF8F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E5E3);

  static const radiusLg = 24.0;
  static const radiusMd = 18.0;
  static const radiusSm = 14.0;

  static BoxDecoration cardDecoration({Color color = surface}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(color: border),
      boxShadow: const [
        BoxShadow(
          blurRadius: 18,
          offset: Offset(0, 6),
          color: Color(0x0D000000),
        ),
      ],
    );
  }

  static Widget sectionTitle(
    String title, {
    String? action,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: coral),
            child: Text(action),
          ),
      ],
    );
  }

  static Widget pill(String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? navy : surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: selected ? navy : border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : ink,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  static Widget imagePlaceholder({
    required String label,
    IconData icon = Icons.checkroom_outlined,
    double? height,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF7D8490)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LmlBottomNav extends StatelessWidget {
  const LmlBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.checkroom_outlined, Icons.checkroom_rounded, 'Wardrobe'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Style AI'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x120B1B35),
            blurRadius: 22,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 7, 12, 4),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == currentIndex;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.$3,
                child: InkWell(
                  onTap: () {
                    if (index == 4) {
                      context.push(AppRoutes.settings);
                    } else {
                      onTap(index);
                    }
                  },
                  borderRadius: BorderRadius.circular(18),
                  splashColor: LockMyLookUi.coralSoft,
                  highlightColor: LockMyLookUi.coralSoft.withValues(alpha: 0.35),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? LockMyLookUi.coralSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: selected ? 1.08 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            selected ? item.$2 : item.$1,
                            size: selected ? 23 : 22,
                            color: selected
                                ? LockMyLookUi.coral
                                : LockMyLookUi.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: selected
                                ? LockMyLookUi.navy
                                : LockMyLookUi.muted,
                            fontSize: 11.5,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                          child: Text(item.$3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
