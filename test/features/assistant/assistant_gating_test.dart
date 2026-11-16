import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/repositories/fake_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/gemini_rest_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';

class _DemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

ProviderContainer _container({
  required String key,
  String? uid,
  bool demo = false,
}) {
  final container = ProviderContainer(
    overrides: [
      geminiApiKeyProvider.overrideWithValue(key),
      currentUserUidProvider.overrideWithValue(uid),
      if (demo) demoModeProvider.overrideWith(_DemoNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('assistantEnabledProvider', () {
    test('is on when the key is present and a user is signed in', () {
      final container = _container(key: 'restricted-key', uid: 'visitor-1');

      expect(container.read(assistantEnabledProvider), isTrue);
      expect(
        container.read(assistantRepositoryProvider),
        isA<GeminiRestAssistantRepository>(),
      );
    });

    test('is off when the key is missing', () {
      final container = _container(key: '', uid: 'visitor-1');

      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });

    test('is off when the visitor is signed out', () {
      final container = _container(key: 'restricted-key', uid: null);

      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });

    test('is forced on in Demo Mode with the scripted fake', () {
      final container = _container(key: '', uid: null, demo: true);

      expect(container.read(assistantEnabledProvider), isTrue);
      expect(
        container.read(assistantRepositoryProvider),
        isA<FakeAssistantRepository>(),
      );
    });

    test('turning Demo Mode off falls back to key plus signed-in gate', () {
      final container = _container(key: 'restricted-key', uid: 'visitor-1');

      container.read(demoModeProvider.notifier).setDemo(true);
      expect(
        container.read(assistantRepositoryProvider),
        isA<FakeAssistantRepository>(),
      );

      container.read(demoModeProvider.notifier).setDemo(false);
      expect(
        container.read(assistantRepositoryProvider),
        isA<GeminiRestAssistantRepository>(),
      );
    });

    test('the same gate applies regardless of platform', () {
      // The gate has no platform branch: web and Android read the same key
      // define and the same auth state.
      for (final uid in ['web-visitor', 'android-visitor']) {
        final container = _container(key: 'restricted-key', uid: uid);
        expect(container.read(assistantEnabledProvider), isTrue, reason: uid);
      }
    });
  });
}
