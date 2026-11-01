import 'package:expresiones/models/production_capacity.dart';
import 'package:expresiones/services/production_capacity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductionCapacityService', () {
    final monday = DateTime(2026, 10, 12, 10);

    test('distribuye una carga grande entre varios días', () {
      final snapshot = ProductionCapacitySnapshot(
        weeklyCapacityPoints: const {
          DateTime.monday: 8,
          DateTime.tuesday: 8,
          DateTime.wednesday: 8,
          DateTime.thursday: 8,
          DateTime.friday: 8,
          DateTime.saturday: 0,
          DateTime.sunday: 0,
        },
        reservedPointsByDate: const {'2026-10-12': 6},
      );

      final plan = ProductionCapacityService(snapshot)
          .earliestPlan(requiredPoints: 12, minimumLeadDays: 0, now: monday);

      expect(plan.isAvailable, isTrue);
      expect(plan.completionDate, DateTime(2026, 10, 14));
      expect(plan.allocations.map((item) => item.points), [2, 8, 2]);
    });

    test('respeta cierres y capacidad excepcional', () {
      final snapshot = ProductionCapacitySnapshot(
        weeklyCapacityPoints: const {
          DateTime.monday: 8,
          DateTime.tuesday: 8,
          DateTime.wednesday: 8,
          DateTime.thursday: 8,
          DateTime.friday: 8,
          DateTime.saturday: 0,
          DateTime.sunday: 0,
        },
        overridesByDate: const {
          '2026-10-12': ProductionDayOverride(
            isClosed: true,
            reason: 'Inventario',
          ),
          '2026-10-13': ProductionDayOverride(capacityPoints: 3),
        },
      );

      final plan = ProductionCapacityService(snapshot)
          .earliestPlan(requiredPoints: 4, minimumLeadDays: 0, now: monday);

      expect(plan.completionDate, DateTime(2026, 10, 14));
      expect(plan.allocations.map((item) => item.points), [3, 1]);
    });

    test('rechaza una fecha sin puntos suficientes', () {
      final snapshot = ProductionCapacitySnapshot(
        weeklyCapacityPoints: const {
          DateTime.monday: 4,
          DateTime.tuesday: 4,
          DateTime.wednesday: 4,
          DateTime.thursday: 4,
          DateTime.friday: 4,
          DateTime.saturday: 0,
          DateTime.sunday: 0,
        },
      );

      final plan = ProductionCapacityService(snapshot).planByDate(
        requiredPoints: 10,
        minimumLeadDays: 0,
        now: monday,
        desiredDate: DateTime(2026, 10, 13),
      );

      expect(plan.status, ProductionPlanStatus.noCapacity);
      expect(plan.scheduledPoints, 8);
      expect(plan.unscheduledPoints, 2);
    });

    test('aplica tiempo mínimo antes de reservar capacidad', () {
      final snapshot = ProductionCapacitySnapshot(
        weeklyCapacityPoints: const {
          DateTime.monday: 8,
          DateTime.tuesday: 8,
          DateTime.wednesday: 8,
          DateTime.thursday: 8,
          DateTime.friday: 8,
          DateTime.saturday: 0,
          DateTime.sunday: 0,
        },
      );

      final plan = ProductionCapacityService(snapshot)
          .earliestPlan(requiredPoints: 2, minimumLeadDays: 2, now: monday);

      expect(plan.notBefore, DateTime(2026, 10, 14));
      expect(plan.completionDate, DateTime(2026, 10, 14));
    });

    test('conserva los días configurados para cada tipo de entrega', () {
      final snapshot = ProductionCapacitySnapshot.fromMap({
        'weeklyCapacityPoints': {'1': 8},
        'deliveryWeekdays': {
          'pickup': [2, 3, 4],
          'shalom': [DateTime.monday, DateTime.saturday],
        },
        'pickupTimeSlots': ['08:00 - 09:00', '15:00 - 16:00'],
      });
      final restored = ProductionCapacitySnapshot.fromMap(snapshot.toMap());

      expect(restored.weekdaysForDelivery('pickup'), {2, 3, 4});
      expect(restored.weekdaysForDelivery('shalom'), {
        DateTime.monday,
        DateTime.saturday,
      });
      expect(restored.isDeliveryDay('shalom', DateTime(2026, 10, 24)), isTrue);
      expect(restored.isDeliveryDay('shalom', DateTime(2026, 10, 23)), isFalse);
      expect(restored.pickupTimeSlots, ['08:00 - 09:00', '15:00 - 16:00']);
    });

    test('usa horarios de recojo seguros cuando faltan o son inválidos', () {
      final missing = ProductionCapacitySnapshot.fromMap({
        'weeklyCapacityPoints': {'1': 8},
      });
      final invalid = ProductionCapacitySnapshot.fromMap({
        'weeklyCapacityPoints': {'1': 8},
        'pickupTimeSlots': ['18:00 - 17:00'],
      });

      expect(
        missing.pickupTimeSlots,
        ProductionCapacitySnapshot.defaultPickupTimeSlots,
      );
      expect(
        invalid.pickupTimeSlots,
        ProductionCapacitySnapshot.defaultPickupTimeSlots,
      );
    });
  });
}
