import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/commerce_telemetry.dart';
import '../services/commerce_telemetry_service.dart';

/// Optional remote sink. Do not construct it until Firebase is configured and
/// telemetry collection has been enabled for the release.
class FirestoreCommerceTelemetrySink implements CommerceTelemetrySink {
  FirestoreCommerceTelemetrySink(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<void> send(List<CommerceTelemetryEvent> events) async {
    if (events.isEmpty) return;
    final batch = firestore.batch();
    final collection = firestore.collection('analytics_events');
    for (final event in events) {
      batch.set(collection.doc(), {
        ...event.toRemoteMap(),
        'occurredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
