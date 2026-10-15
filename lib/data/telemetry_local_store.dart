import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/commerce_telemetry.dart';

abstract interface class TelemetryLocalStore {
  Future<List<CommerceTelemetryEvent>> loadPendingEvents();
  Future<void> savePendingEvents(List<CommerceTelemetryEvent> events);
  Future<AnonymousQuoteActivity?> loadQuoteActivity();
  Future<void> saveQuoteActivity(AnonymousQuoteActivity? activity);
}

class SharedPreferencesTelemetryStore implements TelemetryLocalStore {
  const SharedPreferencesTelemetryStore();

  static const _eventsKey = 'expresiones.telemetry.events.v1';
  static const _quoteKey = 'expresiones.telemetry.quote.v1';

  @override
  Future<List<CommerceTelemetryEvent>> loadPendingEvents() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_eventsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => CommerceTelemetryEvent.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> savePendingEvents(List<CommerceTelemetryEvent> events) async {
    final preferences = await SharedPreferences.getInstance();
    if (events.isEmpty) {
      await preferences.remove(_eventsKey);
      return;
    }
    await preferences.setString(
      _eventsKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }

  @override
  Future<AnonymousQuoteActivity?> loadQuoteActivity() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_quoteKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AnonymousQuoteActivity.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveQuoteActivity(AnonymousQuoteActivity? activity) async {
    final preferences = await SharedPreferences.getInstance();
    if (activity == null) {
      await preferences.remove(_quoteKey);
      return;
    }
    await preferences.setString(_quoteKey, jsonEncode(activity.toJson()));
  }
}

/// Lightweight test double that is also useful for demos without persistence.
class MemoryTelemetryStore implements TelemetryLocalStore {
  List<CommerceTelemetryEvent> pendingEvents = [];
  AnonymousQuoteActivity? quoteActivity;

  @override
  Future<List<CommerceTelemetryEvent>> loadPendingEvents() async =>
      List.of(pendingEvents);

  @override
  Future<void> savePendingEvents(List<CommerceTelemetryEvent> events) async {
    pendingEvents = List.of(events);
  }

  @override
  Future<AnonymousQuoteActivity?> loadQuoteActivity() async => quoteActivity;

  @override
  Future<void> saveQuoteActivity(AnonymousQuoteActivity? activity) async {
    quoteActivity = activity;
  }
}
