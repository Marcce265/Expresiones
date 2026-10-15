import 'dart:math' as math;

import '../models/production_capacity.dart';

/// Allocates workshop load against real daily capacity and confirmed workload.
class ProductionCapacityService {
  const ProductionCapacityService(this.snapshot);

  final ProductionCapacitySnapshot snapshot;

  /// Finds the earliest completion date after the product's preparation delay.
  ProductionPlan earliestPlan({
    required int requiredPoints,
    required int minimumLeadDays,
    required DateTime now,
  }) {
    return _buildPlan(
      requiredPoints: requiredPoints,
      minimumLeadDays: minimumLeadDays,
      now: now,
    );
  }

  /// Verifies whether the workshop can complete this workload by [desiredDate].
  ProductionPlan planByDate({
    required int requiredPoints,
    required int minimumLeadDays,
    required DateTime now,
    required DateTime desiredDate,
  }) {
    return _buildPlan(
      requiredPoints: requiredPoints,
      minimumLeadDays: minimumLeadDays,
      now: now,
      desiredDate: desiredDate,
    );
  }

  ProductionPlan _buildPlan({
    required int requiredPoints,
    required int minimumLeadDays,
    required DateTime now,
    DateTime? desiredDate,
  }) {
    final points = math.max(0, requiredPoints);
    final leadDays = math.max(0, minimumLeadDays);
    final today = dateOnly(now);
    final notBefore = today.add(Duration(days: leadDays));
    final requested = desiredDate == null ? null : dateOnly(desiredDate);

    if (requested != null && requested.isBefore(notBefore)) {
      return ProductionPlan(
        status: ProductionPlanStatus.invalidRequest,
        requiredPoints: points,
        scheduledPoints: 0,
        notBefore: notBefore,
        requestedDate: requested,
        allocations: const [],
        message: 'La fecha está antes del tiempo mínimo de preparación.',
      );
    }

    final horizonEnd = today.add(Duration(days: snapshot.horizonDays));
    if (requested != null && requested.isAfter(horizonEnd)) {
      return ProductionPlan(
        status: ProductionPlanStatus.outsideBookingWindow,
        requiredPoints: points,
        scheduledPoints: 0,
        notBefore: notBefore,
        requestedDate: requested,
        allocations: const [],
        message: 'La fecha está fuera de la ventana de reservas.',
      );
    }

    final end = requested ?? horizonEnd;
    if (points == 0) {
      final openDate = _firstOpenDate(notBefore, end);
      return ProductionPlan(
        status: openDate == null
            ? ProductionPlanStatus.noCapacity
            : ProductionPlanStatus.available,
        requiredPoints: 0,
        scheduledPoints: 0,
        notBefore: notBefore,
        completionDate: openDate,
        requestedDate: requested,
        allocations: const [],
        message: openDate == null
            ? 'No hay un día de atención disponible en ese rango.'
            : '',
      );
    }

    var remaining = points;
    final allocations = <ProductionDayAllocation>[];
    for (
      var date = notBefore;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final available = snapshot.availableFor(date);
      if (available <= 0) continue;
      final assigned = math.min(available, remaining);
      allocations.add(
        ProductionDayAllocation(
          date: date,
          points: assigned,
          capacityBeforeAllocation: available,
        ),
      );
      remaining -= assigned;
      if (remaining == 0) {
        return ProductionPlan(
          status: ProductionPlanStatus.available,
          requiredPoints: points,
          scheduledPoints: points,
          notBefore: notBefore,
          completionDate: date,
          requestedDate: requested,
          allocations: List.unmodifiable(allocations),
        );
      }
    }

    return ProductionPlan(
      status: ProductionPlanStatus.noCapacity,
      requiredPoints: points,
      scheduledPoints: points - remaining,
      notBefore: notBefore,
      requestedDate: requested,
      allocations: List.unmodifiable(allocations),
      message: requested == null
          ? 'No hay capacidad suficiente dentro de la ventana publicada.'
          : 'La carga disponible no alcanza para terminar en la fecha elegida.',
    );
  }

  DateTime? _firstOpenDate(DateTime start, DateTime end) {
    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      if (snapshot.capacityFor(date) > 0) return date;
    }
    return null;
  }
}
