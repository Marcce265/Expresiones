import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/commerce_telemetry.dart';
import '../models/production_capacity.dart';

class AdminOperationsRepository {
  AdminOperationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _availability =>
      _firestore.collection('availability').doc('public');

  Stream<ProductionCapacitySnapshot> watchCapacity() {
    return _availability.snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? ProductionCapacitySnapshot.twoPersonFallback()
          : ProductionCapacitySnapshot.fromMap(data);
    });
  }

  Future<void> saveCapacity(ProductionCapacitySnapshot snapshot) {
    final data = snapshot.toMap()..remove('updatedAt');
    return _availability.set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reads at most [limit] anonymous events from the selected recent window.
  /// This keeps both Firestore reads and admin rendering bounded.
  Stream<AdminAnalyticsSummary> watchAnalytics({
    Duration window = const Duration(days: 30),
    int limit = 1000,
  }) {
    final safeLimit = math.max(1, math.min(limit, 2000));
    final from = Timestamp.fromDate(DateTime.now().subtract(window));
    return _firestore
        .collection('analytics_events')
        .where('occurredAt', isGreaterThanOrEqualTo: from)
        .orderBy('occurredAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => AdminAnalyticsSummary.fromDocuments(
            snapshot.docs.map((document) => document.data()),
            requestedWindow: window,
            sampleLimit: safeLimit,
          ),
        );
  }
}

class AdminAnalyticsSummary {
  const AdminAnalyticsSummary({
    required this.totalEvents,
    required this.counts,
    required this.topMissingSearches,
    required this.topViewedProducts,
    required this.topAddedProducts,
    required this.requestedWindow,
    required this.sampleLimit,
  });

  final int totalEvents;
  final Map<CommerceEventType, int> counts;
  final List<AnalyticsRank> topMissingSearches;
  final List<AnalyticsRank> topViewedProducts;
  final List<AnalyticsRank> topAddedProducts;
  final Duration requestedWindow;
  final int sampleLimit;

  int count(CommerceEventType type) => counts[type] ?? 0;

  double get quoteCompletionRate {
    final sent = count(CommerceEventType.quoteSent);
    final abandoned = count(CommerceEventType.quoteAbandoned);
    final total = sent + abandoned;
    return total == 0 ? 0 : sent / total;
  }

  factory AdminAnalyticsSummary.fromDocuments(
    Iterable<Map<String, dynamic>> documents, {
    required Duration requestedWindow,
    required int sampleLimit,
  }) {
    final counts = <CommerceEventType, int>{};
    final searches = <String, int>{};
    final views = <String, int>{};
    final added = <String, int>{};
    var total = 0;

    for (final data in documents) {
      final type = CommerceEventType.fromKey(data['eventType']);
      if (type == null) continue;
      total += 1;
      counts[type] = (counts[type] ?? 0) + 1;
      switch (type) {
        case CommerceEventType.zeroResultSearch:
          _increment(searches, data['searchTerm']);
        case CommerceEventType.productView:
          _increment(views, data['productId']);
        case CommerceEventType.productAdded:
          _increment(added, data['productId']);
        case CommerceEventType.quoteAbandoned:
        case CommerceEventType.quoteSent:
          break;
      }
    }

    return AdminAnalyticsSummary(
      totalEvents: total,
      counts: Map.unmodifiable(counts),
      topMissingSearches: _rank(searches),
      topViewedProducts: _rank(views),
      topAddedProducts: _rank(added),
      requestedWindow: requestedWindow,
      sampleLimit: sampleLimit,
    );
  }

  static void _increment(Map<String, int> values, Object? rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) return;
    values[value] = (values[value] ?? 0) + 1;
  }

  static List<AnalyticsRank> _rank(Map<String, int> values) {
    final rows =
        values.entries
            .map((entry) => AnalyticsRank(entry.key, entry.value))
            .toList()
          ..sort((a, b) {
            final count = b.count.compareTo(a.count);
            return count != 0 ? count : a.label.compareTo(b.label);
          });
    return List.unmodifiable(rows.take(10));
  }
}

class AnalyticsRank {
  const AnalyticsRank(this.label, this.count);

  final String label;
  final int count;
}
