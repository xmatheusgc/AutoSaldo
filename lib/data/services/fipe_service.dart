import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/formatters.dart';

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
  final Map<String, int> versionCodes;
  final int? defaultCode;

  const FipeModelGroup({
    required this.baseModel,
    required this.versions,
    this.versionCodes = const {},
    this.defaultCode,
  });

  /// Retorna o código FIPE da versão informada, ou o código padrão do modelo.
  int? codeForVersion(String? version) {
    final trimmed = version?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final target = trimmed.toLowerCase();
      for (final entry in versionCodes.entries) {
        if (entry.key.toLowerCase() == target) return entry.value;
      }
    }
    if (defaultCode != null) return defaultCode;
    if (trimmed.isEmpty && versionCodes.length == 1) {
      return versionCodes.values.first;
    }
    return null;
  }
}

class FipeYearOption {
  final String code;
  final String name;

  const FipeYearOption({required this.code, required this.name});

  int? get yearNumber => int.tryParse(code.split('-').first);

  factory FipeYearOption.fromJson(Map<String, dynamic> json) {
    return FipeYearOption(
      code: (json['codigo'] ?? '').toString().trim(),
      name: (json['nome'] ?? '').toString().trim(),
    );
  }
}

class FipePriceResult {
  final String priceFormatted;
  final int priceCents;
  final String brand;
  final String model;
  final int modelYear;
  final String fuel;
  final String fipeCode;
  final String referenceMonth;

  const FipePriceResult({
    required this.priceFormatted,
    required this.priceCents,
    required this.brand,
    required this.model,
    required this.modelYear,
    required this.fuel,
    required this.fipeCode,
    required this.referenceMonth,
  });

  factory FipePriceResult.fromJson(Map<String, dynamic> json) {
    final valor = (json['Valor'] ?? '').toString().trim();
    return FipePriceResult(
      priceFormatted: valor,
      priceCents: Formatters.parseCurrencyToCents(valor),
      brand: (json['Marca'] ?? '').toString().trim(),
      model: (json['Modelo'] ?? '').toString().trim(),
      modelYear: (json['AnoModelo'] as num?)?.toInt() ??
          int.tryParse((json['AnoModelo'] ?? '').toString()) ??
          0,
      fuel: (json['Combustivel'] ?? '').toString().trim(),
      fipeCode: (json['CodigoFipe'] ?? '').toString().trim(),
      referenceMonth: (json['MesReferencia'] ?? '').toString().trim(),
    );
  }
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
  final Map<String, List<FipeYearOption>> _cachedYearsByModel = {};
  final Map<String, FipePriceResult> _cachedPriceByKey = {};

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

