import 'dart:math' as math;

class ShalomAgency {
  ShalomAgency({
    required this.id,
    required this.name,
    required this.locationName,
    required this.zone,
    required this.department,
    required this.province,
    required this.district,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.openingHours,
    required this.sundayHours,
    required this.isPublic,
    required this.isAgent,
    required this.isProPoint,
    required this.canReceive,
    required this.canSend,
  });

  final String id;
  final String name;
  final String locationName;
  final String zone;
  final String department;
  final String province;
  final String district;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String openingHours;
  final String sundayHours;
  final bool isPublic;
  final bool isAgent;
  final bool isProPoint;
  final bool canReceive;
  final bool canSend;

  String get displayName {
    if (locationName.trim().isNotEmpty) return locationName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return 'Agencia Shalom';
  }

  String get typeLabel => isProPoint
      ? 'Punto PRO'
      : isAgent
      ? 'Punto de envío'
      : 'Agencia';

  String get localityLabel =>
      _uniqueNonEmpty([district, province, department]).join(' · ');

  String get transitEstimateFromHuancayo => estimateTransitFromHuancayo(
    department: department,
    locality: localityLabel,
    latitude: latitude,
    longitude: longitude,
  );

  /// Estima los días de envío terrestre por Shalom desde Huancayo.
  static String estimateTransitFromHuancayo({
    String department = '',
    String locality = '',
    double? latitude,
    double? longitude,
    double originLatitude = -12.065,
    double originLongitude = -75.210,
  }) {
    final normalizedDept = _normalize(department);
    final normalizedLoc = _normalize(locality);
    final region = normalizedDept.isNotEmpty
        ? normalizedDept
        : normalizedLoc.split('·').last.trim();

    final hasValidCoords =
        latitude != null &&
        longitude != null &&
        latitude >= -20 &&
        latitude <= 0 &&
        longitude >= -82 &&
        longitude <= -68;
    final distanceKm = hasValidCoords
        ? _haversineKm(originLatitude, originLongitude, latitude, longitude)
        : null;

    if (region.contains('loreto') ||
        region.contains('madre de dios') ||
        region.contains('tumbes') ||
        (distanceKm != null && distanceKm >= 1000)) {
      return 'Llega en 3 a 4 días';
    }

    if (region.contains('junin') ||
        region.contains('huancavelica') ||
        region.contains('pasco') ||
        region.contains('ayacucho')) {
      return 'Llega en 1 a 2 días';
    }

    if (region == 'lima' ||
        region == 'callao' ||
        normalizedLoc.contains('lima') ||
        normalizedLoc.contains('callao')) {
      if (distanceKm != null && distanceKm > 360) {
        return 'Llega en 2 a 3 días';
      }
      return 'Llega en 1 a 2 días';
    }

    return 'Llega en 2 a 3 días';
  }

  late final String searchableText = _normalize(
    [
      displayName,
      name,
      locationName,
      zone,
      department,
      province,
      district,
      address,
      phone,
      typeLabel,
    ].join(' '),
  );

  bool matches(String query) =>
      _searchTerms(query).every(searchableText.contains);

  factory ShalomAgency.fromJson(Map<String, Object?> json) {
    return ShalomAgency(
      id: _string(json['id'] ?? json['ter_id']),
      name: _string(json['name'] ?? json['nombre']),
      locationName: _string(
        json['locationName'] ?? json['location_name'] ?? json['lugar'],
      ),
      zone: _string(json['zone'] ?? json['zona']),
      department: _string(json['department'] ?? json['departamento']),
      province: _string(json['province'] ?? json['provincia']),
      district: _string(json['district'] ?? json['distrito']),
      address: _string(json['address'] ?? json['direccion']),
      phone: _string(json['phone'] ?? json['telefono']),
      latitude: _double(json['latitude'] ?? json['latitud']),
      longitude: _double(json['longitude'] ?? json['longitud']),
      openingHours: _string(
        json['openingHours'] ?? json['opening_hours'] ?? json['hora_atencion'],
      ),
      sundayHours: _string(
        json['sundayHours'] ?? json['sunday_hours'] ?? json['hora_domingo'],
      ),
      isPublic: _bool(json['web'] ?? json['isPublic'] ?? json['is_public']),
      isAgent: _bool(json['isAgent'] ?? json['is_agent'] ?? json['agente']),
      isProPoint: _bool(
        json['isProPoint'] ?? json['is_pro_point'] ?? json['puntospro'],
      ),
      canReceive: _bool(
        json['canReceive'] ?? json['can_receive'] ?? json['destino'],
      ),
      canSend: _bool(json['canSend'] ?? json['can_send'] ?? json['origen']),
    );
  }
}

class ShalomAgencyCatalog {
  ShalomAgencyCatalog({
    required this.source,
    required this.updatedAt,
    required this.agencies,
  }) : publicAgencies = List.unmodifiable(
         (agencies.where((agency) => agency.isPublic).toList()..sort((a, b) {
           final byDepartment = a.department.compareTo(b.department);
           if (byDepartment != 0) return byDepartment;
           return a.displayName.compareTo(b.displayName);
         })),
       );

  final String source;
  final DateTime? updatedAt;
  final List<ShalomAgency> agencies;
  final List<ShalomAgency> publicAgencies;

  List<ShalomAgency> searchPublicAgencies(String query) {
    final terms = _searchTerms(query);
    if (terms.isEmpty) return publicAgencies;
    return publicAgencies
        .where((agency) => terms.every(agency.searchableText.contains))
        .toList(growable: false);
  }

  factory ShalomAgencyCatalog.fromJson(Map<String, Object?> json) {
    final rawAgencies = json['agencies'];
    final agencies = rawAgencies is List
        ? rawAgencies
              .whereType<Map>()
              .map(
                (item) => ShalomAgency.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((agency) => agency.id.isNotEmpty)
              .toList(growable: false)
        : const <ShalomAgency>[];

    return ShalomAgencyCatalog(
      source: _string(json['source']),
      updatedAt: DateTime.tryParse(
        _string(json['updatedAt'] ?? json['updated_at']),
      ),
      agencies: agencies,
    );
  }
}

List<String> _searchTerms(String query) {
  final clean = query.trim();
  final capped = clean.length > 60 ? clean.substring(0, 60) : clean;
  final normalized = _normalize(capped);
  return normalized.isEmpty
      ? const []
      : normalized.split(' ').take(8).toList(growable: false);
}

String _string(Object? value) => value?.toString().trim() ?? '';

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_string(value).replaceAll(',', '.'));
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'si',
    'sí',
    'yes',
  }.contains(_string(value).toLowerCase());
}

List<String> _uniqueNonEmpty(List<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final clean = value.trim();
    final key = clean.toLowerCase();
    if (clean.isNotEmpty && seen.add(key)) result.add(clean);
  }
  return result;
}

String _normalize(String value) {
  const accents = 'áéíóúüñÁÉÍÓÚÜÑ';
  const plain = 'aeiouunAEIOUUN';
  var result = value.toLowerCase();
  for (var index = 0; index < accents.length; index++) {
    result = result.replaceAll(accents[index], plain[index]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0088;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(math.min(1.0, a)));
}
