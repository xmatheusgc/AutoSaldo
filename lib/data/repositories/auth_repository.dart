import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Login com e-mail e senha
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Erro ao autenticar. Verifique sua conexão e tente novamente.';
    }
  }

  /// Login com provedor Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      
      if (kIsWeb) {
        return await _auth.signInWithPopup(googleProvider);
      } else {
        return await _auth.signInWithProvider(googleProvider);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Erro ao realizar login com Google. Tente novamente.';
    }
  }

  /// Recuperação de senha por e-mail
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Erro ao enviar e-mail de recuperação de senha.';
    }
  }

  /// Encerramento de sessão
  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Já existe uma conta vinculada a este e-mail usando outro método de login. Faça login com o método original.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'invalid-email':
        return 'Formato de e-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada pelo administrador.';
      case 'popup-closed-by-user':
        return 'A janela de login com Google foi fechada antes de concluir.';
      case 'network-request-failed':
        return 'Falha de conexão com a internet. Verifique sua rede.';
      case 'too-many-requests':
        return 'Muitas tentativas sem sucesso. Aguarde alguns minutos antes de tentar novamente.';
      default:
        return e.message ?? 'Ocorreu um erro na autenticação (${e.code}).';
    }
  }
}

