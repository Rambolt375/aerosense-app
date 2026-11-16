import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/app_check.dart';
import 'package:aerosense_app/core/app_check_provider.dart';
import 'package:aerosense_app/data/repositories/fake_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/firebase_ai_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';

class _FixedAppCheck extends AppCheckNotifier {
  _FixedAppCheck(this.status);

  final AppCheckStatus status;

  @override
  AppCheckStatus build() => status;
}

class _DemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

ProviderContainer _container({
  required AppCheckStatus appCheck,
  String? uid,
  bool demo = false,
}) {
  final container = ProviderContainer(
    overrides: [
      appCheckStatusProvider.overrideWith(() => _FixedAppCheck(appCheck)),
      currentUserUidProvider.overrideWithValue(uid),
      if (demo) demoModeProvider.overrideWith(_DemoNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('assistantEnabledProvider', () {
    test('is on only with App Check active and a signed-in user', () {
      final enabled = _container(
        appCheck: AppCheckStatus.active,
        uid: 'visitor-1',
      );

      expect(enabled.read(assistantEnabledProvider), isTrue);
      expect(
        enabled.read(assistantRepositoryProvider),
        isA<FirebaseAiAssistantRepository>(),
      );
    });

    test('is off when App Check is not configured', () {
      final container = _container(
        appCheck: AppCheckStatus.notConfigured,
        uid: 'visitor-1',
      );

      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });

    test('is off when App Check activation failed', () {
      final container = _container(
        appCheck: AppCheckStatus.failed,
        uid: 'visitor-1',
      );

      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });

    test('is off when the visitor is signed out', () {
      final container = _container(appCheck: AppCheckStatus.active, uid: null);

      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });

    test('is forced on in Demo Mode even without App Check or a user', () {
      final container = _container(
        appCheck: AppCheckStatus.notConfigured,
        uid: null,
        demo: true,
      );

      expect(container.read(assistantEnabledProvider), isTrue);
      expect(
        container.read(assistantRepositoryProvider),
        isA<FakeAssistantRepository>(),
      );
    });

    test('turning Demo Mode off falls back to the live gate', () {
      final container = _container(
        appCheck: AppCheckStatus.notConfigured,
        uid: 'visitor-1',
      );

      container.read(demoModeProvider.notifier).setDemo(true);
      expect(container.read(assistantEnabledProvider), isTrue);

      container.read(demoModeProvider.notifier).setDemo(false);
      expect(container.read(assistantEnabledProvider), isFalse);
      expect(container.read(assistantRepositoryProvider), isNull);
    });
  });

  group('AppCheckNotifier', () {
    test('starts not configured so nothing is enabled before activation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appCheckStatusProvider),
        AppCheckStatus.notConfigured,
      );
    });
  });
}
