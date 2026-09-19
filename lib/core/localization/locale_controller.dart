import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _key = 'dawacare_locale';

  String? _languageCode;
  bool _loaded = false;

  String? get languageCode => _languageCode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = _normalize(prefs.getString(_key));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    final normalized = _normalize(languageCode);
    if (normalized == null) return;
    if (_languageCode == normalized) return;
    _languageCode = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalized);
    notifyListeners();
  }

  Future<void> syncFromProfile(String? languageCode) async {
    final normalized = _normalize(languageCode);
    if (normalized == null) return;
    if (_languageCode == normalized) return;
    _languageCode = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalized);
    notifyListeners();
  }

  static String? _normalize(String? value) =>
      value != null && ['ar', 'en', 'fr'].contains(value) ? value : null;
}
