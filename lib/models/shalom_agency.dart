class ShalomAgency {
  const ShalomAgency({
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

  String get searchableText => _normalize(
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

  bool matches(String query) {
    final normalized = _normalize(query.trim());
    return normalized.isEmpty ||
        normalized.split(' ').every(searchableText.contains);
  }

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
  const ShalomAgencyCatalog({
    required this.source,
    required this.updatedAt,
    required this.agencies,
  });

  final String source;
  final DateTime? updatedAt;
  final List<ShalomAgency> agencies;

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
