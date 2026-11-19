import 'package:autosaldo/presentation/widgets/currency_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyInputFormatter', () {
    final formatter = CurrencyInputFormatter();

    TextEditingValue applySequence(List<String> inputs) {
      var current = TextEditingValue.empty;
      for (final ch in inputs) {
        final nextText = current.text + ch;
        current = formatter.formatEditUpdate(
          current,
          TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          ),
        );
      }
      return current;
    }

    test('formats digits progressively from cents to BRL', () {
      expect(applySequence(['9']).text, '0,09');
      expect(applySequence(['9', '5']).text, '0,95');
      expect(applySequence(['9', '5', '0']).text, '9,50');
      expect(applySequence(['9', '5', '0', '0']).text, '95,00');
      expect(applySequence(['9', '5', '0', '0', '0']).text, '950,00');
      expect(applySequence(['9', '5', '0', '0', '0', '0']).text, '9.500,00');
      expect(applySequence(['9', '5', '0', '0', '0', '0', '0']).text, '95.000,00');
    });

    test('ignores non-digit characters such as dots and commas while typing 95.000,00', () {
      final result = applySequence(['9', '5', '.', '0', '0', '0', ',', '0', '0']);
      expect(result.text, '95.000,00');
    });

    test('handles pasted formatted BRL strings', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'R\$ 95.000,00',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      expect(result.text, '95.000,00');
      expect(result.selection.baseOffset, '95.000,00'.length);
    });

    test('clears field when backspaced to zero', () {
      const oldVal = TextEditingValue(
        text: '0,05',
        selection: TextSelection.collapsed(offset: 4),
      );
      final result = formatter.formatEditUpdate(
        oldVal,
        const TextEditingValue(
          text: '0,0',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(result.text, '');
      expect(result.selection.baseOffset, 0);
    });

    test('preserves relative cursor position when editing in the middle', () {
      const oldVal = TextEditingValue(
        text: '12,34',
        selection: TextSelection.collapsed(offset: 1),
      );
      final result = formatter.formatEditUpdate(
        oldVal,
        const TextEditingValue(
          text: '152,34',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(result.text, '152,34');
      expect(result.selection.baseOffset, 2);
    });
  });

  group('CurrencyTextField widget', () {
    testWidgets('masks input while typing and emits exact cents', (tester) async {
      int latestCents = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencyTextField(
              label: 'Valor *',
              required: true,
              onChanged: (cents) => latestCents = cents,
            ),
          ),
        ),
      );

      final field = find.byType(TextFormField);
      await tester.enterText(field, '9500000');
      await tester.pump();

      expect(find.text('95.000,00'), findsOneWidget);
      expect(latestCents, 9500000);
    });

    testWidgets('displays initialValueCents formatted without R\$', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CurrencyTextField(
              label: 'Valor *',
              initialValueCents: 9500000,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('95.000,00'), findsOneWidget);
    });
  });
}
