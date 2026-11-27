import 'package:flutter/material.dart';
import '../../core/formatters.dart';

class CarPlateWidget extends StatelessWidget {
  final String plate;
  final double fontSize;
  final bool compact;

  const CarPlateWidget({
    super.key,
    required this.plate,
    this.fontSize = 15,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final clean = Formatters.normalizePlate(plate);
    final isMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$').hasMatch(clean);
    final displayPlate = Formatters.formatPlate(clean);

    final Widget plateWidget;
    if (isMercosul) {
      // PLACA MERCOSUL: Fundo Branco, Contorno Preto, Faixa Azul no Topo ("BRASIL"), Letras Pretas
      plateWidget = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
          border: Border.all(color: Colors.black, width: compact ? 1.5 : 2.0),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 3.5 : 4),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Faixa azul oficial Mercosul
                Container(
                  color: const Color(0xFF003399),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 8,
                    vertical: compact ? 1 : 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bandeira do Brasil sutil
                      Container(
                        width: compact ? 7 : 9,
                        height: compact ? 5 : 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009C3B),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: Center(
                          child: Container(
                            width: compact ? 2.5 : 3.5,
                            height: compact ? 2.5 : 3.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFDF00),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 3.5 : 5),
                      Text(
                        'BRASIL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 6.0 : 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? 1.1 : 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chapa branca com caracteres pretos
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 1.5 : 3,
                  ),
                  child: Center(
                    child: Text(
                      displayPlate,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: compact ? 1.1 : 2.0,
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
      plateWidget = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1), // Chapa cinza automotiva
          borderRadius: BorderRadius.circular(compact ? 5 : 6),
          border: Border.all(
            color: const Color(0xFF1E293B),
            width: compact ? 1.5 : 2.0,
          ),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 3.5 : 4),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarja superior cinza com rebites simulados
                Container(
                  color: const Color(0xFF94A3B8),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 6,
                    vertical: compact ? 1 : 1.5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: compact ? 3 : 3.5,
                        height: compact ? 3 : 3.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF334155),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'BR',
                        style: TextStyle(
                          color: const Color(0xFF1E293B),
                          fontSize: compact ? 5.5 : 6.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        width: compact ? 3 : 3.5,
                        height: compact ? 3 : 3.5,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 1.5 : 4,
                  ),
                  child: Center(
                    child: Text(
                      displayPlate,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: compact ? 1.0 : 1.6,
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

    return Semantics(
      label: 'Placa $displayPlate',
      excludeSemantics: true,
      child: plateWidget,
    );
  }
}

