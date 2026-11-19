import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FipeBrand {
  final String code;
  final String name;
  final String rawName;

  const FipeBrand({
    required this.code,
    required this.name,
    String? rawName,
  }) : rawName = rawName ?? name;

  factory FipeBrand.fromJson(Map<String, dynamic> json) {
    final raw = (json['nome'] ?? '').toString().trim();
    return FipeBrand(
      code: json['codigo'].toString(),
      name: FipeService.cleanBrandName(raw),
      rawName: raw,
    );
  }
}

class FipeModelEntry {
  final int code;
  final String fullName;

  const FipeModelEntry({required this.code, required this.fullName});

  factory FipeModelEntry.fromJson(Map<String, dynamic> json) {
    return FipeModelEntry(
      code: int.tryParse(json['codigo'].toString()) ?? 0,
      fullName: (json['nome'] ?? '').toString().trim(),
    );
  }
}

class FipeModelGroup {
  final String baseModel;
  final List<String> versions;

  const FipeModelGroup({required this.baseModel, required this.versions});
}

class FipeService {
  static const String _baseUrl = 'https://parallelum.com.br/fipe/api/v1/carros';
  static const Duration _timeout = Duration(seconds: 8);

  static const Set<String> _commonBrandKeys = {
    'audi',
    'bmw',
    'byd',
    'caoa chery',
    'caoa chery/chery',
    'chery',
    'chevrolet',
    'citroen',
    'citroën',
    'dodge',
    'fiat',
    'ford',
    'gwm',
    'honda',
    'hyundai',
    'jac',
    'jeep',
    'kia',
    'kia motors',
    'land rover',
    'mercedes-benz',
    'mitsubishi',
    'nissan',
    'peugeot',
    'ram',
    'renault',
    'subaru',
    'suzuki',
    'toyota',
    'volkswagen',
    'volvo',
  };

  /// Normaliza nomes peculiares da FIPE (ex: "VW - VolksWagen" -> "Volkswagen").
  static String cleanBrandName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'vw - volkswagen') return 'Volkswagen';
    if (lower == 'gm - chevrolet') return 'Chevrolet';
    if (lower == 'kia motors') return 'Kia';
    return raw.trim();
  }

  /// Filtra apenas as marcas mais comuns do mercado brasileiro, mantendo ordem alfabética.
  static List<FipeBrand> filterCommonBrands(List<FipeBrand> allBrands) {
    final filtered = allBrands.where((b) {
      final cleanLower = b.name.toLowerCase();
      final rawLower = b.rawName.toLowerCase();
      return _commonBrandKeys.contains(cleanLower) || _commonBrandKeys.contains(rawLower);
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  final http.Client _client;

  List<FipeBrand>? _cachedBrands;
  final Map<String, List<FipeModelGroup>> _cachedModelsByBrand = {};

  FipeService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<FipeBrand>> getBrands() async {
    if (_cachedBrands != null) return _cachedBrands!;

    final response = await _client
        .get(Uri.parse('$_baseUrl/marcas'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar marcas da FIPE (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final brands = data
        .map((e) => FipeBrand.fromJson(e as Map<String, dynamic>))
        .where((b) => b.code.isNotEmpty && b.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _cachedBrands = brands;
    return brands;
  }

  Future<List<FipeModelGroup>> getModelsByBrand(String brandCode) async {
    if (_cachedModelsByBrand.containsKey(brandCode)) {
      return _cachedModelsByBrand[brandCode]!;
    }

    final response = await _client
        .get(Uri.parse('$_baseUrl/marcas/$brandCode/modelos'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar modelos da FIPE (${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> rawModels = (data['modelos'] as List<dynamic>?) ?? [];

    final entries = rawModels
        .map((e) => FipeModelEntry.fromJson(e as Map<String, dynamic>))
        .where((m) => m.fullName.isNotEmpty)
        .toList();

    final grouped = groupModels(entries);
    _cachedModelsByBrand[brandCode] = grouped;
    return grouped;
  }

  /// Agrupa entradas da FIPE (ex: "Gol 1.0 Flex 12V 5p") por modelo base ("Gol")
  /// e lista de versões ("1.0 Flex 12V 5p").
  static List<FipeModelGroup> groupModels(List<FipeModelEntry> entries) {
    final Map<String, Set<String>> grouped = {};

    for (final entry in entries) {
      final parts = entry.fullName.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      final base = parts.first;
      final version = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      grouped.putIfAbsent(base, () => <String>{});
      if (version.isNotEmpty) {
        grouped[base]!.add(version);
      }
    }

    final result = grouped.entries.map((e) {
      final versions = e.value.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return FipeModelGroup(baseModel: e.key, versions: versions);
    }).toList();

    result.sort((a, b) => a.baseModel.toLowerCase().compareTo(b.baseModel.toLowerCase()));
    return result;
  }

  void dispose() {
    _client.close();
  }
}
