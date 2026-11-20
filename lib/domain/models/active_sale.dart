import '../../core/constants.dart';
import 'payment.dart';

class ActiveSale {
  final String id;
  final String saleDate; // AAAA-MM-DD
  final int salePriceCents;
  final String? buyerName;
  final String? buyerPhone;
  final String? buyerDocument;
  final List<Payment> payments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String updatedByUid;
  final String? createdByEmail;
  final String? updatedByEmail;

  ActiveSale({
    required this.id,
    required this.saleDate,
    required this.salePriceCents,
    this.buyerName,
    this.buyerPhone,
    this.buyerDocument,
    this.payments = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
    this.createdByEmail,
    this.updatedByEmail,
  });

  bool get hasBuyerInfo =>
      (buyerName != null && buyerName!.isNotEmpty) ||
      (buyerPhone != null && buyerPhone!.isNotEmpty) ||
      (buyerDocument != null && buyerDocument!.isNotEmpty);

  /// Total de pagamentos válidos já recebidos
  int get totalReceivedCents {
    int total = 0;
    for (final p in payments) {
      if (p.isValid) {
        total += p.amountCents;
      }
    }
    return total;
  }

  /// Saldo restante a receber
  int get balanceDueCents {
    final balance = salePriceCents - totalReceivedCents;
    return balance > 0 ? balance : 0;
  }

  /// Status financeiro da venda (Quitado, Parcial ou Em aberto)
  String get paymentStatus {
    final received = totalReceivedCents;
    if (received >= salePriceCents) {
      return AppConstants.paymentStatusSettled;
    } else if (received > 0) {
      return AppConstants.paymentStatusPartial;
    }
    return AppConstants.paymentStatusOpen;
  }

  bool get hasValidPayments => payments.any((p) => p.isValid);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleDate': saleDate,
      'salePriceCents': salePriceCents,
      'buyerName': ?buyerName,
      'buyerPhone': ?buyerPhone,
      'buyerDocument': ?buyerDocument,
      'payments': payments.map((p) => p.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
      'createdByEmail': createdByEmail,
      'updatedByEmail': updatedByEmail,
    };
  }

  static String? _cleanOptional(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory ActiveSale.fromMap(Map<String, dynamic> map) {
    final paymentsRaw = map['payments'] as List<dynamic>? ?? [];
    final paymentsList = paymentsRaw
        .map((item) => Payment.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return ActiveSale(
      id: map['id'] as String? ?? '',
      saleDate: map['saleDate'] as String? ?? '',
      salePriceCents: (map['salePriceCents'] as num?)?.toInt() ?? 0,
      buyerName: _cleanOptional(map['buyerName']),
      buyerPhone: _cleanOptional(map['buyerPhone']),
      buyerDocument: _cleanOptional(map['buyerDocument']),
      payments: paymentsList,
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

  ActiveSale copyWith({
    String? id,
    String? saleDate,
    int? salePriceCents,
    String? buyerName,
    String? buyerPhone,
    String? buyerDocument,
    List<Payment>? payments,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
    String? createdByEmail,
    String? updatedByEmail,
  }) {
    return ActiveSale(
      id: id ?? this.id,
      saleDate: saleDate ?? this.saleDate,
      salePriceCents: salePriceCents ?? this.salePriceCents,
      buyerName: buyerName ?? this.buyerName,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerDocument: buyerDocument ?? this.buyerDocument,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      updatedByEmail: updatedByEmail ?? this.updatedByEmail,
    );
  }

  /// Cria cópia substituindo integralmente os campos opcionais do comprador (permite limpar para null).
  ActiveSale withBuyerInfo({
    String? buyerName,
    String? buyerPhone,
    String? buyerDocument,
    required DateTime updatedAt,
    required String updatedByUid,
  }) {
    return ActiveSale(
      id: id,
      saleDate: saleDate,
      salePriceCents: salePriceCents,
      buyerName: _cleanOptional(buyerName),
      buyerPhone: _cleanOptional(buyerPhone),
      buyerDocument: _cleanOptional(buyerDocument),
      payments: payments,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdByUid: createdByUid,
      updatedByUid: updatedByUid,
      createdByEmail: createdByEmail,
      updatedByEmail: updatedByEmail,
    );
  }
}

