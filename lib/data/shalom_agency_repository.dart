import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/shalom_agency.dart';

class ShalomAgencyRepository {
  ShalomAgencyRepository._();

  static Future<ShalomAgencyCatalog>? _catalog;

  static Future<ShalomAgencyCatalog> load() {
    return _catalog ??= _loadFromAssets();
  }

  static Future<ShalomAgencyCatalog> _loadFromAssets() async {
    final source = await rootBundle.loadString(
      'assets/data/shalom_agencies.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('El directorio de Shalom no es válido.');
    }
    final catalog = ShalomAgencyCatalog.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (catalog.agencies.isEmpty) {
      throw const FormatException('El directorio de Shalom está vacío.');
    }
    return catalog;
  }
}
