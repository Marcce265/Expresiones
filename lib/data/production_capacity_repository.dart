import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/production_capacity.dart';

abstract interface class CapacityRepository {
  Future<ProductionCapacitySnapshot> load();
  Stream<ProductionCapacitySnapshot> watch();
}

/// Reads the single aggregate `availability/public` document.
///
/// There are no customer records in that document. When Firestore is not
/// configured or temporarily fails, the app continues with [fallback].
class FirestoreCapacityRepository implements CapacityRepository {
  FirestoreCapacityRepository({
    FirebaseFirestore? firestore,
    ProductionCapacitySnapshot? fallback,
  }) : _injectedFirestore = firestore,
       fallback = fallback ?? ProductionCapacitySnapshot.twoPersonFallback();

  final FirebaseFirestore? _injectedFirestore;
  final ProductionCapacitySnapshot fallback;

  @override
  Future<ProductionCapacitySnapshot> load() async {
    final firestore = _resolveFirestore();
    if (firestore == null) return fallback;
    try {
      final snapshot = await firestore
          .collection('availability')
          .doc('public')
          .get();
      final data = snapshot.data();
      return data == null ? fallback : ProductionCapacitySnapshot.fromMap(data);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Stream<ProductionCapacitySnapshot> watch() async* {
    final firestore = _resolveFirestore();
    if (firestore == null) {
      yield fallback;
      return;
    }
    yield* firestore
        .collection('availability')
        .doc('public')
        .snapshots()
        .transform(
          StreamTransformer.fromHandlers(
            handleData: (document, sink) {
              final data = document.data();
              sink.add(
                data == null
                    ? fallback
                    : ProductionCapacitySnapshot.fromMap(data),
              );
            },
            handleError: (_, _, sink) => sink.add(fallback),
          ),
        );
  }

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (Firebase.apps.isEmpty) return null;
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app());
    } catch (_) {
      return null;
    }
  }
}
