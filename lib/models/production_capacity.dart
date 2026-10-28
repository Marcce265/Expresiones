import 'dart:math' as math;

/// Public, aggregate production availability.
///
/// It deliberately contains no customer, quote or order identifiers. Supabase
/// can therefore expose the public `availability` row safely through RLS.
class ProductionCapacitySnapshot {
  const ProductionCapacitySnapshot({
    required this.weeklyCapacityPoints,
    this.deliveryWeekdays = defaultDeliveryWeekdays,
    this.reservedPointsByDate = const {},
    this.overridesByDate = const {},
    this.horizonDays = 120,
    this.timezone = 'America/Lima',
    this.updatedAt,
  });

  /// Keys use [DateTime.weekday] (`1` Monday through `7` Sunday).
  final Map<int, int> weeklyCapacityPoints;

  /// Days customers may choose for each delivery method.
  ///
  /// Keys match `DeliveryMethod.name`; values use [DateTime.weekday].
  static const Map<String, Set<int>> defaultDeliveryWeekdays = {
    'pickup': {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    },
    'shalom': {DateTime.monday, DateTime.saturday},
  };

  final Map<String, Set<int>> deliveryWeekdays;

  /// Aggregated confirmed workload, keyed as `yyyy-MM-dd`.
  final Map<String, int> reservedPointsByDate;

  /// Closures and exceptional capacity, keyed as `yyyy-MM-dd`.
  final Map<String, ProductionDayOverride> overridesByDate;
  final int horizonDays;
  final String timezone;
  final DateTime? updatedAt;

  /// Conservative local fallback until the owner configures Supabase.
  ///
  /// One point should represent roughly 30 minutes of combined workshop time.
  /// These values must be calibrated from real work before publishing dates as
  /// confirmed promises.
  factory ProductionCapacitySnapshot.twoPersonFallback() {
    return const ProductionCapacitySnapshot(
      weeklyCapacityPoints: {
        DateTime.monday: 24,
        DateTime.tuesday: 24,
        DateTime.wednesday: 24,
        DateTime.thursday: 24,
        DateTime.friday: 24,
        DateTime.saturday: 12,
        DateTime.sunday: 0,
      },
    );
  }

