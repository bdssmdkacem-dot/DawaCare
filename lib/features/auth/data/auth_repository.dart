import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/user_profile.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signUp({required String email, required String password, required String fullName}) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserProfile?> fetchMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  Future<UserProfile> updateMyProfile(UserProfile profile) async {
    final row = await _client
        .from('profiles')
        .update(profile.toUpdateMap())
        .eq('id', profile.id)
        .select()
        .single();
    return UserProfile.fromMap(row);
  }
}
