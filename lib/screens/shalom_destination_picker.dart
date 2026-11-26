import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/shalom_agency_repository.dart';
import '../models/shalom_agency.dart';
import '../services/device_location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shalom_embedded_map.dart';

class ShalomDestinationPicker extends StatefulWidget {
  const ShalomDestinationPicker({
    super.key,
    required this.selectedId,
    required this.showError,
    required this.onSelected,
    this.loadCatalog = ShalomAgencyRepository.load,
    this.locationService = const DeviceLocationService(),
  });

  final String selectedId;
  final bool showError;
  final ValueChanged<ShalomAgency?> onSelected;
  final Future<ShalomAgencyCatalog> Function() loadCatalog;
  final DeviceLocationService locationService;

  @override
  State<ShalomDestinationPicker> createState() =>
      _ShalomDestinationPickerState();
}

class _ShalomDestinationPickerState extends State<ShalomDestinationPicker> {
  static const _visibleAgencyCount = 3;
  final _agencyScroll = ScrollController(keepScrollOffset: false);
  late var _destinations = _loadDestinations();
  (String?, String?, String?)? _area;
  Map<ShalomAgency, double> _nearby = const {};
  Object? _locationRequest;
  String? _locationError;

  @override
  void dispose() {
    _agencyScroll.dispose();
    super.dispose();
  }

  Future<List<ShalomAgency>> _loadDestinations() async {
    final catalog = await widget.loadCatalog();
    final destinations = catalog.publicAgencies
        .where(
          (agency) =>
              agency.canReceive &&
              agency.department.isNotEmpty &&
              agency.province.isNotEmpty &&
              agency.district.isNotEmpty,
        )
        .toList(growable: false);
    if (mounted &&
        widget.selectedId.isNotEmpty &&
        !destinations.any((agency) => agency.id == widget.selectedId)) {
      widget.onSelected(null);
    }
    return destinations;
  }

  void _changeArea(String? department, String? province, String? district) {
    if (_agencyScroll.hasClients) _agencyScroll.jumpTo(0);
    setState(() {
      _area = (department, province, district);
      _nearby = const {};
      _locationRequest = null;
      _locationError = null;
    });
    if (widget.selectedId.isNotEmpty) widget.onSelected(null);
  }

  void _selectAgency(ShalomAgency agency) {
    if (_nearby.isNotEmpty || _locationRequest != null) {
      setState(() {
        _area = (agency.department, agency.province, agency.district);
        _locationRequest = null;
        _locationError = null;
      });
    }
    widget.onSelected(agency);
  }

