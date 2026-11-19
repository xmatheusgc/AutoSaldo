import 'dart:convert';
import 'package:autosaldo/data/services/fipe_service.dart';
import 'package:autosaldo/presentation/widgets/searchable_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FipeService', () {
    test('loads and caches brands from FIPE API', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.toString(), endsWith('/carros/marcas'));
        return http.Response(
          jsonEncode([
            {'codigo': '21', 'nome': 'Fiat'},
            {'codigo': '59', 'nome': 'VW - VolksWagen'},
          ]),
          200,
        );
      });

      final service = FipeService(client: client);
      final brands1 = await service.getBrands();
      final brands2 = await service.getBrands();

      expect(calls, 1);
      expect(brands1.length, 2);
      expect(brands1.first.code, '21');
      expect(brands1.first.name, 'Fiat');
      expect(brands2.length, 2);
      service.dispose();
    });

    test('loads, groups, and caches models and versions by brand', () async {
      int calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.toString(), endsWith('/carros/marcas/59/modelos'));
        return http.Response(
          jsonEncode({
            'modelos': [
              {'codigo': 1, 'nome': 'Gol 1.6 MSI Flex 8V 4p'},
              {'codigo': 2, 'nome': 'Gol 1.0 Flex 12V 5p'},
              {'codigo': 3, 'nome': 'Polo Highline 200 TSI 1.0 Flex Aut.'},
              {'codigo': 4, 'nome': 'Fusca'},
            ],
            'anos': [],
          }),
          200,
        );
      });

      final service = FipeService(client: client);
      final groups1 = await service.getModelsByBrand('59');
      final groups2 = await service.getModelsByBrand('59');

      expect(calls, 1);
      expect(groups1.map((g) => g.baseModel).toList(), ['Fusca', 'Gol', 'Polo']);
      expect(groups1[0].versions, isEmpty);
      expect(groups1[1].versions, ['1.0 Flex 12V 5p', '1.6 MSI Flex 8V 4p']);
      expect(groups1[2].versions, ['Highline 200 TSI 1.0 Flex Aut.']);
      expect(groups2.length, 3);
      service.dispose();
    });

    test('cleans FIPE brand prefixes and filters common Brazilian brands', () {
      final brands = [
        const FipeBrand(code: '1', name: 'Aston Martin', rawName: 'Aston Martin'),
        const FipeBrand(code: '2', name: 'Maserati', rawName: 'Maserati'),
        FipeBrand(
          code: '59',
          name: FipeService.cleanBrandName('VW - VolksWagen'),
          rawName: 'VW - VolksWagen',
        ),
        FipeBrand(
          code: '23',
          name: FipeService.cleanBrandName('GM - Chevrolet'),
          rawName: 'GM - Chevrolet',
        ),
        const FipeBrand(code: '21', name: 'Fiat', rawName: 'Fiat'),
      ];

      final common = FipeService.filterCommonBrands(brands);
      expect(common.map((b) => b.name).toList(), ['Chevrolet', 'Fiat', 'Volkswagen']);
    });
  });

  group('SearchableSelectField', () {
    testWidgets('filters options in picker and selects value', (tester) async {
      String? selected;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableSelectField(
              label: 'Marca *',
              options: const ['Fiat', 'Honda', 'Toyota'],
              selectedValue: selected,
              isOtherMode: false,
              manualController: controller,
              onOptionSelected: (val) => selected = val,
              onOtherSelected: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hon');
      await tester.pump();

      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('Fiat'), findsNothing);

      await tester.tap(find.text('Honda'));
      await tester.pumpAndSettle();

      expect(selected, 'Honda');
      controller.dispose();
    });

    testWidgets('switches to manual input when Outro is selected', (tester) async {
      bool isOther = false;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SearchableSelectField(
                  label: 'Marca *',
                  options: const ['Fiat', 'Honda'],
                  selectedValue: null,
                  isOtherMode: isOther,
                  manualController: controller,
                  onOptionSelected: (_) {},
                  onOtherSelected: () => setState(() => isOther = true),
                  onSwitchToSelect: () => setState(() => isOther = false),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Outro (digitar manualmente)'));
      await tester.pumpAndSettle();

      expect(isOther, isTrue);
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'BYD');
      expect(controller.text, 'BYD');

      // Tapping "Lista" switches back to select mode
      expect(find.text('Lista'), findsOneWidget);
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();

      expect(isOther, isFalse);
      expect(find.byType(TextFormField), findsNothing);
      controller.dispose();
    });

    testWidgets('does not overlap labelText with hintText when empty', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchableSelectField(
              label: 'Marca *',
              hintText: 'Selecione a marca',
              options: const ['Fiat', 'Honda'],
              selectedValue: null,
              isOtherMode: false,
              manualController: controller,
              onOptionSelected: (_) {},
              onOtherSelected: () {},
            ),
          ),
        ),
      );

      final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(decorator.isEmpty, isTrue);
      expect(decorator.child, isA<SizedBox>());
      controller.dispose();
    });
  });
}
