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

  // Origem e consignação
  final String ownershipType; // 'own' ou 'consigned'
  final String consignmentType; // 'fixed_payout', 'commission_percent', 'commission_fixed'
  final int consignmentAgreementValueCents;
  final int? consignmentCommissionBps; // Ex: 500 = 5,00%
  final String? consignorName;
  final String? consignorPhone;
  final String? consignorDocument;
  final String? consignmentReturnedDate; // AAAA-MM-DD (devolvido ao proprietário)
  final String? consignmentReturnedNotes;

  // Venda ativa do ciclo
  final ActiveSale? activeSale;

  // Histórico de vendas canceladas
  final List<Map<String, dynamic>> cancelledSales;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String updatedByUid;
  final String? createdByEmail;
  final String? updatedByEmail;

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
    this.ownershipType = AppConstants.ownershipOwn,
    this.consignmentType = AppConstants.consignmentTypeFixedPayout,
    this.consignmentAgreementValueCents = 0,
    this.consignmentCommissionBps,
    this.consignorName,
    this.consignorPhone,
    this.consignorDocument,
    this.consignmentReturnedDate,
    this.consignmentReturnedNotes,
    this.activeSale,
    this.cancelledSales = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
    this.createdByEmail,
    this.updatedByEmail,
  });

  bool get isConsigned => ownershipType == AppConstants.ownershipConsigned;
  bool get isOwn => !isConsigned;
  bool get isReturned =>
      isConsigned &&
      consignmentReturnedDate != null &&
      consignmentReturnedDate!.isNotEmpty;
  bool get isInStock => activeSale == null && !isReturned;
  bool get isSold => activeSale != null;

  bool get hasConsignorInfo =>
      (consignorName != null && consignorName!.isNotEmpty) ||
      (consignorPhone != null && consignorPhone!.isNotEmpty) ||
      (consignorDocument != null && consignorDocument!.isNotEmpty);

  String get formattedPlate => Formatters.formatPlate(plate);
  String get docStatusLabel =>
      AppConstants.docStatusLabels[docStatus] ?? docStatus;
  String get ownershipLabel =>
      AppConstants.ownershipLabels[ownershipType] ?? ownershipType;
  String get consignmentTypeLabel =>
      AppConstants.consignmentTypeLabels[consignmentType] ?? consignmentType;

  String get title => version != null && version!.isNotEmpty
      ? '$brand $model $version'
      : '$brand $model';

  static String? _cleanOptional(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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
      'ownershipType': ownershipType,
      if (isConsigned) ...{
        'consignmentType': consignmentType,
        'consignmentAgreementValueCents': consignmentAgreementValueCents,
        'consignmentCommissionBps': consignmentCommissionBps,
        'consignorName': consignorName,
        'consignorPhone': consignorPhone,
        'consignorDocument': consignorDocument,
        'consignmentReturnedDate': consignmentReturnedDate,
        'consignmentReturnedNotes': consignmentReturnedNotes,
      },
      'activeSale': activeSale?.toMap(),
      'cancelledSales': cancelledSales,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
      'createdByEmail': createdByEmail,
      'updatedByEmail': updatedByEmail,
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

    final rawOwnership = map['ownershipType'] as String?;
    final ownershipType = rawOwnership == AppConstants.ownershipConsigned
        ? AppConstants.ownershipConsigned
        : AppConstants.ownershipOwn;

    final rawConsignmentType = map['consignmentType'] as String?;
    final consignmentType =
        AppConstants.consignmentTypeLabels.containsKey(rawConsignmentType)
            ? rawConsignmentType!
            : AppConstants.consignmentTypeFixedPayout;

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
      ownershipType: ownershipType,
      consignmentType: consignmentType,
      consignmentAgreementValueCents:
          (map['consignmentAgreementValueCents'] as num?)?.toInt() ?? 0,
      consignmentCommissionBps:
          (map['consignmentCommissionBps'] as num?)?.toInt(),
      consignorName: _cleanOptional(map['consignorName']),
      consignorPhone: _cleanOptional(map['consignorPhone']),
      consignorDocument: _cleanOptional(map['consignorDocument']),
      consignmentReturnedDate: _cleanOptional(map['consignmentReturnedDate']),
      consignmentReturnedNotes: _cleanOptional(map['consignmentReturnedNotes']),
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
      createdByEmail: map['createdByEmail'] as String?,
      updatedByEmail: map['updatedByEmail'] as String?,
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
    String? ownershipType,
    String? consignmentType,
    int? consignmentAgreementValueCents,
    int? consignmentCommissionBps,
    String? consignorName,
    String? consignorPhone,
    String? consignorDocument,
    String? consignmentReturnedDate,
    String? consignmentReturnedNotes,
    bool clearConsignmentReturn = false,
    ActiveSale? activeSale,
    bool clearActiveSale = false,
    List<Map<String, dynamic>>? cancelledSales,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
    String? createdByEmail,
    String? updatedByEmail,
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
      ownershipType: ownershipType ?? this.ownershipType,
      consignmentType: consignmentType ?? this.consignmentType,
      consignmentAgreementValueCents:
          consignmentAgreementValueCents ?? this.consignmentAgreementValueCents,
      consignmentCommissionBps:
          consignmentCommissionBps ?? this.consignmentCommissionBps,
      consignorName: consignorName ?? this.consignorName,
      consignorPhone: consignorPhone ?? this.consignorPhone,
      consignorDocument: consignorDocument ?? this.consignorDocument,
      consignmentReturnedDate: clearConsignmentReturn
          ? null
          : (consignmentReturnedDate ?? this.consignmentReturnedDate),
      consignmentReturnedNotes: clearConsignmentReturn
          ? null
          : (consignmentReturnedNotes ?? this.consignmentReturnedNotes),
      activeSale: clearActiveSale ? null : (activeSale ?? this.activeSale),
      cancelledSales: cancelledSales ?? this.cancelledSales,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      updatedByEmail: updatedByEmail ?? this.updatedByEmail,
    );
  }
}

