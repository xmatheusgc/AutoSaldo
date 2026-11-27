import 'package:flutter/material.dart';
import '../../core/brazilian_input_formatters.dart';
import '../../core/validators.dart';

/// Bloco reutilizável com os campos opcionais de pessoa (comprador ou proprietário consignante) e máscaras brasileiras.
class BuyerFieldsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController documentController;
  final String nameLabel;
  final String nameHint;

  const BuyerFieldsSection({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.documentController,
    this.nameLabel = 'Nome do comprador',
    this.nameHint = 'Ex: João da Silva',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: nameLabel,
            hintText: nameHint,
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            fillColor: Colors.white,
            hoverColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: const [PhoneInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Telefone / WhatsApp',
            hintText: '(11) 99999-8888',
            prefixIcon: Icon(Icons.phone_outlined, size: 18),
            fillColor: Colors.white,
            hoverColor: Colors.white,
          ),
          validator: (val) {
            if (!Validators.isValidPhone(val)) {
              return 'Informe um telefone válido com DDD (10 ou 11 dígitos).';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: documentController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: const [CpfCnpjInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'CPF / CNPJ',
            hintText: '000.000.000-00 ou 00.000.000/0000-00',
            prefixIcon: Icon(Icons.badge_outlined, size: 18),
            fillColor: Colors.white,
            hoverColor: Colors.white,
          ),
          validator: (val) {
            if (!Validators.isValidCpfOrCnpj(val)) {
              return 'CPF ou CNPJ inválido. Confira os números digitados.';
            }
            return null;
          },
        ),
      ],
    );
  }
}
