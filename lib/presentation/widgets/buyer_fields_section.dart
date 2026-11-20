import 'package:flutter/material.dart';
import '../../core/brazilian_input_formatters.dart';
import '../../core/validators.dart';

/// Bloco reutilizável com os campos opcionais do comprador e máscaras brasileiras.
class BuyerFieldsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController documentController;

  const BuyerFieldsSection({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.documentController,
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
          decoration: const InputDecoration(
            labelText: 'Nome do comprador',
            hintText: 'Ex: João da Silva',
            prefixIcon: Icon(Icons.person_outline, size: 18),
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
