import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/storefront_settings.dart';
import '../theme/app_theme.dart';
import 'google_map_element.dart'
    if (dart.library.js_interop) 'google_map_element_web.dart';

/// In-app pickup map. It mirrors the Shalom map experience and does not send
/// the customer to another browser or application.
class PickupLocationMap extends StatefulWidget {
  const PickupLocationMap({
    super.key,
    required this.location,
    this.height = 320,
  });

  final PickupLocationSettings location;
  final double height;

  @override
  State<PickupLocationMap> createState() => _PickupLocationMapState();
}

class _PickupLocationMapState extends State<PickupLocationMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  LatLng get _point =>
      LatLng(widget.location.latitude!, widget.location.longitude!);

  @override
  void didUpdateWidget(covariant PickupLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.location.latitude != widget.location.latitude ||
            oldWidget.location.longitude != widget.location.longitude) &&
        widget.location.hasCoordinates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ready) _controller.move(_point, 16);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final query = Uri.encodeComponent(widget.location.address);
      final source = 'https://www.google.com/maps?q=$query&output=embed&z=17';
      return Semantics(
        label: 'Mapa de ${widget.location.name}. ${widget.location.address}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: HtmlElementView.fromTagName(
              key: ValueKey(source),
              tagName: 'iframe',
              onElementCreated: (element) =>
                  configureGoogleMapElement(element, source),
            ),
          ),
        ),
      );
    }

    if (!widget.location.hasCoordinates) {
      return Container(
        height: widget.height,
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.pinkSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 42),
            const SizedBox(height: 10),
            Text(
              'Ubicación de recojo pendiente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'El administrador todavía no ha configurado las coordenadas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Mapa de ${widget.location.name}. ${widget.location.address}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 16,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () => _ready = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'pe.com.expresiones.catalogo',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point,
                        width: 54,
                        height: 62,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 54,
                          color: AppColors.ink,
                          shadows: [
                            Shadow(
                              color: Color(0x55000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Material(
                        color: Colors.white.withValues(alpha: .9),
                        child: InkWell(
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            child: Text(
                              '© OpenStreetMap',
                              style: TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 62,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: Material(
                      elevation: 4,
                      color: Colors.white.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.pinkSoft,
                              child: Icon(Icons.storefront_outlined, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.location.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                  Text(
                                    widget.location.address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  elevation: 4,
                  color: Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      IconButton(
                        tooltip: 'Acercar mapa',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _changeZoom(1),
                        icon: const Icon(Icons.add_rounded, size: 20),
                      ),
                      const SizedBox(
                        width: 30,
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      IconButton(
                        tooltip: 'Alejar mapa',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _changeZoom(-1),
                        icon: const Icon(Icons.remove_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeZoom(double delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(3.0, 19.0).toDouble(),
    );
  }
}
