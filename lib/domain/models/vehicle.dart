import '../../core/constants.dart';
import '../../core/formatters.dart';
import 'active_sale.dart';

class Vehicle {
  final String id;
  final String brand;
  final String model;
  final String? version;
  final String plate; // Normalizada: maiúsculas, sem traço e sem espaços
  final String purchaseDate; // AAAA-MM-DD
  final int purchasePriceCents;
  final int? announcedPriceCents;
  final String? notes;

  // Campos do documento CRLV-e
  final String? renavam; // 11 dígitos, preservando zeros à esquerda
  final int? licensingYear; // Exercício (4 dígitos)
  final int? manufactureYear; // Ano fabricação
  final int? modelYear; // Ano modelo
  final String? crvNumber; // Número do CRV, preservando zeros à esquerda
  final String docStatus; // 'pending_check', 'up_to_date', 'with_issue'
  final String? docNotes;

  // Venda ativa do ciclo
  final ActiveSale? activeSale;

  // Histórico de vendas canceladas
  final List<Map<String, dynamic>> cancelledSales;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String updatedByUid;

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    this.version,
    required this.plate,
    required this.purchaseDate,
    required this.purchasePriceCents,
    this.announcedPriceCents,
    this.notes,
    this.renavam,
    this.licensingYear,
    this.manufactureYear,
    this.modelYear,
    this.crvNumber,
    this.docStatus = AppConstants.docStatusPendingCheck,
    this.docNotes,
    this.activeSale,
    this.cancelledSales = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
  });

  bool get isInStock => activeSale == null;
  bool get isSold => activeSale != null;

  String get formattedPlate => Formatters.formatPlate(plate);
  String get docStatusLabel =>
      AppConstants.docStatusLabels[docStatus] ?? docStatus;

  String get title => version != null && version!.isNotEmpty
      ? '$brand $model $version'
      : '$brand $model';

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'version': version,
      'plate': Formatters.normalizePlate(plate),
      'purchaseDate': purchaseDate,
      'purchasePriceCents': purchasePriceCents,
      'announcedPriceCents': announcedPriceCents,
      'notes': notes,
      'renavam': renavam,
      'licensingYear': licensingYear,
      'manufactureYear': manufactureYear,
      'modelYear': modelYear,
      'crvNumber': crvNumber,
      'docStatus': docStatus,
      'docNotes': docNotes,
      'activeSale': activeSale?.toMap(),
      'cancelledSales': cancelledSales,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
    };
  }

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) {
    ActiveSale? sale;
    if (map['activeSale'] != null && map['activeSale'] is Map) {
      sale = ActiveSale.fromMap(Map<String, dynamic>.from(map['activeSale'] as Map));
    }

    final cancelledRaw = map['cancelledSales'] as List<dynamic>? ?? [];
    final cancelledList = cancelledRaw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Vehicle(
      id: id,
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      version: map['version'] as String?,
      plate: Formatters.normalizePlate(map['plate'] as String? ?? ''),
      purchaseDate: map['purchaseDate'] as String? ?? '',
      purchasePriceCents: (map['purchasePriceCents'] as num?)?.toInt() ?? 0,
      announcedPriceCents: (map['announcedPriceCents'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      renavam: map['renavam'] as String?,
      licensingYear: (map['licensingYear'] as num?)?.toInt(),
      manufactureYear: (map['manufactureYear'] as num?)?.toInt(),
      modelYear: (map['modelYear'] as num?)?.toInt(),
      crvNumber: map['crvNumber'] as String?,
      docStatus: map['docStatus'] as String? ?? AppConstants.docStatusPendingCheck,
      docNotes: map['docNotes'] as String?,
      activeSale: sale,
      cancelledSales: cancelledList,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdByUid: map['createdByUid'] as String? ?? '',
      updatedByUid: map['updatedByUid'] as String? ?? '',
    );
  }

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    String? version,
    String? plate,
    String? purchaseDate,
    int? purchasePriceCents,
    int? announcedPriceCents,
    String? notes,
    String? renavam,
    int? licensingYear,
    int? manufactureYear,
    int? modelYear,
    String? crvNumber,
    String? docStatus,
    String? docNotes,
    ActiveSale? activeSale,
    bool clearActiveSale = false,
    List<Map<String, dynamic>>? cancelledSales,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      version: version ?? this.version,
      plate: plate ?? this.plate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
      announcedPriceCents: announcedPriceCents ?? this.announcedPriceCents,
      notes: notes ?? this.notes,
      renavam: renavam ?? this.renavam,
      licensingYear: licensingYear ?? this.licensingYear,
      manufactureYear: manufactureYear ?? this.manufactureYear,
      modelYear: modelYear ?? this.modelYear,
      crvNumber: crvNumber ?? this.crvNumber,
      docStatus: docStatus ?? this.docStatus,
      docNotes: docNotes ?? this.docNotes,
      activeSale: clearActiveSale ? null : (activeSale ?? this.activeSale),
      cancelledSales: cancelledSales ?? this.cancelledSales,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
