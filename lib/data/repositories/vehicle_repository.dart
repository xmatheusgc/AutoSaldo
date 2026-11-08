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

  /// Verifica se há duplicidade de placa ou RENAVAM em veículos "Em estoque"
  Future<bool> hasStockDuplicate(
    String workspaceId, {
    required String plate,
    String? renavam,
    String? excludeVehicleId,
  }) async {
    final normalizedPlate = Formatters.normalizePlate(plate);
    final normalizedRenavam = Formatters.normalizeRenavam(renavam);

    final snapshot = await _vehiclesCol(workspaceId).get();
    for (final doc in snapshot.docs) {
      if (excludeVehicleId != null && doc.id == excludeVehicleId) continue;
      final data = doc.data();
      final activeSale = data['activeSale'];
      // Apenas veículos em estoque
      if (activeSale == null) {
        final existingPlate = Formatters.normalizePlate(data['plate'] as String? ?? '');
        if (existingPlate == normalizedPlate) {
          return true;
        }
        if (normalizedRenavam != null && normalizedRenavam.isNotEmpty) {
          final existingRenavam = Formatters.normalizeRenavam(data['renavam'] as String?);
          if (existingRenavam != null && existingRenavam == normalizedRenavam) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Salva ou atualiza a ficha do veículo
  Future<String> saveVehicle(String workspaceId, Vehicle vehicle, String userUid) async {
    final col = _vehiclesCol(workspaceId);
    final isNew = vehicle.id.isEmpty;
    final docRef = isNew ? col.doc() : col.doc(vehicle.id);
    final now = DateTime.now();

    final data = vehicle.toMap();
    data['updatedAt'] = now.toIso8601String();
    data['updatedByUid'] = userUid;

    if (isNew) {
      data['createdAt'] = now.toIso8601String();
      data['createdByUid'] = userUid;
      await docRef.set(data);
    } else {
      data['createdByUid'] = vehicle.createdByUid;
      await docRef.set(data, SetOptions(merge: true));
    }

    return docRef.id;
  }

  /// Registra uma nova venda ativa em transação
  Future<void> registerSale({
    required String workspaceId,
    required String vehicleId,
    required ActiveSale sale,
    required String userUid,
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

  /// Cancela a venda e retorna o veículo ao estoque em transação
  /// Exige o estorno prévio dos recebimentos válidos registrados
  Future<void> cancelSale({
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
      final activeSale = vehicle.activeSale;
      if (activeSale == null) {
        throw Exception('O veículo já está em estoque.');
      }

      if (activeSale.hasValidPayments) {
        throw Exception('Para cancelar uma venda, todos os recebimentos ativos devem ser estornados previamente.');
      }

      final now = DateTime.now();
      final cancelledRecord = activeSale.toMap();
      cancelledRecord['cancelledAt'] = now.toIso8601String();
      cancelledRecord['cancelledByUid'] = userUid;

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
