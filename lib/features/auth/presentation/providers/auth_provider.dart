import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/notifications/push_notification_service.dart';
import '../../../../models/user_profile.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  UserProfile? profile;
  String? errorMessage;
  bool isLoading = false;

  StreamSubscription<AuthState>? _authSub;

  AuthProvider() {
    _authSub = _repo.onAuthStateChange.listen((state) async {
      if (state.session != null) {
        await _loadProfile();
      } else {
        status = AuthStatus.signedOut;
        profile = null;
        notifyListeners();
      }
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_repo.currentUser != null) {
      await _loadProfile();
    } else {
      status = AuthStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> _loadProfile() async {
    for (int attempt = 0; attempt < 5; attempt++) {
      final p = await _repo.fetchMyProfile();
      if (p != null) {
        profile = p;
        status = AuthStatus.signedIn;
        notifyListeners();
        unawaited(PushNotificationService.instance.ensureRegistered());
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<bool> signUp({required String email, required String password, required String fullName}) {
    if (isLoading) return Future.value(false);
    return _run(() => _repo.signUp(email: email, password: password, fullName: fullName));
  }

  Future<bool> signIn({required String email, required String password}) {
    if (isLoading) return Future.value(false);
    return _run(() => _repo.signIn(email: email, password: password));
  }

  Future<bool> resetPassword(String email) {
    if (isLoading) return Future.value(false);
    return _run(() => _repo.resetPassword(email));
  }

  Future<void> signOut() async {
    final userId = profile?.id;
    if (userId != null) {
      await PushNotificationService.instance.unregister(userId);
    }
    await _repo.signOut();
  }

  Future<void> refreshProfile() => _loadProfile();

  Future<void> updateProfile(UserProfile updated) async {
    profile = await _repo.updateMyProfile(updated);
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (isLoading) return false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = _authErrorMessage(e);
      isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _authErrorMessage(AuthException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    final statusCode = int.tryParse('${error.statusCode}') ?? -1;
    if (statusCode == 429 ||
        code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        message.contains('too many requests') ||
        message.contains('too many attempts') ||
        message.contains('rate limit')) {
      return 'AUTH_RATE_LIMITED';
    }
    return error.message;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
