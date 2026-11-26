import 'package:flutter/material.dart';

import '../data/shalom_agency_repository.dart';
import '../models/shalom_agency.dart';
import '../theme/app_theme.dart';
import '../widgets/shalom_embedded_map.dart';

/// Selector visual y guiado de agencia Shalom, diseñado para que cualquier
/// compradora entienda dónde elegir en 2 segundos tanto en celular como en web.
class ShalomDestinationPicker extends StatefulWidget {
  const ShalomDestinationPicker({
    super.key,
    required this.selectedId,
    required this.showError,
    required this.onSelected,
    this.loadCatalog = ShalomAgencyRepository.load,
  });

  final String selectedId;
  final bool showError;
  final ValueChanged<ShalomAgency?> onSelected;
  final Future<ShalomAgencyCatalog> Function() loadCatalog;

  @override
  State<ShalomDestinationPicker> createState() =>
      _ShalomDestinationPickerState();
}

class _ShalomDestinationPickerState extends State<ShalomDestinationPicker> {
  static const _visibleAgencyCount = 3;
  final _agencyScroll = ScrollController(keepScrollOffset: false);
  late var _destinations = _loadDestinations();
  (String?, String?, String?)? _area;
  bool _showMobileMap = false;

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
    });
    if (widget.selectedId.isNotEmpty) widget.onSelected(null);
  }

  void _selectAgency(ShalomAgency agency) {
    widget.onSelected(agency);
  }

  List<String> _sortedOptions(Iterable<String> names) =>
      names.toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: FutureBuilder<List<ShalomAgency>>(
        future: _destinations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('No pudimos cargar las agencias Shalom.'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _destinations = _loadDestinations()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return Container(
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                'Cargando agencias Shalom...',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
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
          final matches = inProvince
              .where((agency) => agency.district == district)
              .toList(growable: false);

          final deptField = _LocationField(
            label: 'Departamento',
            selected: department,
            options: _sortedOptions(
              destinations.map((agency) => agency.department),
            ),
            onChanged: (value) => _changeArea(value, null, null),
          );
          final provField = _LocationField(
            label: 'Provincia',
            selected: province,
            options: _sortedOptions(
              inDepartment.map((agency) => agency.province),
            ),
            onChanged: (value) => _changeArea(department, value, null),
          );
          final distField = _LocationField(
            label: 'Distrito',
            selected: district,
            options: _sortedOptions(
              inProvince.map((agency) => agency.district),
            ),
            onChanged: (value) => _changeArea(department, province, value),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final medium = constraints.maxWidth >= 560;

              final locationSection = Container(
                padding: EdgeInsets.all(wide ? 18 : 14),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¿A dónde enviamos tu pedido?',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elige tu departamento, provincia y distrito.',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    if (medium)
                      Row(
                        children: [
                          Expanded(child: deptField),
                          const SizedBox(width: 12),
                          Expanded(child: provField),
                          const SizedBox(width: 12),
                          Expanded(child: distField),
                        ],
                      )
                    else
                      Column(
                        children: [
                          deptField,
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: provField),
                              const SizedBox(width: 10),
                              Expanded(child: distField),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              );

              final listTitle = district != null
                  ? 'Agencias en ${_formatTitleCase(district)} (${matches.length})'
                  : 'Agencias Shalom disponibles';

              final agenciesList = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.store_mall_directory_outlined,
                        size: 18,
                        color: AppColors.roseDeep,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listTitle,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (matches.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.showError
                              ? AppColors.error
                              : AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.pinkSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pin_drop_outlined,
                              color: AppColors.roseDeep,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            district == null
                                ? 'Elige tu departamento, provincia y distrito arriba'
                                : 'No encontramos agencias de destino en este distrito.',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aquí verás las agencias para tocar la que te convenga.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _AgencyResultsList(
                      controller: _agencyScroll,
                      agencies: matches,
                      selectedId: widget.selectedId,
                      visibleCount: _visibleAgencyCount,
                      onSelect: _selectAgency,
                    ),
                  if (widget.showError && matches.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Toca una agencia Shalom de la lista para continuar.',
                      style: text.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              );

              const desktopPanelHeight = 302.0;

              final mapWidget = ShalomEmbeddedMap(
                selectedAgencyId: selected?.id ?? '',
                selectedAgencyName:
                    selected != null && selected.latitude != null
                    ? _formatTitleCase(selected.displayName)
                    : '',
                selectedAgencyLocality:
                    selected != null && selected.latitude != null
                    ? _formatTitleCase(selected.localityLabel)
                    : '',
                latitude: selected?.latitude,
                longitude: selected?.longitude,
                height: wide ? desktopPanelHeight : 230,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  locationSection,
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: agenciesList),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: mapWidget,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        agenciesList,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => setState(
                              () => _showMobileMap = !_showMobileMap,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.roseDeep,
                              side: BorderSide(
                                color: AppColors.rose.withValues(alpha: 0.45),
                              ),
                              backgroundColor: _showMobileMap
                                  ? AppColors.pinkSoft.withValues(alpha: 0.5)
                                  : AppColors.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              _showMobileMap
                                  ? Icons.visibility_off_outlined
                                  : Icons.map_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _showMobileMap ? 'Ocultar mapa' : 'Ver mapa',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (_showMobileMap) ...[
                          const SizedBox(height: 12),
                          mapWidget,
                        ],
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
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
    final enabled = options.isNotEmpty;
    final current = options.contains(selected) ? selected : null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey(label),
          value: current,
          isExpanded: true,
          isDense: true,
          hint: Text(
            'Elegir',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.muted,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _AgencyResultsList extends StatelessWidget {
  const _AgencyResultsList({
    required this.controller,
    required this.agencies,
    required this.selectedId,
    required this.visibleCount,
    required this.onSelect,
  });

  final ScrollController controller;
  final List<ShalomAgency> agencies;
  final String selectedId;
  final int visibleCount;
  final ValueChanged<ShalomAgency> onSelect;

  @override
  Widget build(BuildContext context) {
    final scrollable = agencies.length > visibleCount;
    const itemHeight = 94.0;
    const itemGap = 10.0;
    final listHeight = scrollable
        ? (itemHeight * visibleCount) + (itemGap * (visibleCount - 1))
        : null;

    final list = RadioGroup<String>(
      groupValue: selectedId,
      onChanged: (id) {
        if (id == null) return;
        final agency = agencies.where((item) => item.id == id).firstOrNull;
        if (agency != null) onSelect(agency);
      },
      child: ListView.separated(
        key: const ValueKey('agency-results'),
        controller: controller,
        shrinkWrap: !scrollable,
        physics: scrollable
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(right: scrollable ? 8 : 0),
        itemCount: agencies.length,
        separatorBuilder: (_, _) => const SizedBox(height: itemGap),
        itemBuilder: (context, index) {
          final agency = agencies[index];
          final selected = agency.id == selectedId;
          return _AgencyOptionCard(
            agency: agency,
            selected: selected,
            onTap: () => onSelect(agency),
          );
        },
      ),
    );

    if (!scrollable) return list;
    return SizedBox(
      height: listHeight,
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: list,
      ),
    );
  }
}

class _AgencyOptionCard extends StatelessWidget {
  const _AgencyOptionCard({
    required this.agency,
    required this.selected,
    required this.onTap,
  });

  final ShalomAgency agency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cleanName = _formatTitleCase(agency.displayName);
    final cleanAddress = _formatTitleCase(
      agency.address.isNotEmpty ? agency.address : agency.localityLabel,
    );
    final shortTransit = _shortTransitLabel(agency.transitEstimateFromHuancayo);

    return SizedBox(
      height: 94,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: selected
            ? AppColors.pinkSoft.withValues(alpha: 0.45)
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.rose : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<String>(
                  value: agency.id,
                  activeColor: AppColors.rose,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cleanName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? AppColors.roseDeep
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.surface
                                  : AppColors.pinkSoft,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              shortTransit,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.roseDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cleanAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.35,
                        ),
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

String _shortTransitLabel(String fullLabel) {
  final cleaned = fullLabel
      .replaceFirst(RegExp(r'^Llega en\s+', caseSensitive: false), '')
      .replaceAll(' a ', '–')
      .trim();
  return cleaned.isEmpty ? '1–2 días' : cleaned;
}

String _formatTitleCase(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return '';
  const lowercaseWords = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'en', 'a'};
  const abbreviations = {
    'av': 'Av.',
    'av.': 'Av.',
    'jr': 'Jr.',
    'jr.': 'Jr.',
    'mz': 'Mz.',
    'mz.': 'Mz.',
    'lt': 'Lt.',
    'lt.': 'Lt.',
    'urb': 'Urb.',
    'urb.': 'Urb.',
    'ref': 'Ref.',
    'ref.': 'Ref.',
    'km': 'Km.',
    'km.': 'Km.',
    'cdra': 'Cdra.',
    'cdras': 'Cdras.',
  };

  final words = trimmed.split(' ');
  final buffer = <String>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word == '-' || word == '·') {
      buffer.add(word);
      continue;
    }
    final lower = word.toLowerCase();
    if (abbreviations.containsKey(lower)) {
      buffer.add(abbreviations[lower]!);
      continue;
    }
    if (i > 0 && lowercaseWords.contains(lower)) {
      buffer.add(lower);
      continue;
    }
    if (word.contains('-')) {
      buffer.add(
        word
            .split('-')
            .map(
              (part) => part.isEmpty
                  ? ''
                  : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
            )
            .join('-'),
      );
      continue;
    }
    buffer.add('${lower[0].toUpperCase()}${lower.substring(1)}');
  }
  return buffer.join(' ');
}
