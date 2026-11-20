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
        if (doc.data()['activeSale'] == null) {
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
        if (doc.data()['activeSale'] == null) {
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

      if (!Validators.isValidSaleDate(vehicle.purchaseDate, sale.saleDate)) {
        throw Exception('A data da venda deve ser igual ou posterior à data da compra e não pode ser futura.');
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

      if (activeSale.hasValidPayments && !revertPaymentsAtomically) {
        throw Exception('Para cancelar uma venda, todos os recebimentos ativos devem ser estornados previamente.');
      }

      final now = DateTime.now();
      ActiveSale saleToArchive = activeSale;
      if (activeSale.hasValidPayments && revertPaymentsAtomically) {
        final revertedPayments = activeSale.payments.map((p) {
          if (!p.isValid) return p;
          return p.copyWith(
            status: AppConstants.statusReverted,
            revertedAt: now,
            revertedByUid: userUid,
          );
        }).toList();
        saleToArchive = activeSale.copyWith(
          payments: revertedPayments,
          updatedAt: now,
          updatedByUid: userUid,
        );
      }

      final cancelledRecord = saleToArchive.toMap();
      cancelledRecord['cancelledAt'] = now.toIso8601String();
      cancelledRecord['cancelledByUid'] = userUid;
      if (activeSale.hasValidPayments && revertPaymentsAtomically) {
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
}

