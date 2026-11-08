import '../../core/constants.dart';

class Payment {
  final String id;
  final int amountCents;
  final String date; // AAAA-MM-DD
  final String status; // 'valid' ou 'reverted'
  final DateTime createdAt;
  final String createdByUid;
  final DateTime? revertedAt;
  final String? revertedByUid;

  Payment({
    required this.id,
    required this.amountCents,
    required this.date,
    this.status = AppConstants.statusValid,
    required this.createdAt,
    required this.createdByUid,
    this.revertedAt,
    this.revertedByUid,
  });

  bool get isValid => status == AppConstants.statusValid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amountCents': amountCents,
      'date': date,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'createdByUid': createdByUid,
      'revertedAt': revertedAt?.toIso8601String(),
      'revertedByUid': revertedByUid,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String? ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      date: map['date'] as String? ?? '',
      status: map['status'] as String? ?? AppConstants.statusValid,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdByUid: map['createdByUid'] as String? ?? '',
      revertedAt: map['revertedAt'] != null
          ? DateTime.tryParse(map['revertedAt'].toString())
          : null,
      revertedByUid: map['revertedByUid'] as String?,
    );
  }

  Payment copyWith({
    String? id,
    int? amountCents,
    String? date,
    String? status,
    DateTime? createdAt,
    String? createdByUid,
    DateTime? revertedAt,
    String? revertedByUid,
  }) {
    return Payment(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdByUid: createdByUid ?? this.createdByUid,
      revertedAt: revertedAt ?? this.revertedAt,
      revertedByUid: revertedByUid ?? this.revertedByUid,
    );
  }
}
