import 'package:flutter/material.dart';
import 'package:mobile/core/theme/lockmylook_ui.dart';

class BuyCreditsScreen extends StatelessWidget {
  const BuyCreditsScreen({super.key});

  static const _packages = [
    _CreditPackage(
      code: 'basic',
      name: 'Basic',
      credits: 10,
      price: 50,
      description: 'A quick credit boost',
    ),
    _CreditPackage(
      code: 'starter',
      name: 'Starter',
      credits: 20,
      price: 100,
      description: 'For occasional try-ons',
    ),
    _CreditPackage(
      code: 'standard',
      name: 'Standard',
      credits: 50,
      price: 250,
      description: 'For regular styling',
      featured: true,
    ),
    _CreditPackage(
      code: 'pro',
      name: 'Pro',
      credits: 100,
      price: 500,
      description: 'For heavy styling use',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LockMyLookUi.background,
      appBar: AppBar(
        title: const Text(
          'Buy Credits',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Power your next look',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: LockMyLookUi.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a credit package. 1 credit = ₹5.',
            style: TextStyle(color: LockMyLookUi.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          for (final package in _packages) _PackageCard(package: package),
          const SizedBox(height: 12),
          const Text(
            'Payments will be securely verified before credits are added to your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LockMyLookUi.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CreditPackage {
  const _CreditPackage({
    required this.code,
    required this.name,
    required this.credits,
    required this.price,
    required this.description,
    this.featured = false,
  });

  final String code;
  final String name;
  final int credits;
  final int price;
  final String description;
  final bool featured;
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});

  final _CreditPackage package;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: package.featured
              ? LockMyLookUi.coral
              : Colors.black.withAlpha(10),
          width: package.featured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: LockMyLookUi.ink,
                          ),
                        ),
                        if (package.featured) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: LockMyLookUi.coralSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'POPULAR',
                              style: TextStyle(
                                color: LockMyLookUi.coral,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.description,
                      style: const TextStyle(
                        color: LockMyLookUi.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${package.price}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: LockMyLookUi.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: LockMyLookUi.coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${package.credits} credits',
                  style: const TextStyle(
                    color: LockMyLookUi.coral,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _showComingSoon(context, package),
                child: const Text('Buy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, _CreditPackage package) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 30, color: LockMyLookUi.coral),
            const SizedBox(height: 10),
            Text(
              '${package.credits} credits · ₹${package.price}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Payment checkout will be connected in the next billing step.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LockMyLookUi.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
