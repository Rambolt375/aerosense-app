import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/account_name.dart';

void main() {
  group('normalizeDisplayName', () {
    test('trims leading and trailing whitespace', () {
      expect(normalizeDisplayName('  Alice  '), 'Alice');
      expect(normalizeDisplayName('\tAlice\n'), 'Alice');
    });

    test('collapses inner whitespace runs to one space', () {
      expect(normalizeDisplayName('Alice   Visitor'), 'Alice Visitor');
      expect(normalizeDisplayName('Alice\t\tVisitor'), 'Alice Visitor');
      expect(normalizeDisplayName('Alice \n Visitor'), 'Alice Visitor');
      expect(normalizeDisplayName('Alice\u00A0Visitor'), 'Alice Visitor');
    });

    test('removes control characters without inserting spaces', () {
      expect(normalizeDisplayName('Ali\u0000ce'), 'Alice');
      expect(normalizeDisplayName('Ali\u0007ce'), 'Alice');
      expect(normalizeDisplayName('\u0000Alice\u0007'), 'Alice');
      expect(normalizeDisplayName('A\u0085B'), 'AB');
    });

    test('rejects an empty or whitespace-only name', () {
      expect(normalizeDisplayName(''), isNull);
      expect(normalizeDisplayName('   '), isNull);
      expect(normalizeDisplayName('\u0000\u0007'), isNull);
      expect(normalizeDisplayName(null), isNull);
    });

    test('accepts 1 and 40 characters and rejects 41', () {
      expect(normalizeDisplayName('A'), 'A');
      expect(normalizeDisplayName('A' * 40), 'A' * 40);
      expect(normalizeDisplayName('A' * 41), isNull);
    });

    test('counts emoji as single characters', () {
      // 40 waving hands: 40 grapheme clusters even though they are 80 runes.
      final fortyEmoji = '👋' * 40;
      expect(normalizeDisplayName(fortyEmoji), fortyEmoji);
      expect(normalizeDisplayName('👋' * 41), isNull);
    });

    test('measures length after cleanup, not before', () {
      expect(normalizeDisplayName('  ${'A' * 40}  '), 'A' * 40);
      expect(
        normalizeDisplayName('${'A' * 19}   ${'B' * 20}'),
        '${'A' * 19} ${'B' * 20}',
      );
    });
  });

  group('accountInitial', () {
    test('uses the first letter of the display name, uppercased', () {
      expect(accountInitial(displayName: 'alice'), 'A');
      expect(accountInitial(displayName: '  bob  ', email: 'zz@x.com'), 'B');
    });

    test('falls back to the email local part when the name is missing', () {
      expect(
        accountInitial(displayName: null, email: 'carol@example.com'),
        'C',
      );
      expect(
        accountInitial(displayName: '   ', email: 'dave@example.com'),
        'D',
      );
      expect(accountInitial(displayName: '', email: 'ERIN@example.com'), 'E');
    });

    test('falls back to "?" when nothing is available', () {
      expect(accountInitial(), '?');
      expect(accountInitial(displayName: null, email: null), '?');
      expect(accountInitial(displayName: '  ', email: ''), '?');
      expect(accountInitial(displayName: '', email: '@example.com'), '?');
    });

    test(
      'is emoji safe (one grapheme cluster, never half a surrogate pair)',
      () {
        expect(accountInitial(displayName: '👋 Alice'), '👋');
        expect(accountInitial(displayName: '🇮🇩 Indonesia'), '🇮🇩');
        expect(accountInitial(displayName: null, email: '🙂bob@x.com'), '🙂');
      },
    );

    test('uppercases a letter but leaves emoji untouched', () {
      expect(accountInitial(displayName: 'țeodora'), 'Ț');
    });
  });
}
