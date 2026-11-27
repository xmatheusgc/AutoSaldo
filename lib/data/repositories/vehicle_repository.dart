import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../domain/models/active_sale.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/vehicle.dart';

class VehicleRepository {
  final FirebaseFirestore _firestore;

  VehicleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _vehiclesCol(String workspaceId) =>
      _firestore.collection('workspaces').doc(workspaceId).collection('vehicles');

  /// Stream em tempo real de todos os veículos do workspace
  Stream<List<Vehicle>> getVehiclesStream(String workspaceId) {
    return _vehiclesCol(workspaceId)
        .orderBy('purchaseDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Vehicle.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Busca um veículo pelo ID
  Future<Vehicle?> getVehicle(String workspaceId, String vehicleId) async {
    final doc = await _vehiclesCol(workspaceId).doc(vehicleId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Vehicle.fromMap(doc.id, doc.data()!);
  }

  /// Stream em tempo real de um único veículo pelo ID
  Stream<Vehicle?> getVehicleStream(String workspaceId, String vehicleId) {
    return _vehiclesCol(workspaceId).doc(vehicleId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Vehicle.fromMap(doc.id, doc.data()!);
    });
  }

  bool _isDocInStock(Map<String, dynamic> data) {
    final activeSale = data['activeSale'];
    final returnedDate = data['consignmentReturnedDate'];
    final isReturned =
        returnedDate is String && returnedDate.trim().isNotEmpty;
    return activeSale == null && !isReturned;
  }

  /// Verifica se há duplicidade de placa ou RENAVAM em veículos "Em estoque"
  Future<bool> hasStockDuplicate(
    String workspaceId, {
    required String plate,
    String? renavam,
    String? excludeVehicleId,
  }) async {
    final normalizedPlate = Formatters.normalizePlate(plate);
    final normalizedRenavam = Formatters.normalizeRenavam(renavam);

    if (normalizedPlate.isNotEmpty) {
      final plateSnap = await _vehiclesCol(workspaceId)
          .where('plate', isEqualTo: normalizedPlate)
          .get();
      for (final doc in plateSnap.docs) {
        if (excludeVehicleId != null && doc.id == excludeVehicleId) continue;
        if (_isDocInStock(doc.data())) {
          return true;
        }
      }
    }

    if (normalizedRenavam != null && normalizedRenavam.isNotEmpty) {
      final renavamSnap = await _vehiclesCol(workspaceId)
          .where('renavam', isEqualTo: normalizedRenavam)
          .get();
      for (final doc in renavamSnap.docs) {
        if (excludeVehicleId != null && doc.id == excludeVehicleId) continue;
        if (_isDocInStock(doc.data())) {
          return true;
        }
      }
    }

    return false;
  }

  /// Salva ou atualiza a ficha do veículo
  Future<String> saveVehicle(
    String workspaceId,
    Vehicle vehicle,
    String userUid, {
    String? userEmail,
  }) async {
    final col = _vehiclesCol(workspaceId);
    final isNew = vehicle.id.isEmpty;
    final docRef = isNew ? col.doc() : col.doc(vehicle.id);
    final now = DateTime.now();

    if (isNew) {
      final data = vehicle.toMap();
      data['updatedAt'] = now.toIso8601String();
      data['updatedByUid'] = userUid;
      data['createdAt'] = now.toIso8601String();
      data['createdByUid'] = userUid;
      if (userEmail != null) {
        data['updatedByEmail'] = userEmail;
        data['createdByEmail'] = userEmail;
      }
      await docRef.set(data);
    } else {
      final updates = <String, dynamic>{
        'brand': vehicle.brand,
        'model': vehicle.model,
        'version': vehicle.version,
        'plate': vehicle.plate,
        'purchaseDate': vehicle.purchaseDate,
        'purchasePriceCents': vehicle.purchasePriceCents,
        'announcedPriceCents': vehicle.announcedPriceCents,
        'notes': vehicle.notes,
        'renavam': vehicle.renavam,
        'licensingYear': vehicle.licensingYear,
        'manufactureYear': vehicle.manufactureYear,
        'modelYear': vehicle.modelYear,
        'crvNumber': vehicle.crvNumber,
        'docStatus': vehicle.docStatus,
        'docNotes': vehicle.docNotes,
        'ownershipType': vehicle.ownershipType,
        'consignmentType': vehicle.isConsigned ? vehicle.consignmentType : null,
        'consignmentAgreementValueCents':
            vehicle.isConsigned ? vehicle.consignmentAgreementValueCents : null,
        'consignmentCommissionBps':
            vehicle.isConsigned ? vehicle.consignmentCommissionBps : null,
        'consignorName': vehicle.isConsigned ? vehicle.consignorName : null,
        'consignorPhone': vehicle.isConsigned ? vehicle.consignorPhone : null,
        'consignorDocument':
            vehicle.isConsigned ? vehicle.consignorDocument : null,
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
        'updatedByEmail': ?userEmail,
      };
      await docRef.update(updates);
    }

    return docRef.id;
  }

  /// Registra uma nova venda ativa em transação
  Future<void> registerSale({
    required String workspaceId,
    required String vehicleId,
    required ActiveSale sale,
    required String userUid,
    String? userEmail,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      if (vehicle.activeSale != null) {
        throw Exception('Este veículo já possui uma venda ativa registrada.');
      }
      if (vehicle.isReturned) {
        throw Exception('Este veículo consignado foi devolvido ao proprietário.');
      }

      if (!Validators.isValidSaleDate(vehicle.purchaseDate, sale.saleDate)) {
        throw Exception(
          vehicle.isConsigned
              ? 'A data da venda deve ser igual ou posterior à data de entrada no pátio e não pode ser futura.'
              : 'A data da venda deve ser igual ou posterior à data da compra e não pode ser futura.',
        );
      }

      final now = DateTime.now();
      final saleMap = sale.toMap();
      saleMap['createdAt'] = now.toIso8601String();
      saleMap['updatedAt'] = now.toIso8601String();
      saleMap['createdByUid'] = userUid;
      saleMap['updatedByUid'] = userUid;
      if (userEmail != null) {
        saleMap['createdByEmail'] = userEmail;
        saleMap['updatedByEmail'] = userEmail;
      }

      transaction.update(docRef, {
        'activeSale': saleMap,
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Atualiza o valor negociado da venda em transação
  Future<void> updateSalePrice({
    required String workspaceId,
    required String vehicleId,
    required int newSalePriceCents,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('O veículo não possui venda ativa para editar.');
      }

      if (newSalePriceCents < activeSale.totalReceivedCents) {
        throw Exception('O novo valor da venda não pode ser menor que o total já recebido.');
      }

      final now = DateTime.now();
      final updatedSale = activeSale.copyWith(
        salePriceCents: newSalePriceCents,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Atualiza os dados do comprador da venda ativa em transação
  Future<void> updateSaleBuyerInfo({
    required String workspaceId,
    required String vehicleId,
    String? buyerName,
    String? buyerPhone,
    String? buyerDocument,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('O veículo não possui venda ativa para editar.');
      }

      final now = DateTime.now();
      final updatedSale = activeSale.withBuyerInfo(
        buyerName: buyerName,
        buyerPhone: buyerPhone,
        buyerDocument: buyerDocument,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Adiciona um recebimento à venda ativa em transação
  Future<void> addPayment({
    required String workspaceId,
    required String vehicleId,
    required Payment payment,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('Não é possível adicionar recebimento a um veículo em estoque.');
      }

      if (!Validators.isValidPaymentDate(activeSale.saleDate, payment.date)) {
        throw Exception('A data do recebimento deve ser igual ou posterior à data da venda e não pode ser futura.');
      }

      final newTotal = activeSale.totalReceivedCents + payment.amountCents;
      if (newTotal > activeSale.salePriceCents) {
        throw Exception('O total recebido não pode ultrapassar o valor negociado da venda.');
      }

      final now = DateTime.now();
      final updatedPayments = List<Payment>.from(activeSale.payments)
        ..add(payment.copyWith(
          createdAt: now,
          createdByUid: userUid,
        ));

      final updatedSale = activeSale.copyWith(
        payments: updatedPayments,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Estorna um recebimento registrado em transação
  Future<void> revertPayment({
    required String workspaceId,
    required String vehicleId,
    required String paymentId,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('Venda ativa não encontrada.');
      }

      final now = DateTime.now();
      final updatedPayments = activeSale.payments.map((p) {
        if (p.id == paymentId) {
          return p.copyWith(
            status: AppConstants.statusReverted,
            revertedAt: now,
            revertedByUid: userUid,
          );
        }
        return p;
      }).toList();

      final updatedSale = activeSale.copyWith(
        payments: updatedPayments,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Cancela a venda e retorna o veículo ao estoque em transação.
  /// Quando [revertPaymentsAtomically] é `true`, estorna automaticamente todos
  /// os recebimentos ativos dentro da mesma transação.
  Future<void> cancelSale({
    required String workspaceId,
    required String vehicleId,
    required String userUid,
    bool revertPaymentsAtomically = false,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('O veículo já está em estoque.');
      }

      final hasActiveEntries =
          activeSale.hasValidPayments || activeSale.hasValidOwnerPayouts;
      if (hasActiveEntries && !revertPaymentsAtomically) {
        throw Exception('Para cancelar uma venda, todos os recebimentos e repasses ativos devem ser estornados previamente.');
      }

      final now = DateTime.now();
      ActiveSale saleToArchive = activeSale;
      if (hasActiveEntries && revertPaymentsAtomically) {
        final revertedPayments = activeSale.payments.map((p) {
          if (!p.isValid) return p;
          return p.copyWith(
            status: AppConstants.statusReverted,
            revertedAt: now,
            revertedByUid: userUid,
          );
        }).toList();
        final revertedPayouts = activeSale.ownerPayouts.map((p) {
          if (!p.isValid) return p;
          return p.copyWith(
            status: AppConstants.statusReverted,
            revertedAt: now,
            revertedByUid: userUid,
          );
        }).toList();
        saleToArchive = activeSale.copyWith(
          payments: revertedPayments,
          ownerPayouts: revertedPayouts,
          updatedAt: now,
          updatedByUid: userUid,
        );
      }

      final cancelledRecord = saleToArchive.toMap();
      cancelledRecord['cancelledAt'] = now.toIso8601String();
      cancelledRecord['cancelledByUid'] = userUid;
      if (hasActiveEntries && revertPaymentsAtomically) {
        cancelledRecord['revertedPaymentsAtomically'] = true;
      }

      final updatedCancelledSales = List<Map<String, dynamic>>.from(vehicle.cancelledSales)
        ..add(cancelledRecord);

      transaction.update(docRef, {
        'activeSale': null,
        'cancelledSales': updatedCancelledSales,
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Registra um repasse pago ao proprietário em venda de veículo consignado
  Future<void> addOwnerPayout({
    required String workspaceId,
    required String vehicleId,
    required Payment payout,
    required int maxNetPayoutCents,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      if (!vehicle.isConsigned) {
        throw Exception('Apenas veículos consignados possuem repasse ao proprietário.');
      }
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('Não é possível registrar repasse para um veículo não vendido.');
      }

      if (!Validators.isValidPaymentDate(activeSale.saleDate, payout.date)) {
        throw Exception('A data do repasse deve ser igual ou posterior à data da venda e não pode ser futura.');
      }

      final newTotal = activeSale.totalOwnerPayoutPaidCents + payout.amountCents;
      if (newTotal > maxNetPayoutCents) {
        throw Exception('O total repassado não pode ultrapassar o repasse líquido combinado.');
      }

      final now = DateTime.now();
      final updatedPayouts = List<Payment>.from(activeSale.ownerPayouts)
        ..add(payout.copyWith(
          createdAt: now,
          createdByUid: userUid,
        ));

      final updatedSale = activeSale.copyWith(
        ownerPayouts: updatedPayouts,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Estorna um repasse ao proprietário registrado em transação
  Future<void> revertOwnerPayout({
    required String workspaceId,
    required String vehicleId,
    required String payoutId,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('Venda ativa não encontrada.');
      }

      final now = DateTime.now();
      final updatedPayouts = activeSale.ownerPayouts.map((p) {
        if (p.id == payoutId) {
          return p.copyWith(
            status: AppConstants.statusReverted,
            revertedAt: now,
            revertedByUid: userUid,
          );
        }
        return p;
      }).toList();

      final updatedSale = activeSale.copyWith(
        ownerPayouts: updatedPayouts,
        updatedAt: now,
        updatedByUid: userUid,
      );

      transaction.update(docRef, {
        'activeSale': updatedSale.toMap(),
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Marca um veículo consignado em estoque como devolvido ao proprietário
  Future<void> returnConsignedVehicle({
    required String workspaceId,
    required String vehicleId,
    required String returnedDate,
    String? notes,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      if (!vehicle.isConsigned) {
        throw Exception('Apenas veículos consignados podem ser devolvidos ao proprietário.');
      }
      if (vehicle.activeSale != null) {
        throw Exception('Não é possível devolver um veículo com venda ativa.');
      }
      if (!Validators.isValidSaleDate(vehicle.purchaseDate, returnedDate)) {
        throw Exception('A data de devolução deve ser igual ou posterior à entrada no pátio e não pode ser futura.');
      }

      final now = DateTime.now();
      final trimmedNotes = notes?.trim();
      transaction.update(docRef, {
        'consignmentReturnedDate': returnedDate,
        'consignmentReturnedNotes':
            (trimmedNotes != null && trimmedNotes.isNotEmpty) ? trimmedNotes : null,
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Reabre um veículo consignado devolvido, retornando-o ao estoque
  Future<void> reopenConsignedVehicle({
    required String workspaceId,
    required String vehicleId,
    required String userUid,
  }) async {
    final docRef = _vehiclesCol(workspaceId).doc(vehicleId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw Exception('Veículo não encontrado.');
      }

      final vehicle = Vehicle.fromMap(snapshot.id, snapshot.data()!);
      if (!vehicle.isConsigned || !vehicle.isReturned) {
        throw Exception('Este veículo não está marcado como devolvido.');
      }

      final now = DateTime.now();
      transaction.update(docRef, {
        'consignmentReturnedDate': null,
        'consignmentReturnedNotes': null,
        'updatedAt': now.toIso8601String(),
        'updatedByUid': userUid,
      });
    });
  }

  /// Exclui permanentemente um veículo sem venda ativa e todas as suas despesas em lote atômico.
  Future<void> deleteVehicleWithExpenses({
    required String workspaceId,
    required String vehicleId,
  }) async {
    final vehicleRef = _vehiclesCol(workspaceId).doc(vehicleId);
    final vehicleSnap = await vehicleRef.get();
    if (!vehicleSnap.exists || vehicleSnap.data() == null) {
      throw Exception('Veículo não encontrado.');
    }

    final vehicle = Vehicle.fromMap(vehicleSnap.id, vehicleSnap.data()!);
    if (vehicle.isSold) {
      throw Exception(
        'Não é possível excluir um veículo com venda ativa. Cancele a venda primeiro.',
      );
    }

    final expensesCol = _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('expenses');
    final expensesSnap =
        await expensesCol.where('vehicleId', isEqualTo: vehicleId).get();

    if (expensesSnap.docs.length >= 500) {
      throw Exception(
        'Este veículo possui muitas despesas para exclusão em lote único. Estorne ou remova em partes.',
      );
    }

    final batch = _firestore.batch();
    for (final expDoc in expensesSnap.docs) {
      batch.delete(expDoc.reference);
    }
    batch.delete(vehicleRef);
    await batch.commit();
  }
}