  factory ProductionCapacitySnapshot.fromMap(Map<String, dynamic> map) {
    final weekly = <int, int>{};
    final rawWeekly = map['weeklyCapacityPoints'];
    if (rawWeekly is Map) {
      for (final entry in rawWeekly.entries) {
        final weekday = int.tryParse(entry.key.toString());
        final points = _nonNegativeInt(entry.value);
        if (weekday != null && weekday >= 1 && weekday <= 7) {
          weekly[weekday] = points;
        }
      }
    }

    final reserved = <String, int>{};
    final rawReserved = map['reservedPointsByDate'];
    if (rawReserved is Map) {
      for (final entry in rawReserved.entries) {
        final key = entry.key.toString();
        if (_isDateKey(key)) reserved[key] = _nonNegativeInt(entry.value);
      }
    }

    final overrides = <String, ProductionDayOverride>{};
    final rawOverrides = map['overridesByDate'];
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (_isDateKey(key) && value is Map) {
          overrides[key] = ProductionDayOverride.fromMap(
            value.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }

    return ProductionCapacitySnapshot(
      weeklyCapacityPoints: weekly.isEmpty
          ? ProductionCapacitySnapshot.twoPersonFallback().weeklyCapacityPoints
          : Map.unmodifiable(weekly),
      deliveryWeekdays: _deliveryWeekdays(map['deliveryWeekdays']),
      reservedPointsByDate: Map.unmodifiable(reserved),
      overridesByDate: Map.unmodifiable(overrides),
      horizonDays: math.max(1, _int(map['horizonDays'], fallback: 120)),
      timezone: _nonEmptyString(map['timezone']) ?? 'America/Lima',
      updatedAt: _dateTime(map['updatedAt']),
    );
  }

  int capacityFor(DateTime date) {
    final normalized = dateOnly(date);
    final override = overridesByDate[dateKey(normalized)];
    if (override?.isClosed ?? false) return 0;
    return math.max(
      0,
      override?.capacityPoints ?? weeklyCapacityPoints[normalized.weekday] ?? 0,
    );
  }

  int reservedFor(DateTime date) =>
      math.max(0, reservedPointsByDate[dateKey(date)] ?? 0);

  int availableFor(DateTime date) =>
      math.max(0, capacityFor(date) - reservedFor(date));

  Set<int> weekdaysForDelivery(String method) =>
      deliveryWeekdays[method] ?? defaultDeliveryWeekdays[method] ?? const {};

  bool isDeliveryDay(String method, DateTime date) =>
      weekdaysForDelivery(method).contains(date.weekday);

  Map<String, dynamic> toMap() => {
    'weeklyCapacityPoints': {
      for (final entry in weeklyCapacityPoints.entries)
        entry.key.toString(): entry.value,
    },
    'deliveryWeekdays': {
      for (final entry in deliveryWeekdays.entries)
        entry.key: (entry.value.toList()..sort()),
    },
    'reservedPointsByDate': reservedPointsByDate,
    'overridesByDate': {
      for (final entry in overridesByDate.entries)
        entry.key: entry.value.toMap(),
    },
    'horizonDays': horizonDays,
    'timezone': timezone,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

class ProductionDayOverride {
  const ProductionDayOverride({
    this.capacityPoints,
    this.isClosed = false,
    this.reason = '',
  });

  final int? capacityPoints;
  final bool isClosed;
  final String reason;

  factory ProductionDayOverride.fromMap(Map<String, dynamic> map) {
    return ProductionDayOverride(
      capacityPoints: map['capacityPoints'] == null
          ? null
          : _nonNegativeInt(map['capacityPoints']),
      isClosed: map['isClosed'] == true,
      reason: _nonEmptyString(map['reason']) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    if (capacityPoints != null) 'capacityPoints': capacityPoints,
    'isClosed': isClosed,
    if (reason.isNotEmpty) 'reason': reason,
  };
}

class ProductionDayAllocation {
  const ProductionDayAllocation({
    required this.date,
    required this.points,
    required this.capacityBeforeAllocation,
  });

  final DateTime date;
  final int points;
  final int capacityBeforeAllocation;
}

enum ProductionPlanStatus {
  available,
  noCapacity,
  outsideBookingWindow,
  invalidRequest,
}

class ProductionPlan {
  const ProductionPlan({
    required this.status,
    required this.requiredPoints,
    required this.scheduledPoints,
    required this.notBefore,
    required this.allocations,
    this.completionDate,
    this.requestedDate,
    this.message = '',
  });

  final ProductionPlanStatus status;
  final int requiredPoints;
  final int scheduledPoints;
  final DateTime notBefore;
  final DateTime? completionDate;
  final DateTime? requestedDate;
  final List<ProductionDayAllocation> allocations;
  final String message;

  bool get isAvailable => status == ProductionPlanStatus.available;
  int get unscheduledPoints => math.max(0, requiredPoints - scheduledPoints);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String dateKey(DateTime value) {
  final date = dateOnly(value);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

bool _isDateKey(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value) != null;

int _int(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _nonNegativeInt(Object? value) => math.max(0, _int(value, fallback: 0));

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

Map<String, Set<int>> _deliveryWeekdays(Object? value) {
  final map = value is Map ? value : const <Object?, Object?>{};
  return Map.unmodifiable({
    for (final method
        in ProductionCapacitySnapshot.defaultDeliveryWeekdays.keys)
      method: Set.unmodifiable(
        _weekdaySet(
          map[method],
          ProductionCapacitySnapshot.defaultDeliveryWeekdays[method]!,
        ),
      ),
  });
}

Set<int> _weekdaySet(Object? value, Set<int> fallback) {
  if (value is! Iterable) return fallback;
  final parsed = value
      .map((item) => _int(item, fallback: 0))
      .where(
        (weekday) => weekday >= DateTime.monday && weekday <= DateTime.sunday,
      )
      .toSet();
  return parsed.isEmpty ? fallback : parsed;
}
