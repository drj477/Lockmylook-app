import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      height: 76,
      backgroundColor: Colors.white,
      indicatorColor: LockMyLookUi.coralSoft,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.checkroom_outlined),
          selectedIcon: Icon(Icons.checkroom),
          label: 'Wardrobe',
        ),
        NavigationDestination(
          icon: Icon(Icons.auto_awesome_outlined),
          selectedIcon: Icon(Icons.auto_awesome),
          label: 'Style AI',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
