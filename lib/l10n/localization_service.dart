import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'translations.dart';

class LocalizationService extends ChangeNotifier {
  String _locale = 'en';
  
  String get locale => _locale;
  
  void setLocale(String newLocale) {
    if (_locale != newLocale) {
      _locale = newLocale;
      notifyListeners();
    }
  }
  
  String translate(String key) {
    return AppTranslations.get(_locale, key);
  }
  
  // Helper method to get translations from context
  static String of(BuildContext context, String key) {
    return Provider.of<LocalizationService>(context).translate(key);
  }
}