import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl_standalone.dart' if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

class EasyLocalizationController extends ChangeNotifier {
  static Locale? _savedLocale;
  static late Locale _deviceLocale;

  late Locale _locale;
  Locale? _fallbackLocale;

  final Function(FlutterError e) onLoadError;
  final assetLoader;
  final String path;
  final bool useFallbackTranslations;
  final bool saveLocale;
  final bool useOnlyLangCode;
  Translations? _translations, _fallbackTranslations;
  Translations? get translations => _translations;
  Translations? get fallbackTranslations => _fallbackTranslations;

  EasyLocalizationController({
    required List<Locale> supportedLocales,
    required this.useFallbackTranslations,
    required this.saveLocale,
    required this.assetLoader,
    required this.path,
    required this.useOnlyLangCode,
    required this.onLoadError,
    Locale? startLocale,
    Locale? fallbackLocale,
    Locale? forceLocale, // used for testing
  }) {
    _fallbackLocale = fallbackLocale;
    if (forceLocale != null) {
      _locale = forceLocale;
    } else if (_savedLocale == null && startLocale != null) {
      _locale = _getFallbackLocale(supportedLocales, startLocale);
      EasyLocalization.logger('Start locale loaded ${_locale.toString()}');
    }
    // If saved locale then get
    else if (saveLocale && _savedLocale != null) {
      EasyLocalization.logger('Saved locale loaded ${_savedLocale.toString()}');
      _locale = _savedLocale!;
    } else {
      if (_deviceLocale.languageCode == 'zh') {
        _locale = _getZhLocale(_deviceLocale, supportedLocales);
      } else {
        // From Device Locale
        _locale = supportedLocales.firstWhere((locale) => _checkInitLocale(locale, _deviceLocale),
            orElse: () => _getFallbackLocale(supportedLocales, fallbackLocale));
      }
    }
  }

  //Get fallback Locale
  Locale _getFallbackLocale(List<Locale> supportedLocales, Locale? fallbackLocale) {
    //If fallbackLocale not set then return first from supportedLocales
    if (fallbackLocale != null) {
      return fallbackLocale;
    } else {
      return supportedLocales.first;
    }
  }

  bool _checkInitLocale(Locale locale, Locale? _deviceLocale) {
    // If supported locale not contain countryCode then check only languageCode
    if (locale.countryCode == null) {
      return (locale.languageCode == _deviceLocale!.languageCode);
    } else {
      return (locale == _deviceLocale);
    }
  }

  Future loadTranslations() async {
    Map<String, dynamic> data;
    try {
      data = await loadTranslationData(_locale);
      _translations = Translations(data);
      if (useFallbackTranslations && _fallbackLocale != null) {
        data = await loadTranslationData(_fallbackLocale!);
        _fallbackTranslations = Translations(data);
      }
    } on FlutterError catch (e) {
      onLoadError(e);
    } catch (e) {
      onLoadError(FlutterError(e.toString()));
    }
  }

  Future loadTranslationData(Locale locale) async {
    if (useOnlyLangCode) {
      return assetLoader.load(path, Locale(locale.languageCode));
    } else {
      return assetLoader.load(path, locale);
    }
  }

  Locale get locale => _locale;

  Future<void> setLocale(Locale l) async {
    _locale = l;
    await loadTranslations();
    notifyListeners();
    EasyLocalization.logger('Locale $locale changed');
    await _saveLocale(_locale);
  }

  Future<void> _saveLocale(Locale? locale) async {
    if (!saveLocale) return;
    final _preferences = await SharedPreferences.getInstance();
    await _preferences.setString('locale', locale.toString());
    EasyLocalization.logger('Locale $locale saved');
  }

  static Future<void> initEasyLocation() async {
    final _preferences = await SharedPreferences.getInstance();
    final _strLocale = _preferences.getString('locale');
    _savedLocale = _strLocale != null ? _strLocale.toLocale() : null;
    final _foundPlatformLocale = await findSystemLocale();
    _deviceLocale = _foundPlatformLocale.toLocale();
    EasyLocalization.logger.debug('Localization initialized');
  }

  Future<void> deleteSaveLocale() async {
    _savedLocale = null;
    final _preferences = await SharedPreferences.getInstance();
    await _preferences.remove('locale');
    EasyLocalization.logger('Saved locale deleted');
  }

  Locale get deviceLocale => _deviceLocale;

  Future<void> resetLocale() async {
    EasyLocalization.logger('Reset locale to platform locale $_deviceLocale');

    await setLocale(_deviceLocale);
  }

  Locale _getZhLocale(Locale _osLocale, List<Locale> supportedLocales) {
    final zhSupportedList = <Locale>[];
    supportedLocales.forEach((element) {
      if (element.languageCode == 'zh') {
        zhSupportedList.add(element);
      }
    });
    if (zhSupportedList.isEmpty) {
      return _getFallbackLocale(supportedLocales, _fallbackLocale);
    }
    if (_osLocale.scriptCode != null && zhSupportedList.any((element) => element.scriptCode != null)) {
      return zhSupportedList.firstWhere(
        (locale) => _osLocale.scriptCode == locale.scriptCode,
        orElse: () => _getZHLocaleByContryCode(_osLocale, zhSupportedList, supportedLocales),
      );
    } else {
      return _getZHLocaleByContryCode(_osLocale, zhSupportedList, supportedLocales);
    }
  }

  Locale _getZHLocaleByContryCode(Locale _osLocale, List<Locale> zhSupportedList, List<Locale> supportedLocales) {
    return zhSupportedList.firstWhere(
      (locale) => _osLocale.countryCode == locale.countryCode,
      orElse: () => _getZHLocaleByLang(_osLocale, zhSupportedList, supportedLocales),
    );
  }

  Locale _getZHLocaleByLang(Locale _osLocale, List<Locale> zhSupportedList, List<Locale> supportedLocales) {
    return zhSupportedList.firstWhere(
      (locale) => locale.languageCode == _osLocale.languageCode,
      orElse: () => _getFallbackLocale(supportedLocales, _fallbackLocale),
    );
  }
}
