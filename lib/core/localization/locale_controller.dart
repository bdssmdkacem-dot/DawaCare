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
    _languageCode = prefs.getString(_key);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!['ar', 'en', 'fr'].contains(languageCode)) return;
    _languageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
    notifyListeners();
  }
}
