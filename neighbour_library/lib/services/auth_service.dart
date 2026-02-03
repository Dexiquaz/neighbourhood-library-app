import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authState => _client.auth.onAuthStateChange;

  Future<void> login({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signup({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
