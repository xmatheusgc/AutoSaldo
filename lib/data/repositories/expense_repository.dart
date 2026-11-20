import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../domain/models/expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _expensesCol(String workspaceId) =>
      _firestore.collection('workspaces').doc(workspaceId).collection('expenses');

  /// Stream em tempo real de todas as despesas do workspace
  Stream<List<Expense>> getExpensesStream(String workspaceId) {
    return _expensesCol(workspaceId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromMap(doc.data()..['id'] = doc.id);
      }).toList();
    });
  }

  /// Stream em tempo real apenas das despesas de um veículo específico
  Stream<List<Expense>> getVehicleExpensesStream(String workspaceId, String vehicleId) {
    return _expensesCol(workspaceId)
        .where('vehicleId', isEqualTo: vehicleId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return Expense.fromMap(doc.data()..['id'] = doc.id);
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Cria uma nova despesa vinculada a um veículo existente
  Future<String> createExpense(
    String workspaceId,
    Expense expense,
    String userUid, {
    String? userEmail,
  }) async {
    final col = _expensesCol(workspaceId);
    final docRef = col.doc();
    final now = DateTime.now();

    final data = expense.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = now.toIso8601String();
    data['updatedAt'] = now.toIso8601String();
    data['createdByUid'] = userUid;
    data['updatedByUid'] = userUid;
    if (userEmail != null) {
      data['createdByEmail'] = userEmail;
      data['updatedByEmail'] = userEmail;
    }

    await docRef.set(data);
    return docRef.id;
  }

  /// Atualiza apenas os campos editáveis de uma despesa sem sobrescrever auditoria de criação
  Future<void> updateExpense(
    String workspaceId,
    Expense expense,
    String userUid, {
    String? userEmail,
  }) async {
    final docRef = _expensesCol(workspaceId).doc(expense.id);
    final now = DateTime.now();

    await docRef.update({
      'amountCents': expense.amountCents,
      'date': expense.date,
      'category': expense.category,
      'description': expense.description,
      'updatedAt': now.toIso8601String(),
      'updatedByUid': userUid,
      'updatedByEmail': ?userEmail,
    });
  }

  /// Estorna uma despesa registrada
  Future<void> revertExpense(String workspaceId, String expenseId, String userUid) async {
    final docRef = _expensesCol(workspaceId).doc(expenseId);
    final now = DateTime.now();

    await docRef.update({
      'status': AppConstants.statusReverted,
      'revertedAt': now.toIso8601String(),
      'revertedByUid': userUid,
      'updatedAt': now.toIso8601String(),
      'updatedByUid': userUid,
    });
  }
}

