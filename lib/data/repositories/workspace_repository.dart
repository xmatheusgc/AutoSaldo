import 'package:cloud_firestore/cloud_firestore.dart';

class WorkspaceRepository {
  final FirebaseFirestore _firestore;

  WorkspaceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Verifica se o UID fornecido está cadastrado como membro autorizado do workspace
  Future<bool> isUserAuthorized({
    required String workspaceId,
    required String uid,
  }) async {
    try {
      final doc = await _firestore
          .collection('workspaces')
          .doc(workspaceId)
          .collection('members')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (_) {
      // Se as security rules negarem leitura ou se não existir o documento
      return false;
    }
  }

  /// Observa em tempo real a associação do membro
  Stream<bool> watchUserAuthorization({
    required String workspaceId,
    required String uid,
  }) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Retorna o nome do espaço de trabalho, se existir
  Future<String> getWorkspaceName(String workspaceId) async {
    try {
      final doc = await _firestore.collection('workspaces').doc(workspaceId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()?['name'] as String? ?? 'AutoSaldo';
      }
    } catch (_) {}
    return 'AutoSaldo';
  }
}

