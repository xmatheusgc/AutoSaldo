import '../../core/constants.dart';

class Expense {
  final String id;
  final String vehicleId;
  final int amountCents;
  final String date; // AAAA-MM-DD
  final String category;
  final String? description;
  final String status; // 'valid' ou 'reverted'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdByUid;
  final String updatedByUid;
  final DateTime? revertedAt;
  final String? revertedByUid;

  Expense({
    required this.id,
    required this.vehicleId,
    required this.amountCents,
    required this.date,
    required this.category,
    this.description,
    this.status = AppConstants.statusValid,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUid,
    required this.updatedByUid,
    this.revertedAt,
    this.revertedByUid,
  });

  bool get isValid => status == AppConstants.statusValid;

  String get categoryLabel =>
      AppConstants.expenseCategoryLabels[category] ?? category;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'amountCents': amountCents,
      'date': date,
      'category': category,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
      'revertedAt': revertedAt?.toIso8601String(),
      'revertedByUid': revertedByUid,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String? ?? '',
      vehicleId: map['vehicleId'] as String? ?? '',
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      date: map['date'] as String? ?? '',
      category: map['category'] as String? ?? AppConstants.expenseCategoryOther,
      description: map['description'] as String?,
      status: map['status'] as String? ?? AppConstants.statusValid,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdByUid: map['createdByUid'] as String? ?? '',
      updatedByUid: map['updatedByUid'] as String? ?? '',
      revertedAt: map['revertedAt'] != null
          ? DateTime.tryParse(map['revertedAt'].toString())
          : null,
      revertedByUid: map['revertedByUid'] as String?,
    );
  }

  Expense copyWith({
    String? id,
    String? vehicleId,
    int? amountCents,
    String? date,
    String? category,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
    DateTime? revertedAt,
    String? revertedByUid,
  }) {
    return Expense(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      revertedAt: revertedAt ?? this.revertedAt,
      revertedByUid: revertedByUid ?? this.revertedByUid,
    );
  }
}

