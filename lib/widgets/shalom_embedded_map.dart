import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../data/shalom_agency_repository.dart';
import '../models/shalom_agency.dart';
import '../security/rate_limiter.dart';
import '../theme/app_theme.dart';

/// Mapa interactivo de agencias Shalom que permanece dentro de la aplicación.
///
/// Usa teselas públicas de OpenStreetMap y el directorio local de agencias. La
/// agencia elegida se resalta y el mapa vuelve a centrarla cuando cambia.
class ShalomEmbeddedMap extends StatefulWidget {
  const ShalomEmbeddedMap({
    super.key,
    this.selectedAgencyId = '',
    this.selectedAgencyName = '',
    this.selectedAgencyLocality = '',
    this.latitude,
    this.longitude,
    this.showOtherAgencies = true,
    this.height = 330,
  });

  final String selectedAgencyId;
  final String selectedAgencyName;
  final String selectedAgencyLocality;
  final double? latitude;
  final double? longitude;
  final bool showOtherAgencies;
  final double height;

  @override
  State<ShalomEmbeddedMap> createState() => _ShalomEmbeddedMapState();
}

class _ShalomEmbeddedMapState extends State<ShalomEmbeddedMap> {
  static const _peruCenter = LatLng(-9.189967, -75.015152);
  static const _shalomRed = Color(0xFFC8102E);

  final MapController _controller = MapController();
  List<ShalomAgency> _agencies = const [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadAgencies();
  }

  Future<void> _loadAgencies() async {
    final catalog = await ShalomAgencyRepository.load();
    if (!mounted) return;
    setState(() {
      _agencies = [
        for (final agency in catalog.agencies)
          if (agency.isPublic &&
              agency.canReceive &&
              agency.latitude != null &&
              agency.longitude != null)
            agency,
      ];
    });
  }

  bool get _hasSelectedCoordinates =>
      widget.latitude != null && widget.longitude != null;

  bool get _hasSelection =>
      widget.selectedAgencyId.trim().isNotEmpty ||
      widget.selectedAgencyName.trim().isNotEmpty ||
      _hasSelectedCoordinates;

  String get _selectedAgencyName => widget.selectedAgencyName.trim().isEmpty
      ? 'Agencia Shalom elegida'
      : widget.selectedAgencyName.trim();

  LatLng get _selectedPoint => _hasSelectedCoordinates
      ? LatLng(widget.latitude!, widget.longitude!)
      : _peruCenter;

