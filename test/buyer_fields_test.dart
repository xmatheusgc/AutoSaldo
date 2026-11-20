import 'package:autosaldo/core/brazilian_input_formatters.dart';
import 'package:autosaldo/core/validators.dart';
import 'package:autosaldo/data/repositories/vehicle_repository.dart';
import 'package:autosaldo/domain/models/active_sale.dart';
import 'package:autosaldo/domain/models/vehicle.dart';
import 'package:autosaldo/presentation/screens/sales/sale_form_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVehicleRepository extends VehicleRepository {
  _FakeVehicleRepository() : super(firestore: _FakeFirebaseFirestore());

  ActiveSale? lastRegisteredSale;

  @override
  Future<void> registerSale({
    required String workspaceId,
    required String vehicleId,
    required ActiveSale sale,
    required String userUid,
    String? userEmail,
  }) async {
    lastRegisteredSale = sale;
  }
}

class _FakeFirebaseFirestore extends Fake implements FirebaseFirestore {}

TextEditingValue _applyFormatter(
  DigitsMaskInputFormatter formatter,
  TextEditingValue oldVal,
  String nextText, {
  int? cursor,
}) {
  final offset = cursor ?? nextText.length;
  return formatter.formatEditUpdate(
    oldVal,
    TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
    ),
  );
}

void main() {
  group('PhoneInputFormatter & CpfCnpjInputFormatter', () {
    test('PhoneInputFormatter formats 10 and 11 digits progressively and backspaces cleanly', () {
      const formatter = PhoneInputFormatter();
      var val = const TextEditingValue();

      val = _applyFormatter(formatter, val, '11');
      expect(val.text, '(11');

      val = _applyFormatter(formatter, val, '(119');
      expect(val.text, '(11) 9');

      // Simula backspace removendo '9' -> volta para '(11' sem travar em ') '
      val = _applyFormatter(formatter, val, '(11) ');
      expect(val.text, '(11');

      // 10 dígitos (fixo)
      val = _applyFormatter(formatter, const TextEditingValue(), '1134567890');
      expect(val.text, '(11) 3456-7890');

      // 11 dígitos (celular)
      val = _applyFormatter(formatter, const TextEditingValue(), '11999998888');
      expect(val.text, '(11) 99999-8888');

      // Limita em 11 dígitos ao colar texto extra
      val = _applyFormatter(formatter, const TextEditingValue(), '11999998888777');
      expect(val.text, '(11) 99999-8888');
    });

    test('CpfCnpjInputFormatter switches smoothly between CPF and CNPJ and handles separator backspace', () {
      const formatter = CpfCnpjInputFormatter();

      final cpfVal = _applyFormatter(formatter, const TextEditingValue(), '12345678901');
      expect(cpfVal.text, '123.456.789-01');

      // Backspace exatamente sobre o primeiro ponto em '123.456' remove o dígito '3'
      const withDot = TextEditingValue(
        text: '123.456',
        selection: TextSelection.collapsed(offset: 4),
      );
      final afterBackspace = formatter.formatEditUpdate(
        withDot,
        const TextEditingValue(
          text: '123456',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(afterBackspace.text, '124.56');
      expect(afterBackspace.selection.baseOffset, 2);

      // Transiciona para CNPJ ao digitar 12+ dígitos
      final cnpjVal = _applyFormatter(formatter, const TextEditingValue(), '11222333000181');
      expect(cnpjVal.text, '11.222.333/0001-81');
    });
  });

  group('Buyer Validators & ActiveSale serialization', () {
    test('Validators allow blank optional values and validate phone/CPF/CNPJ check digits', () {
      expect(Validators.isValidPhone(null), isTrue);
      expect(Validators.isValidPhone(''), isTrue);
      expect(Validators.isValidPhone('(11) 99999-8888'), isTrue);
      expect(Validators.isValidPhone('(11) 3456-7890'), isTrue);
      expect(Validators.isValidPhone('(11) 9999'), isFalse);
      expect(Validators.isValidPhone('(00) 99999-8888'), isFalse);

      expect(Validators.isValidCpfOrCnpj(null), isTrue);
      expect(Validators.isValidCpfOrCnpj(''), isTrue);
      expect(Validators.isValidCpfOrCnpj('529.982.247-25'), isTrue);
      expect(Validators.isValidCpfOrCnpj('111.111.111-11'), isFalse);
      expect(Validators.isValidCpfOrCnpj('123.456.789-00'), isFalse);
      expect(Validators.isValidCpfOrCnpj('11.222.333/0001-81'), isTrue);
      expect(Validators.isValidCpfOrCnpj('11.222.333/0001-82'), isFalse);
    });

    test('ActiveSale persists and clears optional buyer info cleanly', () {
      final now = DateTime(2026, 11, 20, 19);
      final sale = ActiveSale(
        id: 's1',
        saleDate: '2026-11-20',
        salePriceCents: 5500000,
        buyerName: 'João Silva',
        buyerPhone: '11987654321',
        buyerDocument: '52998224725',
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );

      final map = sale.toMap();
      final decoded = ActiveSale.fromMap(map);
      expect(decoded.hasBuyerInfo, isTrue);
      expect(decoded.buyerName, 'João Silva');
      expect(decoded.buyerPhone, '11987654321');
      expect(decoded.buyerDocument, '52998224725');

      final cleared = decoded.withBuyerInfo(
        buyerName: null,
        buyerPhone: '',
        buyerDocument: null,
        updatedAt: now,
        updatedByUid: 'u1',
      );
      expect(cleared.hasBuyerInfo, isFalse);
      expect(cleared.buyerName, isNull);
      expect(cleared.buyerPhone, isNull);
      expect(cleared.buyerDocument, isNull);
    });
  });

  group('SaleFormDialog buyer inputs', () {
    Vehicle makeVehicle() {
      final now = DateTime(2026, 11, 1);
      return Vehicle(
        id: 'v1',
        plate: 'ABC1D23',
        brand: 'VW',
        model: 'Gol',
        purchaseDate: '2026-10-01',
        purchasePriceCents: 4000000,
        announcedPriceCents: 5000000,
        createdAt: now,
        updatedAt: now,
        createdByUid: 'u1',
        updatedByUid: 'u1',
      );
    }

    testWidgets('Applies phone and CPF masks and saves normalized digits', (tester) async {
      final repo = _FakeVehicleRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SaleFormDialog(
                workspaceId: 'ws1',
                vehicle: makeVehicle(),
                totalCostCents: 4200000,
                userUid: 'u1',
                vehicleRepository: repo,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dados do comprador (opcional)'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do comprador'),
        'Maria Oliveira',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefone / WhatsApp'),
        '11987654321',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CPF / CNPJ'),
        '52998224725',
      );
      await tester.pump();

      expect(find.text('(11) 98765-4321'), findsOneWidget);
      expect(find.text('529.982.247-25'), findsOneWidget);

      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // Modal de confirmação mostra os dados formatados
      expect(find.text('Maria Oliveira'), findsAtLeastNWidgets(1));
      expect(find.text('(11) 98765-4321'), findsAtLeastNWidgets(1));
      expect(find.text('529.982.247-25'), findsAtLeastNWidgets(1));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmar Venda'));
      await tester.pumpAndSettle();

      expect(repo.lastRegisteredSale, isNotNull);
      expect(repo.lastRegisteredSale!.buyerName, 'Maria Oliveira');
      expect(repo.lastRegisteredSale!.buyerPhone, '11987654321');
      expect(repo.lastRegisteredSale!.buyerDocument, '52998224725');
    });
  });
}
