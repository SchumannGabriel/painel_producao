import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Future<String?> login(String email, String senha) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      return null; // sucesso
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('FirebaseAuthException → code: ${e.code} | msg: ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          return 'Usuário não encontrado.';
        case 'wrong-password':
          return 'Senha incorreta.';
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-disabled':
          return 'Usuário desabilitado.';
        case 'invalid-credential':
        case 'INVALID_LOGIN_CREDENTIALS':
          return 'E-mail ou senha incorretos.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde alguns minutos.';
        case 'network-request-failed':
          return 'Sem conexão com a internet.';
        default:
          return 'E-mail ou senha incorretos. (${e.code})';
      }
    } catch (e) {
      // ignore: avoid_print
      print('Login error genérico: $e');
      return 'Erro inesperado: ${e.toString()}';
    }
  }

  Future<void> logout() => _auth.signOut();
}
