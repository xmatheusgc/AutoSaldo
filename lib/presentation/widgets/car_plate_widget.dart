import 'package:flutter/material.dart';
import '../../core/formatters.dart';

class CarPlateWidget extends StatelessWidget {
  final String plate;
  final double fontSize;

  const CarPlateWidget({
    super.key,
    required this.plate,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final clean = Formatters.normalizePlate(plate);
    final isMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$').hasMatch(clean);
    final displayPlate = Formatters.formatPlate(clean);

    if (isMercosul) {
      // PLACA MERCOSUL: Fundo Branco, Contorno Preto, Faixa Azul no Topo ("BRASIL"), Letras Pretas
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faixa azul oficial Mercosul
                Container(
                  color: const Color(0xFF003399),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bandeira do Brasil sutil
                      Container(
                        width: 9,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009C3B),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: Center(
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFDF00),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'BRASIL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chapa branca com caracteres pretos
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: Center(
                    child: Text(
                      displayPlate,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // PLACA ANTIGA (CINZA): Fundo Cinza, Contorno Preto, Letras Pretas no formato ABC-1234
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1), // Chapa cinza automotiva
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1E293B), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarja superior cinza com rebites simulados
                Container(
                  color: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF334155),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Text(
                        'BR',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 6.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF334155),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chapa cinza com letras pretas e traço
                Container(
                  color: const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Center(
                    child: Text(
                      displayPlate,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

