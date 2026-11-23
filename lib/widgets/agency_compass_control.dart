import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/device_location_service.dart';
import '../theme/app_theme.dart';

class AgencyCompassControl extends StatefulWidget {
  const AgencyCompassControl({super.key, required this.target});

  final LatLng target;

  @override
  State<AgencyCompassControl> createState() => _AgencyCompassControlState();
}

class _AgencyCompassControlState extends State<AgencyCompassControl> {
  StreamSubscription<CompassEvent>? _subscription;
  LatLng? _userLocation;
  double? _heading;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await const DeviceLocationService().currentPosition();
      final events = FlutterCompass.events;
      if (events == null) throw StateError('Brújula no disponible.');
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _heading = null;
      });
      await _subscription?.cancel();
      _subscription = events.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _heading = event.heading;
            _error = event.heading == null ? 'Sensor no disponible' : null;
          });
        },
        onError: (_) {
          if (mounted) setState(() => _error = 'No se pudo leer la brújula');
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;
    setState(() {
      _userLocation = null;
      _heading = null;
      _error = null;
    });
  }

  double get _bearing {
    final user = _userLocation!;
    final startLatitude = user.latitude * math.pi / 180;
    final endLatitude = widget.target.latitude * math.pi / 180;
    final longitudeDelta =
        (widget.target.longitude - user.longitude) * math.pi / 180;
    final y = math.sin(longitudeDelta) * math.cos(endLatitude);
    final x =
        math.cos(startLatitude) * math.sin(endLatitude) -
        math.sin(startLatitude) *
            math.cos(endLatitude) *
            math.cos(longitudeDelta);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double get _distanceKm {
    final user = _userLocation!;
    return Geolocator.distanceBetween(
          user.latitude,
          user.longitude,
          widget.target.latitude,
          widget.target.longitude,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    if (_userLocation == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _start,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              visualDensity: VisualDensity.compact,
            ),
            icon: _loading
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.navigation_rounded, size: 17),
            label: Text(_loading ? 'Buscando…' : 'Orientarme'),
          ),
        ],
      );
    }

    final relativeBearing = _heading == null
        ? null
        : (_bearing - _heading!) * math.pi / 180;
    final distanceLabel = _distanceKm < 1
        ? '${(_distanceKm * 1000).round()} m'
        : '${_distanceKm.toStringAsFixed(1)} km';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, top: 7, bottom: 7, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (relativeBearing == null)
              const Icon(Icons.explore_off_outlined, color: AppColors.muted)
            else
              Transform.rotate(
                angle: relativeBearing,
                child: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.pinkStrong,
                  size: 22,
                ),
              ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error == null ? 'Hacia la agencia' : 'Brújula',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  _error ?? distanceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            IconButton(
              tooltip: 'Detener orientación',
              onPressed: _stop,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}
