import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

class HtMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const HtMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ht';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) => false;
}

class HtCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const HtCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ht';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) => false;
}

class HtFlutterQuillLocalizationsDelegate
    extends LocalizationsDelegate<FlutterQuillLocalizations> {
  const HtFlutterQuillLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ht';

  @override
  Future<FlutterQuillLocalizations> load(Locale locale) {
    return FlutterQuillLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<FlutterQuillLocalizations> old) => false;
}
