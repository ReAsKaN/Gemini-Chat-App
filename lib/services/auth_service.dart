import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;


  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }


  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      rethrow;
    }
  }


  Future<void> signOut() async {
    await _auth.signOut();
  }


  Stream<User?> get authStateChanges => _auth.authStateChanges();


  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Şifre çok zayıf!';
      case 'invalid-email':
        return 'Geçersiz email formatı. Örnek: kullanici@ornek.com';
      case 'email-already-in-use':
        return 'Bu email zaten kullanılıyor';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Yanlış şifre';
      default:
        return 'Bir hata oluştu: ${e.message}';
    }
  }
}