  Future<void> _findNearby(List<ShalomAgency> destinations) async {
    final request = Object();
    setState(() {
      _locationRequest = request;
      _locationError = null;
    });
    try {
      final position = await widget.locationService.currentPosition();
      if (!mounted || _locationRequest != request) return;
      final ranked = <(ShalomAgency, double)>[
        for (final agency in destinations)
          if (agency.latitude != null && agency.longitude != null)
            (
              agency,
              Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    agency.latitude!,
                    agency.longitude!,
                  ) /
                  1000,
            ),
      ]..sort((first, second) => first.$2.compareTo(second.$2));
      if (ranked.isEmpty) {
        setState(
          () => _locationError =
              'No encontramos agencias con ubicación disponible.',
        );
        return;
      }
      final nearest = ranked.first.$1;
      if (_agencyScroll.hasClients) _agencyScroll.jumpTo(0);
      setState(() {
        _nearby = {
          for (final (agency, distance) in ranked.take(_visibleAgencyCount))
            agency: distance,
        };
        _area = (nearest.department, nearest.province, nearest.district);
      });
      if (widget.selectedId.isNotEmpty) widget.onSelected(null);
    } on LocationPermissionException catch (error) {
      if (mounted && _locationRequest == request) {
        setState(() => _locationError = error.message);
      }
    } catch (_) {
      if (mounted && _locationRequest == request) {
        setState(
          () => _locationError =
              'No pudimos obtener tu ubicación. Puedes elegir el distrito.',
        );
      }
    } finally {
      if (mounted && _locationRequest == request) {
        setState(() => _locationRequest = null);
      }
    }
  }

  List<String> _sortedOptions(Iterable<String> names) =>
      names.toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agencia de destino', style: text.titleSmall),
          const SizedBox(height: 12),
          FutureBuilder<List<ShalomAgency>>(
            future: _destinations,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No pudimos cargar las agencias Shalom.'),
                    TextButton(
                      onPressed: () =>
                          setState(() => _destinations = _loadDestinations()),
                      child: const Text('Volver a intentar'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(
                  semanticsLabel: 'Cargando agencias Shalom',
                );
              }

              final destinations = snapshot.requireData;
              final selected = widget.selectedId.isEmpty
                  ? null
                  : destinations
                        .where((agency) => agency.id == widget.selectedId)
                        .firstOrNull;
              final (department, province, district) =
                  _area ??
                  (
                    selected?.department,
                    selected?.province,
                    selected?.district,
                  );
              final inDepartment = destinations.where(
                (agency) => agency.department == department,
              );
              final inProvince = inDepartment.where(
                (agency) => agency.province == province,
              );
              final matches =
                  (_nearby.isEmpty
                          ? inProvince.where(
                              (agency) => agency.district == district,
                            )
                          : _nearby.keys)
                      .toList(growable: false);
              final fields = [
                _LocationField(
                  label: 'Departamento',
                  selected: department,
                  options: _sortedOptions(
                    destinations.map((agency) => agency.department),
                  ),
                  onChanged: (value) => _changeArea(value, null, null),
                ),
                _LocationField(
                  label: 'Provincia',
                  selected: province,
                  options: _sortedOptions(
                    inDepartment.map((agency) => agency.province),
                  ),
                  onChanged: (value) => _changeArea(department, value, null),
                ),
                _LocationField(
                  label: 'Distrito',
                  selected: district,
                  options: _sortedOptions(
                    inProvince.map((agency) => agency.district),
                  ),
                  onChanged: (value) =>
                      _changeArea(department, province, value),
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final beside = width >= 700;
                      final fieldWidth = beside
                          ? (width - 176 - 24) / 3
                          : width >= 450
                          ? (width - 16) / 3
                          : width;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final field in fields)
                            SizedBox(width: fieldWidth, child: field),
                          SizedBox(
                            width: 176,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: _locationRequest == null
                                  ? () => _findNearby(destinations)
                                  : null,
                              icon: _locationRequest == null
                                  ? const Icon(
                                      Icons.my_location_outlined,
                                      size: 18,
                                    )
                                  : const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                              label: const Text('Agencia cercana'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_locationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _locationError!,
                        style: text.bodySmall?.copyWith(color: AppColors.error),
                      ),
                    ),
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _agencyResults(context, matches, selected),
                  ],
                  if (widget.showError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona una agencia para continuar.',
                      style: text.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _agencyResults(
    BuildContext context,
    List<ShalomAgency> matches,
    ShalomAgency? selected,
  ) {
    final text = Theme.of(context).textTheme;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _nearby.isEmpty
              ? 'Agencias Shalom en el distrito'
              : 'Agencias Shalom más cercanas',
          style: text.labelLarge,
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: widget.selectedId,
          onChanged: (id) {
            final agency = matches
                .where((agency) => agency.id == id)
                .firstOrNull;
            if (agency != null) _selectAgency(agency);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasMore = matches.length > _visibleAgencyCount;
              if (!hasMore) {
                return Column(
                  children: [
                    for (final agency in matches)
                      _DestinationOption(
                        agency: agency,
                        selected: agency.id == widget.selectedId,
                        onSelected: () => _selectAgency(agency),
                        distanceKm: _nearby[agency],
                      ),
                  ],
                );
              }
              final narrow = constraints.maxWidth < 420;
              final titleLines = narrow ? 2 : 1;
              final addressLines = narrow ? 3 : 2;
              final scale = MediaQuery.textScalerOf(context);
              final titleHeight =
                  scale.scale(text.labelLarge?.fontSize ?? 14) *
                  (text.labelLarge?.height ?? 1.25);
              final bodyHeight =
                  scale.scale(text.bodySmall?.fontSize ?? 12) *
                  (text.bodySmall?.height ?? 1.45);
              final rowHeight =
                  16 +
                  titleHeight * titleLines +
                  bodyHeight * (addressLines + 1);
              return SizedBox(
                height: rowHeight * _visibleAgencyCount,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: RawScrollbar(
                    controller: _agencyScroll,
                    thumbVisibility: true,
                    thumbColor: AppColors.muted.withValues(alpha: 0.55),
                    thickness: 5,
                    crossAxisMargin: 2,
                    mainAxisMargin: 3,
                    radius: const Radius.circular(4),
                    child: ListView.builder(
                      key: const ValueKey('agency-results'),
                      controller: _agencyScroll,
                      primary: false,
                      padding: const EdgeInsets.only(right: 18),
                      itemCount: matches.length,
                      itemExtent: rowHeight,
                      itemBuilder: (context, index) {
                        final agency = matches[index];
                        return _DestinationOption(
                          agency: agency,
                          selected: agency.id == widget.selectedId,
                          onSelected: () => _selectAgency(agency),
                          titleLines: titleLines,
                          addressLines: addressLines,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
    if (selected == null ||
        selected.latitude == null ||
        selected.longitude == null) {
      return list;
    }
    final map = ShalomEmbeddedMap(
      selectedAgencyId: selected.id,
      selectedAgencyName: selected.displayName,
      selectedAgencyLocality: selected.localityLabel,
      latitude: selected.latitude,
      longitude: selected.longitude,
      showOtherAgencies: false,
      height: 250,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [list, const SizedBox(height: 12), map],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: list),
            const SizedBox(width: 14),
            Expanded(flex: 5, child: map),
          ],
        );
      },
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        enabled: options.isNotEmpty,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
      ),
      child: DropdownButtonHideUnderline(
        child: Semantics(
          label: label,
          child: DropdownButton<String>(
            key: ValueKey(label),
            value: selected,
            isExpanded: true,
            isDense: true,
            menuMaxHeight: 320,
            hint: const Text(
              'Elige una opción',
              overflow: TextOverflow.ellipsis,
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: options.isEmpty ? null : onChanged,
          ),
        ),
      ),
    );
  }
}

class _DestinationOption extends StatelessWidget {
  const _DestinationOption({
    required this.agency,
    required this.selected,
    required this.onSelected,
    this.titleLines,
    this.addressLines,
    this.distanceKm,
  });

  final ShalomAgency agency;
  final bool selected;
  final VoidCallback onSelected;
  final int? titleLines;
  final int? addressLines;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        color: selected ? AppColors.pinkSoft : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.rose : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: MergeSemantics(
          child: InkWell(
            onTap: onSelected,
            excludeFromSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: agency.id,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: agency.displayName,
                          excludeFromSemantics: true,
                          child: Text(
                            agency.displayName,
                            maxLines: titleLines,
                            overflow: titleLines == null
                                ? null
                                : TextOverflow.ellipsis,
                            style: text.labelLarge,
                          ),
                        ),
                        if (agency.address.isNotEmpty)
                          Tooltip(
                            message: agency.address,
                            excludeFromSemantics: true,
                            child: Text(
                              agency.address,
                              maxLines: addressLines,
                              overflow: addressLines == null
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                        Text(
                          distanceKm == null
                              ? agency.transitEstimateFromHuancayo
                              : '${distanceKm!.toStringAsFixed(1)} km · ${agency.localityLabel}',
                          style: text.bodySmall,
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
    );
  }
}