  @override
  void didUpdateWidget(covariant ShalomEmbeddedMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.selectedAgencyId != widget.selectedAgencyId;
    if (changed && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelection());
    }
  }

  void _centerSelection() {
    if (!mounted || !_mapReady) return;
    _controller.move(_selectedPoint, _hasSelectedCoordinates ? 17.0 : 5.2);
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    if (!ClientRateLimiter.instance.tryAcquire(
      'shalom_map_zoom',
      maxAttempts: 6,
      window: const Duration(seconds: 2),
    )) {
      return;
    }
    final camera = _controller.camera;
    final zoom = (camera.zoom + delta).clamp(4.5, 18.0).toDouble();
    _controller.move(camera.center, zoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAttribution() async {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _hasSelectedCoordinates
          ? 'Mapa de la agencia $_selectedAgencyName'
          : 'Mapa de agencias Shalom en el Perú',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE6EEF0),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _selectedPoint,
                  initialZoom: _hasSelectedCoordinates ? 17.0 : 5.2,
                  minZoom: 4.5,
                  maxZoom: 18,
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: LatLngBounds(
                      const LatLng(-19.5, -82.5),
                      const LatLng(0.5, -67.5),
                    ),
                  ),
                  backgroundColor: const Color(0xFFE6EEF0),
                  interactionOptions: const InteractionOptions(
                    flags:
                        (InteractiveFlag.all &
                        ~InteractiveFlag.rotate &
                        ~InteractiveFlag.flingAnimation),
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    _centerSelection();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'pe.com.expresiones.catalogo',
                    maxNativeZoom: 18,
                  ),
                  _ShalomAgenciesLayer(
                    agencies: widget.showOtherAgencies ? _agencies : const [],
                    selectedAgencyId: widget.selectedAgencyId,
                    selectedAgencyName: _selectedAgencyName,
                    selectedPoint: _hasSelectedCoordinates ? _selectedPoint : null,
                  ),
                  SimpleAttributionWidget(
                    source: const Text(
                      'OpenStreetMap',
                      style: TextStyle(fontSize: 9),
                    ),
                    onTap: _openAttribution,
                    backgroundColor: Colors.white.withValues(alpha: .88),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 62,
                child: _MapSelectionLabel(
                  hasCoordinates: _hasSelectedCoordinates,
                  hasSelection: _hasSelection,
                  agencyName: _selectedAgencyName,
                  agencyLocality: widget.selectedAgencyLocality,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _ZoomControls(
                  onZoomIn: () => _changeZoom(1),
                  onZoomOut: () => _changeZoom(-1),
                ),
              ),
              const Positioned(
                left: 12,
                bottom: 12,
                child: _MapLegend(color: _shalomRed),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ShalomAgenciesLayer extends StatelessWidget {
  const _ShalomAgenciesLayer({
    required this.agencies,
    required this.selectedAgencyId,
    required this.selectedAgencyName,
    required this.selectedPoint,
  });

  static const _pinZoomThreshold = 10.5;
  static const _maxVisiblePins = 45;

  final List<ShalomAgency> agencies;
  final String selectedAgencyId;
  final String selectedAgencyName;
  final LatLng? selectedPoint;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final showDetailedPins = camera.zoom >= _pinZoomThreshold;

    final visibleOthers = <ShalomAgency>[];
    for (final agency in agencies) {
      if (agency.id == selectedAgencyId) continue;
      final lat = agency.latitude!;
      final lng = agency.longitude!;
      if (lat >= bounds.south - 0.05 &&
          lat <= bounds.north + 0.05 &&
          lng >= bounds.west - 0.05 &&
          lng <= bounds.east + 0.05) {
        visibleOthers.add(agency);
      }
    }

    final markers = <Marker>[];
    final circles = <CircleMarker>[];

    if (showDetailedPins && visibleOthers.length <= _maxVisiblePins) {
      for (final agency in visibleOthers) {
        markers.add(
          Marker(
            key: ValueKey(agency.id),
            point: LatLng(agency.latitude!, agency.longitude!),
            width: 26,
            height: 31,
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: agency.displayName,
              child: const _ShalomMarker(selected: false),
            ),
          ),
        );
      }
    } else {
      for (final agency in visibleOthers) {
        circles.add(
          CircleMarker(
            point: LatLng(agency.latitude!, agency.longitude!),
            radius: camera.zoom >= 8 ? 5.5 : 4.2,
            color: _ShalomEmbeddedMapState._shalomRed,
            borderColor: Colors.white,
            borderStrokeWidth: 1.2,
          ),
        );
      }
    }

    if (selectedPoint != null) {
      markers.add(
        Marker(
          key: ValueKey('selected-$selectedAgencyId'),
          point: selectedPoint!,
          width: 36,
          height: 42,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: selectedAgencyName,
            child: const _ShalomMarker(selected: true),
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (circles.isNotEmpty) CircleLayer(circles: circles),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

class _MapSelectionLabel extends StatelessWidget {
  const _MapSelectionLabel({
    required this.hasCoordinates,
    required this.hasSelection,
    required this.agencyName,
    required this.agencyLocality,
  });

  final bool hasCoordinates;
  final bool hasSelection;
  final String agencyName;
  final String agencyLocality;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 370),
        child: Material(
          color: Colors.white.withValues(alpha: .95),
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.pinkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasCoordinates
                        ? Icons.location_on_rounded
                        : Icons.travel_explore_rounded,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSelection
                            ? agencyName
                            : 'Agencias Shalom en el Perú',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        hasSelection && agencyLocality.isNotEmpty
                            ? agencyLocality
                            : hasSelection && !hasCoordinates
                            ? 'Esta agencia todavía no tiene coordenadas.'
                            : 'Elige una agencia para centrar el mapa.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .96),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IconButton(
            tooltip: 'Acercar mapa',
            onPressed: onZoomIn,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
          const SizedBox(
            width: 30,
            child: Divider(height: 1, color: AppColors.border),
          ),
          IconButton(
            tooltip: 'Alejar mapa',
            onPressed: onZoomOut,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .1), blurRadius: 10),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'Agencias Shalom',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShalomMarker extends StatelessWidget {
  const _ShalomMarker({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final width = selected ? 36.0 : 26.0;
    final height = selected ? 42.0 : 31.0;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ShalomPinPainter(selected: selected),
        child: Align(
          alignment: const Alignment(0, -0.26),
          child: Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: selected ? 16 : 11.5,
              height: 1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShalomPinPainter extends CustomPainter {
  const _ShalomPinPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final boxH = h * 0.74;
    final radius = w * 0.2;
    final pointerHalfW = w * 0.16;
    final cx = w / 2;

    final pinPath = Path()
      ..moveTo(radius, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, boxH - radius)
      ..quadraticBezierTo(w, boxH, w - radius, boxH)
      ..lineTo(cx + pointerHalfW, boxH)
      ..lineTo(cx, h)
      ..lineTo(cx - pointerHalfW, boxH)
      ..lineTo(radius, boxH)
      ..quadraticBezierTo(0, boxH, 0, boxH - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();

    if (selected) {
      canvas.drawShadow(pinPath, const Color(0x55000000), 4, true);
    }

    final fillPaint = Paint()
      ..color = _ShalomEmbeddedMapState._shalomRed
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, fillPaint);

    final borderPaint = Paint()
      ..color = selected ? Colors.white : const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.6 : 1.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(pinPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ShalomPinPainter oldDelegate) =>
      oldDelegate.selected != selected;
}
