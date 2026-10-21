import 'package:flutter/material.dart';

import '../data/shalom_agency_repository.dart';
import '../models/shalom_agency.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class ShalomAgencyPicker extends StatefulWidget {
  const ShalomAgencyPicker({super.key, this.selectedId = ''});

  final String selectedId;

  @override
  State<ShalomAgencyPicker> createState() => _ShalomAgencyPickerState();
}

class _ShalomAgencyPickerState extends State<ShalomAgencyPicker> {
  final _searchController = TextEditingController();
  late final Future<ShalomAgencyCatalog> _catalog =
      ShalomAgencyRepository.load();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agencias Shalom')),
      body: FutureBuilder<ShalomAgencyCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'No pudimos abrir el directorio',
              message: 'Vuelve a intentarlo en unos minutos.',
            );
          }

          final catalog = snapshot.data!;
          final publicAgencies = catalog.agencies
              .where((agency) => agency.isPublic)
              .toList(growable: false);
          final filtered =
              publicAgencies
                  .where((agency) => agency.matches(_query))
                  .toList(growable: false)
                ..sort((a, b) {
                  final byDepartment = a.department.compareTo(b.department);
                  if (byDepartment != 0) return byDepartment;
                  return a.displayName.compareTo(b.displayName);
                });

          return ResponsivePage(
            maxWidth: 1180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elige dónde recogerás tu pedido',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Busca por agencia, ciudad, distrito o dirección.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                const InfoBanner(
                  icon: Icons.local_shipping_outlined,
                  title: 'Elige un punto que reciba envíos',
                  message: 'Mostramos el directorio disponible de Shalom. Toca una tarjeta para usarla en tu cotización.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Ej. Huancayo o Lima',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'local encontrado' : 'locales encontrados'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (catalog.updatedAt != null)
                      Text(
                        'Directorio actualizado el ${catalog.updatedAt!.day}/${catalog.updatedAt!.month}/${catalog.updatedAt!.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sin resultados',
                          message:
                              'Prueba con otra ciudad, agencia o dirección.',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            Widget cardAt(int index) {
                              final agency = filtered[index];
                              return _AgencyCard(
                                agency: agency,
                                selected: agency.id == widget.selectedId,
                                onTap: agency.canReceive
                                    ? () => Navigator.of(context).pop(agency)
                                    : null,
                              );
                            }

                            if (constraints.maxWidth < 820) {
                              return ListView.separated(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) => cardAt(index),
                              );
                            }

                            return GridView.builder(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 540,
                                    mainAxisExtent: 214,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => cardAt(index),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({
    required this.agency,
    required this.selected,
    required this.onTap,
  });

  final ShalomAgency agency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                agency.isProPoint
                    ? Icons.place_outlined
                    : Icons.storefront_outlined,
                color: onTap == null ? AppColors.muted : AppColors.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${agency.typeLabel} · ${agency.localityLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (agency.address.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        agency.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (agency.openingHours.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Horario: ${agency.openingHours}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (onTap == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Este local no figura como destino de envíos.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.ink)
              else if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
