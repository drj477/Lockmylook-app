import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/outfits/data/models/virtual_try_on_models.dart';

void main() {
  test('Virtual Try-On request serializes existing Gemini model', () {
    final request = VirtualTryOnRequest(
      itemIds: const ['item-1'],
      model: VirtualTryOnModel.gemini,
    );

    expect(request.toJson(), {
      'item_ids': ['item-1'],
      'model': 'gemini',
    });
  });

  test('Virtual Try-On request serializes Gemini Chat model', () {
    final request = VirtualTryOnRequest(
      itemIds: const ['item-1'],
      model: VirtualTryOnModel.geminiChat,
    );

    expect(request.toJson(), {
      'item_ids': ['item-1'],
      'model': 'gemini_chat',
    });
  });

  test('Virtual Try-On result falls back to Replicate for unknown model', () {
    final result = VirtualTryOnResult.fromJson({
      'id': 'result-1',
      'profile_id': 'profile-1',
      'image_url': 'http://localhost/result.webp',
      'item_ids': ['item-1'],
      'model': 'unknown-provider',
      'created_at': '2026-08-16T00:00:00Z',
      'saved': false,
    });

    expect(result.model, VirtualTryOnModel.replicate);
  });
}