  Future<List<FipeYearOption>> getModelYears(String brandCode, int modelCode) async {
    final cacheKey = '$brandCode:$modelCode';
    if (_cachedYearsByModel.containsKey(cacheKey)) {
      return _cachedYearsByModel[cacheKey]!;
    }

    final response = await _client
        .get(Uri.parse('$_baseUrl/marcas/$brandCode/modelos/$modelCode/anos'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar anos da FIPE (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final years = data
        .map((e) => FipeYearOption.fromJson(e as Map<String, dynamic>))
        .where((y) => y.code.isNotEmpty && y.name.isNotEmpty)
        .toList();

    _cachedYearsByModel[cacheKey] = years;
    return years;
  }

  Future<FipePriceResult> getFipePrice(
    String brandCode,
    int modelCode,
    String yearCode,
  ) async {
    final cacheKey = '$brandCode:$modelCode:$yearCode';
    if (_cachedPriceByKey.containsKey(cacheKey)) {
      return _cachedPriceByKey[cacheKey]!;
    }

    final response = await _client
        .get(Uri.parse('$_baseUrl/marcas/$brandCode/modelos/$modelCode/anos/$yearCode'))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Falha ao consultar preço na FIPE (${response.statusCode})');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = FipePriceResult.fromJson(data);
    _cachedPriceByKey[cacheKey] = result;
    return result;
  }

  static String _normalizeForSearch(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _brandAliases = {
    'vw': 'volkswagen',
    'volks': 'volkswagen',
    'gm': 'chevrolet',
    'chevy': 'chevrolet',
    'mercedes': 'mercedes-benz',
    'mb': 'mercedes-benz',
    'caoa': 'caoa chery',
    'chery': 'caoa chery',
    'land': 'land rover',
  };

  FipeBrand? _matchBrand(List<FipeBrand> brands, String brand) {
    final rawNorm = _normalizeForSearch(brand);
    if (rawNorm.isEmpty) return null;
    final target = _brandAliases[rawNorm] ?? rawNorm;

    for (final b in brands) {
      if (_normalizeForSearch(b.name) == target ||
          _normalizeForSearch(b.rawName) == target) {
        return b;
      }
    }
    for (final b in brands) {
      final n = _normalizeForSearch(b.name);
      final r = _normalizeForSearch(b.rawName);
      if (n.contains(target) ||
          target.contains(n) ||
          r.contains(target) ||
          target.contains(r)) {
        return b;
      }
    }
    return null;
  }

  FipeModelGroup? _matchModelGroup(
    List<FipeModelGroup> groups,
    String model,
  ) {
    final target = _normalizeForSearch(model);
    if (target.isEmpty) return null;

    for (final g in groups) {
      if (_normalizeForSearch(g.baseModel) == target) return g;
    }

    final firstWord = target.split(' ').first;
    for (final g in groups) {
      if (_normalizeForSearch(g.baseModel) == firstWord) return g;
    }

    for (final g in groups) {
      final base = _normalizeForSearch(g.baseModel);
      if (target.startsWith(base) || base.startsWith(target)) return g;
    }
    return null;
  }

  List<int> _rankModelCodes(
    FipeModelGroup group,
    String modelText,
    String? version,
  ) {
    final exactCode = group.codeForVersion(version);
    if (exactCode != null) return [exactCode];

    final combinedQuery = _normalizeForSearch(
      '${version ?? ''} $modelText',
    );
    final tokens = combinedQuery
        .split(RegExp(r'[^a-z0-9.]+'))
        .where((t) => t.isNotEmpty && t != _normalizeForSearch(group.baseModel))
        .toSet();

    if (group.versionCodes.isEmpty) {
      return group.defaultCode != null ? [group.defaultCode!] : const [];
    }

    if (tokens.isEmpty) {
      final list = <int>[
        ?group.defaultCode,
        ...group.versionCodes.values.take(3),
      ];
      return list;
    }

    final scored = <({int code, int score})>[];
    for (final entry in group.versionCodes.entries) {
      final vNorm = _normalizeForSearch(entry.key);
      final vTokens = vNorm.split(RegExp(r'[^a-z0-9.]+')).where((t) => t.isNotEmpty).toSet();
      int score = 0;
      for (final token in tokens) {
        if (vTokens.contains(token)) {
          score += RegExp(r'^\d\.\d$').hasMatch(token) ? 4 : 2;
        } else if (vNorm.contains(token)) {
          score += 1;
        }
      }
      scored.add((code: entry.value, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).map((e) => e.code).toList();
  }

  /// Consulta o valor de referência FIPE a partir dos textos cadastrados do veículo,
  /// usando correspondência flexível de marca, modelo, versão e ano.
  Future<FipePriceResult?> lookupVehicleReference({
    required String brand,
    required String model,
    String? version,
    int? modelYear,
    int? manufactureYear,
  }) async {
    if (brand.trim().isEmpty || model.trim().isEmpty) return null;

    final brands = await getBrands();
    final matchedBrand = _matchBrand(brands, brand);
    if (matchedBrand == null) return null;

    final groups = await getModelsByBrand(matchedBrand.code);
    final matchedGroup = _matchModelGroup(groups, model);
    if (matchedGroup == null) return null;

    final candidateCodes = _rankModelCodes(matchedGroup, model, version);
    if (candidateCodes.isEmpty) return null;

    final targetYears = <int>[
      ?modelYear,
      if (manufactureYear != null && manufactureYear != modelYear) manufactureYear,
    ];

    for (final code in candidateCodes) {
      final years = await getModelYears(matchedBrand.code, code);
      if (years.isEmpty) continue;

      FipeYearOption? chosenYear;
      if (targetYears.isNotEmpty) {
        for (final yNum in targetYears) {
          final matches = years.where((y) => y.yearNumber == yNum).toList();
          if (matches.isNotEmpty) {
            chosenYear = matches.firstWhere(
              (y) =>
                  y.name.toLowerCase().contains('flex') ||
                  y.name.toLowerCase().contains('gasolina'),
              orElse: () => matches.first,
            );
            break;
          }
        }
      } else {
        chosenYear = years.firstWhere(
          (y) => y.yearNumber != 32000,
          orElse: () => years.first,
        );
      }

      if (chosenYear != null) {
        return getFipePrice(matchedBrand.code, code, chosenYear.code);
      }
    }

    return null;
  }

  /// Agrupa entradas da FIPE (ex: "Gol 1.0 Flex 12V 5p") por modelo base ("Gol"),
  /// lista de versões ("1.0 Flex 12V 5p") e códigos de modelo FIPE correspondentes.
  static List<FipeModelGroup> groupModels(List<FipeModelEntry> entries) {
    final Map<String, Map<String, int>> grouped = {};
    final Map<String, int> defaultCodes = {};

    for (final entry in entries) {
      final parts = entry.fullName.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      final base = parts.first;
      final version = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final versionsMap = grouped.putIfAbsent(base, () => <String, int>{});
      if (version.isNotEmpty) {
        versionsMap.putIfAbsent(version, () => entry.code);
      } else {
        defaultCodes.putIfAbsent(base, () => entry.code);
      }
    }

    final result = grouped.entries.map((e) {
      final versions = e.value.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return FipeModelGroup(
        baseModel: e.key,
        versions: versions,
        versionCodes: Map.unmodifiable(e.value),
        defaultCode: defaultCodes[e.key],
      );
    }).toList();

    result.sort((a, b) => a.baseModel.toLowerCase().compareTo(b.baseModel.toLowerCase()));
    return result;
  }

  void dispose() {
    _client.close();
  }
}
