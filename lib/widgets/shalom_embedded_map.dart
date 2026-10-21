import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/shalom_agency_repository.dart';
import '../models/shalom_agency.dart';
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
  late final Future<ShalomAgencyCatalog> _catalog =
      ShalomAgencyRepository.load();
  bool _mapReady = false;

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
    _controller.move(_selectedPoint, _hasSelectedCoordinates ? 15 : 5);
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    final camera = _controller.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 18.0).toDouble();
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
                  initialZoom: _hasSelectedCoordinates ? 15 : 5,
                  minZoom: 3,
                  maxZoom: 18,
                  backgroundColor: const Color(0xFFE6EEF0),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                    maxNativeZoom: 19,
                  ),
                  FutureBuilder<ShalomAgencyCatalog>(
                    future: _catalog,
                    builder: (context, snapshot) => MarkerLayer(
                      markers: _markers(snapshot.data?.agencies ?? const []),
                    ),
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

  List<Marker> _markers(List<ShalomAgency> agencies) {
    final result = <Marker>[
      for (final agency
          in widget.showOtherAgencies ? agencies : const <ShalomAgency>[])
        if (agency.isPublic &&
            agency.canReceive &&
            agency.latitude != null &&
            agency.longitude != null &&
            agency.id != widget.selectedAgencyId)
          Marker(
            key: ValueKey(agency.id),
            point: LatLng(agency.latitude!, agency.longitude!),
            width: 30,
            height: 38,
            alignment: Alignment.bottomCenter,
            child: Tooltip(
              message: agency.displayName,
              child: const _ShalomMarker(selected: false),
            ),
          ),
    ];

    if (_hasSelectedCoordinates) {
      result.add(
        Marker(
          key: ValueKey('selected-${widget.selectedAgencyId}'),
          point: _selectedPoint,
          width: 48,
          height: 58,
          alignment: Alignment.bottomCenter,
          child: Tooltip(
            message: _selectedAgencyName,
            child: const _ShalomMarker(selected: true),
          ),
        ),
      );
    }
    return result;
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
    final size = selected ? 48.0 : 30.0;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: size,
          color: _ShalomEmbeddedMapState._shalomRed,
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        Positioned(
          top: selected ? 8 : 5,
          child: Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: selected ? 14 : 9,
              height: 1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
