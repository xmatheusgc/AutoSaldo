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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMercosul) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF003399), // Azul Mercosul
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: const Text(
                'BRASIL',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: isMercosul ? 3 : 5,
            ),
            child: Text(
              displayPlate,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

